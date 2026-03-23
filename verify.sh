#!/usr/bin/env bash

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

ok()   { echo -e "  ${GREEN}✓${NC} $1"; ((PASS++)); }
fail() { echo -e "  ${RED}✗${NC} $1"; ((FAIL++)); }
warn() { echo -e "  ${YELLOW}~${NC} $1"; }
section() { echo ""; echo "$1"; }

DOTFILES="$HOME/dotfiles"

# ── Symlinks ────────────────────────────────────────────────────────────────
section "Symlinks"

check_symlink() {
  local dst="$1"
  local expected_src="$2"
  local label="${3:-$dst}"

  if [ ! -L "$dst" ]; then
    fail "$label — not a symlink"
  elif [ "$(readlink "$dst")" != "$expected_src" ]; then
    fail "$label — points to $(readlink "$dst") (expected $expected_src)"
  else
    ok "$label"
  fi
}

check_symlink "$HOME/.zshrc"            "$DOTFILES/.zshrc"
check_symlink "$HOME/.aliases"          "$DOTFILES/.aliases"
check_symlink "$HOME/.gitconfig"        "$DOTFILES/.gitconfig"
check_symlink "$HOME/.vimrc"            "$DOTFILES/.vimrc"
check_symlink "$HOME/.tmux.conf"        "$DOTFILES/.tmux.conf"
check_symlink "$HOME/.config/ghostty/config" "$DOTFILES/config/ghostty/config"
check_symlink "$HOME/.config/nvim"      "$DOTFILES/config/nvim"
check_symlink "$HOME/.config/starship.toml" "$DOTFILES/config/starship.toml"
check_symlink "$HOME/.claude/CLAUDE.md" "$DOTFILES/config/claude/CLAUDE.md"
check_symlink "$HOME/Library/Application Support/Code/User/settings.json" \
              "$DOTFILES/config/vscode/settings.json" "vscode/settings.json"

# ── Generated files ──────────────────────────────────────────────────────────
section "Generated files"

if [ -f "$HOME/.ssh/config" ]; then
  ok "~/.ssh/config exists"
else
  fail "~/.ssh/config missing — run bootstrap.sh"
fi

# ── Tools in PATH ────────────────────────────────────────────────────────────
section "Tools"

check_cmd() {
  if command -v "$1" &>/dev/null; then
    ok "$1"
  else
    fail "$1 — not found in PATH"
  fi
}

check_cmd brew
check_cmd git
check_cmd tmux
check_cmd nvim
check_cmd starship
check_cmd zoxide
check_cmd gh
check_cmd bat
check_cmd eza
check_cmd fd
check_cmd rg
check_cmd ghostty

# ── Brew packages ────────────────────────────────────────────────────────────
section "Brew bundle"

if command -v brew &>/dev/null; then
  if brew bundle check --file="$DOTFILES/Brewfile" &>/dev/null; then
    ok "All Brewfile packages installed"
  else
    fail "Some Brewfile packages missing — run: brew bundle --file=$DOTFILES/Brewfile"
    warn "Run 'brew bundle check --file=$DOTFILES/Brewfile' to see details"
  fi
else
  fail "Homebrew not installed"
fi

# ── Hostname ─────────────────────────────────────────────────────────────────
section "System"

HOSTNAME=$(scutil --get HostName 2>/dev/null)
if [ -n "$HOSTNAME" ]; then
  ok "Hostname set: $HOSTNAME"
else
  fail "Hostname not configured — run bootstrap.sh"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────"
TOTAL=$((PASS + FAIL))
if [ "$FAIL" -eq 0 ]; then
  echo -e "  ${GREEN}All $TOTAL checks passed${NC}"
else
  echo -e "  ${GREEN}$PASS passed${NC} · ${RED}$FAIL failed${NC} · $TOTAL total"
fi
echo ""
