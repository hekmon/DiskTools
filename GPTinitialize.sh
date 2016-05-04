#!/bin/bash

fatalerror() {
	echo
	echo -e "\t${1}"
	echo
	exit 1
}

# checks
test "$(whoami)" != "root" && fatalerror "You need to be root"
test $# -eq 0 && fatalerror "Usage : $0 <block device>"
test ! -b "$1" && fatalerror "$1 is not a block device"
test -n "$(mount | grep "$1" )" && fatalerror "$1 or one of its partition is currently mounted !"

# print table partition
echo
echo " Table partition for : $1"
echo
parted "$1" print free
RETURNCODE=$?
test $RETURNCODE -ne 0 && fatalerror "Error code $RETURNCODE from parted"

# user confirm
REP="no"
while [ "$REP" != "yes" ]
do
	echo
	echo -e "\tYou are about to FORMAT and INITIALIZE as GPT the following block device :"
	echo -e "\t\t$1"
	echo
	read -p "Please type 'yes' to proceed : " REP
done

# compute some working values
device_short_name=$(echo "$1" | sed -r 's;^.+/([^/]+);\1;')
test -z "$device_short_name" && fatalerror "can't compute device's shortname"
physical_block_size=$(cat /sys/block/${device_short_name}/queue/physical_block_size)
test $? -ne 0 && fatalerror "can't get device physical block size"

# bios compatibility partition (legacy MBR free space)
bios_part_sectors_start=4096 # aligned on both 512 (hdd) or 4096 (sdd)
bios_part_sectors_size=$(( (2 * 1024 * 1024) / $physical_block_size )) # 2 MiB
bios_part_sectors_end=$(( $bios_part_sectors_start + $bios_part_sectors_size - 1))

# UEFI partition
uefi_part_sectors_start=8192 # aligned with both physical block size at 512 (hdd) or 4096 (sdd) with enough space for a 2MiB bios partition as long as sectors are not < 512B
test ! $uefi_part_sectors_start -gt $bios_part_sectors_end && fatalerror "Something is weird here. UEFI partition start sector ($uefi_part_sectors_start) should be greater than bios partition end sector ($bios_part_sectors_end). Do you really have a disk with less than 512B per sector ? (actually you have : ${physical_block_size})"
uefi_part_sectors_size=$(( 512 * 1024 * 1024 / $physical_block_size )) # 512 MiB
uefi_part_sectors_end=$(( $uefi_part_sectors_start + $uefi_part_sectors_size - 1 )) 

# proceed
echo
echo
echo " * Initializing disk with GPT partitionning"
parted -s "$1" mklabel gpt
test $? -eq 0 || fatalerror "Can't initialize '$1' as GPT"
echo
echo " * Writing BIOS compatibility partition"
echo -e "\tcreating partition"
parted -s "$1" mkpart bios_boot "${bios_part_sectors_start}s" "${bios_part_sectors_end}s"
test $? -eq 0 || fatalerror "Can't create BIOS partition on '$1'"
echo -e "\tsetting bios compatibility flag"
parted "$1" set 1 bios_grub on 2> /dev/null
test $? -eq 0 || fatalerror "Can't set the BIOS compatibility flag on partition"
echo -e "\tformating partition"
dd if=/dev/zero of="${1}1" "bs=${physical_block_size}" "count=${bios_part_sectors_size}" 2> /dev/null
test $? -eq 0 || fatalerror "Formating/zeroing the bios partition failed"
echo
echo " * Writing UEFI partition"
echo -e "\tcreating partition"
parted -s "$1" mkpart uefi_boot "${uefi_part_sectors_start}s" "${uefi_part_sectors_end}s"
test $? -eq 0 || fatalerror "Can't create the UEFI partition"
echo -e "\tsetting uefi partition flag"
parted -s "$1" set 2 boot on
test $? -eq 0 || fatalerror "Can't set the boot flag on the UEFI partition"
echo -e "\tformating partition"
partprobe "${1}" # inform OS to rescan device in order to findout the now partition
sleep 1	# partprobe to udev take some time
mkfs.fat -F32 "${1}2" > /dev/null
test $? -eq 0 || fatalerror "Can't format the UEFI partition as FAT32"
echo
echo " * Verifying partitions alignement"
echo -en "\tBIOS partition : "
( parted -s "$1" align-check optimal 1 && echo "OK" ) || echo "KO !"
echo -en "\tUEFI partition : "
( parted -s "$1" align-check optimal 2 && echo "OK" ) || echo "KO !"
echo
echo " * Done !"
echo
echo
echo " Final table partition for $1 :"
echo
parted -s "$1" print free
echo
exit 0
