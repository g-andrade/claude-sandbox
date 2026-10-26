# claude-sandbox

Per-project sandboxes for Claude Code: Docker containers whose only way out is
a domain-allowlisting proxy, with nftables egress firewalls, and a toolchain
image of each project's choosing.

```
           internal network (no route out)                egress network
claude ───────────────────────────────────> proxy ──────────────────────> internet :80/:443
(in claude-net's network namespace)         (Squid allowlist)
  ▲
  └───────────── devport (socat) <───────── host 127.0.0.1:<dev port>
```

- **One sandbox per project** (git repository), created on first use, each with
  its own containers, networks, home directory and dev port.
- **claude** runs the project's own image: any base with a shell and apt, apk or
  dnf (Debian, Ubuntu, Alpine, Fedora, ...), with Claude Code added on top. The
  image is untrusted. Claude runs as your UID with no capabilities, set by
  `compose.yaml`, not the image. The only thing mounted is the project, at
  `/workspace`; `.git` and `.sandbox/` are read-only inside.
- **claude-net** is a small trusted container that owns claude's network
  namespace: only on an internal Docker network (no route out, no external
  DNS), with a firewall that lets it reach the proxy and nothing else.
- **proxy** allows HTTP/HTTPS (ports 80/443) only to allowlisted domains,
  never to private IPs, and never resolves names that aren't allowlisted.
- **The trusted containers** (claude-net, proxy, devport) each load their
  firewall at startup, then drop to a non-root user with no capabilities, so
  nothing running in them can change the rules. They report healthy only once
  their rules are loaded.

Nothing is installed on the host.

## Setup (once)

1. Auth: run `claude setup-token` on the host and set `CLAUDE_CODE_OAUTH_TOKEN`
   in `~/claude-sandbox/.env` (or set `ANTHROPIC_API_KEY`). The file is created
   from `.env.example` on first run; copy it yourself to set the token first.
2. Optional, to run `sandbox` from anywhere: `ln -s ~/claude-sandbox/sandbox ~/.local/bin/sandbox`

## Usage

From inside a project:

| Command | |
|---|---|
| `sandbox claude` | Start the project's sandbox and run Claude Code with `--dangerously-skip-permissions` |
| `sandbox shell` | Bash in the sandbox |
| `sandbox up` | Start it, rebuilding its image if the toolchain changed |
| `sandbox verify` | Check that allowed traffic works and everything else is blocked |
| `sandbox logs` | Follow the proxy log (every allowed and denied request) |
| `sandbox reload` | Apply allowlist changes |
| `sandbox info` | Settings file, dev server URL, toolchain and allowlist paths |
| `sandbox down` / `rm` | Stop / delete the sandbox (`rm` also deletes its home directory) |

From anywhere: `sandbox list`, `sandbox rm <id>`, `sandbox rebuild` (updates
Claude Code and base images; each sandbox rebuilds on its next start).

## Project files

`sandbox` creates `.sandbox/` in the project on first use. Both files are
read-only inside the sandbox, and the sandbox only uses copies you've
approved. When a file differs from its approved copy, for example after an
edit, a `git pull` or cloning someone else's repo, the next start shows the
diff and asks before applying it.

**`.sandbox/Dockerfile`** picks the toolchain. Often it's one line:

```dockerfile
FROM hexpm/elixir:1.20.4-erlang-28.5.0.8-debian-bookworm-20261005-slim
# or: FROM python:3.13-slim / FROM node:24-trixie-slim / FROM erlang:28-alpine
```

It builds without a context, so it can't COPY from the project; use `RUN` or
`COPY --from=<image>`. `sandbox` adds Claude Code (glibc or musl build, to
match), bash, git, curl and ripgrep, plus an account for you. Changes apply on
the next `sandbox up`. The default is plain `debian:trixie-slim`.

**`.sandbox/allowlist.txt`** adds domains for this project on top of the shared
`proxy/allowlist.txt` (just Anthropic and GitHub). Package registries go here:

| | |
|---|---|
| JavaScript | `registry.npmjs.org` |
| Python | `pypi.org` `files.pythonhosted.org` |
| Elixir/Erlang | `hex.pm` `repo.hex.pm` `builds.hex.pm` |

A request was blocked? Run `sandbox logs`, look for `TCP_DENIED`, add the
domain if you trust it, then `sandbox reload`.

The home directory (`/home/sandbox`) persists per sandbox, so Claude's config
and dependency caches (`~/.mix`, `~/.hex`, `~/.cache`, `~/.npm`) survive
restarts.

## Git

`.git` is read-only inside the sandbox. Claude can read history, status and
diffs, but can't commit, branch or stash, so you commit on the host after
reviewing. Git on the host executes things in `.git` (config such as
`core.fsmonitor`, hooks), so a writable `.git` would be a way out of the
sandbox. Protecting only `config` and `hooks` isn't enough, because `.git`
itself could then be renamed and replaced.

The project must be a git repository. `sandbox` offers to run `git init`
on the host if it isn't one.

## Dev server

Inside the sandbox, run the dev server on port 5173, listening on all
interfaces (e.g. `npm run dev -- --host`). `sandbox info` shows the host URL;
each project gets its own port. To reach it from a phone, set
`DEV_BIND=0.0.0.0` in the project's settings file (see `sandbox info`) and run
`sandbox up`. iOS needs HTTPS for service workers; run mkcert or a tunnel on
the host, not in the sandbox.

## Known limits

- Filtering is by hostname, without TLS inspection. Allowlisted CDNs (GitHub,
  Cloudflare-fronted registries) could in principle be used for domain
  fronting.
- With GitHub allowlisted, the sandbox can fetch from any repo. Remove it if
  you don't need it.
- The auth token is in the sandbox's environment, readable by anything that
  runs there, including dependencies' install scripts. It can only leave
  through allowlisted domains.
- Toolchain builds (`RUN` steps in `.sandbox/Dockerfile`) run with normal
  network access, outside the sandbox; that's why they need approval.
- Running the project's code on the host (npm scripts, tests, the dev server)
  runs code Claude may have written outside the sandbox. Run it inside with
  `sandbox shell` instead.
- Git repositories Claude creates inside the project (a nested `.git`) aren't
  protected. Don't run git, or an editor's git integration, in them on the host.
- `/login` doesn't work inside, since its OAuth domains aren't allowlisted. Use
  `setup-token` or an API key.
- Approvals need a terminal. That stops anything inside the sandbox, not a
  process on the host that has a terminal of its own.
- The firewalls live in the containers' network namespaces. Getting around
  them from inside would take a kernel exploit, which would defeat host-level
  rules as well.
