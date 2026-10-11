# Подписка: { channel: "RunLogsChannel", run_id: 5 }
class RunLogsChannel < ApplicationCable::Channel
  def subscribed
    run = current_user.runs.find_by(id: params[:run_id])
    return reject unless run

    stream_from LogEntry.channel_for(run.id)
  end
end
