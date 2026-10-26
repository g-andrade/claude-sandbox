# claude-sandbox

Per-project sandboxes for Claude Code: Docker containers whose only way out is
a domain-allowlisting proxy, backed by host nftables rules.

```
           internal network (no route out)                egress network
claude ───────────────────────────────────> proxy ──────────────────────> internet :80/:443
  ▲                                         (Squid allowlist)
  └───────────── devport (socat) <───────── host 127.0.0.1:<dev port>
```

- **One sandbox per project** (git repository), created on first use, each with
  its own containers, networks, Claude config/history and dev port.
- **claude** sits only on an internal Docker network, so it has no route out
  and no external DNS. It runs as your UID with all capabilities dropped. The
  only thing mounted is the project, at `/workspace`; `.git` and `.sandbox/`
  are read-only inside.
- **proxy** allows HTTP/HTTPS (ports 80/443) only to allowlisted domains,
  never to private IPs, and never resolves names that aren't allowlisted.
- **firewall/** is a host nftables backstop: one ruleset covers all sandboxes.

## Setup (once)

1. Load the firewall (persists across reboots): `sudo ~/claude-sandbox/firewall/install.sh`
2. Auth: run `claude setup-token` on the host and set `CLAUDE_CODE_OAUTH_TOKEN`
   in `~/claude-sandbox/.env` (or set `ANTHROPIC_API_KEY`).
3. Optional, to run `sandbox` from anywhere: `ln -s ~/claude-sandbox/sandbox ~/.local/bin/sandbox`

## Usage

From inside a project:

| Command | |
|---|---|
| `sandbox claude` | Start the project's sandbox and run Claude Code with `--dangerously-skip-permissions` |
| `sandbox shell` | Bash in the sandbox |
| `sandbox verify` | Check that allowed traffic works and everything else is blocked |
| `sandbox logs` | Follow the proxy log (every allowed and denied request) |
| `sandbox reload` | Apply allowlist changes |
| `sandbox info` | Settings file, dev server URL, allowlist paths |
| `sandbox down` / `rm` | Stop / delete the sandbox (`rm` also deletes Claude's config and history) |

From anywhere: `sandbox list`, `sandbox rm <id>`, `sandbox rebuild` (updates Claude Code).

## Allowlists

- **Shared:** `proxy/allowlist.txt` in this repo, for all sandboxes.
- **Per project:** `.sandbox/allowlist.txt` in the project, created on first
  use. It's read-only inside the sandbox, and the proxy only uses a copy you've
  approved. When the file differs from that copy, for example after an edit, a
  `git pull` or cloning someone else's repo, the next start or `sandbox reload`
  shows the diff and asks before applying it.

A request was blocked? Run `sandbox logs`, look for `TCP_DENIED`, add the
domain if you trust it, then `sandbox reload`.

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

Inside the sandbox, run the dev server on port 5173 with `--host` (e.g.
`npm run dev -- --host`). `sandbox info` shows the host URL; each project gets
its own port. To reach it from a phone, set `DEV_BIND=0.0.0.0` in the
project's settings file (see `sandbox info`) and run `sandbox up`. iOS needs
HTTPS for service workers; run mkcert or a tunnel on the host, not in the
sandbox.

## Known limits

- Filtering is by hostname, without TLS inspection. Allowlisted CDNs (GitHub,
  Cloudflare-fronted npm) could in principle be used for domain fronting.
- With GitHub allowlisted, the sandbox can fetch from any repo. Remove it if
  you don't need it.
- Running the project's code on the host (npm scripts, tests, the dev server)
  runs code Claude may have written outside the sandbox. Run it inside with
  `sandbox shell` instead.
- Git repositories Claude creates inside the project (a nested `.git`) aren't
  protected. Don't run git, or an editor's git integration, in them on the host.
- `/login` doesn't work inside, since its OAuth domains aren't allowlisted. Use
  `setup-token` or an API key.
- Approvals need a terminal. That stops anything inside the sandbox, not a
  process on the host that has a terminal of its own.
