#!/bin/bash
# file location = /usr/local/bin/startup-mount.sh

# 1. Create the mount point if it doesn't exist
mkdir -p /media/ubuntu/share

# 2. Mount the 'share' partition (/dev/sda4) using the standard mount command (instead of using udiskcrtl)
mount /dev/sda4 /media/ubuntu/share -o uid=1000,gid=1000

# 3. Perform the bind mount
mount --bind -o x-gvfs-hide /media/ubuntu/share/Music /home/ubuntu/Music

exit 0

# Make sure that the startup script gets execute permissions
# sudo chmod +x /usr/local/bin/startup-mount.sh
