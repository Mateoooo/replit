require "open3"
require "timeout"

class DockerRunner
  class Error < StandardError; end

  Result = Struct.new(:output, :exit_code)

  APP_PORT = 3000          # порт, на котором слушает Rails внутри контейнера
  EXEC_TIMEOUT = 30        # секунд
  BUILD_OUTPUT_KEEP = 200  # сколько последних строк сборки помнить для сообщения об ошибке
  DOCKER_MISSING = "Docker не найден. Установите/запустите Docker Desktop и перезапустите сервер.".freeze

  # cборка образа
  def build(tag, context_dir)
    args = [ "docker", "build", "-t", tag ]
    platform_file = File.join(context_dir.to_s, "Dockerfile.platform")
    args += [ "-f", platform_file ] if File.exist?(platform_file)
    args << context_dir.to_s

    tail = []
    status = nil
    Open3.popen2e(*args) do |stdin, out, waiter|
      stdin.close
      out.each_line do |line|
        line = line.chomp
        tail << line
        tail.shift if tail.size > BUILD_OUTPUT_KEEP
        yield line if block_given?
      end
      status = waiter.value
    end
    raise Error, "Ошибка сборки образа:\n#{tail.last(30).join("\n")}" unless status.success?

    tail.join("\n")
  rescue Errno::ENOENT
    raise Error, DOCKER_MISSING
  end

  def run(image, name:)
    bind = ENV.fetch("PREVIEW_BIND", "127.0.0.1")
    out, err, status = capture3(
      "docker", "run", "-d", "--init", "--name", name,
      "-p", "#{bind}::#{APP_PORT}",
      "--memory", "512m", "--cpus", "1", "--pids-limit", "256",
      "--security-opt", "no-new-privileges", image
    )
    raise Error, "Не удалось запустить контейнер: #{err.strip}" unless status.success?

    out.strip
  end

  def host_port(container, container_port = APP_PORT)
    out, err, status = capture3("docker", "port", container, "#{container_port}/tcp")
    raise Error, "Не удалось получить порт контейнера: #{err.strip}" unless status.success?

    port = out.lines.first.to_s.strip.split(":").last.to_i
    raise Error, "Порт приложения не опубликован" if port.zero?

    port
  end

  def stop(container)
    _out, err, status = capture3("docker", "stop", "-t", "3", container)
    raise Error, "Не удалось остановить контейнер: #{err.strip}" unless status.success?
  end

  def remove(container)
    return if container.blank?

    capture3("docker", "rm", "-f", container)
  rescue Error
    nil
  end

  def remove_image(tag)
    return if tag.blank?

    capture3("docker", "rmi", tag)
  rescue Error
    nil
  end

  def prune_images
    capture3("docker", "image", "prune", "-f")
  rescue Error
    nil
  end

  def container_running?(container)
    out, _err, status = capture3("docker", "inspect", "-f", "{{.State.Running}}", container)
    status.success? && out.strip == "true"
  rescue Error
    false
  end

  def wait(container)
    out, err, status = capture3("docker", "wait", container)
    raise Error, "docker wait: #{err.strip}" unless status.success?

    out.strip.to_i
  end

  def stream_logs(container, since: nil, &block)
    args = [ "docker", "logs", "-f", "--timestamps" ]
    args += [ "--since", since ] if since.present?
    args << container

    Open3.popen2e(*args) do |stdin, out, thread|
      stdin.close
      out.each_line do |line|
        raw, text, time = split_line(line)
        block.call("stdout", time, text, raw)
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

  def capture3(*args)
    Open3.capture3(*args)
  rescue Errno::ENOENT
    raise Error, DOCKER_MISSING
  end

  def split_line(line)
    stamp, text = line.chomp.split(" ", 2)
    [ stamp, text.to_s, Time.iso8601(stamp) ]
  rescue ArgumentError, TypeError
    [ nil, line.chomp, Time.current ]
  end
end
