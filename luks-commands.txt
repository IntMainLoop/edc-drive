#!/bin/bash
# *** REVIEW BEFORE EXECUTING (it should be all good, ...but it's untested!) ***
#
# ==============================================================================
# VENTOY LUKS VAULT SETUP WIZARD [AES512 Serpent + Argon2id (Version 2.1)
# ==============================================================================
#
# SYNOPSIS:
# This plan creates a persistent, bootable [Ubuntu] usb-disk on a keychain with
# a PRIVATE partition that ONLY auto-mounts a PUBLIC partition when enumerated
# on a typical MSFT, AAPL, or Linux machine. By specifying unusual but
# compatible GUIDs (LVM, BootEFI, or Windows Recovery) which are usually
# ignored by the OS, these partitions do not auto-mount. A standard exFAT
# 'msftdata' PUBLIC partition serves both a functional role and obfuscates the
# full capability of the drive from the casual observer. It employs
# Multi-Factor Encryption by using GPG-encrypted symmetric keyfiles to unlock a
# Serpent+Argon2id LUKS partition, providing reasonably secure data storage for
# a persistent live-session located on a single usb-drive carried on a physical
# key-ring.
#
# Ideally, a usb-disk on a key-chain carries [asymmetric] PUBLIC keys and uses
# a passphrase with the GPG [asymmetric] PRIVATE key to unlock the LUKS
# partition's symmetric keyfile. This requires access to the laptop, access to
# the usb-drive, and the GPG passphrase. If the laptop is stolen, the data is
# protected; if the keys are stolen, the data is protected. If both the laptop
# and the keys are stolen, the data is protected. Even if the password and the
# keys are captured, spare LUKS key slots can be used to change the 
# credentials. An attack requires the memorized GPG PRIVATE KEY passphrase, the
# usb-drive's decrypted PUBLIC keys, AND physical access to the laptop. 
# Additionally, the LUKS header could be detached and stored on the usb-drive 
# when not in use, making the unmapped volume appear as random noise.
#
# However, for this specific use case, where the PRIVATE keys are carried WITH
# the secured volume at all times, 2 LUKS keys (1 backup and 1 default) are
# each secured using GPG2 w/ password protection [symmetric encryption]. This
# means that the memorized GPG2 key password effectively provides the only
# 'real' protection since the encrypted keys could easily be found in the live
# instance by a thief, so the key's passphrase should carefully balance the
# requirement of being memorable with the need to be relatively complex/long.
# Critically, both the GPG2-encrypted keys and the Serpent+Argon2id LUKS volume
# data are each well-protected from brute force attacks, which is why this
# approach is vastly superior to simply creating a new LUKS volume with a
# passphrase via 'Disks' in the GUI.
#
# | P-# | Label    | File System | GUID       | Flags/Attributes               |
# | :-- | :------- | :---------- | :--------- | :----------------------------- |
# | P-1 | images   | exFAT       | LVM        | lvm, no_automount              |
# | P-2 | efiboot  | FAT16       | EFI System | boot, esp, hidden, no_automount|
# | P-3 | writable | ext4        | LVM        | lvm, no_automount              |
# | P-4 | share    | exFAT       | msftdata   | msftdata                       |
# | P-5 | secret   | ext4 (LUKS) | LVM        | lvm, no_automount, hidden      |
#
#
# INSTRUCTIONS:
#
# * Use a giant, ultra-fast, BLANK usb drive. (512GB? 3.1/3.2 2x2?)
#
# * Install Ventoy using options to install as GPT instead of the default MBR
# Assign/reserve additional space as desired for this project!!! 
#
# * Ventoy will create partitions 1 and 2.
# You can NEVER change the location or size of these partitions, so get it right
# the FIRST time. (fyi - it's fine to change the LABEL and flags of P1 and P2).
# 
# * Manually create Partition-3 as an ext4 filesystem with the LABEL=writable
# This causes the live Ubuntu-24 to natively identify Partiton-3 as persistent
# storage; No Ventoy .dat file needed. ...But we DO need to use ventoy.json to 
# configure GRUB to append the word 'persistent' to the boot options (else you 
# must press 'e' to manually append the argument to the bootloader each time.
#
# VERIFY that the persistent parition actually works before doing anything else!
#
# * Create a public (exFAT, ntfs, ext4, etc.) Partition-4 with LABEL=share 
# and a private (ext4) Partition-5 with LABEL=secret [fyi - ext4 is REQUIRED for
# LUKS! ...and it only works in linux hosts]. The script expects these volume 
# labels when it sets up the auto-mount for ubuntu to open the 'share' partition
# automatically by creating a systemD service; This is done primarily to mount a
# music library in the 'shared' partition into the ~/Music folder at boot, so 
# that music isn't kept in the 'writable' partiton used for the ubuntu overlay.
# 
# With the basic persistent drive working correctly, chmod +x this script
# and execute it in the Ubuntu [>=v24.04.4] live-session to:
#
# * Always mount Partition-4 [shared] at boot of the persistent live-session.
#   (by using a SystemD service that calls a startup script)
# * Bind /mnt/share/Music to ~/Music at each boot.
# * Secure Partition-5 with LUKS using AES256 Serpent+Argon2id w/ GPG2.
# * Generate '~/vault.sh' to toggle access to the LUKS volume.

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
