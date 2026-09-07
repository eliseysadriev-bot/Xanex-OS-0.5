; Ядро: сюда приходит управление из загрузчика.
; Рисуем в черновик, потом переносим на экран разом.

bits 32
org 0x8000

VGAMEM  equ 0xA0000             ; настоящая память экрана
CANVAS  equ 0x200000            ; черновик, где собираем кадр
FONT    equ 0x300000            ; сюда положим шрифт
W       equ 320
H       equ 200

start:
    call grab_font              ; шрифт забираем из видеокарты
    call mouse_init             ; и мышь тоже, до первого кадра
    call disk_check             ; проверяем, читается ли диск
    call cfg_load               ; и берём сохранённые настройки
    call draw_screen
    call flip
    call draw_cursor

.loop:
    in al, 0x64                 ; есть ли что-нибудь во вводе
    test al, 1
    jz .loop
    test al, 0x20               ; пятый бит - весточка от мыши
    jz .notmouse
    call read_packet

    ; тащим окно за заголовок
    ; калькулятор лежит поверх всего - его и проверяем первым
    cmp byte [cldrag], 1
    jne .nocldrag
    cmp byte [mbtn], 1
    jne .stopcl
    mov eax, [mx]
    sub eax, [cldx]
    mov [clx], eax
    mov eax, [my]
    sub eax, [cldy]
    mov [cly], eax
    jmp .redraw
.stopcl:
    mov byte [cldrag], 0
.nocldrag:
    cmp byte [clopen], 1
    jne .noclstart
    cmp byte [mbtn], 1
    jne .noclstart
    cmp byte [mprev], 1
    je .noclstart
    call over_cltitle
    test al, al
    jz .noclstart
    mov byte [cldrag], 1
    mov eax, [mx]
    sub eax, [clx]
    mov [cldx], eax
    mov eax, [my]
    sub eax, [cly]
    mov [cldy], eax
    jmp .redraw
.noclstart:

    ; сперва настройки: они лежат поверх блокнота
    cmp byte [swdrag], 1
    jne .noswdrag
    cmp byte [mbtn], 1
    jne .stopsw
    mov eax, [mx]
    sub eax, [swdx]
    mov [swx], eax
    mov eax, [my]
    sub eax, [swdy]
    mov [swy], eax
    jmp .redraw
.stopsw:
    mov byte [swdrag], 0
.noswdrag:
    cmp byte [setopen], 1
    jne .noswstart
    cmp byte [mbtn], 1
    jne .noswstart
    cmp byte [mprev], 1
    je .noswstart
    call over_swtitle
    test al, al
    jz .noswstart
    mov byte [swdrag], 1
    mov eax, [mx]
    sub eax, [swx]
    mov [swdx], eax
    mov eax, [my]
    sub eax, [swy]
    mov [swdy], eax
    jmp .redraw
.noswstart:

    cmp byte [npdrag], 1
    jne .nodrag
    cmp byte [mbtn], 1
    jne .stopdrag
    mov eax, [mx]
    sub eax, [npdx]
    mov [npx], eax
    mov eax, [my]
    sub eax, [npdy]
    mov [npy], eax
    jmp .redraw
.stopdrag:
    mov byte [npdrag], 0
.nodrag:
    cmp byte [npopen], 1
    jne .nostart
    cmp byte [mbtn], 1
    jne .nostart
    cmp byte [mprev], 1         ; только в миг нажатия
    je .nostart
    call over_nptitle
    test al, al
    jz .nostart
    mov byte [npdrag], 1
    mov eax, [mx]
    sub eax, [npx]
    mov [npdx], eax
    mov eax, [my]
    sub eax, [npy]
    mov [npdy], eax
.nostart:

    ; пока кнопку держат над настройками, она вдавлена
    mov byte [setdown], 0
    mov byte [xdown], 0
    mov byte [npxdown], 0
    mov byte [clxdown], 0
    mov byte [cldown], 255
    cmp byte [mbtn], 1
    jne .noclheld
    call over_clclose
    test al, al
    jz .noclx
    mov byte [clxdown], 1
.noclx:
    cmp byte [clopen], 1
    jne .noclheld
    call calc_btn_at
    cmp eax, -1
    je .noclheld
    mov [cldown], al
.noclheld:
    cmp byte [mbtn], 1
    jne .notheld
    call over_setbtn
    test al, al
    jz .notset
    mov byte [setdown], 1
.notset:
    call over_closebtn          ; то же и для крестика
    test al, al
    jz .notx
    mov byte [xdown], 1
.notx:
    call over_npclose           ; и для крестика блокнота
    test al, al
    jz .notheld
    mov byte [npxdown], 1
.notheld:

    ; срабатывает по отпусканию, а не по нажатию
    mov al, [mbtn]
    mov ah, [mprev]
    mov [mprev], al
    test ah, ah                 ; была нажата...
    jz .nopress
    test al, al                 ; ...а теперь отпущена
    jnz .nopress
    call on_click
    jmp .redraw
.nopress:
    cmp byte [setopen], 1       ; при открытых окнах список не трогаем
    je .redraw
    cmp byte [npopen], 1
    je .redraw
    cmp byte [clopen], 1
    je .redraw
    call row_at_mouse           ; строка под указателем - выбранная
    cmp eax, -1
    je .redraw
    mov [sel], eax
.redraw:
    call draw_screen
    call flip
    call draw_cursor
    jmp .loop
.notmouse:
    in al, 0x60
    cmp al, 0x1D                ; Ctrl нажат
    jne .notctrldown
    mov byte [ctrl], 1
    jmp .loop
.notctrldown:
    cmp al, 0x9D                ; Ctrl отпущен
    jne .notctrlup
    mov byte [ctrl], 0
    jmp .loop
.notctrlup:
    cmp byte [npopen], 1        ; клавиши нужны только блокноту
    jne .loop
    test al, 0x80               ; отпускание клавиши пропускаем
    jnz .loop
    call key_decode
    test al, al
    jz .loop
    call np_key
    call draw_screen
    call flip
    call draw_cursor
    jmp .loop

; Диск: читаем сектор по номеру через порты контроллера.
; Пока только чтение.

DISKPORT equ 0x1F0

; ждём, пока диск освободится
disk_wait:
    push edx
    push ecx
    mov ecx, 0x400000
    mov dx, DISKPORT + 7
.l:
    in al, dx
    test al, 0x80               ; занят
    jz .ok
    dec ecx
    jnz .l
    mov byte [diskerr], 1
.ok:
    pop ecx
    pop edx
    ret

; читаем один сектор: eax - номер, edi - куда положить
read_sector:
    pusha
    mov byte [diskerr], 0
    push eax
    mov dx, DISKPORT + 6        ; старшие биты номера
    shr eax, 24
    and al, 0x0F
    or al, 0xE0
    out dx, al
    pop eax

    push eax                    ; выждать, пока диск примет выбор
    mov dx, DISKPORT + 7        ; читаем в тот же регистр, где номер,
    in al, dx                   ; поэтому номер прячем
    in al, dx
    in al, dx
    in al, dx
    pop eax

    mov dx, DISKPORT + 2        ; один сектор
    push eax
    mov al, 1
    out dx, al
    pop eax

    push eax
    mov dx, DISKPORT + 3        ; номер по байтам
    out dx, al
    pop eax
    push eax
    mov dx, DISKPORT + 4
    shr eax, 8
    out dx, al
    pop eax
    push eax
    mov dx, DISKPORT + 5
    shr eax, 16
    out dx, al
    pop eax

    mov dx, DISKPORT + 7        ; команда: читать
    mov al, 0x20
    out dx, al

    ; ждём, пока диск скажет: данные готовы
    push ecx
    mov ecx, 0x400000
    mov dx, DISKPORT + 7
.ready:
    in al, dx
    test al, 0x80               ; ещё занят
    jnz .again
    test al, 0x01               ; сообщил об ошибке
    jnz .failed
    test al, 0x08               ; данные готовы
    jnz .gotready
    test al, 0x20               ; поломка привода
    jnz .failed
.again:
    dec ecx
    jnz .ready
.failed:
    pop ecx
    mov byte [diskerr], 1
    jmp .done
.gotready:
    pop ecx
.read:
    mov dx, DISKPORT
    mov ecx, 256                ; сектор идёт по два байта
    cld
    rep insw
.done:
    popa
    ret

; пишем один сектор: eax - номер, esi - откуда брать
write_sector:
    pusha
    mov byte [diskerr], 0
    push eax

    mov dx, DISKPORT + 6        ; старшие биты номера
    shr eax, 24
    and al, 0x0F
    or al, 0xE0
    out dx, al
    pop eax

    push eax                    ; выждать, пока диск примет выбор
    mov dx, DISKPORT + 7
    in al, dx
    in al, dx
    in al, dx
    in al, dx
    pop eax

    mov dx, DISKPORT + 2        ; один сектор
    push eax
    mov al, 1
    out dx, al
    pop eax

    push eax                    ; номер по байтам
    mov dx, DISKPORT + 3
    out dx, al
    pop eax
    push eax
    mov dx, DISKPORT + 4
    shr eax, 8
    out dx, al
    pop eax
    push eax
    mov dx, DISKPORT + 5
    shr eax, 16
    out dx, al
    pop eax

    mov dx, DISKPORT + 7        ; команда: писать
    mov al, 0x30
    out dx, al

    push ecx                    ; ждём, пока диск примет данные
    mov ecx, 0x400000
    mov dx, DISKPORT + 7
.ready:
    in al, dx
    test al, 0x80
    jnz .again
    test al, 0x01
    jnz .failed
    test al, 0x08               ; готов принимать
    jnz .gotready
.again:
    dec ecx
    jnz .ready
.failed:
    pop ecx
    mov byte [diskerr], 1
    jmp .done
.gotready:
    pop ecx

    mov dx, DISKPORT            ; отдаём сектор по два байта
    mov ecx, 256
    cld
    rep outsw

    mov dx, DISKPORT + 7        ; просим сбросить на диск
    mov al, 0xE7
    out dx, al
    call disk_wait
.done:
    popa
    ret

; Файлы. Устройство простое: один сектор - оглавление,
; дальше по сектору на файл. Запись в оглавлении 32 байта:
; имя (12), длина (4), номер сектора (4), запас (12).
; Пустая запись - имя начинается с нуля.

DIRSEC   equ 200                ; где лежит оглавление
DATASEC  equ 201                ; отсюда начинаются файлы
MAXFILES equ 16
ENTSZ    equ 32

; читаем оглавление в dirbuf
load_dir:
    pusha
    mov eax, DIRSEC
    mov edi, dirbuf
    call read_sector
    popa
    ret

; сохраняем оглавление обратно
save_dir:
    pusha
    mov eax, DIRSEC
    mov esi, dirbuf
    call write_sector
    popa
    ret

; ищем файл по имени esi, вернёт номер записи в eax или -1
find_file:
    push ebx
    push ecx
    push edx
    xor ebx, ebx
.l:
    cmp ebx, MAXFILES
    jae .none
    mov eax, ebx
    imul eax, ENTSZ
    add eax, dirbuf
    cmp byte [eax], 0           ; пустая запись
    je .next
    ; сравниваем имена
    push esi
    mov edx, eax
    xor ecx, ecx
.cmp:
    mov al, [esi + ecx]
    cmp al, [edx + ecx]
    jne .nomatch
    test al, al
    jz .match
    inc ecx
    cmp ecx, 12
    jb .cmp
.match:
    pop esi
    mov eax, ebx
    jmp .done
.nomatch:
    pop esi
.next:
    inc ebx
    jmp .l
.none:
    mov eax, -1
.done:
    pop edx
    pop ecx
    pop ebx
    ret

; ищем свободную запись, вернёт номер или -1
find_free:
    push ebx
    xor ebx, ebx
.l:
    cmp ebx, MAXFILES
    jae .none
    mov eax, ebx
    imul eax, ENTSZ
    add eax, dirbuf
    cmp byte [eax], 0
    je .found
    inc ebx
    jmp .l
.found:
    mov eax, ebx
    pop ebx
    ret
.none:
    mov eax, -1
    pop ebx
    ret

; Сохраняем файл. esi - имя, edi - откуда брать,
; ecx - сколько байт. Вернёт al=1, если получилось.
save_file:
    pusha
    mov [savelen], ecx
    mov [savesrc], edi
    mov [savename], esi

    call load_dir
    cmp byte [diskerr], 0
    jne .fail

    mov esi, [savename]         ; такой файл уже есть?
    call find_file
    cmp eax, -1
    jne .haveent
    call find_free              ; нет - берём свободную запись
    cmp eax, -1
    je .fail
.haveent:
    mov [saveent], eax

    ; заполняем запись
    imul eax, ENTSZ
    add eax, dirbuf
    mov edi, eax
    mov esi, [savename]
    mov ecx, 12
    cld
.cpname:
    mov al, [esi]
    mov [edi], al
    test al, al
    jz .padname
    inc esi
    inc edi
    dec ecx
    jnz .cpname
    jmp .lenput
.padname:
    mov byte [edi], 0
    inc edi
    dec ecx
    jnz .padname
.lenput:
    mov eax, [saveent]
    imul eax, ENTSZ
    add eax, dirbuf
    mov ecx, [savelen]
    mov [eax + 12], ecx         ; длина
    mov ecx, [saveent]
    add ecx, DATASEC
    mov [eax + 16], ecx         ; свой сектор у каждой записи

    ; сам текст: досыпаем нулями до целого сектора
    mov edi, secbuf
    mov ecx, 512
    xor al, al
    rep stosb
    mov esi, [savesrc]
    mov edi, secbuf
    mov ecx, [savelen]
    cmp ecx, 512
    jbe .cpdata
    mov ecx, 512
.cpdata:
    rep movsb

    mov eax, [saveent]
    add eax, DATASEC
    mov esi, secbuf
    call write_sector
    cmp byte [diskerr], 0
    jne .fail

    call save_dir
    cmp byte [diskerr], 0
    jne .fail
    popa
    mov al, 1
    ret
.fail:
    popa
    xor al, al
    ret

; Читаем файл по имени esi в edi. Вернёт al=1 и длину в ecx.
load_file:
    push esi
    push edi
    call load_dir
    cmp byte [diskerr], 0
    jne .fail
    pop edi
    pop esi
    push esi
    push edi
    call find_file
    cmp eax, -1
    je .fail
    imul eax, ENTSZ
    add eax, dirbuf
    mov ecx, [eax + 12]         ; длина
    mov [loadlen], ecx
    mov eax, [eax + 16]         ; сектор
    pop edi
    push edi
    call read_sector
    cmp byte [diskerr], 0
    jne .fail
    pop edi
    pop esi
    mov ecx, [loadlen]
    mov al, 1
    ret
.fail:
    pop edi
    pop esi
    xor ecx, ecx
    xor al, al
    ret

; Проверка файлов. При запуске не вызываем: она стирает
; оглавление. Позвать fs_test можно вручную.
fs_test:
    pusha
    ; чистим оглавление, чтобы начать с нуля
    mov edi, dirbuf
    mov ecx, 512
    xor al, al
    cld
    rep stosb
    call save_dir

    mov esi, t_fname            ; сохраняем
    mov edi, t_fdata
    mov ecx, 11
    call save_file
    test al, al
    jz .bad

    mov edi, fsbuf              ; читаем обратно
    mov ecx, 512
    xor al, al
    rep stosb
    mov esi, t_fname
    mov edi, fsbuf
    call load_file
    test al, al
    jz .bad
    cmp ecx, 11
    jne .bad
    ; сравниваем
    mov esi, t_fdata
    mov edi, fsbuf
    mov ecx, 11
.cmp:
    mov al, [esi]
    cmp al, [edi]
    jne .bad
    inc esi
    inc edi
    dec ecx
    jnz .cmp
    mov dword [p_fsmsg], t_fsok
    jmp .e
.bad:
    mov dword [p_fsmsg], t_fsbad
.e:
    popa
    ret

; Проверка: читаем нулевой сектор и смотрим признак
; загрузочного - последние два байта 55 AA.
; Проверяем запись: кладём образец в дальний сектор,
; читаем обратно и сравниваем. Сектор 200 - за концом
; нашего кода, там ничего важного нет.
TESTSEC equ 200

disk_wtest:
    pusha
    mov edi, secbuf             ; готовим образец
    mov ecx, 512
    mov al, 'A'
    cld
    rep stosb
    mov dword [secbuf], 0x54534554   ; и метка в начале

    mov eax, TESTSEC
    mov esi, secbuf
    call write_sector
    cmp byte [diskerr], 0
    jne .bad

    mov edi, secbuf             ; стираем, чтобы читать начисто
    mov ecx, 512
    xor al, al
    rep stosb

    mov eax, TESTSEC
    mov edi, secbuf
    call read_sector
    cmp byte [diskerr], 0
    jne .bad
    cmp dword [secbuf], 0x54534554
    jne .bad
    cmp byte [secbuf + 511], 'A'
    jne .bad
    mov dword [p_wrmsg], t_wrok
    jmp .e
.bad:
    mov dword [p_wrmsg], t_wrbad
.e:
    popa
    ret

; Проверку записи при запуске не делаем: она портит
; сектор. Вызвать disk_wtest можно вручную, когда надо.

disk_check:
    pusha
    xor eax, eax
    mov edi, secbuf
    call read_sector
    cmp byte [diskerr], 0
    jne .bad
    cmp byte [secbuf + 510], 0x55
    jne .bad
    cmp byte [secbuf + 511], 0xAA
    jne .bad
    mov dword [p_diskmsg], t_diskok
    jmp .e
.bad:
    mov dword [p_diskmsg], t_diskbad
.e:
    popa
    ret

; Окно со списком программ

ITEMS   equ 5                   ; строк в списке: настройки ушли наверх
ROWH    equ 18                  ; высота строки
WINX    equ 40                  ; окно списка
WINY    equ 47
WINW    equ 240
WINH    equ 122
LISTX   equ WINX + 4            ; поле внутри корпуса, с отступом
LISTY   equ WINY + 20
LISTW   equ WINW - 8
LISTH   equ ITEMS*ROWH + 8

SETX    equ 4                   ; кнопка настроек вверху слева
SETY    equ 4
SETW    equ 18                  ; квадратная: внутри знак, а не слово
SETH    equ 18

draw_screen:
    ; фон
    mov dword [rx], 0
    mov dword [ry], 0
    mov dword [rw], W
    mov dword [rh], H
    mov byte [rc], 3            ; тёмно-бирюзовый
    call rect

    ; кнопка настроек вверху
    mov dword [rx], SETX
    mov dword [ry], SETY
    mov dword [rw], SETW
    mov dword [rh], SETH
    mov byte [rc], 0
    call rect
    mov dword [rx], SETX + 1
    mov dword [ry], SETY + 1
    mov dword [rw], SETW - 2
    mov dword [rh], SETH - 2
    mov byte [rc], 7
    call rect

    ; объём; пока держат - грани местами
    mov dword [bx0], SETX + 1
    mov dword [by0], SETY + 1
    mov dword [bwid],  SETW - 2
    mov dword [bhgt],  SETH - 2
    mov byte [blight], 15
    mov byte [bdark], 8
    cmp byte [setdown], 1
    jne .setup
    mov byte [blight], 8
    mov byte [bdark], 15
.setup:
    call bevel
    ; знак настроек: одна черта, точками а не буквой
    mov dword [rx], SETX + 4
    mov dword [ry], SETY + 8
    mov dword [rw], 10
    mov dword [rh], 2
    mov byte [rc], 0
    call rect

    ; корпус окна
    mov dword [rx], WINX
    mov dword [ry], WINY
    mov dword [rw], WINW
    mov dword [rh], WINH
    mov byte [rc], 0
    call rect
    mov dword [rx], WINX + 1
    mov dword [ry], WINY + 1
    mov dword [rw], WINW - 2
    mov dword [rh], WINH - 2
    mov byte [rc], 7
    call rect

    ; полоса заголовка
    mov dword [rx], WINX + 1
    mov dword [ry], WINY + 1
    mov dword [rw], WINW - 2
    mov dword [rh], 16
    mov al, [titlecol]          ; цвет выбран в настройках
    mov [rc], al
    call rect
    mov esi, t_title
    mov ecx, WINX + 56
    mov edx, WINY + 1
    mov al, 15
    call text_at

    ; поле под список, вдавленное
    mov dword [rx], LISTX
    mov dword [ry], LISTY
    mov dword [rw], LISTW
    mov dword [rh], LISTH
    mov byte [rc], 15
    call rect

    call draw_list
    call draw_settings          ; настройки рисуем поверх всего
    call draw_notepad
    call draw_calc
    ret

draw_list:
    ; сами строки
    xor ebx, ebx
.line:
    cmp ebx, ITEMS
    jae .done
    mov eax, ebx
    imul eax, ROWH
    add eax, LISTY + 4

    cmp ebx, [sel]              ; выбранная - на синей полосе
    jne .plain
    push eax
    mov [ry], eax
    mov dword [rx], LISTX + 2
    mov dword [rw], LISTW - 4
    mov dword [rh], 16
    mov al, [titlecol]          ; цвет выбран в настройках
    mov [rc], al
    call rect
    pop eax
    mov byte [rowcol], 15       ; буквы белые
    jmp .text
.plain:
    mov byte [rowcol], 0        ; буквы чёрные
.text:
    ; цвет держим отдельно от высоты строки
    push ebx
    push eax
    mov edx, eax
    mov esi, [items + ebx*4]
    mov ecx, LISTX + 8
    mov al, [rowcol]
    call text_at
    pop eax
    pop ebx
    inc ebx
    jmp .line
.done:
    ret

; Объём: светлая грань с одной стороны, тёмная с другой

bevel:
    pusha
    mov eax, [bx0]              ; верхняя грань
    mov [rx], eax
    mov eax, [by0]
    mov [ry], eax
    mov eax, [bwid]
    mov [rw], eax
    mov dword [rh], 1
    mov al, [blight]
    mov [rc], al
    call rect

    mov eax, [bx0]              ; левая
    mov [rx], eax
    mov eax, [by0]
    mov [ry], eax
    mov dword [rw], 1
    mov eax, [bhgt]
    mov [rh], eax
    mov al, [blight]
    mov [rc], al
    call rect

    mov eax, [bx0]              ; нижняя
    mov [rx], eax
    mov eax, [by0]
    add eax, [bhgt]
    dec eax
    mov [ry], eax
    mov eax, [bwid]
    mov [rw], eax
    mov dword [rh], 1
    mov al, [bdark]
    mov [rc], al
    call rect

    mov eax, [bx0]              ; правая
    add eax, [bwid]
    dec eax
    mov [rx], eax
    mov eax, [by0]
    mov [ry], eax
    mov dword [rw], 1
    mov eax, [bhgt]
    mov [rh], eax
    mov al, [bdark]
    mov [rc], al
    call rect
    popa
    ret

; окошко настроек: небольшое, посередине экрана
SWCX    equ 10                  ; полоса выбора цвета
SWCY    equ 40
SWCW    equ 8
SWCH    equ 14
; Место окна - в памяти
SWW     equ 160
SWH     equ 96

draw_settings:
    cmp byte [setopen], 1
    jne .e
    mov eax, [swx]
    mov [rx], eax
    mov eax, [swy]
    mov [ry], eax
    mov dword [rw], SWW
    mov dword [rh], SWH
    mov byte [rc], 0
    call rect
    mov eax, [swx]
    add eax, 1
    mov [rx], eax
    mov eax, [swy]
    add eax, 1
    mov [ry], eax
    mov dword [rw], SWW - 2
    mov dword [rh], SWH - 2
    mov byte [rc], 7
    call rect
    mov eax, [swx]
    add eax, 1
    mov [rx], eax     ; полоса заголовка
    mov eax, [swy]
    add eax, 1
    mov [ry], eax
    mov dword [rw], SWW - 2
    mov dword [rh], 16
    mov al, [titlecol]          ; цвет выбран в настройках
    mov [rc], al
    call rect
    mov esi, t_setwin
    mov ecx, [swx]
    add ecx, 40
    mov edx, [swy]
    inc edx
    mov al, 15
    call text_at

    mov eax, [swx]
    add eax, 6
    mov [rx], eax     ; кнопка закрытия
    mov eax, [swy]
    add eax, 4
    mov [ry], eax
    mov dword [rw], 10
    mov dword [rh], 10
    mov byte [rc], 15
    call rect
    ; и ей объём, как кнопке настроек
    mov eax, [swx]
    add eax, 6
    mov [bx0], eax
    mov eax, [swy]
    add eax, 4
    mov [by0], eax
    mov dword [bwid], 10
    mov dword [bhgt], 10
    mov byte [blight], 15
    mov byte [bdark], 8
    cmp byte [xdown], 1
    jne .xup
    mov byte [blight], 8        ; нажат - грани местами
    mov byte [bdark], 15
.xup:
    call bevel
    ; Сам крестик - две диагонали по шесть точек.
    ; Буквой не рисуем: она выше квадрата и торчит.
    xor ecx, ecx
.xdiag:
    push ecx
    mov eax, [swx]              ; из левого верхнего угла
    add eax, 8
    add eax, ecx
    mov [rx], eax
    mov eax, [swy]
    add eax, 6
    add eax, ecx
    mov [ry], eax
    mov dword [rw], 1
    mov dword [rh], 1
    mov byte [rc], 0
    call rect
    pop ecx
    push ecx
    mov eax, [swx]              ; и из левого нижнего
    add eax, 8
    add eax, ecx
    mov [rx], eax
    mov eax, [swy]
    add eax, 11
    sub eax, ecx
    mov [ry], eax
    mov dword [rw], 1
    mov dword [rh], 1
    mov byte [rc], 0
    call rect
    pop ecx
    inc ecx
    cmp ecx, 6
    jb .xdiag

    mov esi, t_setcol           ; подпись над выбором
    mov ecx, [swx]
    add ecx, 12
    mov edx, [swy]
    add edx, 22
    xor al, al
    call text_at

    ; шестнадцать образцов: щёлкаешь - меняется цвет
    ; заголовков у всех окон
    xor ebx, ebx
.colors:
    cmp ebx, 16
    jae .colsdone
    push ebx
    mov eax, ebx
    imul eax, SWCW
    add eax, [swx]
    add eax, SWCX
    mov [rx], eax
    mov eax, [swy]
    add eax, SWCY
    mov [ry], eax
    mov dword [rw], SWCW
    mov dword [rh], SWCH
    pop ebx
    push ebx
    mov [rc], bl
    call rect
    pop ebx
    inc ebx
    jmp .colors
.colsdone:
    ; чёрточка под выбранным
    movzx eax, byte [titlecol]
    imul eax, SWCW
    add eax, [swx]
    add eax, SWCX
    mov [rx], eax
    mov eax, [swy]
    add eax, SWCY + SWCH + 1
    mov [ry], eax
    mov dword [rw], SWCW
    mov dword [rh], 2
    mov byte [rc], 0
    call rect

.e:
    ret

; указатель над кнопкой настроек? вернёт al=1
over_setbtn:
    mov eax, [mx]
    cmp eax, SETX
    jb .no
    cmp eax, SETX + SETW
    ja .no
    mov eax, [my]
    cmp eax, SETY
    jb .no
    cmp eax, SETY + SETH
    ja .no
    mov al, 1
    ret
.no:
    xor al, al
    ret

; указатель над заголовком калькулятора, но не на крестике?
over_cltitle:
    cmp byte [clopen], 1
    jne .no
    mov eax, [my]
    sub eax, [cly]
    cmp eax, 1
    jb .no
    cmp eax, 17
    ja .no
    mov eax, [mx]
    sub eax, [clx]
    cmp eax, 18                 ; левее - там крестик
    jb .no
    cmp eax, CLW
    ja .no
    mov al, 1
    ret
.no:
    xor al, al
    ret

; номер кнопки калькулятора под указателем, или -1
calc_btn_at:
    push ebx
    xor ebx, ebx
.l:
    cmp ebx, 16
    jae .none
    push ebx
    call calc_btn_pos
    pop ebx
    mov eax, [mx]
    cmp eax, [rx]
    jb .next
    push eax
    mov eax, [rx]
    add eax, CLBW
    cmp [esp], eax
    pop eax
    ja .next
    mov eax, [my]
    cmp eax, [ry]
    jb .next
    push eax
    mov eax, [ry]
    add eax, CLBH
    cmp [esp], eax
    pop eax
    ja .next
    mov eax, ebx
    pop ebx
    ret
.next:
    inc ebx
    jmp .l
.none:
    pop ebx
    mov eax, -1
    ret

; нажали кнопку номер eax
calc_press:
    push eax
    movzx eax, byte [eax + calclabels]
    cmp al, 'C'                 ; очистка
    je .clear
    cmp al, '='
    je .equals
    ; прочее дописываем в поле
    mov ecx, 0
.findend:
    cmp byte [clbuf + ecx], 0
    je .put
    inc ecx
    cmp ecx, 18
    jb .findend
    jmp .done
.put:
    mov [clbuf + ecx], al
    mov byte [clbuf + ecx + 1], 0
    jmp .done
.clear:
    mov byte [clbuf], 0
    jmp .done
.equals:
    call calc_eval
.done:
    pop eax
    ret

; Считаем набранное: число, знак, число
calc_eval:
    pusha
    mov esi, clbuf
    call read_num               ; первое число
    mov [clacc], eax
    mov al, [esi]               ; знак
    test al, al
    jz .show                    ; знака нет - показываем как есть
    mov [clop], al
    inc esi
    call read_num               ; второе число
    mov ebx, eax
    mov eax, [clacc]
    mov cl, [clop]
    cmp cl, '+'
    je .add
    cmp cl, '-'
    je .sub
    cmp cl, '*'
    je .mul
    cmp cl, '/'
    je .div
    jmp .show
.add:
    add eax, ebx
    jmp .save
.sub:
    sub eax, ebx
    jmp .save
.mul:
    imul eax, ebx
    jmp .save
.div:
    test ebx, ebx
    jz .show                    ; на ноль не делим
    xor edx, edx
    div ebx
.save:
    mov [clacc], eax
.show:
    mov eax, [clacc]
    call num_to_buf
    popa
    ret

; читаем число из строки esi, ответ в eax
read_num:
    push ebx
    push ecx
    xor eax, eax
    xor ecx, ecx
.l:
    mov cl, [esi]
    cmp cl, '0'
    jb .done
    cmp cl, '9'
    ja .done
    imul eax, 10
    sub cl, '0'
    add eax, ecx
    inc esi
    jmp .l
.done:
    pop ecx
    pop ebx
    ret

; записываем число eax в поле как текст
num_to_buf:
    pusha
    mov edi, clbuf
    test eax, eax
    jns .pos
    mov byte [edi], '-'         ; отрицательное
    inc edi
    neg eax
.pos:
    ; цифры выходят задом наперёд - разворачиваем
    mov ebx, 10
    xor ecx, ecx
.digits:
    xor edx, edx
    div ebx
    add dl, '0'
    push edx
    inc ecx
    test eax, eax
    jnz .digits
.write:
    pop edx
    mov [edi], dl
    inc edi
    dec ecx
    jnz .write
    mov byte [edi], 0
    popa
    ret

; указатель над крестиком калькулятора? вернёт al=1
over_clclose:
    cmp byte [clopen], 1
    jne .no
    mov eax, [mx]
    sub eax, [clx]
    cmp eax, 6
    jb .no
    cmp eax, 16
    ja .no
    mov eax, [my]
    sub eax, [cly]
    cmp eax, 4
    jb .no
    cmp eax, 14
    ja .no
    mov al, 1
    ret
.no:
    xor al, al
    ret

; указатель над заголовком настроек, но не на крестике?
over_swtitle:
    cmp byte [setopen], 1
    jne .no
    mov eax, [my]
    sub eax, [swy]
    cmp eax, 1
    jb .no
    cmp eax, 17
    ja .no
    mov eax, [mx]
    sub eax, [swx]
    cmp eax, 18                 ; левее - там крестик
    jb .no
    cmp eax, SWW
    ja .no
    mov al, 1
    ret
.no:
    xor al, al
    ret

; указатель над заголовком блокнота, но не на крестике?
over_nptitle:
    cmp byte [npopen], 1
    jne .no
    mov eax, [my]
    sub eax, [npy]
    cmp eax, 1
    jb .no
    cmp eax, 17
    ja .no
    mov eax, [mx]
    sub eax, [npx]
    cmp eax, 18                 ; левее - там крестик
    jb .no
    cmp eax, NPW0
    ja .no
    mov al, 1
    ret
.no:
    xor al, al
    ret

; указатель над крестиком блокнота? вернёт al=1
over_npclose:
    cmp byte [npopen], 1
    jne .no
    mov eax, [mx]
    sub eax, [npx]              ; переводим в место внутри окна
    cmp eax, 6
    jb .no
    cmp eax, 16
    ja .no
    mov eax, [my]
    sub eax, [npy]
    cmp eax, 4
    jb .no
    cmp eax, 14
    ja .no
    mov al, 1
    ret
.no:
    xor al, al
    ret

; указатель над крестиком настроек? вернёт al=1
over_closebtn:
    cmp byte [setopen], 1       ; окошка нет - и крестика нет
    jne .no
    mov eax, [mx]
    sub eax, [swx]              ; переводим в место внутри окна
    cmp eax, 6
    jb .no
    cmp eax, 16
    ja .no
    mov eax, [my]
    sub eax, [swy]
    cmp eax, 4
    jb .no
    cmp eax, 14
    ja .no
    mov al, 1
    ret
.no:
    xor al, al
    ret

; что делать по нажатию кнопки
on_click:
    cmp byte [clopen], 1        ; калькулятор поверх всего
    jne .notcl
    call over_clclose
    test al, al
    jz .clbtns
    mov byte [clopen], 0
    ret
.clbtns:
    call calc_btn_at            ; номер кнопки под указателем
    cmp eax, -1
    je .no
    call calc_press
    ret
.notcl:
    cmp byte [npopen], 1        ; блокнот открыт - только его крестик
    jne .notnp
    call over_npclose
    test al, al
    jz .no
    mov byte [npopen], 0
    ret
.notnp:
    cmp byte [setopen], 1
    je .inset

    ; щелчок по строке списка
    call row_at_mouse
    cmp eax, -1
    je .notlist
    cmp eax, 0                  ; первая строка - блокнот
    jne .notnote
    mov byte [npopen], 1
    call np_load                ; читаем сохранённое
    ret
.notnote:
    cmp eax, 4                  ; пятая - калькулятор
    jne .no
    mov byte [clopen], 1
    ret
.notlist:

    ; кнопка настроек вверху
    mov eax, [mx]
    cmp eax, SETX
    jb .no
    cmp eax, SETX + SETW
    ja .no
    mov eax, [my]
    cmp eax, SETY
    jb .no
    cmp eax, SETY + SETH
    ja .no
    mov byte [setopen], 1
    ret
.inset:
    ; щелчок по образцу цвета
    mov eax, [my]
    sub eax, [swy]
    cmp eax, SWCY
    jb .notcolor
    cmp eax, SWCY + SWCH
    ja .notcolor
    mov eax, [mx]
    sub eax, [swx]
    sub eax, SWCX
    js .notcolor
    xor edx, edx
    mov ecx, SWCW
    div ecx
    cmp eax, 16
    jae .notcolor
    mov [titlecol], al
    call cfg_save               ; запоминаем выбор на диске
    ret
.notcolor:
    ; крестик в окошке настроек
    mov eax, [mx]
    sub eax, [swx]              ; переводим в место внутри окна
    cmp eax, 6
    jb .no
    cmp eax, 16
    ja .no
    mov eax, [my]
    sub eax, [swy]
    cmp eax, 4
    jb .no
    cmp eax, 14
    ja .no
    mov byte [setopen], 0
.no:
    ret

; Клавиатура: клавиша шлёт номер, буква берётся из таблицы

key_decode:                     ; al - номер клавиши, вернёт букву в al
    movzx eax, al
    cmp eax, 58
    jae .none
    movzx eax, byte [keymap + eax]
    ret
.none:
    xor al, al
    ret

keymap:
    db 0,27,49,50,51,52,53,54,55,56,57,48
    db 45,61,8,9,113,119,101,114,116,121,117,105
    db 111,112,91,93,13,0,97,115,100,102,103,104
    db 106,107,108,59,39,96,0,0,122,120,99,118
    db 98,110,109,44,46,47,0,0,0,32

; окно калькулятора
CLW     equ 156
CLH     equ 156
CLBW    equ 34                  ; кнопка
CLBH    equ 22
CLGAP   equ 4

draw_calc:
    cmp byte [clopen], 1
    jne .e
    mov eax, [clx]
    mov [rx], eax
    mov eax, [cly]
    mov [ry], eax
    mov dword [rw], CLW
    mov dword [rh], CLH
    mov byte [rc], 0
    call rect
    mov eax, [clx]
    inc eax
    mov [rx], eax
    mov eax, [cly]
    inc eax
    mov [ry], eax
    mov dword [rw], CLW - 2
    mov dword [rh], CLH - 2
    mov byte [rc], 7
    call rect

    mov eax, [clx]              ; полоса заголовка
    inc eax
    mov [rx], eax
    mov eax, [cly]
    inc eax
    mov [ry], eax
    mov dword [rw], CLW - 2
    mov dword [rh], 16
    mov al, [titlecol]          ; цвет выбран в настройках
    mov [rc], al
    call rect
    mov esi, t_clwin
    mov ecx, [clx]
    add ecx, 40
    mov edx, [cly]
    inc edx
    mov al, 15
    call text_at

    mov eax, [clx]              ; крестик
    add eax, 6
    mov [rx], eax
    mov eax, [cly]
    add eax, 4
    mov [ry], eax
    mov dword [rw], 10
    mov dword [rh], 10
    mov byte [rc], 15
    call rect
    mov eax, [clx]
    add eax, 6
    mov [bx0], eax
    mov eax, [cly]
    add eax, 4
    mov [by0], eax
    mov dword [bwid], 10
    mov dword [bhgt], 10
    mov byte [blight], 15
    mov byte [bdark], 8
    cmp byte [clxdown], 1
    jne .xup
    mov byte [blight], 8
    mov byte [bdark], 15
.xup:
    call bevel
    xor ecx, ecx
.xdiag:
    push ecx
    mov eax, [clx]
    add eax, 8
    add eax, ecx
    mov [rx], eax
    mov eax, [cly]
    add eax, 6
    add eax, ecx
    mov [ry], eax
    mov dword [rw], 1
    mov dword [rh], 1
    mov byte [rc], 0
    call rect
    pop ecx
    push ecx
    mov eax, [clx]
    add eax, 8
    add eax, ecx
    mov [rx], eax
    mov eax, [cly]
    add eax, 11
    sub eax, ecx
    mov [ry], eax
    mov dword [rw], 1
    mov dword [rh], 1
    mov byte [rc], 0
    call rect
    pop ecx
    inc ecx
    cmp ecx, 6
    jb .xdiag

    ; поле, где видно набранное
    mov eax, [clx]
    add eax, CLGAP
    mov [rx], eax
    mov eax, [cly]
    add eax, 22
    mov [ry], eax
    mov dword [rw], CLW - 2*CLGAP
    mov dword [rh], 22
    mov byte [rc], 15
    call rect
    mov esi, clbuf
    mov ecx, [clx]
    add ecx, CLGAP + 4
    mov edx, [cly]
    add edx, 25
    xor al, al
    call text_at

    ; кнопки
    xor ebx, ebx
.btn:
    cmp ebx, 16
    jae .done
    push ebx
    call calc_btn_pos           ; углы кнопки в rx, ry
    mov dword [rw], CLBW
    mov dword [rh], CLBH
    mov byte [rc], 7
    call rect
    mov eax, [rx]
    mov [bx0], eax
    mov eax, [ry]
    mov [by0], eax
    mov dword [bwid], CLBW
    mov dword [bhgt], CLBH
    mov byte [blight], 15
    mov byte [bdark], 8
    pop ebx
    push ebx
    movzx eax, byte [cldown]    ; нажатая - вдавлена
    cmp eax, 255
    je .noheld
    cmp eax, ebx
    jne .noheld
    mov byte [blight], 8
    mov byte [bdark], 15
.noheld:
    call bevel

    ; подпись; углы считаем заново - объём их затёр
    pop ebx
    push ebx
    call calc_btn_pos
    pop ebx
    push ebx
    movzx eax, byte [ebx + calclabels]
    mov [clchar], al
    mov byte [clchar+1], 0
    mov esi, clchar
    mov ecx, [rx]
    add ecx, 13
    mov edx, [ry]
    add edx, 3
    xor al, al
    call text_at
    pop ebx
    inc ebx
    jmp .btn
.done:
.e:
    ret

; углы кнопки номер ebx: ответ в rx и ry
calc_btn_pos:
    push eax
    push edx
    mov eax, ebx
    and eax, 3                  ; столбец
    imul eax, CLBW + CLGAP
    add eax, [clx]
    add eax, CLGAP
    mov [rx], eax
    mov eax, ebx
    shr eax, 2                  ; ряд
    imul eax, CLBH + CLGAP
    add eax, [cly]
    add eax, 48
    mov [ry], eax
    pop edx
    pop eax
    ret

; окно блокнота
; Место окна - в памяти, чтобы можно было двигать
NPW0    equ 260                 ; размеры остаются постоянными
NPW     equ 260
NPH     equ 130
NPROWS  equ 6                   ; строк в поле
NPCOLS  equ 30                  ; знаков в строке
NPSTR   equ 32                  ; байт на строку в памяти

draw_notepad:
    cmp byte [npopen], 1
    jne .e
    mov eax, [npx]
    mov [rx], eax
    mov eax, [npy]
    mov [ry], eax
    mov dword [rw], NPW
    mov dword [rh], NPH
    mov byte [rc], 0
    call rect
    mov eax, [npx]
    add eax, 1
    mov [rx], eax
    mov eax, [npy]
    add eax, 1
    mov [ry], eax
    mov dword [rw], NPW - 2
    mov dword [rh], NPH - 2
    mov byte [rc], 7
    call rect

    mov eax, [npx]
    add eax, 1
    mov [rx], eax     ; полоса заголовка
    mov eax, [npy]
    add eax, 1
    mov [ry], eax
    mov dword [rw], NPW - 2
    mov dword [rh], 16
    mov al, [titlecol]          ; цвет выбран в настройках
    mov [rc], al
    call rect
    mov esi, t_npwin
    mov ecx, [npx]
    add ecx, 100
    mov edx, [npy]
    inc edx
    mov al, 15
    call text_at

    mov eax, [npx]
    add eax, 6
    mov [rx], eax     ; крестик
    mov eax, [npy]
    add eax, 4
    mov [ry], eax
    mov dword [rw], 10
    mov dword [rh], 10
    mov byte [rc], 15
    call rect
    mov eax, [npx]
    add eax, 6
    mov [bx0], eax
    mov eax, [npy]
    add eax, 4
    mov [by0], eax
    mov dword [bwid], 10
    mov dword [bhgt], 10
    mov byte [blight], 15
    mov byte [bdark], 8
    cmp byte [npxdown], 1
    jne .xup
    mov byte [blight], 8
    mov byte [bdark], 15
.xup:
    call bevel
    xor ecx, ecx
.xdiag:
    push ecx
    mov eax, [npx]
    add eax, 8
    add eax, ecx
    mov [rx], eax
    mov eax, [npy]
    add eax, 6
    add eax, ecx
    mov [ry], eax
    mov dword [rw], 1
    mov dword [rh], 1
    mov byte [rc], 0
    call rect
    pop ecx
    push ecx
    mov eax, [npx]
    add eax, 8
    add eax, ecx
    mov [rx], eax
    mov eax, [npy]
    add eax, 11
    sub eax, ecx
    mov [ry], eax
    mov dword [rw], 1
    mov dword [rh], 1
    mov byte [rc], 0
    call rect
    pop ecx
    inc ecx
    cmp ecx, 6
    jb .xdiag

    ; белый лист
    mov eax, [npx]
    add eax, 6
    mov [rx], eax
    mov eax, [npy]
    add eax, 22
    mov [ry], eax
    mov dword [rw], NPW - 12
    mov dword [rh], NPH - 28
    mov byte [rc], 15
    call rect

    mov esi, [p_npmsg]          ; что с сохранением, справа в полосе
    mov ecx, [npx]
    add ecx, NPW0 - 60
    mov edx, [npy]
    inc edx
    mov al, 15
    call text_at

    ; строки текста
    xor ebx, ebx
    mov edx, [npy]
    add edx, 24
.line:
    cmp ebx, NPROWS
    jae .done
    push ebx
    push edx
    mov esi, ebx
    imul esi, NPSTR
    add esi, npbuf
    mov ecx, [npx]
    add ecx, 10
    xor al, al
    call text_at
    pop edx
    pop ebx
    add edx, 16
    inc ebx
    jmp .line
.done:
    ; палочка ввода на месте набора
    mov eax, [nprow]
    imul eax, 16
    add eax, [npy]
    add eax, 24 + 14
    mov [ry], eax
    mov eax, [npcol]
    imul eax, 8
    add eax, [npx]
    add eax, 10
    mov [rx], eax
    mov dword [rw], 7
    mov dword [rh], 2
    mov byte [rc], 0
    call rect
.e:
    ret

; Собираем текст блокнота в одну строку: строки идут
; подряд, разделённые переносом.
np_flatten:
    pusha
    mov edi, npflat
    xor ebx, ebx
.line:
    cmp ebx, NPROWS
    jae .done
    mov esi, ebx
    imul esi, NPSTR
    add esi, npbuf
    xor ecx, ecx
.ch:
    mov al, [esi + ecx]
    test al, al
    jz .eol
    mov [edi], al
    inc edi
    inc ecx
    cmp ecx, NPCOLS
    jb .ch
.eol:
    mov byte [edi], 10          ; перенос строки
    inc edi
    inc ebx
    jmp .line
.done:
    mov byte [edi], 0
    mov eax, edi
    sub eax, npflat
    mov [npflatlen], eax
    popa
    ret

; Раскладываем прочитанный текст обратно по строкам.
np_unflatten:                   ; ecx - сколько байт
    pusha
    mov [npflatlen], ecx
    mov edi, npbuf              ; чистим поле
    mov ecx, NPROWS*NPSTR
    xor al, al
    cld
    rep stosb

    mov esi, npflat
    xor ebx, ebx                ; строка
    xor edx, edx                ; столбец
    mov ecx, [npflatlen]
.ch:
    test ecx, ecx
    jz .done
    mov al, [esi]
    inc esi
    dec ecx
    cmp al, 10                  ; перенос
    je .nl
    cmp al, 32
    jb .ch                      ; прочее лишнее пропускаем
    cmp edx, NPCOLS
    jae .ch
    push edi
    mov edi, ebx
    imul edi, NPSTR
    add edi, npbuf
    add edi, edx
    mov [edi], al
    pop edi
    inc edx
    jmp .ch
.nl:
    inc ebx
    xor edx, edx
    cmp ebx, NPROWS
    jb .ch
.done:
    mov dword [nprow], 0
    mov dword [npcol], 0
    popa
    ret

; сохранить текст блокнота на диск
np_save:
    pusha
    call np_flatten
    mov esi, t_npfile
    mov edi, npflat
    mov ecx, [npflatlen]
    call save_file
    test al, al
    jz .bad
    mov dword [p_npmsg], t_npsaved
    jmp .e
.bad:
    mov dword [p_npmsg], t_npfail
.e:
    popa
    ret

; прочитать текст блокнота с диска
np_load:
    pusha
    mov esi, t_npfile
    mov edi, npflat
    call load_file
    test al, al
    jz .e                       ; файла нет - остаёмся с пустым
    call np_unflatten
    mov dword [p_npmsg], t_nploaded
.e:
    popa
    ret

; Настройки храним отдельным файлом: один байт с цветом.
cfg_save:
    pusha
    mov al, [titlecol]
    mov [cfgbuf], al
    mov esi, t_cfgfile
    mov edi, cfgbuf
    mov ecx, 1
    call save_file
    popa
    ret

cfg_load:
    pusha
    mov esi, t_cfgfile
    mov edi, cfgbuf
    call load_file
    test al, al
    jz .e                       ; файла нет - остаётся синий
    mov al, [cfgbuf]
    cmp al, 16
    jae .e                      ; на всякий случай
    mov [titlecol], al
.e:
    popa
    ret

; буква в блокнот
np_key:                         ; al - знак
    cmp byte [ctrl], 1          ; Ctrl+S - сохранить
    jne .noctrl
    cmp al, 's'
    je .save
    cmp al, 'S'
    je .save
    ret
.save:
    call np_save
    ret
.noctrl:
    cmp al, 13                  ; перенос строки
    je .enter
    cmp al, 8                   ; стирание
    je .back
    cmp al, 32                  ; всё, что не печатается, пропускаем
    jb .e

    mov ecx, [npcol]
    cmp ecx, NPCOLS
    jae .e                      ; строка полна
    mov edi, [nprow]
    imul edi, NPSTR
    add edi, npbuf
    add edi, ecx
    mov [edi], al
    inc dword [npcol]
    ret
.enter:
    mov eax, [nprow]
    inc eax
    cmp eax, NPROWS
    jae .e                      ; ниже не уходим
    mov [nprow], eax
    mov dword [npcol], 0
    ret
.back:
    cmp dword [npcol], 0
    je .e
    dec dword [npcol]
    mov ecx, [npcol]
    mov edi, [nprow]
    imul edi, NPSTR
    add edi, npbuf
    add edi, ecx
    mov byte [edi], 0
.e:
    ret

; какая строка под указателем: вернёт номер в eax,
; или -1, если указатель не над списком
row_at_mouse:
    mov eax, [my]
    sub eax, LISTY + 4
    js .none
    xor edx, edx
    mov ecx, ROWH
    div ecx
    cmp eax, ITEMS
    jae .none
    push eax
    mov eax, [mx]
    cmp eax, LISTX
    jb .nonepop
    cmp eax, LISTX + LISTW
    ja .nonepop
    pop eax
    ret
.nonepop:
    pop eax
.none:
    mov eax, -1
    ret

;  МЫШЬ
;  Разговариваем с ней через тот же ввод, что и с
;  клавиатурой: команды уходят через 0x64, ответы
;  забираем из 0x60.

; ждём, пока примут команду
kwait_write:
    in al, 0x64
    test al, 2
    jnz kwait_write
    ret

; ждём, пока появится ответ
kwait_read:
    push ecx
    mov ecx, 0x200000
.l:
    in al, 0x64
    test al, 1
    jnz .ok
    dec ecx
    jnz .l
.ok:
    pop ecx
    ret

; забрать один байт от мыши
msbyte:
    call kwait_read
    in al, 0x60
    ret

mouse_init:
    pusha
    call kwait_write
    mov al, 0xA8                ; включить второй ввод
    out 0x64, al

    call kwait_write            ; прочитать настройки
    mov al, 0x20
    out 0x64, al
    call kwait_read
    in al, 0x60
    or al, 2                    ; разрешить весточки от мыши
    and al, 0xDF
    mov bl, al
    call kwait_write
    mov al, 0x60                ; записать настройки обратно
    out 0x64, al
    call kwait_write
    mov al, bl
    out 0x60, al

    call kwait_write            ; вернуть мышь к умолчаниям
    mov al, 0xD4
    out 0x64, al
    call kwait_write
    mov al, 0xF6
    out 0x60, al
    call msbyte

    call kwait_write            ; и разрешить ей говорить
    mov al, 0xD4
    out 0x64, al
    call kwait_write
    mov al, 0xF4
    out 0x60, al
    call msbyte
    popa
    ret

; разобрать пакет: три байта - кнопки и два сдвига
read_packet:
    pusha
    call msbyte
    test al, 8                  ; признак настоящего пакета
    jz .done
    and al, 1
    mov [mbtn], al

    call msbyte                 ; сдвиг по горизонтали
    movsx eax, al
    add eax, [mx]
    cmp eax, 0
    jge .x1
    xor eax, eax
.x1:
    cmp eax, W-1
    jle .x2
    mov eax, W-1
.x2:
    mov [mx], eax

    call msbyte                 ; по вертикали, он перевёрнут
    movsx eax, al
    neg eax
    add eax, [my]
    cmp eax, 0
    jge .y1
    xor eax, eax
.y1:
    cmp eax, H-1
    jle .y2
    mov eax, H-1
.y2:
    mov [my], eax
.done:
    popa
    ret

; указатель рисуем прямо на экран, поверх готового кадра
draw_cursor:
    pusha
    mov esi, cursor
    xor ecx, ecx                ; строка картинки
.row:
    xor edx, edx                ; колонка
.col:
    movzx ebx, byte [esi]
    inc esi
    test ebx, ebx
    jz .skip                    ; прозрачная точка
    ; точку рисуем, только если она внутри экрана
    mov eax, [mx]
    add eax, edx
    cmp eax, W
    jae .skip                   ; вылезли вправо
    push eax
    mov eax, [my]
    add eax, ecx
    cmp eax, H
    jae .skippop                ; вылезли вниз
    imul eax, W
    pop edi
    add eax, edi
    add eax, VGAMEM
    mov [eax], bl
    jmp .skip
.skippop:
    pop eax
.skip:
    inc edx
    cmp edx, 8
    jb .col
    inc ecx
    cmp ecx, 12
    jb .row
    popa
    ret

;  РИСОВАНИЕ

; --- закрасить прямоугольник ---
;  Углы и цвет кладём в rx, ry, rw, rh, rc -
;  так не приходится жонглировать регистрами.
rect:
    ; обрезаем то, что вылезло за края экрана
    pusha
    mov eax, [rx]               ; левый край
    mov ebx, [rw]
    mov ecx, [ry]               ; верхний
    mov edx, [rh]

    ; ушли влево - подрезаем начало
    cmp eax, 0
    jge .xok
    add ebx, eax                ; ширина уменьшается
    xor eax, eax
.xok:
    cmp eax, W
    jge .none                   ; целиком за правым краем
    ; ушли вправо - подрезаем конец
    push eax
    add eax, ebx
    cmp eax, W
    jle .xok2
    mov ebx, W
    sub ebx, [esp]
.xok2:
    pop eax

    ; то же по высоте
    cmp ecx, 0
    jge .yok
    add edx, ecx
    xor ecx, ecx
.yok:
    cmp ecx, H
    jge .none
    push ecx
    add ecx, edx
    cmp ecx, H
    jle .yok2
    mov edx, H
    sub edx, [esp]
.yok2:
    pop ecx

    cmp ebx, 0                  ; ничего не осталось
    jle .none
    cmp edx, 0
    jle .none

    mov edi, ecx
    imul edi, W
    add edi, eax
    add edi, CANVAS
.row:
    push edx
    push edi
    mov ecx, ebx
    mov al, [rc]
    cld
    rep stosb
    pop edi
    add edi, W
    pop edx
    dec edx
    jnz .row
.none:
.done:
    popa
    ret

; --- одна буква ---
;  esi - её картинка, ecx и edx - место, bl - цвет
draw_char:
    ; каждую точку проверяем на выход за края
    pusha
    mov [chx], ecx              ; где стоит буква
    mov [chy], edx
    mov bl, [charcol]
    xor ecx, ecx                ; строка буквы
.row:
    mov al, [esi+ecx]
    xor edx, edx                ; колонка
.col:
    test al, 0x80               ; старший бит - крайняя левая точка
    jz .skip
    push eax
    mov eax, [chx]              ; куда ляжет эта точка
    add eax, edx
    cmp eax, 0
    jl .nodot
    cmp eax, W
    jge .nodot
    push eax
    mov eax, [chy]
    add eax, ecx
    cmp eax, 0
    jl .nodotpop
    cmp eax, H
    jge .nodotpop
    imul eax, W
    pop edi
    add eax, edi
    add eax, CANVAS
    mov [eax], bl
    jmp .nodot
.nodotpop:
    pop eax
.nodot:
    pop eax
.skip:
    shl al, 1
    inc edx
    cmp edx, 8
    jb .col
    inc ecx
    cmp ecx, 16
    jb .row
    popa
    ret

chx     dd 0                    ; где рисуется нынешняя буква
chy     dd 0

; --- строка ---
;  esi - текст, ecx и edx - место, al - цвет
text_at:
    pusha
    mov [charcol], al
.next:
    movzx eax, byte [esi]
    test eax, eax
    jz .done
    push esi
    push ecx
    push edx
    shl eax, 4                  ; по 16 байт на букву
    add eax, FONT
    mov esi, eax
    call draw_char
    pop edx
    pop ecx
    pop esi
    inc esi
    add ecx, 8
    cmp ecx, W-8
    jb .next
.done:
    popa
    ret

; --- показать готовый кадр ---
flip:
    pusha
    mov esi, CANVAS
    mov edi, VGAMEM
    mov ecx, W*H/4              ; переносим по четыре байта
    cld
    rep movsd
    popa
    ret

;  ШРИФТ
;  Загрузчик уже забрал его у прошивки и положил в
;  младшую память. Нам остаётся перенести повыше,
;  чтобы не мешался.
grab_font:
    pusha
    mov esi, 0x1000
    mov edi, FONT
    mov ecx, 256*16
    cld
    rep movsb
    popa
    ret

;  ДАННЫЕ
rx      dd 0                    ; углы прямоугольника
ry      dd 0
rw      dd 0
rh      dd 0
rc      db 0                    ; и его цвет
charcol db 15                   ; цвет буквы

mx      dd 160                  ; где сейчас указатель
my      dd 100
mbtn    db 0                    ; нажата ли кнопка

; Указатель: 0 - прозрачно, тёмное рисуем серым
cursor:
    db 15,0,0,0,0,0,0,0
    db 15,15,0,0,0,0,0,0
    db 15,8,15,0,0,0,0,0
    db 15,8,8,15,0,0,0,0
    db 15,8,8,8,15,0,0,0
    db 15,8,8,8,8,15,0,0
    db 15,8,8,8,8,8,15,0
    db 15,8,8,8,15,15,15,15
    db 15,8,15,8,15,0,0,0
    db 15,15,0,15,8,15,0,0
    db 15,0,0,15,8,15,0,0
    db 0,0,0,0,15,15,0,0

sel     dd 0                    ; какая строка выбрана
rowcol  db 0                    ; цвет букв нынешней строки

items:
    dd i1, i2, i3, i4, i5
i1 db "Notepad", 0
i2 db "Paint", 0
i3 db "Terminal", 0
i4 db "Files", 0
i5 db "Calculator", 0

diskerr db 0                    ; не прочиталось
secbuf  times 512 db 0          ; сюда кладём сектор
dirbuf  times 512 db 0          ; оглавление
savelen dd 0                    ; для сохранения
savesrc dd 0
savename dd 0
saveent dd 0
loadlen dd 0
fsbuf   times 512 db 0          ; для проверки

clx     dd 90                   ; где стоит калькулятор
cly     dd 25
clopen  db 0                    ; открыт ли он
clxdown db 0                    ; держат ли его крестик
cldown  db 255                  ; какая кнопка нажата, 255 - никакая
clchar  db 0, 0                 ; подпись кнопки, по одному знаку
clbuf   times 20 db 0           ; что набрано
cldrag  db 0                    ; тащим ли калькулятор
cldx    dd 0
cldy    dd 0
clacc   dd 0                    ; итог счёта
clop    db 0                    ; какой знак между числами

calclabels db "789/456*123-0C=+"

swx     dd 80                   ; где стоит окно настроек
swy     dd 60
swdrag  db 0                    ; тащим ли его
swdx    dd 0
swdy    dd 0

ctrl    db 0                    ; зажат ли Ctrl
; Запас на целый сектор: чтение кладёт 512 байт всегда,
; и при меньшем запасе затирало бы соседние данные.
npflat  times 512 db 0          ; текст одной строкой
npflatlen dd 0
p_npmsg dd t_npnone

npx     dd 30                   ; где стоит окно блокнота
npy     dd 40
npdrag  db 0                    ; тащим ли его сейчас
npdx    dd 0                    ; за какое место ухватились
npdy    dd 0

npopen  db 0                    ; открыт ли блокнот
npxdown db 0                    ; держат ли его крестик
nprow   dd 0                    ; где сейчас набираем
npcol   dd 0
npbuf   times NPROWS*NPSTR db 0 ; сам текст

setopen db 0                    ; открыто ли окошко настроек
setdown db 0                    ; и держат ли на ней кнопку
xdown   db 0                    ; держат ли крестик настроек
bx0     dd 0                    ; углы для объёма
by0     dd 0
bwid    dd 0
bhgt    dd 0
blight  db 15                   ; цвет светлой грани
bdark   db 8                    ; и тёмной
mprev   db 0                    ; была ли кнопка нажата в прошлый раз

t_title   db "Programs", 0
t_setbtn  db "Settings", 0
t_setwin  db "Settings", 0
t_close   db "x", 0
titlecol db 1                   ; цвет заголовков, синий по умолчанию
cfgbuf   times 512 db 0         ; запас на целый сектор
t_cfgfile db "config", 0
t_setcol  db "Window color:", 0
p_diskmsg dd t_diskbad
t_diskok  db "Disk: OK", 0
t_diskbad db "Disk: error", 0
p_fsmsg   dd t_fsbad
t_fsok    db "Files: OK", 0
t_fsbad   db "Files: error", 0
t_fname   db "hello.txt", 0
t_fdata   db "Hello disk", 0
p_wrmsg   dd t_wrbad
t_wrok    db "Write: OK", 0
t_wrbad   db "Write: error", 0
t_npwin   db "Notepad", 0
t_clwin   db "Calculator", 0
t_npfile  db "notes.txt", 0
t_npnone  db "", 0
t_npsaved db "saved", 0
t_nploaded db "loaded", 0
t_npfail  db "error", 0

times 65536-($-$$) db 0         ; добиваем до 64 КБ