require "rails_helper"

RSpec.describe CommandExecution do
  let(:user)    { User.create!(email: "student@example.com", password: "secret123") }
  let(:project) { user.projects.create!(name: "Todo", archive_path: "storage/projects/1/archive.zip") }
  let(:run)     { project.runs.create!(status: "pending").tap { |r| r.start!(container_id: "abc123") } }
  let(:runner)  { instance_double(DockerRunner) }

  describe "валидации" do
    context "когда запуск активен" do
      it "принимает непустую команду" do
        expect(run.command_executions.new(user: user, command: "ls -la")).to be_valid
      end

      it "отклоняет пустую и слишком длинную команду" do
        expect(run.command_executions.new(user: user, command: " ")).not_to be_valid
        expect(run.command_executions.new(user: user, command: "a" * 2001)).not_to be_valid
      end
    end

    context "когда контейнер уже остановлен" do
      it "не позволяет создать команду" do
        run.stop!
        execution = run.command_executions.new(user: user, command: "ls")

        expect(execution).not_to be_valid
        expect(execution.errors.full_messages.first).to include("не запущен")
      end
    end
  end

  describe "#execute!" do
    let(:execution) { run.command_executions.create!(user: user, command: "ruby -v") }

    context "когда команда выполнилась успешно" do
      it "сохраняет вывод и статус completed" do
        allow(runner).to receive(:exec).with("abc123", "ruby -v")
                                       .and_return(DockerRunner::Result.new("ruby 3.3.0\n", 0))

        execution.execute!(runner: runner)

        expect(execution.reload).to be_completed
        expect(execution.output).to eq("ruby 3.3.0\n")
        expect(execution.exit_code).to eq(0)
      end
    end

    context "когда команда завершилась с ошибкой" do
      it "ставит статус failed и сохраняет код выхода" do
        allow(runner).to receive(:exec).and_return(DockerRunner::Result.new("sh: foo: not found", 127))

        execution.execute!(runner: runner)

        expect(execution.reload).to be_failed
        expect(execution.exit_code).to eq(127)
      end
    end

    context "когда docker вернул ошибку или таймаут" do
      it "сохраняет сообщение об ошибке в output" do
        allow(runner).to receive(:exec).and_raise(DockerRunner::Error, "таймаут")

        execution.execute!(runner: runner)

        expect(execution.reload).to be_failed
        expect(execution.output).to eq("таймаут")
      end
    end
  end
end
