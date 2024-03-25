# OS For Developers PreBoot

This is toolchain branch of multi project repository based on [orphan](https://git-scm.com/docs/git-checkout#Documentation/git-checkout.txt---orphanltnew-branchgt) branches.

Builder is a script that build preboot artifacts like kernel, initrd, etc. The script executes in toolchain container.

## Quick Start

0. Define vars

    ```shell
    #export TOOLCHAIN_ARCH=arm32v5
    #export TOOLCHAIN_ARCH=arm32v6
    #export TOOLCHAIN_ARCH=arm32v7
    #export TOOLCHAIN_ARCH=arm64v8
    export TOOLCHAIN_ARCH=amd64
    #export TOOLCHAIN_ARCH=i668
    ```

1. Pull toolchain image
    ```bash
    # pull latest tag
    docker pull ghcr.io/osfordev/preboot/toolchain/${TOOLCHAIN_ARCH}:latest
    # or latest commit in toolchain branch
    docker pull ghcr.io/osfordev/preboot/toolchain/${TOOLCHAIN_ARCH}/snapshot:latest
    docker tag ghcr.io/osfordev/preboot/toolchain/${TOOLCHAIN_ARCH}/snapshot:latest ghcr.io/osfordev/preboot/toolchain/${TOOLCHAIN_ARCH}:latest
    ```
2. Optionally, use cache to speedup rebuild kernel
    ```bash
    docker volume create osfordev-preboot-cache
    ```
3. Run build
    * NOTE 1: Container required --privileged flag to manipulate loop devices while creating disk image.
    * NOTE 2: For UBoot loader you have to add `--env UBOOT_TARGET_BOARD=Cubietruck`
    ```bash
    docker run \
        --privileged --rm --interactive --tty \
        --env UBOOT_TARGET_BOARD=Cubietruck \
        --volume osfordev-preboot-cache:/cache \
        --mount type=bind,source="$(pwd)",target=/preboot \
        --volume $(pwd)/.build:/preboot.build \
        ghcr.io/osfordev/preboot/toolchain/${TOOLCHAIN_ARCH}:latest
    ```
    Note: Container required --privileged flag to manipulate loop devices while creating disk image.
4. Obtain build

## What the image includes

TBD
