#!/bin/bash
#

if [ -x /preboot/build.sh ]; then
	cd /preboot
	exec /preboot/build.sh "$@"
else
	echo
	echo "A script /preboot/build.sh not found. Entering shell ..."
	echo
	sleep 3
fi

exec /bin/bash "$@"