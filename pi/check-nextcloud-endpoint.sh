#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
	printf 'Usage: %s https://nextcloud.example.com\n' "$0" >&2
	exit 2
fi

base_url=${1%/}
status_url="$base_url/status.php"
dav_url="$base_url/remote.php/dav/files/${NEXTCLOUD_USER:-endpoint-probe}/"

status_code=$(curl --silent --show-error --output /dev/null \
	--write-out '%{http_code}' "$status_url")

case "$status_code" in
	200)
		printf 'PASS  status.php returned HTTP 200\n'
		;;
	*)
		printf 'FAIL  status.php returned HTTP %s\n' "$status_code" >&2
		exit 1
		;;
esac

if [ -n "${NEXTCLOUD_USER:-}" ] && [ -n "${NEXTCLOUD_APP_PASSWORD:-}" ]; then
	dav_code=$(curl --silent --show-error --output /dev/null \
		--user "$NEXTCLOUD_USER:$NEXTCLOUD_APP_PASSWORD" \
		--request PROPFIND --header 'Depth: 1' \
		--write-out '%{http_code}' "$dav_url")
	expected=207
else
	dav_code=$(curl --silent --show-error --output /dev/null \
		--request PROPFIND --header 'Depth: 1' \
		--write-out '%{http_code}' "$dav_url")
	expected=401
	printf 'INFO  Set NEXTCLOUD_USER and NEXTCLOUD_APP_PASSWORD for an authenticated check.\n'
fi

if [ "$dav_code" = "$expected" ]; then
	printf 'PASS  WebDAV PROPFIND returned HTTP %s\n' "$dav_code"
	exit 0
fi

printf 'FAIL  WebDAV PROPFIND returned HTTP %s (expected %s)\n' \
	"$dav_code" "$expected" >&2
if [ "$dav_code" = 405 ]; then
	printf '      The public ingress is blocking a method required by Nextcloud.\n' >&2
fi
exit 1

