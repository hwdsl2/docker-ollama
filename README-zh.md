[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# Docker 上的 Ollama

[![构建状态](https://github.com/hwdsl2/docker-ollama/actions/workflows/main.yml/badge.svg)](https://github.com/hwdsl2/docker-ollama/actions/workflows/main.yml) &nbsp;[![授权协议: MIT](docs/images/license.svg)](https://opensource.org/licenses/MIT)

用于运行 [Ollama](https://github.com/ollama/ollama) 本地大语言模型服务器的 Docker 镜像。提供与 OpenAI 兼容的 API，可在本地运行大型语言模型。基于 Debian Trixie（slim）。设计简单、私密，并默认安全。

**功能特性：**

- **默认安全** — 所有 API 请求均需 Bearer Token（首次启动时自动生成）
- 首次启动时自动生成 API 密钥，并存储在持久化卷中
- 通过 `OLLAMA_MODELS` 环境变量在首次启动时预先拉取模型
- 通过辅助脚本（`ollama_manage`）管理模型
- 与 OpenAI 兼容的 API — 只需修改一行即可将任何 OpenAI SDK 或应用指向本地服务器
- Caddy 反向代理对所有 API 请求强制执行 Bearer Token 认证（`/` 健康检查除外）
- NVIDIA GPU (CUDA) 加速推理（使用 `:cuda` 镜像标签）
- 通过 [GitHub Actions](https://github.com/hwdsl2/docker-ollama/actions/workflows/main.yml) 自动构建和发布
- 通过 Docker 卷持久化存储模型数据
- 轻量级镜像（约 70MB）；多架构：`linux/amd64`、`linux/arm64`

**另提供：**

- AI/音频：[Whisper (STT)](https://github.com/hwdsl2/docker-whisper/blob/main/README-zh.md)、[Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro/blob/main/README-zh.md)、[Embeddings](https://github.com/hwdsl2/docker-embeddings/blob/main/README-zh.md)、[LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh.md)
- VPN：[WireGuard](https://github.com/hwdsl2/docker-wireguard/blob/main/README-zh.md)、[OpenVPN](https://github.com/hwdsl2/docker-openvpn/blob/main/README-zh.md)、[IPsec VPN](https://github.com/hwdsl2/docker-ipsec-vpn-server/blob/master/README-zh.md)、[Headscale](https://github.com/hwdsl2/docker-headscale/blob/main/README-zh.md)

**提示：** Ollama、LiteLLM、Whisper、Kokoro 和 Embeddings 可以[协同使用](#与其他-ai-服务配合使用)，在您自己的服务器上构建完整的私有 AI 技术栈。

## 安全说明

约 175,000 台 Ollama 服务器被发现在未经认证的情况下公开暴露（[来源](https://www.sentinelone.com/labs/silent-brothers-ollama-hosts-form-anonymous-ai-network-beyond-platform-guardrails/)）。裸装的 Ollama 默认绑定到所有接口且无认证。本镜像通过内置认证代理对**所有 API 请求强制执行 Bearer Token 认证**，即使端口意外暴露，未授权访问也会被阻止。

## 快速开始

**第一步。** 启动 Ollama 服务器：

```bash
docker run \
    --name ollama \
    --restart=always \
    -v ollama-data:/var/lib/ollama \
    -p 11434:11434/tcp \
    -d hwdsl2/ollama-server
```

首次启动时，系统会自动生成 API 密钥并显示在容器日志中。所有 API 请求均需此密钥。

**注意：** 对于需要 HTTPS 的面向互联网部署，请参阅[使用反向代理](#使用反向代理)。

**第二步。** 获取 API 密钥：

```bash
# 在容器日志中查看密钥
docker logs ollama

# 或获取密钥以在脚本中使用
API_KEY=$(docker exec ollama ollama_manage --getkey)
```

API 密钥显示在标有 **Ollama API key** 的方框中。随时可以通过以下命令重新显示：

```bash
docker exec ollama ollama_manage --showkey
```

**第三步。** 拉取模型：

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

**提示：** 要在首次启动时自动拉取一个或多个模型，可在运行容器前设置 `OLLAMA_MODELS`：

```bash
docker run \
    --name ollama \
    --restart=always \
    -v ollama-data:/var/lib/ollama \
    -p 11434:11434/tcp \
    -e OLLAMA_MODELS=llama3.2:3b \
    -d hwdsl2/ollama-server
```

或在 `ollama.env` 文件中添加 `OLLAMA_MODELS=llama3.2:3b`（参见[环境变量](#环境变量)）。

**第四步。** 通过 API 测试：

```bash
API_KEY=$(docker exec ollama ollama_manage --getkey)

# 列出模型
curl http://localhost:11434/api/tags \
  -H "Authorization: Bearer $API_KEY"

# 对话补全（流式）
curl http://localhost:11434/api/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{"model": "llama3.2:3b", "messages": [{"role": "user", "content": "你好！"}]}'
```

**注意：** `docker exec` 管理命令（`ollama_manage`）不需要 API 密钥。

要了解有关如何使用此镜像的更多信息，请阅读以下各节。

## 系统要求

- 已安装 Docker 的 Linux 服务器（本地或云端）
- 足够的磁盘空间用于存储模型（3B 模型 ≈ 2GB，7B 模型 ≈ 4–5GB，14B+ 模型 ≈ 8–10GB+）
- 足够的内存以运行模型（3B 模型 ≈ 2–4GB，7B 模型 ≈ 6–8GB，14B+ 模型 ≈ 12–16GB+）
- TCP 端口 11434（或您配置的端口）需可访问

**GPU 加速（`:cuda` 镜像）要求：**

- 支持 CUDA 的 NVIDIA GPU
- 主机已安装 [NVIDIA 驱动](https://www.nvidia.com/en-us/drivers/)
- 已安装 [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
- `:cuda` 镜像仅支持 `linux/amd64`

## 下载

从 [Docker Hub 镜像仓库](https://hub.docker.com/r/hwdsl2/ollama-server/)获取可信构建版本：

```bash
docker pull hwdsl2/ollama-server
```

GPU 支持版本：

```bash
docker pull hwdsl2/ollama-server:cuda
```

或者从 [Quay.io](https://quay.io/repository/hwdsl2/ollama-server) 下载：

```bash
docker pull quay.io/hwdsl2/ollama-server
docker image tag quay.io/hwdsl2/ollama-server hwdsl2/ollama-server
```

支持平台：`linux/amd64` 和 `linux/arm64`。`:cuda` 标签仅支持 `linux/amd64`。

## 环境变量

所有变量均为可选。如果未设置，将自动使用安全默认值。

此 Docker 镜像使用以下变量，可在 `env` 文件中声明（参见[示例](ollama.env.example)）：

| 变量 | 说明 | 默认值 |
|---|---|---|
| `OLLAMA_API_KEY` | 用于认证请求的 API 密钥（未设置时自动生成） | 自动生成 |
| `OLLAMA_PORT` | API 的 TCP 端口（1–65535） | `11434` |
| `OLLAMA_HOST` | 在启动信息和 `--showkey` 输出中显示的主机名或 IP | 自动检测 |
| `OLLAMA_DEBUG` | 设置为 `1` 以启用详细调试日志 | *(未设置)* |
| `OLLAMA_MODELS` | 首次启动时拉取的模型（逗号分隔），例如 `llama3.2:3b,qwen2.5:7b` | *(未设置)* |
| `OLLAMA_MAX_LOADED_MODELS` | 同时保持加载在内存中的最大模型数 | *(Ollama 默认)* |
| `OLLAMA_NUM_PARALLEL` | 每个模型的并行请求槽数 | *(Ollama 默认)* |
| `OLLAMA_CONTEXT_LENGTH` | 默认上下文窗口大小（token 数） | *(Ollama 默认)* |

**注意：** 在 `env` 文件中，您可以将值用单引号括起来，例如 `VAR='value'`。不要在 `=` 两侧添加空格。如果您更改了 `OLLAMA_PORT`，请相应地更新 `docker run` 命令中的 `-p` 标志。

使用 `env` 文件的示例：

```bash
cp ollama.env.example ollama.env
# 编辑 ollama.env 并设置您的值，然后：
docker run \
    --name ollama \
    --restart=always \
    -v ollama-data:/var/lib/ollama \
    -v ./ollama.env:/ollama.env:ro \
    -p 11434:11434/tcp \
    -d hwdsl2/ollama-server
```

## 模型管理

使用 `docker exec` 通过 `ollama_manage` 辅助脚本管理模型。模型存储在 Docker 卷中，在容器重启后仍然保留。

**列出已下载的模型：**

```bash
docker exec ollama ollama_manage --listmodels
```

**拉取模型：**

```bash
# 小型、快速的模型（推荐入门使用）
docker exec ollama ollama_manage --pull llama3.2:3b
docker exec ollama ollama_manage --pull qwen2.5:7b

# 大型模型（需要更多内存/显存）
docker exec ollama ollama_manage --pull mistral:7b
docker exec ollama ollama_manage --pull phi4:14b
docker exec ollama ollama_manage --pull gemma3:12b
```

**删除模型：**

```bash
docker exec ollama ollama_manage --remove llama3.2:3b
```

**显示运行中的模型和内存使用情况：**

```bash
docker exec ollama ollama_manage --status
```

**更新所有模型**（重新拉取最新版本）：

```bash
docker exec ollama ollama_manage --update
```

**显示 API 密钥：**

```bash
docker exec ollama ollama_manage --showkey
```

**获取 API 密钥**（机器可读，用于脚本）：

```bash
API_KEY=$(docker exec ollama ollama_manage --getkey)
```

**在首次启动时拉取模型**，在 `env` 文件中使用 `OLLAMA_MODELS` 变量：

```
OLLAMA_MODELS=llama3.2:3b,qwen2.5:7b
```

## 使用 API

所有 API 请求均需 Bearer Token。首先获取 API 密钥：

```bash
API_KEY=$(docker exec ollama ollama_manage --getkey)
```

**Ollama API：**

```bash
# 列出模型
curl http://localhost:11434/api/tags \
  -H "Authorization: Bearer $API_KEY"

# 生成（流式）
curl http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{"model": "llama3.2:3b", "prompt": "天空为什么是蓝色的？"}'

# 对话补全（流式）
curl http://localhost:11434/api/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{"model": "llama3.2:3b", "messages": [{"role": "user", "content": "你好！"}]}'
```

**OpenAI 兼容 API**（适用于任何 OpenAI SDK 或应用）：

```bash
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{"model": "llama3.2:3b", "messages": [{"role": "user", "content": "你好！"}]}'
```

**Python（OpenAI SDK）：**

```python
from openai import OpenAI

client = OpenAI(
    api_key="<你的API密钥>",
    base_url="http://localhost:11434/v1",
)

response = client.chat.completions.create(
    model="llama3.2:3b",
    messages=[{"role": "user", "content": "你好！"}],
)
print(response.choices[0].message.content)
```

## 持久化数据

所有服务器数据存储在 Docker 卷中（容器内的 `/var/lib/ollama`）：

```
/var/lib/ollama/
├── models/           # 已下载的模型文件
├── .api_key          # API 密钥（自动生成，或从 OLLAMA_API_KEY 同步）
├── .initialized      # 首次运行标记
├── .port             # 保存的端口（供 ollama_manage 使用）
├── .server_addr      # 缓存的服务器地址（供 ollama_manage --showkey 使用）
└── .Caddyfile        # 生成的 Caddy 配置（认证代理）
```

备份 Docker 卷以保留您的模型和 API 密钥。

## 使用 docker-compose

```bash
cp ollama.env.example ollama.env
# 编辑 ollama.env 并设置您的值，然后：
docker compose up -d
docker logs ollama
```

`docker-compose.yml` 示例（已包含）：

```yaml
services:
  ollama:
    image: hwdsl2/ollama-server
    container_name: ollama
    restart: always
    ports:
      - "11434:11434/tcp"
    volumes:
      - ollama-data:/var/lib/ollama
      - ./ollama.env:/ollama.env:ro

volumes:
  ollama-data:
```

### GPU 加速（CUDA）

使用 `docker-compose.cuda.yml` 以 NVIDIA GPU 支持运行：

```bash
docker compose -f docker-compose.cuda.yml up -d
```

**要求：** NVIDIA GPU 以及主机上已安装 [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)。`:cuda` 镜像仅支持 `linux/amd64`。

## 使用反向代理

对于面向互联网的部署，在前面放置反向代理来处理 HTTPS。内置的 Caddy 认证代理处理认证；外部反向代理添加 TLS。使用以下地址之一访问 Ollama 容器：

- **`ollama:11434`** — 如果反向代理作为容器在同一 Docker 网络中运行
- **`127.0.0.1:11434`** — 如果反向代理在主机上运行且端口已发布

**注意：** `Authorization: Bearer` 头会自动通过反向代理传递，无需特殊配置。

**使用 [Caddy](https://caddyserver.com/docs/) 的示例（通过 Let's Encrypt 自动 TLS）：**

`Caddyfile`：
```
ollama.example.com {
  reverse_proxy ollama:11434
}
```

**使用 nginx 的示例（主机上的反向代理）：**

```nginx
server {
  listen 443 ssl;
  server_name ollama.example.com;

  ssl_certificate     /path/to/cert.pem;
  ssl_certificate_key /path/to/key.pem;

  location / {
    proxy_pass http://127.0.0.1:11434;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 300s;
    proxy_buffering off;
  }
}
```

设置反向代理后，在 `env` 文件中设置 `OLLAMA_HOST=ollama.example.com`，以便在启动日志和 `ollama_manage --showkey` 输出中显示正确的端点 URL。

## 更新 Docker 镜像

要更新 Docker 镜像和容器：

```bash
docker pull hwdsl2/ollama-server
docker rm -f ollama
# 然后使用相同的卷重新运行快速开始中的 docker run 命令。
```

您下载的模型保存在 `ollama-data` 卷中。

## 与其他 AI 服务配合使用

[Ollama](https://github.com/hwdsl2/docker-ollama)、[LiteLLM](https://github.com/hwdsl2/docker-litellm)、[Whisper (STT)](https://github.com/hwdsl2/docker-whisper)、[Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro) 和 [Embeddings](https://github.com/hwdsl2/docker-embeddings) 镜像可以组合在一起，在您自己的服务器上构建完整的私有 AI 技术栈——从语音输入/输出到 RAG 问答。Whisper、Kokoro 和 Embeddings 完全在本地运行。Ollama 在本地运行所有 LLM 推理，无需向第三方发送数据。使用 LiteLLM 接入外部提供商（如 OpenAI、Anthropic）时，您的数据将发送给这些提供商。

```mermaid
graph LR
    D["📄 文档"] -->|嵌入| E["Embeddings<br/>（文本 → 向量）"]
    E -->|存储| VDB["向量数据库<br/>（Qdrant、Chroma）"]
    A["🎤 音频输入"] -->|转录| W["Whisper<br/>（语音转文字）"]
    W -->|查询| E
    VDB -->|上下文| L["LiteLLM<br/>（AI 网关）"]
    W -->|文本| L
    L -->|路由到| O["Ollama<br/>（本地 LLM）"]
    L -->|响应| T["Kokoro TTS<br/>（文字转语音）"]
    T --> B["🔊 音频输出"]
```

| 服务 | 作用 | 默认端口 |
|---|---|---|
| **[Ollama](https://github.com/hwdsl2/docker-ollama)** | 运行本地 LLM 模型（llama3、qwen、mistral 等） | `11434` |
| **[LiteLLM](https://github.com/hwdsl2/docker-litellm)** | AI 网关 — 将请求路由到 Ollama、OpenAI、Anthropic 等 100+ 提供商 | `4000` |
| **[Embeddings](https://github.com/hwdsl2/docker-embeddings)** | 将文本转换为向量，用于语义搜索和 RAG | `8000` |
| **[Whisper（语音转文字）](https://github.com/hwdsl2/docker-whisper)** | 将语音音频转录为文本 | `9000` |
| **[Kokoro（文字转语音）](https://github.com/hwdsl2/docker-kokoro)** | 将文本转换为自然语音 | `8880` |

**将 Ollama 连接到 LiteLLM：**

```bash
# 在 docker-litellm 中，将 Ollama 添加为模型提供商：
docker exec litellm litellm_manage \
  --addmodel ollama/llama3.2:3b \
  --base-url http://ollama:11434
```

<details>
<summary><strong>语音管道示例</strong></summary>

将语音问题转录为文本，通过 Ollama 获取本地 LLM 响应，并转换为语音：

```bash
OLLAMA_KEY=$(docker exec ollama ollama_manage --getkey)
LITELLM_KEY=$(docker exec litellm litellm_manage --getkey)

# 第一步：将音频转录为文本（Whisper）
TEXT=$(curl -s http://localhost:9000/v1/audio/transcriptions \
    -F file=@question.mp3 -F model=whisper-1 | jq -r .text)

# 第二步：通过 LiteLLM 将文本发送给 Ollama 并获取响应
RESPONSE=$(curl -s http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer $LITELLM_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"ollama/llama3.2:3b\",\"messages\":[{\"role\":\"user\",\"content\":\"$TEXT\"}]}" \
    | jq -r '.choices[0].message.content')

# 第三步：将响应转换为语音（Kokoro TTS）
curl -s http://localhost:8880/v1/audio/speech \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"tts-1\",\"input\":\"$RESPONSE\",\"voice\":\"af_heart\"}" \
    --output response.mp3
```

</details>

<details>
<summary><strong>RAG 管道示例</strong></summary>

对文档进行向量化以实现语义搜索，检索上下文，然后用本地 Ollama 模型回答问题：

```bash
OLLAMA_KEY=$(docker exec ollama ollama_manage --getkey)
LITELLM_KEY=$(docker exec litellm litellm_manage --getkey)

# 第一步：对文档片段进行嵌入并将向量存入向量数据库
curl -s http://localhost:8000/v1/embeddings \
    -H "Content-Type: application/json" \
    -d '{"input": "Docker 通过将应用打包在容器中来简化部署。", "model": "text-embedding-ada-002"}' \
    | jq '.data[0].embedding'
# → 将返回的向量与原始文本一起存入 Qdrant、Chroma、pgvector 等。

# 第二步：查询时，对问题进行嵌入，从向量数据库检索最匹配的片段，
#          然后将问题和检索到的上下文发送给 Ollama（通过 LiteLLM）。
curl -s http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer $LITELLM_KEY" \
    -H "Content-Type: application/json" \
    -d '{
      "model": "ollama/llama3.2:3b",
      "messages": [
        {"role": "system", "content": "仅根据提供的上下文回答问题。"},
        {"role": "user", "content": "Docker 是做什么的？\n\n上下文：Docker 通过将应用打包在容器中来简化部署。"}
      ]
    }' \
    | jq -r '.choices[0].message.content'
```

</details>

<details>
<summary><strong>完整技术栈 docker-compose 示例</strong></summary>

```yaml
services:
  ollama:
    image: hwdsl2/ollama-server
    container_name: ollama
    restart: always
    volumes:
      - ollama-data:/var/lib/ollama
      - ./ollama.env:/ollama.env:ro

  litellm:
    image: hwdsl2/litellm-server
    container_name: litellm
    restart: always
    ports:
      - "127.0.0.1:4000:4000/tcp"
    volumes:
      - litellm-data:/etc/litellm
      - ./litellm.env:/litellm.env:ro

volumes:
  ollama-data:
  litellm-data:
```

</details>

## 技术细节

- 基础镜像：`debian:trixie-slim`（CPU）/ `nvidia/cuda:12.9.1-base-ubuntu24.04`（CUDA）
- 镜像大小：约 70MB（CPU）/ 约 3.2GB（CUDA）
- Ollama：最新版本，以静态二进制文件安装
- 认证代理：[Caddy](https://caddyserver.com)（始终启用，强制执行 Bearer Token 认证）
- 数据目录：`/var/lib/ollama`（Docker 卷）
- 模型存储：卷内的 `/var/lib/ollama/models`
- Ollama API：`http://localhost:11434`（或您配置的端口）
- OpenAI 兼容 API：`http://localhost:11434/v1`

## 许可协议

**注意：** 预构建镜像中的软件组件（如 Ollama、Caddy 及其依赖项）遵循其各自版权持有者选择的许可证。与任何预构建镜像的使用一样，镜像用户有责任确保对此镜像的任何使用均符合其中包含的所有软件的相关许可证。

版权所有 (C) 2026 Lin Song   
本作品基于 [MIT 许可证](https://opensource.org/licenses/MIT)授权。

**Ollama** 版权所有 (C) 2023 Ollama，基于 [MIT 许可证](https://github.com/ollama/ollama/blob/main/LICENSE)分发。

**Caddy** 版权所有 (C) 2015 Matthew Holt 和 Caddy 作者，基于 [Apache 许可证 2.0](https://github.com/caddyserver/caddy/blob/master/LICENSE) 分发。

本项目是 Ollama 的独立 Docker 配置，与 Ollama 没有任何关联、背书或赞助关系。
