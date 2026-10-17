class CommandExecution < ApplicationRecord
  MAX_COMMAND_LENGTH = 2000
  MAX_OUTPUT_LENGTH  = 100_000

  enum :status, {
    pending:   "pending",
    running:   "running",
    completed: "completed",
    failed:    "failed"
  }, default: "pending"

  belongs_to :run
  belongs_to :user

  validates :command, presence: true, length: { maximum: MAX_COMMAND_LENGTH }
  validate :run_must_be_running, on: :create

  # выполняет команду в контейнере запуска и сохраняет результат
  def execute!(runner: DockerRunner.new)
    update!(status: "running", started_at: Time.current)
    result = runner.exec(run.container_id, command)
    update!(
      output: result.output.to_s.truncate(MAX_OUTPUT_LENGTH, omission: "\n…вывод обрезан"),
      exit_code: result.exit_code,
      status: result.exit_code.to_i.zero? ? "completed" : "failed",
      finished_at: Time.current
    )
    self
  rescue DockerRunner::Error => e
    update!(status: "failed", output: e.message, finished_at: Time.current)
    self
  end

  def api_json
    {
      id: id, runId: run_id, command: command, output: output, exitCode: exit_code,
      status: status, startedAt: started_at&.iso8601, finishedAt: finished_at&.iso8601,
      createdAt: created_at.iso8601
    }
  end

  private

  def run_must_be_running
    errors.add(:base, "Проект не запущен — команду выполнить нельзя") unless run&.running?
  end
end
