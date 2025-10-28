# frozen_string_literal: true

require 'singleton'
require 'eventmachine'
require 'websocket-eventmachine-client'
require 'thread'
require 'dotenv'
require 'date'
require 'json'
require 'logger'

Dotenv.load

module RubyWebsocketClient
  class BaseClient
    include Singleton

    private

    # METODOS QUE PODEM SER SOBRESCRITOS POR SUBCLASSES

    def handle_ping(msg, str_fetch: '"operation":"ping"')
      return unless msg.include?(str_fetch)

      log 'Enviando pong response'

      send_message(
        {
          receiver_id: ENV.fetch('WS_HOST_IDENTIFIER'),
          data: { operation: 'pong' }
        }.to_json
      )
    end

    def logger
      @logger ||= Logger.new($stdout)
    end

    def log(message, level: :info)
      return unless log?

      puts '*' * 100
      logger.send(level, "[#{self.class.name}][#{Time.now.strftime('%H:%M:%S')}]:\n#{message}\n")
    end

    def log!(message, level: :info)
      puts '*' * 100
      logger.send(level, "[#{self.class.name}][#{Time.now.strftime('%H:%M:%S')}]:\n#{message}\n")
    end

    def log?
      ENV.fetch('WS_LOG', 'false').downcase.eql?('true')
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

    def identifier
      raise NotImplementedError, "[#{self.class.name}] #{__method__} must implement this method"
    end

    def last_connected_at
      raise NotImplementedError, "[#{self.class.name}] #{__method__} must implement this method"
    end
  end
end
