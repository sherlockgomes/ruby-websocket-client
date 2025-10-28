# frozen_string_literal: true

require_relative '../lib/ruby_websocket_client/websocket_client'

class MonitorTest < RubyWebsocketClient::WebSocketClient
  private

  def url
    ENV.fetch('WS_URL')
  end

  def handle_message(msg)
    puts "#{identifier} - Mensagem recebida: #{msg.to_s.force_encoding('UTF-8')}"
  end

  def identifier
    'monitor'
  end

  def last_connected_at
    nil
  end
end
