class LogEntry < ApplicationRecord
  STREAMS = %w[stdout stderr system].freeze

  belongs_to :run

  before_validation do
    self.content = content.to_s
    self.logged_at ||= Time.current
  end

  validates :stream, inclusion: { in: STREAMS }
  validates :logged_at, presence: true

  scope :chronological, -> { order(:logged_at, :id) }
  scope :after_id,   ->(id)   { where("log_entries.id > ?", id) }
  scope :after_time, ->(time) { where("log_entries.logged_at > ?", time) }

  # Вариант 2 (WebSocket): сервер сам пушит новые строки подписчикам
  after_create_commit :broadcast_to_subscribers

  def self.channel_for(run_id)
    "run_logs_#{run_id}"
  end

  def api_json
    { id: id, runId: run_id, stream: stream, content: content, loggedAt: logged_at.iso8601(6) }
  end

  private

  def broadcast_to_subscribers
    ActionCable.server.broadcast(self.class.channel_for(run_id), api_json)
  rescue StandardError => e
    Rails.logger.warn("LogEntry broadcast failed: #{e.message}")
  end
end
