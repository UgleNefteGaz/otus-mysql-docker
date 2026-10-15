#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LAB="${LAB:-$ROOT_DIR/../pxc-lab}"

PXC_BASE="${PXC_BASE:-$LAB/Percona-XtraDB-Cluster_8.0.41-32.1_Linux.x86_64.glibc2.35}"

MYSQL="$PXC_BASE/bin/mysql"

if [[ ! -x "$MYSQL" ]]; then
    echo "ERROR: mysql client not found:"
    echo "$MYSQL"
    exit 1
fi

echo "PXC base: $PXC_BASE"
echo "Lab:      $LAB"
echo

for n in 1 2 3; do
    SOCKET="$LAB/node${n}/run/mysql.sock"

    echo "========================================"
    echo "NODE$n"
    echo "Socket: $SOCKET"
    echo "========================================"

    if [[ ! -S "$SOCKET" ]]; then
        echo "Node$n is unavailable: socket not found"
        echo
        continue
    fi

    "$MYSQL" \
        --socket="$SOCKET" \
        -uroot \
        -e "
SELECT
    @@hostname AS hostname,
    @@port AS mysql_port;

SHOW STATUS WHERE Variable_name IN (
    'wsrep_cluster_size',
    'wsrep_cluster_status',
    'wsrep_connected',
    'wsrep_local_state_comment',
    'wsrep_ready',
    'wsrep_last_committed'
);

SHOW TABLES FROM pxc_demo;

SELECT COUNT(*) AS customers_count
FROM pxc_demo.customers;

SELECT COUNT(*) AS orders_count
FROM pxc_demo.orders;
"

    echo
done
