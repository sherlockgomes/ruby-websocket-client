# Ruby WebSocket Client

Projetado para aplicações que precisam de comunicação em tempo real com alta disponibilidade e recuperação automática de falhas.

## 🚀 Características Principais

- **Reconexão Automática**: Sistema inteligente de reconexão com backoff exponencial
- **Thread-Safe**: Operações seguras para ambientes multi-threaded
- **Fila de Mensagens**: Sistema de fila assíncrona para envio de mensagens
- **Health Check**: Monitoramento contínuo da saúde da conexão
- **Controle de Overflow**: Estratégias configuráveis para gerenciar picos de tráfego
- **Logging Configurável**: Sistema de logs detalhado para debugging e monitoramento
- **Timeout de Conexão**: Proteção contra conexões que ficam pendentes
- **Graceful Shutdown**: Encerramento seguro de todas as threads e recursos

## 📋 Pré-requisitos

- Ruby 3.3+
- Rails 8+ (opcional, mas recomendado)
- PostgreSQL 15+ (para aplicações que usam banco de dados)

## 🛠 Instalação

1. Adicione as dependências ao seu `Gemfile`:

```ruby
gem 'websocket-eventmachine-client'
gem 'dotenv'
```

2. Execute o bundle:

```bash
bundle install
```

3. Configure as variáveis de ambiente no arquivo `.env`:

```env
HERMES_WS_URL=wss://seu-servidor-websocket.com/websocket
HERMES_WS_IDENTIFIER=seu-identificador-unico
HERMES_WS_LOG=true
```

## 🏗 Arquitetura

### BaseClient

A classe base que define a interface comum para todos os clientes WebSocket:

- **Singleton Pattern**: Garante uma única instância por aplicação
- **Métodos Abstratos**: Define contratos que devem ser implementados pelas subclasses
- **Funcionalidades Comuns**: Ping/Pong automático, logging, headers padrão

### WebSocketClient

A implementação principal que herda de `BaseClient` e adiciona:

- **Gerenciamento de Threads**: Threads dedicadas para eventos, envio e health check
- **Sistema de Fila**: Fila thread-safe para mensagens assíncronas
- **Reconexão Inteligente**: Backoff exponencial com limite configurável
- **Monitoramento**: Health checks e alertas de performance

## 📖 Como Usar

### 1. Criando um Cliente Personalizado

```ruby
require_relative 'websocket_client'

class MeuCliente < WebSocketClient
  private

  def url
    ENV.fetch('HERMES_WS_URL')
  end

  def identifier
    ENV.fetch('HERMES_WS_IDENTIFIER')
  end

  def last_connected_at
    # Retorna a data da última conexão bem-sucedida
    # Útil para sincronização de dados
    Date.today.strftime('%Y-%m-%d')
  end

  def handle_message(msg)
    # Processa mensagens recebidas do servidor
    puts "Mensagem recebida: #{msg}"
    
    # Exemplo: processar diferentes tipos de mensagem
    data = JSON.parse(msg) rescue {}
    
    case data['operation']
    when 'notification'
      process_notification(data)
    when 'sync'
      process_sync(data)
    else
      log "Operação desconhecida: #{data['operation']}", level: :warn
    end
  end

  def process_notification(data)
    # Lógica para processar notificações
    puts "Nova notificação: #{data['message']}"
  end

  def process_sync(data)
    # Lógica para sincronização de dados
    puts "Sincronizando dados: #{data['payload']}"
  end
end
```

### 2. Inicializando e Gerenciando o Cliente

```ruby
# Criar instância do cliente
cliente = MeuCliente.instance

# Iniciar conexão
cliente.start

# Verificar status
puts cliente.status
# => {
#   connected: true,
#   started: true,
#   stopping: false,
#   retry_count: 0,
#   max_retries_reached: false,
#   queue_size: 0,
#   event_thread_alive: true,
#   send_thread_alive: true
# }

# Enviar mensagem
cliente.send_message({
  receiver_id: 'servidor',
  data: { operation: 'ping', timestamp: Time.now.to_i }
}.to_json)

# Parar cliente (graceful shutdown)
cliente.stop
```

### 3. Integração com Rails

```ruby
# config/initializers/websocket_client.rb
class ApplicationWebSocketClient < WebSocketClient
  private

  def url
    Rails.application.credentials.websocket[:url]
  end

  def identifier
    Rails.application.credentials.websocket[:identifier]
  end

  def last_connected_at
    # Buscar do banco de dados ou cache
    Rails.cache.read('last_websocket_connection') || Date.today.strftime('%Y-%m-%d')
  end

  def handle_message(msg)
    # Processar mensagens em background job
    WebSocketMessageProcessorJob.perform_later(msg)
  end
end

# Iniciar o cliente quando a aplicação subir
Rails.application.config.after_initialize do
  ApplicationWebSocketClient.instance.start
end

# Parar o cliente quando a aplicação for encerrada
at_exit do
  ApplicationWebSocketClient.instance.stop
end
```

## ⚙️ Configurações Avançadas

### Constantes Configuráveis

```ruby
class MeuCliente < WebSocketClient
  # Personalizar limites e timeouts
  DEFAULT_RETRY_LIMIT = 500        # Número máximo de tentativas de reconexão
  DEFAULT_RETRY_DELAY = 3          # Delay inicial entre tentativas (segundos)
  MAX_RETRY_DELAY = 30             # Delay máximo entre tentativas (segundos)
  MAX_QUEUE_SIZE = 10000           # Tamanho máximo da fila de mensagens
  QUEUE_OVERFLOW_STRATEGY = :drop_oldest  # Estratégia: :drop_oldest ou :drop_newest
  MAX_THREAD_WAIT_TIME = 10        # Timeout para finalização de threads (segundos)
  HEALTH_CHECK_INTERVAL = 60       # Intervalo do health check (segundos)
end
```

### Estratégias de Overflow

- **`:drop_oldest`**: Remove a mensagem mais antiga da fila (padrão)
- **`:drop_newest`**: Descarta a nova mensagem quando a fila está cheia

## 🔧 Justificativas Técnicas

### 1. **Thread-Safety e Concorrência**

```ruby
@mutex.synchronize do
  # Operações críticas protegidas por mutex
  @connected = true
  @queue_size += 1
end
```

**Por que é importante:**
- Previne race conditions em ambientes multi-threaded
- Garante consistência dos dados compartilhados
- Evita corrupção de estado durante operações concorrentes

### 2. **Sistema de Fila Assíncrona**

```ruby
def process_send_queue
  loop do
    msg = @send_queue.pop(true)
    @ws.send(msg) if @connected
  end
end
```

**Benefícios:**
- **Desacoplamento**: Envio não bloqueia o thread principal
- **Resilência**: Mensagens são preservadas durante desconexões
- **Performance**: Processamento em lote e otimização de I/O

### 3. **Backoff Exponencial**

```ruby
delay = [DEFAULT_RETRY_DELAY * (2**@retry_count), MAX_RETRY_DELAY].min
```

**Vantagens:**
- **Reduz carga no servidor**: Evita "thundering herd" durante falhas
- **Recuperação gradual**: Permite que problemas temporários se resolvam
- **Limite de tentativas**: Previne loops infinitos de reconexão

### 4. **Health Check Automático**

```ruby
def health_check_loop
  if connected && last_msg && (Time.now - last_msg) > HEALTH_CHECK_INTERVAL
    log "ALERTA: Sem mensagens há #{HEALTH_CHECK_INTERVAL} segundos", level: :warn
  end
end
```

**Funcionalidades:**
- **Detecção precoce**: Identifica conexões "mortas" rapidamente
- **Monitoramento de performance**: Alerta sobre filas críticas
- **Métricas de qualidade**: Tracking de tempo entre mensagens

### 5. **Graceful Shutdown**

```ruby
def stop
  @stopping = true
  @send_queue << :stop_signal
  wait_for_threads_completion
  clear_queue
end
```

**Importância:**
- **Integridade de dados**: Evita perda de mensagens durante shutdown
- **Limpeza de recursos**: Previne memory leaks e conexões órfãs
- **Cooperação**: Permite que threads finalizem suas operações

## 🚨 Tratamento de Erros

### Estratégias de Recuperação

1. **Falhas de Conexão**: Reconexão automática com backoff
2. **Overflow de Fila**: Estratégias configuráveis (drop oldest/newest)
3. **Timeouts**: Cancelamento automático e retry
4. **Erros de Thread**: Logging detalhado e recuperação graciosa

### Logging e Monitoramento

```ruby
# Configurar níveis de log
ENV['HERMES_WS_LOG'] = 'true'

# Exemplo de logs gerados
# {INFO}: [WebSocketClient][14:30:15]: Cliente WebSocket iniciado
# {WARN}: [WebSocketClient][14:30:20]: Tentando reconexão em 5s (tentativa 1/1000)
# {ERROR}: [WebSocketClient][14:30:25]: Limite de reconexões atingido
```

## 📊 Métricas e Monitoramento

### Status do Cliente

```ruby
status = cliente.status
puts "Conectado: #{status[:connected]}"
puts "Fila: #{status[:queue_size]} mensagens"
puts "Tentativas: #{status[:retry_count]}"
puts "Threads ativas: #{status[:event_thread_alive] && status[:send_thread_alive]}"
```

### Alertas Recomendados

- **Fila crítica**: `queue_size > MAX_QUEUE_SIZE * 0.9`
- **Sem mensagens**: `last_message_at > HEALTH_CHECK_INTERVAL`
- **Muitas reconexões**: `retry_count > DEFAULT_RETRY_LIMIT * 0.8`
- **Threads mortas**: `!event_thread_alive || !send_thread_alive`

## 🔒 Considerações de Segurança

1. **Headers de Autenticação**: Use o método `headers` para incluir tokens
2. **Validação de Mensagens**: Sempre valide dados recebidos
3. **Rate Limiting**: Implemente limites de envio se necessário
4. **Logs Sensíveis**: Evite logar dados sensíveis

## 🧪 Testes

```ruby
# Exemplo de teste básico
require 'minitest/autorun'
require_relative 'websocket_client'

class WebSocketClientTest < Minitest::Test
  def setup
    @client = TestClient.instance
  end

  def test_client_startup
    @client.start
    assert @client.running?
    assert @client.status[:started]
  end

  def test_message_sending
    @client.start
    @client.send_message('{"test": "message"}')
    assert @client.status[:queue_size] > 0
  end

  def teardown
    @client.stop
  end
end
```

## 🤝 Contribuição

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/nova-funcionalidade`)
3. Commit suas mudanças (`git commit -am 'Adiciona nova funcionalidade'`)
4. Push para a branch (`git push origin feature/nova-funcionalidade`)
5. Abra um Pull Request

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo `LICENSE` para mais detalhes.

## 🆘 Suporte

Para dúvidas ou problemas:

1. Verifique a documentação
2. Consulte os logs com `HERMES_WS_LOG=true`
3. Abra uma issue no repositório
4. Entre em contato com a equipe de desenvolvimento

---

**Desenvolvido com ❤️ para aplicações Ruby robustas e escaláveis.**
