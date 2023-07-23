#!/bin/bash 

echo "Please enter your desired root password:"
read root_pass

echo "Please enter your desired username:"
read username
echo "And now your password for this user:"
read password

echo "Please enter the device name that will be used for partitioning:"
read device

efi_partition="$device"1
swap_partition="$device"2
root_partition="$device"3

fdisk $device

echo "Formatting partitions"
mkfs.ext4 $root_partition
mkswap $swap_partition
mkfs.fat -F 32 $efi_partition

echo "Mounting partitions"
mount $root_partition /mnt
mount --mkdir $efi_partition /mnt/boot
swapon $swap_partition

echo "Updating mirror list"
reflector --latest 200 --protocol http,https --sort rate --save /etc/pacman.d/mirrorlist

pacstrap -K /mnt base base-devel linux linux-firmware e2fsprogs networkmanager vim man-db man-pages texinfo


genfstab -U /mnt >> /mnt/etc/fstab

echo "Chrooting into new environment"
# Figure out how to edit specific line in a file using bash
arch-chroot /mnt /bin/bash << EOT
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
hwclock --systohc
--------------------------------- Finish this part here ---------------------------------
locale-gen

touch /etc/locale.conf
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

touch /etc/hostname
echo 'arch' > /etc/hostname
--------------------------------- Once the locale-gen stuff is figured out do hosts too ---------------------------------

mkinitcpio -P

passwd $root_pass

pacman -S grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
exit
EOT

umount -R /mnt

echo "Install completed successfully"
