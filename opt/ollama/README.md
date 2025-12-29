# Environment variables

```bash
touch .env
echo OLLAMA_WEB_URL="ollama.docker.lan" >> .env
echo WEBUI_URL="openwebui.docker.lan" >> .env
echo WEBUI_SECRET_KEY="$(openssl rand -base64 32)" >> .env
```

# Ollama commands

```bash
docker compose -p ollama exec ollama ollama ps
docker compose -p ollama exec ollama ollama list
docker compose -p ollama exec ollama ollama pull some-model
```
