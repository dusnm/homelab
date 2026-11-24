# homelab

A self-hosted home server as code: Docker Compose services behind a host nginx reverse proxy
with a wildcard Let's Encrypt certificate, Authelia 2FA in front of the admin tools, and
encrypted off-site backups. Everything machine-specific (domain, paths, user IDs, secrets,
hardware) lives outside the repo, so the same files run on any machine.

## Layout

```
homelab.env.example        settings for one machine: copy to homelab.env (git-ignored)
scripts/homelab            runs the services (`homelab up`, `homelab nginx install`, ...)
services/<name>/           compose.yml per service, plus .env.example, example configs and
                           helper scripts where the service needs them
nginx/sites/, snippets/    reverse-proxy templates (${DOMAIN}, ${HOST_*} filled in on install)
```

State never lives in the repo. Each service keeps its data, configs and secrets in
`$DATA_ROOT/<service>/`:

```
$DATA_ROOT/<service>/.env                    secrets and settings (from services/<service>/.env.example)
$DATA_ROOT/<service>/compose.override.yml    optional: this machine's devices, extra mounts
$DATA_ROOT/<service>/...                     the service's data (bind mounts)
```

Docker named volumes (databases of Nextcloud, Paperless, CleanSlate, ...) are named after the
service folder, as with plain `docker-compose`.

## Requirements

- Linux with Docker and docker-compose (v1.29 or the v2 plugin), bash, envsubst (gettext-base)
- nginx on the host, and a domain whose DNS you control (wildcard `*.example.com` record to
  this machine). The certificate comes from `certbot-dns-namecheap` (Namecheap DNS); with
  another DNS provider, use a matching certbot DNS plugin instead.

## Setup

```bash
git clone <this repo> ~/homelab && cd ~/homelab
cp homelab.env.example homelab.env && $EDITOR homelab.env    # domain, paths, IDs
ln -s "$PWD/scripts/homelab" ~/.local/bin/homelab             # optional: on your PATH
```

Then per service you want (list only those in `SERVICES=` in homelab.env, or all are started):

1. Create `$DATA_ROOT/<service>/` and copy `services/<service>/.env.example` to
   `$DATA_ROOT/<service>/.env` (chmod 600) if there is one; fill in the secrets
   (`openssl rand -hex 32` makes a good one).
2. Copy the service's other `*.example` files to the place their first line names.
3. `homelab up <service>`

Order for a fresh machine: `certbot-dns-namecheap` (certificate), `authelia` (run
`services/authelia/init-secrets.sh` and `services/authelia/add-user.sh` first), then the rest,
then `homelab nginx install`.

## Services

| Service | Host name | Port (127.0.0.1) | Access |
|---|---|---|---|
| adguard-home | `HOST_DNS` | host network | AdGuard's own login; DNS on port 53 |
| authelia | `HOST_AUTH` | 9091 | login portal |
| beszel | `HOST_MONITOR` | 8090 | Authelia |
| borgmatic | - | - | backups, daily |
| certbot-dns-namecheap | - | - | renews `*.DOMAIN` |
| cleanslate | `HOST_MACROS` | 3010-3013 | own login |
| cloudflared | - | host network | Cloudflare Tunnel |
| deluge | `HOST_DELUGE` | 8112 | Authelia |
| euro-office | `HOST_OFFICE` | 9981 | JWT (Nextcloud) |
| homer | `HOST_HOME` (the bare domain) | 5678 | Authelia |
| immich | `HOST_PHOTOS` | 2283 | own login |
| mealie | `HOST_RECIPES` | 9925 | own login |
| metube | `HOST_DOWNLOAD` | 8081 | Authelia |
| music-importer | - | - | imports into the music library ([music-importer](#music-importer)) |
| navidrome | `HOST_MUSIC` | 4533 | own login (Subsonic apps) |
| nextcloud | `HOST_CLOUD` | 6080 | own login |
| paperless | `HOST_DOCS` | 8010 | own login |
| prowlarr | `HOST_PROWLARR` | 9696 | Authelia |
| ps2smb | - | 137-139, 445 (LAN) | SMBv1 share for PS2 OPL |
| searxng | `HOST_SEARCH` | 10200 | open |
| slskd | `HOST_SLSKD` | 5030 | Authelia |
| vikunja | `HOST_TASKS` | 8080 | own login |
| wastebin | `HOST_PASTE` | 8088 | open |
| watchtower | - | - | updates unpinned images |

Host names default to `<name>.$DOMAIN`, and Homer to `$DOMAIN` itself (see `homelab.env.example`). Every web app listens on
127.0.0.1 only; nginx publishes it. Apps marked "Authelia" are listed in
`services/authelia/configuration.yml` and get 2FA in front of them; everything else not listed
there is refused by Authelia (`default_policy: deny`).

## The homelab command

```bash
homelab up [SERVICE...]          # start (all enabled services when none given)
homelab down|restart|pull|ps [SERVICE...]
homelab logs SERVICE -- -f       # anything after -- goes to docker-compose
homelab build SERVICE            # rebuild images built from source (music-importer)
homelab config SERVICE           # the rendered compose file
homelab check                    # validate every compose file
homelab compose SERVICE ARGS...  # any docker-compose command, e.g. exec
homelab list                     # services, enabled or not, running containers
homelab env                      # the settings in effect (no secrets)
homelab nginx render [DIR]       # render the nginx templates (default: build/nginx)
homelab nginx install            # render, copy into /etc/nginx, enable, test, reload (sudo)
```

`homelab` reads `homelab.env`, then runs docker-compose for the service with
`--env-file $DATA_ROOT/<service>/.env` and, if present, `$DATA_ROOT/<service>/compose.override.yml`.
Plain `docker-compose` in a service folder does not know these settings: use `homelab compose`.

## nginx

`nginx/sites/*.conf` are templates; `homelab nginx install` fills in `${DOMAIN}`, `${HOST_*}`
and `${LETSENCRYPT_DIR}`, copies them to `/etc/nginx/sites-available`, enables them, runs
`nginx -t` and reloads. They expect the certificate at
`$LETSENCRYPT_DIR/live/$DOMAIN/` and certbot's `options-ssl-nginx.conf` and
`ssl-dhparams.pem` in `$LETSENCRYPT_DIR`. `private.conf` holds the Authelia-protected apps;
`authelia-location.conf` and `authelia-authrequest.conf` in `snippets/` wire them up.
The bare domain is the Homer dashboard (`HOST_HOME`), behind Authelia like the other private apps.

## Machine-specific additions

Hardware and extra mounts go in `$DATA_ROOT/<service>/compose.override.yml`. Examples:
`services/beszel/compose.override.yml.example` (disks for SMART and extra filesystems),
`services/immich/compose.override.yml.example` (GPU transcoding, an external library),
`services/borgmatic/compose.override.yml.example` (what to back up).

## music-importer

Built from its own project (`MUSIC_IMPORTER_SRC` in `$DATA_ROOT/music-importer/.env`: a local
checkout or the git URL). It needs slskd's network, so start slskd first (`homelab up` does).
Its command-line front end `mi` comes with that project.

## Backups

`borgmatic` backs up `$DATA_ROOT`, the music library, Nextcloud's files, Paperless' volumes and
the host's `/etc`, with consistent dumps of the Postgres and MariaDB databases, into an
encrypted borg repository (BorgBase by default). See `services/borgmatic/*.example`.

## Scripts

- `scripts/setup-swapfile.sh`: adds a swap file on the root filesystem (run with sudo).
