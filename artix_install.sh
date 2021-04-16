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
ping -c 1 -W 5 -w 10 artixlinux.org

# Format Partition
mkfs.ext4 -L ROOT $PARTITION

# Mount Partition
mount $PARTITION /mnt

# Install essential packages
basestrap /mnt base base-devel runit elogind-runit linux-lts linux-firmware intel-ucode networkmanager networkmanager-runit cronie cronie-runit htop neovim

# Generate fstab
fstabgen -U /mnt >> /mnt/etc/fstab
sed -i 's/relatime/noatime,lazytime,commit=60/' /mnt/etc/fstab
echo "$SWAPFILE none swap defaults 0 0" >> /mnt/etc/fstab
echo "" >> /mnt/etc/fstab
echo "tmpfs /tmp tmpfs rw,nodev,nosuid,size=1G 0 0" >> /mnt/etc/fstab

# Create swapfile
dd if=/dev/zero of=/mnt$SWAPFILE bs=1M count=$SWAPSIZE status=progress
chmod 600 /mnt$SWAPFILE
mkswap /mnt$SWAPFILE

# Change swappiness
mkdir /mnt/etc/sysctl.d
echo "vm.swappiness=1" > /mnt/etc/sysctl.d/99-swappiness.conf

# Set time zone
artools-chroot /mnt ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
artools-chroot /mnt hwclock --systohc

# Uncomment locale and gen locale
sed -i "s/#$LOCALE/$LOCALE/" /mnt/etc/locale.gen
artools-chroot /mnt locale-gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf

# Create hostname file
echo $HOSTNAME > /mnt/etc/hostname

# Add matching entries to hosts
echo -e "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t$HOSTNAME.localdomain\t$HOSTNAME" >> /mnt/etc/hosts

# Enable Services
artools-chroot /mnt ln -s /etc/runit/sv/NetworkManager /etc/runit/runsvdir/default
artools-chroot /mnt ln -s /etc/runit/sv/cronie /etc/runit/runsvdir/default

# Set root password
printf "$ROOT_PASSWORD\n$ROOT_PASSWORD" | artools-chroot /mnt passwd

# Install grub and configure
artools-chroot /mnt pacman -Syu --needed --noconfirm grub
artools-chroot /mnt grub-install --target=i386-pc --recheck $DEVICE
artools-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Download LARBS script
curl https://raw.githubusercontent.com/tserphe/LARBS/master/larbs.sh >> /mnt/root/larbs.sh

# Unmount all partitions
umount -R /mnt

# Install completed. Prompt for reboot
echo "Artix Linux installed successfully"'!'" Please type 'reboot'."
