# frozen_string_literal: true

require 'yaml'
require 'erb'
require 'pathname'

module RubyWebsocketClient
  module BaseConstants
    TIMEOUT_CONNECTION = 30 # Tempo de timeout para a conexão em segundos
    DEFAULT_RETRY_LIMIT = 1000 # Limite de tentativas de reconexão antes de parar o cliente
    DEFAULT_RETRY_DELAY = 5 # Tempo de espera entre tentativas em segundos de reconexão
    MAX_RETRY_DELAY = 15 # Tempo máximo para aguardar a próxima tentativa de reconexão
    MAX_QUEUE_SIZE = 15_000 # Importante se vier um grande volume de mensagens simultâneas, como em caso de sync
    QUEUE_OVERFLOW_STRATEGY = :drop_oldest # Remover a mensagem mais antiga da fila se a fila estiver cheia
    MAX_THREAD_WAIT_TIME = 10 # Tempo máximo para aguardar threads finalizarem
    THREAD_CLEANUP_INTERVAL = 30 # Intervalo para limpar threads
    HEALTH_CHECK_INTERVAL = 300 # Intervalo para fazer o health check da conexão
  end
end
