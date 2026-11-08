require "rails_helper"
require_relative "../support/test_storage"

RSpec.describe ProjectLauncher do
  let(:user)    { User.create!(email: "student@example.com", password: "secret123") }
  let(:project) { user.projects.create!(name: "Rails Quest", archive_path: "storage/projects/1/archive.zip") }
  let(:runner)  { instance_double(DockerRunner) }
  let(:archive) { instance_double(ProjectArchive, prepare_context: "/tmp/ctx", cleanup: nil) }

  subject(:launcher) { described_class.new(runner: runner, archive: archive) }

  describe "#enqueue" do
    context "когда проект не запущен (happy path)" do
      it "создаёт запуск в очереди, не запуская Docker, и ставит проекту статус running" do
        run = launcher.enqueue(project)

        expect(run).to be_pending
        expect(run).to be_queued
        expect(run.container_id).to be_nil
        expect(project.reload).to be_running
      end
    end

    context "когда уже есть активный запуск" do
      it "бросает AlreadyRunning и не создаёт второй" do
        launcher.enqueue(project)

        expect { launcher.enqueue(project) }.to raise_error(ProjectLauncher::AlreadyRunning)
        expect(project.runs.count).to eq(1)
      end
    end
  end

  describe "#start" do
    let!(:run) { project.runs.create!(status: "pending") }

    context "когда сборка и запуск прошли успешно (happy path)" do
      before do
        allow(runner).to receive(:build) { |_tag, _context, &line| line.call("Step 1/5"); "ok" }
        allow(runner).to receive(:run).and_return("container123")
        allow(runner).to receive(:host_port).and_return(49_153)
      end

      it "запускает контейнер и запоминает его данные" do
        launcher.start(run)

        run.reload
        expect(run).to be_running
        expect(run.container_id).to eq("container123")
        expect(run.host_port).to eq(49_153)
        expect(run.image_tag).to eq("rails-project-#{project.id}-run-#{run.id}")
        expect(runner).to have_received(:run).with(run.image_tag, name: "rails-run-#{run.id}")
      end

      it "пишет ход сборки в логи вживую и чистит рабочую папку" do
        launcher.start(run)

        expect(run.log_entries.pluck(:content)).to include("Step 1/5", a_string_matching(/порту 49153/))
        expect(archive).to have_received(:cleanup).with(run)
      end

      it "не ждёт завершения контейнера (возвращается сразу после старта)" do
        expect(runner).not_to receive(:wait)
        expect(runner).not_to receive(:stream_logs)

        launcher.start(run)
      end
    end

    context "когда сборка образа упала" do
      it "помечает запуск failed, пишет ошибку в лог и удаляет образ" do
        allow(runner).to receive(:build).and_raise(DockerRunner::Error, "build boom")
        allow(runner).to receive(:remove_image)

        launcher.start(run)

        expect(run.reload).to be_failed
        expect(run.error_message).to eq("build boom")
        expect(run.log_entries.where(stream: "stderr").pluck(:content)).to include("build boom")
        expect(project.reload).to be_failed
        expect(runner).to have_received(:remove_image).with(run.image_tag)
        expect(archive).to have_received(:cleanup)
      end

      it "при ошибке docker run убирает созданный контейнер" do
        allow(runner).to receive(:build).and_return("ok")
        allow(runner).to receive(:run).and_return("container123")
        allow(runner).to receive(:host_port).and_raise(DockerRunner::Error, "порт не опубликован")
        allow(runner).to receive(:remove)
        allow(runner).to receive(:remove_image)

        launcher.start(run)

        expect(run.reload).to be_failed
        expect(runner).to have_received(:remove).with("container123")
      end
    end

    context "когда запуск остановили во время сборки" do
      it "не стартует контейнер и удаляет собранный образ" do
        allow(runner).to receive(:build) { run.stop!; "ok" }
        allow(runner).to receive(:remove_image)
        expect(runner).not_to receive(:run)

        launcher.start(run)

        expect(run.reload).to be_stopped
        expect(runner).to have_received(:remove_image).with(run.image_tag)
      end
    end

    context "когда запуск уже не в очереди" do
      it "ничего не делает" do
        run.stop!
        expect(runner).not_to receive(:build)

        launcher.start(run)
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

    context "когда нужно, чтобы остановка не выглядела как ошибка" do
      it "помечает запуск остановленным ДО остановки контейнера (воркер увидит stopped, а не код 137)" do
        run = project.runs.create!(status: "pending")
        run.start!(container_id: "abc")
        allow(runner).to receive(:stop) { expect(run.reload).to be_stopped }

        launcher.stop(project)

        expect(runner).to have_received(:stop).with("abc")
      end

      it "если docker stop не сработал, убирает контейнер принудительно, а запуск остаётся stopped" do
        run = project.runs.create!(status: "pending")
        run.start!(container_id: "abc")
        allow(runner).to receive(:stop).and_raise(DockerRunner::Error, "daemon error")
        allow(runner).to receive(:remove)

        expect { launcher.stop(project) }.not_to raise_error

        expect(runner).to have_received(:remove).with("abc")
        expect(run.reload).to be_stopped
      end
    end

    context "когда запуск ещё стоит в очереди" do
      it "останавливает без обращения к Docker" do
        run = project.runs.create!(status: "pending")
        expect(runner).not_to receive(:stop)

        launcher.stop(project)

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
