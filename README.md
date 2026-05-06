# edc-drive
create a bootable, persistent, secure, usb-drive with a public partiton that auto-mounts  
-----------------------------------------------------------------------------------------------

* WARNING!  
The luks-commands.sh script is untested, strongly consider running each command by hand for now

* DE'STRUCTIONS:
1.  Install Ventoy with a GPT boot sector to a large USB drive assigning plenty of unallocated space
    * This creates P1-exFAT, P2:FAT16.  
    * Carefully consider the parition sizes requried. USB drives don't appreciate unnecessary writes.
    * DO NOT attempt to re-size the partitions which Ventoy created.  
    * It's ok to re-label the ventoy partitions, but that's about it.
2.  Copy an Ubuntu-desktop 24.04 LTS or later .iso image into Ventoy's 'images' partiton (P1:exFAT)  
3.  Create an [ext4] partion labeled 'writable' for persistent data
    * Be sure that the Ubuntu persistence partition uses the label 'writable' or it will be ignored starting in Ubuntu v20  
4.  Configure persistence for the Ubuntu instance:
    * "[P1:images]:/ventoy/ventoy.json"
    * "[P1:images]:/ventoy/ubuntu_grub.cfg"
    * The dedicated persistence partition (P3) MUST be labeled: 'writable'
5.  While running the Ubuntu live session, setup the auto-mounts using a custom service (to allow bind-mounts of [P4:share]/Music/* to /home/ubuntu/Music/):
    * cp startup-mount.service [P3:writable]:/etc/systemd/system/startup-mount.service/startup-mount.service  
    * cp startup-mount.sh [P3:writable]:/usr/local/bin/startup-mount.sh
    * sudo chmod +x /usr/local/bin/startup-mount.sh  
    * sudo systemctl daemon-reload  
    * sudo systemctl enable startup-mount.service
6.  VERIFY THAT PERSISTENCE WORKS BY WRITING A NEW FILE TO THE DESKTOP AND REBOOTING!  
7.  create (P4:exFAT), 'share', Public  
8.  create (P5:ext4), 'system', Private  
9.  Execute 'luks-commands.sh' (probably still need to run commands one-at-a-time and think about them instead of running blindly as a script to avoid any issues, but hey, it might work?)  
10.  Use gParted to set the Flags/Attributes and GUID's after the vault works so that only the public, 'share' partiton will auto-mount when enumerated on nearly any OS.

| P-# | Label    | File System | GUID       | Flags/Attributes               |  
| :-: | :------: | :---------: | :--------: | :----------------------------: |  
| P-1 | images   | exFAT       | LVM        | lvm, no_automount              |  
| P-2 | efiboot  | FAT16       | EFI System | boot, esp, hidden, no_automount|  
| P-3 | writable | ext4        | LVM        | lvm, no_automount              |  
| P-4 | share    | exFAT       | msftdata   | msftdata                       |  
| P-5 | system   | ext4 (LUKS) | LVM        | lvm, no_automount, hidden      |  
  
11. Keep the vault.sh script anywhere you like
    * Simply run vault.sh to open or close the vault  
    * Remember to ALWAYS close the LUKS vault before un-mounting the drive to prevent data corruption!  
* Operational Notes
    * Keep the secret-0 somewhere safe. Only use secret-1.
    * If secret-1 becomes corrupt, secret-0 is your only way to recover your data. Keep secret-0 and its gpg passphrase in a secure location.
    * Use a different gpg passphrase for secret-0 and secret-1
    * Never write your gpg passphrase (or the decrypted secret) to the disk in any way. ...If that happens, even once, even by accident, the passphrase and key must be changed immediately!
    * Becuase the LUKS key is stored in the usb-drive's 'writable' partiton, the memorized secret-1 passphrase effectively becomes the only means of security, but that's actually pretty secure if the passphrase is fairly long, non-sensical and complicated.
    * If you're paranoid, memorize both passphrases and make them long; if you're normal, write down the passphrase for each key and keep them with the encrypted secret-0 key in a physically secure location
    * if you're extremely paranoid, fill every available LUKS keyslot with an encrypted key value like the others, don't leave any of them empty, then shred all but 1 key (i.e., you're gonna lose access to the data, but at least no one else will read it for a long time.)
