# Оркестрация запуска проекта: Run -> сборка образа -> контейнер -> сбор логов -> итог.
class ProjectLauncher
  class AlreadyRunning < StandardError; end
  class NotRunning < StandardError; end

  def initialize(runner: DockerRunner.new, archive: ProjectArchive.new)
    @runner = runner
    @archive = archive
  end

  def enqueue(project)
    raise AlreadyRunning, "Проект уже запущен" if project.active_run

    run = project.runs.create!(status: "pending")
    LaunchRunJob.perform_later(run.id)
    run
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    raise AlreadyRunning, "Проект уже запущен"
  end

  def perform(run)
    return unless run.pending?

    project = run.project
    tag = "rails-project-#{project.id}-run-#{run.id}"

    log(run, "Распаковка архива…")
    context = @archive.prepare_context(project, run)

    log(run, "Сборка Docker-образа (первый раз может занять несколько минут)…")
    build_output = @runner.build(tag, context)
    build_output.each_line { |line| log(run, line.chomp) }

    return unless run.reload.pending?

    container_id = @runner.run(tag, name: "rails-run-#{run.id}")
    run.container_id = container_id # чтобы fail_run мог убрать контейнер
    port = @runner.host_port(container_id)
    run.start!(container_id: container_id, image_tag: tag, host_port: port)
    log(run, "Контейнер запущен, приложение доступно на порту #{port}")

    @runner.stream_logs(container_id) do |stream, time, text|
      run.log_entries.create!(stream: stream, content: text, logged_at: time)
    end

    exit_code = @runner.wait(container_id)
    log(run, "Контейнер завершился с кодом #{exit_code}")
    run.reload.complete!(exit_code: exit_code)
    @runner.remove(container_id)
  rescue DockerRunner::Error, ProjectArchive::Error => e
    fail_run(run, e.message)
  rescue StandardError => e
    Rails.logger.error("ProjectLauncher: #{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}")
    fail_run(run, "Внутренняя ошибка: #{e.message}")
  ensure
    @archive.cleanup(run)
  end

  def stop(project)
    run = project.active_run
    raise NotRunning, "Проект не запущен" unless run

    @runner.stop(run.container_id) if run.container_id.present?
    run.stop!
    run
  end

  private

  def log(run, text, stream = "system")
    run.log_entries.create!(stream: stream, content: text)
  end

  def fail_run(run, message)
    log(run, message, "stderr")
    run.reload.fail!(message)
    @runner.remove(run.container_id) if run.container_id.present?
  end
end
