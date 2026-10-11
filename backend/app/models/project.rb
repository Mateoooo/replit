class Project < ApplicationRecord
  # Виртуальный атрибут: загруженный zip (ActionDispatch::Http::UploadedFile)
  attr_accessor :archive_upload

  enum :status, { created: "created", running: "running", stopped: "stopped", failed: "failed" },
       default: "created"

  belongs_to :user
  has_many :runs, dependent: :destroy

  before_validation { self.name = name.to_s.strip }

  validates :name, presence: true,
                   length: { maximum: 100 },
                   uniqueness: { scope: :user_id, case_sensitive: false }
  validate :archive_must_be_present_and_valid, on: :create

  after_create  :store_archive, unless: -> { archive_upload.nil? }
  after_destroy :delete_archive

  def owned_by?(other_user)
    other_user.present? && user_id == other_user.id
  end

  def active_run
    runs.active.order(:id).first
  end

  # Для списков используем уже загруженные runs (без N+1)
  def last_run
    if runs.loaded?
      runs.max_by { |r| [r.created_at, r.id] }
    else
      runs.order(created_at: :desc, id: :desc).first
    end
  end

  def last_run_at
    run = last_run
    run && (run.started_at || run.created_at)
  end

  # Статус проекта выводится из последнего запуска
  def refresh_status!
    update_column(:status, derive_status)
  end

  def api_json
    {
      id: id,
      name: name,
      status: status,
      lastRunAt: last_run_at&.iso8601,
      createdAt: created_at.iso8601,
      archiveFilename: archive_filename,
      activeRunId: runs.loaded? ? runs.find(&:active?)&.id : active_run&.id
    }
  end

  private

  def derive_status
    run = runs.order(created_at: :desc, id: :desc).first
    return "created" unless run
    return "running" if run.active?

    run.failed? ? "failed" : "stopped"
  end

  def archive_must_be_present_and_valid
    if archive_upload.nil?
      errors.add(:base, "Загрузите zip-архив с проектом") if archive_path.blank?
    elsif (message = ProjectArchive.validate_upload(archive_upload))
      errors.add(:base, message)
    end
  end

  def store_archive
    ProjectArchive.new.store(self, archive_upload)
  end

  def delete_archive
    ProjectArchive.new.delete(self)
  end
end
