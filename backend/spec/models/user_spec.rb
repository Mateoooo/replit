require "rails_helper"
require_relative "../support/test_storage"

RSpec.describe User, type: :model do
  def build_user(attrs = {})
    described_class.new({ email: "student@example.com", password: "secret123" }.merge(attrs))
  end

  describe "регистрация" do
    context "с корректными данными (happy path)" do
      it "сохраняет пользователя и хранит хэш пароля, а не сам пароль" do
        user = build_user

        expect(user.save).to be(true)
        expect(user.password_digest).to be_present
        expect(user.password_digest).not_to include("secret123")
      end

      it "приводит email к нижнему регистру и убирает пробелы" do
        user = build_user(email: "  Student@Example.COM ")
        user.save!

        expect(user.email).to eq("student@example.com")
      end
    end

    context "с некорректными данными" do
      it "не принимает повторный email, даже в другом регистре" do
        build_user.save!
        duplicate = build_user(email: "STUDENT@example.com")

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:email]).to be_present
      end

      it "не принимает пароль короче 6 символов" do
        user = build_user(password: "12345")

        expect(user).not_to be_valid
        expect(user.errors[:password]).to be_present
      end

      it "не принимает пустой email и email неверного формата" do
        expect(build_user(email: "")).not_to be_valid
        expect(build_user(email: "not-an-email")).not_to be_valid
      end
    end
  end

  describe "#authenticate" do
    let!(:user) { build_user.tap(&:save!) }

    context "когда пароль верный" do
      it "возвращает пользователя" do
        expect(user.authenticate("secret123")).to eq(user)
      end
    end

    context "когда пароль неверный" do
      it "возвращает false" do
        expect(user.authenticate("wrong-password")).to be(false)
      end
    end
  end

  describe "связи" do
    context "при удалении пользователя" do
      it "удаляет его токены, проекты и запуски" do
        user = build_user.tap(&:save!)
        RefreshToken.issue_for(user)
        project = user.projects.create!(name: "Blog", archive_path: "x.zip")
        project.runs.create!(status: "pending")

        expect { user.destroy }
          .to change(RefreshToken, :count).by(-1)
          .and change(Project, :count).by(-1)
          .and change(Run, :count).by(-1)
      end
    end

    context "при обращении к запускам через пользователя" do
      it "возвращает запуски только его проектов" do
        user = build_user.tap(&:save!)
        other = build_user(email: "other@example.com").tap(&:save!)
        own_run = user.projects.create!(name: "A", archive_path: "x.zip").runs.create!(status: "pending")
        other.projects.create!(name: "B", archive_path: "x.zip").runs.create!(status: "pending")

        expect(user.runs).to contain_exactly(own_run)
      end
    end
  end
end
