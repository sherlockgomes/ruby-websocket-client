# Design Técnico - Ruby WebSocket Client

## 🏗 Arquitetura do Sistema

### Visão Geral

O Ruby WebSocket Client:

- **Confiabilidade**: Sistema resiliente a falhas de rede e servidor
- **Performance**: Processamento assíncrono e otimizado
- **Escalabilidade**: Suporte a alta carga de mensagens
- **Manutenibilidade**: Código limpo e bem estruturado
- **Observabilidade**: Logging e monitoramento abrangentes

### Diagrama de Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                    WebSocket Client                         │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ Event Thread│  │ Send Thread │  │Health Thread│        │
│  │             │  │             │  │             │        │
│  │ • EventMachine│  │ • Queue     │  │ • Monitoring│        │
│  │ • WebSocket │  │ • Async Send│  │ • Alerts    │        │
│  │ • Callbacks │  │ • Overflow  │  │ • Metrics   │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Mutex     │  │   Queue     │  │  Retry      │        │
│  │             │  │             │  │  Manager    │        │
│  │ • Thread    │  │ • Messages  │  │ • Backoff   │        │
│  │   Safety    │  │ • Overflow  │  │ • Limits    │        │
│  │ • State     │  │ • Strategy  │  │ • Recovery  │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                 WebSocket Server                            │
└─────────────────────────────────────────────────────────────┘
```

## 🧵 Gerenciamento de Threads

### Thread Principal (Event Thread)

```ruby
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
    log "EventMachine loop finalizado"
  end
end
```

**Responsabilidades:**
- Execução do EventMachine reactor
- Gerenciamento de callbacks WebSocket
- Tratamento de eventos de conexão/desconexão
- Coordenação de reconexões

**Justificativa Técnica:**
- **EventMachine**: Framework maduro e estável para I/O assíncrono
- **Reactor Pattern**: Eficiente para gerenciar múltiplas conexões
- **Isolamento**: Thread dedicada evita bloqueio da aplicação principal

### Thread de Envio (Send Thread)

```ruby
def process_send_queue
  loop do
    break if @stopping
    
    begin
      msg = @send_queue.pop(true)
      break if msg == :stop_signal || @stopping
      
      @mutex.synchronize { @queue_size -= 1 }
      
      if @connected && @ws && !@stopping
        @ws.send(msg)
      elsif !@stopping
        # Recolocar na fila se não conectado
        @mutex.synchronize do
          unless @stopping
            @send_queue << msg
            @queue_size += 1
          end
        end
      end
    rescue StandardError => e
      log "Erro ao enviar mensagem: #{e.message}", level: :error unless @stopping
    end
  end
end
```

**Responsabilidades:**
- Processamento assíncrono da fila de mensagens
- Envio não-bloqueante de mensagens
- Gerenciamento de overflow da fila
- Recuperação de mensagens durante desconexões

**Justificativa Técnica:**
- **Desacoplamento**: Envio não bloqueia operações de recebimento
- **Resilência**: Mensagens são preservadas durante falhas
- **Performance**: Processamento em lote otimiza I/O

### Thread de Health Check

```ruby
def health_check_loop
  loop do
    break if @stopping
    sleep HEALTH_CHECK_INTERVAL
    
    begin
      connected, queue_size, last_msg = @mutex.synchronize do
        [@connected, @queue_size, @last_message_at]
      end
      
      if connected && queue_size > MAX_QUEUE_SIZE * 0.9
        log "ALERTA: Fila crítica #{queue_size}/#{MAX_QUEUE_SIZE}", level: :error
      end
      
      if connected && last_msg && (Time.now - last_msg) > HEALTH_CHECK_INTERVAL
        log "ALERTA: Sem mensagens há #{HEALTH_CHECK_INTERVAL} segundos", level: :warn
      end
    rescue StandardError => e
      log "Erro no health check: #{e.message}", level: :error
    end
  end
end
```

**Responsabilidades:**
- Monitoramento contínuo da saúde da conexão
- Detecção de conexões "mortas"
- Alertas de performance
- Métricas de qualidade de serviço

**Justificativa Técnica:**
- **Proatividade**: Detecta problemas antes que afetem usuários
- **Observabilidade**: Fornece métricas para monitoramento
- **Prevenção**: Evita acúmulo de problemas não detectados

## 🔒 Thread Safety e Sincronização

### Mutex Strategy

```ruby
@mutex = Mutex.new

# Exemplo de uso
@mutex.synchronize do
  @connected = true
  @retry_count = 0
  @max_retries_reached = false
end
```

**Áreas Protegidas:**
- Estado da conexão (`@connected`)
- Contador de tentativas (`@retry_count`)
- Tamanho da fila (`@queue_size`)
- Flags de controle (`@started`, `@stopping`)

**Justificativa Técnica:**
- **Race Conditions**: Previne condições de corrida em operações concorrentes
- **Consistência**: Garante estado consistente entre threads
- **Atomicidade**: Operações críticas são atômicas

### Queue Management

```ruby
@send_queue = Queue.new

# Thread-safe operations
@send_queue << message  # Adicionar
msg = @send_queue.pop(true)  # Remover (não-bloqueante)
```

**Características:**
- **Thread-Safe**: Operações nativas thread-safe
- **FIFO**: First In, First Out para mensagens
- **Non-blocking**: Pop com timeout para evitar deadlocks

## 🔄 Sistema de Reconexão

### Backoff Exponencial

```ruby
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
```

**Algoritmo:**
1. **Delay Inicial**: 5 segundos
2. **Exponencial**: 5s → 10s → 20s → 40s → ...
3. **Limite Máximo**: 15 segundos
4. **Limite de Tentativas**: 1000 (configurável)

**Justificativa Técnica:**
- **Reduz Carga**: Evita "thundering herd" durante falhas
- **Recuperação Gradual**: Permite resolução de problemas temporários
- **Limite de Recursos**: Previne loops infinitos
- **Adaptabilidade**: Ajusta-se à severidade da falha

### Timeout de Conexão

```ruby
@connection_timeout = EM::Timer.new(30) do
  log "Timeout na conexão após 30s", level: :error
  disconnect!
  retry_with_backoff unless @stopping
end
```

**Funcionalidades:**
- **Timeout**: 30 segundos para estabelecer conexão
- **Cancelamento**: Cancelado quando conexão é estabelecida
- **Recuperação**: Inicia processo de reconexão em caso de timeout

## 📊 Gerenciamento de Fila

### Estratégias de Overflow

```ruby
def handle_queue_overflow(message)
  case QUEUE_OVERFLOW_STRATEGY
  when :drop_oldest
    begin
      @send_queue.pop(true)
      @queue_size -= 1
      @send_queue << message
      @queue_size += 1
      log "Fila cheia: mensagem antiga descartada, nova adicionada", level: :warn
    rescue StandardError => e
      log "Tentativa de drop_oldest em fila vazia - adicionando nova mensagem #{e.message}", level: :warn
      @send_queue << message
      @queue_size += 1
    end
  when :drop_newest
    log "Fila cheia: nova mensagem descartada (#{QUEUE_OVERFLOW_STRATEGY})", level: :warn
  else
    log "Estratégia de overflow desconhecida: #{QUEUE_OVERFLOW_STRATEGY}", level: :error
  end
end
```

**Estratégias Disponíveis:**

1. **`:drop_oldest`** (Padrão)
   - Remove mensagem mais antiga
   - Adiciona nova mensagem
   - Útil para dados em tempo real

2. **`:drop_newest`**
   - Descarta nova mensagem
   - Preserva mensagens antigas
   - Útil para dados críticos

**Justificativa Técnica:**
- **Controle de Memória**: Previne crescimento ilimitado da fila
- **Flexibilidade**: Diferentes estratégias para diferentes casos de uso
- **Configurabilidade**: Permite ajuste baseado em requisitos

### Monitoramento de Fila

```ruby
if @queue_size > (MAX_QUEUE_SIZE * 0.8)
  log "Atenção: Fila de envio com #{@queue_size}/#{MAX_QUEUE_SIZE} mensagens", level: :warn
end
```

**Alertas:**
- **80%**: Aviso de fila alta
- **90%**: Alerta crítico
- **100%**: Overflow ativo

## 🛡 Tratamento de Erros

### Estratégia de Recuperação

```ruby
rescue StandardError => e
  log "Erro ao processar mensagem: Backtrace: #{e.backtrace.first(5).join("\n")}", level: :error
end
```

**Níveis de Tratamento:**

1. **Erros de Conexão**
   - Reconexão automática
   - Backoff exponencial
   - Limite de tentativas

2. **Erros de Mensagem**
   - Logging detalhado
   - Continuação do processamento
   - Não interrompe o cliente

3. **Erros de Thread**
   - Logging com backtrace
   - Recuperação graciosa
   - Notificação de falhas críticas

### Graceful Shutdown

```ruby
def stop
  @mutex.synchronize do
    return if @stopping
    
    @stopping = true
    @started = false
    @connected = false
    
    log "Iniciando parada do cliente..."
    
    @send_queue << :stop_signal
    
    disconnect!
    
    EM.stop_event_loop if EM.reactor_running?
  end
  
  wait_for_threads_completion
  clear_queue
  
  log "Cliente parado com sucesso"
end
```

**Processo de Shutdown:**

1. **Sinalização**: Marca `@stopping = true`
2. **Desconexão**: Fecha conexão WebSocket
3. **Parada de Threads**: Envia sinal de parada
4. **Aguarda Finalização**: Timeout para threads finalizarem
5. **Limpeza**: Remove mensagens pendentes
6. **Logging**: Confirma parada bem-sucedida

## 📈 Performance e Otimizações

### Métricas de Performance

```ruby
# Configurações otimizadas para diferentes cenários
DEFAULT_RETRY_LIMIT = 1000        # Limite de tentativas
DEFAULT_RETRY_DELAY = 5           # Delay inicial (segundos)
MAX_RETRY_DELAY = 15              # Delay máximo (segundos)
MAX_QUEUE_SIZE = 15000            # Tamanho máximo da fila
MAX_THREAD_WAIT_TIME = 5          # Timeout para threads (segundos)
HEALTH_CHECK_INTERVAL = 300       # Intervalo de health check (segundos)
```

### Otimizações Implementadas

1. **Processamento Assíncrono**
   - Threads dedicadas para diferentes responsabilidades
   - Não bloqueia thread principal da aplicação

2. **Gerenciamento de Memória**
   - Limite de tamanho da fila
   - Estratégias de overflow
   - Limpeza automática de recursos

3. **Eficiência de I/O**
   - Envio em lote quando possível
   - Timeout de conexão para evitar bloqueios
   - Cancelamento de operações pendentes

4. **Recuperação Rápida**
   - Detecção precoce de falhas
   - Reconexão automática
   - Preservação de mensagens durante falhas

## 🔍 Observabilidade

### Sistema de Logging

```ruby
def log(message, level: :info)
  return unless log?
  
  puts '*' * 100
  puts "{#{level.upcase}}: [#{self.class.name}][#{Time.now.strftime('%H:%M:%S')}]:\n#{message}\n"
  puts '*' * 100
end
```

**Características:**
- **Configurável**: Ativado via variável de ambiente
- **Estruturado**: Formato consistente com timestamp
- **Níveis**: Info, Warn, Error
- **Contexto**: Inclui classe e timestamp

### Métricas Expostas

```ruby
def status
  @mutex.synchronize do
    {
      connected: @connected,
      started: @started,
      stopping: @stopping,
      retry_count: @retry_count,
      max_retries_reached: @max_retries_reached,
      queue_size: @queue_size,
      event_thread_alive: @event_thread&.alive? || false,
      send_thread_alive: @send_thread&.alive? || false
    }
  end
end
```

**Métricas Disponíveis:**
- **Estado da Conexão**: Conectado/Desconectado
- **Estado do Cliente**: Iniciado/Parando
- **Contadores**: Tentativas de reconexão
- **Fila**: Tamanho atual
- **Threads**: Status de vida das threads

## 🧪 Testabilidade

### Design para Testes

```ruby
# Métodos privados expostos para testes
def wait_for_threads_completion(timeout = MAX_THREAD_WAIT_TIME)
  # Implementação testável
end

def clear_queue
  # Implementação testável
end
```

**Estratégias de Teste:**

1. **Testes Unitários**
   - Métodos isolados
   - Mocks para dependências externas
   - Verificação de comportamento

2. **Testes de Integração**
   - Cliente completo
   - Simulação de falhas de rede
   - Verificação de reconexão

3. **Testes de Performance**
   - Carga de mensagens
   - Tempo de resposta
   - Uso de memória

## 🔮 Extensibilidade

### Hooks para Customização

```ruby
# Hook para notificações externas
def notify_max_retries_reached
  # Implementação customizada
end

# Métodos abstratos para implementação
def url
  raise NotImplementedError
end

def handle_message(msg)
  raise NotImplementedError
end
```

**Pontos de Extensão:**

1. **Notificações**: Slack, email, PagerDuty
2. **Processamento**: Lógica específica de mensagens
3. **Configuração**: URLs e identificadores
4. **Monitoramento**: Métricas customizadas

### Padrões de Design Utilizados

1. **Singleton**: Uma instância por aplicação
2. **Template Method**: BaseClient define estrutura
3. **Strategy**: Estratégias de overflow configuráveis
4. **Observer**: Callbacks para eventos WebSocket
5. **Factory**: Criação de timers e threads

## 📚 Dependências e Compatibilidade

### Dependências Principais

```ruby
gem 'websocket-eventmachine-client'  # Cliente WebSocket
gem 'dotenv'                         # Gerenciamento de variáveis de ambiente
```

### Compatibilidade

- **Ruby**: 3.3+
- **Rails**: 8+ (opcional)
- **EventMachine**: Compatível com versões estáveis
- **WebSocket**: Suporte a protocolo RFC 6455

### Considerações de Segurança

1. **Validação de Entrada**: Sempre validar mensagens recebidas
2. **Headers de Autenticação**: Usar método `headers` para tokens
3. **Logs Sensíveis**: Evitar logar dados sensíveis
4. **Rate Limiting**: Implementar se necessário
5. **TLS**: Usar WSS em produção

Este design técnico garante que o Ruby WebSocket Client seja uma solução robusta, escalável e manutenível para aplicações que precisam de comunicação em tempo real confiável.
