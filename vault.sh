#!/bin/bash
# ----------------------------------------------------------------------
# Vault Management Script (Matches secure_partition.sh Environment)
# ----------------------------------------------------------------------

# Production Configuration Parameters
PUBLIC_VOLUME_LABEL="system"
MAPPER_NAME="vault"
MNT="/mnt/sd/secrets"
GPG_KEY_1_PATH="$HOME/keys/secret-1.key.gpg"

# Check if the cryptographic volume is already active
if [ -b "/dev/mapper/$MAPPER_NAME" ]; then
    echo "Vault is currently active. Initiating secure tear-down..."
    
    # Safely unmount filesystem if mounted
    if mountpoint -q "$MNT"; then
        echo "Unmounting filesystem at $MNT..."
        sudo umount "$MNT"
    fi
    
    # Close the LUKS2 Container
    echo "Collapsing virtual cryptographic pathways..."
    sudo cryptsetup close "$MAPPER_NAME"
    
    # Structural integrity check post-closure
    if [ -b "/dev/mapper/$MAPPER_NAME" ]; then
        echo "❌ WARNING: The vault was unable to be secured!" >&2
        echo "Close active target applications using the volume and retry." >&2
        exit 1
    else
        # Remove target mount directory if cleanup succeeded
        if [ -d "$MNT" ]; then
            sudo rmdir "$MNT"
        fi
        echo "✅ Process Complete: Vault pathways collapsed and secured."
    fi
else
    echo "Unlocking Multi-Layer Encrypted Vault..."$'\n'
    
    # Enumerate available physical attachments (excluding root storage blocks)
    echo "=================================================================="
    echo " AVAILABLE BLOCK STORAGE ATTACHMENTS:"
    echo "=================================================================="
    lsblk -o NAME,FSTYPE,LABEL,SIZE --include 8
    echo "=================================================================="
    echo ""

    # 1. Ask for the GPT Partition Label (Defaults to "system")
    read -erp "Enter the GPT partition label: " -i "$PUBLIC_VOLUME_LABEL" TARGET_NAME

    # 2. Dynamic Discovery: Find the /dev block path via GPT Partition Name/Label
    DYNAMIC_DEVICE=$(lsblk -lnpo PATH,LABEL --include 8 | awk -v label="$TARGET_NAME" '$2==label {print $1; exit}')

    # 3. Structural Fallback: Scan blocks for an unmapped crypto_LUKS filesystem type
    if [ -z "$DYNAMIC_DEVICE" ]; then
        DYNAMIC_DEVICE=$(lsblk -lnpo PATH,FSTYPE --include 8 | awk '$2=="crypto_LUKS" {print $1; exit}')
    fi

    # 4. Confirm the Targeted Block Device
    read -erp "Confirm target block device path: " -i "$DYNAMIC_DEVICE" TARGET_DEVICE

    # Strict Safety Check: Verify block device presence before execution
    if [ ! -b "$TARGET_DEVICE" ]; then
        echo "❌ Error: Targeted block device '$TARGET_DEVICE' is unavailable." >&2
        exit 1
    fi

    # Prepare local transient mount paths
    sudo mkdir -p "$MNT"

    echo "Streaming cryptographic token via GPG symmetric decryption layer..."
    
    # 5. Pipeline GPG Decrypted Token straight to cryptsetup stdin (-)
    if gpg --decrypt "$GPG_KEY_1_PATH" 2>/dev/null | sudo cryptsetup open "$TARGET_DEVICE" "$MAPPER_NAME" --key-file=-; then
        echo "Mounting file container filesystem..."
        sudo mount "/dev/mapper/$MAPPER_NAME" "$MNT"
        
        echo "------------------------------------------------------------------"
        echo " ✅ SUCCESS: Dual-Layer Vault mapped and mounted at: $MNT"
        echo "------------------------------------------------------------------"
        
        # Flush transient GPG cache agents to clean system memory footprints
        gpg-connect-agent reloadagent /bye >/dev/null 2>&1
    else
        echo "❌ Error: Symmetric GPG decryption failed or bad passphrase." >&2
        # Clean up the unused directory if the mount process failed
        sudo rmdir "$MNT" 2>/dev/null || true
        exit 1
    fi
fi
