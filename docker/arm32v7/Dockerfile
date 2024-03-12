# https://hub.docker.com/r/theanurin/gentoo-sources-bundle
ARG GENTOO_SOURCES_BUNDLE_IMAGE_TAG=latest


# Target container with Gentoo Linux + necessary tools to build kernel and initramfs
FROM --platform=linux/arm/v7 theanurin/gentoo-sources-bundle:${GENTOO_SOURCES_BUNDLE_IMAGE_TAG} as stage

RUN \
  emerge-webrsync && \
  echo >> /etc/portage/make.conf && \
  echo '# OS For Dev Preboot toolchain' >> /etc/portage/make.conf && \
  echo 'ACCEPT_LICENSE="intel-ucode linux-fw-redistributable no-source-code"' >> /etc/portage/make.conf && \
  echo 'FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox -sandbox -usersandbox"' >> /etc/portage/make.conf && \
  echo 'USE="-ipv6 -pam static static-libs -udev"' >> /etc/portage/make.conf && \
  mkdir --parents /etc/portage/repos.conf && \
  echo '[osfordev]' >> /etc/portage/repos.conf/osfordev-repo.conf && \
  echo 'location = /var/db/repos/osfordev' >> /etc/portage/repos.conf/osfordev-repo.conf && \
  echo 'sync-type = git' >> /etc/portage/repos.conf/osfordev-repo.conf && \
  echo 'sync-uri = https://github.com/osfordev/gentoo-overlay.git' >> /etc/portage/repos.conf/osfordev-repo.conf && \
  echo 'sync-git-clone-extra-opts = --single-branch --branch master' >> /etc/portage/repos.conf/osfordev-repo.conf && \
  echo 'auto-sync = yes' >> /etc/portage/repos.conf/osfordev-repo.conf && \
  rm --recursive /etc/portage/package.accept_keywords && \
  echo 'sys-apps/kexec-tools ~arm64' >> /etc/portage/package.accept_keywords && \
  rm --recursive /etc/portage/package.use && \
  echo 'sys-apps/busybox mdev -pam' >> /etc/portage/package.use && \
  echo 'sys-apps/util-linux -su' >> /etc/portage/package.use && \
  echo 'sys-fs/lvm2 lvm' >> /etc/portage/package.use

RUN \
  emerge --quiet --oneshot \
    dev-lang/swig \
    dev-vcs/git \
    net-wireless/wireless-regdb \
    sys-apps/busybox \
    sys-apps/kexec-tools \
    sys-fs/dosfstools \
    sys-fs/lvm2 \
    sys-fs/mdadm

RUN \
  cd /opt && \
  git clone --depth 1 --branch v2023.04 https://source.denx.de/u-boot/u-boot.git

RUN \
  eselect kernel set 1

# Compile gen_init_cpio tool. See https://github.com/torvalds/linux/blob/master/usr/gen_init_cpio.c
RUN \
  cd /usr/src/linux && make -C usr/ gen_init_cpio && chmod +x usr/gen_init_cpio usr/gen_initramfs.sh

RUN \
  rm --recursive --force /run/*; \
  rm --recursive --force /tmp/*; \
  rm --recursive --force /usr/share/man; \
  rm --recursive --force /var/cache/*; \
  rm --recursive --force /var/db/repos/*; \
  rm --recursive --force /var/log/*; \
  rm --recursive --force /var/tmp/*

COPY docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint-osfordev-preboot-toolchain.sh


FROM scratch
COPY --from=stage / /
VOLUME [ "/cache" ]
ENTRYPOINT [ "/usr/local/bin/docker-entrypoint-osfordev-preboot-toolchain.sh" ]
