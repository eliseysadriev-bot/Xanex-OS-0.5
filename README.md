# XANEX 2

A small operating system written from scratch in x86 assembly.
No libraries, no existing kernel — everything is done by hand.

## What works

- Boots from disk, switches to protected mode, 320x200 graphics with 256 colors
- PS/2 mouse with a hardware cursor drawn over the frame
- Keyboard input
- Draggable windows with title bars and pressable buttons
- Notepad — type text and save it to disk
- Calculator — four operations
- Own file system: a directory sector plus one sector per file
- Raw ATA disk read and write
- Settings: pick the window color, saved between runs

## What doesn't

- No networking, no sound
- One sector per file, 16 files maximum
- Paint, Terminal and Files are listed but not implemented yet

## Build

Needs NASM and QEMU. Run `build.bat`, or:

    nasm -f bin boot.asm -o boot.bin
    nasm -f bin kernel.asm -o kernel.bin
    copy /b boot.bin + kernel.bin os.img

Pad the image to 516096 bytes — the firmware refuses odd-sized disks.

## Size

Bootloader: ~110 lines. Kernel: ~2300 lines.
