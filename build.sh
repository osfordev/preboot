#!/bin/bash
#

if [ ! -f /DOCKER_ARCH ]; then
	echo "Look like you have wrong build container. The container should present a file /DOCKER_ARCH" >&2
	exit 1
fi
DOCKER_ARCH=$(cat /DOCKER_ARCH)
if [ -z "${DOCKER_ARCH}" ]; then
	echo "Look like you have wrong build container. The container should present a file /DOCKER_ARCH with proper arch value." >&2
	exit 2
fi

set -e

case "${DOCKER_ARCH}" in
	linux/386)
		exec /preboot/build-i686.sh 
		;;
	linux/amd64)
		exec /preboot/build-amd64.sh 
		;;
	linux/amd64/v2)
		exec /preboot/build-amd64.sh 
		;;
	linux/arm/v5)
		exec /preboot/build-arm32v5.sh 
		;;
	linux/arm/v6)
		exec /preboot/build-arm32v6.sh 
		;;
	linux/arm/v7)
		exec /preboot/build-arm32v7.sh 
		;;
	*)
		echo "Unsupported DOCKER_ARCH: ${DOCKER_ARCH}" >&2
		exit 3
		;;
esac
