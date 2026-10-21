#!/usr/bin/env bash
# Smoke test: start the image and check that a request served by
# OpenLiteSpeed runs through lsphp with the expected PHP version.
#
#   ./test.sh <image> <expected php version>
set -euo pipefail

image=$1
expected=$2
port=${PORT:-8088}

cid=$(docker run -d -p "127.0.0.1:${port}:80" "$image")
cleanup() {
    status=$?
    if [ "$status" -ne 0 ]; then
        echo "--- container logs ---"
        docker logs "$cid" 2>&1 | tail -n 50
        docker exec "$cid" sh -c 'tail -n 50 /usr/local/lsws/logs/error.log' 2>/dev/null || true
    fi
    docker rm -f "$cid" >/dev/null
    exit "$status"
}
trap cleanup EXIT

docker exec "$cid" sh -c \
    'echo "<?php echo PHP_SAPI, \" \", PHP_VERSION;" > /var/www/vhosts/localhost/html/version.php'

got=
for _ in $(seq 30); do
    got=$(curl -fsS "http://127.0.0.1:${port}/version.php" 2>/dev/null || true)
    [ -n "$got" ] && break
    sleep 1
done

if [ "$got" != "litespeed $expected" ]; then
    echo "expected 'litespeed $expected', got '$got'" >&2
    exit 1
fi
echo "ok: $got"
