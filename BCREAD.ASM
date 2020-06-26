                page
                page ,132
                title BCREAD basicode leesroutines

                ; Maakt gebruik van BC.OBJ

                ;=======================================:
                ;              BCREAD.OBJ               :
                ;    Een programma van Jac Goudsmit     :
                ;                                       :
                ;              JG  120788               :
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
                public Read_BC
                .const
                align 10
                db '  PATCH POINT   CYCLE TIME-OUT ='
TimeOutVal      dw 200d                 ; 100d kan gebruikt worden tot een
                                        ; klokfrekwentie van ongeveer 16 MHz
                .data
iobit           db ?                    ; ingelezen poortwaarde (0 of niet-0)
Timer           dw ?                    ; Stand van timer toen laatste flank
                                        ; gedetekteerd werd
ByteFlag        db ?                    ; vorige byte correct ingelezen=0
NieuweFlag      db ?                    ; deze byte correct ingelezen=0
                .code

                ; Read_BC
                ; Leest een BASICODE programma of bestandsblok in.
                ; N: ES:BX=adres, CX=max aantal bytes
                ; X: ES:BX=adres na ingelezen data
                ;    DX=werkelijk aantal ingelezen bytes.
                ;       Voor bestanden is dit 1024d, behalve bij het laatste
                ;       blok.
                ;    AH=error code als CF=1
                ;       1=CRC error
                ;       2=data lost
                ;       4=not found (time-out) of user break
                ;       8=buffer te klein
                ;       10=interface niet aanwezig
Read_BC         proc near uses si cx
                assume es:nothing
                push bx
                push cx
                mov EOT,0
                mov ByteFlag,0
                call Screensave
                in al,21
                or al,1
                out 21,al               ; timer interrupt uitschakelen
                call Motor_on
                jnc @F
                jmp Einde

@@:             mov si,7                ; max 7x synchroniseren tijdens header

Re_search2:     push cx                 ; alleen omdat Re_search CX moet POPpen
Re_Search:      pop cx
                in al,62                ; initiele cassettepoort-waarde
                and al,10
                mov iobit,al

                mov dx,3f7a             ; time-out waarde
@@:             call Checkbreak
                jnz @F
                dec dx
                jz @F

                call Leesbit
                jcxz @B                 ; time-out? blijf zoeken
                jnc @B                  ; geen stopbit? blijf zoeken
                mov cx,0C8              ; time-out waarde voor header
                jmp short LeaderLoop

Retry:          dec si
                jnz Re_search2

@@:             pop cx
                pop bx
Break:          mov ah,4
                jmp Einde

LeaderLoop:     call CheckBreak
                jnz @B
                push cx
                call Leesbit
                jcxz Re_search
                pop cx
                jcxz @F                 ; einde leader verwacht? zoek STX
                jnc Re_search2
                loop LeaderLoop

@@:             jc LeaderLoop
                call LeesKorteByte      ; lees byte zonder startbit
                jc Retry                ; probeer si keer, anders Not Found
                cmp al,STX
                jne Retry

                mov Checksum,al         ; init checksum
                pop cx                  ; buffergrootte
                cmp BSTflag,0
                je @F

                ; Bestandsblok: lees blocknummer

                mov BST_gelezen,0
                call Leesbyte
                jc DataLost
                xor Checksum,al
                xor al,80
                mov Blockno,al
                mov cx,1024d            ; altijd 1024 bytes voor bestanden

@@:             pop bx                  ; adres
                xor dx,dx               ; teller
                inc cx                  ; tel stopbyte mee

ReadLoop:       call CheckBreak
                jnz Break
                jcxz BufferVol

                call Leesbyte
                jc DataLost
                xor Checksum,al

                cmp EOT,0               ; was er al een EOT gevonden?
                jne @F                  ; ja-nergens meer op letten.
                cmp al,84               ; EOT-char
                jne GeenBSTeind
                mov BST_Gelezen,dx      ; echte waarde bloklengte
                dec dx
                mov EOT,1
                jmp short Nostore       ; byte niet opslaan

GeenBSTeind:    cmp al,83               ; ETX?
                je EndFile

@@:             xor al,80
                mov es:[bx],al
                inc bx
Nostore:        inc dx                  ; aantal gelezen excl stopbyte
                dec cx                  ; aantal nog te lezen incl stopbyte
                jmp ReadLoop

EndFile:        call Leesbyte           ; lees checksum van tape
                xor ah,ah
                xor Checksum,al
                jz Einde
                mov ah,1                ; checksum fout
                jmp short Einde

DataLost:       mov ah,2
                jmp short Einde
Buffervol:      mov ah,8

Einde:          push ax
                in al,21
                and al,0FE              ; enable timer int
                out 21,al

                call Motor_Off

                pop ax
                cmp ah,1                ; CY wordt 1 als ah<1
                cmc                     ; CY wordt 1 als ah>=1

                call ScreenRestore

                cmp BSTflag,0
                je @F
                mov dx,BST_gelezen

@@:             ret
Read_BC         endp

                ; LeesFlank meet de tijd totdat de poort van waarde verandert.
                ; Tijd-kritisch! niet veranderen!
LeesFlank       proc near
                mov cx,TimeOutVal
                mov ah,iobit
                test Printer,4
                jz F_Cass

                push dx
                mov dx,Poort0
                inc dx

F_P_Loop:       in al,dx                ; wacht op een flank
                jmp short @F
@@:             and al,80
                cmp al,ah
                loope F_P_Loop
                pop dx
                jmp short Flankgelezen

F_Cass:         in al,62
                jmp short @F
@@:             and al,10
                cmp al,ah
                loope F_Cass

FlankGelezen:   mov iobit,al
                mov al,0                ; latch timer 0 count
                out 43,al               ; timer control port
                in al,40                ; lage waarde
                mov ah,al
                in al,40                ; hoge waarde
                xchg al,ah              ; ax=aantal cycles op 1.1931817 MHz
                mov bx,Timer            ; lees vorige timerstand
                sub bx,ax               ; bereken tijdsverschil
                mov Timer,ax            ; Sla nieuwe timerstand op
                ret
LeesFlank       endp

                ; LeesBit leest een BASICODE-standaard bit in,
                ; dwz 1 volle cycle van 1200 Hz of 2 volle cycles van 2400 Hz.
                ; LeesBit2 is een alternatieve entry voor her-sync na
                ; signaaluitval.
LeesBit         proc near uses ax bx
                call LeesFlank          ; Eerste halve cycle
                jcxz @F
LeesBit2:       push bx
                call LeesFlank          ; Tweede halve cycle
                pop ax
                jcxz @F

                add bx,ax               ; Meet totale cycle-tijd
                cmp bx,5c6              ; bepaal grens
                jnb @F

                call LeesFlank          ; Derde halve cycle
                jcxz @F
                push bx
                call LeesFlank
                pop ax
                jcxz @F
                add bx,ax
                cmp bx,5C6              ; CF=1 voor 1-bit.

@@:             ret
LeesBit         endp

                ; Leesbyte leest een BASICODE standaard byte.
                ; Dat bestaat uit:
                ;  - Startbit: altijd 0
                ;  - 8 databits, LSB eerst. MSB is altijd 1
                ;  - 2 Stopbits: altijd 1
                ; Als er iets mis gaat wordt eerst geprobeerd opnieuw te
                ; synchroniseren door te zoeken naar 2 bits met waarde 1,
                ; gevolgd door een bit met waarde 0. Als deze gevonden zijn
                ; staat de tape dus op het eerste databit van het volgende
                ; byte (tenzij de combinatie toevallig midden in een byte
                ; voorkwam, maar dat trekt zichzelf wel weer recht.)
                ; LeesByte2 is een alternatieve entry die een byte inleest
                ; zonder startbit. Dit is nodig voor het allereerste byte in
                ; een file, en voor hersynchronisatie.
                ; Als een start-of stopbit de verkeerde waarde heeft, en het
                ; vorige byte was ook al fout, dan wordt er gehersync'd
                ; M.a.w. 1 byte met valse bits wordt beschouwd als toeval,
                ; 2 foute bytes levert een hersync op.
LeesByte        proc near
                clc
                call LeesByteService
                ret
LeesByte        endp

LeesKorteByte   proc near
                stc
                call LeesByteService
                ret
LeesKorteByte   endp

LeesByteService proc near uses bx cx
                mov NieuweFlag,0
                jc Leesbyte2
                call LeesBit            ; Startbit
                jcxz Hersync
                jnc LeesByte2           ; moet 0 zijn
                mov NieuweFlag,1
                cmp ByteFlag,0          ; Byte fout
                je Leesbyte2
                jmp short Hersync

LeesByte2:      mov cl,8                ; 8 databits. CL=teller CH=byte
@@:             push cx
                call LeesBit
                jcxz Hersync
                pop cx
                rcr ch,1                ; update byte waarde
                dec cl
                jnz @B
                mov al,ch

                call LeesBit            ; stopbit. (TWEEDE STOPBIT
                jcxz Hersync            ; WORDT NIET GELEZEN???)
                jc @F                   ; moet 1 zijn
                mov NieuweFlag,1
                cmp ByteFlag,0
                jne Hersync

@@:             push ds
                xor al,80
                push ax
                mov ax,0B800
                mov ds,ax
                pop ax
                mov byte ptr ds:[0],al
                push ax
                mov ax,0B000
                mov ds,ax
                pop ax
                mov byte ptr ds:[0],al
                xor al,80
                pop ds
                jmp short LeesByteEinde

                ; HERSYNCHRONISATIE-ROUTINE
                ; Dit is zo een van de belangrijkste routines van het
                ; programma, want hij zorgt ervoor dat BASICODE files die
                ; slecht zijn opgenomen of waar bijvoorbeeld een tik in zit,
                ; toch ingeladen kunnen worden.

                ; zoek naar 2 '1' bit en een '0' bit. Totaal dus 8 korte
                ; halve golven en 2 lange halve golven.
Hersync:        mov NieuweFlag,1
Hersync0:       mov cl,8                ; 8 halve golven
Hersync1:       mov ch,0FF              ; max aantal flanken testen
Hersync2:       dec ch
                jz SyncFail
                call LeesFlank
                jcxz Hersync2
                cmp bx,2e3              ; grens voor korte halve golven
                jae Hersync2
                cmp bx,171              ; minimum lengte korte halve golf
                jb Hersync2

                ; korte halve golf gevonden
                dec cl
                jnz Hersync1

                ; 8 korte halve golven gevonden
                mov cl,2                ; 2 lange halve golven
Hersync3:       mov ch,20               ; max aantal flanken te testen
Hersync4:       dec ch
                jz Hersync0
                call LeesFlank
                jcxz Hersync4

                cmp bx,2e3              ; grens voor lange halve golven
                jb Hersync4
                cmp bx,5c6
                jae Hersync4            ; max lengte lange halve golven

                ; Lange halve golf gevonden
                dec cl
                jnz Hersync3

                ; Gesynchroniseerd.
                mov ByteFlag,1
                jmp LeesByte2

SyncFail:       stc
                jmp short @F

LeesByteEinde:  clc
@@:             mov cl,NieuweFlag       ; cl wordt toch gerestored
                mov ByteFlag,cl
                ret
LeesByteService endp
                end
