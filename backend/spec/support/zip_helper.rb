require "zip"

# Собирает zip-архивы для тестов: build_zip(путь, "Gemfile" => "содержимое", ...)
module ZipHelper
  def build_zip(path, files)
    Zip::OutputStream.open(path) do |zip|
      files.each do |name, content|
        zip.put_next_entry(name)
        zip.write(content)
      end
    end
    path
  end
end
