# OS For Developers PreBoot

This is toolchain branch of multi project repository based on [orphan](https://git-scm.com/docs/git-checkout#Documentation/git-checkout.txt---orphanltnew-branchgt) branches.

Toolchain is a Docker image that includes all necessary sources/tools to be able to build preboot artifacts like kernel, initrd, etc.

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

1. Build toolchain image (or use image from CI)
    ```bash
    docker build --file docker/${TOOLCHAIN_ARCH}/Dockerfile --tag ghcr.io/osfordev/preboot/toolchain/${TOOLCHAIN_ARCH}:latest .
    ```

## Tags format

`toolchain-<KERNEL_VERSION>-<TOOLCHAIN_ARCH>-<YYYYMMDD>`

Relevant tag names like a:

| Kernel Version  | Docker Arch     | Tag Name                            |
|-----------------|-----------------|-------------------------------------|
| 5.15.80         | linux/amd64     | toolchain-5.15.80-amd64-YYYYMMDD    |
| 5.15.80         | linux/arm/v7    | toolchain-5.15.80-arm32v7-YYYYMMDD  |
| 5.15.80         | linux/arm64/v8  | toolchain-5.15.80-amd64v8-YYYYMMDD  |
| 5.15.80         | linux/386       | toolchain-5.15.80-i686-YYYYMMDD     |
