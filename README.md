# claude-with-tools

Docker Sandbox (v3 kit) running Claude Code with:

- Java 25, Maven, Ruby/Bundler
- Docker Engine (Testcontainers, `docker build`)
- RTK (auto-rewrites Bash commands for compact output)
- Playwright CLI + headless Chromium

One kit, reused for every project: each project gets its own sandbox.

## Prerequisites (once)

```bash
sbx login                      # Docker account
sbx secret set anthropic       # Anthropic API key, kept on the host
```

Clone the kit to a fixed place:

```bash
git clone https://github.com/christ-off/claude-with-tools ~/sbx-kits/claude-with-tools
```

Update later with `git -C ~/sbx-kits/claude-with-tools pull`, then recreate sandboxes
that should pick up the change.

## Start a new sandbox

```bash
sbx run --name <project> ~/sbx-kits/claude-with-tools ~/code/<project>
```

- `--name`: sandbox name, used to reattach later.
- Last argument: project directory, mounted read-write at the same path.
  Omit it to mount the current directory.

First run:

1. `sbx` builds the kit image (several minutes; later runs reuse the build).
2. Approve the kit's request to use the `anthropic` secret.
3. RTK registers its Claude hook, then Claude Code starts in the project.

Variants:

```bash
# Work on a separate git clone (host repo untouched until you fetch/push)
sbx run --clone --name <project> ~/sbx-kits/claude-with-tools ~/code/<project>

# Create without attaching, attach later
sbx create --name <project> ~/sbx-kits/claude-with-tools ~/code/<project>
sbx run --name <project>

# More resources than the default 4 CPU / 8 GB
sbx run --name <project> --cpus 8 --memory 16g ~/sbx-kits/claude-with-tools ~/code/<project>
```

Optional shortcut in `~/.bashrc` / `~/.zshrc`:

```bash
cwt() { sbx run --name "$(basename "$1")" ~/sbx-kits/claude-with-tools "$1"; }
# cwt ~/code/my-api
```

## Check a new sandbox

```bash
sbx exec <project> bash -c 'java -version && mvn -v && ruby -v && docker info --format "{{.ServerVersion}}" && rtk init --show && playwright-cli --help >/dev/null && echo OK'
```

## Day-to-day

```bash
sbx run --name <project>            # reattach (from any directory)
sbx exec -it <project> bash         # shell inside the sandbox
sbx ls                              # list sandboxes
sbx stop <project>                  # stop (state kept)
sbx rm <project>                    # delete (project files on host are kept)
sbx ports <project> --publish 8080  # expose a port (e.g. Spring Boot on 8080)
```

State inside a sandbox (`~/.m2`, Docker images, Claude history) survives stop/start
and is lost on `sbx rm`.

## Network

Egress is allow-listed in `claude-with-tools.yaml` (Anthropic, Maven Central,
RubyGems, npm, Playwright CDN, GitHub, Docker Hub). If something is blocked:

```bash
sbx policy allow network "ghcr.io:443"     # quick, host-wide
```

or add the host to `claude-with-tools.yaml` (applies to sandboxes created afterwards).

## Updating

- **Claude Code**: unpinned; each sandbox auto-updates. Force: `sbx exec <project> claude update`.
  To hold a release, set `args.claude.default` to a version and recreate the sandbox.
- **Kit changes** (tools, versions, allowlist): edit the kit, then recreate:
  `sbx rm <project> && sbx run --name <project> ~/sbx-kits/claude-with-tools ~/code/<project>`.

## Files

| File | Purpose |
|---|---|
| `claude-with-tools.dockerfile` | Image: base `claude-code-docker` + tools |
| `claude-with-tools.yaml` | Kit descriptor: args, network, credential, RTK hook |
| `context.md` | Instructions given to Claude (CLAUDE.md) |
| `files/mavenrc` | Routes Maven through the sandbox proxy |
