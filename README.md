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
    #export TOOLCHAIN_ARCH=i686
    ```
1. Select `SITE`
    ```shell
    #export SITE="Cubietruck"
    #export SITE="B2G18EC#ABA"
    #export SITE="C3C58ES#AKD"
    export SITE="D4H65EC#AKD"
    #export SITE="DELLCS24SC"
    #export SITE="DigitalOceanDroplet"
    #export SITE="H5E56ET#ABU"
    ```
2. Pull toolchain image
    ```shell
    # pull latest tag
    docker pull ghcr.io/osfordev/preboot/toolchain/${TOOLCHAIN_ARCH}:latest
    # or latest commit in toolchain branch
    docker pull ghcr.io/osfordev/preboot/toolchain/${TOOLCHAIN_ARCH}/snapshot:latest
    docker tag ghcr.io/osfordev/preboot/toolchain/${TOOLCHAIN_ARCH}/snapshot:latest ghcr.io/osfordev/preboot/toolchain/${TOOLCHAIN_ARCH}:latest
    ```
3. Optionally, use cache to speedup rebuild kernel
    ```shell
    docker volume create "osfordev-preboot-${SITE//#/X}-cache"
    ```
4. Run build
    ```shell
    export TOOLCHAIN_ARCH=amd64
    for AMD64_SITE in "27K51EA#A2Q" "B2G18EC#ABA" "C3C58ES#AKD" "D4H65EC#AKD" "DELLCS24SC" "DigitalOceanDroplet" "H5E56ET#ABU"; do
    for AMD64_SITE in "C3C58ES#AKD" "DELLCS24SC"; do
        docker run \
            --platform linux/amd64 \
            --privileged --rm --interactive --tty \
            --env SITE="${AMD64_SITE}" \
            --env MENUCONFIG=no \
            --volume "osfordev-preboot-${AMD64_SITE//#/X}-cache":/cache \
            --mount type=bind,source="$(pwd)",target=/preboot \
            --volume $(pwd)/.build:/preboot.build \
            ghcr.io/osfordev/preboot/toolchain/${TOOLCHAIN_ARCH}:5.15.151
    done
    ```

    ```shell
    export TOOLCHAIN_ARCH=arm32v7
    for ARM32V7_SITE in "Cubietruck"; do
        docker run \
            --platform linux/amd32/v7 \
            --privileged --rm --interactive --tty \
            --env SITE="${ARM32V7_SITE}" \
            --env MENUCONFIG=no \
            --volume "osfordev-preboot-${ARM32V7_SITE//#/X}-cache":/cache \
            --mount type=bind,source="$(pwd)",target=/preboot \
            --volume $(pwd)/.build:/preboot.build \
            ghcr.io/osfordev/preboot/toolchain/${TOOLCHAIN_ARCH}:5.15.151
    done
    ```

    ```shell
    export TOOLCHAIN_ARCH=i686
    for I686_SITE in "ASRockPV530"; do
        docker run \
            --platform linux/386 \
            --privileged --rm --interactive --tty \
            --env SITE="${I686_SITE}" \
            --env MENUCONFIG=no \
            --volume "osfordev-preboot-${I686_SITE//#/X}-cache":/cache \
            --mount type=bind,source="$(pwd)",target=/preboot \
            --volume $(pwd)/.build:/preboot.build \
            ghcr.io/osfordev/preboot/toolchain/${TOOLCHAIN_ARCH}:5.15.151
    done
    ```

    Note: Container required --privileged flag to manipulate loop devices while creating disk image.
4. Obtain result in `.build` directory

## What the image includes

TBD

## Development

- Run HTTP server
    ```shell
    cd .build/boot && python -m http.server
    ```
- Build ipxe image to load PreBoot image from network (see `httpboot` branch for examples)
    ```ipxe
    #!ipxe


    :start
    dhcp && goto boot
    prompt --key s --timeout 1500 Press "s" for the iPXE command line... && shell
    goto start


    :boot
    dhcp
    kernel http://192.168.0.209:8000/preboot-C3C58ES%23AKD panic=300 || goto boot_error
    boot || goto boot_error


    :boot_error
    sleep 10
    goto start
    ```
- Create EFI USB with iPXE image