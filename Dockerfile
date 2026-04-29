#
# Copyright (C) 2026 Lin Song <linsongui@gmail.com>
#
# This work is licensed under the MIT License
# See: https://opensource.org/licenses/MIT

FROM debian:trixie-slim

WORKDIR /opt/src

RUN set -x \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
         ca-certificates curl jq \
    && ARCH=$(uname -m) \
    && if [ "$ARCH" = "x86_64" ]; then ARCH_LABEL="amd64"; \
       elif [ "$ARCH" = "aarch64" ]; then ARCH_LABEL="arm64"; \
       else echo "Unsupported architecture: $ARCH" >&2; exit 1; fi \
    && OLLAMA_VER=$(curl -fsSL "https://api.github.com/repos/ollama/ollama/releases/latest" \
         | jq -r '.tag_name') \
    && curl -fsSL "https://github.com/ollama/ollama/releases/download/${OLLAMA_VER}/ollama-linux-${ARCH_LABEL}.tar.zst" \
         -o /tmp/ollama.tar.zst \
    && apt-get install -y --no-install-recommends zstd \
    && mkdir -p /usr/local/lib/ollama \
    && tar -I zstd -xf /tmp/ollama.tar.zst -C /usr/local bin lib \
    && chmod 755 /usr/local/bin/ollama \
    && rm -f /tmp/ollama.tar.zst \
    && find /usr/local/lib/ollama -mindepth 1 -maxdepth 1 -type d \
         ! -name 'cpu*' -exec rm -rf {} + \
    && CADDY_VER=$(curl -fsSL "https://api.github.com/repos/caddyserver/caddy/releases/latest" \
         | jq -r '.tag_name' | tr -d 'v') \
    && curl -fsSL "https://github.com/caddyserver/caddy/releases/download/v${CADDY_VER}/caddy_${CADDY_VER}_linux_${ARCH_LABEL}.tar.gz" \
         -o /tmp/caddy.tar.gz \
    && tar -xzf /tmp/caddy.tar.gz -C /usr/local/bin caddy \
    && chmod 755 /usr/local/bin/caddy \
    && rm -f /tmp/caddy.tar.gz \
    && apt-get purge -y jq zstd \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/lib/ollama

COPY ./run.sh /opt/src/run.sh
COPY ./manage.sh /opt/src/manage.sh
COPY ./LICENSE.md /opt/src/LICENSE.md
RUN chmod 755 /opt/src/run.sh /opt/src/manage.sh \
    && ln -s /opt/src/manage.sh /usr/local/bin/ollama_manage

EXPOSE 11434/tcp
VOLUME ["/var/lib/ollama"]
CMD ["/opt/src/run.sh"]

ARG BUILD_DATE
ARG VERSION
ARG VCS_REF
ENV IMAGE_VER=$BUILD_DATE

LABEL maintainer="Lin Song <linsongui@gmail.com>" \
    org.opencontainers.image.created="$BUILD_DATE" \
    org.opencontainers.image.version="$VERSION" \
    org.opencontainers.image.revision="$VCS_REF" \
    org.opencontainers.image.authors="Lin Song <linsongui@gmail.com>" \
    org.opencontainers.image.title="Ollama on Docker" \
    org.opencontainers.image.description="Docker image to run an Ollama local LLM server with secure-by-default API key authentication." \
    org.opencontainers.image.url="https://github.com/hwdsl2/docker-ollama" \
    org.opencontainers.image.source="https://github.com/hwdsl2/docker-ollama" \
    org.opencontainers.image.documentation="https://github.com/hwdsl2/docker-ollama"