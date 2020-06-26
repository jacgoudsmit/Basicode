                page
                page ,132
                title BCREAD_BST basicode-3 bestandsleesroutines

                ; Maakt gebruik van BC.OBJ, BCREAD.OBJ en BCMSGDF.OBJ

                ;=======================================:
                ;             BCREADDF.OBJ              :
                ;    Een programma van Jac Goudsmit     :
                ;                                       :
                ;              JG  061088               :
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

                extrn Read_BC:near

                extrn Boodschap:near
String          struc
Len             db ?
Txt             db 255 dup(?)
String          ends
                .data?
Buffer          db 1024d dup(?)
CurSt           String <,>
BufLen          dw ?                    ; aantal bytes in buffer
StringOfs       db ?                    ; offset van in te lezen string tov
                                        ; buffer-begin (0=dus begin)
LaatsteBlock    db ?                    ; blok dat in de buffer zit (-1=geen)
                .code
                ; Open een BASICODE bestand voor lezen.
                ; De routines worden ingesteld op bestandsbedrijf, daarna
                ; wordt er een blok ingelezen.
                ; Tijdens bestandsbedrijf blijft de motor ingeschakeld.
                ; N: -
                ; X: AH=error code als CY=1
                ;    10=
OpenFileRead    proc near
                call Motor_On
                jc OpenEinde
                mov BSTflag,1
                mov STX,81

                mov BufLen,1024d
                mov StringOfs,1024d
                mov LaatsteBlock,-1
                call ReadString

ReadString      proc near uses ax
                mov CurSt.Len,0
                mov cx,BufLen
                sub cx,StringOfs        ; cx bevat nu aantal bytes over in buf
                cmp cx,0
                jne @F
                call ReadBlock
