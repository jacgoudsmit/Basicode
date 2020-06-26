                   page
                   page ,132
                   title LOADBC - laad basicode programma's

                   ;--------------------------------------------:
                   ;                   LoadBC                   :
                   ;       Een programma van Jac Goudsmit       :
                   ;                                            :
                   ;                 JG  871214                 :
                   ;--------------------------------------------:

                   .radix 16
Code               segment
                   assume cs:Code,ds:Code,es:Code

                   org 100
Entry:             jmp Start
Txt0               db 0Dh,'IBM Personal Computer interaktieve BASICODE '
                   db 'lader.',0Dh,0A
                   db 'Door Jac Goudsmit. V2.10. Datum 21 feb 1988.',0Dh,0A,0A
                   db 24,8,20,1A
DosErr             db 'Foute DOS versie (moet minstens 3.00 zijn).',0Dh,0A,24
Txt1               db 0Dh,0A,0A,'Start recorder (PLAY)',0Dh,24
Txt2               db 'Stop recorder        ',0Dh,0A,0A,24
Txt3               db 'Gevonden programmanaam: $'
Txt4               db 'Wegschrijven als: $'
Txt5               db 'Fout bij wegschrijven naar disk. Opnieuw proberen$'
Txt6               db 'Nog een programma inladen$'
Txt7               db 'Ingeladen gedeelte wegschrijven$'
Txt7A              db 'Ingeladen programma toch wegschrijven$'
Txt8               db '(J/N) ?$'
Txt9               db ' Kb beschikbaar voor het Basicode programma.'
                   db 0Dh,0A,24
Txt10              db 'Te weinig geheugen beschikbaar.',0Dh,0A,24
Err0               db 'FOUT: $'
Err1               db 'Waarschuwing: checksum fout. (Programma is misschien '
                   db 'onbruikbaar.)',0Dh,0A,24
Err2               db 'signaal onderbroken.',0Dh,0A,24
Err2A              db 'afgebroken door gebruiker.',0Dh,0A,24
Err4               db 'geen programma gevonden.',0Dh,0A,24
Err8               db 'programma past niet in geheugen.',0Dh,0A,24
Err10              db 'Basicode-interface niet aangesloten.$' ; zonder crlf
Err86              db 'Basicode-routines niet geladen.$' ; zonder crlf
Err2BAS            db 'Programma BC2BAS.COM niet gevonden. '
Err2BAS2           db 'File is niet '
                   db 'vertaald.',0Dh,0A,24
ErrTxt             db 'Onbekende foutmelding van BASICODE routines.'
CrLf               db 0Dh,0A,24
Rem                db 'REM'

Fout_Tab           db 1,2,4,8,10,86
Fout_Rt            dw FOUT1,FOUT2,FOUT4,FOUT8,FOUT10,FOUT86

                   ; invoer-buffer voor filenaam
Filenaam_Invoer    db 40
Filenaam_lengte    db ?
Filenaam           db 40 dup (?)

Oude1B             dd ?
Break              db 0             ; 0:break verlaat programma
Geheugen           dw 0             ; buffergeheugen in bytes; 0=nog niets

                   ; data voor EXEC
BC2BAS             db 'BC2BAS.COM',0
HoldSS             dw ?
HoldSP             dw ?
BC2BAS_Data        label byte
Environ            dw ?             ; segment van environment
                   dw Filenaam_Lengte
Parm_CS1           dw ?             ; hier wordt CS ingevuld
PSP1               dw 5C
Parm_CS2           dw ?
PSP2               dw 6C
Parm_CS3           dw ?

;----- programma-begin: tekst op scherm
Start:             mov dx,offset Txt0
                   mov ah,9
                   int 21

;----- controleer DOS versie
                   mov ah,30
                   int 21
                   cmp al,3
                   jae DosOk

                   mov dx,offset DosErr
                   jmp Err

;----- Maak ruimte vrij en eis opnieuw op
                   ; es=cs
DosOk:             mov sp,offset TOS
                   add sp,0F
                   and sp,0FFF0
                   mov bx,sp
                   mov cl,4
                   shr bx,cl
                   mov ah,4A
                   int 21
                   jnc Alloc

MemErr:            mov dx,offset Txt10
                   jmp Err

Alloc:             mov bx,0fff      ; (bijna) 64K
Alloc2:            mov dx,bx        ; opslaan
                   mov ah,48
                   int 21
                   jnc MemOk
                   cmp dx,0fff      ; was het verzoek al ingeperkt?
                   jb MemErr        ; ja: geheugenfout
                   cmp bx,80        ; min. 2K
                   jb MemErr
                   jmp Alloc2       ; probeer opnieuw met ingeperkt verzoek

;----- Hoeveelheid geheugen omrekenen naar bytes en KB
MemOk:             mov es,ax        ; es=buffer
                   assume es:nothing

                   mov ax,dx        ; opslaan
                   mov cl,4
                   shl dx,cl        ; omrekenen naar bytes
                   mov Geheugen,dx
                   mov cl,6d        ; 40h para=1K dus delen door 40h
                   shr ax,cl

;----- Meld beschikbare ruimte op scherm
                   ; ax=aantal kb
                   cmp Txt9,0       ; Eerste keer?
                   je GeenMelding   ; Nee- dan geen KB-melding op scherm

                   mov bl,10d       ; delen door 10
                   div bl
                   push ax
                   mov dl,al
                   add dl,'0'
                   mov ah,2
                   int 21
                   pop dx
                   mov dl,dh
                   add dl,'0'
                   mov ah,2
                   int 21

                   mov dx,offset Txt9 ; 'KB geheugen beschikbaar'
                   mov ah,9
                   int 21
                   mov Txt9,0

;----- initialisatie Ctrl-Break interrupt
                   push es
                   mov ax,351Bh
                   int 21
                   mov word ptr [Oude1B],bx
                   mov word ptr [Oude1B+2],es
                   pop es
GeenMelding:       mov dx,offset Nieuwe1B
                   mov ax,251Bh
                   int 21

;----- Start recorder
Laadfile:          mov dx,offset Txt1
                   mov ah,9
                   int 21

;----- Laad programma
                   mov Break,1      ; Break keert terug na boodschap
                   xor bx,bx
                   mov cx,Geheugen
                   mov ah,4
                   int 15
                   mov bp,dx
                   cmp ah,0
                   je Geladen

;----- foutmelding van cassette-routines.
                   push es
                   push cs
                   pop es
                   mov di,offset Fout_Tab
                   mov cx,6
                   mov al,ah
                   repne scasb
                   pop es
                   je FoutGevonden
                   mov dx,offset ErrTxt
                   jmp Err          ; beeindig programma bij rare foutcode
FoutGevonden:      sub di,offset Fout_Tab+1
                   shl di,1
                   call ds:[Fout_Rt+di]
                   mov Break,0      ; Break beeindigt programma
                   cmp ah,0         ; 0=toch wegschrijven
                   je SchrijfWeg
                   cmp ah,1         ; 1=niet wegschrijven, wel doorgaan
                   je Doorgaan
                   jmp Err          ; 2=stoppen: interface/routines niet gev
Doorgaan:          jmp NietGeschreven

;----- programma geladen: zoek eventuele naam in REM statement
Geladen:           mov Break,0
                   call StopRec

SchrijfWeg:        mov cx,dx        ; aantal ingeladen bytes
                   xor di,di
LP1:               push cx
                   mov si,offset Rem
                   mov cx,3
                   push si
                   push di
                   repe cmpsb
                   pop di
                   pop si
                   je NaamGevonden
                   pop cx
                   inc di
                   loop LP1
                   jmp short VraagNaam

;----- Naam gevonden: Melding op scherm
NaamGevonden:      mov dx,offset Txt3
                   mov ah,9
                   int 21

                   add di,3         ; sla REM statement over
LP2:               mov al,es:[di]   ; en eventueel spaties
                   inc di
                   cmp al,20
                   je LP2

LP3:               cmp al,0Dh
                   je NaamEinde
                   mov dl,al
                   mov ah,2
                   int 21
                   mov al,es:[di]
                   inc di
                   jmp LP3

NaamEinde:         mov dx,offset CrLf ; naar volgende regel
                   mov ah,9
                   int 21

;----- vraag filenaam aan gebruiker
VraagNaam:         mov dx,offset Txt4
                   mov ah,9
                   int 21
                   mov dx,offset Filenaam_Invoer
                   mov ah,0A
                   int 21
                   mov dx,offset CrLf
                   mov ah,9
                   int 21
                   mov bl,Filenaam_Lengte
                   xor bh,bh
                   cmp bl,0
                   je VraagNaam     ; blijf vragen tot filenaam gegeven

;----- schrijf weg
                   mov byte ptr [Filenaam+bx],0
Schrijf:           mov Break,2
                   mov dx,offset Filenaam
                   xor cx,cx
                   mov ah,3C        ; create file
                   int 21
                   jnc OpenOk
                   jmp Short FileFout

FileFout2:         mov ah,3E
                   int 21
                   push cs
                   pop ds
FileFout:          mov dx,offset Txt5
                   call Janee
                   jz Schrijf
                   jmp short Weggeschreven

OpenOk:            mov bx,ax
                   mov cx,bp
                   push bx
                   mov ax,es
                   mov ds,ax
                   xor dx,dx
                   mov ah,40
                   int 21           ; write file
                   pop bx
                   jc FileFout2
                   cmp ax,bp
                   jne FileFout2

                   mov ah,3E
                   int 21           ; close file
                   push cs
                   pop ds

Weggeschreven:     mov Break,0

;----- Probeer BC2BAS te starten

                   ; geheugen vrijmaken
                   mov ah,49
                   int 21
                   mov Geheugen,0

                   ; Herstel Break-vector
                   push ds
                   lds dx,Oude1B
                   mov ax,251Bh
                   int 21
                   pop ds

                   ; starten
                   pushf
                   push ax
                   push bx
                   push cx
                   push dx
                   push si
                   push di
                   push bp
                   push ds
                   push es
                   mov HoldSS,ss
                   mov HoldSP,sp

                   mov dx,offset BC2BAS
                   mov ax,cs
                   mov es,ax
                   mov Parm_CS1,ax
                   mov Parm_CS2,ax
                   mov Parm_CS3,ax

                   mov ax,word ptr ds:[2C] ; haal environment uit PSP
                   mov Environ,ax

                   mov al,Filenaam+1 ; zoek drive
                   cmp al,':'
                   jne GeenDrive
                   mov ah,Filenaam
                   sub ah,40
                   cmp ah,26d
                   jbe WelDrive
                   sub ah,20
                   cmp ah,26d
                   jbe WelDrive

GeenDrive:         mov ah,0
WelDrive:          mov byte ptr ds:[6C],ah

                   mov bx,offset BC2BAS_Data
                   mov ax,4B00
                   int 21

                   mov ss,cs:HoldSS
                   mov sp,cs:HoldSP
                   pop es
                   pop ds
                   pop bp
                   pop di
                   pop si
                   pop dx
                   pop cx
                   pop bx
                   pop ax

                   jnc BC2BAS_Klaar

;----- BC2BAS niet gedraaid-foutmelding
                   mov dx,offset Err2BAS
                   cmp Err2BAS,0
                   jne EersteKeer
                   mov dx,offset Err2BAS2
EersteKeer:        mov ah,9
                   int 21
                   mov Err2Bas,0

;----- BC2BAS afgelopen.
BC2BAS_Klaar:      popf

;----- Nog een?
NietGeschreven:    mov dx,offset Txt6 ; nog een?
                   call Janee
                   jnz Exit

;----- Ja - eis geheugen opnieuw op en laad file
                   cmp Geheugen,0
                   jne NietOpeisen
                   jmp Alloc
NietOpeisen:       jmp GeenMelding

;----- Fout - einde: druk tekst af en eindig programma
Err:               mov ah,9
                   int 21

;----- Einde: geef geheugen terug en herstel Break-interrupt
Exit:              cmp Geheugen,0   ; geheugen gereserveerd?
                   je NietVrijMaken
                   mov ah,49        ; free mem
                   int 21

NietVrijMaken:     xor ax,ax
                   mov ds,ax
                   assume ds:nothing
                   and byte ptr ds:[471],7F ; Break_Flag op 0

                   lds dx,Oude1B
                   mov ax,251Bh
                   int 21
                   int 20

;------------------------------------
; Einde hoofdprogramma              :
;------------------------------------

                   assume ds:Code

;----- subroutines

;----- Foutmelding op het scherm
WriteErr           proc near
                   push dx
                   mov dx,offset Err0
                   mov ah,9
                   int 21
                   pop dx
                   mov ah,9
                   int 21
                   ret
WriteErr           endp

;----- JaNee: zet tekst DX op scherm, vraag ja of nee. ZF=1 voor ja
JaNee              proc near
                   mov ah,9
                   int 21
                   mov dx,offset Txt8
                   mov ah,9
                   int 21
Toets:             mov ah,0
                   int 16
                   cmp al,'j'
                   jne IsHetJ
                   jmp short JaNeeEinde
IsHetJ:            cmp al,'J'
                   jne IsHetN
                   jmp short JaNeeEinde

IsHetN:            cmp al,'n'
                   je TisN
                   cmp al,'N'
                   je TisN
                   jmp Toets

TisN:              or al,0          ; zet ZF uit
JaNeeEinde:        pushf
                   mov dl,al
                   mov ah,2
                   int 21
                   mov dx,offset CrLf
                   mov ah,9
                   int 21
                   popf
                   ret
JaNee              endp

;----- Tekst "Stop recorder"
StopRec            proc near
                   mov dx,offset Txt2 ; Stop recorder
                   mov ah,9
                   int 21
                   ret
StopRec            endp

;----- Foutmelding 1: checksum fout.
FOUT1              proc near
                   call StopRec
                   mov dx,offset Err1
                   mov ah,9
                   int 21
GedeelteSchrijven: mov dx,offset Txt7A
AlsnogSchrijven:   call JaNee
                   mov ah,1
                   jnz Nietschrijven1
                   dec ah
NietSchrijven1:    ret
FOUT1              endp

;----- Foutmelding 2: signaal kwijt of Ctrl-Break gedrukt
FOUT2              proc near
                   call StopRec
                   cmp Break,0      ; Break op 0 gezet?
                   je UserInt2
                   mov dx,offset Err2
                   jmp short SignalInt2
UserInt2:          mov dx,offset Err2A
SignalInt2:        call WriteErr
                   mov dx,offset Txt7
                   jmp AlsnogSchrijven
FOUT2              endp

;----- Foutmelding 4: Time-out
FOUT4              proc near
                   call StopRec
                   cmp Break,0      ; Break op 0 gezet?
                   je UserInt3
                   mov dx,offset Err4
                   jmp short TimeOut2
UserInt3:          mov dx,offset Err2A
TimeOut2:          call WriteErr
                   mov ah,1
                   ret
FOUT4              endp

;----- Foutmelding 8: Te weinig geheugen
FOUT8              proc near
                   call StopRec
                   mov dx,offset Err8
                   call WriteErr
                   jmp GedeelteSchrijven
FOUT8              endp

;----- Foutmelding 10: interface niet gevonden
FOUT10             proc near
                   mov dx,offset Err10
                   call WriteErr
                   mov dx,offset CrLf
                   mov ah,2
                   ret
FOUT10             endp

;----- Foutmelding 86: routines niet aanwezig
FOUT86             proc near
                   mov dx,offset Err86
                   call WriteErr
                   mov dx,offset CrLf
                   mov ah,2
                   ret
FOUT86             endp

;----- Nieuwe interrupt routine voor Int 1B (Break)
; Zet Bios_Break_Flag in segment 40h op 80h om verdere interrupts te voorkomen
; Zet Break in CS op 0 om aan te geven dat er op Break is gedrukt
; Eventueel wordt het programma beeindigd
Nieuwe1B           proc far
                   push ax
                   push ds
                   xor ax,ax
                   mov ds,ax
                   or byte ptr ds:[471],80 ; Bios_Break
                   cmp cs:Break,0
                   jne Routine_Break
                   push cs
                   pop ss
                   mov sp,offset TOS
                   jmp Exit

Routine_Break:     mov cs:Break,0   ; afvlaggen van de break
                   pop ds
                   pop ax
                   iret
Nieuwe1B           endp

TOS                equ $+100
Code               ends
                   end Entry
