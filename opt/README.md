# Setup

Create the traefik network.

```
docker network create traefik
```

## Certificates

I am using a self signed cert. These services are available to my home network so I name my domain `lan`

Using [mkcert](https://github.com/FiloSottile/mkcert).

```
cd opt/traefik/certs
mkcert -install
mkcert "*.docker.lan"
```

You must update `dynamic/tls.yml` with your updated pem files.

## DNS

You need to be able to configure local DNS to host this on your network. WRT or Pihole should work.

1. Setup a DHCP or a static IP address to your machines, pin them.
2. In the DNS settings point each traefik domain to the IP address where traefik is hosted.
