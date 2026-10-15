#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LAB="${LAB:-$ROOT_DIR/../pxc-lab}"
PXC_BASE="${PXC_BASE:-$LAB/Percona-XtraDB-Cluster_8.0.41-32.1_Linux.x86_64.glibc2.35}"

MYSQL="$PXC_BASE/bin/mysql"
MYSQLD="$PXC_BASE/bin/mysqld"

status_node() {
    local n="$1"

    "$MYSQL" \
        --socket="$LAB/node${n}/run/mysql.sock" \
        -uroot \
        -e "
SHOW STATUS WHERE Variable_name IN (
    'wsrep_cluster_size',
    'wsrep_cluster_status',
    'wsrep_connected',
    'wsrep_local_state_comment',
    'wsrep_ready',
    'wsrep_last_committed'
);
"
}

wait_for_ready() {
    local n="$1"
    local socket="$LAB/node${n}/run/mysql.sock"

    echo "Waiting for node$n to become ready..."

    for attempt in $(seq 1 60); do
        if "$MYSQL" \
            --socket="$socket" \
            -uroot \
            -N \
            -e "SHOW STATUS LIKE 'wsrep_ready';" \
            2>/dev/null \
            | grep -q $'wsrep_ready\tON'
        then
            echo "node$n is ready"
            return 0
        fi

        sleep 1
    done

    echo "ERROR: node$n did not become ready"
    return 1
}

start_node_background() {
    local n="$1"

    rm -f \
        "$LAB/node${n}/run/mysql.pid" \
        "$LAB/node${n}/run/mysql.sock" \
        "$LAB/node${n}/run/mysql.sock.lock"

    nohup "$MYSQLD" \
        --defaults-file="$LAB/conf/node${n}.cnf" \
        --daemonize \
        >"$LAB/node${n}/log/start-recovery.log" \
        2>&1 &

    echo "Start command sent to node$n"
}

echo "======================================================"
echo "DANGER: PXC quorum-loss recovery test"
echo "======================================================"
echo
echo "This test will:"
echo "  1. kill node2 and node3 with SIGKILL"
echo "  2. force node1 into non-Primary state"
echo "  3. demonstrate SQL blocking"
echo "  4. start node2"
echo "  5. recover Primary Component with pc.bootstrap=YES"
echo "  6. start node3 and restore the 3-node cluster"
echo
echo "Never use pc.bootstrap=YES in production unless you are"
echo "certain that no other Primary Component exists."
echo

read -r -p "Type QUORUM-LOSS to continue: " answer

if [[ "$answer" != "QUORUM-LOSS" ]]; then
    echo "Cancelled."
    exit 0
fi

echo
echo "===== INITIAL CLUSTER STATE ====="

for n in 1 2 3; do
    echo
    echo "NODE$n"
    status_node "$n"
done

echo
echo "===== CHECKING INITIAL QUORUM ====="

INITIAL_SIZE="$(
    "$MYSQL" \
        --socket="$LAB/node1/run/mysql.sock" \
        -uroot \
        -N \
        -e "SHOW STATUS LIKE 'wsrep_cluster_size';" \
        | awk '{print $2}'
)"

INITIAL_STATUS="$(
    "$MYSQL" \
        --socket="$LAB/node1/run/mysql.sock" \
        -uroot \
        -N \
        -e "SHOW STATUS LIKE 'wsrep_cluster_status';" \
        | awk '{print $2}'
)"

if [[ "$INITIAL_SIZE" != "3" || "$INITIAL_STATUS" != "Primary" ]]; then
    echo "ERROR: cluster is not in expected 3-node Primary state"
    echo "cluster_size=$INITIAL_SIZE"
    echo "cluster_status=$INITIAL_STATUS"
    exit 1
fi

echo "Cluster is healthy: 3/3 Primary"

echo
echo "===== CRASH NODE2 AND NODE3 ====="

NODE2_PID="$(cat "$LAB/node2/run/mysql.pid")"
NODE3_PID="$(cat "$LAB/node3/run/mysql.pid")"

echo "node2 PID: $NODE2_PID"
echo "node3 PID: $NODE3_PID"

kill -9 "$NODE2_PID" "$NODE3_PID"

sleep 5

echo
echo "Remaining PXC processes:"

ps -ef \
    | grep '[m]ysqld' \
    | grep 'pxc-lab' \
    || true

echo
echo "===== NODE1 AFTER QUORUM LOSS ====="

status_node 1

echo
echo "===== SELECT WITHOUT QUORUM ====="

if "$MYSQL" \
    --socket="$LAB/node1/run/mysql.sock" \
    -uroot \
    -e "
SELECT COUNT(*)
FROM pxc_demo.customers;
"
then
    echo "ERROR: SELECT unexpectedly succeeded without quorum"
    exit 1
else
    echo
    echo "Expected result: SELECT was blocked."
fi

echo
echo "===== INSERT WITHOUT QUORUM ====="

if "$MYSQL" \
    --socket="$LAB/node1/run/mysql.sock" \
    -uroot \
    -e "
INSERT INTO pxc_demo.customers(id,name,email)
VALUES (901,'No Quorum Test','no-quorum-test@example.com');
"
then
    echo "ERROR: INSERT unexpectedly succeeded without quorum"
    exit 1
else
    echo
    echo "Expected result: INSERT was blocked."
fi

echo
echo "===== START NODE2 ====="

start_node_background 2

sleep 5

echo
echo "node1 state before Primary Component recovery:"
status_node 1

echo
echo "===== RECOVER PRIMARY COMPONENT ====="

echo "Last committed seqno on node1:"

"$MYSQL" \
    --socket="$LAB/node1/run/mysql.sock" \
    -uroot \
    -e "
SHOW STATUS LIKE 'wsrep_last_committed';
"

echo
echo "Executing pc.bootstrap=YES on node1..."

"$MYSQL" \
    --socket="$LAB/node1/run/mysql.sock" \
    -uroot \
    -e "
SET GLOBAL wsrep_provider_options='pc.bootstrap=YES';
"

wait_for_ready 1
wait_for_ready 2

echo
echo "===== CLUSTER AFTER PRIMARY COMPONENT RECOVERY ====="

for n in 1 2; do
    echo
    echo "NODE$n"
    status_node "$n"
done

echo
echo "===== WRITE AFTER QUORUM RECOVERY ====="

"$MYSQL" \
    --socket="$LAB/node2/run/mysql.sock" \
    -uroot \
    -e "
DELETE FROM pxc_demo.customers
WHERE id=902;

INSERT INTO pxc_demo.customers(id,name,email)
VALUES (
    902,
    'Quorum Recovery Test',
    'quorum-recovery@example.com'
);

SELECT id,name,email
FROM pxc_demo.customers
WHERE id=902;
"

echo
echo "===== READ FROM NODE1 ====="

"$MYSQL" \
    --socket="$LAB/node1/run/mysql.sock" \
    -uroot \
    -e "
SET SESSION wsrep_sync_wait=1;

SELECT id,name,email
FROM pxc_demo.customers
WHERE id=902;
"

echo
echo "===== START NODE3 ====="

start_node_background 3

wait_for_ready 3

echo
echo "===== FINAL CLUSTER STATE ====="

for n in 1 2 3; do
    echo
    echo "NODE$n"

    status_node "$n"

    "$MYSQL" \
        --socket="$LAB/node${n}/run/mysql.sock" \
        -uroot \
        -e "
SELECT id,name,email
FROM pxc_demo.customers
WHERE id=902;
"
done

echo
echo "======================================================"
echo "Quorum-loss recovery test completed successfully."
echo "======================================================"
