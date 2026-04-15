default: fdbcli

up:
    docker compose up -d --build --wait

down:
    docker compose down

fdbcli:
    docker compose exec -it fdb fdbcli -C /var/fdb/cluster/fdb.cluster
