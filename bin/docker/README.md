# Troubleshooting

On my laptop `docker.service` gets stuck on `systemd-networkd-wait-online` for a very long time.

You can override the start command and then tell wait-online to listen to any of the devices to become available rather than all. (I don't really use my ethernet port)

```bash
sudo systemctl edit systemd-networkd-wait-online.service
```

```
[Service]
ExecStart=
ExecStart=/usr/lib/systemd/systemd-networkd-wait-online --any
```

[more info](https://unix.stackexchange.com/questions/381448/systemd-networkd-wait-online-failure)
