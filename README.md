# dotfiles

My personal layer for Baseten MP dev pods. The devpod chart clones this
repo to `/root/dotfiles` and runs `./bootstrap.sh` on every pod boot
(set `dotfiles repo` to this repo in `intertubin`, or `dotfilesRepo` in
the chart values). Re-running is always safe: every step checks before
acting.

What each file is:

- `bootstrap.sh`: the installer. Copies the configs below into place,
  sets git identity, installs tools (uv, HF CLI, Claude Code, fzf), and,
  only when secrets are present, logs into GitHub and Docker Hub.
- `aliases.sh`: shell aliases (docker, gpus, disk) plus the `drun`
  helper, copied to `~/.aliases.sh` on every run so edits reach
  already-bootstrapped pods on their next boot.
- `tmux.conf`: copied to `~/.tmux.conf`.
- `env.secrets`: my tokens (GITHUB_TOKEN, DOCKERHUB_USER/DOCKERHUB_TOKEN).
  Laptop-only and gitignored; it reaches a pod by rsync (or paste it once
  as `~/.env`). Bootstrap skips the logins when it is absent. THIS REPO
  IS PUBLIC: nothing secret may ever be committed here.

Division of labor: the shared image carries the heavy stack (CUDA
userland, python, docker, the `code` CLI); the chart carries pod glue
(sshd, app-state symlinks to node storage, cache routing); this repo
carries only what I personally want in every pod. Project setup lives in
that project's own scripts; team-wide tools go into the image via PR.
