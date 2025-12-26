# Locally hosted docker apps.

The default admin panel is at [https://traefik.docker.localhost](traefik.docker.localhost).

# Certificates

Using [mkcert](https://github.com/FiloSottile/mkcert).

```
cd ~/xdg-base/opt/traefik/certs
mkcert -install
mkcert "*.docker.localhost"
```

You must update dynamic/tls.yml with your updated hostname.
