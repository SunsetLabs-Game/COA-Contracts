#!/usr/bin/env bash
set -e

echo "🚀 Setting up development environment..."

# Install dependencies
apt-get update && apt-get install -y curl git build-essential

# Install asdf
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc
. ~/.asdf/asdf.sh

# Add and install plugins
asdf plugin add scarb || true
asdf install scarb 2.10.1
asdf global scarb 2.10.1

asdf plugin add dojo https://github.com/dojoengine/asdf-dojo || true
asdf install dojo 1.5.0
asdf global dojo 1.5.0

asdf plugin add starknet-foundry || true
asdf install starknet-foundry 0.35.0
asdf global starknet-foundry 0.35.0

echo "✅ Environment ready!"
