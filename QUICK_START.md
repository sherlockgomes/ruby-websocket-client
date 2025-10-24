# Quick Start - Ruby WebSocket Client

## 🚀 Início Rápido (5 minutos)

### 1. Instalação

```bash
# Adicionar ao Gemfile
echo "gem 'websocket-eventmachine-client'" >> Gemfile
echo "gem 'dotenv'" >> Gemfile

# Instalar dependências
bundle install
```

### 2. Configuração

```bash
# Criar arquivo .env
cp config.example.env .env

# Editar configurações
# HERMES_WS_URL=wss://seu-servidor.com/websocket
# HERMES_WS_IDENTIFIER=meu-cliente
# HERMES_WS_LOG=true
```

### 3. Implementação Básica

```ruby
# app/services/my_websocket_client.rb
require_relative '../../websocket_client'

class MyWebSocketClient < WebSocketClient
  private

  def url
    ENV['HERMES_WS_URL']
  end

  def identifier
    ENV['HERMES_WS_IDENTIFIER']
  end

  def last_connected_at
    Date.today.strftime('%Y-%m-%d')
  end

  def handle_message(msg)
    puts "Mensagem recebida: #{msg}"
    # Sua lógica aqui
  end
end
```

### 4. Uso

```ruby
# Iniciar cliente
client = MyWebSocketClient.instance
client.start

# Enviar mensagem
client.send_message('{"test": "hello world"}')

# Verificar status
puts client.status

# Parar cliente
client.stop
```

## ✅ Pronto!

Seu cliente WebSocket está funcionando com:
- ✅ Reconexão automática
- ✅ Fila de mensagens thread-safe
- ✅ Health check automático
- ✅ Logging estruturado
- ✅ Graceful shutdown

## 📚 Próximos Passos

- 📖 [README.md](README.md) - Documentação completa
- 🎯 [EXAMPLES.md](EXAMPLES.md) - Exemplos práticos
- 🔧 [TECHNICAL_DESIGN.md](TECHNICAL_DESIGN.md) - Design técnico
- 🔄 [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) - Guia de migração

## 🆘 Precisa de Ajuda?

1. Verifique os logs com `HERMES_WS_LOG=true`
2. Consulte a documentação completa
3. Abra uma issue no repositório
