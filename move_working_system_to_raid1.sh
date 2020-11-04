#!/bin/bash

echo "Install packages..."
yum install -y vim wget mdadm gdisk net-tools pciutils 

echo "#########################################"
lsblk
echo "#########################################"

echo "Create GPT part..."
sleep 10
echo -e "o \ny \nn \n1 \n \n+4M \nef02\nn \n2 \n \n+500M \nef00 \nn\n3 \n \n \nfd00 \nw\ny\n" | gdisk /dev/sdb
echo -e "o \ny \nn \n1 \n \n+4M \nef02\nn \n2 \n \n+500M \nef00 \nn\n3 \n \n \nfd00 \nw\ny\n" | gdisk /dev/sdc
echo -e "o \ny \nn \n1 \n \n+4M \nef02\nn \n2 \n \n+500M \nef00 \nn\n3 \n \n \nfd00 \nw\ny\n" | gdisk /dev/sdd

echo "Create RAID 1..."
sleep 10
mdadm --create /dev/md0 --level 1 -n 4 missing /dev/sd{b,c,d}3 -e 0.90

cat /proc/mdstat
sleep 5

echo "Create EXT4..."
sleep 10
# create filesystem ext4
mkfs.ext4 /dev/md0
mount /dev/md0 /mnt

echo "Add info to fstab..."
sleep 10
cat << EOF > /etc/fstab
/dev/md0 /       ext4      defaults        0 0
EOF

echo "Add info to mdadm.conf..."
sleep 10
mdadm --verbose --detail --scan > /etc/mdadm.conf

sed -i"" -e "s/crashkernel=auto/rd.auto rd.auto=1 selinux=0/g" /etc/default/grub
echo "GRUB_DISABLE_LINUX_UUID=\"true\"" >> /etc/default/grub
echo "GRUB_PRELOAD_MODULES=\"part_gpt raid mdraid mdraid09 mdraid1x \"" >> /etc/default/grub

echo "Update dracut..."
sleep 10
# Update dracut
dracut --mdadmconf --fstab --add="mdraid" --add-drivers="raid1" --force /boot/initramfs-$(uname -r).img $(uname -r) -M

grub2-mkconfig -o /boot/grub2/grub.cfg

grubby --update-kernel=ALL --args="root=/dev/md0"

echo "Install GRUB on disks..."
sleep 10
grub2-install /dev/sdb
grub2-install /dev/sdc
grub2-install /dev/sdd


echo "Create postscript.sh for add sda to raid1..."
sleep 5
chmod +x /etc/rc.d/rc.local
touch /root/postscript.sh
chmod +x /root/postscript.sh

echo "Generate /root/postscript.sh..."
sleep 5
cat << EOF > /root/postscript.sh
#!/bin/bash

sgdisk -R /dev/sda /dev/sdb && sgdisk -G /dev/sda
grub2-mkconfig -o /boot/grub2/grub.cfg
mdadm --add /dev/md0 /dev/sda3

for((f=1;f>0;))do grep -q idle /sys/block/md0/md/sync_action ; f=$?; sleep 1;done && grub2-install /dev/sda

chmod -x /etc/rc.d/rc.local
rm -f /root/postscript.sh 
shutdown -r now
EOF

cat << EOF >>  /etc/rc.d/rc.local

if [ -f "/root/postscript.sh" ]; then
 /bin/bash /root/postscript.sh
fi


EOF

echo "Copy file..."
cp -dpRx / /mnt

# Reboot VM
shutdown -r now


