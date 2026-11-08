class RunSupervisor
  TICK = 1.0
  MAX_LINE = 10_000
  RETRY_DELAY = 5
  PRUNE_INTERVAL = 600
  HEARTBEAT_INTERVAL = 60
  CONTAINER_PREFIX = "rails-run-".freeze

  def initialize(runner: DockerRunner.new, launcher: nil, max_builds: nil, inline: false, output: $stdout)
    @runner = runner
    @launcher = launcher || ProjectLauncher.new(runner: runner)
    @max_builds = max_builds || Integer(ENV.fetch("PLATFORM_MAX_BUILDS", "3"))
    @inline = inline
    @output = output
    @builds = {}
    @followers = {}
    @retry_after = {}
    @stopping = false
    @last_prune = monotonic
    @last_heartbeat = monotonic
  end

  def run
    say "Воркер запущен. Параллельных сборок: #{@max_builds}"
    recover
    until @stopping
      begin
        tick
      rescue StandardError => e
        say "Ошибка цикла: #{e.class}: #{e.message}"
      end
      sleep TICK
    end
    say "Воркер остановлен (запущенные контейнеры продолжают работать, при старте воркер подхватит их)"
  end

  def stop
    @stopping = true
  end

  def recover
    db do
      Run.pending.where.not(claimed_at: nil).find_each do |run|
        @runner.remove("#{CONTAINER_PREFIX}#{run.id}")
        run.update_column(:claimed_at, nil)
        say "Запуск ##{run.id} возвращён в очередь на сборку"
      end
    end
  end

  def tick
    reap
    db do
      start_builds
      attach_followers
    end
    housekeeping
  end

  def follow(run_id)
    run = db { Run.find(run_id) }
    container = run.container_id
    cursor = run.logs_cursor
    last = parse_time(cursor)

    loop do
      @runner.stream_logs(container, since: cursor) do |stream, time, text, raw|
        next if last && time <= last

        save_line(run, stream, time, text, raw)
        next unless raw

        last = time
        cursor = raw
      end
      break unless @runner.container_running?(container)

      sleep 1
    end

    finish(run, @runner.wait(container))
  rescue DockerRunner::Error => e
    fail_run(run_id, e.message)
  rescue ActiveRecord::RecordNotFound, ActiveRecord::InvalidForeignKey
    say "Запуск ##{run_id} удалён, наблюдение прекращено"
    cleanup_docker(run) if run
  rescue StandardError => e
    say "Наблюдение за ##{run_id}: #{e.class}: #{e.message}"
    @retry_after[run_id] = monotonic + RETRY_DELAY
  end

  def join_all(timeout = 5)
    (@builds.values + @followers.values).each { |thread| thread.join(timeout) }
  end

  private

  def start_builds
    free = @max_builds - @builds.size
    return if free <= 0

    Run.pending.where(claimed_at: nil).order(:id).limit(free).each do |run|
      next unless run.claim!

      say "Сборка запуска ##{run.id}"
      @builds[run.id] = spawn_thread { build(run.id) }
    end
  end

  def attach_followers
    Run.running.where.not(container_id: nil).where.not(id: @followers.keys).each do |run|
      next if @retry_after[run.id] && @retry_after[run.id] > monotonic

      say "Наблюдаю за запуском ##{run.id}"
      @followers[run.id] = spawn_thread { follow(run.id) }
    end
  end

  def build(run_id)
    db { @launcher.start(Run.find(run_id)) }
  rescue StandardError => e
    say "Сборка ##{run_id}: #{e.class}: #{e.message}"
  end

  def finish(run, exit_code)
    db do
      current = Run.find(run.id)
      if current.active?
        current.log_entries.create!(stream: "system", content: "Контейнер завершился с кодом #{exit_code}")
        current.complete!(exit_code: exit_code)
      end
    end
    cleanup_docker(run)
  rescue ActiveRecord::RecordNotFound, ActiveRecord::InvalidForeignKey
    cleanup_docker(run)
  end

  def fail_run(run_id, message)
    run = db { Run.find(run_id) }
    db do
      run.log_entries.create!(stream: "stderr", content: message)
      run.reload.fail!(message)
    end
    cleanup_docker(run)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def cleanup_docker(run)
    @runner.remove(run.container_id)
    @runner.remove_image(run.image_tag)
  end

  def save_line(run, stream, time, text, raw)
    db do
      run.log_entries.create!(stream: stream, content: text.to_s.truncate(MAX_LINE), logged_at: time)
      Run.where(id: run.id).update_all(logs_cursor: raw) if raw
    end
  end

  def parse_time(raw)
    raw.present? ? Time.iso8601(raw) : nil
  rescue ArgumentError
    nil
  end

  def reap
    @builds.delete_if { |_id, thread| !thread.alive? }
    @followers.delete_if { |_id, thread| !thread.alive? }
  end

  def housekeeping
    now = monotonic
    if now - @last_prune >= PRUNE_INTERVAL
      @last_prune = now
      @runner.prune_images
    end
    return unless now - @last_heartbeat >= HEARTBEAT_INTERVAL

    @last_heartbeat = now
    say "Сборок: #{@builds.size}, под наблюдением запусков: #{@followers.size}"
  end

  def spawn_thread(&block)
    return Thread.new(&block) unless @inline

    block.call
    Thread.new { }.tap(&:join)
  end

  def db(&block)
    ActiveRecord::Base.connection_pool.with_connection(&block)
  end

  def say(message)
    @output&.puts("#{Time.current.strftime('%H:%M:%S')} [worker] #{message}")
  end

  def monotonic
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
