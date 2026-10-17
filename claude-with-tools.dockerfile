# syntax=docker/dockerfile:1.7
# Claude Code + Java 25, Maven, Ruby, RTK, Playwright CLI (Chromium)
FROM docker/sandbox-templates:claude-code-docker

ARG TARGETARCH
ARG JAVA_MAJOR=25
ARG MAVEN_VERSION=3.9.11
ARG PLAYWRIGHT_BROWSERS="chromium"

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Java (Ubuntu build: uses system cacerts, so it trusts the sandbox proxy CA) + Ruby
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      "openjdk-${JAVA_MAJOR}-jdk-headless" ca-certificates-java \
      ruby-full build-essential libyaml-dev libffi-dev zlib1g-dev unzip \
 && JDK="/usr/lib/jvm/java-${JAVA_MAJOR}-openjdk-$(dpkg --print-architecture)" \
 && ln -sfn "$JDK" /usr/lib/jvm/java-current \
 && for t in java javac jar jshell keytool; do update-alternatives --set "$t" "$JDK/bin/$t" || true; done \
 && rm -rf /var/lib/apt/lists/*

# Maven (checksum-verified) + proxy shim
RUN url="https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
 && curl -fsSLo /tmp/m.tgz "$url" && curl -fsSLo /tmp/m.sha "$url.sha512" \
 && echo "$(cut -d' ' -f1 /tmp/m.sha)  /tmp/m.tgz" | sha512sum -c - \
 && mkdir -p /opt/maven && tar -xzf /tmp/m.tgz -C /opt/maven --strip-components=1 \
 && ln -sf /opt/maven/bin/mvn /usr/local/bin/mvn && rm -f /tmp/m.*
COPY files/mavenrc /etc/mavenrc

# RTK binary (hook is registered at sandbox creation, see claude-with-tools.yaml)
RUN case "$TARGETARCH" in \
      amd64) t=x86_64-unknown-linux-musl ;; arm64) t=aarch64-unknown-linux-gnu ;; \
      *) echo "unsupported arch $TARGETARCH" >&2; exit 1 ;; esac \
 && mkdir /tmp/rtk \
 && curl -fsSL "https://github.com/rtk-ai/rtk/releases/latest/download/rtk-$t.tar.gz" | tar -xz -C /tmp/rtk \
 && install -m 0755 "$(find /tmp/rtk -type f -name rtk | head -n1)" /usr/local/bin/rtk \
 && rm -rf /tmp/rtk

ENV JAVA_HOME=/usr/lib/jvm/java-current \
    MAVEN_HOME=/opt/maven \
    NPM_CONFIG_PREFIX=/usr/local/share/npm-global \
    GEM_HOME=/home/agent/.local/share/gem \
    PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright \
    RTK_TELEMETRY_DISABLED=1 \
    IS_SANDBOX=1
ENV PATH=$JAVA_HOME/bin:$MAVEN_HOME/bin:$GEM_HOME/bin:$NPM_CONFIG_PREFIX/bin:/home/agent/.local/bin:$PATH

RUN mkdir -p "$NPM_CONFIG_PREFIX" "$GEM_HOME" "$PLAYWRIGHT_BROWSERS_PATH" \
 && chown -R agent:agent "$NPM_CONFIG_PREFIX" /home/agent/.local

# Playwright CLI (as agent) + browsers & OS deps (as root, shared path)
USER agent
RUN npm install -g @playwright/cli@latest
USER root
RUN apt-get update \
 && for b in $PLAYWRIGHT_BROWSERS; do playwright-cli install-browser --with-deps "$b"; done \
 && chmod -R a+rX "$PLAYWRIGHT_BROWSERS_PATH" \
 && rm -rf /var/lib/apt/lists/*

# Claude Code — last layer so a version bump rebuilds only this
USER agent
ARG CLAUDE_VERSION=stable
RUN curl -fsSL https://claude.ai/install.sh | bash -s -- "$CLAUDE_VERSION" \
 && claude --version

# Smoke test + launch
WORKDIR /home/agent/workspace
RUN docker --version && java -version && mvn -v && ruby -v && rtk --version && playwright-cli --help >/dev/null
ENTRYPOINT ["claude", "--dangerously-skip-permissions"]
CMD []
