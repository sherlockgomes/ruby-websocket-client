# frozen_string_literal: true

require 'singleton'
require 'eventmachine'
require 'websocket-eventmachine-client'
require 'thread'
require 'dotenv'
require 'date'
require 'json'

require_relative 'base_logger'

Dotenv.load

module RubyWebsocketClient
  class BaseClient
    include Singleton
    include BaseLogger

    private

    # METODOS QUE PODEM SER SOBRESCRITOS POR SUBCLASSES

    def handle_ping(msg, str_fetch: '"operation":"ping"')
      return unless msg.include?(str_fetch)

      log 'Enviando pong response'

      pong!
    end

    def pong!
      receivers = []

      receivers << {
        receiver_id: ws_host_identifier,
        data: { operation: 'pong' }
      }

      unless ws_monitor_identifier.empty?
        receivers << {
          receiver_id: ws_monitor_identifier,
          data: {
            status: status,
            config: {
              tipo_operacao: 'monitor',
              gpa_code: identifier
            }
          }
        }
      end

      receivers.each do |receiver|
        send_message(
          {
            receiver_id: receiver[:receiver_id],
            data: receiver[:data]
          }.to_json
        )
      end
    end

    def headers
      {
        'identifier' => identifier,
        'last-connected-at' => last_connected_at
      }
    end

    # METODOS QUE 'DEVEM' SER IMPLEMENTADOS POR SUBCLASSES

    def url
      raise NotImplementedError, "[#{self.class.name}] #{__method__} must implement this method"
    end

    def handle_message(msg)
      raise NotImplementedError, "[#{self.class.name}] #{__method__} must implement this method"
    end

    def ws_host_identifier
      ENV.fetch('WS_HOST_IDENTIFIER')
    end

    def ws_monitor_identifier
      ENV.fetch('WS_MONITOR_IDENTIFIER', 'monitor')
    end

    def identifier
      raise NotImplementedError, "[#{self.class.name}] #{__method__} must implement this method"
    end

    def last_connected_at
      raise NotImplementedError, "[#{self.class.name}] #{__method__} must implement this method"
    end
  end
end
