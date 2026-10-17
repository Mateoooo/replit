require "rails_helper"
require_relative "../support/zip_helper"
require_relative "../support/test_storage"

RSpec.describe "Проекты", type: :request do
  include ZipHelper

  let(:user)  { User.create!(email: "student@example.com", password: "secret123") }
  let(:other) { User.create!(email: "other@example.com", password: "secret123") }
  let(:headers)       { { "Authorization" => "Bearer #{JsonWebToken.access_for(user)}" } }
  let(:other_headers) { { "Authorization" => "Bearer #{JsonWebToken.access_for(other)}" } }
  let(:tmpdir) { Dir.mktmpdir("projects-spec") }

  before { ActiveJob::Base.queue_adapter = :test }
  after  { FileUtils.remove_entry(tmpdir) }

  def json
    JSON.parse(response.body)
  end

  def zip_upload(files = { "Gemfile" => "source 'https://rubygems.org'\n" })
    path = build_zip(File.join(tmpdir, "app.zip"), files)
    Rack::Test::UploadedFile.new(path, "application/zip")
  end

  def create_project(owner: user, name: "Blog API")
    owner.projects.create!(name: name, archive_path: "storage/x.zip")
  end

  describe "POST /projects (загрузка архива)" do
    context "с корректным архивом (happy path)" do
      it "создаёт проект и сохраняет архив на диск" do
        post "/projects", params: { name: "Blog API", archive: zip_upload }, headers: headers

        expect(response).to have_http_status(:created)
        expect(json["project"]["name"]).to eq("Blog API")
        expect(json["project"]["status"]).to eq("created")
        project = Project.last
        expect(project.archive_filename).to eq("app.zip")
        expect(File.exist?(project.archive_path)).to be(true)
      end
    end

    context "с неподходящим архивом" do
      it "отклоняет архив без Gemfile" do
        post "/projects", params: { name: "X", archive: zip_upload("README.md" => "hi") }, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json["errors"].join).to include("Gemfile")
        expect(Project.count).to eq(0)
      end

      it "отклоняет файл, который не является zip" do
        path = File.join(tmpdir, "fake.zip")
        File.write(path, "просто текст")

        post "/projects", params: { name: "X", archive: Rack::Test::UploadedFile.new(path, "application/zip") },
                          headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json["errors"].join).to include("не является корректным zip")
      end

      it "требует файл" do
        post "/projects", params: { name: "X" }, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json["errors"].join).to include("zip")
      end

      it "не позволяет создать проект с занятым названием" do
        create_project(name: "Blog API")

        post "/projects", params: { name: "blog api", archive: zip_upload }, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "без авторизации" do
      it "отвечает 401" do
        post "/projects", params: { name: "X", archive: zip_upload }

        expect(response).to have_http_status(:unauthorized)
        expect(Project.count).to eq(0)
      end
    end
  end

  describe "GET /projects" do
    context "когда у разных пользователей есть проекты" do
      it "показывает только проекты текущего пользователя" do
        create_project(name: "Мой")
        create_project(owner: other, name: "Чужой")

        get "/projects", headers: headers

        expect(response).to have_http_status(:ok)
        expect(json["projects"].map { |p| p["name"] }).to eq([ "Мой" ])
      end
    end
  end

  describe "доступ к чужому проекту" do
    let!(:project) { create_project }

    context "когда пользователь пытается управлять чужим проектом" do
      it "не показывает его (404)" do
        get "/projects/#{project.id}", headers: other_headers

        expect(response).to have_http_status(:not_found)
      end

      it "не даёт запустить (404) и не создаёт запуск" do
        post "/projects/#{project.id}/start", headers: other_headers

        expect(response).to have_http_status(:not_found)
        expect(Run.count).to eq(0)
      end

      it "не даёт остановить и посмотреть историю запусков" do
        post "/projects/#{project.id}/stop", headers: other_headers
        expect(response).to have_http_status(:not_found)

        get "/projects/#{project.id}/runs", headers: other_headers
        expect(response).to have_http_status(:not_found)
      end

      it "не даёт удалить (404), проект остаётся" do
        delete "/projects/#{project.id}", headers: other_headers

        expect(response).to have_http_status(:not_found)
        expect(Project.exists?(project.id)).to be(true)
      end
    end
  end

  describe "POST /projects/:id/start" do
    let!(:project) { create_project }

    context "когда проект не запущен (happy path)" do
      it "создаёт запуск, ставит задачу в очередь и обновляет статус проекта" do
        post "/projects/#{project.id}/start", headers: headers

        expect(response).to have_http_status(:accepted)
        expect(json["run"]["status"]).to eq("pending")
        expect(LaunchRunJob).to have_been_enqueued.with(json["run"]["id"])
        expect(project.reload).to be_running
      end
    end

    context "когда проект уже запущен" do
      it "отвечает 409 и не создаёт второй запуск" do
        post "/projects/#{project.id}/start", headers: headers
        post "/projects/#{project.id}/start", headers: headers

        expect(response).to have_http_status(:conflict)
        expect(json["error"]).to include("уже запущен")
        expect(project.runs.count).to eq(1)
      end
    end
  end

  describe "POST /projects/:id/stop" do
    let!(:project) { create_project }

    context "когда запуск идёт" do
      it "останавливает его, проект получает статус stopped" do
        post "/projects/#{project.id}/start", headers: headers

        post "/projects/#{project.id}/stop", headers: headers

        expect(response).to have_http_status(:ok)
        expect(json["run"]["status"]).to eq("stopped")
        expect(project.reload).to be_stopped
      end
    end

    context "когда проект не запущен" do
      it "отвечает 409" do
        post "/projects/#{project.id}/stop", headers: headers

        expect(response).to have_http_status(:conflict)
      end
    end
  end

  describe "GET /projects/:id/runs" do
    context "когда запусков несколько" do
      it "возвращает их от новых к старым" do
        project = create_project
        first = project.runs.create!(status: "pending")
        first.stop!
        second = project.runs.create!(status: "pending")

        get "/projects/#{project.id}/runs", headers: headers

        expect(json["runs"].map { |r| r["id"] }).to eq([ second.id, first.id ])
      end
    end
  end

  describe "DELETE /projects/:id" do
    context "когда владелец удаляет проект (happy path)" do
      it "удаляет запись и файл архива" do
        post "/projects", params: { name: "Blog API", archive: zip_upload }, headers: headers
        project = Project.last
        archive_path = project.archive_path

        delete "/projects/#{project.id}", headers: headers

        expect(response).to have_http_status(:ok)
        expect(Project.exists?(project.id)).to be(false)
        expect(File.exist?(archive_path)).to be(false)
      end
    end
  end
end
