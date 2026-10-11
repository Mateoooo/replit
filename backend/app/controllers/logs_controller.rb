# Вариант 1: polling.
# GET /runs/:run_id/logs?after_id=123   — «всё, что новее id» (надёжнее)
# GET /runs/:run_id/logs?since=<ISO8601 с микросекундами> — «всё, что новее timestamp»
class LogsController < ApplicationController
  before_action :authenticate_user!

  LIMIT = 500

  def index
    run = current_user.runs.find(params[:run_id])
    logs = run.log_entries.chronological

    if params[:after_id].present?
      logs = logs.after_id(params[:after_id].to_i)
    elsif params[:since].present?
      since = parse_time(params[:since])
      return render json: { error: "Некорректный параметр since" }, status: :unprocessable_entity unless since

      logs = logs.after_time(since)
    end

    logs = logs.limit(LIMIT).to_a
    render json: {
      logs: logs.map(&:api_json),
      lastId: logs.last&.id,
      lastTimestamp: logs.last&.logged_at&.iso8601(6),
      runStatus: run.status
    }
  end

  private

  def parse_time(value)
    Time.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end
end
