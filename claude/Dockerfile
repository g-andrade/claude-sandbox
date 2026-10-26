# Sandbox layer, built on top of a project's toolchain image (BASE): Claude
# Code, the tools it needs, and an account for the host user. Isolation
# doesn't rely on anything in this image: compose.yaml fixes the user and
# capabilities, and the claude-net container holds the firewall. That's what
# lets a project pick any base image.
ARG BASE
FROM claude-sandbox-cli AS cli

FROM ${BASE}
ARG LIBC
ARG HOST_UID
ARG HOST_GID
# 1 on glibc (Claude Code's bundled ripgrep), 0 on musl (the system one).
ARG BUILTIN_RIPGREP

USER root
COPY claude/install-layer /tmp/install-layer
RUN sh /tmp/install-layer "$LIBC" "$HOST_UID" "$HOST_GID" && rm /tmp/install-layer
COPY --from=cli /opt/claude/${LIBC}/claude /usr/local/bin/claude
ENV USE_BUILTIN_RIPGREP=${BUILTIN_RIPGREP}
