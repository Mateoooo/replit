require "rails_helper"
require_relative "../support/test_storage"

RSpec.describe LogEntry, type: :model do
  let(:user)    { User.create!(email: "student@example.com", password: "secret123") }
  let(:project) { user.projects.create!(name: "Blog API", archive_path: "storage/x.zip") }
  let(:run)     { project.runs.create!(status: "pending") }

  describe "создание строки лога" do
    context "с минимальными данными (happy path)" do
      it "подставляет stream=stdout и текущее время" do
        entry = run.log_entries.create!(content: "Hello")

        expect(entry.stream).to eq("stdout")
        expect(entry.logged_at).to be_present
      end

      it "допускает пустую строку (в логах бывают пустые строки)" do
        entry = run.log_entries.create!(content: nil)

        expect(entry.content).to eq("")
      end
    end

    context "с неизвестным потоком" do
      it "не сохраняется" do
        entry = run.log_entries.new(content: "x", stream: "weird")

        expect(entry).not_to be_valid
        expect(entry.errors[:stream]).to be_present
      end
    end
  end

  describe "области выборки" do
    let!(:first)  { run.log_entries.create!(content: "1", logged_at: 3.minutes.ago) }
    let!(:second) { run.log_entries.create!(content: "2", logged_at: 2.minutes.ago) }
    let!(:third)  { run.log_entries.create!(content: "3", logged_at: 1.minute.ago) }

    context "after_id" do
      it "возвращает только строки новее указанной" do
        expect(run.log_entries.after_id(first.id)).to contain_exactly(second, third)
        expect(run.log_entries.after_id(third.id)).to be_empty
      end
    end

    context "chronological" do
      it "сортирует по времени, а не по порядку вставки" do
        older = run.log_entries.create!(content: "старая", logged_at: 10.minutes.ago)

        expect(run.log_entries.chronological.first).to eq(older)
        expect(run.log_entries.chronological.last).to eq(third)
      end
    end

    context "after_time" do
      it "возвращает строки новее момента времени" do
        expect(run.log_entries.after_time(90.seconds.ago)).to contain_exactly(third)
      end
    end
  end

  describe "рассылка подписчикам WebSocket" do
    context "когда создаётся новая строка" do
      it "отправляет её в поток запуска" do
        allow(ActionCable.server).to receive(:broadcast)

        run.log_entries.create!(content: "Hello")

        expect(ActionCable.server).to have_received(:broadcast)
          .with("run_logs_#{run.id}", hash_including(content: "Hello"))
      end
    end

    context "когда рассылка падает" do
      it "строка всё равно сохраняется" do
        allow(ActionCable.server).to receive(:broadcast).and_raise(StandardError, "cable down")

        expect { run.log_entries.create!(content: "Hello") }.to change(described_class, :count).by(1)
      end
    end
  end
end
