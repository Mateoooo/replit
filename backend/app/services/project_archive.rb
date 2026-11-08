require "zip"
require "fileutils"

class ProjectArchive
  class Error < StandardError; end

  MAX_ARCHIVE_SIZE  = 100.megabytes
  MAX_UNPACKED_SIZE = 500.megabytes
  MAX_ENTRIES       = 20_000
  ROOT = Rails.root.join("storage", "projects")

  def self.validate_upload(upload)
    return "Загрузите zip-архив с проектом" unless upload.respond_to?(:path) && upload.respond_to?(:size)
    return "Архив больше #{MAX_ARCHIVE_SIZE / 1.megabyte} МБ" if upload.size > MAX_ARCHIVE_SIZE

    Zip::File.open(upload.path) do |zip|
      entries = zip.entries
      return "Слишком много файлов в архиве" if entries.size > MAX_ENTRIES
      return "Распакованный размер больше #{MAX_UNPACKED_SIZE / 1.megabyte} МБ" if entries.sum(&:size) > MAX_UNPACKED_SIZE
      return "В архиве не найден Gemfile — это не Rails-проект" unless entries.any? { |e| gemfile_entry?(e.name) }
    end
    nil
  rescue Zip::Error
    "Файл не является корректным zip-архивом"
  end

  def self.gemfile_entry?(name)
    parts = name.split("/").reject(&:empty?)
    parts.first != "__MACOSX" && parts.last == "Gemfile" && parts.size <= 2
  end

  def store(project, upload)
    dir = ROOT.join(project.id.to_s)
    FileUtils.mkdir_p(dir)
    path = dir.join("archive.zip")
    FileUtils.cp(upload.path, path)
    project.update_columns(
      archive_path: path.to_s,
      archive_filename: upload.original_filename.to_s.truncate(255),
      archive_size: upload.size
    )
  end

  def delete(project)
    FileUtils.rm_rf(ROOT.join(project.id.to_s))
  end

  def prepare_context(project, run)
    raise Error, "Архив проекта не найден" unless project.archive_path && File.exist?(project.archive_path)

    target = workdir(run)
    FileUtils.rm_rf(target)
    FileUtils.mkdir_p(target)
    extract(project.archive_path, target)
    root = project_root(target)
    PlatformDockerfile.new(root).write
    inject_preview_initializer(root)
    root
  end

  def cleanup(run)
    FileUtils.rm_rf(workdir(run))
  end

  private

  def workdir(run)
    ROOT.join(run.project_id.to_s, "run-#{run.id}").to_s
  end

  def extract(zip_path, target)
    target = File.expand_path(target)
    total = 0

    Zip::File.open(zip_path) do |zip|
      zip.each do |entry|
        next if entry.name.start_with?("__MACOSX/")
        raise Error, "Символические ссылки в архиве запрещены" if entry.symlink?

        dest = File.expand_path(entry.name, target)
        unless dest == target || dest.start_with?(target + File::SEPARATOR)
          raise Error, "Недопустимый путь в архиве: #{entry.name}"
        end

        if entry.directory?
          FileUtils.mkdir_p(dest)
          next
        end

        FileUtils.mkdir_p(File.dirname(dest))
        entry.get_input_stream do |input|
          File.open(dest, "wb") do |out|
            while (chunk = input.read(64 * 1024))
              total += chunk.bytesize
              raise Error, "Распакованный размер превышает лимит" if total > MAX_UNPACKED_SIZE

              out.write(chunk)
            end
          end
        end
        perm = entry.unix_perms
        File.chmod(perm & 0o777, dest) if perm && perm.positive?
      end
    end
  rescue Zip::Error => e
    raise Error, "Не удалось распаковать архив: #{e.message}"
  end

  def project_root(target)
    return target if File.exist?(File.join(target, "Gemfile"))

    children = Dir.children(target).reject { |c| c == "__MACOSX" }
    single = children.size == 1 ? File.join(target, children.first) : nil
    single && File.directory?(single) ? single : target
  end

  def inject_preview_initializer(root)
    return unless File.exist?(File.join(root, "config", "application.rb"))

    dir = File.join(root, "config", "initializers")
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "zz_platform_preview.rb"), <<~RUBY)
      class PlatformAllowFraming
        def initialize(app)
          @app = app
        end

        def call(env)
          status, headers, body = @app.call(env)
          headers.delete("X-Frame-Options")
          headers.delete("x-frame-options")
          [status, headers, body]
        end
      end

      Rails.application.config.middleware.insert_before 0, PlatformAllowFraming
      Rails.application.config.hosts.clear if Rails.application.config.respond_to?(:hosts)
    RUBY
  end
end
