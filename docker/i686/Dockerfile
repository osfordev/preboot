# https://hub.docker.com/r/zxteamorg/gentoo-sources-bundle
ARG GENTOO_SOURCES_BUDNLE_IMAGE_TAG=latest


# Target container with Gentoo Linux + necessary tools to build kernel and initramfs
FROM --platform=linux/386 zxteamorg/gentoo-sources-bundle:${GENTOO_SOURCES_BUDNLE_IMAGE_TAG} as stage

RUN \
  emerge-webrsync && \
  rm -r /etc/portage/package.use && \
  echo >> /etc/portage/make.conf && \
  echo '# OS For Dev Preboot toolchain' >> /etc/portage/make.conf && \
  echo 'ACCEPT_LICENSE="intel-ucode linux-fw-redistributable no-source-code"' >> /etc/portage/make.conf && \
  echo 'FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox -sandbox -usersandbox"' >> /etc/portage/make.conf && \
  echo 'USE="-ipv6 -pam static static-libs -udev"' >> /etc/portage/make.conf && \
  echo 'sys-apps/busybox mdev -pam' >> /etc/portage/package.use && \
  echo 'sys-apps/util-linux -su' >> /etc/portage/package.use && \
  echo 'sys-fs/lvm2 lvm' >> /etc/portage/package.use

RUN \
  emerge --quiet --oneshot \
    sys-apps/busybox \
    sys-apps/kexec-tools \
    sys-boot/syslinux \
    sys-fs/lvm2 \
    sys-fs/mdadm

RUN \
  eselect kernel set 1

# Compile gen_init_cpio tool. See https://github.com/torvalds/linux/blob/master/usr/gen_init_cpio.c
RUN \
  cd /usr/src/linux && make -C usr/ gen_init_cpio && chmod +x usr/gen_init_cpio usr/gen_initramfs.sh

RUN \
  rm -rf /run/*; \
  rm -rf /tmp/*; \
  rm -rf /usr/share/man; \
  rm -rf /var/cache/*; \
  rm -rf /var/db/repos/*; \
  rm -rf /var/log/*; \
  rm -rf /var/tmp/*

COPY docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint-osfordev-preboot-toolchain.sh


FROM scratch
COPY --from=stage / /
VOLUME [ "/cache" ]
ENTRYPOINT [ "/usr/local/bin/docker-entrypoint-osfordev-preboot-toolchain.sh" ]
