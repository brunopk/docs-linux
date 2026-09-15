# LVM

## Identify the physical disk / LVM PV

```
pvs
lvs -o lv_name,vg_name,lv_attr,lv_size,devices
```

Found:

VG: vg
LV: home
PV: /dev/sdc2

Check the physical PV

```
dd if=/dev/sdc2 of=/dev/null bs=4096 count=1 iflag=direct
```

This succeeded, confirming /dev/sdc2 was readable.

Test the LV

```
dd if=/dev/mapper/vg-home of=/dev/null bs=4096 count=1 iflag=direct
```

This failed with I/O error.

Discover the stale device-mapper mapping

```
dmsetup table /dev/mapper/vg-home
```

Initially:

0 716718080 linear 8:18 29362176

8:18 was /dev/sdb, which no longer existed.

Confirm the current disk

```
lsblk -o NAME,MAJ:MIN,SIZE,TYPE,MOUNTPOINTS
```

Current PV:

sdc2  8:34  365.8G  part

Check that nothing was actively using the mount

```
findmnt /dev/mapper/vg-home
lsof +f -- /mnt/vg-home
```

Unmount

```
umount /mnt/vg-home
```

Rebuild the LV device mapping through LVM

```
lvchange -an /dev/vg/home
lvchange -ay /dev/vg/home
```

Verify the mapping

```
dmsetup table /dev/mapper/vg-home
```

Now:

0 716718080 linear 8:34 29362176

Correctly pointing to /dev/sdc2.

Test and remount

```
dd if=/dev/mapper/vg-home of=/dev/null bs=4096 count=1 iflag=direct
mount /dev/mapper/vg-home /mnt/vg-home
```
