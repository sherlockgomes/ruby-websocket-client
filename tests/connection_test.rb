# frozen_string_literal: true

require_relative '../lib/ruby_websocket_client/websocket_client'

class ConnectionTest < RubyWebsocketClient::WebSocketClient
  private

  def url
    ENV.fetch('WS_URL')
  end

  def handle_message(msg)
    puts "Mensagem recebida: #{msg.to_s.force_encoding('UTF-8')}"
  end

  def last_connected_at
    Date.new(Date.today.year, Date.today.month, Date.today.day - 1).strftime('%Y-%m-%d')
  end

  def identifier
    ENV.fetch('WS_IDENTIFIER')
  end
end
