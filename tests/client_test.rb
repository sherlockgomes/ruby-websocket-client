require_relative '../websocket_client'

class ClientTest < WebSocketClient
  def start
    super
  end

  private

  def url
    ENV.fetch('HERMES_WS_URL')
  end

  def handle_message(msg)
    puts "Mensagem recebida: #{msg.to_s.force_encoding('UTF-8')}"
  end

  def last_connected_at
    Date.new(Date.today.year, Date.today.month, Date.today.day - 1).strftime('%Y-%m-%d')
  end

  def identifier
    ENV.fetch('HERMES_WS_IDENTIFIER')
  end
end
