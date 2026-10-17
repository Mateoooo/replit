class Run < ApplicationRecord
  ACTIVE_STATUSES = %w[pending running].freeze

  enum :status, {
    pending:  "pending",
    running:  "running",
    finished: "finished",
    failed:   "failed",
    stopped:  "stopped"
  }, default: "pending"

  belongs_to :project
  has_many :log_entries, dependent: :delete_all
  has_many :command_executions, dependent: :destroy

  scope :active, -> { where(status: ACTIVE_STATUSES) }

  validate :single_active_run_per_project, on: :create

  after_create :sync_project_status
  after_update :sync_project_status, if: :saved_change_to_status?

  def active?
    ACTIVE_STATUSES.include?(status)
  end

  def start!(container_id:, image_tag: nil, host_port: nil)
    update!(status: "running", container_id: container_id,
            image_tag: image_tag || self.image_tag, host_port: host_port,
            started_at: Time.current)
  end

  def preview_url
    return nil unless host_port && running?

    "http://#{ENV.fetch('PREVIEW_HOST', 'localhost')}:#{host_port}"
  end

  def complete!(exit_code:)
    with_lock do
      return false unless active?

      update!(status: exit_code.to_i.zero? ? "finished" : "failed",
              exit_code: exit_code, finished_at: Time.current)
    end
    true
  end

  def fail!(message)
    with_lock do
      return false unless active?

      update!(status: "failed", error_message: message.to_s.truncate(5000), finished_at: Time.current)
    end
    true
  end

  def stop!
    with_lock do
      return false unless active?

      update!(status: "stopped", finished_at: Time.current)
    end
    true
  end

  def duration
    return nil unless started_at

    ((finished_at || Time.current) - started_at).to_f
  end

  def api_json
    {
      id: id,
      projectId: project_id,
      status: status,
      startedAt: started_at&.iso8601,
      finishedAt: finished_at&.iso8601,
      exitCode: exit_code,
      errorMessage: error_message,
      hostPort: host_port,
      previewUrl: preview_url,
      createdAt: created_at.iso8601
    }
  end

  private

  def single_active_run_per_project
    return unless project && active_status_for_validation?

    errors.add(:base, "У проекта уже есть активный запуск") if project.runs.active.exists?
  end

  def active_status_for_validation?
    ACTIVE_STATUSES.include?(status)
  end

  def sync_project_status
    project.refresh_status!
  end
end
