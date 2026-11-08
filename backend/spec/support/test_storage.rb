require "tmpdir"
require "fileutils"

RSpec.configure do |config|
  config.before do
    @platform_storage_dir = Dir.mktmpdir("platform-storage")
    stub_const("ProjectArchive::ROOT", Pathname.new(@platform_storage_dir))
  end

  config.after do
    FileUtils.remove_entry(@platform_storage_dir) if @platform_storage_dir
  end
end
