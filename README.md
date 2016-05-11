# DiskTools

DiskTools is a small collection of bash scripts I wrote for tasks I was tired of doing manually.

It is for now composed of :
* [GPTinitialize](https://github.com/Hekmon/DiskTools)
* [optimalAlignment](https://github.com/Hekmon/DiskTools)


## GPTinitialize

GPTinitialize prepare a disk with a GPT partitonning schema for a dual compatibility between BIOS and UEFI. Once initialized, the disk can be used in both boot mode as long as the 2 specials partitions are on the disk.

It :
* Initializes the disk as GPT (and yes that means __loss of data__)
* Creates a special partition for BIOS boot (in GPT there is no more unused MBR free space and boot loaders need one)
* Creates a UEFI partition with the right formating (FAT32) and flags (boot) in order to be used in a UEFI boot mode

### Requirements

In order to work properly, the following binaries should be available on your system/PATH :

* `bash` obviously  :)
* `parted` for printing partition tables, partitioning and tagging
* `partprobe` to update udev in order to properly see the partitions as block devices files just after being created
* `dd` to "format" the BIOS partition which should be in RAW format (zeroed)
* `mkfs.fat` to format the UEFI partition which should be in FAT32


### Example

Let's initialize a disk seen as `/dev/sdb`. At the beginning it has a classical `msdos` partionning schema, and a single 500 GB size partition. I did backup the data I wanted to keep, and now I am ready to reinitialize it using `GPTinitialize.sh` :

```
DiskTools> sudo ./GPTinitialize.sh /dev/sdb

 Table partition for : /dev/sdb

Model: ASMT 2105 (scsi)
Disk /dev/sdb: 500GB
Sector size (logical/physical): 512B/512B
Partition Table: msdos
Disk Flags: 

Number  Start   End     Size    Type     File system  Flags
        32,3kB  1049kB  1016kB           Free Space
 1      1049kB  500GB   500GB   primary
        500GB   500GB   24,6kB           Free Space


	You are about to FORMAT and INITIALIZE as GPT the following block device :
		/dev/sdb

Please type 'yes' to proceed : yes


 * Initializing disk with GPT partitionning

 * Writing BIOS compatibility partition
	creating partition
	setting bios compatibility flag
    formating partition                                               

 * Writing UEFI partition
	creating partition
	setting uefi partition flag
	formating partition

 * Verifying partitions alignement
	BIOS partition : OK
	UEFI partition : OK

 * Done !


 Final table partition for /dev/sdb :

Model: ASMT 2105 (scsi)
Disk /dev/sdb: 500GB
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Disk Flags: 

Number  Start   End     Size    File system  Name       Flags
        17,4kB  2097kB  2080kB  Free Space
 1      2097kB  4194kB  2097kB  ext4         bios_boot  bios_grub
 2      4194kB  541MB   537MB   fat32        uefi_boot  boot, esp
        541MB   500GB   500GB   Free Space


DiskTools>
```

As you can seen in the end, disk is in `GPT` and has abilities to be used as a boot disk in both `msdos` or `GPT` mode. You are now free to add whatever partitions you need, but I recommand you check [optimalAlignment](https://github.com/Hekmon/DiskTools) in order to do so ;)

### Limitations

To keep the partitions aligned in most cases, I had to set some hard values in the script. It will work as long as your disk has `sector size >= 512B`. If not, you will have a nice error message.

But using [optimalAlignment](https://github.com/Hekmon/DiskTools) and with little calculations, you should be able to adapt it to your needs as you only need to change two variables : `bios_part_sectors_start` and `uefi_part_sectors_start`.

Ho and if you are wondering how to check your disk sector size, just keep on reading.

## optimalAlignment

optimalAlignment helps you to keep your partitions aligned depending on your disk sector size.

It gives you the sector multiple to use for every partition start. It can also compute the next sector you should use for a new partition by using the last sector used (check example 2).

### Example 1

If you are just interested by your disk metadata and/or the the multiple you should use, just pass a block device as first parameter :

```
DiskTools> ./optimalAlignment.sh /dev/sdb

  Results for device :	/dev/sdb
    Optimal IO Size		0
    Minimum IO Size		512
    Alignment Offset	0
    Physical Block Size	512

	You should start your partition with a multiple of 2048 sectors

DiskTools>
```

### Example 2

But you can pass a second argument to optimalAlignment : the sector number of your last partition in order to compute the sector number to use for your next partition in order to make it aligned.

Let's use the disk we initialized in the [GPTinitialize](https://github.com/Hekmon/DiskTools) part :

```
DiskTools> sudo parted /dev/sdb u s print free
Model: ASMT 2105 (scsi)
Disk /dev/sdb: 976773168s
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Disk Flags: 

Number  Start     End         Size        File system  Name       Flags
        34s       4095s       4062s       Free Space
 1      4096s     8191s       4096s       ext4         bios_boot  bios_grub
 2      8192s     1056767s    1048576s    fat32        uefi_boot  boot, esp
        1056768s  976773134s  975716367s  Free Space

DiskTools>
```


As you can see, the last used sector is `1056767`. Let's pass it as a second parameter :

```
DiskTools> ./optimalAlignment.sh /dev/sdb 1056767

  Results for device :	/dev/sdb
    Optimal IO Size		0
    Minimum IO Size		512
    Alignment Offset	0
    Physical Block Size	512

	You should start your partition with a multiple of 2048 sectors

	Starting sector of your next partition should be 1056768 as the last sector used is 1056767

DiskTools>
```

The script will compute the next sector safe to be used for a new aligned partition by taking into account your disk particularities : `1056768`.

In this case it is the sector just after the last one used, but this is because I made sure that [GPTinitialize](https://github.com/Hekmon/DiskTools) creates very precise partitions bounderies and wastes no space (at least for 512/4096 scenarios) : it won't always be the case for other partitions so don't assume a simple `+1` !


## License

MIT licensed. See the LICENSE file for details.

