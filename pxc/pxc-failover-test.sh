#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LAB="${LAB:-$ROOT_DIR/../pxc-lab}"
PXC_BASE="${PXC_BASE:-$LAB/Percona-XtraDB-Cluster_8.0.41-32.1_Linux.x86_64.glibc2.35}"

MYSQL="$PXC_BASE/bin/mysql"
MYSQLD="$PXC_BASE/bin/mysqld"

NODE1_SOCKET="$LAB/node1/run/mysql.sock"
NODE2_SOCKET="$LAB/node2/run/mysql.sock"
NODE3_SOCKET="$LAB/node3/run/mysql.sock"
NODE3_PIDFILE="$LAB/node3/run/mysql.pid"

echo "WARNING: this script intentionally kills node3."
echo
read -r -p "Continue? [y/N] " answer

if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
    echo "Cancelled."
    exit 0
fi

echo
echo "===== INITIAL CLUSTER STATE ====="

for n in 1 2 3; do
    echo
    echo "NODE$n"

    "$MYSQL" \
        --socket="$LAB/node${n}/run/mysql.sock" \
        -uroot \
        -N \
        -e "
SHOW STATUS WHERE Variable_name IN (
    'wsrep_cluster_size',
    'wsrep_cluster_status',
    'wsrep_local_state_comment',
    'wsrep_ready'
);
"
done

echo
echo "===== SIMULATING NODE3 FAILURE ====="

NODE3_PID="$(cat "$NODE3_PIDFILE")"

echo "node3 PID: $NODE3_PID"
kill -9 "$NODE3_PID"

sleep 5

if kill -0 "$NODE3_PID" 2>/dev/null; then
    echo "ERROR: node3 process is still running"
    exit 1
fi

echo "node3 is down"

echo
echo "===== CLUSTER AFTER NODE3 FAILURE ====="

for n in 1 2; do
    echo
    echo "NODE$n"

    "$MYSQL" \
        --socket="$LAB/node${n}/run/mysql.sock" \
        -uroot \
        -e "
SHOW STATUS WHERE Variable_name IN (
    'wsrep_cluster_size',
    'wsrep_cluster_status',
    'wsrep_connected',
    'wsrep_local_state_comment',
    'wsrep_ready'
);
"
done

echo
echo "===== WRITE WHILE NODE3 IS DOWN ====="

"$MYSQL" \
    --socket="$NODE1_SOCKET" \
    -uroot \
    -e "
DELETE FROM pxc_demo.customers
WHERE id=900;

INSERT INTO pxc_demo.customers(id,name,email)
VALUES (
    900,
    'Failover Script Test',
    'failover-script@example.com'
);

SELECT id,name,email
FROM pxc_demo.customers
WHERE id=900;
"

echo
echo "===== READ FROM NODE2 ====="

"$MYSQL" \
    --socket="$NODE2_SOCKET" \
    -uroot \
    -e "
SET SESSION wsrep_sync_wait=1;

SELECT id,name,email
FROM pxc_demo.customers
WHERE id=900;
"

echo
echo "===== RESTART NODE3 ====="

rm -f \
    "$LAB/node3/run/mysql.pid" \
    "$LAB/node3/run/mysql.sock" \
    "$LAB/node3/run/mysql.sock.lock"

"$MYSQLD" \
    --defaults-file="$LAB/conf/node3.cnf" \
    --daemonize

echo "Waiting for node3 to become ready..."

for attempt in $(seq 1 30); do
    if "$MYSQL" \
        --socket="$NODE3_SOCKET" \
        -uroot \
        -N \
        -e "SHOW STATUS LIKE 'wsrep_ready';" \
        2>/dev/null \
        | grep -q $'wsrep_ready\tON'
    then
        echo "node3 is ready"
        break
    fi

    if [[ "$attempt" -eq 30 ]]; then
        echo "ERROR: node3 did not become ready"
        exit 1
    fi

    sleep 1
done

echo
echo "===== DATA ON RECOVERED NODE3 ====="

"$MYSQL" \
    --socket="$NODE3_SOCKET" \
    -uroot \
    -e "
SELECT id,name,email
FROM pxc_demo.customers
WHERE id=900;
"

echo
echo "===== FINAL CLUSTER STATE ====="

for n in 1 2 3; do
    echo
    echo "NODE$n"

    "$MYSQL" \
        --socket="$LAB/node${n}/run/mysql.sock" \
        -uroot \
        -e "
SHOW STATUS WHERE Variable_name IN (
    'wsrep_cluster_size',
    'wsrep_cluster_status',
    'wsrep_connected',
    'wsrep_local_state_comment',
    'wsrep_ready'
);
"
done

echo
echo "Failover test completed successfully."
