## Sandbox toolchain

- Java 25 (`$JAVA_HOME`), Maven (proxy wired via `/etc/mavenrc`), Ruby + Bundler (`$GEM_HOME`).
- RTK rewrites Bash commands for compact output; use `rtk proxy <cmd>` for raw output.
- `playwright-cli` with headless Chromium preinstalled. See `playwright-cli --help`.
- Docker Engine runs inside the sandbox (Testcontainers, `docker build`, `spring-boot:build-image`). Images from Docker Hub are allowed; other registries may be blocked.
- `sudo` is passwordless.

Egress is allow-listed. If a download is blocked, report the host instead of retrying elsewhere.
Run the project's checks (e.g. `mvn -q verify`) before reporting a task done.
