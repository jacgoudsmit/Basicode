                page
                page ,132
                title BCWRITE basicode schrijfroutines

                ; Maakt gebruik van BC.OBJ

                ;=======================================:
                ;              BCWRITE.OBJ              :
                ;    Een programma van Jac Goudsmit     :
                ;                                       :
                ;              JG  051088               :
                ;=======================================:

                ; N.B.    N=On Entry   X=On Exit

                dosseg
                .model small,BASIC
                .radix 16
                .lall
                extrn BSTflag:byte,Poort0:word,Printer:byte,BST_gelezen:word
                extrn Checksum:byte,STX:byte,EOT:byte,Blockno:byte
                extrn Motor:near,Motor_on:near,Motor_off:near,TestPr:near
                extrn Init:near,Exit:near,Err_Exit:near
                extrn Screensave:near,Screenrestore:near,Checkbreak:near
                .const
                align 10
                db '  PATCH POINT   TRAILER LENGTH ='
TrailerLen      dw 1200d                ; trailer 1 sec. (BC3)
                                        ; evt wijzigen in 3*1200d voor BC2
                .code

                ; Write_BC
                ; Schrijft een stuk geheugen weg als BASICODE programma of
                ; bestand.
                ; N: ES:BX=beginadres
                ;    CX=aantal bytes weg te schrijven
                ; X: ES:BX=adres van byte na weggeschreven data
                ;    AH=error code als CY=1
                ;       4=user break
                ;       10=interface niet aanwezig
                ;    DX=aantal weggeschreven bytes (1024d voor bestanden)
Write_BC        proc near
                assume es:nothing
                push bx
                push cx
                call Motor_On
                jnc @F
                pop cx
                pop bx
                jmp Einde

@@:             in al,61
                and al,0FDh             ; disable speaker
                or al,1                 ; set speaker data
                out 61,al

                mov al,10110110b        ; programmeer timer 2; blokgolf binair
                out 43,al               ; control port
                mov ax,1EC
                call SchrijfTimer
                mov cx,5*1200d          ; 5 seconden lang stopbits

                in al,21
                or al,1
                out 21,al               ; disable timer int

LeaderLoop:     stc
                call SchrijfBit
                loop LeaderLoop

                mov al,STX
                mov Checksum,al
                call SchrijfByte        ; schrijf STX
                pop cx
                pop bx

                xor dx,dx
                cmp BSTflag,0
                je ByteLoop
                mov al,Blockno
                xor al,80
                xor Checksum,al
                call SchrijfByte

ByteLoop:       call CheckBreak
                jz @F
                mov ah,4
                jmp short Einde

@@:             jcxz EOF
                mov al,es:[bx]
                xor al,80
                xor Checksum,al
                call SchrijfByte

                inc bx
                inc dx
                dec cx
                cmp BSTflag,0
                jz ByteLoop

                cmp dx,1024d            ; bestandsblokken zijn 1024 bytes lang
                jb ByteLoop

                cmp EOT,0               ; 1024 bytes geschreven en nog geen
                je BlokEinde            ; bestands-einde? schrijf ETX, stop.
                jmp short BSTeinde      ; Anders stop zonder ETX (EOT al
                                        ; geschreven)
EOF:            cmp BSTflag,0
                je BlokEinde            ; prog-einde? dan normaal eindigen.

                mov EOT,1
                mov al,84               ; EOT signaleert einde bestand
                xor Checksum,al
                call SchrijfByte
                dec cx
                dec bx                  ; bx corrigeren
                jmp ByteLoop

BlokEinde:      mov al,83               ; ETX signaleert einde bstblok/prog
                xor Checksum,al
                call SchrijfByte

BSTEinde:       push cx
                mov cx,TrailerLen       ; trailer teller: 1 sec (BC3)
TrailerLoop:    stc
                call SchrijfBit
                loop TrailerLoop
                pop cx
                xor ah,ah

                cmp BSTflag,0
                je Einde
                cmp EOT,0               ; einde bestand bereikt?
                jne Einde
                inc Blockno
                jmp Write_BC            ; nee? volgende blok

Einde:          push ax
                mov al,10110000b        ; programmeer timer 2; mode 0 bin
                out 43,al
                mov ax,1
                call Schrijftimer
                test Printer,4
                in al,21
                and al,0FE
                out 21,al
                call Motor_off
                pop ax
                cmp ah,1                ; CY=1 als AH<1
                cmc                     ; CY=1 als AH>=1
                ret
write_BC        endp

                ; SchrijfBit schrijft een bit weg naar tape volgens de
                ; BASICODE standaard,
                ; dwz 0=1 cycle van 1200 Hz
                ;     1=2 cycles van 2400 Hz
                ; N: CY=0 voor 0-bit, 1 voor 1-bit
                ; X: -
SchrijfBit      proc near uses ax
                pushf
                mov ax,3DA              ; waarde voor 0
                jnc @F
                mov ax,1EC              ; waarde voor 1

@@:             call WachtCycle
                jnc @F
                call SchrijfTimer
                call WachtCycle
@@:             call SchrijfTimer
                popf
                ret
SchrijfBit      endp

                ; SchrijfByte schrijft een byte naar tape volgens de BASICODE
                ; standaard: 1 startbit (0), 8 databits, 2 stopbits (1)
SchrijfByte     proc near uses cx
                clc
                call SchrijfBit         ; startbit=0
                mov ch,al
                mov cl,8                ; 8 bits

@@:             rcr ch,1
                call SchrijfBit
                dec cl
                jnz @B

                stc
                call SchrijfBit         ; 2 stopbits 1
                call SchrijfBit
                ret
Schrijfbyte     endp

                ; Wacht tot de uitgang omslaat als gevolg van de vorige
                ; klok-programmering
WachtCycle      proc near uses ax dx
                pushf
                mov dx,62
                push es
                mov ax,0FFFF
                mov es,ax
                cmp byte ptr es:[000E],0FC ; PC-AT
                pop es
                ja @F
                dec dx                  ; niet voor PC's en XT's

@@:             in al,dx
                and al,20
                jz @B

                test Printer,4
                jz @F
                call SchrijfPRP
@@:             in al,dx
                and al,20
                jnz @B

                test Printer,4
                jz @F
                call SchrijfPRP
@@:             popf
                ret
WachtCycle      endp

                ; SchrijfPRP maakt de uitgang van de printerpoort gelijk aan
                ; de cassettepoort
SchrijfPRP      proc near uses cx dx
                mov dx,Poort0
                mov cl,5
                shr al,cl
                out dx,al
                ret
SchrijfPRP      endp

SchrijfTimer    proc near uses ax
                out 42,al
                mov al,ah
                out 42,al
                ret
SchrijfTimer    endp
                end
