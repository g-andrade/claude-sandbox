# AGENTS.md

Template for per-project Claude Code sandboxes: Docker containers whose only
network path out is a domain-allowlisting proxy, backed by host nftables
rules. `sandbox` (bash) creates and manages one instance per project. See
README.md for the user-facing view.

## Layout

- `sandbox`: the CLI; all instance logic lives here.
- `compose.yaml`: one instance, parameterised by `instances/<id>/instance.env`.
- `claude/Dockerfile`: the sandbox image (Claude Code, runs as the host UID).
- `proxy/`: Squid image and config, plus the shared `allowlist.txt`. The
  devport relay reuses this image for `socat`.
- `firewall/`: host nftables backstop and its systemd unit.
- `instances/<id>/`: per-project state (gitignored): `instance.env` and
  `allowlist.approved.txt`, the copy the proxy actually reads.
- `.env`: shared secrets (gitignored). `.env.example` is its template.

## Security invariants

Every change must keep these true. `sandbox verify` checks most of them.

- The claude service is attached only to the `internal` network.
- Only `PROJECT_DIR` is mounted into the claude container: never this repo,
  `instances/`, the Docker socket, `~/.ssh` or host credentials.
- `.git` and `.sandbox` are read-only mount points inside the container.
  Overlaying only parts of `.git` isn't enough (`.git` could be renamed and
  replaced). The `.sandbox` source must not be a symlink.
- The proxy reads the project allowlist only from the approved copy in
  `instances/<id>/`, which changes only after an interactive approval on the
  host. Entries must have at least two labels (no `.` or `.com`).
- In `squid.conf`, `deny !allowed_domains` stays before any ACL that resolves
  DNS (`dst`), so names that aren't allowlisted are never looked up.
- nftables rules only drop, never accept, and match the `csi-*`/`cse-*`
  bridge names set in `compose.yaml`. Change both together.
- Containers run non-root with `cap_drop: [ALL]` and `no-new-privileges`.
- Don't add domains to `proxy/allowlist.txt` without the user's explicit OK.

## Working on this repo

- Test against real instances in throwaway git repos (not the user's
  projects): `sandbox up`, `sandbox verify`, then `sandbox rm`. Prompts need a
  terminal; in tests use `printf 'y\n' | script -qec "sandbox ..." /dev/null`.
- After changing `proxy/` or `claude/`, rebuild: `sandbox build`.
- Check firewall syntax without root: `unshare -rn nft -c -f firewall/claude-sandbox.nft`.
  Loading it needs `sudo firewall/install.sh`; ask the user to run that.
- Shell scripts: bash with `set -euo pipefail`, kept shellcheck-clean:
  `docker run --rm -v "$PWD:/mnt:ro" -w /mnt koalaman/shellcheck:v0.10.0 sandbox firewall/install.sh`
