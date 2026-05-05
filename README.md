# edc-drive
how to create a bootable, persistent, secure, usb-drive with a public partiton that auto-mounts  

WARNING!  
The luks-commands.sh script is untested, but the same steps have been taken successfully and they should be able to be executed (please report any errors or upload a fix)  

1.) Install Ventoy with a GPT boot sector to a large USB drive assigning plenty of unallocated space (P1-exFAT, P2:FAT16)  
2.) Copy an Ubuntu 24.04 LTS or later .iso into Ventoy's image folder (P1:exFAT)  
3.) Configure persistence for the Ubuntu instance by using a ventoy GRUB injection to add the 'e' option at boot and also by creating a partition labeled 'writable' (P3:ext4)  
4.) VERIFY THAT PERSISTENCE WORKS UPON REBOOT  
5.) create (P4:exFAT) Public  
6.) create (P5:ext4) Private  
7.) Execute luks-commands.sh (probably still need to run them one at a time instead of as a script to avoid any issues, but hey, it might work?)  

Partition1 [exFAT] = 'images' (created by Ventoy - use GPT and leave remaining space) [GUID_TYPE:LVM]
Partition2 [FAT16] = 'EFIBOOT' (created by Ventoy) [GUID_TYPE:EFI BOOT]
Partition3 [ext4] = 'writable' (persistent partition) [GUID_TYPE:LVM]
Partition4 [exFAT] = 'share' (public) [GUID_TYPE:Basic Data, msftdata]
Partition5 [ext4] = 'secret' (LUKS secured) [GUID_TYPE:LVM]
(These GUID_TYPE's cause only the 'share' partition to automount on most systems.)

To LABEL ExFAT partitons use:
sudo fatlabel /dev/sdXx share

To LABEL ext4 partitons use:
sudo e2label /dev/sdXx share

CRITICAL: be sure that the Ubuntu persistence partition uses the label 'writable' or it will be ignored starting in Ubuntu v20
