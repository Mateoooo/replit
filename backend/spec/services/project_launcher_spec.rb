require "rails_helper"

RSpec.describe ProjectLauncher do
  let(:user)    { User.create!(email: "student@example.com", password: "secret123") }
  let(:project) { user.projects.create!(name: "Rails Quest", archive_path: "storage/projects/1/archive.zip") }
  let(:runner)  { instance_double(DockerRunner) }
  let(:archive) { instance_double(ProjectArchive, prepare_context: "/tmp/ctx", cleanup: nil) }

  subject(:launcher) { described_class.new(runner: runner, archive: archive) }

  before { ActiveJob::Base.queue_adapter = :test }

  describe "#enqueue" do
    context "когда проект не запущен" do
      it "создаёт pending-запуск и ставит задачу в очередь" do
        run = launcher.enqueue(project)

        expect(run).to be_pending
        expect(LaunchRunJob).to have_been_enqueued.with(run.id)
      end
    end

    context "когда уже есть активный запуск" do
      it "бросает AlreadyRunning" do
        launcher.enqueue(project)

        expect { launcher.enqueue(project) }.to raise_error(ProjectLauncher::AlreadyRunning)
      end
    end
  end

  describe "#perform" do
    let(:run) { project.runs.create!(status: "pending") }

    context "когда сборка и запуск прошли успешно" do
      before do
        allow(runner).to receive(:build).and_return("Successfully built\n")
        allow(runner).to receive(:run).and_return("container123")
        allow(runner).to receive(:host_port).and_return(49_153)
        allow(runner).to receive(:remove)
        allow(runner).to receive(:stream_logs).and_yield("stdout", Time.current, "Hello from Rails")
        allow(runner).to receive(:wait).and_return(0)
      end

      it "сохраняет логи и завершает запуск со статусом finished" do
        launcher.perform(run)

        run.reload
        expect(run).to be_finished
        expect(run.container_id).to eq("container123")
        expect(run.host_port).to eq(49_153)
        expect(run.log_entries.pluck(:content)).to include("Hello from Rails")
        expect(project.reload).to be_stopped
        expect(archive).to have_received(:cleanup).with(run)
      end
    end

    context "когда сборка образа упала" do
      it "помечает запуск как failed с сообщением и чистит файлы" do
        allow(runner).to receive(:build).and_raise(DockerRunner::Error, "build boom")

        launcher.perform(run)

        expect(run.reload).to be_failed
        expect(run.error_message).to eq("build boom")
        expect(project.reload).to be_failed
        expect(archive).to have_received(:cleanup)
      end
    end
  end

  describe "#stop" do
    context "когда контейнер работает" do
      it "останавливает его и помечает запуск stopped" do
        run = project.runs.create!(status: "pending")
        run.start!(container_id: "abc")
        allow(runner).to receive(:stop)

        launcher.stop(project)

        expect(runner).to have_received(:stop).with("abc")
        expect(run.reload).to be_stopped
      end
    end

    context "когда проект не запущен" do
      it "бросает NotRunning" do
        expect { launcher.stop(project) }.to raise_error(ProjectLauncher::NotRunning)
      end
    end
  end
end
