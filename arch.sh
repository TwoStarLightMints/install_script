#!/bin/bash 

echo "Please enter your desired root password:"
read -s root_pass

echo "Please enter your desired username:"
read username
echo "And now your password for this user:"
read -s password

echo "Please enter the device name that will be used for partitioning:"
read device

efi_partition="$device"1
swap_partition="$device"2
root_partition="$device"3

echo -e "label:gpt\n,350M,U\n,2G,S\n,+,L" | sfdisk $device

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

pacstrap -K /mnt base base-devel linux linux-firmware e2fsprogs networkmanager man-db man-pages texinfo


genfstab -U /mnt >> /mnt/etc/fstab

echo "Chrooting into new environment"
# Figure out how to edit specific line in a file using bash
arch-chroot /mnt /bin/bash << EOT
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
hwclock --systohc
sed -i 's/\#en_US/en_US/' /etc/locale.gen
locale-gen

touch /etc/locale.conf
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

touch /etc/hostname
echo 'arch' > /etc/hostname
echo '127.0.0.1  localhost' > /etc/hosts

mkinitcpio -P

useradd -m -G wheel $username

echo root:$root_pass | chpasswd
echo $username:$password | chpasswd

pacman -Syu --noconfirm

pacman -S grub efibootmgr --noconfirm
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

pacman -S qtile ly helix git alsa-utils libreoffice-still alacritty fish chromium ttf-hack-nerd starship zellij npm gimp rustup rofi code xorg virtualbox-guest-utils openssh --noconfirm

systemctl enable NetworkManager.service
systemctl enable ly.service
systemctl enable vboxservice.service

su $username << EOF
cd ~
echo "alias config='/usr/bin/git --git-dir=/home/$username/.cfg/ --work-tree=/home/$username'" >> /home/$username/.bashrc
echo ".cfg" >> .gitignore
git clone --bare git@github.com:TwoStarLightMints/dotfiles.git /home/$username/.cfg
rm -rf /home/$username/.config/*
/usr/bin/git --git-dir=/home/$username/.cfg/ --work-tree=/home/$username checkout
/usr/bin/git --git-dir=/home/$username/.cfg/ --work-tree=/home/$username config --local status.showUntrackedFiles no
EOF

exit
EOT

umount -R /mnt

echo "Install completed successfully"
