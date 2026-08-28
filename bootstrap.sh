#!/usr/bin/env bash
# Yan's pod bootstrap. The devpod chart clones this repo to /root/dotfiles
# and runs this script on EVERY boot (recreation included, no first-boot
# tracking), so every step checks reality before acting and nothing here
# may fail the boot. sshd, app-state symlinks, and cache routing are the
# chart's job; this script never touches them.
set -u
cd "$(dirname "$0")"

log() { echo "[dotfiles] $*"; }

# --- shell config: copied fresh every run so edits reach existing pods ---
cp aliases.sh ~/.aliases.sh
cp tmux.conf ~/.tmux.conf
grep -qxF 'source ~/.aliases.sh' ~/.bashrc 2>/dev/null \
  || echo 'source ~/.aliases.sh' >> ~/.bashrc

# --- git identity ---
git config --global user.name "Yan Cheng" || true
git config --global user.email "yan.cheng@baseten.co" || true

# --- tools (check-first: reruns are free) ---
if ! command -v uv >/dev/null 2>&1; then
  log "installing uv"
  curl -LsSf https://astral.sh/uv/install.sh | sh || log "uv install failed"
fi
export PATH="$HOME/.local/bin:$PATH"

if ! command -v hf >/dev/null 2>&1 && ! command -v huggingface-cli >/dev/null 2>&1; then
  log "installing HF CLI"
  uv tool install -q "huggingface_hub[cli]" || log "hf install failed"
fi

if ! command -v claude >/dev/null 2>&1; then
  log "installing Claude Code"
  curl -fsSL https://claude.ai/install.sh | bash || log "claude install failed"
fi

if [ ! -d ~/.fzf ]; then
  log "installing fzf"
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf \
    && ~/.fzf/install --key-bindings --completion --no-update-rc --no-zsh --no-fish \
    || log "fzf install failed"
fi
grep -qxF '[ -f ~/.fzf.bash ] && source ~/.fzf.bash' ~/.bashrc 2>/dev/null \
  || echo '[ -f ~/.fzf.bash ] && source ~/.fzf.bash' >> ~/.bashrc

# --- secrets: NEVER in this repo. env.secrets arrives by rsync (laptop)
# or is pasted once into ~/.env; without it, logins are skipped and
# everything else still works.
if [ -f env.secrets ]; then cp env.secrets ~/.env && chmod 600 ~/.env; fi
if [ -f ~/.env ]; then
  # shellcheck disable=SC1090
  . ~/.env
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    git config --global credential.helper store
    grep -q "x-access-token" ~/.git-credentials 2>/dev/null \
      || echo "https://x-access-token:${GITHUB_TOKEN}@github.com" >> ~/.git-credentials
  fi
  if [ -n "${DOCKERHUB_TOKEN:-}" ] && command -v docker >/dev/null 2>&1; then
    echo "$DOCKERHUB_TOKEN" | docker login -u "${DOCKERHUB_USER:-}" --password-stdin \
      >/dev/null 2>&1 || log "docker login failed (daemon not up yet?)"
  fi
else
  log "no ~/.env — skipping GitHub/Docker logins (rsync env.secrets over when needed)"
fi

log "done"
exit 0
