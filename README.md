# OS For Developers PreBoot

**PreBoot** is a generic Gentoo Linux kernel (+initramfs) that acts as an early stage of a booting process.

- detect number of installed **OS For Developers** versions
- select **OS For Developers** boot version
- unify the boot process of **OS For Developers** across BIOS, EFI, U-Boot, etc.

```text
 ┌─────────┐    ┌──────────┐                                            
 │ BIOS    ├───►│          │            ┌───────────────────────────────┐ 
 └─────────┘    │          │            │      OS For Developers        │ 
                │          │            │           Image               │ 
 ┌─────────┐    │          │            │                               │ 
 │ EFI     ├───►│ PreBoot  ├── kexec ──►│   /boot (/dev/vgxx/system-xx) │ 
 └─────────┘    │          │            │   ├─ OSFORDEV_CMDLINE         │ 
                │          │            │   ├─ vmlinuz                  │ 
 ┌─────────┐    │          │            │   └─ initramfs.cpio.gz        │ 
 │ U-Boot  ├───►│          │            └───────────────────────────────┘ 
 └─────────┘    └──────────┘                                            

Created in https://asciiflow.com/
```

**PreBoot** is distributed as a disk image ready to burn on HDD/SSD, SD-card, USB-flash, etc.

## Get Started

1. Obtain an image (according to your platform)
1. Create GPT disk layout (use `LegacyBIOSBootable` attribute for BIOS/MBR hardware)
    - without soft RAID
        ```text
        sda
        └─sda1
        ```
    - with soft RAID1
        ```text
        sda
        └─sda1
            └─md0
        sdb
        └─sdb1
            └─md0
        ...
        ```
1. Install MBR boot code (required for BIOS/MBR hardware only)
    ```shell
    wget -qO- https://github.com/osfordev/preboot/raw/binary/syslinux/gptmbr-6.04.bin | dd of=/dev/sda bs=440 count=1 conv=notrunc
    ```
1. Install software (include Syslinux) to EFI partition `/dev/md0`
    ```shell
    wget -qO- https://github.com/osfordev/preboot/raw/binary/syslinux/boot-partition-6.04.img.gz | gzip -d | dd of=/dev/md0
    ```
1. Mount EFI partition
    ```shell
    mount /dev/md0 /mnt
    ```
1. Follow instruction from `README.txt` to download Preboot Image
    ```shell
    cat /mnt/README.txt
    ```
1. Optionally create `osfordev-vgs-assembler.sh`
    For non-standard layout you may provide a helper script. The script should return list of Volume Groups, where first Volume Group contains `system-*` logical volumes.
    In following example we run two soft RAID and activate two Volume Groups.
    ```shell
    cat <<EOF > /mnt/osfordev-vgs-assembler.sh
    #!/bin/sh
    #

    source /init-base.functions
    source /init-platform.functions

    if [ "${1}" == "down" ]; then
        info "De-activating volume groups ..." >&2
        /sbin/vgchange --activate n >&2 || fatal "/sbin/vgchange: Failure de-activate volume groups"

        info "De-activating RAID /dev/md1 ..." >&2
        /sbin/mdadm --stop /dev/md1 >&2

        info "De-activating RAID /dev/md0 ..." >&2
        /sbin/mdadm --stop /dev/md0 >&2
    elif [ "${1}" == "up" ]; then
        info "Assemble RAID1 (boot)" >&2
        /sbin/mdadm --assemble --run /dev/md0 /dev/sda1 /dev/sdb1 /dev/sdc1 /dev/sdd1 >&2

        info "Assemble RAID5 (HDDs)" >&2
        /sbin/mdadm --assemble --run /dev/md1           /dev/sdb2 /dev/sdc2 /dev/sdd2 >&2

        info "Scanning for volume groups ..." >&2
        /sbin/vgscan >&2 || fatal "/sbin/vgscan: Failure scan volume groups"

        info "Activating volume group: 'vgroot' ..." >&2
        /sbin/vgchange --activate y >&2 || fatal "/sbin/vgchange: Failure activate volume groups"

        # tell Preboot about VGs. First VG should contain "system-XXXX" 
        echo "vgssd"
        echo "vghddraid5"
    fi
    EOF
    chmod +x /mnt/osfordev-vgs-assembler.sh
    ```
1. Optionally create `OSFORDEV_CMDLINE`
    For non-standard layout you may provide a custom kernel cmdline.
    In following example we relay to previous create `osfordev-vgs-assembler.sh`
    ```shell
    cat <<EOF > /mnt/OSFORDEV_CMDLINE
    osfordev_pwd=xxxxxxxx
    osfordev_ip=eth0,192.168.0.xxx/24,192.168.0.xxx
    osfordev_ssh
    osfordev_md=md0,sda1,sdb1,sdc1,sdd1;md1,sdb2,sdc2,sdd2
    osfordev_vg=vgssd;vghddraid5
    osfordev_uncrypt=vgssd/luks-docker,uncrypted-docker,discard;vgssd/luks-home,uncrypted-home,discard;vgssd/luks-log,uncrypted-log,discard;vgssd/luks-registry,uncrypted-registry,discard;vgssd/luks-swap,uncrypted-swap,discard
    osfordev_root=vgssd/system,ext4,ro,discard
    EOF
    ```


## Development

### Repository Structure

This is workspace branch of multi project repository based on [orphan](https://git-scm.com/docs/git-checkout#Documentation/git-checkout.txt---orphanltnew-branchgt) branches.

Branches (sub-projects):

* `binary` - Binaries history of preboot
* `builder` - Builder is a script that build preboot artifacts like kernel, initrd, etc.
* `httpboot` - HTTP boot allows to load preboot from network. Include sources to build ipxe.efi, undionly.kpxe, etc.
* `toolchain` - Toolchain is a Docker image that includes all necessary sources/tools to be able to build preboot artifacts like kernel, initrd, etc.

### Initialize Workspace

1. Clone the repository
    ```shell
    git clone git@github.com:osfordev/preboot.git osfordev.preboot
    ```
1. Enter into cloned directory
    ```shell
    cd osfordev.preboot
    ```
1. Initialize [worktree](https://git-scm.com/docs/git-worktree) by execute following commands:
    ```shell
    for BRANCH in binary builder httpboot toolchain; do git worktree add "${BRANCH}" "${BRANCH}"; done
    ```
1. Open VSCode Workspace
    ```shell
    code "OS For Developers PreBoot.code-workspace"
    ```

### Notes

Add new orphan branch

```shell
NEW_BRANCH=...
git worktree add --detach "./${NEW_BRANCH}"
cd "./${NEW_BRANCH}"
git checkout --orphan "${NEW_BRANCH}"
git reset --hard
git commit --allow-empty -m "Initial Commit"
git push origin "${NEW_BRANCH}":"${NEW_BRANCH}"
```
