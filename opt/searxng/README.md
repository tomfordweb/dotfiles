# Setup

```bash
touch .env
echo SEARXNG_SECRET="$(openssl rand -hex 32)" > .env
echo SEARXNG_HOST="searx.docker.lan" >> .env
```

# JSON APIs and integration with code.

In order to use this with code. It is important to enable json format.

```
search:
    ...
    formats:
        ...
        - json
```

# Default browser search chromium

1. Settings -> Search Engine -> Manage search engines and site search
2. Site Search -> Add
3. Name it, use a shortcut named something like `@searxng`
4. For the url: `https://searxng.docker.lan/search?q=%s`
5. Click add. Make it the default search provider if desired.
