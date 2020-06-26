                page
                page ,132
                title BC basicode kernel module

                ;=======================================:
                ;                BC.OBJ                 :
                ;    Een programma van Jac Goudsmit     :
                ;                                       :
                ;              JG  120788               :
                ;=======================================:

                ; N.B.    N=On Entry   X=On Exit

                dosseg
                .model small,BASIC
                .radix 16
                .lall
                .const
Txt1            db 'Personal Computer BASICODE-3 support.',0Dh,0A
                db 'Door Jac Goudsmit. Versie 2.00. '
                db 'Datum 30 sept 1988.',0Dh,0A,0A,24
Txt2            db 'Cassettepoort',24
Txt3            db 'Printerpoort ',24
Txt4            db ' wordt gebruikt.',0Dh,0A,0A,24

Err             db 'Programma afgebroken.',0Dh,0A,24
Err1            db 'BASICODE interface niet aanwezig.',0Dh,0A,24
Err2            db 'U heeft geen printerpoorten, of opgegeven printerpoort bestaat niet.'
                db 0Dh,0A,24
                .data
STX             db ?                    ; STX-karakter.
EOT             db ?                    ; End-Of-Tape flag. wordt ongelijk aan
                                        ; 0 als EOT char ingelezen in
                                        ; bestanden.
                                        ; (EOT signaleert einde file)
BSTflag         db 0                    ; bestands-bedrijf flag
Checksum        db 0                    ; Checksum-byte
Poort0          dw ?                    ; Poort 0 van printerpoort
                                        ;   PR0=latched output
                                        ;       bit 0=uitgang naar interface
                                        ;   PR1=input rechtstreeks
                                        ;       bit 7=input van interface
                                        ;       bit 6=input van Loop
                                        ;   PR2=latched I/O
                                        ;       bit 2=Motor I/O
                                        ;       bit 0=output naar Loop
                                        ;            (geinverteerd bij IN code)
Printer         db 0                    ; bit 2=printer gebruikt, bit 1 en 0=
                                        ;  poort nummer (4=lpt1, 5=lpt2 enz)
BST_gelezen     dw ?                    ; aantal ingelezen bytes van blok of
                                        ; totale bestand
Blockno         db ?                    ; huidig bestandsblok nummer
Schermbytes     dw ?                    ; opgeslagen bytes van scherm
                public BSTflag,Poort0,Printer,BST_gelezen,Checksum,STX,EOT
                public Blockno
                public Motor,Motor_on,Motor_off,TestPr,Init,Exit,Err_Exit
                public Screensave,Screenrestore,Checkbreak
                .code
                assume es:nothing

                ; Motor in- of uitschakelen
                ; Schakelt bestandsbedrijf uit
                ; N: AH=0 inschakelen, AH=1 uitschakelen.
                ; X: CF=1 en AH=10: interface niet aanwezig
Motor           proc near uses cx dx
                                        ; gevonden (bestanden)
                mov cx,1F7              ; mask voor lezen van bit 3
                test Printer,4
                jnz @F

                mov dx,61               ; cassettepoort
                jmp short Motor2

@@:             push ax
                call TestPR
                pop ax
                jc Motor_End

                mov dx,Poort0
                add dx,2
                mov cl,0FBh             ; lees bit 2 voor printer-interface

Motor2:         in al,dx
                and ax,cx               ; reset bit n uit en zorg dat ah goed
                mov cl,3                ;  is.
                test Printer,4
                jz @F
                dec cl                  ; bit 2 voor cassette, 3 voor printer
@@:             shl al,cl
                or al,ah                ; set bit als ah=1
                out dx,al
                xor ah,ah               ; ah=0 en CF=0

Motor_End:      mov BSTFlag,0
                mov STX,82
                ret
Motor           endp

                ; Motor inschakelen (indien nodig)
                ; Ingebouwde vertraging voor motor-start.
                ; N: -
                ; X: CF=1: zie MOTOR voor foutcodes. Alleen AX gewijzigd.
motor_on        proc near uses bx cx
                cmp BSTflag,0
                jne @F
                mov ah,0
                call Motor
                jc Motor_on_quit

                mov bl,42
motor_on_lp1:   mov cx,700
motor_on_lp2:   loop motor_on_lp2
                dec bl
                jnz Motor_on_lp1

@@:             clc

Motor_on_quit:  ret
Motor_on        endp

                ; Motor uitschakelen (indien nodig)
                ; N: -
                ; X: CF=1: zie MOTOR voor foutcodes. Alleen AX gewijzigd.
Motor_off       proc near
                cmp BSTflag,0
                jne @F
                mov ah,1
                call Motor

@@:             ret
Motor_off       endp

                ; Test of interface aanwezig.
                ; N: -
                ; X: CF=1 en AH=10: interface niet aanwezig. AX gewijzigd.
TestPR          proc near uses bx cx dx
                mov cx,4                ; aan, uit, aan, uit
                mov dx,Poort0
                add dx,2

TestPR_loop:    in al,dx                ; al=xxxxxxxi  i=input van loop
                mov bl,al               ; bl=xxxxxxxi
                and al,1                ; al=0000000i
                mov ah,al               ; ah=0000000i
                dec dx
                in al,dx                ; al=x/xxxxxx  /=geinverteerde output
                inc dx
                and al,40               ; al=0/000000
                xor al,40               ; al=0u000000  u=uitgang van loop
                or al,ah                ; al=0u00000i  dus al=0 of 41h is OK
                jz @F
                cmp al,41
                jne TestPR_Err

@@:             mov al,bl               ; al=xxxxxxxi
                xor al,1                ; al=xxxxxxx\  \=geinverteerde input
                out dx,al
                loop TestPR_loop

                xor ah,ah               ; ah=0 en CF=0
                jmp short @F

TestPR_Err:     mov ah,10
                stc

@@:             ret
TestPR          endp

Screensave      proc near uses ax bx
                push ds
                mov ax,0B000
                mov ds,ax
                mov bl,byte ptr ds:[0]
                add ax,800
                mov ds,ax
                mov bh,byte ptr ds:[0]
                pop ds
                mov Schermbytes,bx
                ret
Screensave      endp

Screenrestore   proc near uses ax bx
                mov bx,Schermbytes
                push ds
                mov ax,0B000
                mov ds,ax
                mov byte ptr ds:[0],bl
                add ax,800
                mov ds,ax
                mov byte ptr ds:[0],bh
                pop ds
                ret
Screenrestore   endp

                ; Test of er op Ctrl-Break gedrukt is.
                ; N: -
                ; X: ZF=0 als er op break gedrukt is
Checkbreak      proc near uses es ax
                mov ax,40
                mov es,ax
                test byte ptr es:[71],80
Checkbreak      endp

Init            proc near
                mov dx,offset Txt1      ; opening kernel
                mov ah,9
                int 21

                ; Zoek parameter

                mov ah,62               ; get PSP segment in BX
                int 21
                push es
                mov es,bx
                mov di,81
                mov cl,es:[di-1]
                xor ch,ch
                mov al,'/'
                repne scasb
                jne GeenParms

                mov al,es:[di]
                pop es
                mov dx,offset Err2
                cmp al,'1'
                jb Err_Exit
                cmp al,'4'
                ja Err_Exit

                sub al,'1'              ; hierna zit LPT nr -1 in AL
                or al,4
                mov Printer,al
                jmp short GeenParms

                ; Fout - programma afgebroken

Err_exit:       mov ah,9
                int 21
                mov dx,offset Err
                mov ah,9
                int 21
                mov al,1
                jmp short @F

                ; programma-einde

Exit:           mov al,0
@@:             mov ah,4C               ; Exit
                int 21

                ; Controle van parameters

GeenParms:      push es
                mov ax,0FFFF
                mov es,ax
                mov al,es:[000E]        ; lees PC ID
                pop es
                cmp al,0FF              ; FF=originele PC met cass poort
                je @F

                ; computer is geen originele PC - forceer printerpoort-gebruik

                or Printer,4

                ; Lees poortadres van gevraagde printerpoort in Poort0

                push es
                mov ax,40
                mov es,ax
                mov bl,Printer
                and bx,3
                shl bx,1
                mov ax,es:[bx+8]        ; in 40:8 staat een tabel met LPT
                pop es                  ; adressen
                mov Poort0,ax
                cmp ax,0
                jne @F

                mov dx,offset Err2
                jmp Err_Exit

@@:             test Printer,4
                jz Cass_req
                mov dx,offset Txt3      ; 'Printerpoort'
                mov ah,9
                int 21
                mov dl,Printer          ; nr
                and dl,3
                add dl,'1'
                mov ah,2
                int 21
                jmp short @F

Cass_req:       mov dx,offset Txt2      ; 'Cass poort'
                mov ah,9
                int 21

@@:             mov dx,offset Txt4      ; ' wordt gebruikt'
                mov ah,9
                int 21

                call TestPr
                jnc @F
                mov dx,offset Err1
                jmp Err_exit

@@:             ret
Init            endp
                end
