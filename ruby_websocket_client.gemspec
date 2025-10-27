# frozen_string_literal: true

require_relative 'lib/ruby_websocket_client/version'

Gem::Specification.new do |spec|
  spec.name          = 'ruby_websocket_client'
  spec.version       = RubyWebsocketClient::VERSION
  spec.authors       = ['Public']
  spec.email         = ['public@example.com']

  spec.summary       = 'Cliente WebSocket Ruby robusto com reconexão automática e alta disponibilidade'
  spec.description   = <<~DESC
    Uma gem Ruby para comunicação WebSocket em tempo real com recursos avançados:
    - Reconexão automática com backoff exponencial
    - Thread-safe para ambientes multi-threaded
    - Sistema de fila assíncrona para mensagens
    - Health check automático
    - Controle de overflow configurável
    - Logging detalhado
    - Graceful shutdown
  DESC
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.3.0'

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Dependencies
  spec.add_dependency 'websocket-eventmachine-client', '~> 1.2'
  spec.add_dependency 'dotenv', '~> 2.8'
  spec.add_dependency 'eventmachine', '~> 1.2'

  # Development dependencies
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'rubocop', '~> 1.0'
  spec.add_development_dependency 'rubocop-rake', '~> 0.6'
  spec.add_development_dependency 'rubocop-minitest', '~> 0.22'
end
