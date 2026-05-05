#!/bin/bash

# Run this once to get the UUID of the drive you want to use:
# sudo blkid -s UUID -o value /dev/sda4

# Enter the value from the above command:
TARGET_UUID="YOUR_UUID" #Partition #4 (share)
# TARGET_UUID="xxxxxxxxxxxxxxxxxxxxxxxxxxxx" #Partition #5 (secret)

# 1. Create the mount point if it doesn't exist
mkdir -p /media/ubuntu/share

# 2. Mount the partition
# If necessary, use: 
# sudo e2label /dev/sda4 share
# to set the volume label for /dev/sda4 to the label 'share'
# check that the correct drive is being labeled with:
# blkid
# lsblk
# To mount by label (acceptable) use:
#mount /dev/disk/by-label/share /media/ubuntu/share -o uid=1000,gid=1000
# To mount by UUID (preferred) use:
mount /dev/disk/by-uuid/$TARGET_UUID /media/ubuntu/share -o uid=1000,gid=1000

# 3. [Optional] Perform a BIND MOUNT to actually put the Music in the Music folder
# Ensure the directory exists
mkdir -p /home/ubuntu/Music
mount --bind -o x-gvfs-hide /media/ubuntu/share/Music /home/ubuntu/Music

exit 0

# Make sure that the startup script gets execute permissions
# sudo chmod +x /usr/local/bin/startup-mount.sh
