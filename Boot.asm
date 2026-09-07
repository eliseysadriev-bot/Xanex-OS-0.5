; Загрузчик: первый сектор диска, ровно 512 байт.
; Читает ядро, включает графику, переходит в защищённый режим.

bits 16
org 0x7c00

FONTTMP equ 0x1000              ; куда сложить шрифт до перехода
SECTORS equ 128                 ; сколько секторов читаем (64 КБ)
LOADSEG equ 0x0800              ; и куда: адрес 0x8000

start:
    cli                         ; пока настраиваемся, не отвлекаемся
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00              ; стек растёт вниз от нас
    sti
    mov [drive], dl             ; с какого диска загрузились

    ; умеет ли прошивка читать по номеру сектора
    mov ah, 0x41
    mov bx, 0x55AA
    mov dl, [drive]
    int 0x13
    jc err
    cmp bx, 0xAA55
    jne err

    ; читаем ядро по 16 секторов за раз
    mov word [dap_cnt], 16
    mov word [dap_off], 0
    mov word [dap_seg], LOADSEG
    mov dword [dap_lba], 1      ; сразу за собой
    mov cx, SECTORS / 16
.read:
    push cx
    mov ah, 0x42
    mov si, dap
    mov dl, [drive]
    int 0x13
    jc err
    pop cx
    mov ax, [dap_seg]           ; следующие 16 секторов - дальше
    add ax, 16 * 512 / 16
    mov [dap_seg], ax
    mov eax, [dap_lba]
    add eax, 16
    mov [dap_lba], eax
    dec cx
    jnz .read

    ; шрифт берём сейчас: после графики его не спросить
    push es
    mov ax, 0x1130
    mov bh, 6                   ; набор 8 на 16
    int 0x10                    ; вернёт адрес в es:bp
    push ds
    mov ax, es
    mov ds, ax
    mov si, bp
    xor ax, ax
    mov es, ax
    mov di, FONTTMP
    mov cx, 256*16
    cld
    rep movsb
    pop ds
    pop es

    ; графика 320 на 200, 256 цветов
    mov ax, 0x0013
    int 0x10

    ; --- переходим в защищённый режим ---
    cli
    in al, 0x92                 ; открываем память выше мегабайта
    or al, 2
    out 0x92, al

    lgdt [gdt_desc]             ; описание памяти
    mov eax, cr0
    or eax, 1                   ; вот он, переключатель
    mov cr0, eax
    jmp 0x08:pm_entry           ; прыжок обновляет и сам режим

; диск не читается - сказать и остановиться
err:
    mov si, msg_err
.print:
    lodsb
    test al, al
    jz .halt
    mov ah, 0x0e
    int 0x10
    jmp .print
.halt:
    hlt
    jmp .halt

bits 32
pm_entry:
    mov ax, 0x10                ; все обращения к памяти - через данные
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000            ; стек повыше, чтобы не мешал
    jmp 0x8000                  ; управление второй части

;  Описание памяти: два куска на всю память,
;  один для кода, другой для данных.
gdt:
    dq 0                        ; первый всегда пустой
    dw 0xFFFF, 0, 0x9A00, 0x00CF    ; код
    dw 0xFFFF, 0, 0x9200, 0x00CF    ; данные
gdt_desc:
    dw 24 - 1
    dd gdt

; как просим прошивку читать диск
dap:
    db 0x10                     ; длина этой записи
    db 0
dap_cnt dw 16                   ; сколько секторов
dap_off dw 0                    ; куда, смещение
dap_seg dw LOADSEG              ; куда, сегмент
dap_lba dq 1                    ; откуда, номер сектора

msg_err db "Disk error", 0
drive   db 0

times 510-($-$$) db 0           ; добиваем до 512
dw 0xaa55                       ; признак загрузочного сектора