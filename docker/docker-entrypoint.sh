#!/bin/bash
#

if [ -x /preboot/build.sh ]; then
	cd /preboot
	exec /preboot/build.sh "$@"
fi

echo
echo "A script /preboot/build.sh not found. Entering shell ..."
echo
sleep 3

exec /bin/bash "$@"