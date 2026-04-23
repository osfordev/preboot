1. Create GPT disk layout (with enabled `LegacyBIOSBootable` attribute)

  ```shell
  TBD
  ```

1. Install MBR boot code

  ```shell
  wget -qO- https://github.com/osfordev/preboot/raw/binary/amd64/syslinux/gptmbr-6.04.bin | dd of=/dev/sda bs=440 count=1 conv=notrunc
  ```

1. Install software (include Syslinux) to EFI partition `/dev/sda1`

  ```shell
  wget -qO- https://github.com/osfordev/preboot/raw/binary/amd64/syslinux/boot-partition-6.04.img.gz | gzip -d | dd of=/dev/sda1
  ```

1. Mount EFI partition

  ```shell
  mount /dev/sda1 /mnt
  ```

1. Follow instruction from `cat /mnt/README.txt`
