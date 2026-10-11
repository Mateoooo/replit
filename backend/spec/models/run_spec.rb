require "rails_helper"

RSpec.describe Run do
  let(:user)    { User.create!(email: "student@example.com", password: "secret123") }
  let(:project) { user.projects.create!(name: "Blog API", archive_path: "storage/projects/1/archive.zip") }

  describe "валидации" do
    context "когда у проекта уже есть активный запуск" do
      it "не даёт создать второй" do
        project.runs.create!(status: "pending")
        second = project.runs.new(status: "pending")

        expect(second).not_to be_valid
        expect(second.errors.full_messages.first).to include("активный запуск")
      end
    end

    context "когда предыдущий запуск завершён" do
      it "позволяет создать новый" do
        first = project.runs.create!(status: "pending")
        first.stop!

        expect(project.runs.new(status: "pending")).to be_valid
      end
    end
  end

  describe "#complete!" do
    let!(:run) { project.runs.create!(status: "pending").tap { |r| r.start!(container_id: "abc") } }

    context "при коде выхода 0" do
      it "помечает запуск finished, а проект stopped" do
        expect(run.complete!(exit_code: 0)).to be(true)

        expect(run.reload).to be_finished
        expect(run.finished_at).to be_present
        expect(project.reload).to be_stopped
      end
    end

    context "при ненулевом коде выхода" do
      it "помечает запуск и проект как failed" do
        run.complete!(exit_code: 1)

        expect(run.reload).to be_failed
        expect(run.exit_code).to eq(1)
        expect(project.reload).to be_failed
      end
    end

    context "когда запуск уже остановлен пользователем" do
      it "не перезаписывает статус (код 137 от docker stop)" do
        run.stop!

        expect(run.complete!(exit_code: 137)).to be(false)
        expect(run.reload).to be_stopped
      end
    end
  end

  describe "статус проекта" do
    context "при смене статуса запуска" do
      it "автоматически синхронизируется" do
        run = project.runs.create!(status: "pending")
        expect(project.reload).to be_running

        run.fail!("boom")
        expect(project.reload).to be_failed
        expect(run.reload.error_message).to eq("boom")
      end
    end
  end
end
