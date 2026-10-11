class RunsController < ApplicationController
  before_action :authenticate_user!

  # GET /projects/:project_id/runs — таблица результатов запусков
  def index
    project = current_user.projects.find(params[:project_id])
    runs = project.runs.order(created_at: :desc, id: :desc).limit(100)
    render json: { runs: runs.map(&:api_json) }
  end

  # GET /runs/:id
  def show
    render json: { run: current_user.runs.find(params[:id]).api_json }
  end
end
