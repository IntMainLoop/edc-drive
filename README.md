# edc-drive
create a bootable, persistent, secure, usb-drive with a public partiton that auto-mounts  
-----------------------------------------------------------------------------------------------

* WARNING!  
The luks-commands.sh script is untested, strongly consider running each command by hand for now

* DE'STRUCTIONS:
1.  Install Ventoy with a GPT boot sector to a large USB drive assigning plenty of unallocated space
    * This creates P1-exFAT, P2:FAT16.  
    * Carefully consider the parition sizes requried.  
    * DO NOT attempt to resize the partitions Ventoy created.  
    * It's ok to re-label the ventoy partitions, but that's about it.
2.  Copy an Ubuntu-desktop 24.04 LTS or later .iso image into Ventoy's 'images' partiton (P1:exFAT)  
3.  Configure persistence for the Ubuntu instance:
    * "[P1:images]:/ventoy/ventoy.json"
    * "[P1:images]:/ventoy/ubuntu_grub.cfg"
    * The dedicated persistence partition (P3) MUST be labeled: 'writable'
4.  While running the Ubuntu live session, setup the auto-mounts using a custom service (to allow bind-mounts of [P4:share]/Music/* to /home/ubuntu/Music/):
    * cp startup-mount.service [P3:writable]:/etc/systemd/system/startup-mount.service/startup-mount.service  
    * cp startup-mount.sh [P3:writable]:/usr/local/bin/startup-mount.sh
    * sudo chmod +x /usr/local/bin/startup-mount.sh  
    * sudo systemctl daemon-reload  
    * sudo systemctl enable startup-mount.service
5.  VERIFY THAT PERSISTENCE WORKS UPON REBOOT!  
6.  create (P4:exFAT), 'share', Public  
7.  create (P5:ext4), 'system', Private  
8.  Execute 'luks-commands.sh' (probably still need to run commands one-at-a-time and think about them instead of running blindly as a script to avoid any issues, but hey, it might work?)  
9.  Use gParted to set the Flags/Attributes and GUID's after the vault works so that only the public, 'share' partiton will auto-mount when enumerated on nearly any OS.

| P-# | Label    | File System | GUID       | Flags/Attributes               |  
| :-: | :------: | :---------: | :--------: | :----------------------------: |  
| P-1 | images   | exFAT       | LVM        | lvm, no_automount              |  
| P-2 | efiboot  | FAT16       | EFI System | boot, esp, hidden, no_automount|  
| P-3 | writable | ext4        | LVM        | lvm, no_automount              |  
| P-4 | share    | exFAT       | msftdata   | msftdata                       |  
| P-5 | system   | ext4 (LUKS) | LVM        | lvm, no_automount, hidden      |  
  
CRITICAL: be sure that the Ubuntu persistence partition uses the label 'writable' or it will be ignored starting in Ubuntu v20  
