#!/bin/bash

echo 24 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio24/direction

#fallocate -l 2097152 ./ccd_top.bin
dd bs=2M count=1 if=/dev/zero of=flash_image.bin
dd if="$1" conv=notrunc of=flash_image.bin
flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=20000 -w flash_image.bin

echo in > /sys/class/gpio/gpio24/direction
