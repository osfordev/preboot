# OS For Developers PreBoot

This is toolchain branch of multi project repository based on [orphan](https://git-scm.com/docs/git-checkout#Documentation/git-checkout.txt---orphanltnew-branchgt) branches.

Toolchain is a Docker image that includes all necessary sources/tools to be able to build preboot artifacts like kernel, initrd, etc.

## Quick Start

1. Define vars

    ```shell
    #export TOOLCHAIN_ARCH=arm32v5
    #export TOOLCHAIN_ARCH=arm32v6
    #export TOOLCHAIN_ARCH=arm32v7
    #export TOOLCHAIN_ARCH=arm64v8
    export TOOLCHAIN_ARCH=amd64
    #export TOOLCHAIN_ARCH=i668
    ```

1. Obtain an image

    - Build toolchain image
        ```shell
        docker build --file docker/${TOOLCHAIN_ARCH}/Dockerfile --tag ghcr.io/osfordev/preboot/toolchain/${TOOLCHAIN_ARCH}:latest .
        ```

    - Pull toolchain image

        ```shell
        docker pull ghcr.io/osfordev/preboot/toolchain/${TOOLCHAIN_ARCH}
        docker pull ghcr.io/osfordev/preboot/toolchain/${TOOLCHAIN_ARCH}/snapshot
        ```

1. Run toolchain container

    ```shell
    docker run --rm -it --entrypoint /bin/bash ghcr.io/osfordev/preboot/toolchain/${TOOLCHAIN_ARCH}
    docker run --rm -it --entrypoint /bin/bash ghcr.io/osfordev/preboot/toolchain/${TOOLCHAIN_ARCH}/snapshot
    ```

## Tags format

`toolchain-<KERNEL_VERSION>-<TOOLCHAIN_ARCH>-<YYYYMMDD>`

Relevant tag names like a:

| Kernel Version  | Docker Arch     | Git Tag Name                        | Docker Image                                        |
|-----------------|-----------------|-------------------------------------|-----------------------------------------------------|
| 5.15.80         | linux/amd64     | toolchain-5.15.80-amd64-YYYYMMDD    | ghcr.io/osfordev/preboot/toolchain/amd64:5.15.80    |
| 5.15.80         | linux/arm/v7    | toolchain-5.15.80-arm32v7-YYYYMMDD  | ghcr.io/osfordev/preboot/toolchain/arm32v7:5.15.80  |
| 5.15.80         | linux/arm64/v8  | toolchain-5.15.80-amd64v8-YYYYMMDD  | ghcr.io/osfordev/preboot/toolchain/amd64v8:5.15.80  |
| 5.15.80         | linux/386       | toolchain-5.15.80-i686-YYYYMMDD     | ghcr.io/osfordev/preboot/toolchain/i686:5.15.80     |
