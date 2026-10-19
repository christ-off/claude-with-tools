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
sbx secret set anthropic       # console API key or Claude login; check with `sbx secret ls`
```

The credential stays on the host: the sandbox only holds a `proxy-managed`
placeholder and the sandbox proxy injects the real token on calls to Anthropic.
No `/login` is needed inside the sandbox (and don't set `ANTHROPIC_API_KEY` there).

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


## Check a new sandbox

```bash
sbx exec <project> bash -c 'java -version && mvn -v && ruby -v && docker info --format "{{.ServerVersion}}" && rtk init --show && playwright-cli --help >/dev/null && echo OK'

# credential is proxied: prints sk-ant-oat01-proxy-managed (OAuth) and no warning in Claude Code
sbx exec <project> bash -c "jq -r '.claudeAiOauth.accessToken' ~/.claude/.credentials.json"
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
- **Kit changes** (tools, versions, allowlist, credentials): edit the kit, then `sbx rm <project>`
  and start it again as above. Credentials are resolved at create, so a changed
  `anthropic` secret also needs a recreate.

## Files

| File | Purpose |
|---|---|
| `claude-with-tools.dockerfile` | Image: base `claude-code-docker` + tools |
| `claude-with-tools.yaml` | Kit descriptor: args, network, credential, RTK hook |
| `context.md` | Instructions given to Claude (CLAUDE.md) |
| `files/mavenrc` | Routes Maven through the sandbox proxy |
