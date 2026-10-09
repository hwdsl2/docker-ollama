[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# InferCrate

**Open-source, self-hosted local LLM server.**

[![Build Status](https://github.com/hwdsl2/infercrate/actions/workflows/main.yml/badge.svg)](https://github.com/hwdsl2/infercrate/actions/workflows/main.yml) &nbsp;[![Docker Pulls](https://raw.githubusercontent.com/hwdsl2/badges/main/img/docker-pulls-ollama-server.svg)](https://hub.docker.com/r/hwdsl2/ollama-server) &nbsp;[![License: MIT](docs/images/license.svg)](https://opensource.org/licenses/MIT)

Run local language models on your own hardware with InferCrate. Powered by [Ollama](https://github.com/ollama/ollama), it provides the native Ollama API and an OpenAI-compatible `/v1` API subset, with API-key authentication, model management, and CPU or NVIDIA GPU deployment.

Previously known as `docker-ollama`. The Docker image remains `hwdsl2/ollama-server`.

**Features:**

- **OpenAI-compatible API:** a `/v1` API subset for compatible OpenAI SDKs and apps, alongside the native Ollama API.
- **Secure by default:** Caddy enforces Bearer token authentication for API access; an API key is auto-generated on first start and stored in the persistent volume.
- **Model pre-pull:** pre-pull models on first start with the `OLLAMA_MODELS` environment variable.
- **Model management:** via a helper script (`ollama_manage`).
- **CPU and GPU support:** run on CPU or use the `:cuda` image for NVIDIA GPU acceleration.
- **Lightweight CPU image:** based on Debian Trixie (slim); approximately 75 MB.
- **Automated builds:** images are automatically built and published through [GitHub Actions](https://github.com/hwdsl2/infercrate/actions).

Also available as part of the [Self-Hosted AI Stack](https://github.com/hwdsl2/self-hosted-ai-stack), which deploys a complete self-hosted AI stack with a single command.

> 📘 [The Self-Hosted AI Builder’s Guide](https://books2read.com/aiguide?store=amazon) is a practical guide to building, securing, and operating your own private AI stack.

**Also available:**

- Related AI services: [ScribeCrate](https://github.com/hwdsl2/scribecrate), [SpeakCrate](https://github.com/hwdsl2/speakcrate), [EmbedCrate](https://github.com/hwdsl2/embedcrate), [GatewayCrate](https://github.com/hwdsl2/gatewaycrate), [ParseCrate](https://github.com/hwdsl2/parsecrate), [ToolUplink](https://github.com/hwdsl2/tooluplink)

## Quick start

**Step 1.** Start InferCrate:

```bash
docker run \
    --name ollama \
    --restart=always \
    -v ollama-data:/var/lib/ollama \
    -p 11434:11434/tcp \
    -d hwdsl2/ollama-server
```

On first start, an API key is auto-generated and displayed in the container logs. All API requests require this key.

> [!NOTE]
> For internet-facing deployments, use a [reverse proxy](#using-a-reverse-proxy) to add HTTPS. Also replace `-p 11434:11434/tcp` with `-p 127.0.0.1:11434:11434/tcp` in the `docker run` command above, to prevent direct access to the unencrypted port.

**Step 2.** Get the API key:

```bash
# View the key in the container logs
docker logs ollama

# Or retrieve it for use in scripts
infer_api_key="$(docker exec ollama ollama_manage --getkey)"
```

The API key is displayed in a box labeled **InferCrate API key**. To display it again at any time:

```bash
docker exec ollama ollama_manage --showkey
```

**Step 3.** Pull a model:

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

**Tip:** To pull one or more models automatically on first start, set `OLLAMA_MODELS` before running the container:

```bash
docker run \
    --name ollama \
    --restart=always \
    -v ollama-data:/var/lib/ollama \
    -p 11434:11434/tcp \
    -e OLLAMA_MODELS=llama3.2:3b \
    -d hwdsl2/ollama-server
```

Or add `OLLAMA_MODELS=llama3.2:3b` to your `ollama.env` file (see [Environment variables](#environment-variables)).

**Step 4.** Test with the API:

```bash
infer_api_key="$(docker exec ollama ollama_manage --getkey)"

# List models
curl http://localhost:11434/api/tags \
  -H "Authorization: Bearer $infer_api_key"

# Chat completion (streaming)
curl http://localhost:11434/api/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $infer_api_key" \
  -d '{"model": "llama3.2:3b", "messages": [{"role": "user", "content": "Hello!"}]}'
```

**Note:** The `docker exec` management commands (`ollama_manage`) do not require the API key.

To learn more about how to use this image, read the sections below.

## Community

- 📬 [Get project updates and free deployment guides](https://selfhostedstack.beehiiv.com/subscribe?utm_campaign=ai) (1–2 emails/month)
- 💬 Join the [r/selfhostedstack](https://www.reddit.com/r/selfhostedstack/) community for discussions and showcases
- ⭐ Star the repository if you find it useful — it helps others discover it

<details>
<summary>Self-hosted VPN & networking projects</summary>

- [Setup IPsec VPN](https://github.com/hwdsl2/setup-ipsec-vpn)
- [IPsec VPN on Docker](https://github.com/hwdsl2/docker-ipsec-vpn-server)
- [WireGuard](https://github.com/hwdsl2/docker-wireguard)
- [OpenVPN](https://github.com/hwdsl2/docker-openvpn)
- [Headscale](https://github.com/hwdsl2/docker-headscale)

</details>

## Requirements

- A Linux server (local or cloud) with Docker installed
- Sufficient disk space for models (3B models ≈ 2GB, 7B models ≈ 4–5GB, 14B+ models ≈ 8–10GB+)
- Sufficient RAM to run models (3B models ≈ 2–4GB, 7B models ≈ 6–8GB, 14B+ models ≈ 12–16GB+)
- TCP port 11434 (or your configured port) accessible

**For GPU acceleration (`:cuda` image):**

- NVIDIA GPU with CUDA support
- [NVIDIA driver](https://www.nvidia.com/en-us/drivers/) 575.57.08+ (Linux) or 576.57+ (Windows) installed on the host
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) installed
- The `:cuda` image supports `linux/amd64` only

## Download

Get the trusted build from the [Docker Hub registry](https://hub.docker.com/r/hwdsl2/ollama-server/):

```bash
docker pull hwdsl2/ollama-server
```

For GPU support:

```bash
docker pull hwdsl2/ollama-server:cuda
```

Alternatively, you may download from [Quay.io](https://quay.io/repository/hwdsl2/ollama-server):

```bash
docker pull quay.io/hwdsl2/ollama-server
docker image tag quay.io/hwdsl2/ollama-server hwdsl2/ollama-server
```

Supported platforms: `linux/amd64` and `linux/arm64`. The `:cuda` tag supports `linux/amd64` only.

## Environment variables

All variables are optional. If not set, secure defaults are used automatically.

This Docker image uses the following variables, that can be declared in an `env` file (see [example](ollama.env.example)):

| Variable | Description | Default |
|---|---|---|
| `OLLAMA_API_KEY` | API key for authenticating requests (auto-generated if not set) | Auto-generated |
| `OLLAMA_PORT` | TCP port for the API (1–65535) | `11434` |
| `OLLAMA_HOST` | Hostname or IP shown in startup info and `--showkey` output | Auto-detected |
| `OLLAMA_DEBUG` | Set to `1` to enable verbose debug logging | *(not set)* |
| `OLLAMA_MODELS` | Comma-separated models to pull on first start, e.g. `llama3.2:3b,qwen2.5:7b` | *(not set)* |
| `OLLAMA_MAX_LOADED_MODELS` | Max models kept loaded in memory simultaneously | *(Ollama default)* |
| `OLLAMA_NUM_PARALLEL` | Number of parallel request slots per model | *(Ollama default)* |
| `OLLAMA_CONTEXT_LENGTH` | Default context window size in tokens | *(Ollama default)* |
| `OLLAMA_DISABLE_USAGE_COUNTS` | Set to `1` to disable anonymous aggregate usage counts. | *(not set)* |

**Note:** In your `env` file, you may enclose values in single quotes, e.g. `VAR='value'`. Do not add spaces around `=`. If you change `OLLAMA_PORT`, update the `-p` flag in the `docker run` command accordingly.

Example using an `env` file:

```bash
cp ollama.env.example ollama.env
# Edit ollama.env and set your values, then:
docker run \
    --name ollama \
    --restart=always \
    -v ollama-data:/var/lib/ollama \
    -v ./ollama.env:/ollama.env:ro \
    -p 11434:11434/tcp \
    -d hwdsl2/ollama-server
```

## Model management

Use `docker exec` to manage models with the `ollama_manage` helper script. Models are stored in the Docker volume and persist across container restarts.

**List downloaded models:**

```bash
docker exec ollama ollama_manage --listmodels
```

**Pull a model:**

```bash
# Small, fast models (recommended for getting started)
docker exec ollama ollama_manage --pull llama3.2:3b
docker exec ollama ollama_manage --pull qwen2.5:7b

# Larger models (require more RAM/VRAM)
docker exec ollama ollama_manage --pull mistral:7b
docker exec ollama ollama_manage --pull phi4:14b
docker exec ollama ollama_manage --pull gemma3:12b
```

**Remove a model:**

```bash
docker exec ollama ollama_manage --remove llama3.2:3b
```

**Show running models and memory usage:**

```bash
docker exec ollama ollama_manage --status
```

**Update all models** (re-pulls latest versions):

```bash
docker exec ollama ollama_manage --update
```

**Show the API key:**

```bash
docker exec ollama ollama_manage --showkey
```

**Get the API key** (machine-readable, for use in scripts):

```bash
infer_api_key="$(docker exec ollama ollama_manage --getkey)"
```

**Pull models on first start** using the `OLLAMA_MODELS` variable in your `env` file:

```
OLLAMA_MODELS=llama3.2:3b,qwen2.5:7b
```

## Using the API

All API requests require a Bearer token. Retrieve the API key first:

```bash
infer_api_key="$(docker exec ollama ollama_manage --getkey)"
```

**Ollama API:**

```bash
# List models
curl http://localhost:11434/api/tags \
  -H "Authorization: Bearer $infer_api_key"

# Generate (streaming)
curl http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $infer_api_key" \
  -d '{"model": "llama3.2:3b", "prompt": "Why is the sky blue?"}'

# Chat completion (streaming)
curl http://localhost:11434/api/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $infer_api_key" \
  -d '{"model": "llama3.2:3b", "messages": [{"role": "user", "content": "Hello!"}]}'
```

**OpenAI-compatible API** (Ollama `/v1` subset; works with compatible OpenAI SDK and app workflows):

```bash
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $infer_api_key" \
  -d '{"model": "llama3.2:3b", "messages": [{"role": "user", "content": "Hello!"}]}'
```

**Python (OpenAI SDK):**

```python
from openai import OpenAI

client = OpenAI(
    api_key="<your-api-key>",
    base_url="http://localhost:11434/v1",
)

response = client.chat.completions.create(
    model="llama3.2:3b",
    messages=[{"role": "user", "content": "Hello!"}],
)
print(response.choices[0].message.content)
```

## Persistent data

All server data is stored in the Docker volume (`/var/lib/ollama` inside the container):

```
/var/lib/ollama/
├── models/           # Downloaded model files
├── .api_key          # API key (auto-generated, or synced from OLLAMA_API_KEY)
├── .initialized      # First-run marker
├── .port             # Saved port (used by ollama_manage)
└── .Caddyfile        # Generated Caddy config (auth proxy)
```

Back up the Docker volume to preserve your models and API key.

## Using docker-compose

```bash
cp ollama.env.example ollama.env
# Edit ollama.env and set your values, then:
docker compose up -d
docker logs ollama
```

Example `docker-compose.yml` (already included):

```yaml
services:
  ollama:
    image: hwdsl2/ollama-server
    container_name: ollama
    restart: always
    ports:
      - "11434:11434/tcp"  # For a host-based reverse proxy, change to "127.0.0.1:11434:11434/tcp"
    volumes:
      - ollama-data:/var/lib/ollama
      - ./ollama.env:/ollama.env:ro

volumes:
  ollama-data:
    name: ollama-data
```

> [!NOTE]
> For internet-facing deployments, use a [reverse proxy](#using-a-reverse-proxy) to add HTTPS. Also change `"11434:11434/tcp"` to `"127.0.0.1:11434:11434/tcp"` in `docker-compose.yml`, to prevent direct access to the unencrypted port.

### GPU acceleration (CUDA)

Use `docker-compose.cuda.yml` to run with NVIDIA GPU support:

```bash
docker compose -f docker-compose.cuda.yml up -d
```

**Requirements:** NVIDIA GPU, [NVIDIA driver](https://www.nvidia.com/en-us/drivers/) 575.57.08+ (Linux) or 576.57+ (Windows), and the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) installed on the host. The `:cuda` image is `linux/amd64` only.

## Using a reverse proxy

For internet-facing deployments, place a reverse proxy in front of Ollama to handle HTTPS termination. The server works without HTTPS on a local or trusted network, but HTTPS is recommended when the API endpoint is exposed to the internet.

Use one of the following addresses to reach the Ollama container from your reverse proxy:

- **`ollama:11434`** — if your reverse proxy runs as a container in the **same Docker network** as Ollama (e.g. defined in the same `docker-compose.yml`).
- **`127.0.0.1:11434`** — if your reverse proxy runs **on the host** and port `11434` is published (the default `docker-compose.yml` publishes it).

**Note:** The `Authorization: Bearer` header passes through reverse proxies automatically — no special configuration needed.

**Example with [Caddy](https://caddyserver.com/docs/) ([Docker image](https://hub.docker.com/_/caddy))** (automatic TLS via Let's Encrypt, reverse proxy in the same Docker network):

`Caddyfile`:
```
ollama.example.com {
  reverse_proxy ollama:11434
}
```

**Example with nginx** (reverse proxy on the host):

```nginx
server {
    listen 443 ssl;
    server_name ollama.example.com;

    ssl_certificate     /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass         http://127.0.0.1:11434;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;       # required for streaming responses
        proxy_read_timeout 300s;
        proxy_buffering    off;
    }
}
```

After setting up a reverse proxy, set `OLLAMA_HOST=ollama.example.com` in your `env` file so that the correct endpoint URL is shown in the startup logs and `ollama_manage --showkey` output.

## Update Docker image

To update the Docker image and container:

```bash
docker pull hwdsl2/ollama-server
docker rm -f ollama
# Then re-run the docker run command from Quick start with the same volume.
```

Your downloaded models are preserved in the `ollama-data` volume.

## Using with other AI services

Ollama can be used as the local LLM service in a broader self-hosted AI setup.

For full and lightweight Docker Compose stacks, manual `docker run` examples, and voice/RAG/MCP pipeline examples with SpeakCrate, EmbedCrate, GatewayCrate, InferCrate, ParseCrate, and ToolUplink, see [Self-Hosted AI Stack](https://github.com/hwdsl2/self-hosted-ai-stack).

**Connect Ollama to LiteLLM:**

```bash
# In docker-litellm, add Ollama as a model provider:
docker exec litellm litellm_manage \
  --addmodel ollama/llama3.2:3b \
  --base-url http://ollama:11434
```

## Usage counts

This image uses public GitHub release asset download counts for anonymous, aggregate usage counts. Counts are approximate and are not unique users or active installs. The image does not send a telemetry payload or use a private collector. It only attempts the best-effort count after the server starts successfully with a mounted `/var/lib/ollama` volume, and again when that persistent install first runs a different image build. To opt out, set `OLLAMA_DISABLE_USAGE_COUNTS=1`.

## Technical details

- Base image: `debian:trixie-slim` for `:latest`; `nvidia/cuda` for `:cuda`
- Image size: ~75MB (CPU) / ~1.7GB (CUDA)
- Ollama: latest release, installed as a static binary
- Auth proxy: [Caddy](https://caddyserver.com) (always active, enforces Bearer token auth)
- Data directory: `/var/lib/ollama` (Docker volume)
- Model storage: `/var/lib/ollama/models` inside the volume
- Ollama API: `http://localhost:11434` (or your configured port)
- OpenAI-compatible API: `http://localhost:11434/v1`

## License

**Note:** The software components inside the pre-built image (such as Ollama, Caddy, and their dependencies) are under the respective licenses chosen by their respective copyright holders. As for any pre-built image usage, it is the image user's responsibility to ensure that any use of this image complies with any relevant licenses for all software contained within.

Copyright (C) 2026 Lin Song   
This work is licensed under the [MIT License](https://opensource.org/licenses/MIT).

**Ollama** is Copyright (C) 2023 Ollama, and is distributed under the [MIT License](https://github.com/ollama/ollama/blob/main/LICENSE).

**Caddy** is Copyright (C) 2015 Matthew Holt and The Caddy Authors, and is distributed under the [Apache License 2.0](https://github.com/caddyserver/caddy/blob/master/LICENSE).

This project is an independent Docker setup for Ollama and is not affiliated with, endorsed by, or sponsored by Ollama.
