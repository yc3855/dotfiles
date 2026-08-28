# Runbook: getting my environment onto a pod

Everything here assumes the ssh alias exists (`intertubin pods ssh
<pod-name>` created it). Replace `POD` with the alias, e.g.
`yanc-dev-pod-b300`.

## Set up a fresh pod (the whole thing)

```bash
rsync -av ~/Documents/dotfiles/ POD:/root/dotfiles/
ssh POD 'cd /root/dotfiles && ./bootstrap.sh'
```

Done. New ssh logins have the aliases and tmux config; git commits carry my
identity; GitHub (and Docker Hub, if the token is filled in) are logged in.
Already-open shells do not pick up aliases; run `source ~/.bashrc` in them
or open a new one.

## Push an update to a pod that was already set up

Same two commands. bootstrap.sh is idempotent: re-running overwrites the
configs with the current versions and skips what is already done. This is
the only update path; pods never pull changes themselves.

## Change or add an alias

Edit `aliases.sh` here, then run the two commands above per pod you care
about. Do not edit `~/.aliases.sh` on a pod directly: the next bootstrap
overwrites it with the laptop copy.

## Credentials

Tokens live in `env.secrets` in this folder. It is gitignored, chmod 600,
and travels only by rsync; bootstrap installs it as `~/.env` on the pod and
runs the logins.

- Refresh the GitHub token: `gh auth token` on the laptop, paste the output
  into the `GITHUB_TOKEN=` line of `env.secrets`.
- Docker Hub: create an access token at hub.docker.com > Account Settings >
  Personal access tokens; fill `DOCKERHUB_USER` and `DOCKERHUB_TOKEN`.
- Never put a token in any other file here. This folder may become a public
  GitHub repo one day, and only the gitignore stands between `env.secrets`
  and that.

## Install Claude Code on a pod

Uncomment the `claude.ai/install.sh` line in bootstrap.sh, re-run the two
commands, then log in once on the pod (`claude` and follow the prompt).

## How it works (read once)

Two kinds of file ride along, and bootstrap treats them differently:

- Programs' config files (`tmux.conf`, `aliases.sh`): copied to the exact
  home paths where their programs look (`~/.tmux.conf`, `~/.aliases.sh`).
  Nothing "runs" them at bootstrap time; tmux reads its file at every tmux
  start, and every new bash reads `.bashrc`, which sources the aliases.
  That is why aliases feel like they need "re-running" per login: they live
  in the shell process's memory and die with it; the file on disk is the
  recipe each new shell cooks from.
- One-time actions (git identity, uv tools, logins): these write to disk,
  and `/root` is network storage, so they survive logouts and even pod
  recreation. Re-running just reconfirms them.

Layering: every pod is born with Pankaj's configs already applied. The
pod-creation hook (`REPO_FOR_DOTFILES`) clones a public GitHub repo and
runs its bootstrap; the default deploy points it at
pankajroark/generaldotfiles because this folder is not on GitHub. My
bootstrap then layers on top: it replaces `.tmux.conf`, overwrites the git
identity, and appends my block to his `.bashrc` (his lines stay
underneath). If shell behavior ever looks foreign, it is his base layer.

## Traps (each one bit us)

1. Fresh JuiceFS homes arrive mode 777, and sshd refuses logins to a
   world-writable home. New pods chmod 755 at boot; if ssh mysteriously
   rejects you on an old pod, `kubectl exec` in and `chmod 755 /root`.
2. `~/.env` is per pod home, and homes are per cluster. A new cluster means
   the secrets have not arrived until the first rsync + bootstrap there.
3. The `.bashrc` block is append-once (guarded by a marker), which is why
   aliases live in a separate always-recopied file. Adding lines to the
   block itself will NOT reach pods that already have the marker.
4. The pod image may lack `gh`; the credentials step then skips GitHub
   login silently (by design). Install gh or add it to bootstrap if needed.

## What deliberately does not happen

- Nothing runs automatically at pod creation from this folder; only
  Pankaj's repo does. Automation would require pushing this folder to
  GitHub and pointing `REPO_FOR_DOTFILES` at it in my release values.
- bootstrap never touches project code, GPU state, or anything outside
  `/root`; it is safe to run while work is in flight.
