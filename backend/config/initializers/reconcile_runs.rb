# При перезапуске сервера фоновые потоки (сборка, сбор логов) умирают, а запуски
# в статусе pending/running остаются «висеть», и контейнеры тоже. Здесь наводим порядок.
Rails.application.config.after_initialize do
  next unless defined?(Rails::Server) # только при `rails s`, не в консоли/тестах/миграциях

  begin
    next unless ActiveRecord::Base.connection.table_exists?(:runs)

    runner = DockerRunner.new
    Run.active.find_each do |run|
      runner.remove(run.container_id) if run.container_id.present?
      run.fail!("Сервер был перезапущен во время запуска")
    end
  rescue StandardError => e
    Rails.logger.warn("reconcile_runs: #{e.class}: #{e.message}")
  end
end
