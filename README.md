# OS For Developers PreBoot

**PreBoot** is a generic Gentoo Linux kernel (+initramfs) that acts as an early stage of a booting process.
It unifies the boot process of **OS For Developers** across BIOS, EFI, U-Boot, etc.

```
+---------+       +----------+
| BIOS    +-----> |          |             +--------------------+
+---------+       |          |             |                    |
                  |          |             |      Kernel        |
+---------+       |          |             |                    |
| EFI     +-----> | PreBoot  +-- kexec --> | OS For Developers  |
+---------+       |          |             |                    |
                  |          |             |     Initramfs      |
+---------+       |          |             |                    |
| U-Boot  +-----> |          |             +--------------------+
+---------+       +----------+
```

**PreBoot** is distributed as a disk image ready to burn on HDD/SSD, SD-card, USB-flash, etc.

## Get Started

1. Obtain an image  (according to your platform)

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
NEW_ORPHAN_BRANCH=mybranch
git switch --orphan  "${NEW_ORPHAN_BRANCH}"
git commit --allow-empty -m "Initial Commit"
git push origin "${NEW_ORPHAN_BRANCH}"
```
