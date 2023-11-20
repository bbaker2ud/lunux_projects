#!/bin/bash

genisoimage \
-quiet \
-D \
-r \
-V "ubuntu-autoinstall-testing" \
-cache-inodes \
-J -joliet-long \
-b isolinux/isolinux.bin \
-c isolinux/boot.cat \
-no-emul-boot \
-boot-load-size 4 \
-boot-info-table \
-eltorito-alt-boot \
-e boot/grub/efi.img \
-no-emul-boot \
-o  /media/autoinstall-testing.iso \
.