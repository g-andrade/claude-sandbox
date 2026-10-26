# The Claude Code binary in its glibc and musl builds, from the official
# release channel, checksum-verified. Only a COPY source for the sandbox layer
# (claude/Dockerfile). Update by rebuilding: sandbox rebuild
FROM alpine:3.22 AS fetch
ARG CLAUDE_CODE_VERSION=latest
RUN apk add --no-cache curl jq
COPY cli/fetch /usr/local/bin/fetch
RUN fetch "$CLAUDE_CODE_VERSION"

FROM scratch
COPY --from=fetch /opt/claude /opt/claude
