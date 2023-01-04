# OS For Developers PreBoot

This is toolchain branch of multi project repository based on [orphan](https://git-scm.com/docs/git-checkout#Documentation/git-checkout.txt---orphanltnew-branchgt) branches.

Builder is a script that build preboot artifacts like kernel, initrd, etc. The script executes in toolchain container.

## Quick Start

0. Define vars
    ```shell
    export GENTOO_ARCH=amd64
    #export GENTOO_ARCH=i668
    ```

1. Pull toolchain image
    ```bash
    # pull latest tag
    docker pull ghcr.io/osfordev/preboot/toolchain/${GENTOO_ARCH}:latest
    # or latest commit in toolchain branch
    docker pull ghcr.io/osfordev/preboot/toolchain/${GENTOO_ARCH}:snapshot
    docker tag ghcr.io/osfordev/preboot/toolchain/${GENTOO_ARCH}:snapshot ghcr.io/osfordev/preboot/toolchain/${GENTOO_ARCH}:latest
    ```
2. Optionally, use cache to speedup rebuild kernel
    ```bash
    docker volume create osfordev-preboot-cache
    ```
3. Run build
    ```bash
    docker run --rm --interactive --tty \
        --volume osfordev-preboot-cache:/cache \
        --mount type=bind,source="$(pwd)",target=/preboot \
        --volume $(pwd)/.build:/preboot.build \
        ghcr.io/osfordev/preboot/toolchain/${GENTOO_ARCH}
    ```
4. Obtain build

## What the image includes

TBD
