# Build Guide - Ruby WebSocket Client

Este documento descreve como construir, testar e publicar a gem `ruby_websocket_client` para novas versões.

## 📋 Pré-requisitos

- Ruby 3.3+ instalado
- Bundler instalado (`gem install bundler`)
- Conta no RubyGems.org
- Git configurado com suas credenciais

## 🔧 Configuração Inicial

### 1. Instalar Dependências
```bash
bundle install
```

### 2. Configurar Credenciais do RubyGems
```bash
gem signin
```
Digite suas credenciais do RubyGems.org quando solicitado.

## 🚀 Processo de Build e Publicação

### Passo 1: Atualizar Versão

Antes de fazer o build, atualize a versão no arquivo `lib/ruby_websocket_client/version.rb`:

```ruby
module RubyWebsocketClient
  VERSION = '1.0.1'  # Incremente conforme necessário
end
```

### Passo 2: Verificar Mudanças

```bash
# Verificar status do git
git status

# Adicionar mudanças
git add .

# Fazer commit
git commit -m "feat: descrição das mudanças"
```

### Passo 3: Construir a Gem

```bash
# Construir a gem
gem build ruby_websocket_client.gemspec
```

**Saída esperada:**
```
Successfully built RubyGem
Name: ruby_websocket_client
Version: 1.0.1
File: ruby_websocket_client-1.0.1.gem
```

### Passo 4: Testar Localmente

```bash
# Instalar a gem localmente para teste
gem install ruby_websocket_client-1.0.1.gem --local

# Verificar se foi instalada
gem list | grep ruby_websocket_client

# Testar em um script Ruby
ruby -e "require 'ruby_websocket_client'; puts RubyWebsocketClient::VERSION"
```

### Passo 5: Executar Testes

```bash
# Executar testes
bundle exec rake test

# Ou executar diretamente
ruby tests/connection_test.rb
```

### Passo 6: Push para GitHub

```bash
# Fazer push das mudanças
git push origin main

# Criar e fazer push de uma tag (opcional, mas recomendado)
git tag v1.0.1
git push origin v1.0.1
```

### Passo 7: Publicar no RubyGems

```bash
# Publicar a gem
gem push ruby_websocket_client-1.0.1.gem
```

**Saída esperada:**
```
Pushing gem to https://rubygems.org...
Successfully registered gem: ruby_websocket_client (1.0.1)
```

## 🔍 Verificação Pós-Publicação

### 1. Verificar no RubyGems.org
- Acesse: https://rubygems.org/gems/ruby_websocket_client
- Confirme que a nova versão está listada

### 2. Testar Instalação
```bash
# Desinstalar versão local
gem uninstall ruby_websocket_client

# Instalar do RubyGems
gem install ruby_websocket_client

# Verificar versão
gem list ruby_websocket_client
```

## 📝 Convenções de Versionamento

Seguimos [Semantic Versioning](https://semver.org/):

- **MAJOR** (1.0.0 → 2.0.0): Mudanças incompatíveis na API
- **MINOR** (1.0.0 → 1.1.0): Nova funcionalidade compatível
- **PATCH** (1.0.0 → 1.0.1): Correções de bugs compatíveis

### Exemplos de Commits:
- `feat: adiciona suporte a SSL/TLS` → MINOR
- `fix: corrige reconexão automática` → PATCH
- `feat!: remove método deprecated` → MAJOR

## 🛠️ Comandos Úteis

### Limpeza
```bash
# Remover gems construídas
rm *.gem

# Limpar cache do bundler
bundle clean --force
```

### Verificação
```bash
# Verificar gemspec
gem spec ruby_websocket_client.gemspec

# Verificar dependências
bundle check

# Verificar sintaxe Ruby
ruby -c lib/ruby_websocket_client/*.rb
```

### Debug
```bash
# Ver logs detalhados do build
gem build ruby_websocket_client.gemspec --verbose

# Verificar conteúdo da gem
gem contents ruby_websocket_client-1.0.1.gem
```

## ⚠️ Troubleshooting

### Erro: "Invalid credentials"
```bash
# Reconfigurar credenciais
gem signout
gem signin
```

### Erro: "Gem already exists"
- Verifique se a versão já foi publicada
- Incremente a versão no `version.rb`

### Erro: "Dependencies not satisfied"
```bash
# Instalar dependências
bundle install

# Verificar dependências
bundle check
```

### Erro: "Files not found"
- Verifique se todos os arquivos estão commitados
- Execute `git add .` antes do build

## 📚 Recursos Adicionais

- [RubyGems Guide](https://guides.rubygems.org/)
- [Semantic Versioning](https://semver.org/)
- [Bundler Documentation](https://bundler.io/)
- [Git Tagging](https://git-scm.com/book/en/v2/Git-Basics-Tagging)

## 🎯 Checklist de Publicação

- [ ] Versão atualizada em `version.rb`
- [ ] Todos os arquivos commitados
- [ ] Testes passando
- [ ] Gem construída com sucesso
- [ ] Teste local realizado
- [ ] Push para GitHub
- [ ] Publicação no RubyGems
- [ ] Verificação pós-publicação

---

**Última atualização:** $(date)
**Versão atual:** 1.0.0
