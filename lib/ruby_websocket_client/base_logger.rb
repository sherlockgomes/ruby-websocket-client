# frozen_string_literal: true

require 'logger'

module RubyWebsocketClient
  module BaseLogger
    # METODOS QUE PODEM SER SOBRESCRITOS POR SUBCLASSES

    private

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
  end
end
