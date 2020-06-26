                page
                page 60,95
                title CAS - BASICODE cassette interface routines
                .radix 16
                if1
                %out >>>Pass 1...
                else
                %out >>>Pass 2...
                endif

zero            segment at 0
                org 54
int15ofs        label word
                org 56
int15seg        label word
zero            ends

biosdata        segment at 40
                org 67
io_rom_init     label word
                org 71
biosbreak       label byte
                org 6Bh
intflag         label byte
                org 69
io_rom_seg      label word
biosdata        ends

RJNO            = 0
RJMAC           macro no
                jmp short R&NO
R&NO:
                endm

RJ              macro
                RJMAC %RJNO
RJNO            = RJNO+1
                endm

TESTPM          macro label
                test byte ptr cs:portmode,4
                jz label
                endm

                %out >>>  Begin van programma.
code            segment
                assume cs:code,ds:biosdata
                org 80
parms           label byte
                org 100
begin:          jmp entry

oldint15        dd 0

newint15        proc far
                sti
                cmp ah,7
                jb code_ok
                jmp [oldint15]
code_ok:        push ds
                push ax
                mov ax,40
                mov ds,ax
                pop ax
                and biosbreak,7F
                call main
                pop ds
                ret 2
newint15        endp

                %out >>>  Main
main            proc near
                xchg ah,al
                xor ah,ah
                push si
                mov si,ax
                shl si,1
                call cs:dispatch[si]
                pop si
                ret
main            endp

dispatch        dw motor_on,motor_off,read_ibm,write_ibm,read_bc,write_bc
                dw set_mask

                %out >>>  Motor_on
motor_on        proc near
                TESTPM mn1
                call testpr
                jnc mn2
                ret
mn2:            push dx
                mov dx,cs:port0
                add dx,2
                in al,dx
                RJ
                and al,0F7
                out dx,al
                pop dx
                ret
mn1:            in al,61
                RJ
                and al,0F7
mn3:            out 61,al
                sub ah,ah
                ret
motor_on        endp

                %out >>>  Motor_off
motor_off       proc near
                TESTPM mo1
                call testpr
                jnc mo2
                ret
mo2:            push dx
                mov dx,cs:port0
                add dx,2
                in al,dx
                RJ
                or al,8
                out dx,al
                pop dx
                ret
mo1:            in al,61
                RJ
                or al,8
                jmp mn3
motor_off       endp

                %out >>>  Set_mask
set_mask        proc near
                mov cs:maskbyte,al
                xor ah,ah
                ret
set_mask        endp

                %out >>>    TestPr
testpr          proc near
                push dx
                push cx
                push bx
                mov cx,4
                mov dx,cs:port0
                add dx,2
tp1:            in al,dx
                mov bl,al
                and al,1
                mov ah,al
                dec dx
                in al,dx
                inc dx
                and al,40
                xor al,40
                or al,ah
                jz tp2
                cmp al,41
                jne tp3
tp2:            mov al,bl
                xor al,1
                out dx,al
                loop tp1
                or al,al
tp4:            pop bx
                pop cx
                pop dx
                ret
tp3:            mov ah,10
                stc
                jmp tp4
testpr          endp

                %out >>>  Read_IBM
read_ibm        proc near
                push bx
                push cx
                push si
                mov si,7
                call m_on_wait
                jnc ri1
                jmp ri2
ri1:            in al,62
                and al,10
                mov intflag,al
                mov dx,3f7a
ri3:            test biosbreak,80
                jnz ri4
                dec dx
                jnz ri5
ri4:            jmp ri6
ri5:            call onbek1
                jcxz ri3
                mov dx,378
                mov cx,200
                in al,21
                RJ
                or al,1
                out 21,al
ri7:            test biosbreak,80
                jnz ri6
                push cx
                call onbek1
                or cx,cx
                pop cx
                jz ri1
                cmp dx,bx
                jcxz ri8
                jnb ri1
                loop ri7
ri8:            jc ri7
                call onbek1
                call onbek2
                cmp al,16
                jne ri9
                pop si
                pop cx
                pop bx
                push cx
ri10:           mov io_rom_seg,0FFFF
                mov dx,100
ri11:           test biosbreak,80
                jnz ri12
                call onbek2
                jc ri12
                jcxz ri13
                mov es:[bx],al
                inc bx
                dec cx
ri13:           dec dx
                jg ri11
                call onbek2
                call onbek2
                sub ah,ah
                cmp io_rom_seg,1D0F
                jne ri14
                jcxz ri15
                jmp ri10
ri12:           mov ah,1
ri14:           inc ah
ri15:           pop dx
                sub dx,cx
                push ax
                test ah,3
                jne ri16
                call onbek2
                jmp short ri16
ri9:            dec si
                jz ri6
                jmp ri1
ri6:            pop si
                pop cx
                pop bx
                sub dx,dx
                mov ah,4
                push ax
ri16:           in al,21
                RJ
                and al,0FE
                out 21,al
                call motor_off
                pop ax
                cmp ah,1
                cmc
                ret
ri2:            pop si
                pop cx
                pop bx
                ret
read_ibm        endp

                %out >>>    onbek2
onbek2          proc near
                push bx
                push cx
                mov cl,8
o21:            push cx
                call onbek1
                jcxz o22
                push bx
                call onbek1
                pop ax
                jcxz o22
                add bx,ax
                cmp bx,6F0
                cmc
                lahf
                pop cx
                rcl ch,1
                sahf
                call onbek3
                dec cl
                jnz o21
                mov al,ch
                clc
o23:            pop cx
                pop bx
                ret
o22:            pop cx
                stc
                jmp o23
onbek2          endp

                %out >>>    onbek1
onbek1          proc near
                mov cx,64
                mov ah,intflag
                TESTPM o11
                push dx
                mov dx,cs:port0
                inc dx
o12:            in al,dx
                RJ
                and al,80
                cmp al,ah
                loopz o12
                pop dx
                jmp short o13
o11:            in al,62
                RJ
                and al,10
                cmp al,ah
                loopz o11
o13:            mov intflag,al
                mov al,0
                out 43,al
                RJ
                in al,40
                RJ
                mov ah,al
                in al,40
                xchg al,ah
                mov bx,io_rom_init
                sub bx,ax
                mov io_rom_init,ax
                ret
onbek1          endp

                %out >>>  Write_IBM
write_ibm       proc near
                push bx
                push cx
                call m_on_wait
                jnc wi1
                pop cx
                pop bx
                ret
wi1:            in al,61
                RJ
                and al,0FDh
                or al,1
                out 61,al
                RJ
                mov al,0B6
                out 43,al
                mov ax,4a0
                call out41ax
                mov cx,800
                in al,21
                or al,1
                out 21,al
wi2:            stc
                call out41iets
                loop wi2
                clc
                call out41iets
                pop cx
                pop bx
                mov al,16
                call onbek4
wi3:            mov io_rom_seg,0FFFF
                mov dx,100
wi4:            mov al,es:[bx]
                call onbek4
                jcxz wi5
                inc bx
                dec cx
wi5:            dec dx
                jg wi4
                mov ax,io_rom_seg
                not ax
                push ax
                xchg ah,al
wi6:            call onbek4
                pop ax
                call onbek4
                or cx,cx
                jnz wi3
                push cx
                mov cx,20
wi7:            stc
                call out41iets
                loop wi7
                pop cx
                mov al,0B0
                out 43,al
                RJ
                mov ax,1
                call out41ax
                in al,21
                RJ
                and al,0FE
                out 21,al
                call motor_off
                sub ax,ax
                ret
write_ibm       endp

                %out >>>    onbek4
onbek4          proc near
                push cx
                push ax
                mov ch,al
                mov cl,8
o41:            rcl ch,1
                pushf
                call out41iets
                popf
                call onbek3
                dec cl
                jnz o41
                pop ax
                pop cx
                ret
onbek4          endp

                %out >>>    Out41
out41iets       proc near
                mov ax,4a0
                jc ui1
                mov ax,250
ui1:            push ax
                call onbek11
                pop ax
out41ax:        out 42,al
                RJ
                mov al,ah
                out 42,al
                ret
out41iets       endp

                %out >>>    onbek3
onbek3          proc near
                mov ax,io_rom_seg
                rcr ax,1
                rcl ax,1
                clc
                jno o31
                xor ax,810
                stc
o31:            rcl ax,1
                mov io_rom_seg,ax
                ret
onbek3          endp

                %out >>>    M_on_wait
m_on_wait       proc near
                call motor_on
                jc mw1
                mov bl,42
mw2:            mov cx,700
mw3:            loop mw3
                dec bl
                jnz mw2
mw1:            ret
m_on_wait       endp

                %out >>>  Read_BC
read_bc         proc near
                push bx
                push cx
                push si
                mov si,7
                call m_on_wait
                jnc rb1
                jmp rb2
rb1:            in al,62
                and al,10
                mov intflag,al
                mov dx,3f7a
rb3:            test biosbreak,80
                jnz rb6
                dec dx
                jnz rb5
rb6:            jmp rb7
rb8:            pop cx
                jmp rb1
rb5:            call onbek6
                jcxz rb3
                jnc rb3
                mov cx,0C8
                in al,21
                RJ
                or al,1
                out 21,al
rb9:            test biosbreak,80
                jnz rb7
                push cx
                call onbek6
                jcxz rb8
                pop cx
                jcxz rb10
                jnc rb1
                loop rb9
rb10:           jc rb9
                call onbek7
                jc rb11
                cmp al,82
                jne rb11
                mov byte ptr io_rom_seg,al
                pop si
                pop cx
                pop bx
                xor dx,dx
rb15:           test biosbreak,80
                jnz rb12
                call onbek8
                jc rb12
                mov ah,8
                jcxz rb13
                xor byte ptr io_rom_seg,al
                cmp al,83
                je rb14
                mov ah,cs:maskbyte
                not ah
                and al,ah
                mov es:[bx],al
                inc bx
                dec cx
                inc dx
                jmp rb15
rb14:           call onbek8
                xor byte ptr io_rom_seg,al
                xor ah,ah
                cmp io_rom_seg,0
                jnz rb16
                jmp rb13        ; short
rb12:           mov ah,1
rb16:           inc ah
rb13:           push ax
                test ah,0F
                jnz rb17
                call onbek8
                jmp rb17        ; short
rb11:           dec si
                jz rb7
                jmp rb1
rb7:            pop si
                pop cx
                pop bx
                sub dx,dx
                mov ah,4
                push ax
rb17:           in al,21
                RJ
                and al,0FE
                out 21,al
                call motor_off
                pop ax
                cmp ah,1
                cmc
                ret
rb2:            pop si
                pop cx
                pop bx
                ret
read_bc         endp

                %out >>>    onbek7
onbek7          proc near
                push bx
                push cx
                jmp short o71
onbek8:         push bx
                push cx
o72:            call onbek6
                jcxz o73
                jc o72
o71:            mov cl,8
o74:            push cx
o75:            call onbek6
                jcxz o76
                pop cx
                rcr ch,1
                dec cl
                jnz o74
                mov al,ch
                call onbek6
                jcxz o73
                cmc
o77:            pop cx
                pop bx
                ret
o76:            pop cx
o73:            stc
                jmp o77
onbek7          endp

                %out >>>    onbek6
onbek6          proc near
                push ax
                push bx
                call onbek1
                jcxz o61
                push bx
                call onbek1
                pop ax
                jcxz o61
                add bx,ax
                cmp bx,5c6
                jnc o61
                call onbek1
                jcxz o61
                push bx
                call onbek1
                pop ax
                jcxz o61
                add bx,ax
                cmp bx,5c6
o61:            pop bx
                pop ax
                ret
onbek6          endp

                %out >>>  Write_BC
write_bc        proc near
                push bx
                push cx
                call m_on_wait
                jnc wb1
                pop cx
                pop bx
                ret
wb1:            in al,61
                RJ
                and al,0FDh
                or al,1
                out 61,al
                mov al,0B6
                RJ
                out 43,al
                mov ax,1EC
                RJ
                out 42,al
                mov al,ah
                RJ
                out 42,al
                mov cx,1770
                TESTPM wb2
                in al,21
                or al,1
                out 21,al
wb2:            stc
                call onbek9
                loop wb2
                mov al,82
                mov byte ptr io_rom_seg,al
                call onbek10
                pop cx
                pop bx
                xor dx,dx
wb3:            mov al,es:[bx]
                or al,cs:maskbyte
                xor byte ptr io_rom_seg,al
                call onbek10
                jcxz wb4
                inc bx
                dec cx
                inc dx
                jmp wb3
wb4:            mov al,83
                xor byte ptr io_rom_seg,al
                call onbek10
                mov al,byte ptr io_rom_seg
                call onbek10
                mov cx,1770
wb5:            stc
                call onbek9
                loop wb5
                mov al,0B0
                out 43,al
                RJ
                mov ax,1
                out 42,al
                RJ
                mov al,ah
                out 42,al
                TESTPM wb6
                in al,21
                RJ
                and al,0FE
                out 21,al
wb6:            call motor_off
                sub ax,ax
                ret
write_bc        endp

                %out >>>    onbek10
onbek10         proc near
                push cx
                push ax
                clc
                call onbek9
                mov ch,al
                mov cl,8
o101:           rcr ch,1
                call onbek9
                dec cl
                jnz o101
                stc
                call onbek9
                call onbek9
                pop ax
                pop cx
                ret
onbek10         endp

                %out >>>    onbek9
onbek9          proc near
                push ax
                pushf
                mov ax,3da
                jnc o91
                mov ax,1ec
o91:            call onbek11
                jnc o92
                push ax
                out 42,al
                mov al,ah
                RJ
                out 42,al
                pop ax
                call onbek11
o92:            out 42,al
                mov al,ah
                RJ
                out 42,al
                popf
                pop ax
                ret
onbek9          endp

                %out >>>    onbek11
onbek11         proc near
                pushf
                push ax
                push dx
                mov dx,62
                cmp cs:iets,0FC ; byte ptr
                jne o111
                dec dx
o111:           in al,dx
                and al,20
                jz o111
                TESTPM o112
                call onbek12
o112:           in al,dx
                and al,20
                jnz o112
                TESTPM o113
                call onbek12
o113:           pop dx
                pop ax
                popf
                ret
onbek11         endp

                %out >>>    onbek12
onbek12         proc near
                push dx
                mov dx,cs:port0
                in al,dx
                RJ
                xor al,1
                out dx,al
                pop dx
                ret
onbek12         endp

                %out >>>  data...
maskbyte        db 80
port0           dw 0
portmode        db 0
iets            db 0

                %out >>>  hoofdroutine...
entry:          assume ds:code,es:zero
                push ds
                mov dx,offset txt1
                mov ah,9
                int 21
                xor ax,ax
                mov es,ax
                mov ax,int15ofs
                mov word ptr oldint15,ax
                mov ax,int15seg
                mov word ptr oldint15[2],ax
                push cs
                pop es
                call setup1
                jnz s1
                xor ax,ax
                mov es,ax
                mov ax,int15seg
                mov es,ax
                assume es:nothing
s1:             mov al,es:portmode
                call setup2
                mov iets2,al
                test al,4
                jnz s2
                mov ax,0FFFF
                push es
                mov es,ax
                mov bl,es:[000E]
                pop es
                mov es:iets,bl
                cmp bl,0FF
                je s2
                or iets2,4      ; byte ptr
s2:             test iets2,4    ; byte ptr
                jz s3
                mov al,iets2
                call setup3
                jnc s3
                mov dx,offset txt2
                mov ah,9
                int 21
                mov al,iets2
                and al,3
                jnz s4
                mov dx,offset txt3
                jmp short s5
s4:             or al,30
                mov dl,al
                mov ah,2
                int 21
                mov dx,offset txt4
s5:             mov ah,9
                int 21
                call setup4
                call setup1
                mov dx,offset txt5
                jnz s6
                mov dx,offset txt6
s6:             mov ah,9
                int 21
                pop ds
                int 20
s3:             mov al,iets2
                mov es:portmode,al
                call setup4
                call setup1
                jnz s7
                mov dx,offset txt7
                mov ah,9
                int 21
                pop ds
                int 20
s7:             push es
                xor ax,ax
                mov es,ax
                assume es:zero
                cli
                mov int15ofs,offset newint15
                mov int15seg,cs
                sti
                pop es
                assume es:nothing
                mov dx,offset txt8
                mov ah,9
                int 21
                mov dx,offset entry
                pop ds
                int 27

                %out >>>  setup 2
setup2          proc near
                push bx
                push cx
                mov bx,offset parms
                mov cl,[bx]
                xor ch,ch
                jcxz s8
s21:            inc bx
                cmp byte ptr [bx],'/'
                je s22
                cmp byte ptr [bx],'?'
                je s23
                loopnz s21
                jmp short s8
s22:            dec cx
                jcxz s8
                inc bx
                or byte ptr [bx],20
                cmp byte ptr [bx],'p'
                jne s24
                or al,4
                and al,0FC
                dec cx
                jcxz s8
                inc bx
                cmp byte ptr [bx],'1'
                jb s25
                cmp byte ptr [bx],'4'
                jae s25
                mov ah,[bx]
                and ah,3
                and al,0FC
                or al,ah
                jmp short s8
s24:            cmp byte ptr [bx],'c'
                jne s25
                and al,0FBh
                RJ
s8:             pop cx
                pop bx
                ret
s23:            call setup5
                int 20
s25:            mov dx,offset txt9
                mov ah,9
                int 21
                jmp s23
setup2          endp

                %out >>>  setup 5
setup5          proc near
                mov dx,offset txt10
                mov ah,9
                int 21
                mov dx,offset txt11
                test es:portmode,4
                jz s51
                mov dx,offset txt12
s51:            mov ah,9
                int 21
                ret
setup5          endp

                %out >>>  setup 3
setup3          proc near
                push bx
                mov bl,al
                and bl,3
                jz s31
                dec bl
s31:            xor bh,bh
                push bx
                shl bx,1
                mov ax,40
                push es
                mov es,ax
                assume es:biosdata
                mov dx,es:[bx+iets3]
iets3           equ 8
                pop es
                assume es:nothing
                pop ax
                inc al
                or dx,dx
                stc
                jz s32
                cmc
                mov es:port0,dx
s32:            pop bx
                ret
setup3          endp

                %out >>>  setup 4
setup4          proc near
                test es:portmode,4
                jz s41
                mov dx,offset txt2
                mov ah,9
                int 21
                mov al,es:portmode
                call setup3
                and al,3
                or al,30
                mov dl,al
                mov ah,2
                int 21
                mov dx,offset txt13
                mov ah,9
                int 21
                jmp short s42
s41:            mov dx,offset txt14
                mov ah,9
                int 21
s42:            mov dx,offset txt15
                mov ah,9
                int 21
                ret
setup4          endp

                %out >>>  setup 1
setup1          proc near
                push es
                xor ax,ax
                mov es,ax
                assume es:zero
                mov bx,int15ofs
                pop es
                assume es:nothing
                mov cx,offset newint15
                cmp cx,bx
                ret
                ret
setup1          endp

                %out >>>  teksten...
                .radix 10
txt1            db 'BASICODE ondersteuning V 1.01',13,10
                db 'voor de IBM Personal Computer',13,10
                db 'Copyright 1984 B.S.H. Niewold',13,10,36
txt10           db 'De DOS commandovorm is: CAS  [?] | [/C] | [/P[n]]',13,10
                db '? geeft dit scherm.',13,10
                db 'C voor cassettepoort',13,10
                db 'P voor parallel printerpoort',13,10
                db 'waar   n = blanko,1,2 of 3',13,10,36
txt2            db 'Printerpoort $'
txt3            db 'is in deze computer niet beschikbaar.',13,10,36
txt13           db ' zal worden gebruikt.',13,10,36
txt4            db ' bestaat niet.',13,10,36
txt14           db 'Cassette-aansluiting zal worden gebruikt.',13,10,36
txt15           db 'Cassette-ondersteuning voor BASICODE is $'
txt7            db 'al eerder '
txt8            db 'geladen.',13,10,36
txt5            db 'niet geladen.',13,10,36
txt6            db 'niet aangepast.',13,10,36
txt9            db '***** FOUT IN PARAMETERS. ******',13,10,36
txt12           db '   IBM PC parallel printerpoort aansluiting',13,10
                db '  2   1   10   17   11    18-25',13,10
                db '  ÅÄÄÄÅÄÄÄÅÄÄÄÄÅÄÄÄÄÅÄÄÄÄÄÄÄÅÄÄÄ',13,10
                db '  ³   ÀÄÄÄÙ   n.c.  ³  DUG  ³',13,10
                db '  ± 1k              ÃÄÄ´<ÄÄÄ´',13,10
                db '  ±                 ³       ³',13,10
                db '  ³                 ÃÄÄ´/ÃÄÄ´',13,10
                db '  ³                 ³  4.7v ³ <Ä massa',13,10
                db '  ³              22 ±  zener³   (aarde)',13,10
                db '  ³       56nF  ohm ±       ³',13,10
                db '  ÃÄÄÄÄÄÄÄ´ÃÄÄÄÄÄÄÄÄ³ÄÄÄÄÄÄÄ´',13,10
                db '  ± 5k6             ³       ³',13,10
                db '  ±                 ³       ³',13,10
                db '  ÃÄÄ±±±±ÄÄÂÄÄÄÄÄÄÄÄ³ÄÄÄÄÄÄÄ´',13,10
                db '  ³   1k   ³        ³       ³',13,10
                db '  Cassette         Luidspreker',13,10
                db '  aux ingangs        plug',13,10
                db '  plug ',13,10,36
txt11           db ' IBM PC Cassette-aansluiting',13,10
                db '                    motor',13,10
                db '  in    uit   nul   aan/uit',13,10
                db ' ÄÄ³ÄÄÄÄÄ³ÄÄÄÄÄ³ÄÄÄÄÄ³ÄÄÄÄÄ³Ä',13,10
                db '   ³4    ³5    ³2    ³3    ³1',13,10
                db 3 dup('   ³     ³     ³     ³     ³',13,10)
                db '   ³  ÚÄÄ³ÄÄÄÄÄÙ     ³     ³',13,10
                db ' ÄÄ³ÄÄÅÄÄ³ÄÄÄ      ÄÄ³ÄÄÄÄÄ³Ä',13,10
                db '   3  2  1',13,10
                db '   DIN plug          cassette',13,10
                db '                     recorder',13,10
                db '                    afhankelijk',13,10,36
iets2           db 0

                %out >>>EINDE.
code            ends
                end begin