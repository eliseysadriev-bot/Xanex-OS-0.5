@echo off
rem ==================================================
rem  XANEX 2 - build and run
rem  Put this file next to boot.asm and double-click it.
rem ==================================================

cd /d "%~dp0"

set NASM=%LOCALAPPDATA%\bin\NASM\nasm.exe
set QEMU=C:\Program Files\qemu\qemu-system-i386.exe

echo [1/3] Bootloader...
"%NASM%" -f bin boot.asm -o boot.bin
if errorlevel 1 goto failed

echo [2/3] Kernel...
"%NASM%" -f bin kernel.asm -o kernel.bin
if errorlevel 1 goto failed

echo [3/3] Disk image...
copy /b boot.bin + kernel.bin os.img >nul
if errorlevel 1 goto failed

rem Pad the image to a round size. The firmware dislikes
rem disks of odd length and may refuse to boot at all.
powershell -NoProfile -Command "$f=[IO.File]::ReadAllBytes('os.img'); $n=516096; if($f.Length -lt $n){$b=New-Object byte[] $n; [Array]::Copy($f,$b,$f.Length); [IO.File]::WriteAllBytes('os.img',$b)}"

echo.
echo Starting...
"%QEMU%" -m 64 -drive format=raw,file=os.img
goto done

:failed
echo.
echo BUILD FAILED - see the message above.
echo If nasm or qemu is not found, fix the paths
echo at the top of this file.
pause
exit /b 1

:done