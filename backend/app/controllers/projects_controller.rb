class ProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: %i[show destroy start stop]

  def index
    projects = current_user.projects.includes(:runs).order(created_at: :desc)
    render json: { projects: projects.map(&:api_json) }
  end

  def show
    render json: { project: @project.api_json }
  end

  # POST /projects (multipart/form-data: name, archive)
  def create
    project = current_user.projects.new(name: params[:name], archive_upload: params[:archive])

    if project.save
      render json: { project: project.api_json }, status: :created
    else
      render json: { errors: project.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    begin
      launcher.stop(@project)
    rescue ProjectLauncher::NotRunning
      nil
    end
    @project.destroy!
    render json: { ok: true }
  end

  def start
    run = launcher.enqueue(@project)
    render json: { run: run.api_json }, status: :accepted
  rescue ProjectLauncher::AlreadyRunning => e
    render json: { error: e.message }, status: :conflict
  end

  def stop
    run = launcher.stop(@project)
    render json: { run: run.api_json }
  rescue ProjectLauncher::NotRunning => e
    render json: { error: e.message }, status: :conflict
  rescue DockerRunner::Error => e
    render json: { error: e.message }, status: :bad_gateway
  end

  private

  def set_project
    @project = current_user.projects.find(params[:id])
  end

  def launcher
    @launcher ||= ProjectLauncher.new
  end
end
