# OS For Developers PreBoot

This is toolchain branch of multi project repository based on [orphan](https://git-scm.com/docs/git-checkout#Documentation/git-checkout.txt---orphanltnew-branchgt) branches.

Toolchain is a Docker image that includes all necessary sources/tools to be able to build preboot artifacts like kernel, initrd, etc.

## Quick Start

0. Define vars
    ```shell
    #export GENTOO_ARCH=arm64
    export GENTOO_ARCH=amd64
    #export GENTOO_ARCH=i668
    ```

1. Build toolchain image (or use image from CI)
    ```bash
    docker build --file docker/${GENTOO_ARCH}/Dockerfile --tag ghcr.io/osfordev/preboot/toolchain/${GENTOO_ARCH}:latest .
    ```

## Bump Kernel Version

Kernel version defined in `KERNEL_VERSION` file.

Name of tag should be suffixed by `-toolchain` relevant to kernel version like a:

| Kernel Version | Tag Name             |
|----------------|----------------------|
| 5.15.80        | 5.15.80-toolchain    |
| 4.9.25-r1      | 4.9.25-r1-toolchain  |
