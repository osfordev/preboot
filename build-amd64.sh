#!/bin/bash
#

set -e

if [ ! -f /preboot/BANNER ]; then
	echo "Look like you have wrong toolchain container. The container should present a file /preboot/BANNER" >&2
	exit 1
fi
cat /preboot/BANNER

if [ ! -f /KERNEL_VERSION ]; then
	echo "Look like you have wrong toolchain container. The container should present a file /KERNEL_VERSION" >&2
	exit 1
fi
KERNEL_VERSION=$(cat /KERNEL_VERSION)
if [ -z "${KERNEL_VERSION}" ]; then
	echo "Look like you have wrong toolchain container. The container should present a file /KERNEL_VERSION with proper kernel version." >&2
	exit 1
fi

if [ ! -f /DOCKER_ARCH ]; then
	echo "Look like you have wrong build container. The container should present a file /DOCKER_ARCH"
	exit 1
fi
DOCKER_ARCH=$(cat /DOCKER_ARCH)
if [ -z "${DOCKER_ARCH}" ]; then
	echo "Look like you have wrong build container. The container should present a file /DOCKER_ARCH with proper arch value."
	exit 1
fi

# https://www.kernel.org/doc/html/v5.14/kbuild/kconfig.html#kconfig-overwriteconfig
# If you set KCONFIG_OVERWRITECONFIG in the environment,
# Kconfig will not break symlinks when .config is a symlink to somewhere else.
export KCONFIG_OVERWRITECONFIG=y

case "${DOCKER_ARCH}" in
	linux/386)
		KERNEL_ARCH=x86
		;;
	linux/amd64)
		KERNEL_ARCH=x86_64
		;;
	*)
		echo "Unsupported DOCKER_ARCH: ${DOCKER_ARCH}" >&2
		exit 62
		;;
esac

cd /usr/src/linux

KERNEL_SLUG=$(basename $(pwd -LP) | cut -d- -f2-)
export KBUILD_OUTPUT="/cache/${KERNEL_SLUG}/kernel"
[ ! -d "${KBUILD_OUTPUT}" ] && mkdir --parents "${KBUILD_OUTPUT}"

if [ ! -f "/preboot/kernel/${KERNEL_ARCH}/config-${KERNEL_VERSION}-gentoo" ]; then
	echo "Kernel configuration /preboot/kernel/${KERNEL_ARCH}/config-${KERNEL_VERSION}-gentoo was not found. Cannot continue." >&2
	exit 1
fi
rm -f "${KBUILD_OUTPUT}/.config"
ln -s "/preboot/kernel/${KERNEL_ARCH}/config-${KERNEL_VERSION}-gentoo" "${KBUILD_OUTPUT}/.config"

make oldconfig
make menuconfig

make "-j$(nproc)"
INSTALL_MOD_PATH="/cache/${KERNEL_SLUG}/modules" make modules_install

cd "${KBUILD_OUTPUT}"
[ ! -d "/cache/${KERNEL_SLUG}/boot" ] && mkdir "/cache/${KERNEL_SLUG}/boot"
cp --verbose "System.map"                       "/cache/${KERNEL_SLUG}/boot/System.map"
cp --verbose ".config"                          "/cache/${KERNEL_SLUG}/boot/config"
cp --verbose "arch/${KERNEL_ARCH}/boot/bzImage" "/cache/${KERNEL_SLUG}/boot/vmlinuz"

[ ! -d /preboot.build/boot ] && mkdir /preboot.build/boot
cp --verbose "System.map"                       "/preboot.build/boot/System.map"
cp --verbose ".config"                          "/preboot.build/boot/config"
cp --verbose "arch/${KERNEL_ARCH}/boot/bzImage" "/preboot.build/boot/vmlinuz"

# cd "/cache/${KERNEL_SLUG}/modules"
# tar --create --gzip --preserve-permissions --file="/cache/${KERNEL_SLUG}/modules.tar.gz" lib/modules


echo "Building initramfs..."
if [ -d "/cache/${KERNEL_SLUG}/initramfs" ]; then
	rm --force --recursive "/cache/${KERNEL_SLUG}/initramfs"
fi

echo "Initialize initramfs configuration..."
mkdir "/cache/${KERNEL_SLUG}/initramfs"
cp /preboot/BANNER "/cache/${KERNEL_SLUG}/initramfs/BANNER"
cp --archive "/preboot/initramfs/fs/"* "/cache/${KERNEL_SLUG}/initramfs/"
#cp --archive "/preboot/initramfs/fs.${KERNEL_ARCH}"/* "/cache/${KERNEL_SLUG}/initramfs/"

CPIO_LIST=$(mktemp)
cat "/preboot/initramfs/initramfs_list.${KERNEL_ARCH}" >> "${CPIO_LIST}"
echo >> "${CPIO_LIST}"


echo "file /etc/group /cache/${KERNEL_SLUG}/initramfs/etc/group 644 0 0" >> "${CPIO_LIST}"
echo "file /etc/ld.so.conf /etc/ld.so.conf 644 0 0" >> "${CPIO_LIST}"
echo "file /etc/nsswitch.conf /cache/${KERNEL_SLUG}/initramfs/etc/nsswitch.conf 644 0 0" >> "${CPIO_LIST}"
echo "file /etc/passwd /cache/${KERNEL_SLUG}/initramfs/etc/passwd 644 0 0" >> "${CPIO_LIST}"
echo "file /init /cache/${KERNEL_SLUG}/initramfs/init 755 0 0" >> "${CPIO_LIST}"
# echo "file /uncrypt /cache/${KERNEL_SLUG}/initramfs/uncrypt 755 0 0" >> "${CPIO_LIST}"
# echo "dir /usr/share/udhcpc 755 0 0" >> "${CPIO_LIST}"
# echo "file /usr/share/udhcpc/default.script /usr/share/udhcpc/default.script 755 0 0" >> "${CPIO_LIST}"
echo >> "${CPIO_LIST}"


echo "# Software" >> "${CPIO_LIST}"
SOFT_ITEMS=""

# Busybox
SOFT_ITEMS="${SOFT_ITEMS} /bin/busybox"

# KExec
SOFT_ITEMS="${SOFT_ITEMS} /usr/sbin/kexec /usr/sbin/vmcore-dmesg"

# # Strace
# SOFT_ITEMS="${SOFT_ITEMS} /usr/bin/strace"

# # Curl requires for stratum download
# SOFT_ITEMS="${SOFT_ITEMS} /usr/bin/curl"

# # Filesystem tools
# SOFT_ITEMS="${SOFT_ITEMS} /sbin/e2fsck /sbin/fsck /sbin/fsck.ext4 /sbin/mke2fs /sbin/mkfs /sbin/mkfs.ext4 /sbin/resize2fs"

# # Disk partition tools
# SOFT_ITEMS="${SOFT_ITEMS} /sbin/fdisk /sbin/sfdisk /usr/sbin/gdisk /usr/sbin/parted"

# LVM stuff
SOFT_ITEMS="${SOFT_ITEMS} /sbin/dmsetup /sbin/lvm /sbin/lvcreate /sbin/lvdisplay /sbin/lvextend /sbin/lvremove /sbin/lvresize /sbin/lvs /sbin/pvcreate /sbin/pvdisplay /sbin/pvresize /sbin/vgchange /sbin/vgcreate /sbin/vgdisplay /sbin/vgextend /sbin/vgscan"
echo "dir /etc/lvm 755 0 0" >> "${CPIO_LIST}"
echo "file /etc/lvm/lvm.conf /etc/lvm/lvm.conf 644 0 0" >> "${CPIO_LIST}"

# Tool for running RAID systems
SOFT_ITEMS="${SOFT_ITEMS} /sbin/mdadm"
echo "file /etc/mdadm.conf /cache/${KERNEL_SLUG}/initramfs/etc/mdadm.conf 644 0 0" >> "${CPIO_LIST}"

# # Cryptsetup
# SOFT_ITEMS="${SOFT_ITEMS} /sbin/cryptsetup"

# # Dropbear SSH Server
# SOFT_ITEMS="${SOFT_ITEMS} /usr/bin/dbclient /usr/bin/dropbearkey /usr/sbin/dropbear"

# # UDEV (See for udevd location indise init script /etc/init.d/udev)
# SOFT_ITEMS="${SOFT_ITEMS} /bin/udevadm"
# echo "slink /bin/udevd /bin/udevadm 755 0 0" >> "${CPIO_LIST}"

case "${KERNEL_ARCH}" in
	x86_64)
		ELF_IGNORE="linux-vdso"
		;;
	x86)
		ELF_IGNORE="linux-gate"
		;;
	*)
		echo "Unsupported KERNEL_ARCH: ${KERNEL_ARCH}" >&2
		exit 62
		;;
esac

declare -a LIB_ITEMS

# # libgcc_s.so.1 for cryptsetup
# echo "dir /usr/lib/gcc 755 0 0" >> "${CPIO_LIST}"
# LIBGCC_FILE=$(find /usr/lib/gcc -maxdepth 3 -name libgcc_s.so.1 | head -n 1)
# if [ -z "${LIBGCC_FILE}" ]; then
# 	echo "Unable to resolve libgcc_s.so.1" >&2
# 	exit 71
# fi
# LIBGCC_DIR=$(dirname "${LIBGCC_FILE}")
# case "${KERNEL_ARCH}" in
# 	x86_64)
# 		echo "dir /usr/lib/gcc/x86_64-pc-linux-gnu 755 0 0" >> "${CPIO_LIST}"
# 		echo "file /lib64/libgcc_s.so.1 ${LIBGCC_FILE} 755 0 0" >> "${CPIO_LIST}"
# 		;;
# 	x86)
# 		echo "dir /usr/lib/gcc/i686-pc-linux-gnu 755 0 0" >> "${CPIO_LIST}"
# 		echo "file /lib/libgcc_s.so.1 ${LIBGCC_FILE} 755 0 0" >> "${CPIO_LIST}"
# 		;;
# esac

for SOFT_ITEM in ${SOFT_ITEMS}; do
	if [ -e "${SOFT_ITEM}" ]; then
		if [ ! -L "${SOFT_ITEM}" ]; then
			declare -a DIRECT_LIBS_ARRAY=($(ldd "${SOFT_ITEM}" 2>/dev/null | grep -v "${ELF_IGNORE}" | grep -v '=>' | awk '{print $1}'))
			declare -a LINKED_LIBS_ARRAY=($(ldd "${SOFT_ITEM}" 2>/dev/null | grep '=>' | awk '{print $3}'))
			for LIB in ${DIRECT_LIBS_ARRAY[@]} ${LINKED_LIBS_ARRAY[@]}; do
				if ! (printf '%s\n' "${LIB_ITEMS[@]}" | grep -xq "${LIB}"); then
					LIB_ITEMS+=("${LIB}")
				fi

				if [ -L "${LIB}" ]; then
					TARGET_LIB=$(readlink -f "${LIB}")
					if ! (printf '%s\n' "${LIB_ITEMS[@]}" | grep -xq "${TARGET_LIB}"); then
						LIB_ITEMS+=("${TARGET_LIB}")
					fi
				fi
			done
		fi
	else
		echo "Bad soft file: ${SOFT_ITEM}" >&2
		exit 2
	fi
done

# for NSSLIB in $(ls -1 /lib/libnss_*); do
# 	if ! (printf '%s\n' "${LIB_ITEMS[@]}" | grep -xq "${NSSLIB}"); then
# 		LIB_ITEMS+=("${NSSLIB}")
# 	fi
# done

# case "${KERNEL_ARCH}" in
# 	x86_64)
# 		for NSSLIB in $(ls -1 /lib64/libnss_*); do
# 			if ! (printf '%s\n' "${LIB_ITEMS[@]}" | grep -xq "${NSSLIB}"); then
# 				LIB_ITEMS+=("${NSSLIB}")
# 			fi
# 		done
# 		;;
# esac

# for RESOLVLIB in $(ls -1 /lib/libresolv*); do
# 	if ! (printf '%s\n' "${LIB_ITEMS[@]}" | grep -xq "${RESOLVLIB}"); then
# 		LIB_ITEMS+=("${RESOLVLIB}")
# 	fi
# done

for LIB_ITEM in ${LIB_ITEMS[@]}; do
	if [ -e "${LIB_ITEM}" ]; then
		# # Right now pass all libs as files (without symlinks)
		# echo "file ${LIB_ITEM} ${LIB_ITEM} 755 0 0" >> "${CPIO_LIST}"

		if [ -L "${LIB_ITEM}" ]; then
			TARGET_LIB_ITEM=$(readlink -f "${LIB_ITEM}")
			echo "slink ${LIB_ITEM} ${TARGET_LIB_ITEM} 755 0 0" >> "${CPIO_LIST}"
		else
			echo "file ${LIB_ITEM} ${LIB_ITEM} 755 0 0" >> "${CPIO_LIST}"
		fi
	else
		echo "Bad soft file: ${LIB_ITEM}" >&2
		exit 2
	fi
done

for SOFT_ITEM in ${SOFT_ITEMS}; do
	if [ -e "${SOFT_ITEM}" ]; then
		if [ -L "${SOFT_ITEM}" ]; then
			TARGET_SOFT_ITEM=$(readlink -f "${SOFT_ITEM}")
			echo "slink ${SOFT_ITEM} ${TARGET_SOFT_ITEM} 755 0 0" >> "${CPIO_LIST}"
		else
			echo "file ${SOFT_ITEM} ${SOFT_ITEM} 755 0 0" >> "${CPIO_LIST}"
		fi
	else
		echo "Bad soft file: ${SOFT_ITEM}" >&2
		exit 2
	fi
done

echo >> "${CPIO_LIST}"


echo "# Modules" >> "${CPIO_LIST}"
echo >> "${CPIO_LIST}"

if [ -d "/cache/${KERNEL_SLUG}/modules/lib/modules" ]; then
	cd "/cache/${KERNEL_SLUG}/modules/lib/modules"
	for n in $(find *); do
		echo "Adding module $n..."
		[ -d $n ] && echo "dir /lib/modules/$n 700 0 0" >> "${CPIO_LIST}"
		[ -f $n ] && echo "file /lib/modules/$n /cache/${KERNEL_SLUG}/modules/lib/modules/$n 600 0 0" >> "${CPIO_LIST}"
	done
fi

echo >> "${CPIO_LIST}"
find /lib/udev -type d | while read D; do
	echo "dir $D 755 0 0" >> "${CPIO_LIST}"
done
find /lib/udev -type f | while read F; do 
	MODE=$(stat -c %a $F)
	echo "file $F $F $MODE 0 0" >> "${CPIO_LIST}"
done

cd "/usr/src/linux"

[ ! -d /preboot.build/boot ] && mkdir /preboot.build/boot
echo "Generating initramfs file /preboot.build/boot/initramfs.cpio.gz..."
./usr/gen_initramfs.sh -o "/preboot.build/boot/initramfs.cpio" "${CPIO_LIST}"
gzip --best --force "/preboot.build/boot/initramfs.cpio"

# Debugging

echo "Unpack final image into /preboot.build/initramfs.debug"
[ -d "/preboot.build/initramfs.debug" ] && rm -rf "/preboot.build/initramfs.debug"
mkdir -p "/preboot.build/initramfs.debug"
cd "/preboot.build/initramfs.debug"
zcat "/preboot.build/boot/initramfs.cpio.gz" | cpio --extract || /bin/busybox
echo "Chrooting..."
cat "${CPIO_LIST}" > /preboot.build/boot/initramfs.txt
# chroot . /bin/busybox sh -i

# /bin/busybox sh
