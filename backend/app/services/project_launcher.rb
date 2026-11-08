class ProjectLauncher
  class AlreadyRunning < StandardError; end
  class NotRunning < StandardError; end

  def initialize(runner: DockerRunner.new, archive: ProjectArchive.new)
    @runner = runner
    @archive = archive
  end

  def enqueue(project)
    raise AlreadyRunning, "Проект уже запущен" if project.active_run

    project.runs.create!(status: "pending")
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    raise AlreadyRunning, "Проект уже запущен"
  end

  def start(run)
    return unless run.pending?

    project = run.project
    tag = "rails-project-#{project.id}-run-#{run.id}"
    run.update_column(:image_tag, tag) # чтобы образ можно было удалить, даже если сборка упадёт

    log(run, "Распаковка архива…")
    context = @archive.prepare_context(project, run)

    log(run, "Сборка Docker-образа (первый раз может занять несколько минут)…")
    @runner.build(tag, context) { |line| log(run, line) }

    unless run.reload.pending?
      @runner.remove_image(tag)
      return
    end

    container_id = @runner.run(tag, name: "rails-run-#{run.id}")
    run.container_id = container_id
    port = @runner.host_port(container_id)
    run.start!(container_id: container_id, image_tag: tag, host_port: port)
    log(run, "Контейнер запущен, приложение доступно на порту #{port}")
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

    run.stop!
    stop_container(run.container_id)
    run
  end

  private

  def stop_container(container_id)
    return if container_id.blank?

    @runner.stop(container_id)
  rescue DockerRunner::Error
    @runner.remove(container_id)
  end

  def log(run, text, stream = "system")
    run.log_entries.create!(stream: stream, content: text)
  end

  def fail_run(run, message)
    container_id = run.container_id
    image_tag = run.image_tag

    log(run, message, "stderr")
    run.reload.fail!(message)
    @runner.remove(container_id) if container_id.present?
    @runner.remove_image(image_tag)
  end
end
