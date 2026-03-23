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
read -p "Enter machine hostname (e.g. rambla or gotic): " MACHINE_NAME
sudo scutil --set HostName "$MACHINE_NAME"
sudo scutil --set LocalHostName "$MACHINE_NAME"
sudo scutil --set ComputerName "$MACHINE_NAME"
info "Hostname set to: $MACHINE_NAME"

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

mkdir -p "$HOME/Library/Application Support/Code/User"
symlink "$DOTFILES/config/vscode/settings.json" "$HOME/Library/Application Support/Code/User/settings.json"

symlink "$DOTFILES/config/starship.toml" "$HOME/.config/starship.toml"

mkdir -p "$HOME/.claude"
symlink "$DOTFILES/config/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

# SSH config — substitute HOSTNAME placeholder with actual machine name
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
sed "s/HOSTNAME/$MACHINE_NAME/g" "$DOTFILES/config/ssh/config" > "$HOME/.ssh/config"
chmod 600 "$HOME/.ssh/config"
info "  ~/.ssh/config generated for $HOSTNAME"

# VS Code extensions
if command -v code &>/dev/null; then
  info "Installing VS Code extensions..."
  code --install-extension catppuccin.catppuccin-vsc || true
  code --install-extension catppuccin.catppuccin-vsc-icons || true
  code --install-extension ms-vscode-remote.remote-ssh || true
  code --install-extension ms-vscode-remote.remote-containers || true
  code --install-extension eamodio.gitlens || true
  code --install-extension yzhang.markdown-all-in-one || true
  code --install-extension vscodevim.vim || true
else
  warning "VS Code 'code' CLI not found — install extensions manually"
fi

# Neovim plugins
info "Installing Neovim plugins..."
nvim --headless '+Lazy sync' +qa 2>/dev/null || warning "Neovim plugins may need manual install (run nvim once)"

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
echo "  1. Generate SSH key: ssh-keygen -t ed25519 -C \"jtibau@$MACHINE_NAME\" -f ~/.ssh/id_ed25519_$MACHINE_NAME"
echo "  2. Add public key to GitHub: cat ~/.ssh/id_ed25519_$MACHINE_NAME.pub"
echo "  3. Switch dotfiles remote to SSH: git -C ~/dotfiles remote set-url origin git@github.com:jtibau/dotfiles.git"
echo "  4. Install Docker manually (requires GUI interaction)"
echo "  5. Add machine to Tailscale"
echo ""
