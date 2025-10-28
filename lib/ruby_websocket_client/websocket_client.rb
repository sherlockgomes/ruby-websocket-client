# frozen_string_literal: true

require_relative 'base_client'
require_relative 'base_constants'

module RubyWebsocketClient
  class WebSocketClient < BaseClient
    include BaseConstants

    attr_reader :connected, :queue_size

    def initialize
      @retry_count = 0
      @connected = false
      @send_queue = SizedQueue.new(MAX_QUEUE_SIZE)
      @send_thread = nil
      @event_thread = nil
      @health_thread = nil
      @mutex = Mutex.new
      @queue_size = 0
      @started = false
      @stopping = false
      @max_retries_reached = false
      @last_message_at = nil
      @connection_timeout = nil
    end

    # Inicia o cliente WebSocket em uma thread separada
    def start
      @mutex.synchronize do
        return if @started

        @started = true
        @stopping = false
        @max_retries_reached = false

        @event_thread = Thread.new { run_event_loop } # Loop principal do EventMachine
        @send_thread = Thread.new { process_send_queue } # Thread dedicada a enviar mensagens de forma assíncrona
        @health_thread = Thread.new { health_check_loop } # Loop de verificação de health check

        log "Cliente WebSocket iniciado com threads: event=#{@event_thread.object_id}, send=#{@send_thread.object_id}"
      end
    end

    # Enfileira mensagem para envio com controle de limite
    def send_message(message)
      return unless message

      @send_queue.push(message, true)
    rescue StandardError => e
      log! "Erro ao enfileirar mensagem: #{e.message}", level: :error
      handle_queue_overflow(message)
    end

    # Fecha conexão e encerra threads com segurança
    def stop
      @mutex.synchronize do
        return if @stopping

        @stopping = true
        @started = false
        @connected = false

        log 'Iniciando parada do cliente...'

        @send_queue << :stop_signal
      end

      EM.stop_event_loop if EM.reactor_running? && !@connected

      disconnect! unless @connected

      wait_for_threads_completion

      clear_queue

      log 'Cliente parado com sucesso'
    end

    # Verifica se o cliente está rodando (vale após o start)
    def running?
      @started && !@stopping
    end

    # Retorna status para monitoramento
    def status
      @mutex.synchronize do
        {
          connected: @connected,
          started: @started,
          stopping: @stopping,
          retry_count: @retry_count,
          max_retries_reached: @max_retries_reached,
          queue_size: @send_queue.size,
          event_thread_alive: @event_thread&.alive? || false,
          send_thread_alive: @send_thread&.alive? || false
        }
      end
    end

    private

    # Aguarda finalização das threads com timeout
    def wait_for_threads_completion(timeout = MAX_THREAD_WAIT_TIME)
      threads_to_wait = [@event_thread, @send_thread, @health_thread].compact

      return if threads_to_wait.empty?

      log "Aguardando finalização de #{threads_to_wait.size} threads..."

      threads_to_wait.each do |thread|
        begin
          if thread.alive?
            thread.join(timeout)
            if thread.alive?
              log "Thread #{thread.object_id} não finalizou em #{timeout}s, forçando interrupção", level: :warn
              thread.kill
              thread.join(1)
            else
              log "Thread #{thread.object_id} finalizada com sucesso"
            end
          end
        rescue StandardError => e
          log! "Erro ao aguardar thread #{thread.object_id}: #{e.message}"
        end
      end

      @event_thread = nil
      @send_thread = nil
      @health_thread = nil
      log 'Todas as threads foram finalizadas'
    end

    # Loop principal do EventMachine
    def run_event_loop
      begin
        if EM.reactor_running?
          EM.schedule { connect }
        else
          EM.run { connect }
        end
      rescue StandardError => e
        log "Erro no loop principal: #{e.message}", level: :error
        retry_with_backoff unless @stopping
      ensure
        log 'EventMachine loop finalizado'
      end
    end

    # Fecha conexão WebSocket e limpa recursos
    def disconnect!
      return unless @ws

      begin
        if EM.reactor_running?
          EM.schedule { @ws.close_connection rescue nil }
        else
          @ws.close_connection rescue nil
        end
      ensure
        @ws = nil
      end
    end

    # Conecta e define callbacks do EventMachine
    def connect
      return if @stopping

      log "Abrindo conexão com #{url} pelo identifier #{identifier}"

      @connection_timeout&.cancel
      @connection_timeout = EM::Timer.new(TIMEOUT_CONNECTION) do
        log 'Timeout na conexão após 30s', level: :error
        disconnect!
        retry_with_backoff unless @stopping
      end

      @ws = WebSocket::EventMachine::Client.connect(
        uri: url,
        headers: headers
      )

      @ws.onopen do
        log 'Fechando timeout de conexão.'
        cancel_connection_timeout!

        @mutex.synchronize do
          @connected = true
          @retry_count = 0
          @max_retries_reached = false
        end
        log 'Conexão WebSocket estabelecida.'
      rescue StandardError => e
        log "Erro crítico no callback onopen: #{e.message}", level: :error
        log "Backtrace: #{e.backtrace.first(5).join("\n")}", level: :error

        reset_connection_status!
        cancel_connection_timeout!
        @mutex.synchronize { @connected = false } rescue nil # Evita race condition

        retry_with_backoff unless @stopping
      end

      @ws.onmessage do |msg, _type|
        @last_message_at = Time.now

        begin
          handle_ping(msg)
        rescue StandardError => e
          log! "Erro ao processar ping: Backtrace: #{e.backtrace.first(5).join("\n")}", level: :error
        end

        begin
          EM.defer do
            handle_message(msg)
          end
        rescue StandardError => e
          log! "Erro ao processar mensagem: Backtrace: #{e.backtrace.first(5).join("\n")}", level: :error
        end
      end

      @ws.onclose do |code, reason|
        cancel_connection_timeout!
        @mutex.synchronize { @connected = false }
        log "A conexão foi encerrada. Código: (#{code}) - Motivo: #{reason}", level: :error
        retry_with_backoff unless @stopping
      end

      @ws.onerror do |e|
        cancel_connection_timeout!
        @mutex.synchronize { @connected = false }
        log "Ocorreu um erro na conexão. Erro: #{e}", level: :error
        retry_with_backoff unless @stopping
      end
    end

    # Cancela o timeout de conexão ativo
    def cancel_connection_timeout!
      @connection_timeout&.cancel
      @connection_timeout = nil
    rescue StandardError => e
      log "Erro ao cancelar timeout de conexão: #{e.message}", level: :error
      reset_connection_status! unless @stopping
    end

    # Reseta o status da conexão
    def reset_connection_status!
      @mutex.synchronize do
        @connected = false
        @retry_count = 0
        @max_retries_reached = false
      end
    end

    def can_send_message?
      @connected && @ws && !@stopping
    end

    # Thread dedicada a enviar mensagens de forma assíncrona
    def process_send_queue
      loop do
        break if @stopping

        begin
          # Usar pop com timeout e capturar ThreadError
          msg = @send_queue.pop(1) # timeout de 1 segundo
          break if msg == :stop_signal || @stopping

          if can_send_message?
            @ws.send(msg)
          elsif !@stopping
            log 'Fila pausada — sem conexão ativa.'
            sleep 1
            @send_queue.push(msg, true)
          end
        rescue ThreadError => e
          # ThreadError ocorre quando a fila está vazia, mesmo com timeout
          if e.message.include?('queue empty')
            # Fila vazia - continuar o loop normalmente
            sleep 0.1
          else
            log "Erro de thread ao processar fila: #{e.message}", level: :error unless @stopping
          end
        rescue StandardError => e
          log "Erro ao enviar mensagem: #{e.message}", level: :error unless @stopping
        end
      end

      log 'Thread de envio finalizada'
    end

    # Loop de verificação de health check
    def health_check_loop
      loop do
        break if @stopping

        sleep HEALTH_CHECK_INTERVAL

        begin
          connected, queue_size, last_msg = @mutex.synchronize do
            [@connected, @queue_size, @last_message_at]
          end

          if connected && queue_size > MAX_QUEUE_SIZE * 0.9
            log! "ALERTA: Fila crítica #{queue_size}/#{MAX_QUEUE_SIZE}", level: :error
          end

          if connected && last_msg && (Time.now - last_msg) > HEALTH_CHECK_INTERVAL
            log! "ALERTA: Sem mensagens há #{HEALTH_CHECK_INTERVAL} segundos", level: :warn
          end

          log! status.to_json
        rescue StandardError => e
          log! "Erro no health check: #{e.message}", level: :error
        end
      end
    end

    # Trata overflow da fila de mensagens
    def handle_queue_overflow(message)
      case QUEUE_OVERFLOW_STRATEGY
      when :drop_oldest
        begin
          # Tentar remover a mensagem mais antiga com timeout
          @send_queue.pop(0.1) # timeout de 100ms
          @send_queue.push(message, true)
          log 'Fila cheia: mensagem antiga descartada, nova adicionada', level: :warn
        rescue ThreadError => e
          # ThreadError ocorre quando a fila está vazia, mesmo com timeout
          if e.message.include?('queue empty')
            # Fila estava vazia, tentar adicionar a nova mensagem
            begin
              @send_queue.push(message, true)
              log 'Fila estava vazia, nova mensagem adicionada', level: :info
            rescue ThreadError
              log 'Fila ainda cheia após tentativa de drop_oldest', level: :warn
            end
          else
            log "Erro inesperado ao tentar drop_oldest: #{e.message}", level: :error
          end
        end
      when :drop_newest
        log 'Fila cheia: nova mensagem descartada', level: :warn
      else
        log "Estratégia de overflow desconhecida: #{QUEUE_OVERFLOW_STRATEGY}", level: :error
      end
    end

    # Reconexão com backoff exponencial e limite
    def retry_with_backoff
      return if @stopping

      if @retry_count >= DEFAULT_RETRY_LIMIT
        log "Limite de reconexões atingido (#{DEFAULT_RETRY_LIMIT} tentativas). Parando cliente.", level: :error
        handle_max_retries_reached
        return
      end

      delay = [DEFAULT_RETRY_DELAY * (2**@retry_count), MAX_RETRY_DELAY].min
      @retry_count += 1

      log "Tentando reconexão em #{delay}s (tentativa #{@retry_count}/#{DEFAULT_RETRY_LIMIT})", level: :warn

      delay.times do
        break if @stopping

        sleep 1
      end

      connect unless @stopping
    end

    # Chamado quando limite de reconexões é atingido
    def handle_max_retries_reached
      @mutex.synchronize do
        @connected = false
        @max_retries_reached = true
      end

      log '=' * 60, level: :error
      log 'CLIENTE WEBSOCKET PARADO - LIMITE DE RECONEXÕES ATINGIDO', level: :error
      log "Tentativas: #{DEFAULT_RETRY_LIMIT} | URL: #{url} | ID: #{identifier}", level: :error
      log '=' * 60, level: :error

      # Hook para notificações externas (Slack, email, PagerDuty, etc)
      notify_max_retries_reached if respond_to?(:notify_max_retries_reached, true)
    end

    # Limpa fila após threads finalizarem
    def clear_queue
      cleared_count = 0
      begin
        # Usar pop com timeout e capturar ThreadError
        while true
          msg = @send_queue.pop(0.1) # timeout de 100ms
          cleared_count += 1 unless msg == :stop_signal
        end
      rescue ThreadError => e
        # ThreadError ocorre quando a fila está vazia, mesmo com timeout
        if e.message.include?('queue empty')
          # Fila vazia - isso é normal durante a limpeza
          log 'Fila já estava vazia durante limpeza', level: :info
        else
          log "Erro de thread ao limpar fila: #{e.message}", level: :warn
        end
      rescue StandardError => e
        log "Erro ao limpar fila: #{e.message}", level: :warn
      end
      log "Fila limpa: #{cleared_count} mensagens descartadas" if cleared_count.positive?
    end
  end
end
