require "tmpdir"
require "fileutils"

# Тесты не должны трогать настоящую папку storage/projects (там лежат архивы из разработки):
# на время каждого примера подменяем ProjectArchive::ROOT временной папкой.
RSpec.configure do |config|
  config.before do
    @platform_storage_dir = Dir.mktmpdir("platform-storage")
    stub_const("ProjectArchive::ROOT", Pathname.new(@platform_storage_dir))
  end

  config.after do
    FileUtils.remove_entry(@platform_storage_dir) if @platform_storage_dir
  end
end
