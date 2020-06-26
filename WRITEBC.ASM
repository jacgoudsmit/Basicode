                   page
                   page ,132
                   title WRITEBC - schrijft basicode programma's naar cassette

                   ;----------------------------------:
                   ;             WriteBC              :
                   ;  Een programma van Jac Goudsmit  :
                   ;                                  :
                   ;            JG  871214            :
                   ;----------------------------------:
         
                   .radix 16
Code               segment
                   assume cs:Code,ds:Code,es:Code

                   org 100
Entry:             jmp Start
Txt0               db 0Dh,'IBM Personal Computer interaktieve BASICODE '
                   db 'schrijver.',0Dh,0A
                   db 'Door Jac Goudsmit. V1.00. Datum 26 feb 1988.',0Dh,0A,0A
                   db 24,8,20,1A
DosErr             db 'Foute DOS versie (moet minstens 3.00 zijn).',0Dh,0A,24
Txt1               db 0Dh,0A,0A
                   db 'Start recorder (REC)',0Dh,24
Txt2               db 'Stop recorder       ',0Dh,0A,0A,24
Txt4               db 'Geef filenaam van weg te schrijven programma: $'
Txt5               db 'Fout bij inlezen van disk. Opnieuw proberen$'
Txt6               db 'Nog een programma wegschrijven$'
Txt8               db '(J/N) ?$'
Txt9               db ' Kb beschikbaar voor het Basicode programma.'
                   db 0Dh,0A,0A,24
Txt10              db 'Te weinig geheugen beschikbaar.',0Dh,0A,24
Err0               db 'FOUT: $'
Err2A              db 'afgebroken door gebruiker.',0Dh,0A,24
Err10              db 'Basicode-interface niet aangesloten.$' ; zonder crlf
Err86              db 'Basicode-routines niet geladen.$' ; zonder crlf
Err2BAS            db 'Programma BAS2BC.COM niet gevonden. '
Err2BAS2           db 'File kan niet vertaald worden.',0Dh,0A,24
ErrTxt             db 'Onbekende foutmelding van BASICODE routines.'
CrLf               db 0Dh,0A,24

Fout_Tab           db 2,10,86
Fout_Rt            dw FOUT2,FOUT10,FOUT86

                   ; invoer-buffer voor filenaam
Filenaam_Invoer    db 40
Filenaam_lengte    db 0
Filenaam           db 40 dup (?)

Oude1B             dd ?
Break              db 0             ; 0:break verlaat programma
Geheugen           dw 0             ; buffergeheugen in bytes; 0=nog niets

                   ; data voor EXEC
BAS2BC             db 'BAS2BC.COM',0
HoldSS             dw ?
HoldSP             dw ?
BAS2BC_Data        label byte
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

;----- Sla oude Ctrl-Break vector op
DosOk:             push es
                   mov ax,351Bh
                   int 21
                   mov word ptr [Oude1B],bx
                   mov word ptr [Oude1B+2],es
                   pop es

;----- Maak ruimte vrij
                   ; es=cs
                   mov sp,offset TOS
                   add sp,0F
                   and sp,0FFF0
                   mov bx,sp
                   mov cl,4
                   shr bx,cl
                   mov ah,4A
                   int 21
                   jc MemErr
                   jmp Alloc        ; om geheugenruimte op scherm te melden

MemErr:            mov dx,offset Txt10
                   jmp Err

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
                   mov Filenaam[bx],0
                   cmp bl,0
                   je VraagNaam     ; blijf vragen tot filenaam gegeven

;----- Probeer BAS2BC te starten

                   ; geheugen vrijmaken
                   cmp Geheugen,0
                   je NietVrijmaken1
                   mov ah,49
                   int 21
                   mov Geheugen,0

                   ; Herstel Break-vector
NietVrijmaken1:    push ds
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

                   mov dx,offset BAS2BC
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

                   mov bx,offset BAS2BC_Data
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

                   jnc BAS2BC_Klaar

;----- BAS2BC niet gedraaid-foutmelding
                   mov dx,offset Err2BAS
                   cmp Err2BAS,0
                   jne EersteKeer
                   mov dx,offset Err2BAS2
EersteKeer:        mov ah,9
                   int 21
                   mov Err2Bas,0

;----- BAS2BC afgelopen. Eis geheugen op.
BAS2BC_Klaar:      popf

Alloc:             cmp Geheugen,0
                   jne MemOk
                   mov bx,0fff      ; (bijna) 64K
Alloc2:            mov dx,bx        ; opslaan
                   mov ah,48
                   int 21
                   jnc MemOk
                   cmp dx,0fff      ; was het verzoek al ingeperkt?
                   jb MemErr2       ; ja: geheugenfout
                   cmp bx,80        ; min. 2K
                   jae Alloc2       ; probeer opnieuw met ingeperkt verzoek

MemErr2:           jmp MemErr

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
GeenMelding:       mov dx,offset Nieuwe1B
                   mov ax,251Bh
                   int 21

;----- lees in
Lees:              cmp Filenaam_Lengte,0
                   jne Lees2
                   jmp Vraagnaam
                   
Lees2:             mov Break,2
                   mov dx,offset Filenaam
                   xor cx,cx
                   mov ax,3D00      ; open file
                   int 21
                   jnc OpenOk
                   jmp Short FileFout

FileFout2:         mov ah,3E
                   int 21
                   push cs
                   pop ds
FileFout:          mov dx,offset Txt5
                   call Janee
                   jz Lees
                   jmp Nogeens     ; file kan niet worden ingelezen.

OpenOk:            mov bx,ax
                   mov cx,Geheugen
                   mov bp,cx
                   push bx
                   mov ax,es
                   mov ds,ax
                   xor dx,dx
                   mov ah,3F
                   int 21           ; read file
                   pop bx
                   jc FileFout2
                   cmp ax,bp
                   jne BytesGelezen

                   ; Evenveel bytes gelezen als gevraagd -> file te lang
                   mov dx,offset Txt10
                   mov ah,9
                   int 21
                   jmp NogEens

BytesGelezen:      mov bp,ax        ; werkelijk aantal gelezen bytes in bp
                   mov ah,3E
                   int 21           ; close file
                   push cs
                   pop ds

;----- Start recorder
Ingelezen:         mov dx,offset Txt1
                   mov ah,9
                   int 21

;----- Schrijf programma weg
                   mov Break,1      ; Break keert terug na boodschap
                   xor bx,bx
                   mov cx,bp
                   mov ah,5
                   int 15
                   mov Break,0
                   cmp ah,0
                   je NogEens2

;----- foutmelding van cassette-routines.
                   push es
                   push cs
                   pop es
                   mov di,offset Fout_Tab
                   mov cx,3
                   mov al,ah
                   repne scasb
                   pop es
                   je FoutGevonden
                   mov dx,offset ErrTxt
                   jmp Err          ; beeindig programma bij rare foutcode
FoutGevonden:      sub di,offset Fout_Tab+1
                   shl di,1
                   call ds:[Fout_Rt+di]
                   cmp ah,2
                   jne Nogeens
                   jmp Err          ; 2=stoppen: interface/routines niet gev

;----- Klaar. Nog een?
NogEens2:          call StopRec
NogEens:           mov dx,offset Txt6 ; nog een?
                   call Janee
                   jnz Exit
                   jmp VraagNaam

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

;----- Foutmelding 2: signaal kwijt of Ctrl-Break gedrukt
FOUT2              proc near
                   call StopRec
                   mov dx,offset Err2A
                   call WriteErr
                   mov ah,1
                   ret
FOUT2              endp

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

