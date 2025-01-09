#!/bin/bash -l
#

set -e

if [ ! -f /preboot/BANNER ]; then
    echo "Look like you have wrong toolchain container. The container should present a file /preboot/BANNER" >&2
    exit 11
fi
cat /preboot/BANNER

if [ -z "${SITE}" ]; then
    echo "Look like you have wrong toolchain container. The container should present an environment variable SITE (like: 27K51EA#A2Q, ASRockPV530, etc.). See https://github.com/osfordev/gentoo-overlay/tree/master/profiles for relevant values." >&2
    exit 12
fi

if [ -z "${KERNEL_VERSION}" ]; then
    echo "Look like you have wrong toolchain container. The container should present an environment variable KERNEL_VERSION with proper kernel version." >&2
    exit 13
fi

if [ -z "${DOCKER_ARCH}" ]; then
    echo "Look like you have wrong build container. The container should present an environment variable DOCKER_ARCH with proper arch value."
    exit 15
fi

case "${DOCKER_ARCH}" in
    linux/386)
        KERNEL_ARCH=x86
        OSFORDEV_ARCH=i686
        ;;
    linux/amd64)
        KERNEL_ARCH=x86_64
        OSFORDEV_ARCH=amd64
        ;;
    *)
        echo "Unsupported (yet) DOCKER_ARCH: ${DOCKER_ARCH}" >&2
        exit 62
        ;;
esac

cd /usr/src/linux

KERNEL_SLUG=$(basename $(pwd -LP) | cut -d- -f2-)
export KBUILD_OUTPUT="/cache/${KERNEL_SLUG}/kernel"
[ ! -d "${KBUILD_OUTPUT}" ] && mkdir --parents "${KBUILD_OUTPUT}"

# Sync osfordev repository (overlay) to point kernel config
emerge --sync osfordev


KERNEL_CONFIG_FILE="/var/db/repos/osfordev/profiles/${SITE}/kernel.config"
if [ ! -f "${KERNEL_CONFIG_FILE}" ]; then
    echo "Wrong value '${SITE}' for the environment variable SITE. Kernel configuration was not found by path '${KERNEL_CONFIG_FILE}'. See https://github.com/osfordev/gentoo-overlay/tree/master/profiles for relevant values." >&2
    exit 1
fi

rm -f "${KBUILD_OUTPUT}/.config"
ln -s "${KERNEL_CONFIG_FILE}" "${KBUILD_OUTPUT}/.config"

make oldconfig
if [ "${MENUCONFIG}" == "yes" ]; then
    if tty >/dev/null; then
        make menuconfig
    else
        echo "Skipping 'make menuconfig' due to non-interactive terminal."
    fi
fi

cp -a "${KERNEL_CONFIG_FILE}" "${KERNEL_CONFIG_FILE}-bak"

KEXEC_CONFIG_SCRIPT="/preboot/kexec-config/kexec-config-${SITE}.sh"
if [ -x "${KEXEC_CONFIG_SCRIPT}" ]; then
    echo "Enable kexec by execute config script ${KEXEC_CONFIG_SCRIPT} ..."
    KERNEL_CONFIG_FILE="${KERNEL_CONFIG_FILE}" ${KEXEC_CONFIG_SCRIPT}
else
    echo "Enable kexec ..."
    ./scripts/config --file "${KERNEL_CONFIG_FILE}" --enable "KEXEC"
    ./scripts/config --file "${KERNEL_CONFIG_FILE}" --enable "KEXEC_CORE"
    ./scripts/config --file "${KERNEL_CONFIG_FILE}" --disable "BLK_DEV_LOOP"
fi

echo "=== Enable kexec diff ==="
diff "${KERNEL_CONFIG_FILE}" "${KERNEL_CONFIG_FILE}-bak" || true
echo "========================="

make "-j$(nproc)"
INSTALL_MOD_PATH="/cache/${KERNEL_SLUG}/modules" make modules_install

cd "${KBUILD_OUTPUT}"
[ ! -d "/cache/${KERNEL_SLUG}/boot" ] && mkdir          "/cache/${KERNEL_SLUG}/boot"
cp --verbose "System.map"                               "/cache/${KERNEL_SLUG}/boot/System.map"
cp --verbose ".config"                                  "/cache/${KERNEL_SLUG}/boot/config"
cp --verbose "arch/${KERNEL_ARCH}/boot/bzImage"         "/cache/${KERNEL_SLUG}/boot/vmlinuz"

# [ ! -d /preboot.build/boot ] && mkdir /preboot.build/boot
# cp --verbose "System.map"                       "/preboot.build/boot/System.map"
# cp --verbose ".config"                          "/preboot.build/boot/config"
# cp --verbose "arch/${KERNEL_ARCH}/boot/bzImage" "/preboot.build/boot/vmlinuz"

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
cp --archive "/preboot/initramfs/fs.${OSFORDEV_ARCH}"/* "/cache/${KERNEL_SLUG}/initramfs/"

CPIO_LIST=$(mktemp)
chmod 644 "${CPIO_LIST}"
cat "/preboot/initramfs/initramfs_list.${OSFORDEV_ARCH}" >> "${CPIO_LIST}"
echo >> "${CPIO_LIST}"

echo "file /BANNER                  /cache/${KERNEL_SLUG}/initramfs/BANNER                  644 0 0" >> "${CPIO_LIST}"
echo "file /etc/group               /cache/${KERNEL_SLUG}/initramfs/etc/group               644 0 0" >> "${CPIO_LIST}"
echo "file /etc/ld.so.conf          /etc/ld.so.conf                                         644 0 0" >> "${CPIO_LIST}"
echo "file /etc/nsswitch.conf       /cache/${KERNEL_SLUG}/initramfs/etc/nsswitch.conf       644 0 0" >> "${CPIO_LIST}"
echo "file /etc/passwd              /cache/${KERNEL_SLUG}/initramfs/etc/passwd              644 0 0" >> "${CPIO_LIST}"
echo "file /init                    /cache/${KERNEL_SLUG}/initramfs/init                    755 0 0" >> "${CPIO_LIST}"
echo "file /init-base.functions     /cache/${KERNEL_SLUG}/initramfs/init-base.functions     644 0 0" >> "${CPIO_LIST}"
echo "file /init-platform.functions /cache/${KERNEL_SLUG}/initramfs/init-platform.functions 644 0 0" >> "${CPIO_LIST}"
echo >> "${CPIO_LIST}"


echo "# Software" >> "${CPIO_LIST}"
SOFT_ITEMS=""

# Busybox
SOFT_ITEMS="${SOFT_ITEMS} /bin/busybox"

# KExec
SOFT_ITEMS="${SOFT_ITEMS} /usr/sbin/kexec /usr/sbin/vmcore-dmesg"

# LVM stuff
SOFT_ITEMS="${SOFT_ITEMS} /sbin/dmsetup /sbin/lvm /usr/bin/lvm /sbin/lvcreate /sbin/lvdisplay /sbin/lvextend /sbin/lvremove /sbin/lvresize /sbin/lvs /sbin/pvcreate /sbin/pvdisplay /sbin/pvresize /sbin/vgchange /sbin/vgcreate /sbin/vgdisplay /sbin/vgextend /sbin/vgrename /sbin/vgscan"
echo "dir /etc/lvm 755 0 0" >> "${CPIO_LIST}"
echo "file /etc/lvm/lvm.conf /etc/lvm/lvm.conf 644 0 0" >> "${CPIO_LIST}"

# Tool for running RAID systems
SOFT_ITEMS="${SOFT_ITEMS} /sbin/mdadm"
echo "file /etc/mdadm.conf /cache/${KERNEL_SLUG}/initramfs/etc/mdadm.conf 644 0 0" >> "${CPIO_LIST}"

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

if [ -d "/cache/${KERNEL_SLUG}/modules/lib/modules/${KERNEL_SLUG}-${SITE}" ]; then
    cd "/cache/${KERNEL_SLUG}/modules/lib/modules/${KERNEL_SLUG}-${SITE}"
    for n in $(find *); do
        echo "Adding module $n..."
        [ -d $n ] && echo "dir /lib/modules/${KERNEL_SLUG}-${SITE}/$n 700 0 0" >> "${CPIO_LIST}"
        [ -f $n ] && echo "file /lib/modules/${KERNEL_SLUG}-${SITE}/$n /cache/${KERNEL_SLUG}/modules/lib/modules/${KERNEL_SLUG}-${SITE}/$n 600 0 0" >> "${CPIO_LIST}"
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

echo "Generating initramfs file /cache/${KERNEL_SLUG}/boot/initramfs.cpio.gz ..."
./usr/gen_initramfs.sh -o "/cache/${KERNEL_SLUG}/boot/initramfs.cpio" "${CPIO_LIST}"
cp -a "${CPIO_LIST}" "/cache/${KERNEL_SLUG}/boot/initramfs.cpio.list"

make \
    CONFIG_INITRAMFS_SOURCE="/cache/${KERNEL_SLUG}/boot/initramfs.cpio" \
    CONFIG_INITRAMFS_ROOT_UID="0" \
    CONFIG_INITRAMFS_ROOT_GID="0" \
    CONFIG_INITRAMFS_COMPRESSION_NONE="y" \
    "-j$(nproc)"

cd "${KBUILD_OUTPUT}"
[ ! -d /preboot.build/boot ] && mkdir /preboot.build/boot
cp --verbose "System.map"                       "/preboot.build/boot/preboot-${SITE}-System.map"
cp --verbose ".config"                          "/preboot.build/boot/preboot-${SITE}-config"
cp --verbose "arch/${KERNEL_ARCH}/boot/bzImage" "/preboot.build/boot/preboot-${SITE}"

# # Debugging

# echo "Unpack final image into /preboot.build/initramfs.debug"
# [ -d "/preboot.build/initramfs.debug" ] && rm -rf "/preboot.build/initramfs.debug"
# mkdir -p "/preboot.build/initramfs.debug"
# cd "/preboot.build/initramfs.debug"
# zcat "/preboot.build/boot/initramfs.cpio.gz" | cpio --extract || /bin/busybox
# echo "Chrooting..."
# cat "${CPIO_LIST}" > /preboot.build/boot/initramfs.txt
# # chroot . /bin/busybox sh -i
# # /bin/busybox sh

#
# Build disk image
#

## TODO
