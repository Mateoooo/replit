class CommandsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_run

  def index
    commands = @run.command_executions.order(:id).last(100)
    render json: { commands: commands.map(&:api_json) }
  end

  def create
    execution = @run.command_executions.new(command: params[:command], user: current_user)

    if execution.save
      execution.execute!
      render json: { command: execution.api_json }, status: :created
    else
      render json: { errors: execution.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_run
    @run = current_user.runs.find(params[:run_id])
  end
end
