namespace :platform do
  desc "Воркер платформы: собирает образы, запускает контейнеры, собирает логи"
  task worker: :environment do
    $stdout.sync = true
    supervisor = RunSupervisor.new
    %w[INT TERM].each { |signal| Signal.trap(signal) { supervisor.stop } }
    supervisor.run
  end
end
