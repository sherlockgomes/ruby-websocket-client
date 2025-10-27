# Ruby WebSocket Client

Uma gem Ruby robusta para comunicação WebSocket em tempo real com recursos avançados de reconexão automática, thread-safety e alta disponibilidade.

## 🚀 TechStack
- Acompanhe o TECH_STACK.MD para entender tecnicamente o comportamento do código

## 🚀 Build
- Acompanhe o BUILD.MD para entender tecnicamente como criar uma nova versão da gem

## 🚀 Características

- **Reconexão automática** com backoff exponencial (até 1000 tentativas)
- **Thread-safe** para ambientes multi-threaded
- **Sistema de fila assíncrona** para mensagens (até 15.000 mensagens)
- **Health check automático** a cada 5 minutos
- **Controle de overflow** configurável (drop_oldest/drop_newest)
- **Logging detalhado** com níveis configuráveis
- **Graceful shutdown** com limpeza de recursos
- **Timeout de conexão** configurável (30s padrão)
- **Singleton pattern** para instância única

## 📦 Instalação

### Ruby Puro

Adicione ao seu `Gemfile`:

```ruby
gem 'ruby_websocket_client'
```

Ou instale diretamente:

```bash
gem install ruby_websocket_client
```

### Rails

Adicione ao seu `Gemfile`:

```ruby
gem 'ruby_websocket_client'
```

Execute:

```bash
bundle install
```

## ⚙️ Configuração

### Variáveis de Ambiente

Crie um arquivo `.env` na raiz do seu projeto:

```env
# URL do servidor WebSocket
WS_URL=wss://seu-servidor.com/websocket

# Identificador único do cliente
WS_IDENTIFIER=meu-cliente-123

# ID do host (usado no pong response)
WS_HOST_IDENTIFIER=host-456

# Habilitar logs (opcional, padrão: false)
WS_LOG=true
```

## 🔧 Uso

### Ruby Puro

```ruby
require 'ruby_websocket_client'

class MeuCliente < RubyWebsocketClient::WebSocketClient
  private

  def url
    ENV.fetch('WS_URL')
  end

  def handle_message(msg)
    puts "Mensagem recebida: #{msg}"
    
    # Processar mensagem recebida
    data = JSON.parse(msg)
    processar_dados(data)
  end

  def identifier
    ENV.fetch('WS_IDENTIFIER')
  end

  def last_connected_at
    Date.today.strftime('%Y-%m-%d')
  end

  def processar_dados(data)
    # Sua lógica de processamento aqui
    puts "Processando: #{data}"
  end
end

# Uso
cliente = MeuCliente.instance
cliente.start

# Enviar mensagem
cliente.send_message({
  receiver_id: 'destinatario-123',
  data: { operation: 'ping', timestamp: Time.now.to_i }
}.to_json)

# Verificar status
puts cliente.status

# Parar cliente
cliente.stop
```

### Rails

#### 1. Criar um Service

```ruby
# app/services/websocket_client_service.rb
class WebSocketClientService < RubyWebsocketClient::WebSocketClient
  private

  def url
    Rails.application.credentials.websocket[:url]
  end

  def handle_message(msg)
    Rails.logger.info "WebSocket message received: #{msg}"
    
    data = JSON.parse(msg)
    process_message(data)
  end

  def identifier
    Rails.application.credentials.websocket[:identifier]
  end

  def last_connected_at
    Date.today.strftime('%Y-%m-%d')
  end

  def process_message(data)
    case data['operation']
    when 'notification'
      NotificationBroadcastJob.perform_later(data)
    when 'update'
      UpdateModelJob.perform_later(data)
    else
      Rails.logger.warn "Unknown operation: #{data['operation']}"
    end
  end
end
```

#### 2. Inicializar no Application

```ruby
# config/application.rb
module MinhaApp
  class Application < Rails::Application
    # ... outras configurações

    # Inicializar WebSocket client
    config.after_initialize do
      if Rails.env.production? || Rails.env.staging?
        WebSocketClientService.instance.start
      end
    end
  end
end
```

#### 3. Controller para enviar mensagens

```ruby
# app/controllers/api/websocket_controller.rb
class Api::WebsocketController < ApplicationController
  def send_message
    message = {
      receiver_id: params[:receiver_id],
      data: params[:data]
    }

    WebSocketClientService.instance.send_message(message.to_json)
    
    render json: { status: 'sent' }
  end
end
```

#### 4. Job para processar mensagens

```ruby
# app/jobs/notification_broadcast_job.rb
class NotificationBroadcastJob < ApplicationJob
  queue_as :default

  def perform(data)
    ActionCable.server.broadcast(
      "notifications_#{data['user_id']}",
      data
    )
  end
end
```

## 📊 Monitoramento

### Status do Cliente

```ruby
cliente = MeuCliente.instance
status = cliente.status

puts "Conectado: #{status[:connected]}"
puts "Rodando: #{cliente.running?}"
puts "Tentativas de reconexão: #{status[:retry_count]}"
puts "Tamanho da fila: #{status[:queue_size]}"
puts "Threads ativas: event=#{status[:event_thread_alive]}, send=#{status[:send_thread_alive]}"
```

### Health Check

A biblioteca inclui um sistema de health check automático que:

- Monitora o tamanho da fila (alerta se > 90% da capacidade)
- Verifica se há mensagens recentes (alerta se > 5 minutos sem mensagens)
- Executa a cada 5 minutos

## 🔧 Configurações Avançadas

### Personalizar Constantes

Você pode sobrescrever as constantes padrão criando uma subclasse:

```ruby
class MeuClienteCustomizado < RubyWebsocketClient::WebSocketClient
  # Personalizar limites
  DEFAULT_RETRY_LIMIT = 500
  DEFAULT_RETRY_DELAY = 3
  MAX_QUEUE_SIZE = 10_000
  HEALTH_CHECK_INTERVAL = 180

  # ... implementar métodos obrigatórios
end
```

### Estratégias de Overflow

A biblioteca suporta duas estratégias para quando a fila está cheia:

- `:drop_oldest` (padrão): Remove a mensagem mais antiga
- `:drop_newest`: Descarta a nova mensagem

### Logging Personalizado

```ruby
class MeuCliente < RubyWebsocketClient::WebSocketClient
  private

  def log(message, level: :info)
    # Usar Rails logger em vez do padrão
    Rails.logger.send(level, "[WebSocket] #{message}")
  end

  # ... outros métodos
end
```

## 🚨 Tratamento de Erros

### Limite de Reconexões Atingido

Quando o limite de reconexões é atingido (1000 tentativas), o cliente:

1. Para automaticamente
2. Define `max_retries_reached = true`
3. Loga um alerta crítico
4. Chama `notify_max_retries_reached` se implementado

```ruby
class MeuCliente < RubyWebsocketClient::WebSocketClient
  private

  def notify_max_retries_reached
    # Notificar via Slack, email, PagerDuty, etc.
    SlackNotifier.notify("WebSocket client stopped - max retries reached")
  end
end
```

## 🧪 Testes

### Exemplo de Teste

```ruby
# test/websocket_client_test.rb
require 'minitest/autorun'
require 'ruby_websocket_client'

class WebSocketClientTest < Minitest::Test
  def setup
    @cliente = MeuCliente.instance
  end

  def test_start_and_stop
    @cliente.start
    assert @cliente.running?
    
    @cliente.stop
    refute @cliente.running?
  end

  def test_send_message
    @cliente.start
    
    message = { test: 'data' }.to_json
    @cliente.send_message(message)
    
    # Verificar se a mensagem foi enfileirada
    assert @cliente.status[:queue_size] > 0
  end
end
```

## 📋 Requisitos

- Ruby >= 3.3.0
- EventMachine ~> 1.2
- WebSocket-EventMachine-Client ~> 1.2
- Dotenv ~> 2.8

## 🤝 Contribuição

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📄 Licença

Este projeto está licenciado sob a Licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.

## 🆘 Suporte

Para reportar bugs ou solicitar features, abra uma issue no GitHub.

---
