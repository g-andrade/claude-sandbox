FROM node:24-trixie-slim

ARG HOST_UID=1000
ARG HOST_GID=1000
ARG CLAUDE_CODE_VERSION=latest

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git jq less procps ripgrep unzip \
 && rm -rf /var/lib/apt/lists/*

# Match the host user so files written to /workspace keep your ownership.
RUN if [ "$HOST_GID" != "1000" ]; then groupmod -g "$HOST_GID" node; fi \
 && if [ "$HOST_UID" != "1000" ]; then usermod -u "$HOST_UID" -g "$HOST_GID" node; fi

# Installed root-owned, so nothing inside the sandbox can modify it.
# Update by rebuilding: sandbox rebuild
RUN npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
 && npm cache clean --force

RUN mkdir -p /workspace /home/node/.claude \
 && chown node:node /workspace /home/node/.claude

USER node
WORKDIR /workspace
