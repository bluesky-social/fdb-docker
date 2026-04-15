# fdb-docker

Single-node FoundationDB dev cluster in Docker. Works natively on both
macOS aarch64 (Apple Silicon) and Linux amd64 -- the official
`foundationdb/foundationdb:7.3.63` image ships multi-arch manifests for
both platforms.

## Quick start

```bash
docker compose up -d
```

Wait for the healthcheck to pass (~30s on first boot), then connect:

```bash
fdbcli -C <(docker compose exec fdb cat /var/fdb/cluster/fdb.cluster)
```

Or copy the cluster file locally:

```bash
docker compose cp fdb:/var/fdb/cluster/fdb.cluster ./fdb.cluster
fdbcli -C ./fdb.cluster
```

## Port conflict with a local FDB install

If you already have FoundationDB running on port 4500:

```bash
FDB_PORT=4550 docker compose up -d
```

## Using from another project

Add to your project's `docker-compose.yml`:

```yaml
include:
  - path: ../fdb-docker/docker-compose.yml

services:
  myapp:
    depends_on:
      fdb:
        condition: service_healthy
    volumes:
      - fdb-cluster:/etc/foundationdb:ro
    # Your app reads /etc/foundationdb/fdb.cluster
```

## Architecture

The setup is intentionally minimal:

- **Dockerfile** -- thin wrapper around the official image that adds an
  entrypoint script for automatic database initialization.
- **scripts/fdb-entrypoint.bash** -- writes the cluster file, starts
  `fdbserver` via the official entrypoint, and runs
  `configure new single ssd` in the background on first boot.
- **docker-compose.yml** -- wires up volumes, port mapping, and a
  healthcheck.

The server advertises `127.0.0.1:<FDB_PORT>` as its public address
(`FDB_NETWORKING_MODE=host`). Host processes connect directly; containers
in the same compose stack reach it via the port mapping.

Data lives on a tmpfs and is wiped on every `docker compose down` /
`docker compose up` cycle. This is intentional -- it's a dev cluster.
