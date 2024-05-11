#!/bin/bash

[ "$UID" -eq 0 ] || exec sudo "$0" "$@"

echo
lsblk | grep sd
echo

read -p "Specify the Install Medium (sdX): " -r drive

printf "WARNING !!! This will ERASE EVERYTHING on the selected drive !\n"

read -p "Do you want to continue ? (y/n): " -r userConfirmation

declare -A osInfo;
osInfo[/etc/redhat-release]=yum
osInfo[/etc/arch-release]=pacman
osInfo[/etc/gentoo-release]=emerge
osInfo[/etc/SuSE-release]=zypp
osInfo[/etc/debian_version]=apt
osInfo[/etc/alpine-release]=apk

for f in "${!osInfo[@]}"
do
    if [[ -f $f ]];then
        pkgmgr=${osInfo[$f]}
    fi
done

if [[ "$pkgmgr" = 'apt' ]]; then
    printf "Updating Repositories..." && sudo apt -qq update
    printf "Installing Grub & Udisk2..." && sudo apt -qq install -y grub-efi-amd64 udisks2
    
elif [[ "$pkgmgr" = 'pacman' ]]; then
    printf "Updating Repositories..." && sudo pacman -Sy
    printf "Installing Grub & Udisks2..." && sudo pacman -q -S --noconfirm grub udisks2
    
else
    printf 'Your Distribution uses %s package manager which is currently not supported !\n\n' "$pkgmgr"
    exit 0
fi

if [[ "$userConfirmation" =~ ^[Yy](es)?$ ]]; then

    sudo umount /dev/"$drive"?* && echo
    sudo wipefs -a -f "/dev/$drive" && echo

    sudo sgdisk --clear "/dev/$drive" \
    --new=1:0:+512M --typecode=1:ef00 --change-name=1:'EFI' \
    --new=2:0:0 --typecode=2:8300 --change-name=2:'Multiboot'

    sudo mkfs.fat -F32 -n EFI /dev/"$drive"1
    sudo mkfs.ext4 -F -L Multiboot /dev/"$drive"2
    sudo mkdir -p /mnt
    sudo mount /dev/"$drive"1 /mnt
    sudo mkdir -p /mnt/boot
    sudo grub-install --force --removable --target=x86_64-efi --boot-directory=/mnt/boot --efi-directory=/mnt "/dev/$drive"
    
    UUID=$(sudo blkid | grep "/dev/$drive"2 | awk -F '"' '{print $4}')
    sed -i "s/<UUID>/$UUID/g" grub.cfg
    < grub.cfg sudo tee /mnt/boot/grub/grub.cfg >/dev/null
    
    printf "Now read the multiboot wiki to bootstrap your ISOs:\nhttps://github.com/itnerd7/multiboot\n\n"
elif [[ "$userConfirmation" =~ ^[Nn](o)?$ ]]; then

    printf "Aborting...\n"
    exit 0

else

    printf "Invalid choice ! Please choose between (Y)es and (N)o. Aborting...\n\n"
    exit 0

fi
