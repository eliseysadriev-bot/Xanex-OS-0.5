#!/bin/bash
# XANEX 2 - build and run on Linux
# Put this file next to boot.asm, then: chmod +x build.sh && ./build.sh

cd "$(dirname "$0")"

set -e

echo "[1/3] Bootloader..."
nasm -f bin boot.asm -o boot.bin

echo "[2/3] Kernel..."
nasm -f bin kernel.asm -o kernel.bin

echo "[3/3] Disk image..."
cat boot.bin kernel.bin > os.img

# Pad the image to a round size. The firmware dislikes
# disks of odd length and may refuse to boot at all.
truncate -s 516096 os.img

# Two extra disks, created empty if missing.
[ -f disko.img ] || truncate -s 516096 disko.img
[ -f diskm.img ] || truncate -s 516096 diskm.img

echo
echo "Starting..."
qemu-system-i386 -m 64 -serial file:serial.log \
    -drive format=raw,file=os.img,index=0 \
    -drive format=raw,file=disko.img,index=1 \
    -drive format=raw,file=diskm.img,index=2