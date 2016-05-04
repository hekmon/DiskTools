#!/bin/bash

# parted algo detailed here : http://h10025.www1.hp.com/ewfrf/wc/document?cc=uk&lc=en&dlc=en&docname=c03479326

help()
{
	echo
	echo " ${1}"
	echo
	echo " ${0} /dev/sda [last sector of last created partition]"
	echo
	exit 1
}

# checks
test $# -eq 1 -o $# -eq 2 || help "This script needs one parameter"
test $(echo "${1}" | sed -r 's:^/dev/[a-z]{3}$:good:') = "good" || help "The parameter \"${1}\" does not match device regexp"
test -b "${1}" || help "${1} is not a block device"
if [ $# -gt 1 ] && ! [[ $2 =~ ^[0-9]+$ ]]; then help "If used, second parameter has to be an integer"; fi

# recover data
device=$(echo "${1}" | sed -r 's:^/dev/([a-z]{3})[0-9]{0,2}/{0,1}$:\1:')
optimal_io_size=$(cat /sys/block/${device}/queue/optimal_io_size)
minimum_io_size=$(cat /sys/block/${device}/queue/minimum_io_size)
alignment_offset=$(cat /sys/block/${device}/alignment_offset)
physical_block_size=$(cat /sys/block/${device}/queue/physical_block_size)

# Set grain
if ! [ $optimal_io_size -eq 0 ]
then
	grain=$optimal_io_size

elif [ $optimal_io_size -eq 0 ] && [ $alignment_offset -eq 0 ] && \
		[ $minimum_io_size -gt 0 ] && [ $(( $minimum_io_size & ($minimum_io_size - 1) )) -eq 0 ] # this line check if minimum_io_size is a power of 2
then
	grain=1048576 # 1MiB
else
	if [ $minimum_io_size -eq 0 ]; then
		grain=$physical_block_size	# seems weird here
	else
		grain=$minimum_io_size
	fi
fi

# compute
optimal_sectors_multiple=$(( ($grain + $alignment_offset) / $physical_block_size ))

# calculate starting sector for next partition if last sector is provided ($2)
if [ "$2" ];
then
	next_partition_starting_sector=$(( ( ($2 / $optimal_sectors_multiple) + 1) * $optimal_sectors_multiple ))
else
	next_partition_starting_sector=""
fi

# print results
echo
echo -e "  Results for device :\t${1}"
echo -e "    Optimal IO Size\t${optimal_io_size}"
echo -e "    Minimum IO Size\t${minimum_io_size}"
echo -e "    Alignment Offset\t${alignment_offset}"
echo -e "    Physical Block Size\t${physical_block_size}"
echo
echo -e "\tYou should start your partition with a multiple of ${optimal_sectors_multiple} sectors"
if [ "$next_partition_starting_sector" ]
then
	echo
	echo -e "\tStarting sector of your next partition should be ${next_partition_starting_sector} as the last sector used is ${2}"
fi
echo
