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

if ! command -v claude >/dev/null 2>&1 && [ ! -x ~/.local/bin/claude ]; then
  log "installing Claude Code"
  # claude.ai 403s from some cluster egress IPs (ali-apse7, 2026-08-28);
  # code.claude.com serves the same installer and answers everywhere.
  curl -fsSL https://code.claude.com/install.sh | bash     || curl -fsSL https://claude.ai/install.sh | bash     || log "claude install failed"
fi
# The native installer drops the binary in ~/.local/bin but does not wire
# PATH into bashrc; do it here (uv needs it too).
grep -qxF 'export PATH="$HOME/.local/bin:$PATH"' ~/.bashrc 2>/dev/null   || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# --- Claude Code status line (same script as the laptop; copied every run) ---
# Needs jq. Debian images usually lack it; apt first, static binary as fallback.
if ! command -v jq >/dev/null 2>&1; then
  log "installing jq"
  (apt-get install -y -qq jq >/dev/null 2>&1) \
    || (mkdir -p ~/.local/bin && curl -fsSL -o ~/.local/bin/jq https://github.com/jqlang/jq/releases/latest/download/jq-linux-amd64 \
        && chmod +x ~/.local/bin/jq) \
    || log "jq install failed (status line will show 'jq missing')"
fi
mkdir -p ~/.claude
cp claude/statusline-command.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
# Merge only the statusLine key; leave whatever else settings.json holds.
if command -v jq >/dev/null 2>&1; then
  [ -s ~/.claude/settings.json ] || echo '{}' > ~/.claude/settings.json
  jq '.statusLine = {type:"command", command:"bash ~/.claude/statusline-command.sh"}' \
    ~/.claude/settings.json > ~/.claude/settings.json.tmp \
    && mv ~/.claude/settings.json.tmp ~/.claude/settings.json \
    || log "settings.json merge failed"
fi

if [ ! -d ~/.fzf ]; then
  log "installing fzf"
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf \
    && ~/.fzf/install --key-bindings --completion --no-update-rc --no-zsh --no-fish \
    || log "fzf install failed"
fi
# The generated .fzf.bash APPENDS ~/.fzf/bin to PATH, so an older fzf in
# the image (debian 0.44 has no --bash flag) shadows the fresh one and
# `eval "$(fzf --bash)"` errors on every shell. Prepend instead.
[ -f ~/.fzf.bash ] && sed -i 's|PATH="${PATH:+${PATH}:}\(.*/\.fzf/bin\)"|PATH="\1${PATH:+:${PATH}}"|' ~/.fzf.bash
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
  # Hugging Face: write the token where every HF library looks
  # ($HF_HOME/token, default ~/.cache/huggingface/token) rather than
  # relying on the env var, so `hf download`, transformers and vllm all
  # see it in ssh shells, kubectl exec and inside docker-compose alike.
  # Gated repos (Llama, some Qwen) 401 without it; ungated ones work, so
  # the failure only shows up on the model you actually wanted.
  if [ -n "${HF_TOKEN:-}" ]; then
    hf_home="${HF_HOME:-$HOME/.cache/huggingface}"
    mkdir -p "$hf_home"
    printf '%s' "$HF_TOKEN" > "$hf_home/token"
    chmod 600 "$hf_home/token"
  fi
  if [ -n "${DOCKERHUB_TOKEN:-}" ] && command -v docker >/dev/null 2>&1; then
    echo "$DOCKERHUB_TOKEN" | docker login -u "${DOCKERHUB_USER:-}" --password-stdin \
      >/dev/null 2>&1 || log "docker login failed (daemon not up yet?)"
  fi
else
  log "no ~/.env — skipping GitHub/HF/Docker logins (rsync env.secrets over when needed)"
fi

log "done"
exit 0
