---
name: Bug report
about: Tell us about a problem you are experiencing
title: ''
labels: ''
assignees: ''

---
**Checklist**

- [ ] I read the [README](https://github.com/hwdsl2/docker-ollama/blob/main/README.md) or the relevant section
- [ ] I searched existing [Issues](https://github.com/hwdsl2/docker-ollama/issues?q=is%3Aissue)
- [ ] This issue is about the Ollama Docker image/config, not only Ollama itself

<!---
If you found a reproducible bug in the upstream project itself, consider opening an issue upstream: [Ollama](https://github.com/ollama/ollama).
--->

**Describe the issue**
A clear and concise description of the problem.

**Deployment context**
- [ ] Standalone container
- [ ] Part of [docker-ai-stack](https://github.com/hwdsl2/docker-ai-stack)

**To Reproduce**
Steps to reproduce the behavior:

1. ...
2. ...

**Expected behavior**
A clear and concise description of what you expected to happen.

**Environment**
- Docker host OS: [e.g. Ubuntu 24.04]
- Hosting provider (if applicable): [e.g. AWS, GCP, home server]
- CPU architecture: [e.g. amd64, arm64]
- Image/tag: [e.g. `hwdsl2/ollama-server:latest`]
- Start method: [docker run / docker compose / other]
- Published port(s): [11434]

**Configuration**
Remove secrets, API keys, tokens and private URLs before posting.

- Env file or variables changed: [ollama.env / `-e` / compose `environment`]
- Docker run or compose changes:

**Service details**
- Model name(s) involved:
- Auth/API key behavior:
- Management command output, if relevant (for example `docker exec ollama ollama_manage --showinfo`):
- Public internet / reverse proxy setup, if relevant:
- GPU/CUDA image tag and NVIDIA driver/toolkit versions, if relevant:

**Logs**
Add relevant logs with secrets removed.

```bash
docker logs ollama
```

If using Docker Compose, you can also include:

```bash
docker compose logs ollama
```

**Additional context**
Add any other context about the problem here.
