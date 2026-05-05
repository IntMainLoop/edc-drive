#!/bin/bash
# -----------------------------------------------
# Use this script to open/close the secure volume 
# -----------------------------------------------

# Default configuration
PUBLIC_VOLUME_LABEL="system"
MAPPER_NAME="vault"
MNT="/mnt/sd/secrets"
GPG_KEY_1_PATH="$HOME/keys/secret-1.key.gpg"

# Check if the volume is already open
if [ -b "/dev/mapper/$MAPPER_NAME" ]; then
    echo "Vault is already open. Locking down..."
    
    # Unmount if currently mounted
    mountpoint -q "$MNT" && sudo umount "$MNT"
    
    # Close the LUKS container
    sudo cryptsetup close "$MAPPER_NAME"
    
    # Verify the close
    if [ -b "/dev/mapper/$MAPPER_NAME" ]; then
	echo "WARNING: The vault was unable to be secured!!!"
	echo "Close any applications that may be using the volume and try again."
	exit 1
    else
	# Remove the mount point only if unmount was successful
	sudo rmdir $MNT
	echo "Vault secured."
    fi
else
    echo "Unlocking Vault..."$'\n'
    
    # Display available drives and labels for reference
    lsblk -o NAME,FSTYPE,LABEL,SIZE --include 8
    echo ""

    # 1. Ask for the Volume Label
    read -erp "Enter the LUKS volume label: " -i "$PUBLIC_VOLUME_LABEL" TARGET_NAME

    # 2. Dynamic Discovery: Find the /dev path associated with that specific LABEL
    # We use -p for full paths and -l for a flat list
    DYNAMIC_DEVICE=$(lsblk -lnpo PATH,LABEL --include 8 | awk -v label="$TARGET_NAME" '$2==label {print $1; exit}')

    # 3. Fallback: If label not found, suggest the first crypto_LUKS partition available
    if [ -z "$DYNAMIC_DEVICE" ]; then
        DYNAMIC_DEVICE=$(lsblk -lnpo PATH,FSTYPE --include 8 | awk '$2=="crypto_LUKS" {print $1; exit}')
    fi

    # 4. Confirm the Target Device
    read -erp "Enter the target device: " -i "$DYNAMIC_DEVICE" TARGET_DEVICE

    # Safety check: ensure the device exists before proceeding
    if [ ! -b "$TARGET_DEVICE" ]; then
        echo "ERROR: Device $TARGET_DEVICE not found."
        exit 1
    fi

    # Create mount point if it doesn't exist
    sudo mkdir -p "$MNT"

    echo "Requesting passphrase via GPG..."
    
    # 5. Decrypt GPG key and Pipe to LUKS
    # --key-file=- tells cryptsetup to read the key from the pipe
    if gpg --decrypt "$GPG_KEY_1_PATH" | sudo cryptsetup open "$TARGET_DEVICE" "$MAPPER_NAME" --key-file=-; then
        sudo mount "/dev/mapper/$MAPPER_NAME" "$MNT"
        echo "-----------------------------------------------"
        echo "SUCCESS: Vault mounted at $MNT"
        echo "-----------------------------------------------"
        
        # Clear GPG cache so the passphrase isn't sitting in memory
        gpg-connect-agent reloadagent /bye
    else
        echo "ERROR: Decryption failed or incorrect passphrase."
        exit 1
    fi
fi
