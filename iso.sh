#!/bin/bash
DISK_NAME="Ubuntu Jammy Autoinstall"
DESTINATION_ISO="ubuntu-jammy-autoinstall.iso"
SOURCE_ISO="iso.iso"

append_partition=$(xorriso -indev "${SOURCE_ISO}" -report_el_torito as_mkisofs 2>/dev/null | grep append_partition | awk '{print $3}')
iso_mbr_part_type=$(xorriso -indev "${SOURCE_ISO}" -report_el_torito as_mkisofs 2>/dev/null | grep iso_mbr_part_type | awk '{print $2}')


xorriso \
-as mkisofs \
-r \
-V "${DISK_NAME}" \
-o "${DESTINATION_ISO}" \
--grub2-mbr ../BOOT/1-Boot-NoEmul.img \
-partition_offset 16 \
--mbr-force-bootable \
-append_partition 2 "${append_partition}" ../BOOT/2-Boot-NoEmul.img \
-appended_part_as_gpt \
-iso_mbr_part_type "${iso_mbr_part_type}" \
-c '/boot.catalog' \
-J -joliet-long \
-b '/boot/grub/i386-pc/eltorito.img' \
-no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
-eltorito-alt-boot \
-e '--interval:appended_partition_2:::' \
-no-emul-boot \
.