require "rails_helper"
require_relative "../support/test_storage"

RSpec.describe Project, type: :model do
  let(:user)  { User.create!(email: "student@example.com", password: "secret123") }
  let(:other) { User.create!(email: "other@example.com", password: "secret123") }

  def build_project(owner: user, **attrs)
    owner.projects.new({ name: "Blog API", archive_path: "storage/x.zip" }.merge(attrs))
  end

  describe "валидации" do
    context "с корректными данными (happy path)" do
      it "сохраняется со статусом created и обрезает пробелы в названии" do
        project = build_project(name: "  Blog API  ")

        expect(project.save).to be(true)
        expect(project.name).to eq("Blog API")
        expect(project).to be_created
      end
    end

    context "с некорректным названием" do
      it "требует название и ограничивает его 100 символами" do
        expect(build_project(name: "")).not_to be_valid
        expect(build_project(name: "a" * 101)).not_to be_valid
      end

      it "не принимает повтор названия у того же пользователя без учёта регистра" do
        build_project.save!

        expect(build_project(name: "blog api")).not_to be_valid
      end

      it "позволяет другому пользователю взять то же название" do
        build_project.save!

        expect(build_project(owner: other)).to be_valid
      end
    end

    context "без архива" do
      it "не создаётся: нужно загрузить zip" do
        project = user.projects.new(name: "Blog API")

        expect(project).not_to be_valid
        expect(project.errors.full_messages.join).to include("zip-архив")
      end
    end
  end

  describe "#refresh_status!" do
    let!(:project) { build_project.tap(&:save!) }

    context "когда запусков ещё не было" do
      it "оставляет статус created" do
        project.refresh_status!

        expect(project.reload).to be_created
      end
    end

    context "когда есть активный запуск" do
      it "ставит running" do
        project.runs.create!(status: "pending")

        expect(project.reload).to be_running
      end
    end

    context "когда последний запуск завершился" do
      it "ставит failed после ошибки и stopped после остановки" do
        run = project.runs.create!(status: "pending")
        run.fail!("boom")
        expect(project.reload).to be_failed

        project.runs.create!(status: "pending").stop!
        expect(project.reload).to be_stopped
      end
    end
  end

  describe "#last_run и #active_run" do
    let!(:project) { build_project.tap(&:save!) }

    context "когда запусков несколько" do
      it "last_run — самый новый, active_run — только незавершённый" do
        first = project.runs.create!(status: "pending")
        first.stop!
        second = project.runs.create!(status: "pending")

        expect(project.last_run).to eq(second)
        expect(project.active_run).to eq(second)
      end
    end

    context "когда запусков нет" do
      it "возвращает nil" do
        expect(project.last_run).to be_nil
        expect(project.active_run).to be_nil
        expect(project.last_run_at).to be_nil
      end
    end
  end

  describe "удаление" do
    context "при удалении проекта" do
      it "удаляет запуски, логи и файлы архива" do
        project = build_project.tap(&:save!)
        run = project.runs.create!(status: "pending")
        run.log_entries.create!(content: "hello")
        dir = ProjectArchive::ROOT.join(project.id.to_s)
        FileUtils.mkdir_p(dir)
        File.write(dir.join("archive.zip"), "data")

        expect { project.destroy }
          .to change(Run, :count).by(-1)
          .and change(LogEntry, :count).by(-1)
        expect(File.exist?(dir.join("archive.zip"))).to be(false)
      end
    end
  end
end
