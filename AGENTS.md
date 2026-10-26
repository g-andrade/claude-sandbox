# AGENTS.md

Template for per-project Claude Code sandboxes: Docker containers whose only
network path out is a domain-allowlisting proxy, each with its own nftables
egress firewall. `sandbox` (bash) creates and manages one instance per
project. See README.md for the user-facing view.

## Layout

- `sandbox`: the CLI; all instance logic lives here.
- `compose.yaml`: one instance, parameterised by `instances/<id>/instance.env`.
- `claude/Dockerfile`: the sandbox image (Claude Code, runs as the host UID).
- `proxy/`: Squid image and config, plus the shared `allowlist.txt`. The
  devport relay reuses this image for `socat`.
- `firewall/sandbox-init`: entrypoint of every container. Loads that
  container's egress rules, then drops to an unprivileged user.
- `.dockerignore`: images build with the repo root as context; only the files
  they COPY are sent.
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
- Every container's entrypoint is `sandbox-init`: default-deny egress in its
  own network namespace, then `setpriv` to a non-root user with an empty
  capability bounding set. The capabilities in `compose.yaml` (`NET_ADMIN`,
  `SETUID`, `SETGID`, `SETPCAP`) exist only for that step. `sandbox-init` must
  fail closed (`set -eu`, so the container exits if rules don't load) and must
  never flush the ruleset, since Docker's DNS NAT rules share the namespace.
- Claude only ever runs through `AS_NODE` in `sandbox`: as node, with no
  capabilities. Never as root, and not with plain `exec --user node`, which
  keeps the container's bounding set.
- Don't add domains to `proxy/allowlist.txt` without the user's explicit OK.

## Working on this repo

- Test against real instances in throwaway git repos (not the user's
  projects): `sandbox up`, `sandbox verify`, then `sandbox rm`. Prompts need a
  terminal; in tests use `printf 'y\n' | script -qec "sandbox ..." /dev/null`.
- After changing `proxy/`, `claude/` or `firewall/`, rebuild: `sandbox build`.
- For a new firewall check in `verify`, confirm it fails without the firewall
  too (e.g. same image with `--entrypoint` overridden); a check that passes
  either way proves nothing.
- Shell scripts are kept shellcheck-clean (`sandbox` is bash, `sandbox-init`
  is POSIX sh for Alpine):
  `docker run --rm -v "$PWD:/mnt:ro" -w /mnt koalaman/shellcheck:v0.10.0 sandbox firewall/sandbox-init`
