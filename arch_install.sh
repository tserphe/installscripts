#!/usr/bin/env bash

set -e

# Set Variables
SWAPFILE="/swapfile"
SWAPSIZE="1024"
DEVICE="/dev/sda"
PARTITION="/dev/sda1"
LOCALE="en_US.UTF-8 UTF-8"

# Get hostname variable
read -p 'Hostname: ' HOSTNAME

# Get root password
read -p 'Root password: ' ROOT_PASSWORD

# Check for internet
ping -c 1 -W 5 -w 10 archlinux.org

# Update the system clock
timedatectl set-ntp true

# Format Partition
mkfs.ext4 -L ROOT $PARTITION

# Mount Partition
mount $PARTITION /mnt

# Update mirrorlist
reflector --country "United States" --latest 25 --age 24 --protocol https --completion-percent 100 --sort rate --save /etc/pacman.d/mirrorlist

# Install essential packages
pacstrap /mnt base base-devel linux-lts linux-firmware intel-ucode networkmanager htop neovim

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab
sed -i 's/relatime/noatime,lazytime,commit=60/' /mnt/etc/fstab
echo "$SWAPFILE none swap defaults 0 0" >> /mnt/etc/fstab

# Create swapfile
dd if=/dev/zero of=/mnt$SWAPFILE bs=1M count=$SWAPSIZE status=progress
chmod 600 /mnt$SWAPFILE
mkswap /mnt$SWAPFILE

# Change swappiness
echo "vm.swappiness=1" > /mnt/etc/sysctl.d/99-swappiness.conf

# Enable fstrim
arch-chroot /mnt systemctl enable fstrim.timer

# Set time zone
arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
arch-chroot /mnt hwclock --systohc

# Uncomment locale and gen locale
sed -i "s/#$LOCALE/$LOCALE/" /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf

# Create hostname file
echo $HOSTNAME > /mnt/etc/hostname

# Add matching entries to hosts
echo -e "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t$HOSTNAME.localdomain\t$HOSTNAME" >> /mnt/etc/hosts

# Enable Network Manager
arch-chroot /mnt systemctl enable NetworkManager.service

# Set root password
printf "$ROOT_PASSWORD\n$ROOT_PASSWORD" | arch-chroot /mnt passwd

# Install grub and configure
arch-chroot /mnt pacman -Syu --needed --noconfirm grub
arch-chroot /mnt grub-install --target=i386-pc --recheck $DEVICE
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Download LARBS script
curl https://raw.githubusercontent.com/tserphe/LARBS/master/larbs.sh >> /mnt/root/larbs.sh

# Unmount all partitions
umount -R /mnt

# Install completed. Reboot
echo "Arch Linux installed successfully"'!'" Please type 'reboot'."
