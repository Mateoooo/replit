require "rails_helper"
require_relative "../support/test_storage"

RSpec.describe RunSupervisor do
  let(:user)     { User.create!(email: "student@example.com", password: "secret123") }
  let(:runner)   { instance_double(DockerRunner) }
  let(:launcher) { instance_double(ProjectLauncher, start: nil) }
  let(:output)   { StringIO.new }

  def build_supervisor(**options)
    described_class.new(runner: runner, launcher: launcher, output: output, **options)
  end

  def create_run(name:, status: "pending", **attrs)
    project = user.projects.create!(name: name, archive_path: "storage/x.zip")
    project.runs.create!({ status: status }.merge(attrs))
  end

  def create_running_run(name: "Blog")
    create_run(name: name, status: "running", container_id: "abc", image_tag: "img:1", host_port: 49_153)
  end

  describe "очередь сборок" do
    context "когда в очереди есть запуск (happy path)" do
      it "занимает его и передаёт на сборку" do
        run = create_run(name: "Blog")

        build_supervisor(inline: true).tick

        expect(launcher).to have_received(:start).with(run)
        expect(run.reload.claimed_at).to be_present
      end
    end

    context "когда запусков больше, чем разрешено собирать одновременно" do
      it "берёт в работу только max_builds самых старых, остальные ждут" do
        runs = Array.new(3) { |i| create_run(name: "Project #{i}") }
        gate = Queue.new
        allow(launcher).to receive(:start) { gate.pop } # сборка «идёт», пока не откроем шлюз
        supervisor = build_supervisor(max_builds: 2)

        supervisor.tick

        expect(runs.map { |run| run.reload.claimed_at.present? }).to eq([ true, true, false ])
        expect(runs.last.reload).to be_queued
        3.times { gate << :done }
        supervisor.join_all
      end
    end

    context "когда запуск не нужно собирать" do
      it "пропускает остановленные и уже занятые запуски" do
        stopped = create_run(name: "Stopped")
        stopped.stop!
        taken = create_run(name: "Taken", claimed_at: Time.current)

        build_supervisor(inline: true).tick

        expect(launcher).not_to have_received(:start)
        expect(taken.reload.claimed_at).to be_present
      end

      it "не делает ничего, если запусков нет" do
        expect { build_supervisor(inline: true).tick }.not_to raise_error
        expect(launcher).not_to have_received(:start)
      end
    end
  end

  describe "#recover (после перезапуска воркера)" do
    context "когда запуск был «в сборке»" do
      it "возвращает его в очередь и убирает недозапущенный контейнер" do
        run = create_run(name: "Blog", claimed_at: 1.minute.ago)
        allow(runner).to receive(:remove)

        build_supervisor.recover

        expect(run.reload.claimed_at).to be_nil
        expect(run).to be_queued
        expect(runner).to have_received(:remove).with("rails-run-#{run.id}")
      end
    end

    context "когда контейнер уже работает" do
      it "не трогает такой запуск" do
        run = create_running_run
        allow(runner).to receive(:remove)

        build_supervisor.recover

        expect(run.reload).to be_running
        expect(runner).not_to have_received(:remove)
      end
    end
  end

  describe "наблюдение за контейнером" do
    let(:t1) { Time.utc(2026, 10, 10, 12, 0, 0) }
    let(:t2) { Time.utc(2026, 10, 10, 12, 0, 1) }
    let(:raw1) { "2026-10-10T12:00:00Z" }
    let(:raw2) { "2026-10-10T12:00:01Z" }

    before do
      allow(runner).to receive(:container_running?).and_return(false)
      allow(runner).to receive(:wait).and_return(0)
      allow(runner).to receive(:remove)
      allow(runner).to receive(:remove_image)
    end

    def stub_log_lines(*lines)
      allow(runner).to receive(:stream_logs) do |_container, **_options, &block|
        lines.each { |line| block.call(*line) }
      end
    end

    context "когда контейнер отработал и завершился с кодом 0 (happy path)" do
      it "сохраняет строки лога, курсор и завершает запуск" do
        run = create_running_run
        stub_log_lines([ "stdout", t1, "line 1", raw1 ], [ "stdout", t2, "line 2", raw2 ])

        build_supervisor(inline: true).tick

        contents = run.log_entries.chronological.pluck(:content)
        expect(contents).to eq([ "line 1", "line 2", "Контейнер завершился с кодом 0" ])
        expect(run.reload).to be_finished
        expect(run.logs_cursor).to eq(raw2)
        expect(run.project.reload).to be_stopped
      end

      it "удаляет контейнер и образ" do
        run = create_running_run
        stub_log_lines

        build_supervisor(inline: true).tick

        expect(runner).to have_received(:remove).with("abc")
        expect(runner).to have_received(:remove_image).with("img:1")
        expect(run.reload).to be_finished
      end
    end

    context "когда воркер перезапускался" do
      it "не дублирует строки, которые уже были сохранены" do
        run = create_running_run
        run.update!(logs_cursor: raw1)
        stub_log_lines([ "stdout", t1, "уже сохранена", raw1 ], [ "stdout", t2, "новая", raw2 ])

        build_supervisor(inline: true).tick

        expect(run.log_entries.pluck(:content)).to include("новая")
        expect(run.log_entries.pluck(:content)).not_to include("уже сохранена")
      end

      it "передаёт курсор в docker logs, чтобы продолжить с нужного места" do
        run = create_running_run
        run.update!(logs_cursor: raw1)
        stub_log_lines

        build_supervisor(inline: true).tick

        expect(runner).to have_received(:stream_logs).with("abc", since: raw1)
      end
    end

    context "когда контейнер завершился с ошибкой или пропал" do
      it "ненулевой код выхода даёт failed" do
        run = create_running_run
        stub_log_lines
        allow(runner).to receive(:wait).and_return(1)

        build_supervisor(inline: true).tick

        expect(run.reload).to be_failed
        expect(run.exit_code).to eq(1)
        expect(run.log_entries.pluck(:content)).to include("Контейнер завершился с кодом 1")
      end

      it "если Docker не находит контейнер — запуск failed с сообщением" do
        run = create_running_run
        stub_log_lines
        allow(runner).to receive(:wait).and_raise(DockerRunner::Error, "docker wait: No such container")

        build_supervisor(inline: true).tick

        expect(run.reload).to be_failed
        expect(run.error_message).to include("No such container")
        expect(runner).to have_received(:remove).with("abc")
      end
    end

    context "когда запуск остановил пользователь" do
      it "статус остаётся stopped (код 137 не превращает остановку в ошибку), мусор удаляется" do
        run = create_running_run
        stub_log_lines
        allow(runner).to receive(:wait).and_return(137)
        run.stop!

        build_supervisor(inline: true).follow(run.id)

        expect(run.reload).to be_stopped
        expect(runner).to have_received(:remove).with("abc")
        expect(runner).to have_received(:remove_image).with("img:1")
      end
    end

    context "когда пользователь остановил запуск" do
      it "воркер не дописывает в лог «завершился с кодом 137» и не меняет статус" do
        run = create_running_run
        stub_log_lines
        allow(runner).to receive(:wait).and_return(137)
        run.stop!

        build_supervisor(inline: true).follow(run.id)

        expect(run.log_entries.pluck(:content)).not_to include(a_string_matching(/завершился/))
        expect(run.reload).to be_stopped
        expect(run.exit_code).to be_nil
      end
    end

    context "когда проект удалили, пока контейнер работал" do
      it "воркер не падает, а убирает за ним контейнер и образ" do
        run = create_running_run
        allow(runner).to receive(:stream_logs) do |_container, **_options, &block|
          run.project.destroy! # проект удалён посреди чтения логов
          block.call("stdout", t1, "строка для уже удалённого запуска", raw1)
        end

        expect { build_supervisor(inline: true).follow(run.id) }.not_to raise_error

        expect(Run.exists?(run.id)).to be(false)
        expect(runner).to have_received(:remove).with("abc")
        expect(runner).to have_received(:remove_image).with("img:1")
      end
    end

    context "когда прошло несколько циклов" do
      it "не создаёт второго наблюдателя за уже завершённым запуском" do
        create_running_run
        stub_log_lines
        supervisor = build_supervisor(inline: true)

        2.times { supervisor.tick }

        expect(runner).to have_received(:stream_logs).once
      end
    end
  end
end
