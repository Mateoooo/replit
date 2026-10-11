require "open3"
require "timeout"

# Тонкая обёртка над docker CLI. Все аргументы передаются массивом (без shell) —
# инъекция в команды хоста невозможна. Команды студента выполняются ВНУТРИ контейнера.
class DockerRunner
  class Error < StandardError; end

  Result = Struct.new(:output, :exit_code)

  APP_PORT = 3000      # порт, на котором слушает Rails внутри контейнера
  EXEC_TIMEOUT = 30    # секунд
  DOCKER_MISSING = "Docker не найден. Установите/запустите Docker Desktop и перезапустите сервер.".freeze

  def build(tag, context_dir)
    args = ["docker", "build", "-t", tag]
    platform_file = File.join(context_dir.to_s, "Dockerfile.platform")
    args += ["-f", platform_file] if File.exist?(platform_file)
    out, status = capture2e(*args, context_dir.to_s)
    raise Error, "Ошибка сборки образа:\n#{out.lines.last(30).join}" unless status.success?

    out
  end

  # Порт приложения публикуется на случайный свободный порт хоста.
  # PREVIEW_BIND — на каком интерфейсе слушать (по умолчанию только localhost).
  def run(image, name:)
    bind = ENV.fetch("PREVIEW_BIND", "127.0.0.1")
    out, err, status = capture3(
      "docker", "run", "-d", "--name", name,
      "-p", "#{bind}::#{APP_PORT}",
      "--memory", "512m", "--cpus", "1", "--pids-limit", "256",
      "--security-opt", "no-new-privileges", image
    )
    raise Error, "Не удалось запустить контейнер: #{err.strip}" unless status.success?

    out.strip
  end

  # Возвращает порт хоста, на который проброшен порт приложения
  def host_port(container, container_port = APP_PORT)
    out, err, status = capture3("docker", "port", container, "#{container_port}/tcp")
    raise Error, "Не удалось получить порт контейнера: #{err.strip}" unless status.success?

    port = out.lines.first.to_s.strip.split(":").last.to_i
    raise Error, "Порт приложения не опубликован" if port.zero?

    port
  end

  def stop(container)
    _out, err, status = capture3("docker", "stop", "-t", "5", container)
    raise Error, "Не удалось остановить контейнер: #{err.strip}" unless status.success?
  end

  def remove(container)
    capture3("docker", "rm", "-f", container)
  rescue Error
    nil
  end

  # Блокируется до завершения контейнера, возвращает код выхода
  def wait(container)
    out, err, status = capture3("docker", "wait", container)
    raise Error, "docker wait: #{err.strip}" unless status.success?

    out.strip.to_i
  end

  # Читает логи построчно до завершения контейнера. stdout/stderr объединены.
  # Вызывает блок: |stream, time, text|
  def stream_logs(container, &block)
    Open3.popen2e("docker", "logs", "-f", "--timestamps", container) do |stdin, out, thread|
      stdin.close
      out.each_line do |line|
        time, text = parse_line(line)
        block.call("stdout", time, text)
      end
      thread.value
    end
  rescue Errno::ENOENT
    raise Error, DOCKER_MISSING
  end

  def exec(container, command, timeout: EXEC_TIMEOUT)
    Open3.popen2e("docker", "exec", container, "sh", "-c", command) do |stdin, out, waiter|
      stdin.close
      reader = Thread.new { out.read }
      unless waiter.join(timeout)
        Process.kill("KILL", waiter.pid) rescue nil
        reader.kill
        raise Error, "Команда не завершилась за #{timeout} сек. и была прервана"
      end
      Result.new(reader.value.to_s, waiter.value.exitstatus || -1)
    end
  rescue Errno::ENOENT
    raise Error, DOCKER_MISSING
  end

  private

  def capture2e(*args)
    Open3.capture2e(*args)
  rescue Errno::ENOENT
    raise Error, DOCKER_MISSING
  end

  def capture3(*args)
    Open3.capture3(*args)
  rescue Errno::ENOENT
    raise Error, DOCKER_MISSING
  end

  # docker logs --timestamps: "2026-10-10T12:00:00.123456789Z текст"
  def parse_line(line)
    stamp, text = line.chomp.split(" ", 2)
    [Time.iso8601(stamp), text.to_s]
  rescue ArgumentError
    [Time.current, line.chomp]
  end
end
