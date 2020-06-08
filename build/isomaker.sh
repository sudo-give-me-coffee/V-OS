
#!/bin/sh

bold=$(tput bold)
normal=$(tput sgr0)

echo ${bold}Install Dependencies...
echo ${normal}

sudo apt install debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools

echo  ${bold}Prepare Debian Bootstrap...
echo ${normal}

mkdir -p $HOME/LIVE_BOOT
sudo debootstrap --arch=amd64 --variant=minbase buster $HOME/LIVE_BOOT/chroot http://ftp.us.debian.org/debian/

echo ${bold}Vitruvian Building inside the Chroot Environment...
echo ${normal}

sudo chroot $HOME/LIVE_BOOT/chroot /bin/bash -c "echo "vitruvian-live" > /etc/hostname &\
apt update && apt install -y --no-install-recommends linux-image-amd64 live-boot systemd-sysv network-manager net-tools wireless-tools wpagui curl openssh-client vim libfl-dev cmake ninja-build libfreetype6-dev libinput-dev git autoconf automake texinfo flex bison build-essential unzip zip less zlib1g-dev libtool mtools gcc-multilib libncurses-dev plymouth plymouth-themes fonts-noto-core fonts-noto-extra fonts-noto-mono &&\
apt install -y --reinstall ca-certificates &&\
git clone https://github.com/wesbluemarine/Plymouth-Themes.git &&\
mv Plymouth-Themes/isometric /usr/share/plymouth/themes &&\
rm -rf Plymouth-Themes &&\
plymouth-set-default-theme -R isometric &&\
git clone https://github.com/Barrett17/V-OS.git --branch development &&\
cd /V-OS &&\
mkdir /V-OS/generated.x86 &&\
cd /V-OS/generated.x86 &&\
../configure && ninja -j$((`nproc`+1)) &&\
cd /V-OS/generated.x86/ &&\
cpack &&\
apt -y remove --purge autoconf automake bison build-essential cmake flex gcc-multilib git less libfreetype6-dev libinput-dev libncurses-dev libtool mtools ninja-build texinfo unzip zip zlib1g-dev &&\
apt -y autoremove &&\
apt clean &&\
apt install -y -f /V-OS/generated.x86/*.deb &&\
rm -rf /V-OS/ &&\

cat <<EOT >> /etc/systemd/system/registrar.service
[Unit]
Description=registrar server daemon
Conflicts=getty@tty1.service

[Service]
ExecStart=/system/servers/registrar
StandardInput=tty-force
StandardOutput=inherit
StandardError=inherit
Restart=always
RestartSec=500ms

[Install]
WantedBy=graphical.target
EOT

cat <<EOT >> /etc/systemd/system/app_server.service
[Unit]
Description=app server daemon
Conflicts=getty@tty1.service
After=registrar.service

[Service]
ExecStartPre=/bin/sleep 0.5
ExecStart=/system/servers/app_server
StandardInput=tty-force
StandardOutput=inherit
StandardError=inherit
Restart=always
RestartSec=500ms

[Install]
WantedBy=graphical.target
EOT

cat <<EOT >> /etc/systemd/system/input_server.service
[Unit]
Description=app server daemon
Conflicts=getty@tty1.service
After=app_server.service

[Service]
ExecStartPre=/bin/sleep 0.5
ExecStart=/system/servers/input_server
StandardInput=tty-force
StandardOutput=inherit
StandardError=inherit
Restart=always
RestartSec=500ms

[Install]
WantedBy=graphical.target
EOT

cat <<EOT >> /etc/systemd/system/deskbar.service
[Unit]
Description=deskbar daemon
Conflicts=getty@tty1.service
After=input_server.service

[Service]
ExecStartPre=/bin/sleep 0.5
ExecStart=/system/servers/Deskbar
StandardInput=tty-force
StandardOutput=inherit
StandardError=inherit
Restart=always
RestartSec=500ms

[Install]
WantedBy=graphical.target
EOT

systemctl enable app_server.service deskbar.service input_server.service registrar.service &&\
passwd; exit"

echo ${bold}Create Directories for Live Environment Files...
echo ${normal}

mkdir -p $HOME/LIVE_BOOT/scratch
mkdir -p $HOME/LIVE_BOOT/image/live

echo ${bold}Chroot Environment Compression...
echo ${normal}

sudo mksquashfs \
    $HOME/LIVE_BOOT/chroot \
    $HOME/LIVE_BOOT/image/live/filesystem.squashfs \
    -e boot

echo ${bold}Copy Kernel and Initramfs from Chroot to Live Directory...
echo ${normal}

cp $HOME/LIVE_BOOT/chroot/boot/vmlinuz-* $HOME/LIVE_BOOT/image/vmlinuz
cp $HOME/LIVE_BOOT/chroot/boot/initrd.img-* $HOME/LIVE_BOOT/image/initrd

echo ${bold}Create Grub Menu...
echo ${normal}

cat <<'EOF' >$HOME/LIVE_BOOT/scratch/grub.cfg
insmod all_video
search --set=root --file /VITRUVIAN_CUSTOM
set default="0"
set timeout=0
set hidden_timeout=0
menuentry "Vitruvian Live" {
    linux /vmlinuz boot=live quiet splash
    initrd /initrd
}
EOF

touch $HOME/LIVE_BOOT/image/VITRUVIAN_CUSTOM

echo ${bold}GRUB cfg...
echo ${normal}

grub-mkstandalone \
    --format=x86_64-efi \
    --output=$HOME/LIVE_BOOT/scratch/bootx64.efi \
    --locales="" \
    --fonts="" \
    "boot/grub/grub.cfg=$HOME/LIVE_BOOT/scratch/grub.cfg"

echo ${bold}FAT16 Efiboot...
echo ${normal}

cd $HOME/LIVE_BOOT/scratch
dd if=/dev/zero of=efiboot.img bs=1M count=10
mkfs.vfat efiboot.img
mmd -i efiboot.img efi efi/boot
mcopy -i efiboot.img ./bootx64.efi ::efi/boot/

echo ${bold}Grub cfg Modules...
echo ${normal}

grub-mkstandalone \
    --format=i386-pc \
    --output=$HOME/LIVE_BOOT/scratch/core.img \
    --install-modules="linux normal iso9660 biosdisk memdisk search tar ls" \
    --modules="linux normal iso9660 biosdisk search" \
    --locales="" \
    --fonts="" \
    "boot/grub/grub.cfg=$HOME/LIVE_BOOT/scratch/grub.cfg"

cat \
    /usr/lib/grub/i386-pc/cdboot.img \
    $HOME/LIVE_BOOT/scratch/core.img \
> $HOME/LIVE_BOOT/scratch/bios.img

echo ${bold}Generate ISO File...
echo ${normal}

xorriso \
    -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "VITRUVIAN_CUSTOM" \
    -eltorito-boot \
        boot/grub/bios.img \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        --eltorito-catalog boot/grub/boot.cat \
    --grub2-boot-info \
    --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
    -eltorito-alt-boot \
        -e EFI/efiboot.img \
        -no-emul-boot \
    -append_partition 2 0xef ${HOME}/LIVE_BOOT/scratch/efiboot.img \
    -output "${HOME}/LIVE_BOOT/vitruvian-custom.iso" \
    -graft-points \
        "${HOME}/LIVE_BOOT/image" \
        /boot/grub/bios.img=$HOME/LIVE_BOOT/scratch/bios.img \
        /EFI/efiboot.img=$HOME/LIVE_BOOT/scratch/efiboot.img

echo ${bold}Finished!
