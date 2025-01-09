#!/bin/bash

./scripts/config --file "${KERNEL_CONFIG_FILE}" --enable "KEXEC"
./scripts/config --file "${KERNEL_CONFIG_FILE}" --enable "KEXEC_CORE"
./scripts/config --file "${KERNEL_CONFIG_FILE}" --enable "EFI_RUNTIME_MAP"

./scripts/config --file "${KERNEL_CONFIG_FILE}" --disable "KEXEC_JUMP"
./scripts/config --file "${KERNEL_CONFIG_FILE}" --disable "BLK_DEV_LOOP"
