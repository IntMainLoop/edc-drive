#!/bin/bash
# ---------------
# LUKS COMMANDS #
#----------------

# VARIABLES:
# ----------
DISK="sdc"
PART_NUMBER="5"
TARGET_PATH="/dev/$DISK$PART_NUMBER"
# 
# TEMPORARY: put your cleartext luks passwords here:
LUKS_KEY_0_PATH="$HOME/keys/luks0" # Delete when finished
LUKS_KEY_1_PATH="$HOME/keys/luks1" # Delete when finished
# 
# Backup GPG key-0
GPG_KEY_0_PATH="$HOME/keys/secret-0.key.gpg"
# GPG_KEY_0_PHRASE="$HOME/keys/gpg-secret-0" # only necessary for automation
# 
# Default GPG key-1
GPG_KEY_1_PATH="$HOME/keys/secret-1.key.gpg"
# GPG_KEY_1_PHRASE="$HOME/keys/gpg-secret-1" # only necessary for automation
# 
# Virtual device name
MAPPER_NAME="vault"
# 
# Location to mount the volume
PARTITION_LABEL="system" 		# The GPT volume label is always visible
LUKS_LABEL="s_data"       		# The LUKS Container label is visible when the LUKS volume is closed
LUKS_FS_LABEL="secrets"  		# The LUKS File-System label is only visible when the LUKS volume is open
MOUNT="/mnt/sd/"
MOUNT_POINT="$MOUNT$LUKS_FS_LABEL"


# LABELING:
#----------
# Label exFAT partitions use:
# sudo fatlabel $TARGET_PATH <label> 	# 'share'
#
# Label ext4 partitions use:
# sudo e2label $TARGET_PATH <label> 	# 'writable', 'system'
# 
# LUKS - Label GPT Partition [ext4] (visible always!)
# sudo sgdisk --change-name=$PART_NUMBER:$PARTITION_LABEL $TARGET_PATH
# 
# LUKS - Label LUKS2 Container (visible when LUKS='closed')
# sudo cryptsetup config $TARGET_PATH --label $LUKS_LABEL
# 
# LUKS - Label LUKS2 File-System Volume (visible when LUKS='open')
# sudo e2label /dev/mapper/$MAPPER_NAME $LUKS_FS_LABEL
# 
# LUKS - Change the mapper device name:
# sudo dmsetup rename $MAPPER_NAME <NEW_NAME>


# BASIC LUKS KEY MANAGEMENT:
# --------------------------
# Check if the LUKS volume is open:
# ls /dev/mapper/$MAPPER_NAME
#
# Dump LUKS status:
# sudo cryptsetup luksDump $TARGET_PATH
#
# Create a NEW (weak) LUKS passphrase for Slot-1:
# sudo cryptsetup luksAddKey --key-slot 1 $TARGET_PATH
# 
# Verify a (weak) LUKS passphrase:
# sudo cryptsetup -v open --test-passphrase $TARGET_PATH
# 
# Remove a LUKS Key (by Slot-#):
# sudo cryptsetup luksKillSlot $TARGET_PATH 0
# 
# Remove a LUKS Key (by Passphrase):
# sudo cryptsetup luksRemoveKey $TARGET_PATH

# [ BEGIN ]

# PREREQUISITES:
# --------------
sudo apt update
sudo apt install cryptsetup gnupg2
sudo apt upgrade

# GPG KEY MANAGEMENT:
# -------------------
# Create new raw keys (never write this raw value to disk, ever!):
dd if=/dev/urandom bs=1 count=64 of=/dev/shm/secret-0.key  # recovery
dd if=/dev/urandom bs=1 count=64 of=/dev/shm/secret-1.key  # default
# 
# Encrypt the raw keys using GPG2:
gpg --symmetric --cipher-algo AES256 --s2k-digest-algo SHA512 /dev/shm/secret-0.key -o ~/secret-0.key.gpg
gpg --symmetric --cipher-algo AES256 --s2k-digest-algo SHA512 /dev/shm/secret-1.key -o ~/secret-1.key.gpg
# 
# Shred the raw keys immediately:
shred -n 10 -u /dev/shm/secret-0.key
shred -n 10 -u /dev/shm/secret-1.key
# 
# Set permissions for the encrypted keys:
sudo chmod 400 ~/secret-0.key.gpg
sudo chmod 400 ~/secret-1.key.gpg


# CONFIGURE LUKS SLOTS:
# ---------------------
# Enable a new LUKS Keyslot Entry, Slot-1:
sudo cryptsetup luksAddKey --key-slot 1 $TARGET_PATH

# Replace the LUKS Keyslot-1 passphrase w/ the GPG2 Key-1 using Keyslot-1's temp password file: 
# ---------------------------------------------------------------------------------------------
## Automated:
## sudo gpg --batch --passphrase-file $GPG_KEY_1_PHRASE -qd $GPG_KEY_1_PATH | sudo cryptsetup luksChangeKey $TARGET_PATH -S 1 --key-file $LUKS_KEY_S1_PATH -
##
## CLI:
## sudo gpg --pinentry-mode loopback -qd $GPG_KEY_1_PATH | sudo cryptsetup luksChangeKey $TARGET_PATH -S 1 --key-file $LUKS_KEY_S1_PATH -
##
## GUI:
gpg -qd $GPG_KEY_1_PATH | sudo cryptsetup luksChangeKey $TARGET_PATH -S 1 --key-file $LUKS_KEY_S1_PATH -


# Verify the updated LUKS Slot-1 passphrase using the decrypted GPG key-1:
# ------------------------------------------------------------------------
## Automated:
## sudo gpg --batch --passphrase-file $GPG_KEY_1_PHRASE -qd $GPG_KEY_1_PATH | sudo cryptsetup -v open --test-passphrase $TARGET_PATH --key-file=-
##
## CLI:
## sudo gpg --pinentry-mode loopback -qd $GPG_KEY_1_PATH | sudo cryptsetup -v open --test-passphrase $TARGET_PATH --key-file=-
##
## GUI:
gpg -qd $GPG_KEY_1_PATH | sudo cryptsetup -v open --test-passphrase $TARGET_PATH --key-file=-

# CONTINUE ONLY IF THE TEST WAS SUCCESSFUL

# Replace the LUKS Keyslot-0 passhprase w/ the GPG2 Key-0 using Keyslot-0's temp password file: 
# ---------------------------------------------------------------------------------------------
## Automated:
## sudo gpg --batch --passphrase-file $GPG_KEY_0_PHRASE -qd $GPG_KEY_0_PATH | sudo cryptsetup luksChangeKey $TARGET_PATH -S 0 --key-file $LUKS_KEY_S0_PATH -
##
## CLI:
## sudo gpg --pinentry-mode loopback -qd $GPG_KEY_0_PATH | sudo cryptsetup luksChangeKey $TARGET_PATH -S 0 --key-file $LUKS_KEY_S0_PATH -
##
## GUI:
gpg -qd $GPG_KEY_0_PATH | sudo cryptsetup luksChangeKey $TARGET_PATH -S 0 --key-file $LUKS_KEY_S0_PATH -

# Verify the updated LUKS Slot-0 passphrase using the decrypted GPG key-0:
# ------------------------------------------------------------------------
## Automated:
## sudo gpg --batch --passphrase-file $GPG_KEY_0_PHRASE -qd $GPG_KEY_0_PATH | sudo cryptsetup -v open --test-passphrase $TARGET_PATH --key-file=-
##
## CLI:
## sudo gpg --pinentry-mode loopback -qd $GPG_KEY_0_PATH | sudo cryptsetup -v open --test-passphrase $TARGET_PATH --key-file=-
##
## GUI:
gpg -qd $GPG_KEY_0_PATH | sudo cryptsetup -v open --test-passphrase $TARGET_PATH --key-file=-

# Open the LUKS volume using the new (strong) Slot-0 key:
# -------------------------------------------------------
## Automated:
## sudo gpg --passphrase-file $GPG_KEY_0_PHRASE --batch --use-agent --decrypt $GPG_KEY_0_PATH | sudo cryptsetup open $TARGET_PATH $MAPPER_NAME --key-file=-
##
## CLI:
## sudo gpg --decrypt --pinentry-mode loopback $GPG_KEY_0_PATH | sudo cryptsetup open $TARGET_PATH $MAPPER_NAME --key-file=-
##
## GUI:
gpg --decrypt $GPG_KEY_0_PATH | sudo cryptsetup open $TARGET_PATH $MAPPER_NAME -

# Verify that the LUKS volume is now open:
ls /dev/mapper/$MAPPER_NAME

# Format the newly created LUKS virtual volume:
sudo mkfs.ext4 -L $LUKS_FS_LABEL /dev/mapper/$MAPPER_NAME


# MOUNT THE LUKS VOLUME:
# ----------------------
# Create the mount point:
sudo mkdir -p $MOUNT_POINT
# 
# Mount the LUKS volume:
sudo mount /dev/mapper/$MAPPER_NAME $MOUNT_POINT
# 
# Wipe passphrases from GPG-agent memory:
gpg-connect-agent reloadagent /bye
# 
# Set permissions of the mount to use it:
sudo chown $USER:$USER $MOUNT_POINT


# -------------------------------------------------------------
# IMPORTANT: Always unmount before closing the LUKS volume!!! #
# -------------------------------------------------------------

# UNMOUNT THE LUKS VOLUME:
# ------------------------
# Unmount:
sudo umount $MOUNT_POINT
# 
# Close the LUKS volume:
sudo cryptsetup close $MAPPER_NAME
#
# Verify that the volume was actually closed before continuing:
ls /dev/mapper/$MAPPER_NAME
#
# Remove the mount location:
rmdir $MOUNT_POINT
#
# Wipe passphrases from GPG-agent memory [optional]
gpg-connect-agent reloadagent /bye

echo "ATTENTION !!! :"
echo "MOVE $GPG_KEY_0_PATH [Backup Key] to a physically secured location."
echo "Write the passphrase on paper and keep it with the key file."
echo "This is the ONLY way to recover data from the drive."

# Now open the same LUKS volume using the new [default] (strong) Slot-1 key:
# --------------------------------------------------------------------------
## Automated:
## sudo gpg --passphrase-file $GPG_KEY_1_PHRASE --batch --use-agent --decrypt $GPG_KEY_1_PATH | sudo cryptsetup open $TARGET_PATH $MAPPER_NAME --key-file=-
##
## CLI:
## sudo gpg --pinentry-mode loopback --decrypt $GPG_KEY_1_PATH | sudo cryptsetup open $TARGET_PATH $MAPPER_NAME --key-file=-
##
## GUI:
gpg --decrypt $GPG_KEY_1_PATH | sudo cryptsetup open $TARGET_PATH $MAPPER_NAME --key-file=-

# Verify that the LUKS volume is now open
ls /dev/mapper/$MAPPER_NAME


# MOUNT THE VOLUME:
# -----------------
# Create the mount point:
sudo mkdir -p $MOUNT_POINT
# 
# Mount the LUKS volume:
sudo mount /dev/mapper/$MAPPER_NAME $MOUNT_POINT
# 
# Wipe passphrases from GPG-agent memory [optional]
gpg-connect-agent reloadagent /bye
# 
# Set permissions of the mount to use it:
sudo chown $USER:$USER $MOUNT_POINT


# -------------------------------------------------------------
# IMPORTANT: Always unmount before closing the LUKS volume!!! #
# -------------------------------------------------------------


# UNMOUNT THE LUKS VOLUME:
# ------------------------
# Unmount the LUKS volume:
sudo umount $MOUNT_POINT
# 
# Close the LUKS volume:
sudo cryptsetup close $MAPPER_NAME
#
# Verify that the volume was actually closed before continuing:
ls /dev/mapper/$MAPPER_NAME
#
# Remove the mount location:
rmdir $MOUNT_POINT
#
# Wipe passphrases from GPG-agent memory [optional]
gpg-connect-agent reloadagent /bye


# HEADER BACKUP:
# --------------
# If the LUKS header is corrupted, data is permanently lost. Back it up RIGHT NOW to a safe, THIRD location:
sudo cryptsetup luksHeaderBackup $TARGET_PATH --header-backup-file ~/secret_header.bak


# REMOVE SAFELY:
# --------------
# With all partitions unmounted, eject/power-off the target device
udisksctl power-off -b /dev/$DISK
