# Production deployment

Live at **https://harborclick.169-58-108-100.sslip.io** (game at `/jogar/`).
The server, 169.58.108.100, is shared: one Traefik in front of several Docker
Compose projects, each in `/opt/<name>/` — see `/opt/README.md` on the box.
HarborClick is `/opt/harborclick/`, a copy of `docker-compose.yml` and
`nginx.conf` from this directory: nginx serves `current`. The game exports
without threads, so no COOP/COEP are sent — requiring them would break
rewarded-ad SDK iframes (plano-release R4).

Every push to `main` runs `.github/workflows/deploy-production.yml`. The job
downloads the pinned Godot 4.7.1 toolchain, verifies its SHA-256 checksums, runs
the complete headless suite, builds the landing page plus `/jogar/`, and uploads
one immutable archive to the production server.

The workflow authenticates as the unprivileged `harborclick-deploy` user with
the `HARBORCLICK_DEPLOY_KEY` repository secret. `deploy/known_hosts` pins the
server identity. The key can only replace files below
`/var/www/harborclick-deploy`; it has no `sudo` access.

`deploy/remote_release.sh` validates the archive and required Web files before
switching `/var/www/harborclick-deploy/current` atomically. The previous release
and archive remain available for rollback. Nginx always serves the `current`
link, so routine deploys do not need a reload.

To roll back, point `current` at an older directory from `releases/` with the
same temporary-link-then-rename operation. The automatic workflow never prunes
old releases.
