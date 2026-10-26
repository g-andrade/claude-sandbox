# AGENTS.md

Template for per-project Claude Code sandboxes: Docker containers whose only
network path out is a domain-allowlisting proxy, with nftables egress
firewalls, and a toolchain image each project picks. `claude-sandbox` (bash) creates
and manages one instance per project. See README.md for the user-facing view.

## Layout

- `claude-sandbox`: the CLI; all instance logic lives here.
- `compose.yaml`: one instance, parameterised by `instances/<id>/instance.env`
  plus `HOST_UID`/`HOST_GID` from `claude-sandbox`. Services: `claude` (the project's
  image, untrusted), `claude-net` (owns claude's network namespace), `proxy`,
  `devport`.
- `claude/Dockerfile`, `claude/install-layer`: the sandbox layer, built on top
  of each project's toolchain image. Installs packages with apt, apk or dnf,
  copies in the Claude binary for the image's libc, adds the host user.
- `cli/`: the `claude-sandbox-cli` image, holding the Claude Code binary for
  glibc and musl, downloaded and checksum-verified from the release channel.
- `proxy/`: the trusted image (Alpine: Squid, socat, nftables) behind
  `claude-net`, `proxy` and `devport`; Squid config; the shared `allowlist.txt`.
- `firewall/sandbox-init`: entrypoint of the trusted containers. Loads the
  egress rules for a role, then drops to an unprivileged user.
- `.dockerignore`: shared images build with the repo root as context; only
  the files they COPY are sent.
- `instances/<id>/`: per-project state (gitignored): `instance.env`, the
  approved copies `allowlist.approved.txt` and `Dockerfile.approved`, and
  `image.stamp` (what the project's image was last built from).
- `.env`: shared secrets (gitignored). `.env.example` is its template.
- `.github/workflows/shellcheck.yml`: CI, runs the shellcheck command below.

## Security invariants

Every change must keep these true. `claude-sandbox verify` checks most of them.

- The claude image is untrusted: projects choose its base, so isolation must
  never depend on its contents. Its user (the host UID), `cap_drop: [ALL]`
  with no `cap_add`, `no-new-privileges`, entrypoint, mounts and network all
  come from `compose.yaml`. Never exec into it as root to run Claude.
- claude has no network of its own: it joins `claude-net`'s namespace, which
  is only on the `internal` network and whose firewall allows only the proxy.
- Only `PROJECT_DIR` is mounted into the claude container: never this repo,
  `instances/`, the Docker socket, `~/.ssh` or host credentials.
- `.git` and `.claude-sandbox` are read-only mount points inside the container.
  Overlaying only parts of `.git` isn't enough (`.git` could be renamed and
  replaced). `.claude-sandbox` and the files in it must not be symlinks.
- The sandbox only uses the approved copies of `.claude-sandbox/allowlist.txt` and
  `.claude-sandbox/Dockerfile` in `instances/<id>/`, which change only after an
  interactive approval on the host. Allowlist entries need at least two
  labels (no `.` or `.com`). The toolchain builds from the approved
  Dockerfile alone, with no build context.
- In `squid.conf`, `deny !allowed_domains` stays before any ACL that resolves
  DNS (`dst`), so names that aren't allowlisted are never looked up.
- The trusted containers run `sandbox-init`: default-deny egress in their own
  network namespace, then `setpriv` to a non-root user with an empty
  capability bounding set. Their added capabilities (`NET_ADMIN`, `SETUID`,
  `SETGID`, `SETPCAP`) exist only for that step. `sandbox-init` must fail
  closed (`set -eu`, so the container exits if rules don't load) and must
  never flush the ruleset, since Docker's DNS NAT rules share the namespace.
- Don't add domains to `proxy/allowlist.txt` without the user's explicit OK.

## Working on this repo

- Test against real instances in throwaway git repos (not the user's
  projects): `claude-sandbox up`, `claude-sandbox verify`, then `claude-sandbox rm`. Prompts need a
  terminal; in tests use `printf 'y\n' | script -qec "claude-sandbox ..." /dev/null`.
- Changes to the sandbox layer should be tried on Debian, Alpine and Fedora
  bases (e.g. `debian:trixie-slim`, `python:3.13-alpine`, `fedora:42`).
- After changing `proxy/`, `cli/` or `firewall/`, rebuild: `claude-sandbox build`.
  Project images rebuild by themselves when the layer or CLI image changes.
- For a new firewall check in `verify`, confirm it fails without the firewall
  too (e.g. same image with `--entrypoint` overridden); a check that passes
  either way proves nothing.
- Shell scripts are kept shellcheck-clean (`claude-sandbox` is bash; the others are
  POSIX sh, since they run in Alpine and arbitrary toolchain images):
  `docker run --rm -v "$PWD:/mnt:ro" -w /mnt koalaman/shellcheck:v0.10.0 claude-sandbox firewall/sandbox-init claude/install-layer cli/fetch`
