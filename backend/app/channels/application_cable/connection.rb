module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    # ws://host/cable?token=<accessToken> (браузерный WebSocket не умеет заголовки)
    def connect
      self.current_user = find_user || reject_unauthorized_connection
    end

    private

    def find_user
      payload = JsonWebToken.decode(request.params[:token])
      return nil unless payload && payload[:type] == "access"

      User.find_by(id: payload[:user_id])
    end
  end
end
