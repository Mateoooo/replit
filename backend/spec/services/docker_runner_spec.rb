require "rails_helper"

RSpec.describe DockerRunner do
  let(:bin_dir)  { Dir.mktmpdir("fake-docker") }
  let(:calls)    { File.join(bin_dir, "calls.log") }
  let(:runner)   { described_class.new }

  let(:fake_docker) do
    <<~SH
      #!/bin/sh
      echo "$@" >> "$FAKE_DOCKER_LOG"
      case "$1" in
        build)
          echo "Step 1/2"
          echo "Step 2/2"
          if [ "$FAKE_DOCKER_FAIL" = "1" ]; then echo "boom: bundle install failed"; exit 1; fi
          exit 0 ;;
        logs)
          echo "2026-10-10T12:00:00.123456789Z hello"
          echo "2026-10-10T12:00:01Z world"
          echo "строка без метки времени"
          exit 0 ;;
        port) echo "127.0.0.1:49153"; exit 0 ;;
        inspect) echo "${FAKE_DOCKER_RUNNING:-false}"; exit 0 ;;
        rm|rmi) echo "Error: No such container" >&2; exit 1 ;;
        *) exit 0 ;;
      esac
    SH
  end

  before do
    script = File.join(bin_dir, "docker")
    File.write(script, fake_docker)
    File.chmod(0o755, script)
    @old_path = ENV["PATH"]
    ENV["PATH"] = "#{bin_dir}:#{@old_path}"
    ENV["FAKE_DOCKER_LOG"] = calls
  end

  after do
    ENV["PATH"] = @old_path
    %w[FAKE_DOCKER_LOG FAKE_DOCKER_FAIL FAKE_DOCKER_RUNNING].each { |name| ENV.delete(name) }
    FileUtils.remove_entry(bin_dir)
  end

  def recorded_calls
    File.read(calls).lines.map(&:strip)
  end

  describe "#build" do
    context "когда сборка успешна (happy path)" do
      it "передаёт строки вывода в блок по мере сборки" do
        lines = []

        runner.build("img:1", bin_dir) { |line| lines << line }

        expect(lines).to eq([ "Step 1/2", "Step 2/2" ])
      end

      it "использует Dockerfile.platform, если он есть в папке проекта" do
        File.write(File.join(bin_dir, "Dockerfile.platform"), "FROM scratch")

        runner.build("img:1", bin_dir)

        expect(recorded_calls.first).to include("-f #{File.join(bin_dir, 'Dockerfile.platform')}")
      end
    end

    context "когда сборка упала" do
      it "бросает ошибку с последними строками вывода" do
        ENV["FAKE_DOCKER_FAIL"] = "1"

        expect { runner.build("img:1", bin_dir) }
          .to raise_error(DockerRunner::Error, /boom: bundle install failed/)
      end
    end
  end

  describe "#stream_logs" do
    context "при чтении логов контейнера" do
      it "разбирает метку времени, текст и сырую метку (для курсора)" do
        lines = []

        runner.stream_logs("abc") { |stream, time, text, raw| lines << [ stream, time, text, raw ] }

        expect(lines[0]).to eq([ "stdout", Time.iso8601("2026-10-10T12:00:00.123456789Z"), "hello", "2026-10-10T12:00:00.123456789Z" ])
        expect(lines[1][2]).to eq("world")
      end

      it "строку без метки времени сохраняет целиком и без сырой метки" do
        lines = []

        runner.stream_logs("abc") { |_stream, _time, text, raw| lines << [ text, raw ] }

        expect(lines.last).to eq([ "строка без метки времени", nil ])
      end
    end

    context "при продолжении после перезапуска воркера" do
      it "передаёт курсор в docker logs --since" do
        runner.stream_logs("abc", since: "2026-10-10T12:00:00Z") { |*| }

        expect(recorded_calls.first).to include("--since 2026-10-10T12:00:00Z")
      end

      it "без курсора читает с начала" do
        runner.stream_logs("abc") { |*| }

        expect(recorded_calls.first).not_to include("--since")
      end
    end
  end

  describe "остальные команды" do
    it "host_port возвращает порт хоста" do
      expect(runner.host_port("abc")).to eq(49_153)
    end

    it "container_running? отражает состояние контейнера" do
      expect(runner.container_running?("abc")).to be(false)

      ENV["FAKE_DOCKER_RUNNING"] = "true"
      expect(runner.container_running?("abc")).to be(true)
    end

    it "remove и remove_image не падают, если удалять нечего" do
      expect { runner.remove("abc") }.not_to raise_error
      expect { runner.remove_image("img:1") }.not_to raise_error
      expect { runner.remove(nil) }.not_to raise_error
    end
  end

  describe "когда Docker не установлен" do
    it "сообщает понятной ошибкой" do
      ENV["PATH"] = "/nonexistent"

      expect { runner.host_port("abc") }.to raise_error(DockerRunner::Error, /Docker не найден/)
      expect { runner.build("img", bin_dir) }.to raise_error(DockerRunner::Error, /Docker не найден/)
    end
  end
end
