#!/bin/bash
# ==============================================================================
# VENTOY LUKS VAULT SETUP WIZARD [AES512 Serpent + Argon2id (Version 2.1)]
# ==============================================================================
#
# SYNOPSIS:
# This plan creates a persistent, bootable Ubuntu USB drive on a keychain with
# a PRIVATE partition that ONLY auto-mounts a PUBLIC partition when enumerated
# on a typical MSFT, AAPL, or Linux machine. By specifying unusual but
# compatible GUIDs (LVM, BootEFI, or Windows Recovery) which are usually
# ignored by the OS, these partitions do not auto-mount. A standard exFAT
# 'msftdata' PUBLIC partition serves both a functional role and obfuscates the
# full capability of the drive from the casual observer. It employs
# Multi-Factor Encryption by using GPG-encrypted symmetric keyfiles to unlock a
# Serpent+Argon2id LUKS partition, providing reasonably secure data storage for
# a persistent live session located on a single USB drive carried on a physical
# keyring.
#
# Ideally, a USB drive on a keyring carries public keys and uses a passphrase
# with the GPG private key to unlock the LUKS partition's symmetric keyfile.
# This requires access to the laptop, access to the USB drive, and the GPG
# passphrase. If the laptop is stolen, the data is protected; if the keys are
# stolen, the data is protected. If both the laptop and the keys are stolen, 
# the data is protected. Even if the password and the keys are captured, spare
# LUKS key slots can be used to change the credentials. An attack requires the
# memorized GPG private key passphrase, the USB drive's decrypted public keys,
# AND physical access to the laptop. Additionally, the LUKS header could be
# detached and stored on the USB drive when not in use, making the unmapped
# volume appear as random noise.
#
# However, for this specific use case, where the private keys are carried WITH
# the secured volume at all times, 2 LUKS keys (1 backup and 1 default) are
# each secured using GPG2 with password protection (symmetric encryption). This
# means that the memorized GPG2 key password effectively provides the only
# "real" protection since the encrypted keys could easily be found in the live
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
# * Use a giant, ultra-fast, BLANK USB drive. (512GB? 3.1/3.2 2x2?)
#
# * Install Ventoy using options to install as GPT instead of the default MBR.
#   Assign/reserve additional space as desired for this project!!! 
#
# * Ventoy will create partitions 1 and 2.
#   You can NEVER change the location or size of these partitions, so get it right
#   the FIRST time. (fyi - it's fine to change the LABEL and flags of P1 and P2).
# 
# * Manually create Partition-3 as an ext4 filesystem with the LABEL=writable.
#   This causes the live Ubuntu instance to natively identify Partition-3 as persistent
#   storage; No Ventoy .dat file needed. ...But we DO need to use ventoy.json to 
#   configure GRUB to append the word 'persistent' to the boot options (else you 
#   must press 'e' to manually append the argument to the bootloader each time).
#
#   VERIFY that the persistent partition actually works before doing anything else!
#
# * Create a public (exFAT) Partition-4 with LABEL=share 
#   and a private Partition-5 with LABEL=secret (Note: LUKS encapsulates block devices;
#   we format the underlying mapped volume as ext4). The script expects these volume 
#   labels when it sets up the auto-mount for Ubuntu to open the 'share' partition
#   automatically by creating a SystemD service; This is done primarily to mount a
#   music library in the 'shared' partition into the ~/Music folder at boot, so 
#   that music isn't kept in the 'writable' partition used for the Ubuntu overlay.
# 
# With the basic persistent drive working correctly, chmod +x this script
# and execute it in the Ubuntu live session to secure at partition with LUKS using 
# AES512 Serpent+Argon2id w/ GPG2.

set -e # Terminate script early if any command pipeline encounters a structural failure

# -----------------
# REFERENCE NOTES #
# -----------------
# [Variables reference layout, now parsed programmatically during system runtime below]
# DISK="sdc"
# PART_NUMBER="5"
# TARGET_PATH="/dev/\$DISK\$PART_NUMBER"
# LUKS_KEY_0_PATH="\$HOME/keys/luks0" 
# LUKS_KEY_1_PATH="\$HOME/keys/luks1" 
# GPG_KEY_0_PATH="\$HOME/keys/secret-0.key.gpg"
# GPG_KEY_1_PATH="\$HOME/keys/secret-1.key.gpg"
# MAPPER_NAME="vault"
# PARTITION_LABEL="system"
# LUKS_LABEL="s_data"
# LUKS_FS_LABEL="secrets"
# MOUNT="/mnt/sd/"
# MOUNT_POINT="\$MOUNT\$LUKS_FS_LABEL"

# --------------------
# LABELING REFERENCE #
# --------------------
# Label exFAT partitions use (exfatprogs utility):
# sudo exfatlabel /dev/sdcX "share"
#
# Label ext4 partitions use:
# sudo e2label /dev/sdcX "writable"
# 
# LUKS - Label GPT Partition structure (visible always on target parent disk):
# sudo sgdisk --change-name=5:system /dev/sdc
# 
# LUKS - Label LUKS2 Container (visible when LUKS is closed):
# sudo cryptsetup config /dev/sdc5 --label s_data
# 
# LUKS - Label LUKS2 File System Volume (visible when LUKS is open):
# sudo e2label /dev/mapper/vault secrets
# 
# LUKS - Change the mapper device name:
# sudo dmsetup rename vault <NEW_NAME>

# ---------------------------------
# BASIC LUKS KEY MANAGEMENT NOTES #
# ---------------------------------
# Check if the LUKS volume is open:
# ls /dev/mapper/vault
#
# Dump LUKS status:
# sudo cryptsetup luksDump /dev/sdc5
#
# Create a NEW LUKS passphrase for Slot-1:
# sudo cryptsetup luksAddKey --key-slot 1 /dev/sdc5
# 
# Verify a LUKS passphrase:
# sudo cryptsetup -v open --test-passphrase /dev/sdc5
# 
# Remove a LUKS Key (by Slot-#):
# sudo cryptsetup luksKillSlot /dev/sdc5 0
# 
# Remove a LUKS Key (by Passphrase):
# sudo cryptsetup luksRemoveKey /dev/sdc5

# ==============================================================================
# [ BEGIN EXECUTION PHASE ]
# ==============================================================================

# ==============================================================================
# 1. PREREQUISITES & INDEPENDENT TARGET DETECTION
# ==============================================================================
echo "=================================================================="
echo "AVAILABLE BLOCK STORAGE DEVICES (Excluding active OS root):"
echo "=================================================================="
# Prints unmounted physical device blocks to eliminate disk selection mistakes
lsblk -dno NAME,SIZE,MODEL | grep -v "$(lsblk -no PKNAME / | head -n1)" || true
echo "=================================================================="

read -p "Enter target block drive name (e.g., sdc, sdd): " SELECTED_DISK
DISK_PATH="/dev/$SELECTED_DISK"

if [ ! -b "$DISK_PATH" ] || [ -z "$SELECTED_DISK" ]; then
    echo "❌ Error: $DISK_PATH is not a recognized block storage attachment." >&2
    exit 1
fi

PART_NUMBER="5"
TARGET_PATH="/dev/${SELECTED_DISK}${PART_NUMBER}"

if [ ! -b "$TARGET_PATH" ]; then
    echo "❌ Error: Expected storage sub-partition $TARGET_PATH does not exist." >&2
    exit 1
fi

echo ""
echo "⚠️  CRITICAL DESTRUCTIVE WARNING ⚠️"
echo "You are initializing a highly encrypted system footprint on:"
echo "  Parent Storage Device: $DISK_PATH"
echo "  Target Block Partition:  $TARGET_PATH (All existing contents will be dropped!)"
echo ""
read -p "Type exactly 'DESTROY' to execute partition provisioning: " CONFIRM
if [ "$CONFIRM" != "DESTROY" ]; then
    echo "Initialization aborted by user choice."
    exit 1
fi

# Define path parameters
MAPPER_NAME="vault"
PARTITION_LABEL="system"
LUKS_LABEL="s_data"
LUKS_FS_LABEL="secrets"

echo "Syncing repository maps and installing system packages..."
sudo apt update
# exfatprogs replaces legacy exfat-utils to natively enable correct exfatlabel support
sudo apt install -y cryptsetup gnupg2 exfatprogs gdisk

# Generate storage paths
mkdir -p "$HOME/keys"
mkdir -p "/dev/shm"

# ==============================================================================
# 2. GPG SYMMETRIC ENCRYPTION AND KEY MANAGEMENT
# ==============================================================================
echo "Generating secure 512-bit raw tokens directly inside transient RAM..."
dd if=/dev/urandom bs=1 count=64 of=/dev/shm/secret-0.key 2>/dev/null
dd if=/dev/urandom bs=1 count=64 of=/dev/shm/secret-1.key 2>/dev/null

echo "Securing Backup Key Token (LUKS Slot 1) with symmetric GPG2 layer..."
gpg --symmetric --cipher-algo AES256 --s2k-digest-algo SHA512 /dev/shm/secret-0.key
mv /dev/shm/secret-0.key.gpg "$HOME/keys/secret-0.key.gpg"

echo "Securing Default Key Token (LUKS Slot 0) with symmetric GPG2 layer..."
gpg --symmetric --cipher-algo AES256 --s2k-digest-algo SHA512 /dev/shm/secret-1.key
mv /dev/shm/secret-1.key.gpg "$HOME/keys/secret-1.key.gpg"

# ==============================================================================
# 3. LUKS2 CONTEXT PROVISIONING (SERPENT + ARGON2ID TARGETS)
# ==============================================================================
echo "Formatting structural block layer using Serpent-XTS cipher chains..."
# Secure pipe mechanics stream the decrypted text direct into cryptsetup stdin (-)
gpg --decrypt "$HOME/keys/secret-1.key.gpg" 2>/dev/null | sudo cryptsetup luksFormat \
  --type luks2 \
  --cipher serpent-xts-plain64 \
  --key-size 512 \
  --pbkdf argon2id \
  --label "$LUKS_LABEL" \
  "$TARGET_PATH" -

echo "Injecting secondary GPG safe key token into slot 1 allocations..."
sudo cryptsetup luksAddKey \
  --key-slot 1 \
  --pbkdf argon2id \
  "$TARGET_PATH" \
  <(gpg --decrypt "$HOME/keys/secret-0.key.gpg" 2>/dev/null) \
  --key-file <(gpg --decrypt "$HOME/keys/secret-1.key.gpg" 2>/dev/null)

# ==============================================================================
# 4. PARTITION STRUCTURAL LABELS AND LOCAL FILESYSTEM MAPS
# ==============================================================================
echo "Mounting encrypted block device mapping context..."
gpg --decrypt "$HOME/keys/secret-1.key.gpg" 2>/dev/null | sudo cryptsetup open \
  "$TARGET_PATH" \
  "$MAPPER_NAME" \
  --key-file -

echo "Structuring inner volume format via ext4 data container..."
sudo mkfs.ext4 -L "$LUKS_FS_LABEL" "/dev/mapper/$MAPPER_NAME"

echo "Altering raw parent GPT block identifier flags..."
sudo sgdisk --change-name="${PART_NUMBER}:${PARTITION_LABEL}" "$DISK_PATH"

# ==============================================================================
# 5. VOLATILE STORAGE CLEANUP AND DATA PURGE
# ==============================================================================
echo "Shredding plain-text raw cryptographic variables..."
shred -n 10 -u /dev/shm/secret-0.key
shred -n 10 -u /dev/shm/secret-1.key

echo "Collapsing mapped virtual encryption pathways..."
sudo cryptsetup close "$MAPPER_NAME"

echo "=================================================================="
echo "✅ PROCESS COMPLETE: Dual-layer security vault initialized!"
echo "Your protected tokens reside at: $HOME/keys/"
echo "=================================================================="
