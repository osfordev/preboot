#!/bin/bash
#

set -e

if [ ! -f /preboot/BANNER ]; then
	echo "Look like you have wrong toolchain container. The container should present a file /preboot/BANNER" >&2
	exit 11
fi
cat /preboot/BANNER

if [ ! -f /KERNEL_VERSION ]; then
	echo "Look like you have wrong toolchain container. The container should present a file /KERNEL_VERSION" >&2
	exit 12
fi
KERNEL_VERSION=$(cat /KERNEL_VERSION)
if [ -z "${KERNEL_VERSION}" ]; then
	echo "Look like you have wrong toolchain container. The container should present a file /KERNEL_VERSION with proper kernel version." >&2
	exit 13
fi

if [ ! -f /DOCKER_ARCH ]; then
	echo "Look like you have wrong build container. The container should present a file /DOCKER_ARCH" >&2
	exit 14
fi
DOCKER_ARCH=$(cat /DOCKER_ARCH)
if [ -z "${DOCKER_ARCH}" ]; then
	echo "Look like you have wrong build container. The container should present a file /DOCKER_ARCH with proper arch value." >&2
	exit 15
fi

if [ ! -d /preboot.build/gentoo-overlay ]; then
	echo
	echo "Cloning gentoo-overlay ..."
	cd /preboot.build
	git clone --depth 1 -b master https://github.com/osfordev/gentoo-overlay.git
else
	echo
	echo "Updating gentoo-overlay ..."
	cd /preboot.build/gentoo-overlay
	git pull
fi

# https://www.kernel.org/doc/html/v5.14/kbuild/kconfig.html#kconfig-overwriteconfig
# If you set KCONFIG_OVERWRITECONFIG in the environment,
# Kconfig will not break symlinks when .config is a symlink to somewhere else.
export KCONFIG_OVERWRITECONFIG=y

case "${DOCKER_ARCH}" in
	linux/386)
		KERNEL_ARCH=x86
		KERNEL_CONFIG=i686
		;;
	linux/amd64)
		KERNEL_ARCH=x86_64
		KERNEL_CONFIG=amd64
		;;
	*)
		echo "Unsupported DOCKER_ARCH: ${DOCKER_ARCH}" >&2
		exit 62
		;;
esac

if [ -f /preboot.build/preboot/vmlinuz ]; then
	echo "Skip kernel build due /preboot.build/preboot/vmlinuz already presented"
else
	#
	# Kernel
	#
	cd /usr/src/linux
	KERNEL_SLUG=$(basename $(pwd -LP) | cut -d- -f2-)
	export KBUILD_OUTPUT="/cache/${KERNEL_SLUG}/kernel"
	[ ! -d "${KBUILD_OUTPUT}" ] && mkdir --parents "${KBUILD_OUTPUT}"

	if [ ! -f "/preboot/kernel/${KERNEL_CONFIG}/config-${KERNEL_VERSION}-gentoo" ]; then
		echo "Kernel configuration /preboot/kernel/${KERNEL_CONFIG}/config-${KERNEL_VERSION}-gentoo was not found. Cannot continue." >&2
		exit 1
	fi
	rm -f "${KBUILD_OUTPUT}/.config"
	ln -s "/preboot/kernel/${KERNEL_CONFIG}/config-${KERNEL_VERSION}-gentoo" "${KBUILD_OUTPUT}/.config"
	make oldconfig
	if tty >/dev/null; then
		make menuconfig
	else
		echo "Skipping 'make menuconfig' due to non-interactive terminal."
	fi
	make "-j$(nproc)"
	INSTALL_MOD_PATH="/cache/${KERNEL_SLUG}/modules" make modules_install
	cd "${KBUILD_OUTPUT}"
	[ -d /preboot.build/preboot ] && rm -r /preboot.build/preboot
	mkdir /preboot.build/preboot
	cp --verbose "System.map"                               "/preboot.build/preboot/System.map"
	cp --verbose ".config"                                  "/preboot.build/preboot/config"
	cp --verbose "arch/${KERNEL_ARCH}/boot/bzImage"         "/preboot.build/preboot/vmlinuz"

	# cd "/cache/${KERNEL_SLUG}/modules"
	# tar --create --gzip --preserve-permissions --file="/cache/${KERNEL_SLUG}/modules.tar.gz" lib/modules


fi

if [ -f /preboot.build/preboot/initramfs.cpio.gz ]; then
	echo "Skip generating initramfs file /preboot.build/preboot/initramfs.cpio.gz due already presented"
else
	echo "Building initramfs..."
	if [ -d "/cache/${KERNEL_SLUG}/initramfs" ]; then
		rm --force --recursive "/cache/${KERNEL_SLUG}/initramfs"
	fi

	echo "Initialize initramfs configuration..."
	mkdir "/cache/${KERNEL_SLUG}/initramfs"
	cp /preboot/BANNER "/cache/${KERNEL_SLUG}/initramfs/BANNER"
	cp --archive "/preboot/initramfs/fs/"* "/cache/${KERNEL_SLUG}/initramfs/"
	cp --archive "/preboot/initramfs/fs.${KERNEL_CONFIG}"/* "/cache/${KERNEL_SLUG}/initramfs/"

	CPIO_LIST=$(mktemp)
	cat "/preboot/initramfs/initramfs_list.${KERNEL_CONFIG}" >> "${CPIO_LIST}"
	echo >> "${CPIO_LIST}"

	echo "file /etc/group               /cache/${KERNEL_SLUG}/initramfs/etc/group               644 0 0" >> "${CPIO_LIST}"
	echo "file /etc/ld.so.conf          /etc/ld.so.conf                                         644 0 0" >> "${CPIO_LIST}"
	echo "file /etc/nsswitch.conf       /cache/${KERNEL_SLUG}/initramfs/etc/nsswitch.conf       644 0 0" >> "${CPIO_LIST}"
	echo "file /etc/passwd              /cache/${KERNEL_SLUG}/initramfs/etc/passwd              644 0 0" >> "${CPIO_LIST}"
	echo "file /init                    /cache/${KERNEL_SLUG}/initramfs/init                    755 0 0" >> "${CPIO_LIST}"
	echo "file /init-base.functions     /cache/${KERNEL_SLUG}/initramfs/init-base.functions     755 0 0" >> "${CPIO_LIST}"
	echo "file /init-platform.functions /cache/${KERNEL_SLUG}/initramfs/init-platform.functions 755 0 0" >> "${CPIO_LIST}"
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


	# echo "# Modules" >> "${CPIO_LIST}"
	# echo >> "${CPIO_LIST}"

	# if [ -d "/cache/${KERNEL_SLUG}/modules/lib/modules" ]; then
	# 	cd "/cache/${KERNEL_SLUG}/modules/lib/modules"
	# 	for n in $(find *); do
	# 		echo "Adding module $n..."
	# 		[ -d $n ] && echo "dir /lib/modules/$n 700 0 0" >> "${CPIO_LIST}"
	# 		[ -f $n ] && echo "file /lib/modules/$n /cache/${KERNEL_SLUG}/modules/lib/modules/$n 600 0 0" >> "${CPIO_LIST}"
	# 	done
	# fi

	# echo >> "${CPIO_LIST}"
	# find /lib/udev -type d | while read D; do
	# 	echo "dir $D 755 0 0" >> "${CPIO_LIST}"
	# done
	# find /lib/udev -type f | while read F; do 
	# 	MODE=$(stat -c %a $F)
	# 	echo "file $F $F $MODE 0 0" >> "${CPIO_LIST}"
	# done

	cd "/usr/src/linux"

	echo "Generating initramfs file /preboot.build/preboot/initramfs.cpio.gz..."
	./usr/gen_initramfs.sh -o "/preboot.build/preboot/initramfs.cpio" "${CPIO_LIST}"
	gzip --best --force "/preboot.build/preboot/initramfs.cpio"

	mkdir --parents /preboot.build/preboot/EFI/BOOT/

	echo "Copying artifacts ..."
	cp --archive /usr/share/syslinux/efi64/syslinux.efi /preboot.build/preboot/EFI/BOOT/BOOTX64.EFI
	cp --archive /usr/share/syslinux/efi64/ldlinux.e64  /preboot.build/preboot/EFI/BOOT/ldlinux.e64
	cp --archive /usr/share/syslinux/efi64/*.c32        /preboot.build/preboot/EFI/BOOT/
	
	echo "Setup SYSLINUX"
	cat <<EOF > /preboot.build/preboot/EFI/BOOT/syslinux.cfg
PROMPT 1
TIMEOUT 900
ONTIMEOUT preboot
DEFAULT preboot
LABEL preboot
KERNEL /vmlinuz
INITRD /initramfs.cpio.gz
EOF

fi

#
# Debugging
#
if [ -d /preboot.build/initramfs.debug ]; then
	echo "Skip unpack final image into /preboot.build/initramfs.debug due already presented"
else
	echo "Unpack final image into /preboot.build/initramfs.debug"
	[ -d "/preboot.build/initramfs.debug" ] && rm -rf "/preboot.build/initramfs.debug"
	mkdir -p "/preboot.build/initramfs.debug"
	cd "/preboot.build/initramfs.debug"
	zcat "/preboot.build/preboot/initramfs.cpio.gz" | cpio --extract || /bin/busybox
	echo "Chrooting..."
	cat "${CPIO_LIST}" > /preboot.build/initramfs.debug.txt
	# chroot . /bin/busybox sh -i

	# /bin/busybox sh
fi

#
# Cleanup (from previous runs)
#
/sbin/losetup --detach-all

BOOT_PARTITION_SIZE_MB=48
IMAGE_SIZE_B=$((${BOOT_PARTITION_SIZE_MB}*2*1024*1024+2048*512))
IMAGE_FILE="/preboot.build/preboot-amd64.img"

for LOOP_INDEX in $(seq 0 9); do
	if [ ! -b /dev/loop${LOOP_INDEX} ]; then
		mknod /dev/loop${LOOP_INDEX} -m0660 b 7 ${LOOP_INDEX}
	fi
done

echo
echo -n "Searching for available loop device... "
LO_DEV=$(/sbin/losetup --find) || exit 1
echo "Found ${LO_DEV}"

if [ -f "${IMAGE_FILE}" ]; then
	rm "${IMAGE_FILE}"
fi
echo
echo -n "Creating ${IMAGE_FILE} ${IMAGE_SIZE_B}B image ... "
truncate "--size=${IMAGE_SIZE_B}" "${IMAGE_FILE}" || exit 2
echo "Done"

echo
echo -n "Setting loop device ${LO_DEV} => ${IMAGE_FILE} ... "
/sbin/losetup "${LO_DEV}" "${IMAGE_FILE}"
echo "Done"


echo
echo "Make partitions... "
# echo ",${BOOT_PARTITION_SIZE_MB}M" | sfdisk --wipe always --label dos --no-reread --no-tell-kernel "${LO_DEV}" || exit 4
# sfdisk --part-type "${LO_DEV}" 1 06 || exit 4

sfdisk --wipe always --label gpt --no-reread --no-tell-kernel "${LO_DEV}" <<EOF
,${BOOT_PARTITION_SIZE_MB}M,C12A7328-F81F-11D2-BA4B-00A0C93EC93B
,${BOOT_PARTITION_SIZE_MB}M,0FC63DAF-8483-4772-8E79-3D69D8477DE4
EOF
sfdisk  --part-attrs "${LO_DEV}" 2 LegacyBIOSBootable

dd if=/usr/share/syslinux/gptmbr.bin bs=440 count=1 conv=notrunc of="${LO_DEV}"

echo
echo -n "Re-setting loop device ${LO_DEV} => ${IMAGE_FILE} with --partscan option ... "
/sbin/losetup --detach "${LO_DEV}" || exit 5
/sbin/losetup --partscan "${LO_DEV}" "${IMAGE_FILE}" || exit 6
echo "Done"

echo
echo "Fixing loop partitions ... "
PARTITIONS=$(lsblk --raw --output "MAJ:MIN" --noheadings "${LO_DEV}" | tail -n +2)
COUNTER=1
for i in $PARTITIONS; do
	MAJ=$(echo $i | cut -d: -f1)
	MIN=$(echo $i | cut -d: -f2)
	if [ ! -e "${LO_DEV}p${COUNTER}" ]; then 
		mknod ${LO_DEV}p${COUNTER} b $MAJ $MIN
	fi
	echo "	${LO_DEV}p${COUNTER}"
	COUNTER=$((COUNTER + 1))
done
echo "Done"

echo
echo "Creating FAT32 filesystem on ${LO_DEV}p1 ... "
mkfs.vfat -F 32 -n EFI_BOOT "${LO_DEV}p1" 
echo "Creating ext4 filesystem on ${LO_DEV}p2 ... "
# As of Syslinux 6.03, "pure 64bit", compression and/or encryption are not supported.
mkfs.ext4 -L legacy_boot -O "^64bit" "${LO_DEV}p2"

# umask 0022

echo
echo "Mounting EFI partition..."
mount "${LO_DEV}p1" /mnt

mkdir --parents /mnt/EFI/BOOT/

echo "Copying artifacts ..."
cp --archive /usr/share/syslinux/efi64/syslinux.efi /mnt/EFI/BOOT/BOOTX64.EFI
cp --archive /usr/share/syslinux/efi64/ldlinux.e64  /mnt/EFI/BOOT/ldlinux.e64
cp --archive /usr/share/syslinux/efi64/*.c32        /mnt/EFI/BOOT/
cp --archive /preboot.build/preboot/*               /mnt/

echo "Setup SYSLINUX"
cat <<EOF > /mnt/EFI/BOOT/syslinux.cfg
PROMPT 1
TIMEOUT 900
ONTIMEOUT preboot
DEFAULT preboot
LABEL preboot
  KERNEL /vmlinuz
  INITRD /initramfs.cpio.gz
EOF

echo
echo "Zero-ing empty space..."
dd if=/dev/zero of=/mnt/null.dat >/dev/null 2>&1 || true
rm /mnt/null.dat

echo "Unmounting EFI partition..."
umount "${LO_DEV}p1"

echo "Mounting legacy_boot partition..."
mount "${LO_DEV}p2" /mnt

mkdir /mnt/extlinux

echo "Copying artifacts ..."
cp --archive /usr/share/syslinux/*.c32 /mnt/extlinux/
cp --archive /preboot.build/preboot/*  /mnt/

echo "Setup EXTLINUX"
extlinux --install /mnt/extlinux/
cat <<EOF > /mnt/extlinux/syslinux.cfg
PROMPT 1
TIMEOUT 900
ONTIMEOUT preboot
DEFAULT preboot
LABEL preboot
  KERNEL /vmlinuz
  INITRD /initramfs.cpio.gz
EOF

echo
echo "Zero-ing empty space..."
dd if=/dev/zero of=/mnt/null.dat >/dev/null 2>&1 || true
rm /mnt/null.dat

echo "Unmounting legacy_boot partition..."
umount "${LO_DEV}p2"

echo
echo "Destructing..."
/sbin/losetup --detach "${LO_DEV}"

echo
echo "Calculating SHA1 of the image ${IMAGE_FILE} ..."
sha1sum "${IMAGE_FILE}" | tee "${IMAGE_FILE}.sha1"

echo
echo "ZIP image ${IMAGE_FILE} ..."
cat "${IMAGE_FILE}" | gzip > "${IMAGE_FILE}.gz"

echo
echo "Your image is ready"
echo
