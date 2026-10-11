class LaunchRunJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(run_id)
    ProjectLauncher.new.perform(Run.find(run_id))
  end
end
