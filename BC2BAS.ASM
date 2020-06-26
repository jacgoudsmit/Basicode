         page
         page 60,132
         title BC2BAS - Basicode naar BASIC converter
         ;--------------------------------------------:
         ;                   BC2BAS                   :
         ;       Een programma van Jac Goudsmit       :
         ;                                            :
         ;             JG 870425 / 880221             :
         ;--------------------------------------------:
         
         ; Dit programma vertaalt een Basicode file naar BASIC ASCII.
         ; Met "BASICODE file" bedoel ik een programma in BASICODE-
         ; formaat, dat als DOS-file is opgeslagen.

         ; VERSPREIDING
         ; Dit programma mag vrij gekopieerd worden, onder de volgende
         ; voorwaarden:
         ; - Kopieen moeten gratis zijn (m.a.w. een kopie mag niet meer
         ;   kosten dan de lege diskette)
         ; - Wijzigingen die door anderen dan de schrijver zijn aange-
         ;   bracht, moeten duidelijk aangegeven worden;
         ;   bijvoorbeeld kan dan de tekst in de .COM file
         ;   gewijzigd worden in 'Door Jac Goudsmit. datum ... wijzigingen
         ;   door Mr. X dd. ...'
         ; - De naam van de schrijver moet vermeld worden in de
         ;   geassembleerde file (.COM file) (eventueel met toevoeging
         ;   van schrijvers van wijzigingen)
         
         ;--------------------------------------------:
         ;          Algemene voorbereiding MASM       :
         ;--------------------------------------------:

         .radix 16
Code     segment
         assume cs:Code,ds:Code,es:Code

         ;--------------------------------------------:
         ;               Programma-begin              :
         ;--------------------------------------------:

         org 6C
Drive2   label byte             ; drive wordt gebruikt voor 2e parm
         org 80
ParmLen  label byte
         org 81
Parms    label byte

         ;--------------------------------------------:
         ;                 Buffers e.d.               :
         ;--------------------------------------------:

         org 101                ; org 101 omdat [Buffer-1] geen CR mag zijn.
                                ; (ivm leesroutine)
Buffer   label byte
         org 100
Begin:   jmp Main               ; Entry point van COM file.

         ; De volgende tekst wordt afgedrukt als je een TYPE op BC2BAS.COM
         ; probeert. Een goede gewoonte! Vergeet het EOF karakter (1A) niet.

         db 0Dh,'IBM PC Basicode converter.',0Dh,0A
         db 'Door Jac Goudsmit.  V1.10.  Datum 21 feb 1988.',0Dh,0A,1A

         ; De volgende foutmeldingen worden alleen gegeven als de eigenlijke
         ; verwerking nog niet begonnen is. Daarom kunnen ze in het buffer-
         ; gebied liggen.

ParmMsg  db 'Fout in parameters. Syntax is:',0Dh,0A,0A
         db '  BC2BAS source [dest] [/R|/N]',0Dh,0A,0A
         db 'Als de doelfile dezelfde naam heeft als de bronfile, geef dan'
         db ' geen DEST op.',0Dh,0A
         db 'Geef /R voor hele regels op het scherm;',0Dh,0A
         db 'Geef /N om geen regelnummers op het scherm te zetten.',0Dh,0A
         db '(Parameters kunnen niet gecombineerd worden)',0Dh,0A,24
DOSMsg   db 'Foute DOS versie. (Moet 3.00 of hoger zijn.)',0Dh,0A,24

         ; Deze tabel bevat de mogelijke slash-parameters
         ; Om het makkelijk te maken zijn er voor elke parameter twee
         ; mogelijkheden in de tabel: upper case en lower case.
ParmTbl  db 'RrNn'
AantPmM  equ $-ParmTbl          ; aantal Parameter-mogelijkheden

         ; Constanten

BufLen   equ 256d               ; I/O buffer lengte. Van invloed op snelheid
IntLen   equ 65d                ; max lengte van een BC regel inc. CR
OutLen   equ 256d               ; max. lengte van een BASIC(A) regel inc. CR

         ; De volgende berekening wordt gedaan omdat de assembler (V1.00)
         ; de term BUFFER+BUFLEN-$ DUP (?) niet blijkt te pikken.
BufEnd   equ Buffer+BufLen
         ; Buffer opvullen.
         if BufEnd GT $
         db BufEnd-$ dup (?)
         endif

         ; Intermediate buffer - houdt BC regel vast nadat spaties verwijderd
         ; zijn.
IntBuf   db IntLen dup (?)
         ; Output buffer - houdt BASIC regel vast waar spaties weer ingevoegd
         ; zijn.
         ; Deze buffer wordt initieel gevuld met de BASIC-regel om de BASICODE
         ; routines in te laden (CHAIN-regel). Deze regel laadt BASICODE.BAS
         ; dus voor een andere BASICODE versie moet BASICODE.BAS worden
         ; aangepast. (Of het vertaalde programma moet worden veranderd.)
OutBuf   db '10 CLS:PRINT"OGENBLIKJE GEDULD":CHAIN MERGE "BASICODE",1000'
         db 0Dh,0A
InitOLen equ $-OutBuf
         db (OutLen-InitOLen) dup (?)

         ; De volgende buffers bevatten filenamen als het programma draait.
         ; Ze worden met 0 opgevuld omdat een ASCIIZ filenaam ook altijd
         ; eindigt met 0
TMPNaam  db 15d dup (0)         ; Bevat ASCIIZ naam van Temp. file (geen path)
DestNaam db 40 dup (0)          ; Bevat ASCIIZ naam van Destination file

         ;--------------------------------------------:
         ;                    Data                    :
         ;--------------------------------------------:

         ; Enige foutmeldingen die ook tijdens of na het programma kunnen op-
         ; treden. Deze kunnen dus niet naar het buffer-gebied verplaatst
         ; worden.

         ; Deze wordt afgedrukt als DOS na een INT 21 File I/O funktie
         ; een foutmelding geeft. Om het niet te ingewikkeld te maken
         ; heb ik maar een foutmelding voor het hele scala van DOS fouten.
IOMsg    db 'File I/O fout. Programma afgebroken.'

         ; De hierna volgende Carriage Return, Line Feed wordt na bovenstaande
         ; foutmelding afgedrukt, maar kan ook los afgedrukt worden.
CRLF     db 0Dh,0A,24

         ; Deze foutmelding wordt afgedrukt als er bijvoorbeeld een te lange
         ; regel wordt gedetecteerd.
FileMsg  db 'WAARSCHUWING:',0Dh,0A
         db 'Source-file waarschijnlijk geen BASICODE programma.',0Dh,0A,24

SourceF  dw 0                   ; File handle van source file (0=ongeopend)
DestF    dw 0                   ; File handle van Temporary file (0=ongeopend)
EOFFlag  db 0                   ; End of file flag; wordt 1 als laatste regel
                                ; is ingelezen.
BCFlag   db 1                   ; wordt gereset als regel te lang is o.i.d.
EOFOfs   dw BufLen              ; Offset van file-einde in Buffer
InOfs    dw BufLen              ; Offset van eerste ongebruikte byte in Buffer
OutWLen  dw InitOLen            ; Aantal bytes in Output Buffer (schrijven)
                                ; initiele waarde geldt voor de CHAIN regel
IntWLen  dw 0                   ; Aantal bytes in Intermediate Buffer (BC)
IntOfs   dw 0                   ; Lees-offset in intermediate buffer
Qmode    db 0                   ; Quote gevonden - geen spaties verwijderen en
                                ; geen keywords detecteren.
Dmode    db 0                   ; DATA of REM gevonden - rest van regel negeren
                                ; In pass 1:
                                ; 1=gevonden - geen spaties verwijderen
                                ; 3=zojuist gevonden, eventueel eerste spatie
                                ; verwijderen.
Omode    db 0                   ; ON gevonden: GOTO en GOSUB krijgen 2 spaties

ParmSet  label byte             ; tabel met flags van slash-parameters.
SParm    db 0                   ; /R = Source ook weergeven op scherm
NParm    db 0                   ; /N = Niets weergeven (tenzij /R gegeven)

         ;--------------------------------------------:
         ;                  tabellen                  :
         ;--------------------------------------------:
         
         ; Bij de hierna volgende tabel is enige uitleg op zijn plaats.
         ; De tabel is ingedeeld in 3 groepen:
         ; - Sleutelwoorden waar noch voor, noch na het woord een spatie moet
         ;   komen te staan;
         ; - Sleutelwoorden waar een spatie achter moet komen te staan, en
         ; - Sleutelwoorden waar voor en achter het woord een spatie moet komen
         ;   te staan.
         ; Elke "plaats" in de tabel omvat een sleutelwoord, voorafgegaan door
         ; zijn lengte.
         ; De sleutelwoorden zonder spaties zijn er niet voor niets.
         ; Als je 'PRINT:' uit de tabel zou weglaten, dan zou er achter een
         ; 'loze' PRINT in het programma ook een spatie terechtkomen.
         ; Dat geldt ook voor 'NEXT:', hoewel dat in BASICODE 3 niet voorkomt
         ; STOP en RESTORE zijn in de lijst gezet, omdat in allebei het 
         ; sleutelwoord TO voorkomt.
         ; De woorden GOTO en GOSUB zijn apart gemerkt, want die krijgen 2
         ; spaties als ze voorafgegaan worden door ON.
         ; REM en DATA schakelen een speciale flag in, waardoor de computer
         ; de rest van de regel (na die REM of DATA, dus) negeert.
         ; Dat betekent dat daar geen spaties uit het originele programma
         ; hoeven te worden verwijderd.
         ; De tabel wordt beeindigd met een 0 als lengte-byte.
         ; Let op dat de synchronisatie in orde is! Als je een keyword toevoegt
         ; en je hebt de lengte niet goed opgegeven, dan krijg je de gekste
         ; effekten.
         ; De labels EindSp en DublSp geven aan waar de keywords met 1 resp.
         ; 2 spaties beginnen.
         ; Natuurlijk moeten de drie groepen in volgorde blijven staan!
         ; Hier moet nog vermeld worden dat de keywords 'NEXT:' en 'STOP'
         ; VERBODEN zijn in Basicode 3.
         ; Eventueel kan 'ELSE' toegevoegd worden als U ook non-BASICODE
         ; programma's verwacht

         ; zonder spaties
Keywords db 6,'PRINT:',5,'NEXT:',4,'STOP',7,'RESTORE'
         
         ; met eindspaties
         db 3
EindSp   db 'FOR',4,'NEXT',5,'INPUT',3,'DIM',4,'READ',3,'LET'
         db 2,'IF',5,'PRINT',3,'NOT',4
GOTO     db 'GOTO',5
GOSUB    db 'GOSUB',2
ON       db 'ON',3
REM      db 'REM',4
DATA     db 'DATA'
         
         db 2
DublSp   db 'TO',4,'STEP',4,'THEN'
         ; db 4,'ELSE'
         db 3,'AND',2,'OR',0

         ;--------------------------------------------:
         ;             Lage-niveau routines           :
         ;           (Oftewel Sub-subroutines)        :
         ;--------------------------------------------:

         ;
         ; In deze routines worden alle registers bewaard, tenzij anders
         ; aangegeven.
         ;

ClosAl   proc near
         ;
         ; Sluit eventueel files.
         ;

         push ax
         push bx
         push dx

         ; Source file geopend? dan sluiten
         cmp SourceF,0
         je OK8
         mov bx,SourceF
         mov ah,3E
         int 21                 ; close file

         ; Temporary file geopend? dan eerst sluiten, daarna verwijderen
OK8:     cmp DestF,0
         je OK9
         mov bx,DestF
         mov ah,3E
         int 21
         mov dx,offset TMPNaam
         mov ah,41              ; delete (temporary) file
         int 21

         pop dx
         pop bx
         pop ax
         ret
ClosAl   endp

Error    proc near
         ;
         ; Sluit eventueel files, drukt tekst vanaf [DX] af en stopt programma
         ;
         ; Deze routine aanroepen met een JMP instructie.
         ;

         push dx
         call ClosAl

         ; Boodschap afdrukken
OK9:     mov dx,offset CRLF     ; Eerst Cr,Lf printen
         mov ah,9
         int 21
         pop dx
         mov ah,9
         int 21

         ; einde programma
         int 20
Error    endp     

Break    proc far
         ;
         ; Deze routine handelt Ctrl-Break af. Als deze combinatie wordt ge-
         ; drukt tijdens het programma, worden de files gesloten en het pro-
         ; gramma afgebroken.
         ;

         push ds

         push cs
         pop ds
         call ClosAl

         pop ds
         stc                    ; Breek programma af - zie DOS tech ref
         ret
Break    endp

ParmErr  proc near
         ;
         ; Fout in parameters. Aanroepen met JMP
         ;
         mov dx,offset ParmMsg
         jmp Error
ParmErr  endp

IOErr    proc near
         ;
         ; DOS fout. Aanroepen met JMP
         ;
         mov dx,offset IOMsg
         jmp Error
IOErr    endp

FileErr  proc near
         ;
         ; Wordt gegenereerd als de Source-file geen Basicode programma
         ; blijkt te zijn. Aanroepen met JMP
         ;
         mov dx,offset FileMsg
         jmp Error
FileErr  endp

DosErr   proc near
         ;
         ; Foute DOS versie. Aanroepen met JMP
         ;
         mov dx,offset DosMsg
         jmp Error
DosErr   endp

ReadBlok proc near
         ;
         ; Leest een blok in de Buffer vanuit de Source file.
         ; Het niet gebruikte gedeelte van de buffer wordt naar het begin
         ; van de buffer geschoven. De offset van het eerste ongebruikte byte
         ; staat in InOfs.
         ; Als het einde van de file (de staart) zich al in de buffer bevindt,
         ; dan zal EOFOfs de eerste positie na het einde bevatten.
         ; Met andere woorden: als EOFOfs=0, dan is de file helemaal verwerkt
         ; en kan EOFFlag op 1 gezet worden.
         ; Na afloop wordt InOfs bijgewerkt.
         ; Gaat er iets mis, dan gebeurt er een I/O error.
         ;

         push ax
         push bx
         push cx
         push dx
         push si
         push di

         ; Verplaats eventueel ongebruikte deel van de buffer
         mov cx,BufLen          ; bereken aantal te verplaatsen bytes
         sub cx,InOfs
         jcxz OK12              ; is nul? dan niets verplaatsen.
         mov di,offset Buffer   ; verplaats naar begin van buffer
         mov si,di
         add si,InOfs           ; van [Buffer+InOfs]
         mov ax,si
         sub ax,di
         push ax
         push cx
         rep movsb              ; Doe verplaatsing
         pop cx                 ; recover aantal verplaatste bytes
         pop ax

         ; bereken offset voor en lengte van het in te lezen stuk file.
         ; Op de plaats van het eerste in te lezen byte wordt van tevoren
         ; een Carriage Return gezet. Als het einde van de file nog niet
         ; is bereikt, dan wordt deze dus overgeschreven, maar anders
         ; wordt de actie onmiddellijk afgebroken door die CR,
         ; aangezien het halve programma daar steeds op controleert.
OK12:    mov InOfs,cx           ; Sla aantal verplaatste bytes even op. 
         mov dx,cx
         add dx,offset Buffer
         mov bx,dx
         mov byte ptr [bx],0Dh
         mov cx,BufLen
         sub cx,InOfs           ; aantal bytes inlezen=BufLen-InOfs

         ; Moeten we eigenlijk wel inlezen uit de file? of hoeven we alleen
         ; EOFOfs te veranderen?
         cmp EOFOfs,Buflen
         je OK12A
         sub EOFOfs,ax
         mov ax,cx              ; zodat hieronder altijd naar OK14 wordt ge-
         jmp short OK13         ; sprongen

         ; Inlezen uit file
OK12A:   push dx
         mov bx,Sourcef
         mov ah,3F
         int 21                 ; read file
         pop dx
         jnc OK13
         jmp IOErr

         ; Als de staart de buffer inloopt, wordt EOFOfs goed gezet
OK13:    mov InOfs,0
         cmp ax,cx
         je OK14                ; springt altijd als staart al in de Buffer zit
         add dx,ax              ; Dit wordt dus alleen uitgevoerd als de staart
         sub dx,offset Buffer   ; de EERSTE KEER in de buffer zit.
         mov EOFOfs,dx

         ; Eventueel EOFFlag setten.
OK14:    cmp EOFOfs,0
         jne OK14A
         mov EOFFlag,1

         ; Einde.
OK14A:   pop di
         pop si
         pop dx
         pop cx
         pop bx
         pop ax
         ret
ReadBlok endp

WritBlok proc near
         ;
         ; Schrijf Output Buffer weg naar Destination file.
         ; Uitgegaan wordt van de lengte aangegeven in OutWLen.
         ; Na afloop wordt deze op 0 gezet. Gaat er iets mis, dan gebeurt er
         ; een I/O fout.
         ;

         push ax
         push bx
         push cx
         push dx

         ; Zet registers goed en schrijf weg
         mov bx,DestF
         mov dx,offset OutBuf
         mov cx,OutWLen
         xor ax,ax              ; voor controle als cx=0
         cmp cx,0
         je OK15
         mov ah,40              ; write file
         int 21
         jnc OK15
OK16:    jmp IOErr

OK15:    cmp ax,cx              ; aantal weggeschreven bytes OK?
         jne OK16
         mov OutWLen,0

         ; Einde.
         pop dx
         pop cx
         pop bx
         pop ax
         ret
WritBlok endp

ReadByte proc near
         ;
         ; Leest een byte uit de source file. Eerst wordt geprobeerd een byte
         ; uit de buffer te lezen. Als het vorige karakter een CR was,
         ; dan wordt een nieuw blok ingelezen. 
         ; Als er geen CR werd gevonden, dan wordt CY op 1 gezet, en wordt
         ; BCFlag op 0 gezet.
         ;

         push bx

         ; Zitten er nog bytes in de buffer? Als de buffer leeggelezen is,
         ; dan is dit blijkbaar geen geldig programma en wordt dus BCFlag
         ; gereset. Ook wordt dan de CF geset, om aan te geven dat er iets
         ; niet klopt. De aanroeper moet de rest dan maar zelf uitzoeken.
         mov bx,InOfs
         cmp bx,BufLen
         jb OK17
         stc
         and BCFlag,0           ; reset validity flag
         jmp short OK18

         ; Einde van de file (zonder EOF karakter)?
OK17:    cmp bx,EofOfs
         jb OK17A
         mov al,26d             ; verander in EOF karakter
         jmp OK20

         ; Er zitten nog bytes in de buffer - inlezen.
OK17A:   mov al,[bx+Buffer]
         and al,7F

         ; De teller die aangeeft waar het volgende byte moet worden gelezen,
         ; wordt opgehoogd.
         inc bx
         mov InOfs,bx

         ; Lees een nieuw blok in aan het einde van een regel
         cmp al,13d             ; CR? dan blok inlezen
         jne OK20
         call ReadBlok
         jmp short OK22

         ; Als het ingelezen byte een EOF karakter is, dan was dit het laatste
         ; karakter van de file. Dat MOET wel een CR zijn (zie ook ReadBlok)
         ; en wordt dus vervangen.
OK20:    cmp al,26d             ; EOF? dan vervangen door CR
         jne OK22
         mov al,13d
         mov EofFlag,1

OK22:    clc

         ; Einde.
OK18:    pop bx
         ret
ReadByte endp

WriteScr proc near
         ;
         ; Schrijft een karakter naar het scherm
         ;

         cmp al,1A              ; EOF-karakter wordt een pijltje
         je GeenScr             ; en dat wil ik niet

         push dx
         push ax

         mov dl,al
         mov ah,2
         int 21

         pop ax
         pop dx

GeenScr: ret
WriteScr endp

WritByte proc near
         ;
         ; Schrijft het byte in AL weg in de Output buffer.
         ; Was het een LF of is de buffer vol, dan wordt de inhoud
         ; weggeschreven.
         ;

         push ax

         ; Buffer vol? zo ja, dan wegschrijven.
         cmp OutWLen,OutLen
         jb OK24
         call WritBlok

         ; zet byte in buffer
OK24:    push bx
         mov bx,OutWLen
         mov [bx+OutBuf],al

         ; Complete source weergeven? dan byte ook naar scherm
         cmp SParm,0
         je OK24A
         call WriteScr

OK24A:   pop bx
         inc OutWLen

         ; Ook wegschrijven na een LF
         cmp al,0A
         jne OK30
         call WritBlok

         ; Einde.
OK30:    pop ax
         ret
WritByte endp

WriteInt proc near
         ;
         ; Schrijft een byte naar de Intermediate Buffer. Als de buffer vol is,
         ; wordt BCFlag gereset.
         ;

         ; Is de buffer vol? Dan is de regel te lang en het programma is
         ; blijkbaar niet in Basicode. Reset dus BCFlag en negeer de aanroep.
         cmp IntWLen,IntLen
         jb NietVol
         and BCFlag,0
         jmp short BufVol

         ; Is de buffer nog niet vol, dan kan het byte gewoon weggezet worden.
NietVol: push bx
         mov bx,IntWLen
         mov [bx+IntBuf],al
         inc IntWLen

         ; Einde.
         pop bx
BufVol:  ret
WriteInt endp

ReadInt  proc near
         ;
         ; Leest een byte uit de Intermediate Buffer.
         ; Als er geprobeerd wordt te lezen na het einde van de buffer, dan
         ; wordt er CR geretourneerd
         ;

         push bx

         ; Is de buffer leeggelezen? geef dan een Carriage Return als 
         ; resultaat.
         mov bx,IntOfs
         cmp bx,IntWLen
         mov al,0Dh
         je EindInt

         ; Schrijf het byte in de buffer en verhoog de teller
         mov al,[bx+IntBuf]
         inc IntOfs

         ; Einde.
EindInt: pop bx
         ret
ReadInt  endp

Transfer proc near
         ;
         ; Schrijft Intermediate Buffer weg, met toevoeging van een LF na de CR
         ;
         ; Deze routine wordt gebruikt als er een Input Buffer Overflow
         ; gebeurt. De hele Intermediate Buffer wordt dan naar de file 
         ; geschreven.

         push cx
         push si

         ; Bereken begin-offset en lengte
         mov cx,IntWLen
         mov si,offset IntBuf

         ; Schrijf weg
LP5:     lodsb
         call WritByte
         loop LP5

         ; Controleer of de schrijf-actie is afgerond met een CR,LF.
         ; Een LF moet altijd worden toegevoegd, want in het Basicode programma
         ; zitten geen Line Feeds.
         cmp al,13d             ; Is er al een CR geschreven? dan alleen LF
         je WriteLF
         mov al,13d             ; anders ook CR
         call WritByte
WriteLF: mov al,10d
         call WritByte

         ; Einde.
         pop si
         pop cx
         mov IntOfs,0
         mov IntWLen,0
         ret
Transfer endp

         ;--------------------------------------------:
         ;                Subroutines                 :
         ;--------------------------------------------:

         ; In deze routines worden geen registers bewaard, tenzij anders
         ; aangegeven.

ZoekPrms proc near
         ;
         ; Zoekt slash-parameters
         ;

         ; Zoek naar een slash ('/')
         mov di,offset parms
         mov cl,ParmLen
         xor ch,ch
         mov al,'/'
ParmLP:  repne scasb
         jne GeenPrms

         ; Gevonden? dan controleren welke het is
         mov al,[di]
         push di
         push cx
         mov di,offset ParmTbl
         mov cl,AantPmM
         repne scasb
         jne FoutePrm

         ; Is het een geldige parameter? dan opslaan
         dec di
         sub di,offset ParmTbl
         shr di,1               ; voor Upper en Lower case
         mov byte ptr [ParmSet+di],1

         ; Zijn er nog meer parameters?
FoutePrm:pop cx
         pop di
         jmp ParmLP

         ; Geen parameters (meer) - terug
GeenPrms:ret
ZoekPrms endp

ZoekNamn proc near
         ;
         ; Zoekt naar de namen van Source en Destination file in de parameters
         ;
         ; De naam van de Destination file wordt gekopieerd in DestNaam.
         ; Dat moet, omdat het Parameter-gebied overgeschreven wordt. (Dat
         ; is immers ook het Disk Transfer Area.)
         ; De offset van de Sourcefilenaam wordt doorgegeven in DX. Die wordt
         ; maar 1 keer gebruikt, dus die hoeft niet naar het programma door-
         ; gegeven te worden.
         ;

         ; Zoek naam van Source file
         mov di,offset Parms
         mov cl,ParmLen
         xor ch,ch
         mov al,' '
         repe scasb             ; zoek eerste teken van SourceNaam
         pushf                  ; corrigeer DI en CX
         dec di
         inc cx
         popf
         jne OK2
OK3:     jmp ParmErr
OK2:     mov dx,di
OK2A:    repne scasb            ; zoek laatste teken van SourceNaam
         jne OK3A
         pushf                  ; corrigeer
         dec di                 ; cx wordt niet gecorrigeerd; dat zou meteen
         popf                   ; weer ongedaan moeten worden gemaakt hieronder
OK3A:    mov byte ptr [di],0    ; is een ASCIIZ string, dus voeg 0 toe.
         inc di                 ; 1 plaats verder. (geen DEC CX - zie boven)
         jcxz EenParm           ; 1 parameter - dan sourcenaam kopieren

         ; Zoek naam voor destination file
         repe scasb             ; zoek eerste teken van DestinationNaam
         pushf
         dec di
         inc cx
         popf
         je OK3
         cmp byte ptr [di],'/'  ; slash-parameter is geen filenaam
         je OK2A                ; dus zoek einde van parameter en dan filenaam
         push di                ; sla begin-offset op
         repne scasb            ; zoek laatste teken DestinationNaam
         jcxz OK28
         dec di
OK28:    pop si
         jmp short OK28A

         ; Als er maar 1 parameter gegeven werd, betekent dat, dat
         ; DestNaam hetzelfde wordt als SourceNaam
         ; DI bevat nog steeds het einde van de sourcenaam
EenParm: mov si,dx              ; begin-offset in si

         ; Op dit punt geldt: SI=begin van destnaam, DI=einde van destnaam
         ; Destination-naam gevonden? dan kopieren naar programma
         ; Let erop dat de naam 2 bytes verder moet komen als er een drive
         ; voor de destination is opgegeven. Dit laatste wordt in het
         ; hoofdprogramma uitgezocht, want DOS geeft dat keurig netjes door
         ; als het programma begint.
OK28A:   mov cx,di              ; lengte bepalen
         sub cx,si
         cmp cx,40
         jb OK4
         mov cx,3F
OK4:     mov di,offset DestNaam ; verplaatsen naar programma
         cmp byte ptr [di],0
         je OK4A                ; is er een drive ingevuld?
         add di,2
OK4A:    rep movsb              ; doe verplaatsing

         ; Einde
         ret
ZoekNamn endp

OpenSrc  proc near
         ;
         ; Open Source file en lees lengte
         ;
         ; DX moet het adres bevatten van de naam van de file.

         ; Open file
         mov ax,3D00            ; Open file for read
         int 21
         jnc OK5
         jmp IOErr

         ; Sla File-handle op
OK5:     mov SourceF,ax
         
         ; Einde
         ret
OpenSrc  endp

OpenDest proc near
         ;
         ; De Destination file wordt geopend om te controleren of de naam
         ; geldig is. Wordt hij niet gevonden, dan wordt hij gemaakt en
         ; uitgewist, om dezelfde reden.
         ;
         ; Er wordt een Temporary file geopend op de drive die
         ; aangegeven wordt door de naam van de Destination file. 
         ; Aan het einde van het programma krijgt de Temporary file de naam
         ; van de destination file.
         ;

         mov dx,offset DestNaam
         xor cx,cx
         mov ax,3D01            ; openen voor schrijven
         int 21
         jc OK25                ; openen niet gelukt? probeer dan te maken

         ; close file
         mov bx,ax
         mov ah,3E
         int 21
         jnc OK27
         jmp IOErr

         ; Openen niet gelukt; probeer file te creeeren
OK25:    mov dx,offset DestNaam
         mov ah,3C
         int 21
         jnc OK25A
         jmp ParmErr

         ; wis de zojuist gemaakte file uit
OK25A:   mov bx,ax
         mov ah,3Eh             ; close file
         int 21
         jnc OK26
         jmp IOErr
OK26:    mov dx,offset DestNaam ; Delete file
         mov ah,41
         int 21
         jnc OK27
         jmp IOErr

         ; Maak nu een Temporary file (dit kan alleen vanaf DOS 3.00)
OK27:    mov dx,offset TMPNaam
         xor cx,cx
         mov ah,5A              ; Create temporary file
         int 21
         jnc OK7
         jmp IOErr

         ; File-handle opslaan
OK7:     mov DestF,ax

         ; Einde.
         ret
OpenDest endp

Vertaal  proc near
         ;
         ; Deze routine verricht het zware werk.
         ; Er wordt 1 regel van de source file vertaald, en wel als volgt:
         ; - Het regelnummer wordt direct weggeschreven.
         ; - De rest van de regel wordt ingelezen tot een CR gevonden wordt.
         ;   Alle tekens in opdrachten worden vertaald naar Upper Case,
         ;   alle foute Control-karakters worden vertaald naar Lower Case.
         ; - Dan wordt de regel teken voor teken afgescand naar Keywords.
         ;   Wordt er een gevonden dan worden er spaties in de output-buf-
         ;   fer gezet.
         ; - Als een CR wordt gevonden, dan wordt er een CR,LF aan de Output-
         ;   buffer toegevoegd.
         ; De routine keert terug als dit gebeurd is.
         ;

         ; ==== PASS 1 ====

         ; In Pass 1 wordt de regel overgezet in de Intermediate Buffer.
         ; Daarbij worden spaties verwijderd (waar dat nodig en mogelijk is)
         ; Ook worden (waar nodig en mogelijk) transmissiefouten ge-
         ; elimineerd en de tekens naar Upper Case vertaald.

         mov Qmode,0
         mov Dmode,0

         call ReadByte
         cmp EofFlag,0
         je BeginVrt
         jmp VertEind

         ; Lees regelnummer+spatie. Deze worden rechtstreeks weggeschreven
LP3:     call ReadByte          ; lees byte

BeginVrt:cmp al,'0'
         jb OK102AA
         cmp al,'9'
         ja OK102AA
         call WritByte

         cmp SParm,0            ; controleer of het regelnummer moet worden
         jne LP3                ; weggeschreven naar het scherm. Dat hoeft
         cmp NParm,0            ; niet als NParm of SParm 1 is. Als NParm
         jne LP3                ; 1 is, hoeft er niets te worden afgedrukt
         call WriteScr          ; en als SParm 1 is, wordt alles in de WritByte
                                ; procedure afgedrukt.
         jmp LP3
      
         ; We hebben het regelnummer gehad. Er moet nu hoe dan ook een spatie
         ; weggeschreven worden.
OK102AA: push ax
         mov al,' '
         call WritByte
         pop ax

         ; stond er een spatie achter het regelnummer?
         ; lees dan het volgende byte in
         cmp al,' '
         jne OK102A
         call ReadByte

         ; nieuwe regel op scherm (indien nodig)
OK102A:  cmp SParm,0
         jne OK101
         cmp NParm,0
         jne OK101
         push ax
         mov al,13d
         call WriteScr
         pop ax
         jmp short OK101

         ; Lees rest van regel; strip spaties en maak hoofdletters
LP4:     call ReadByte
         jnc OK101              ; Geen overflow? dan verder

         ; In geval van Buffer Overflow wordt volgende code uitgevoerd:
         call Transfer
         call ReadBlok
         and BCFlag,0           ; reset validity flag
         
         cmp EOFFlag,0
         je LP6
         jmp VertEind
         
LP6:     call ReadByte          ; lees rest van regel in en gooi weg
         jnc OK102
         call ReadBlok

         cmp EOFFlag,0
         je OK102
         jmp VertEind

OK102:   cmp al,13d
         jne LP6
         jmp VertEind

         ; Einde van instrukties voor buffer-overflow

         ; Controle op spatie.
OK101:   cmp al,' '             ; geen spatie? Dan hoeft-ie niet te worden
         jne GeenSPC            ; weggehaald

         ; spatie-controle wordt alleen in bepaalde gevallen uitgevoerd
         cmp Qmode,0
         jne GeenSPC
         cmp Dmode,1            ; alleen verwijderen als Dmode<>1
                                ; (Dmode wordt van 3 op 1 gezet bij de eerste
                                ; non-spatie achter de REM of DATA)
         je GeenSPC

         jmp Next1A             ; Dmode niet op 1 zetten

         ; Eventueel vertalen naar Upper Case
GeenSPC: cmp Qmode,0            ; Vertalen naar Upper Case nodig?
         jne OverUpC
         cmp Dmode,0
         jne OverUpC

         cmp al,'a'
         jb OverUpC
         cmp al,'z'
         ja OverUpC
         sub al,20

         ; Control-tekens ongelijk aan CR worden naar een Lower Case
         ; karakter vertaald, zodat ze duidelijk als transmissiefout
         ; herkenbaar zijn.
OverUpC: cmp al,13d
         je Schrijf
         cmp al,20
         jae Schrijf
         add al,'a'-1           ; Foute Ctrl-karakters naar LC vertalen

         ; Het zo bewerkte teken tenslotte wegschrijven
Schrijf: call WriteInt          ; Schrijf teken in Intermediate buffer

         ; Nu nog controleren of een van de modes aan of uit gezet moeten 
         ; worden.
         ; Eerst de Quote mode.
         cmp al,'"'             ; Quote? dan Qmode omschakelen
         jne OK103
         xor Qmode,1

         ; Data mode
OK103:   cmp Dmode,0
         jne Next1              ; Geen controle als REM of DATA al gevonden

         cmp IntWLen,3          ; was dit REM of DATA? dan Dmode aan
         jb Next1
         
         mov si,IntWLen
         add si,offset IntBuf-3 ; si=offset laatste 3 tekens
         push si
         mov di,offset REM
         mov cx,3
         repe cmpsb
         
         pop si
         jne OK104
         mov Dmode,3
         jmp short Next1A

OK104:   dec si
         mov di,offset DATA
         mov cx,4
         repe cmpsb
         jne Next1
         mov Dmode,3
         jmp short Next1A

Next1:   and Dmode,1            ; als Dmode 3 was, wordt die nu 1, zodat
                                ; alleen de eventuele direct volgende
                                ; spaties worden verwijderd
Next1A:  cmp al,13d
         je Pass2
         jmp LP4

         ; ==== Pass 2 ====

         ; In Pass 2 worden (waar nodig) spaties ingevoegd, lettend op de 
         ; sleutelwoorden in de Keywords-tabel. 
         ; De bytes worden een voor een ingelezen en er wordt per byte ge-
         ; controleerd op het begin van een Keyword.
         ; Er zijn ook andere zoek-algoritmen mogelijk, maar die zijn een
         ; stuk ingewikkelder. Ik vond hier de snelheid van het programmeren
         ; belangrijker dan de snelheid van het programma. Mocht je er anders
         ; over denken, ga dan gerust je gang.

Pass2:   mov IntOfs,0
         mov Qmode,0
         mov Dmode,0
         mov Omode,0

         ; controleer op keywords en voeg evt. spaties in.
LP7:     cmp Qmode,0            ; moeten we wel controleren?
         je OK105
         jmp GeenKeyW
         
OK105:   cmp Dmode,0
         je OK106
         jmp GeenKeyW

         ; Deze "pleun" doet de controle op keywords.
OK106:   mov bx,offset Keywords ; [BX]=lengte eerste keyword
         mov di,IntOfs          ; DI=offset in IntBuf
         push di                ; sla op
LP8:     lea si,[bx+1]          ; SI=offset huidige Keyword
         pop di                 ; lees offset van huidige teken terug
         push di                ; en terug opslaan
         mov ax,di              ; bereken eindoffset in IntBuf
         add al,[bx]
         adc ah,0
         cmp ax,IntWLen         ; is Keyword langer dan wat er nog moet komen?
         ja Next2               ; ja- zoek verder
         add di,offset IntBuf   ; bereken adres
         mov cl,[bx]            ; bereken lengte
         xor ch,ch
         repe cmpsb             ; is keyword?
         je KeyWFnd             ; ja-loop verlaten
         
Next2:   add bl,[bx]            ; BX=offset van volgende keyword
         adc bh,0
         inc bx
         cmp byte ptr [bx],0    ; Alle keywords gehad?
         jne LP8                ; nee-controleer
         pop di                 ; herstel stack
         jmp GeenKeyW           ; verder

         ; Keyword gevonden
KeyWFnd: pop di                 ; herstel stack en beginadres
         inc BX
         
         ; We hebben een Keyword gevonden.
         ; BX is nu de offset van het keyword en DI is nu de offset in IntBuf.
         ; Nu gaan we spaties invoegen, aan de hand van de groep waarin
         ; het keyword stond. Hier wordt ook het belang van de volgorde
         ; van de drie groepen duidelijk.
         cmp bx,offset DublSp   ; Moet er een beginspatie komen?
         jae BeginSP
         cmp Omode,0            ; of staat de ONmode aan en is het woord een
         je GeenBSP             ; GOTO of GOSUB?
         cmp bx,offset GOTO
         je BeginSP
         cmp bx,offset GOSUB
         jne GeenBSP            ; voeg dan een beginspatie toe

BeginSP: mov al,' '
         call WritByte

GeenBSP: mov cl,[BX-1]          ; schrijf het keyword weg
         xor ch,ch

LP9:     call ReadInt
         call WritByte
         loop LP9

         cmp bx,offset EindSp   ; eindspatie toevoegen?
         jb GeenSP
         mov al,' '             ; ja - doen
         call WritByte

         ; Nu nog even controleren of een van de Modes aan of uit moeten
GeenSP:  cmp bx,offset ON
         jne OK107
         mov Omode,1
         
OK107:   cmp bx,offset REM
         je OK108
         cmp bx,offset DATA
         jne OK109

OK108:   mov Dmode,1
OK109:   jmp Next3

         ; Geen Keyword gevonden? dan controleren op aanhalingstekens,
         ; dubbele punt enz.
GeenKeyW:call ReadInt
         cmp al,'"'             ; quote? dan Qmode omschakelen
         jne OK110
         xor Qmode,1

OK110:   cmp Qmode,0
         jne GeenClCK           ; Qmode? dan geen ':' controleren
         cmp Dmode,0
         jne GeenClCK

         cmp al,':'             ; na een dubbele punt moet OMode uit
         jne GeenClCK
         mov Omode,0

GeenClCK:call WritByte          ; schrijf 1 byte weg
         
         ; Einde Pass 2. Zijn we aan het einde van de regel? zo nee-volgende
Next3:   cmp al,13d             ; Einde van de regel?
         je VertEnd2            
         jmp LP7                ; nee- volgende karakter

         ; regel-einde: voeg LF toe.
VertEnd2:mov al,10d
         call WritByte

         ; Einde routine
VertEind:mov IntWLen,0
         ret
Vertaal  endp

Rename   proc near
         ;
         ; Sluit source en TMP file; Zorg er dan voor dat er geen file
         ; met naam DestNaam bestaat. Daarna een Rename uitvoeren van TMPnaam
         ; naar DESTnaam. Mislukt dit, dan wordt er een I/O fout gegeven, maar
         ; de Temporary file wordt NIET gewist.
         ;

         ; schrijf EOF karakter naar de file
         call WritBlok          ; zorg ervoor dat EOF altijd weggeschreven
                                ; wordt.
         mov al,1Ah             ; Bij mij was een EOF wel niet nodig, maar
         call WritByte          ; officieel wel.
         call WritBlok          ; schrijf eerst laatste blok weg

         ; sluit source file
         mov bx,SourceF
         mov SourceF,0
         mov ah,3E
         int 21
         jnc OK29A
RenErr:  jmp IOErr

         ; sluit temporary file
OK29A:   mov bx,DestF
         mov DestF,0
         mov ah,3E              ; close file
         int 21
         jc RenErr

         ; creeer Destnaam en wis hem dan weer uit
         mov dx,offset DestNaam
         mov cx,0
         mov ah,3C              ; create file
         int 21
         jc RenErr

         mov bx,ax
         mov ah,3E              ; close file
         int 21
         jc RenErr

         mov dx,offset DestNaam
         mov ah,41              ; delete file
         int 21
         jc RenErr

         ; rename temporary file naar Destination-naam
         mov dx,offset TMPNaam
         mov di,offset DestNaam
         mov ah,56              ; rename file
         int 21
         jc RenErr

         ; Einde.
OK31:    ret
Rename   endp

         ;--------------------------------------------:
         ;                 Hoofdroutine               :
         ;--------------------------------------------:

Main     proc near

         ; Is er expliciet een drive opgegeven in de destination file?
         ; zo ja, dan moet deze worden overgenomen in de File Specificatie
         ; voor de Temporary file. Het is immers niet mogelijk een Rename
         ; over disks uit te voeren.
         cmp ah,0FF
         jne OK6A
         jmp ParmErr

OK6A:    cmp Drive2,0
         je OK6
         mov al,Drive2
         add al,'A'-1
         mov TMPNaam,al
         mov byte ptr TMPNaam+1,':'

         ; Alle string-acties zijn vooruit, dus laten we dat maar meteen 
         ; regelen.
OK6:     cld

         ; Is dit een goede DOS versie?
         mov ah,30
         int 21
         cmp al,3
         jae OK6B
         jmp DOSErr

         ; Het hoofdprogramma.
OK6B:    mov dx,offset Break    ; Eerst Ctrl-Break vector goed zetten
         mov ax,2523            ; (oude vector hoeft niet bewaard)
         int 21

         call ZoekPrms          ; kijk of er '/' parameters gegeven zijn.
         call ZoekNamn          ; Lees parameters in.
         call OpenSrc           ; open source file
         call OpenDest          ; controleer destination naam en open TMP file
         call ReadBlok          ; lees eerste blok uit source file
         call WritBlok          ; schrijf CHAIN-regel weg

         ; Is de file leeg? dan afbreken met een BASICODE fout
LP1:     cmp EOFFlag,0
         je OK21
         jmp FileErr

         ; Lees nu net zo lang bytes in tot er een numeriek teken wordt
         ; gevonden. Sommige Basicode vertaalprogramma's hebben de eigen-
         ; schap dat ze eerst een 0 of een CR in de file zetten o.i.d.
         ; en dat kunnen (lees: moeten) we wel even oppoetsen.
OK21:    call ReadByte
         jnc OK19
         jmp FileErr            ; Geen CR gevonden in buffer? dan is dit
OK19:    cmp al,'0'             ; geen BC file
         jb LP1
         cmp al,'9'
         ja LP1

         cmp SParm,0
         jne OK19A
         cmp NParm,0
         jne OK19A
         call WriteScr

OK19A:   call WritByte          ; eerste numerieke teken moet weggeschreven.

         ; Hoofd-loop. Vertaal net zo lang regels tot de file op is.
LP2:     cmp EOFFlag,0
         jne OK1
         call Vertaal
         jmp LP2

         ; Einde.
OK1:     call Rename            ; sluit files, rename TMP naar Destination
         cmp BCFlag,0           ; geef nog een eindmelding als BCFlag onder-
         jne Einde              ; tussen is gereset.
         jmp FileErr

         ; EINDE van het programma.
Einde:   int 20
Main     endp

         ;--------------------------------------------:
         ;              Programma-einde               :
         ;--------------------------------------------:

Code     ends
         end Begin

