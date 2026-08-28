# Yan's shell aliases — copied to ~/.aliases.sh by bootstrap.sh on every
# run, so edits here reach existing pods on the next bootstrap.

alias gpus='nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader'
alias disk='df -h /root /node-storage /workspace 2>/dev/null | tail -n +2'

# docker
alias d='docker'
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias dlf='docker logs -f'
alias dex='docker exec -it'          # dex <name> bash
alias dprune='docker system prune'

# docker compose (the engine stack)
alias dup='docker compose up -d'
alias dstop='docker compose down'
alias dcp='docker compose ps'
alias dcl='docker compose logs -f'

# the standard NVIDIA-release run: drun <image> <cmd>
drun() {
  docker run --rm --gpus all --network host \
    -v /root/.cache/huggingface:/root/.cache/huggingface "$@"
}
