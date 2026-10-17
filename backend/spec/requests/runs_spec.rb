require "rails_helper"
require_relative "../support/test_storage"

RSpec.describe "Запуски, логи и консоль", type: :request do
  let(:user)  { User.create!(email: "student@example.com", password: "secret123") }
  let(:other) { User.create!(email: "other@example.com", password: "secret123") }
  let(:headers)       { { "Authorization" => "Bearer #{JsonWebToken.access_for(user)}" } }
  let(:other_headers) { { "Authorization" => "Bearer #{JsonWebToken.access_for(other)}" } }
  let(:project) { user.projects.create!(name: "Blog API", archive_path: "storage/x.zip") }
  let(:run) do
    project.runs.create!(status: "pending").tap { |r| r.start!(container_id: "abc123", host_port: 49_153) }
  end

  def json
    JSON.parse(response.body)
  end

  describe "GET /runs/:id" do
    context "для своего запуска (happy path)" do
      it "возвращает статус и адрес предпросмотра" do
        get "/runs/#{run.id}", headers: headers

        expect(response).to have_http_status(:ok)
        expect(json["run"]["status"]).to eq("running")
        expect(json["run"]["previewUrl"]).to end_with(":49153")
      end
    end

    context "для чужого запуска" do
      it "отвечает 404" do
        get "/runs/#{run.id}", headers: other_headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /runs/:id/logs" do
    let!(:logs) do
      [ 1, 2, 3 ].map { |i| run.log_entries.create!(content: "line #{i}", logged_at: (4 - i).minutes.ago) }
    end

    context "при первом запросе (happy path)" do
      it "отдаёт все строки по порядку и курсор lastId" do
        get "/runs/#{run.id}/logs?after_id=0", headers: headers

        expect(response).to have_http_status(:ok)
        expect(json["logs"].map { |l| l["content"] }).to eq([ "line 1", "line 2", "line 3" ])
        expect(json["lastId"]).to eq(logs.last.id)
        expect(json["runStatus"]).to eq("running")
      end
    end

    context "при опросе по курсору" do
      it "after_id возвращает только новое" do
        get "/runs/#{run.id}/logs?after_id=#{logs[1].id}", headers: headers

        expect(json["logs"].map { |l| l["content"] }).to eq([ "line 3" ])
      end

      it "когда нечего возвращать — пустой список без ошибки" do
        get "/runs/#{run.id}/logs?after_id=#{logs.last.id}", headers: headers

        expect(json["logs"]).to eq([])
        expect(json["lastId"]).to be_nil
      end

      it "since принимает время в формате ISO8601" do
        since = 90.seconds.ago.iso8601(6)

        get "/runs/#{run.id}/logs?since=#{CGI.escape(since)}", headers: headers

        expect(json["logs"].map { |l| l["content"] }).to eq([ "line 3" ])
      end

      it "since с мусором даёт 422" do
        get "/runs/#{run.id}/logs?since=garbage", headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "отдаёт не больше LIMIT строк за раз" do
        stub_const("LogsController::LIMIT", 2)

        get "/runs/#{run.id}/logs?after_id=0", headers: headers

        expect(json["logs"].size).to eq(2)
        expect(json["lastId"]).to eq(logs[1].id)
      end
    end

    context "без прав" do
      it "чужой запуск даёт 404" do
        get "/runs/#{run.id}/logs", headers: other_headers

        expect(response).to have_http_status(:not_found)
      end

      it "без токена даёт 401" do
        get "/runs/#{run.id}/logs"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /runs/:id/commands" do
    context "когда команда выполнилась успешно (happy path)" do
      it "возвращает вывод и сохраняет команду в историю" do
        allow_any_instance_of(DockerRunner).to receive(:exec).with("abc123", "ls")
                                                             .and_return(DockerRunner::Result.new("Gemfile\n", 0))

        post "/runs/#{run.id}/commands", params: { command: "ls" }, headers: headers, as: :json

        expect(response).to have_http_status(:created)
        expect(json["command"]["status"]).to eq("completed")
        expect(json["command"]["output"]).to eq("Gemfile\n")

        get "/runs/#{run.id}/commands", headers: headers
        expect(json["commands"].map { |c| c["command"] }).to eq([ "ls" ])
      end
    end

    context "когда команда завершилась с ошибкой" do
      it "запрос успешен, но команда помечена failed с кодом выхода" do
        allow_any_instance_of(DockerRunner).to receive(:exec)
          .and_return(DockerRunner::Result.new("sh: foo: not found", 127))

        post "/runs/#{run.id}/commands", params: { command: "foo" }, headers: headers, as: :json

        expect(response).to have_http_status(:created)
        expect(json["command"]["status"]).to eq("failed")
        expect(json["command"]["exitCode"]).to eq(127)
      end

      it "при таймауте Docker сообщение об ошибке попадает в вывод" do
        allow_any_instance_of(DockerRunner).to receive(:exec).and_raise(DockerRunner::Error, "таймаут")

        post "/runs/#{run.id}/commands", params: { command: "sleep 100" }, headers: headers, as: :json

        expect(json["command"]["status"]).to eq("failed")
        expect(json["command"]["output"]).to eq("таймаут")
      end
    end

    context "когда команду выполнить нельзя" do
      it "для остановленного запуска отвечает 422 и не обращается к Docker" do
        run.stop!
        expect_any_instance_of(DockerRunner).not_to receive(:exec)

        post "/runs/#{run.id}/commands", params: { command: "ls" }, headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json["errors"].join).to include("не запущен")
      end

      it "пустая команда даёт 422" do
        post "/runs/#{run.id}/commands", params: { command: "  " }, headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "в чужом запуске команду выполнить нельзя (404)" do
        expect_any_instance_of(DockerRunner).not_to receive(:exec)

        post "/runs/#{run.id}/commands", params: { command: "ls" }, headers: other_headers, as: :json

        expect(response).to have_http_status(:not_found)
        expect(CommandExecution.count).to eq(0)
      end
    end
  end
end
