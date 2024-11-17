#!/bin/bash

CERT_DIR="/absolute/path/to/docker-haproxy-letsencrypt/certs/yourdomain.com"
HAPROXY_CONTAINER="haproxy"

# Ensure inotifywait and docker are available
INOTIFYWAIT_PATH="/usr/bin/inotifywait"
DOCKER_PATH="/usr/bin/docker"

if [ ! -x "$INOTIFYWAIT_PATH" ]; then
    echo "inotifywait not found at $INOTIFYWAIT_PATH"
    exit 1
fi

if [ ! -x "$DOCKER_PATH" ]; then
    echo "Docker not found at $DOCKER_PATH"
    exit 1
fi

$INOTIFYWAIT_PATH -m -e close_write,moved_to,create "$CERT_DIR" |
while read -r directory events filename; do
  if [[ "$filename" == "fullchain.cer" || "$filename" == "fullchain.cer.key" ]]; then
    echo "Certificate updated, reloading HAProxy..."
    $DOCKER_PATH kill -s HUP $HAPROXY_CONTAINER
  fi
done
