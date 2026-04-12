#!/bin/bash

set -eu

./scripts/config --file "${KERNEL_CONFIG_FILE}" --disable "CRASH_DUMP"
./scripts/config --file "${KERNEL_CONFIG_FILE}" --enable "EXPERT"
./scripts/config --file "${KERNEL_CONFIG_FILE}" --enable "EFI_RUNTIME_MAP"
./scripts/config --file "${KERNEL_CONFIG_FILE}" --enable "EFI_STUB"
./scripts/config --file "${KERNEL_CONFIG_FILE}" --enable "KEXEC"
./scripts/config --file "${KERNEL_CONFIG_FILE}" --enable "KEXEC_CORE"
./scripts/config --file "${KERNEL_CONFIG_FILE}" --disable "KEXEC_JUMP"
./scripts/config --file "${KERNEL_CONFIG_FILE}" --enable "FB_VGA16"
./scripts/config --file "${KERNEL_CONFIG_FILE}" --enable "FB_SIMPLE"

./scripts/config --file "${KERNEL_CONFIG_FILE}" --disable "BLK_DEV_LOOP"
./scripts/config --file "${KERNEL_CONFIG_FILE}" --disable "BT"
./scripts/config --file "${KERNEL_CONFIG_FILE}" --disable "CFG80211"
./scripts/config --file "${KERNEL_CONFIG_FILE}" --disable "DRM"
./scripts/config --file "${KERNEL_CONFIG_FILE}" --disable "ETHERNET"
./scripts/config --file "${KERNEL_CONFIG_FILE}" --disable "FW_LOADER"
./scripts/config --file "${KERNEL_CONFIG_FILE}" --disable "PCCARD"
./scripts/config --file "${KERNEL_CONFIG_FILE}" --disable "PCMCIA"
./scripts/config --file "${KERNEL_CONFIG_FILE}" --disable "RMI4_CORE"
./scripts/config --file "${KERNEL_CONFIG_FILE}" --disable "SOUND"
./scripts/config --file "${KERNEL_CONFIG_FILE}" --disable "SND"
./scripts/config --file "${KERNEL_CONFIG_FILE}" --disable "WIRELESS"
./scripts/config --file "${KERNEL_CONFIG_FILE}" --disable "X86_UV"
