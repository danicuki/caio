# Deploy Caio on a Google Cloud VM

This is the first production-friendly deployment path for Caio: one Ubuntu VM
running the Phoenix portal, Rails/Sidekiq crawler workers, Redis, Caddy, and a
shared SQLite database on persistent disk.

It is intentionally simple. The next step, when traffic or crawler volume
requires it, should be moving the database to Postgres and separating crawler
workers from the web VM.

## Recommended VM

- Machine: `e2-standard-4` minimum, `e2-standard-8` if crawler backfill is heavy.
- OS: Ubuntu 24.04 LTS.
- Boot disk: 100 GB `pd-balanced`.
- Data disk: 200 GB+ `pd-balanced`, mounted at `/var/lib/caio`.
- Network: static external IPv4, only ports 80 and 443 public.
- Domain: point `caio-jobs.com` and `www.caio-jobs.com` A records to the static IP.

## Local prerequisites

Install and authenticate the Google Cloud CLI on your workstation:

```sh
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

Set your deployment variables:

```sh
export GCP_PROJECT=YOUR_PROJECT_ID
export GCP_REGION=us-central1
export GCP_ZONE=us-central1-a
export CAIO_VM_NAME=caio-prod
export CAIO_DOMAIN=caio-jobs.com
```

## Create the VM

From the repository root:

```sh
deploy/google-cloud/create-vm.sh
```

The script reserves a regional static IP, creates firewall rules for HTTP/HTTPS
if needed, creates the VM, and prints the IP address to put in DNS.

## Bootstrap the VM

SSH into the VM:

```sh
gcloud compute ssh "$CAIO_VM_NAME" --zone "$GCP_ZONE"
```

On the VM, run the bootstrap script from this repository:

```sh
sudo bash deploy/google-cloud/bootstrap-vm.sh
```

Then create `/etc/caio/caio.env` from the example:

```sh
sudo cp deploy/google-cloud/caio.env.example /etc/caio/caio.env
sudo editor /etc/caio/caio.env
sudo chmod 600 /etc/caio/caio.env
```

Required values:

```sh
PHX_HOST=caio-jobs.com
SECRET_KEY_BASE=generate-with-mix-phx-gen-secret
DATABASE_PATH=/var/lib/caio/caio.sqlite3
JOB_CRAWLER_DATABASE=/var/lib/caio/caio.sqlite3
GITHUB_CLIENT_ID=...
GITHUB_CLIENT_SECRET=...
GITHUB_REDIRECT_URI=https://caio-jobs.com/auth/github/callback
```

Generate `SECRET_KEY_BASE` after dependencies are installed:

```sh
cd /srv/caio/portal
mix phx.gen.secret
```

## Install and build the app

Clone or update the repo:

```sh
sudo mkdir -p /srv/caio
sudo chown -R caio:caio /srv/caio /var/lib/caio
sudo -iu caio
git clone https://github.com/danicuki/caio.git /srv/caio
cd /srv/caio
```

Install runtime versions with `mise`:

```sh
mise install
mise use -g erlang@26.2.5.17 elixir@1.17.2-otp-26 ruby@3.4.8
```

Install dependencies and build:

```sh
cd /srv/caio/crawler
bundle install
RAILS_ENV=production JOB_CRAWLER_DATABASE=/var/lib/caio/caio.sqlite3 bundle exec rails db:migrate

cd /srv/caio/portal
mix deps.get --only prod
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod DATABASE_PATH=/var/lib/caio/caio.sqlite3 mix ecto.migrate
MIX_ENV=prod mix release --overwrite
```

## Install services

As root:

```sh
sudo cp deploy/google-cloud/systemd/*.service /etc/systemd/system/
sudo cp deploy/google-cloud/Caddyfile /etc/caddy/Caddyfile
sudo systemctl daemon-reload
sudo systemctl enable --now redis-server
sudo systemctl enable --now caddy
sudo systemctl enable --now caio-portal
sudo systemctl enable --now caio-sidekiq-writer caio-sidekiq-fetch caio-sidekiq-sources
sudo systemctl enable --now caio-crawler-scheduler.timer caio-sqlite-backup.timer
```

Check status:

```sh
sudo systemctl status caio-portal
sudo journalctl -u caio-portal -f
```

## Deploy updates

```sh
sudo -iu caio
cd /srv/caio
git pull

cd crawler
bundle install
RAILS_ENV=production JOB_CRAWLER_DATABASE=/var/lib/caio/caio.sqlite3 bundle exec rails db:migrate

cd ../portal
mix deps.get --only prod
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod DATABASE_PATH=/var/lib/caio/caio.sqlite3 mix ecto.migrate
MIX_ENV=prod mix release --overwrite

exit
sudo systemctl restart caio-portal caio-sidekiq-writer caio-sidekiq-fetch caio-sidekiq-sources
```

## Backups

SQLite is a single critical file. Start with:

```sh
sqlite3 /var/lib/caio/caio.sqlite3 ".backup '/var/lib/caio/backups/caio-$(date +%F-%H%M%S).sqlite3'"
```

Then add a cron/systemd timer to upload backups to a private Cloud Storage bucket.
The included `caio-sqlite-backup.timer` creates local backups under
`/var/lib/caio/backups`; wire Cloud Storage upload after you create the bucket.
