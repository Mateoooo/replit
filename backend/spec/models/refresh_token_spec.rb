require "rails_helper"

RSpec.describe RefreshToken do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { User.create!(email: "student@example.com", password: "secret123") }

  describe ".issue_for" do
    context "при выдаче нового токена" do
      it "ограничивает время жизни 30 днями" do
        freeze_time do
          record, _raw = described_class.issue_for(user)
          expect(record.expires_at).to eq(30.days.from_now)
        end
      end

      it "хранит в БД только хэш, а не сам токен" do
        record, raw = described_class.issue_for(user)
        expect(record.token_digest).to eq(described_class.digest(raw))
        expect(record.token_digest).not_to include(raw)
      end
    end

    context "когда у пользователя есть устаревшие токены" do
      it "удаляет просроченные и отозванные" do
        user.refresh_tokens.create!(token_digest: "old1", expires_at: 1.day.ago)
        user.refresh_tokens.create!(token_digest: "old2", expires_at: 1.day.from_now, revoked_at: Time.current)

        described_class.issue_for(user)

        expect(user.refresh_tokens.pluck(:token_digest)).not_to include("old1", "old2")
        expect(user.refresh_tokens.count).to eq(1)
      end
    end
  end

  describe ".find_active_by_raw" do
    let!(:issued) { described_class.issue_for(user) }
    let(:record) { issued.first }
    let(:raw)    { issued.last }

    context "пока токен действителен" do
      it "находит токен" do
        expect(described_class.find_active_by_raw(raw)).to eq(record)
      end
    end

    context "после истечения 30 дней" do
      it "не находит токен" do
        travel_to(31.days.from_now) do
          expect(described_class.find_active_by_raw(raw)).to be_nil
        end
      end
    end

    context "для отозванного, неизвестного или пустого токена" do
      it "возвращает nil" do
        record.revoke!
        expect(described_class.find_active_by_raw(raw)).to be_nil
        expect(described_class.find_active_by_raw("unknown")).to be_nil
        expect(described_class.find_active_by_raw(nil)).to be_nil
      end
    end
  end

  describe ".revoke_by_raw" do
    context "когда токен уже просрочен" do
      it "всё равно отзывает его (logout не ломается)" do
        record, raw = described_class.issue_for(user)
        travel_to(31.days.from_now) do
          expect(described_class.revoke_by_raw(raw)).to be(true)
          expect(record.reload).to be_revoked
        end
      end
    end

    context "когда токена нет" do
      it "возвращает false" do
        expect(described_class.revoke_by_raw("nope")).to be(false)
      end
    end
  end
end
