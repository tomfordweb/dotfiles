# Locally hosted docker apps.

Here is a local AI and self hosted app setup. Most of this should work on any linux.

The default admin panel is at [https://traefik.docker.localhost](traefik.docker.localhost).

# Setup

Create the traefik network.

```
docker network create traefik
```

## Certificates

I am using a self signed cert.

Using [mkcert](https://github.com/FiloSottile/mkcert).

```
cd opt/traefik/certs
mkcert -install
mkcert "*.docker.localhost"
```

You must update `dynamic/tls.yml` with your updated hostname.
