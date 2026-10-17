require "rails_helper"
require_relative "../support/zip_helper"
require_relative "../support/test_storage"

RSpec.describe ProjectArchive do
  include ZipHelper

  let(:tmp) { Dir.mktmpdir("archive-spec") }
  let(:zip_path) { File.join(tmp, "app.zip") }

  after { FileUtils.remove_entry(tmp) }

  def upload_for(path)
    double("upload", path: path, size: File.size(path), original_filename: "app.zip")
  end

  describe ".validate_upload" do
    context "с корректным Rails-архивом (happy path)" do
      it "принимает архив с Gemfile в корне" do
        build_zip(zip_path, "Gemfile" => "source 'https://rubygems.org'")

        expect(described_class.validate_upload(upload_for(zip_path))).to be_nil
      end

      it "принимает архив, где проект лежит в одной вложенной папке" do
        build_zip(zip_path, "my_app/Gemfile" => "source 'https://rubygems.org'")

        expect(described_class.validate_upload(upload_for(zip_path))).to be_nil
      end
    end

    context "с неподходящим файлом" do
      it "отклоняет архив без Gemfile" do
        build_zip(zip_path, "README.md" => "hello")

        expect(described_class.validate_upload(upload_for(zip_path))).to include("Gemfile")
      end

      it "отклоняет файл, который не является zip" do
        File.write(zip_path, "это просто текст")

        expect(described_class.validate_upload(upload_for(zip_path))).to include("не является корректным zip")
      end

      it "отклоняет отсутствие файла" do
        expect(described_class.validate_upload(nil)).to include("Загрузите zip")
      end

      it "отклоняет слишком большой архив" do
        build_zip(zip_path, "Gemfile" => "source 'https://rubygems.org'")
        stub_const("ProjectArchive::MAX_ARCHIVE_SIZE", 10)

        expect(described_class.validate_upload(upload_for(zip_path))).to include("Архив больше")
      end
    end
  end

  describe "#prepare_context" do
    let(:project) { double("project", id: 1, archive_path: zip_path) }
    let(:run)     { double("run", id: 7, project_id: 1) }

    context "с обычным проектом (happy path)" do
      before do
        build_zip(zip_path,
                  "Gemfile" => "source 'https://rubygems.org'",
                  "config/application.rb" => "# rails",
                  ".ruby-version" => "3.2.2\n")
      end

      it "распаковывает файлы и возвращает каталог проекта" do
        root = described_class.new.prepare_context(project, run)

        expect(File.exist?(File.join(root, "Gemfile"))).to be(true)
        expect(File.exist?(File.join(root, "config/application.rb"))).to be(true)
      end

      it "создаёт Dockerfile платформы с нужной версией Ruby и портом 3000" do
        root = described_class.new.prepare_context(project, run)
        dockerfile = File.read(File.join(root, "Dockerfile.platform"))

        expect(dockerfile).to include("FROM ruby:3.2.2")
        expect(dockerfile).to include("EXPOSE 3000")
        expect(dockerfile).to include("RAILS_ENV=development")
      end

      it "добавляет initializer, разрешающий показ во фрейме" do
        root = described_class.new.prepare_context(project, run)
        initializer = File.read(File.join(root, "config/initializers/zz_platform_preview.rb"))

        expect(initializer).to include("PlatformAllowFraming")
      end
    end

    context "с особенностями проекта" do
      it "заходит в единственную вложенную папку" do
        build_zip(zip_path, "my_app/Gemfile" => "x", "my_app/config/application.rb" => "# rails")

        root = described_class.new.prepare_context(project, run)

        expect(File.basename(root)).to eq("my_app")
      end

      it "подключает Node, если есть package.json" do
        build_zip(zip_path, "Gemfile" => "x", "package.json" => "{}")

        root = described_class.new.prepare_context(project, run)

        expect(File.read(File.join(root, "Dockerfile.platform"))).to include("nodejs npm")
      end

      it "игнорирует собственный Dockerfile проекта" do
        build_zip(zip_path, "Gemfile" => "x", "Dockerfile" => "FROM scratch")

        root = described_class.new.prepare_context(project, run)

        expect(File.read(File.join(root, "Dockerfile.platform"))).not_to include("scratch")
      end
    end

    context "с вредоносным или повреждённым архивом" do
      it "не даёт выйти за пределы каталога (zip-slip)" do
        build_zip(zip_path, "Gemfile" => "x", "../evil.rb" => "puts 'pwned'")

        expect { described_class.new.prepare_context(project, run) }
          .to raise_error(ProjectArchive::Error, /Недопустимый путь/)
        expect(File.exist?(ProjectArchive::ROOT.join("1", "evil.rb"))).to be(false)
      end

      it "сообщает, если файла архива нет на диске" do
        missing = double("project", id: 1, archive_path: File.join(tmp, "nope.zip"))

        expect { described_class.new.prepare_context(missing, run) }
          .to raise_error(ProjectArchive::Error, /не найден/)
      end
    end
  end

  describe "#store, #cleanup и #delete" do
    let(:project) { double("project", id: 5, update_columns: nil) }
    let(:run)     { double("run", id: 9, project_id: 5) }

    context "при сохранении загруженного архива" do
      it "копирует файл и запоминает его параметры в проекте" do
        build_zip(zip_path, "Gemfile" => "x")

        described_class.new.store(project, upload_for(zip_path))

        expect(File.exist?(ProjectArchive::ROOT.join("5", "archive.zip"))).to be(true)
        expect(project).to have_received(:update_columns)
          .with(hash_including(archive_filename: "app.zip", archive_size: File.size(zip_path)))
      end
    end

    context "при очистке" do
      it "cleanup удаляет рабочую папку запуска, delete — все файлы проекта" do
        work = ProjectArchive::ROOT.join("5", "run-9")
        FileUtils.mkdir_p(work)
        File.write(work.join("x"), "1")

        described_class.new.cleanup(run)
        expect(Dir.exist?(work)).to be(false)

        described_class.new.delete(project)
        expect(Dir.exist?(ProjectArchive::ROOT.join("5"))).to be(false)
      end
    end
  end
end
