# OS For Developers PreBoot

This is `httpboot` branch of multi project repository based on [orphan](https://git-scm.com/docs/git-checkout#Documentation/git-checkout.txt---orphanltnew-branchgt) branches.

HTTP boot allows to load preboot from network. Include sources to build ipxe.efi, undionly.kpxe, etc.

## Draft

### EFI image

Build

```shell
cd submodules/ipxe/src/

make -j$(nproc) bin-x86_64-efi/ipxe.efi EMBED=../../../preboot.ipxe
make -j$(nproc) bin-i386-efi/ipxe.efi   EMBED=../../../preboot.ipxe

cd ../../..

mkdir --parents .dist/EFI/BOOT/
cp submodules/ipxe/src/bin-i386-efi/ipxe.efi   .dist/EFI/BOOT/BOOTIA32.EFI
cp submodules/ipxe/src/bin-x86_64-efi/ipxe.efi .dist/EFI/BOOT/BOOTX64.EFI
```

Make boot-able USB flash

```shell
USB_FLASH_DEVICE=/dev/sdb

TDB
```


## References

- [EFI system partition](https://en.wikipedia.org/wiki/EFI_system_partition)