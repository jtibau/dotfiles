#!/usr/bin/env bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}==>${NC} $1"; }
warning() { echo -e "${YELLOW}==>${NC} $1"; }
error()   { echo -e "${RED}==>${NC} $1"; exit 1; }

# Check macOS
[[ "$OSTYPE" == "darwin"* ]] || error "This script is for macOS only."

info "Starting bootstrap..."

# Hostname
echo ""
read -p "Enter machine hostname (e.g. rambla or gotic): " HOSTNAME
sudo scutil --set HostName "$HOSTNAME"
sudo scutil --set LocalHostName "$HOSTNAME"
sudo scutil --set ComputerName "$HOSTNAME"
info "Hostname set to: $HOSTNAME"

# Homebrew
if ! command -v brew &>/dev/null; then
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  info "Homebrew already installed."
fi

# Dotfiles
DOTFILES="$HOME/dotfiles"
if [ ! -d "$DOTFILES" ]; then
  info "Cloning dotfiles..."
  git clone https://github.com/jtibau/dotfiles.git "$DOTFILES"
else
  info "Dotfiles already cloned."
fi

# Brew bundle
info "Installing packages from Brewfile..."
brew bundle --file="$DOTFILES/Brewfile"

# Symlinks
info "Creating symlinks..."

symlink() {
  local src="$1"
  local dst="$2"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    warning "Backing up existing $dst → ${dst}.bak"
    mv "$dst" "${dst}.bak"
  fi
  ln -sf "$src" "$dst"
  info "  $dst → $src"
}

symlink "$DOTFILES/.zshrc"          "$HOME/.zshrc"
symlink "$DOTFILES/.aliases"        "$HOME/.aliases"
symlink "$DOTFILES/.gitconfig"      "$HOME/.gitconfig"
symlink "$DOTFILES/.vimrc"          "$HOME/.vimrc"
symlink "$DOTFILES/.tmux.conf"      "$HOME/.tmux.conf"

mkdir -p "$HOME/.config/ghostty"
symlink "$DOTFILES/config/ghostty/config" "$HOME/.config/ghostty/config"

mkdir -p "$HOME/.config"
symlink "$DOTFILES/config/nvim"     "$HOME/.config/nvim"

symlink "$DOTFILES/config/starship.toml" "$HOME/.config/starship.toml"

# Neovim plugins
info "Installing Neovim plugins..."
nvim --headless "+Lazy! sync" +qa 2>/dev/null || warning "Neovim plugins may need manual install (run nvim once)"

# GitHub known_hosts
info "Adding GitHub to known_hosts..."
mkdir -p ~/.ssh
ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null

# Energy settings
info "Configuring energy settings..."
sudo pmset -c sleep 0         # no sleep when on power
sudo pmset -c disksleep 0     # no disk sleep when on power
sudo pmset -a womp 1          # wake on network access

# Done
echo ""
info "Bootstrap complete!"
echo ""
warning "Manual steps remaining:"
echo "  1. Generate SSH key: ssh-keygen -t ed25519 -C \"jtibau@$HOSTNAME\" -f ~/.ssh/id_ed25519_$HOSTNAME"
echo "  2. Add public key to GitHub: cat ~/.ssh/id_ed25519_$HOSTNAME.pub"
echo "  3. Switch dotfiles remote to SSH: git -C ~/dotfiles remote set-url origin git@github.com:jtibau/dotfiles.git"
echo "  4. Install Docker manually (requires GUI interaction)"
echo "  5. Add machine to Tailscale"
echo ""
