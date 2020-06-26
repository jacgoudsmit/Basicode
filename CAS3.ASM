                page
                page 60,132
                title CAS3 - BASICODE 3 cassette interface routines
                .radix 16

                comment @
                Dit programma is afgeleid van CAS.COM - door B.S.H. Niewold -
                voor BASICODE 2.
                Wijzigingen:
                - De logische struktuur is m.i. sterk verbeterd (geen JMP next
                  instructies meer behalve waar noodzakelijk enz.)
                - Alle data (behalve de teksten die alleen bij de initialisatie
                  nodig zijn) is naar het begin van de source verschoven, zodat
                  ik niet steeds BYTE PTR CS: enz. hoefde te tikken.
                - Voor Basicode 3 zijn bestands-verwerkings-routines
                  aangebracht.
                - De 'Set Mask' routine is verwijderd. Er wordt nu altijd met
                  een waarde 80 gewerkt, die met een XOR op de bytes wordt
                  losgelaten.
                - CAS controleert nu met een aanroep van INT 15h met AH=7 of
                  het al geladen is. Op deze manier kan ook de versie gecontro-
                  leerd worden.
                @

                ; VERSIE 1.01
                ; Wijzigingen:
                ; De motor moet nu in het geval van een printerpoort-interface
                ; aan poot 16 (Reset) vastgemaakt zijn. Dit heb ik gedaan
                ; omdat op mijn 2e printerpoort (die ik voor BC gebruik)
                ; geen poot 17 (select) zit.
                ; Overigens geeft de Get_Version call nog steeds versie 3.1.0!
                ; er is immers niets veranderd dat belangrijk genoeg was om
                ; een gedeeltelijke of geheel nieuwe versie te schrijven.

                ; VERSIE 1.02
                ; Wijziging:
                ; Omdat ik ontdekt heb dat niet alle printerpoorten geldige
                ; data geven op een IN instructie van de processor,
                ; is de routine SCHRIJFPRP zodanig veranderd, dat deze
                ; niet meer uitgaat van de momentele waarde van de printer-
                ; poort, maar van die van de cassettepoort.

                ; VERSIE 1.10
                ; Wijziging:
                ; De interface-informatie is weggehaald. Verder wat code-
                ; verbeteringen en ietwat gewijzigde installatie-routines.
                ; De installatie gebeurt nu wat meer automatisch

;============================================================================:
;                       Declaraties in BIOS data-segment                     :
;============================================================================:

biosdata        segment at 40
                org 8
printertabel    label word      ; tabel met adressen van printerpoorten
                org 67
hbit_cycles     label word
                org 71
breakflag       label byte
                org 6Bh
iobit           label byte
                org 69
checksum        label word
biosdata        ends

;============================================================================:
;                                 Code-segment                               :
;============================================================================:

code            segment
                assume cs:code,ds:biosdata

nuladres        equ 0

                ; parameters in DOS-commandoregel
                org 80
parms           label byte

                ; programma-begin
                org 100
begin:          jmp entry

;============================================================================:
;                                   Data                                     :
;============================================================================:

oldint15        dd 0            ; Pointer naar oude int. 15 routine
poort0          dw 0            ; Printer-interface: zie Techref p.1-71 (PC/XT)
                                ; PR0=latched I/O
                                ;     PR0-0=output naar interface
                                ; PR1=input rechtstreeks
                                ;     PR1-7=input van interface
                                ;     PR1-6=Interface ID Loop Input
                                ; PR2=latched I/O
                                ;     PR2-2=motor input/output
                                ;     PR0-0=Interface ID Loop Output
                                ;           (geinverteerd bij IN opcode)
                                ; De ID Loop is de verbinding die op de
                                ; printerpoort is aangebracht om aan te geven
                                ; dat de printer-interface is aangesloten.
printer         db 0FFh         ; Printer-flag en -poort
                                ; bit 2=printer gebruikt 1=ja 0=nee
                                ; bit 1,0=LPT nummer
                                ; 0FFh=niet geinitialiseerd
PC_ID           db 0            ; Computer ID byte. Hiermee wordt gecontro-
                                ; leerd welke poort gebruikt moet worden
                                ; voor de timer-uitgang loopback
BSTflag         db 0            ; flag voor bestandsbedrijf (0=programma)
blockno         db 0            ; Huidige blok voor BC3 bestanden.
STX             db 82           ; startbyte; 81 voor bestanden
EOT             db 0            ; flag als EOT (84) gevonden of weggeschreven
                                ; (BC3 bestanden)
BST_gelezen     dw ?            ; aantal ingelezen bytes in laatste bestands-
                                ; blok, of (bij inlezen compleet bestand)
                                ; tijdelijke opslag totaal ingelezen bytes
BST_BUFLEN      dw ?            ; opslag voor buffer-lengte
schermbytes     dw ?            ; opslag voor eerste bytes van scherm-
                                ; geheugens (BC leesroutines)

                ; routine met sprongadressen voor de routines
dispatch        dw motor,motor,read_ibm,write_ibm,read_bc,write_bc
                dw dummy_return,get_vsn,read_BC_BST,write_BC_BST,readblock

;============================================================================:
;                              Hoofdroutine                                  :
;============================================================================:

newint15        proc far
                sti
                cmp ah,0A       ; 10 services
                jbe code_ok
                jmp [oldint15]  ; fout nummer, laat de oude routines dat maar
                                ; uitzoeken.
code_ok:        push ds
                push ax
                mov ax,40
                mov ds,ax
                pop ax
                and breakflag,7F ; reset break flag
                mov al,ah
                cbw
                push si
                mov si,ax
                shl si,1
                xchg ah,al
                call dispatch[si]
                pop si
                pop ds
                ret 2
newint15        endp

;============================================================================:
;                                routines                                    :
;============================================================================:

                ; MOTOR schakelt motor in en uit
                ; on entry: AH=0 voor motor aan
                ;           AH=1 voor motor uit
                ; on exit:  CY=0 als alles ok
                ;           CY=1 en AH=10h als interface niet aangesloten
                ;           CY=1 en AH=86h als er geen cassette-routines zijn
                ;           DISABLE_MOTOR wordt op 0 gezet
motor           proc near
                push cx
                push dx
                mov cx,1F7
                test printer,4
                jz mrcas
                push ax
                call testpr     ; test of BC interface aanwezig
                jc mrret2       ; nee-dan terugkeren met melding
                pop ax
                mov dx,poort0
                add dx,2
                mov cl,0FBh     ; bit 2 voor printer-IF
mr1:            in al,dx
                and ax,cx       ; reset bit n en zorg dat AH goed is
                mov cl,3        ; bit 3 setten als ah=1 en cassette
                test printer,4
                jz mrcas2
                dec cl          ; bit 2 voor printer
mrcas2:         shl ah,cl       ; schuif bit 0 van AH naar bit n
                or al,ah        ; set bit n als ah=1
                out dx,al
                xor ah,ah       ; geen foutmelding
                jmp short mrret ; einde

mrcas:          mov dx,61       ; neem cassettepoort
                jmp mr1

mrret2:         pop dx          ; oude AX
mrret:          pop dx
                pop cx
                mov BSTflag,0
                mov STX,82
                ret
motor           endp

                ; DUMMY_RETURN
                ; Deze routine komt in de plaats van de SET_MASK routine in
                ; de BC2 versie van CAS.
                ; In dit programma wordt altijd met een waarde van 80h
                ; gewerkt, die dmv een XOR met de bytes in het geheugen/op
                ; band verbonden wordt.
dummy_return    proc near
                xor ah,ah
                clc
                ret
dummy_return    endp

                ; lees versienummer in AX en BC-interface segment in DX
                ; on exit:
                ;   AH=BASICODE versie (3)
                ;   AL hoge nibble=major versie van routines (1)
                ;      lage nibble=minor versie van routines (0)
                ;   DX=segment van BASICODE-routines.
                ;      Dit is dus niet compatible met programma's die
                ;      funktie 7 aanroepen om een andere reden.
                ;      (als het goed is, zijn die er niet)
                ; Als CY=1 en AH=86h, dan zijn de routines niet geladen, of er
                ; is een oudere versie dan BC3 V1.0 geladen
get_vsn         proc near
                mov ax,310
                mov dx,cs
                clc
                ret
get_vsn         endp

                ; READ_IBM
                ; Leest een IBM-formaat programma in (max. 64K)
                ; Hier heb ik niets aan veranderd - JG.
                ; on entry:
                ;   ES:BX=adres
                ;   CX=aantal bytes max. in te lezen
                ; on exit:
                ;   ES:BX=eerste geheugenplaats na ingelezen bytes
                ;   AH=error codes (als CY set, anders 0)
                ;      1=CRC error
                ;      2=data lost
                ;      4=not found (time-out)
                ;    10h=printer-interface niet aangesloten
                ;    86h=routines niet aanwezig (bijv. PC/XT, PC/AT)
                ; CX en DX vernietigd, rest bewaard
                ; Zoals gezegd zijn deze routines in de oude staat behouden,
                ; behalve dat de JMP NEXT instructies eruit zijn gehaald.
                ; (Dit bleek geen problemen op te leveren op mijn XT)
                ; Ik heb wel geprobeerd zoveel mogelijk weer te geven wat ik
                ; denk dat er gebeurt. Ik heb namelijk geen TechRef van de
                ; gewone PC (waaruit deze routines waarschijnlijk letterlijk
                ; zijn overgenomen).
read_ibm        proc near
                push bx         ; save adres
                push cx         ; save aantal bytes
                push si         ; save si
                mov si,7        ; 7 retries
                call motor_on   ; schakel motor in met vertraging
                jnc Isearch
                jmp Iabort

Isearch:        in al,62        ; sla originele waarde van 8255-P2-4 op
                and al,10       ;  als eerste iobit-waarde
                mov iobit,al
                mov dx,3f7a     ; teller
Isearchloop:    test breakflag,80 ; break gedrukt?
                jnz I1          ; ja-stoppen
                dec dx          ; time-out?
                jnz I2          ; nee-zoek
I1:             jmp Ibreak      ; stoppen na break of time-out

I2:             call leeshbit   ; lees een halve bit (hbit)
                jcxz Isearchloop ; time-out, dan verder zoeken
                mov dx,378      ; 888d ; 888/1.19E6=0.74 ms
                mov cx,200      ; min. aantal leader hbits voor lock-in
                in al,21        ; disable timer IRQ
                or al,1
                out 21,al
Ileaderloop:    test breakflag,80 ; break? dan stoppen
                jnz Ibreak
                push cx         ; teller opslaan
                call leeshbit   ; lees een halve bit
                or cx,cx        ; time-out?
                pop cx          ;     teller terug
                jz Isearch      ; dan verder zoeken
                cmp dx,bx       ;
                jcxz I_L_in     ; einde van leader verwacht? dan data zoeken
                jae Isearch     ; is leader-bit wel geldig? nee-verder zoeken
                loop Ileaderloop ; zoek naar einde van leader

I_L_in:         jb Ileaderloop  ; zoek verder als laatste hbit geen startbit
                call leeshbit   ; lees 2e halve bit van startbit
                call leesbyte_IBM ; lees eerste byte
                cmp al,16       ; 16=indicatie begin
                jne Inotfound   ; nee-volgende poging
                pop si          ; si terug
                pop cx          ; aantal bytes terug
                pop bx          ; adres terug
                push cx         ; teller opslaan

Ireadblock:     mov checksum,0FFFF ; init checksum
                mov dx,100      ; 256 bytes per blok
Iblockloop:     test breakflag,80 ; break?
                jnz Idatalost
                call leesbyte_IBM ; lees een byte
                jc Idatalost    ; fout? afbreken
                jcxz Iendblock  ; gevraagde bytes gelezen?
                mov es:[bx],al  ; sla byte op
                inc bx          ; een verder
                dec cx          ; volgende byte in blok
Iendblock:      dec dx          ; aantal gelezen
                jg Iblockloop   ; volgende byte inlezen
                call leesbyte_IBM ; lees stopbyte 1
                call leesbyte_IBM ; lees stopbyte 2
                sub ah,ah
                cmp checksum,1D0F ; checksum OK?
                jne ICRC_err    ; fout? indicatie CRC error
                jcxz IOK        ; gevraagde bytes gelezen?
                jmp Ireadblock  ; volgende blok

Idatalost:      mov ah,1
ICRC_err:       inc ah
IOK:            pop dx          ; teller teruglezen
                sub dx,cx
                push ax         ; error code?
                test ah,3
                jnz Ieinde
                call leesbyte_IBM
                jmp short Ieinde

Inotfound:      dec si
                jz Ibreak
                jmp Isearch

Ibreak:         pop si          ; si
                pop cx          ; aantal bytes
                pop bx          ; adres
                sub dx,dx
                mov ah,4        ; error 4
                push ax         ;
Ieinde:         in al,21        ; enable timer IRQ
                and al,0FE
                out 21,al
                call motor_off  ; motor uit
                pop ax          ; error code?
                cmp ah,1
                cmc             ; AH=0 => ok, anders CY=1
                ret             ; einde

Iabort:         pop si
                pop cx
                pop bx
                ret
read_ibm        endp

                ; WRITE_IBM
                ; Ook deze routine heb ik niet veranderd - JG.
                ; schrijft een stuk geheugen naar cassette in IBM formaat.
                ; on entry:
                ;   ES:BX=beginadres
                ;   CX=aantal bytes weg te schrijven.
                ; on exit:
                ;   ES:BX=eerste adres na weggeschreven data
                ;   AH=errorcodes (als CY=1, anders 0)
                ;      10h: interface niet aanwezig
                ;      86h: routines niet aanwezig
                ; CX en DX vernietigd, rest bewaard
write_ibm       proc near
                push bx         ; sla adres op
                push cx         ; en aantal bytes
                call motor_on   ; schakel motor in en wacht
                jnc WI1         ; ok-verder
                pop cx
                pop bx
                ret

WI1:            in al,61
                and al,0FDh     ; disable speaker
                or al,1         ; zet speakerdata op 1
                out 61,al
                mov al,10110110b ; counter 2; program LSB,MSB; blokgolf; bin
                out 43,al
                mov ax,4a0
                call schrijftimer ; programmeer voor 1000Hz blokgolf
                mov cx,800      ; teller voor leader
                in al,21        ; disable timer IRQ
                or al,1
                out 21,al
WIleaderloop:   stc             ; schrijf 1-bit
                call schrijfbitIBM
                loop WIleaderloop ; 800h keer
                clc
                call schrijfbitIBM ; startbit
                pop cx
                pop bx
                mov al,16       ; startbyte
                call schrijfbyteIBM
WIblockloop:    mov checksum,0FFFF ; init checksum; startbyte niet meerekenen
                mov dx,100      ; 256 bytes per blok
WIbyteloop:     mov al,es:[bx]  ; lees byte
                call schrijfbyteIBM ; schrijf weg
                jcxz WI5        ; laatste gehad?
                inc bx          ; volgende byte
                dec cx          ; schrijf-teller
WI5:            dec dx          ; lees-teller
                jg WIbyteloop   ; nog meer te schrijven? dan terug
                mov ax,checksum ; maak checksum klaar voor wegschrijven
                not ax
                push ax
                xchg ah,al
WI6:            call schrijfbyteIBM ; schrijf MSB checksum
                pop ax
                call schrijfbyteIBM ; schrijf LSB checksum
                or cx,cx        ; nog meer blokken?
                jnz WIblockloop
                push cx
                mov cx,20       ; trailer teller
WItrailerloop:  stc
                call schrijfbitIBM ; 1-bits
                loop WItrailerloop
                pop cx
                mov al,10110000b ; timer 2; program LSB,MSB; IOTC; bin
                out 43,al
                mov ax,1        ; waarde voor timer 2=1 (hoogste freq)
                call schrijftimer
                in al,21        ; enable timer IRQ
                and al,0FE
                out 21,al
                call motor_off  ; schakel motor uit
                sub ax,ax
                ret             ; einde
write_ibm       endp

                ; READ_BC
                ; Leest een BASICODE programma of bestands-blok.
                ; De default-instellingen zijn voor programma-operatie. Zie
                ; de bestandsroutines voor de instellingen voor bestanden.
                ; on entry:
                ;   ES:BX=adres
                ;   CX=max aantal bytes
                ; on exit:
                ;   ES:BX=eerste adres na ingelezen data
                ;   DX=werkelijk aantal gelezen bytes. Voor bestanden is dit
                ;      1024d (als het goed is), maar voor het laatste blok
                ;      wordt het geldige aantal in BST_gelezen opgeslagen.
                ;   AH=error code (als CY set, anders 0)
                ;      1=CRC error
                ;      2=data lost
                ;      4=not found (time out)
                ;      8=data over: meer bytes op tape dan gevraagd in CX
                ;    10h=interface niet aanwezig
                ;    86h=routines niet aanwezig
                ; CX vernietigd, rest bewaard.
                ; De basis van deze routine was de oude versie van CAS.
                ; (Daarvoor waren waarschijnlijk de IBM routines weer de basis)
                ; Er zijn echter invoegingen gedaan voor bestands-support.
                ; Het bleek dat die invoegingen geen invloed hebben op het in-
                ; lezen, wat betreft de tijd.
read_bc         proc near
                call screensave
                push bx         ; sla adres op
                push cx         ; sla aantal bytes op
                push si         ; sla si op
                mov si,7        ; voor synchronisatie
                call motor_on   ; schakel motor in en wacht
                jnc Bsearch
                jmp Babort      ; fout? dan stoppen

Bsearch:        in al,62        ; lees initiele cassettepoort-waarde
                and al,10
                mov iobit,al    ; sla op
                mov dx,3f7a     ; time-out waarde
Bsearchloop:    test breakflag,80 ; break gedrukt? dan stoppen
                jnz B6
                dec dx
                jnz B5
B6:             jmp Bbreak      ; break of time-out? stoppen

B8:             pop cx
                jmp Bsearch

B5:             call leesbit_BC ; lees bit
                jcxz Bsearchloop ; time-out? blijf zoeken
                jnc Bsearchloop ; geen stopbit? dan ook verder zoeken.
                mov cx,0C8      ; time-out waarde voor leader
                in al,21        ; disable timer IRQ
                or al,1
                out 21,al

Bleaderloop:    test breakflag,80 ; break? dan stoppen
                jz Headercont
                jmp Bbreak
Headercont:     push cx         ; sla teller op
                call leesbit_BC ; lees een bit
                jcxz B8         ; time-out? dan verder zoeken
                pop cx          ; teller terug
                jcxz B10        ; einde leader verwacht? zoek dan STX byte
                jnc Bsearch     ; is bit 0? begin dan opnieuw met zoeken
                loop Bleaderloop ; blijf zoeken
B10:            jc Bleaderloop  ; niet ok? blijf zoeken
                call leesbyte2_BC ; lees byte in
                jnc B10A
                jmp Bretry      ; fout? dan opnieuw proberen
B10A:           cmp al,STX
                jne Bretry      ; nee-retry
                mov byte ptr checksum,al ; init checksum
                pop si
                pop cx          ; aantal bytes
                cmp BSTflag,0
                je BgeenBST1
                mov BST_gelezen,0
                call leesbyte_BC
                jc Bdatalost
                xor byte ptr checksum,al
                xor al,80
                mov blockno,al
                mov cx,1024d    ; altijd 1024 bytes voor bestanden
BgeenBST1:      pop bx          ; adres
                xor dx,dx       ; teller
                inc cx          ; tel stopbyte mee
Bloop:          test breakflag,80 ; break? dan stoppen
                jnz Bdatalost
                mov ah,8        ; 'bytes over' of 'bestands-einde'
                jcxz BOK        ; einde na CX bytes; foutmelding 'bytes over'
                call leesbyte_BC ; lees startbit+byte
                jc Bdatalost    ; fout? dan stoppen
                xor byte ptr checksum,al ; update checksum
                cmp EOT,0       ; na bestands-einde nergens meer op letten
                jne BBST2
                cmp al,84       ; bestand-einde?
                jne BgeenBSTeind
                mov BST_gelezen,dx
                dec dx          ; dit is een stopbyte dus corrigeer dx
                mov EOT,1
                jmp short B13A
BgeenBSTeind:   cmp al,83       ; ETX?
                je B14          ; dan einde
BBST2:          xor al,80
                mov es:[bx],al  ; opslaan
                inc bx          ; een byte verder
B13A:           inc dx          ; verhoog aantal gelezen (excl. stopbyte)
                dec cx          ; teller (nog te lezen incl. stopbyte)
                jmp Bloop       ; volgende byte

B14:            call leesbyte_BC ; lees checksum
                xor byte ptr checksum,al ; controle
                xor ah,ah       ; error=0
                cmp byte ptr checksum,0 ; checksum ok?
                jz BOK          ; nee-CRC error
                mov ah,1
                jmp short BOK

Bdatalost:      mov ah,2
BOK:            push ax         ; foutmelding opslaan
                jmp short Beinde

Bretry:         dec si
                jz Bbreak
                jmp Bsearch

Bbreak:         pop si          ; herstel si
                pop cx          ; en cx
                pop bx          ; en bx
                sub dx,dx       ; 0 bytes gelezen
                mov ah,4        ; afgebroken
                push ax
Beinde:         in al,21        ; enable timer IRQ
                and al,0FE
                out 21,al
                call motor_off  ; schakel motor uit
                pop ax          ; error code
                cmp ah,1        ; 0=ok, andere=error
                cmc
                jmp short Bret

Babort:         pop si          ; afbreek-routine na een fout in motor_on
                pop cx
                pop bx
Bret:           call screenload
                ret
read_bc         endp

                ; WRITE_BC
                ; Schrijft een stuk geheugen als BASICODE programma of
                ; bestandsblok weg naar cassette.
                ; De default instellingen zijn voor programma's, zie de
                ; bestandsroutines voor de instellingen voor bestanden.
                ; Merk op dat een programma geen gebruik kan maken van de
                ; schrijfmogelijkheid van 1 bestandsblok. Gebruik funktie 9
                ; om een compleet bestand weg te schrijven.
                ; on entry:
                ;   ES:BX=beginadres van data
                ;   CX=aantal bytes weg te schrijven (alleen programma's)
                ; on exit:
                ;   ES:BX=adres van eerste byte na data
                ;   AH=error code (als CY set, anders 0)
                ;      10h=interface niet aanwezig
                ;      86h=routines niet aanwezig
                ;   DX=aantal weggeschreven bytes (altijd 1024d voor bestanden)
                ; CX vernietigd, rest bewaard.
                ; De basis van deze routine was de oude versie van CAS.
                ; (Daarvoor waren waarschijnlijk de IBM routines weer de basis)
                ; Er zijn echter invoegingen gedaan voor bestands-support.
                ; Het bleek dat die invoegingen geen invloed hebben op het in-
                ; lezen, wat betreft de tijd.
write_bc        proc near
                push bx
                push cx
                call motor_on   ; schakel motor in en wacht
                jnc wb1
                pop cx
                pop bx
                ret

wb1:            in al,61
                and al,0FDh     ; disable speaker
                or al,1         ; set speaker data
                out 61,al
                mov al,10110110b ; timer 2; program LSB,MSB; blokgolf; bin
                out 43,al
                mov ax,1EC
                call schrijftimer
                mov cx,5 * 1200d ; aantal bits voor leader
                test printer,4
                jz WBleaderloop
                in al,21        ; disable timer IRQ als printerpoort gebruikt
                or al,1
                out 21,al

WBleaderloop:   stc
                call schrijfbitBC ; schrijf stopbits
                loop WBleaderloop

                mov al,STX
                mov byte ptr checksum,al ; telt mee met checksum
                call schrijfbyteBC ; schrijf STX
                pop cx          ; aantal bytes
                pop bx          ; adres
                cmp BSTflag,0
                je WgeenBST1
                mov al,blockno
                xor al,80
                xor byte ptr checksum,al
                call schrijfbyteBC
WgeenBST1:      xor dx,dx       ; lees-teller
WBbyteloop:     test breakflag,80
                jnz WBeinde2
                jcxz wb4        ; alle bytes gehad? dan einde
                mov al,es:[bx]  ; lees byte
                xor al,80
                xor byte ptr checksum,al ; update checksum
                call schrijfbyteBC ; schrijf weg
                inc bx          ; volgende adres
                dec cx          ; schrijf-teller
                inc dx          ; lees-teller
                cmp BSTflag,0
                je WBbyteloop
                cmp dx,1024d    ; bestand en 1024 geschreven?
                jb WBbyteloop   ; nee, dan volgende
                cmp EOT,0       ; einde bestand?
                je WBST2        ; nee? schrijf ETX en stop
                jmp short WBST3 ; ja-stop zonder ETX (is al EOT geschreven)

wb4:            cmp BSTflag,0
                je WBST2
                mov EOT,1
                mov al,84
                xor byte ptr checksum,al
                call schrijfbyteBC
                dec cx
                dec bx          ; corrigeer BX
                jmp WBbyteloop

WBST2:          mov al,83       ; ETX byte
                xor byte ptr checksum,al ; ook meerekenen
                call schrijfbyteBC

WBST3:          mov al,byte ptr checksum ; schrijf checksum weg
                call schrijfbyteBC
                push cx
                mov cx,1200d    ; trailer-teller
WBtrailerloop:  stc             ; 1-bits
                call schrijfbitBC
                loop WBtrailerloop
                pop cx

WBeinde:        cmp BSTflag,0
                je WBeinde2
                cmp EOT,0
                jne WBeinde2
                inc blockno
                jmp write_bc

WBeinde2:       mov al,10110000b ; timer 2; program LSB,MSB; mode 0; bin
                out 43,al
                mov ax,1
                call schrijftimer
                test printer,4
                jz wb6
                in al,21        ; enable timer als printer wordt gebruikt
                and al,0FE
                out 21,al
wb6:            call motor_off
                xor ah,ah
                ret
write_bc        endp

                ; READBLOCK
                ; leest een blok van een BASICODE bestand.
                ; on entry:
                ;   ES:BX=adres
                ; on exit:
                ;   ES:BX=eerstvolgende adres na data
                ;   AH=error code (als CY set, anders 0)
                ;       1=CRC fout
                ;       2=data lost
                ;       4=not found (time out)
                ;       8=als CH=1: einde bestand bereikt
                ;         als CH=0:  meer dan 1024 bytes in block (misschien
                ;         hogere versie; in ieder geval klopt er iets niet)
                ;     10h=interface niet aanwezig
                ;     86h=routines niet aanwezig
                ;   AL=nummer van ingelezen block
                ;   CL=checksum (voor controle van CAS3 bedoeld)
                ;   CH=EOT: End Of Tape tegengekomen=einde bestand. Hierbij
                ;      zal AH=8 en CY=1
                ;   DX=aantal geldige ingelezen bytes
                ; Rest van registers bewaard
                ; Beschrijving:
                ;  Deze routine leest slechts 1 block in van tape.
                ;  CAS3 blijft in bestandsbedrijf totdat er een EOT is in-
                ;  gelezen, of totdat de gebruiker met service 1 de motor
                ;  uitschakelt. Tijdens bestandsbedrijf blijft de motor
                ;  namelijk ingeschakeld.
                ;  Met service 8 kan een compleet bestand ingelezen worden,
                ;  echter zonder retry-mogelijkheden.
                ;  Om een heel bestand in te lezen moet het volgende gedaan
                ;  worden:
                ;    - Lees een block met data met deze service
                ;    - Als er een fout gebeurd is, vraag dan de gebruiker
                ;      wat er gedaan moet worden (de block-struktuur staat
                ;      retries toe, bijv. als er een block van tape
                ;      gemist is).
                ;    - ga daarmee net zolang door, totdat de gebruiker wil
                ;      stoppen, of tot het EOT bereikt is.
readblock       proc near
                push bx
                call motor_on   ; motor aan en wachten
                jc BCBST_motorfail ; interface afwezig? dan foutmelding
                mov BSTflag,1   ; bestand
                mov STX,81
                mov EOT,0
                pop bx
                call read_bc
                pushf
                cmp EOT,0
                je BCBSTnietuit
                mov dx,BST_gelezen
                push ax
                mov ah,1
                call motor
                pop ax
BCBSTnietuit:   popf
                mov al,blockno
                mov cl,byte ptr checksum
                mov ch,EOT
                mov STX,82
                jmp short BCBSTret

BCBST_motorfail:pop bx

BCBSTret:       ret
readblock       endp

                ; READ_BC_BST
                ; Deze routine leest een compleet BC3 bestand in.
                ; Als er echter een fout gebeurt, wordt het lezen meteen
                ; afgebroken. Voor werkelijke flexibiliteit kan dus het beste
                ; service no. 0Ah gebruikt worden, samen met wat extra regels
                ; die de gebruiker vragen wat te doen.
                ; on entry: zie READBLOCK
                ;   en: CX=buffer-grootte (wordt afgerond naar beneden op 400h)
                ; on exit: zie READBLOCK
                ;   maar: DX=totale aantal bytes gelezen
                ;   AH=9 en CY=1 als buffer te klein is voor bestand
                ;   AH=10d en CY=1 als verkeerd block gevonden werd
                ;      (AL=gevonden block, BP=verwachte block)
                ;   CY=0 als bestand goed ingelezen
                ;   BP=laatste ingelezen block
                ; De machine wordt achtergelaten met uitgeschakelde motor en
                ; in programma-bedrijf.
read_BC_BST     proc near
                mov bp,0
                xor dx,dx
                mov BST_BUFLEN,cx
BCBSTloop:      cmp BST_BUFLEN,400
                jb bufvol
                sub BST_BUFLEN,400
                push dx
                call readblock
                pop BST_gelezen
                pushf
                add dx,BST_gelezen
                push ax
                xor ah,ah
                cmp ax,bp
                pop ax
                jne blockfout
                popf
                jc BCBSTerr
                inc bp
                jmp BCBSTloop

bufvol:         mov ah,9
                jmp short BCBSTerr2

blockfout:      popf
                mov ah,0a
BCBSTerr2:      stc

BCBSTerr:       pushf
                push ax
                mov ah,1
                call motor
                pop ax
                cmp ah,8
                jne BCBSTret3
                cmp ch,0
                je BCBSTret3
                popf
                clc
                pushf
BCBSTret3:      popf
BCBSTret2:      ret
read_BC_BST     endp

                ; WRITE_BC_BST
                ; Deze routine schrijft een blok geheugen (max. 64K)
                ; als een compleet BC3 bestand naar cassette.
                ; Met opzet is deze routine bedoeld voor een compleet
                ; bestand (niet voor losse blocks) om de gebruiker
                ; programmeerwerk te besparen; er kan immers toch maar een
                ; ding gebeuren, en dat is dat de interface of de routines
                ; niet aanwezig zijn.
                ; on entry:
                ;  ES:BX=adres van data
                ;  CX=aantal bytes weg te schrijven
                ; on exit:
                ;  AH=error code als CY set: 10h=interface afwezig, 86h=
                ;     routines afwezig (rest van deze uitleg dan NVT).
                ;  ES:BX=adres van laatste data + 1
                ;  AL=laatste block dat werd weggeschreven
                ;     (bedoeld voor controle van CAS3)
                ; CX en DX vernietigd, rest bewaard
write_BC_BST    proc near
                push cx
                push bx
                call motor_on
                jc WBCBST_motorfail
                mov blockno,0
                mov BSTflag,1
                mov STX,81
                mov EOT,0
                pop bx
                pop cx
                call write_bc
                mov ah,1
                call motor
                mov al,blockno  ; laatste volledig weggeschreven block no.
                mov STX,82
                jmp short WBCBSTret

WBCBST_motorfail: pop bx
                pop cx
WBCBSTret:      ret
write_BC_BST    endp

;============================================================================:
;                               Service-routines                             :
;============================================================================:

motor_on        proc near
                pushf
                cmp BSTflag,0
                jne MN4
                popf
                mov ah,0
                call motor
                jc MN1
                mov bl,42
MN2:            mov cx,700
MN3:            loop MN3
                dec bl
                jnz MN2
MN1:            ret

MN4:            popf
                clc
                jmp mn1
motor_on        endp

motor_off       proc near
                pushf
                cmp BSTflag,0
                jne MF1
                popf
                push cx
                mov ah,1
                call motor
                pop cx
MF2:            ret

MF1:            popf
                clc
                jmp MF2
motor_off       endp

testpr          proc near
                push dx
                push cx
                push bx
                mov cx,4        ; aan,uit,aan,uit
                mov dx,cs:poort0
                add dx,2
tp1:            in al,dx        ; AL=xxxxxxxi    i=input van ID-loop
                mov bl,al       ; BL=xxxxxxxi
                and al,1        ; AL=0000000i
                mov ah,al       ; AH=0000000i
                dec dx
                in al,dx        ; AL=x\xxxxxx    \=geinverteerde output v. loop
                inc dx
                and al,40       ; AL=0\000000
                xor al,40       ; AL=0u000000
                or al,ah        ; AL=0u00000i
                jz tp2          ; dus AL=0 en AL=41h is ok
                cmp al,41
                jne tp3
tp2:            mov al,bl       ; AL=xxxxxxxi
                xor al,1        ; AL=xxxxxxx/    /=geinverteerde input v. loop
                out dx,al       ; naar buiten
                loop tp1        ; test opnieuw
tp4:            or al,al        ; ok - reset CY ; AH=0
                pop bx
                pop cx
                pop dx
                ret

tp3:            mov ah,10       ; niet ok - set CY ; AH=10
                jmp tp4
testpr          endp

leeshbit        proc near
                mov cx,100d     ; max wachttijd ong. 1 ms op 4.77 Mc
                mov ah,iobit
                test printer,4
                jz LH1

                push dx
                mov dx,cs:poort0
                inc dx          ; input poort
LH2:            in al,dx        ; wacht op een flank
                jmp short LHN1
LHN1:           and al,80
                cmp al,ah
                loope LH2       ; een lus duurt 10080 ns = 10.080 us
                pop dx          ; dus 100 lussen (time-out waarde) duren 1 ms
                jmp short LH3   ; en dat is 2x de max. te verwachten tijd

LH1:            in al,62        ; wacht op een flank
                jmp short LHN2
LHN2:           and al,10
                cmp al,ah
                loopz LH1

LH3:            mov iobit,al    ; sla situatie op
                mov al,0        ; timer 0, latch timer count
                out 43,al
                in al,40        ; lees huidige lage waarde
                mov ah,al
                in al,40        ; lees huidige hoge waarde
                xchg al,ah      ; ax=aantal cycles op de klok (1.1931817 Mc)
                mov bx,hbit_cycles ; lees waarde van vorige hbit
                sub bx,ax       ; neem verschil in BX
                mov hbit_cycles,ax ; schrijf nieuwe waarde weg
                ret
leeshbit        endp

leesbit_BC      proc near
                push ax
                push bx
                call leeshbit   ; lees 2 halve bits voor een cycle
                jcxz LIB1
                push bx
                call leeshbit
                pop ax
                jcxz LIB1
                add bx,ax
                cmp bx,5c6
                jnb LIB1        ; 2 cycles voor BC '1'-bit
                call leeshbit
                jcxz LIB1
                push bx
                call leeshbit
                pop ax
                jcxz LIB1
                add bx,ax
                cmp bx,5c6      ; CY=1 voor '1' bit, anders 0
LIB1:           pop bx
                pop ax
                ret
leesbit_BC      endp

leesbyte_IBM    proc near
                push bx
                push cx
                mov cl,8        ; 8 bits
LI1:            push cx
                call leeshbit   ; lees een halve bit
                jcxz LI2        ; fout-afbreken
                push bx         ; sla lengte even op
                call leeshbit   ; lees 2e halve bit
                pop ax          ; lengte eerste 1/2 bit
                jcxz LI2        ; fout? afbreken
                add bx,ax       ; tel twee halve flanken op
                cmp bx,6F0      ; ok?
                cmc             ; groter? dan CY=1
                lahf
                pop cx
                rcl ch,1
                sahf
                call upd_checksum_IBM
                dec cl
                jnz LI1         ; lees 8 bits
                mov al,ch
                clc
LI3:            pop cx
                pop bx
                ret
LI2:            pop cx
                stc
                jmp LI3
leesbyte_IBM    endp

leesbyte2_BC    proc near       ; leesbyte2_BC leest een byte zonder startbit
                push bx
                push cx
                jmp short LBB1
leesbyte_BC:    push bx
                push cx
LBB2:           call leesbit_BC ; startbit
                jcxz LBB7
                jc LBB2         ; moet 0 zijn
LBB1:           mov cl,8        ; 8 databits
LBB4:           push cx
LBB5:           call leesbit_BC ; lees een bit
                jcxz LBB6
                pop cx
                rcr ch,1        ; update byte waarde
                dec cl
                jnz LBB4
                mov al,ch       ; stopbit
                call leesbit_BC
                jcxz LBB7
                cmc             ; moet 1 zijn
LBB7:           pop cx
                pop bx
                pushf
                push ds
                xor al,80
                push ax
                mov ax,0b800
                mov ds,ax
                pop ax
                mov ds:[nuladres],al
                push ax
                mov ax,0b000
                mov ds,ax
                pop ax
                mov ds:[nuladres],al
                xor al,80
                pop ds
                popf
                ret             ; einde
LBB6:           pop cx
LBB3:           stc             ; fout
                jmp LBB7
leesbyte2_BC    endp

upd_checksum_IBM proc near      ; vreemde checksum-berekening voor IBM-
                mov ax,checksum ; routines
                rcr ax,1
                rcl ax,1
                clc
                jno UC1
                xor ax,810
                stc
UC1:            rcl ax,1
                mov checksum,ax
                ret
upd_checksum_IBM endp

schrijfbitIBM   proc near
                mov ax,4a0      ; 1000Hz voor CY=1
                jc SII1
                mov ax,250      ; 2000Hz voor CY=0
SII1:           push ax
                call wachtncycle
                pop ax
schrijftimer:   out 42,al
                mov al,ah
                out 42,al
                ret
schrijfbitIBM   endp

schrijfbyteIBM  proc near
                push cx
                push ax
                mov ch,al       ; sla byte op in ch
                mov cl,8        ; 8 bits
SBI1:           rcl ch,1        ; volgende bit naar CY
                pushf
                call schrijfbitIBM ; schrijf bit weg
                popf
                call upd_checksum_IBM
                dec cl          ; volgende bit
                jnz SBI1        ; wegschrijven
                pop ax
                pop cx
                ret
schrijfbyteIBM  endp

schrijfbitBC    proc near
                push ax
                pushf
                mov ax,3da      ; waarde voor 0
                jnc o91
                mov ax,1ec      ; waarde voor 1
o91:            call wachtncycle
                jnc o92
                push ax
                call schrijftimer
                pop ax
                call wachtncycle
o92:            call schrijftimer
                popf
                pop ax
                ret
schrijfbitBC    endp

schrijfbyteBC   proc near
                push cx
                push ax
                clc
                call schrijfbitBC ; startbit 0
                mov ch,al
                mov cl,8          ; 8 bits
o101:           rcr ch,1
                call schrijfbitBC ; schrijf bit weg
                dec cl
                jnz o101
                stc
                call schrijfbitBC ; 2 stopbits 1
                call schrijfbitBC
                pop ax
                pop cx
                ret
schrijfbyteBC   endp

wachtncycle     proc near
                pushf
                push ax
                push dx
                mov dx,62       ; terug-invoer van uitgang
                cmp PC_ID,0FC   ; een lager voor cassette-pc's
                jne o111
                dec dx
o111:           in al,dx        ; lees bit in
                and al,20       ; strip af
                jz o111         ; nul? dan loopen
                test printer,4
                jz o112
                call schrijfPRP ; update printerpoort indien nodig
o112:           in al,dx        ; lees weer bit in
                and al,20       ; strip af
                jnz o112        ; niet nul? dan loopen
                test printer,4
                jz o113
                call schrijfPRP ; update printerpoort
o113:           pop dx          ; einde
                pop ax
                popf
                ret
wachtncycle     endp

schrijfPRP      proc near
                push cx
                push dx         ; de printer-uitgangspoort wordt tegelijk ge-
                mov dx,cs:poort0 ; inverteerd met de cassettepoort
                mov cl,5        ; AL=20 of 0 (zie WachtNCycle)
                shr al,cl
                out dx,al
                pop dx
                pop cx
                ret
schrijfPRP      endp

screensave      proc near       ; slaat eerste bytes uit schermgeheugens op
                push ax
                push ds
                mov ax,0B000
                mov ds,ax
                mov al,ds:nuladres
                push ax
                mov ax,0B800
                mov ds,ax
                pop ax
                mov ah,ds:nuladres
                mov schermbytes,ax
                pop ds
                pop ax
                ret
screensave      endp

screenload      proc near
                push ax
                push ds
                mov ax,0B000
                mov ds,ax
                mov ax,schermbytes
                push ax
                mov ds:nuladres,al
                mov ax,0B800
                mov ds,ax
                pop ax
                mov ds:nuladres,ah
                pop ds
                pop ax
                ret
screenload      endp

;=============================================================================:
;                                 Installatie                                 :
;=============================================================================:

reqmode         db 0               ; gevraagde mode

entry           proc near
                assume ds:code,es:nothing
                mov dx,offset txt1 ; 'BC3 support, door... ' enz
                mov ah,9
                int 21
                mov ax,3515
                int 21
                mov word ptr oldint15,bx
                mov word ptr oldint15[2],es
                call casaanwezig ; aanwezig? dan wijst ES naar oude CS
                jz s1           ; niet aanwezig? dan zeker weten dat ES=CS
                push cs
                pop es
s1:             call scanparms  ; lees gevraagde mode in AL, of geef hulp en
                mov reqmode,al  ; breek af. sla gevraagde mode even op
                lahf
                mov dh,ah
                test al,4
                jnz s2          ; printer? dan s2

                mov ax,0FFFF
                push es
                mov es,ax
                mov bl,es:[000E] ; lees PC ID
                pop es          ; voor een PC met ID no. 0FCh moet een van de
                mov es:PC_ID,bl ; I/O adressen anders zijn
                cmp bl,0FF      ; PC's met ID<>0FF hebben geen cassettepoort(?)
                je s2
                mov reqmode,4   ; forceer printerpoort 0
                mov ah,dh
                sahf
                jc s2
                mov dx,offset txt2a
                mov ah,9
                int 21
                mov dx,offset txt4
                mov ah,9
                int 21
s2:             test reqmode,4
                jz s3           ; geen printerpoort-dan verder

                mov al,reqmode
                call leespoort0
                jnc s3          ; ok-dan verder
                mov dx,offset txt2 ; 'printerpoort'
                mov ah,9
                int 21
                mov al,reqmode
                and al,3        ; maak van gevraagde printerpoort een nummer
                jz s5           ; default? dan springen
s4:             or al,30        ; maak ascii
                mov dl,al       ; naar DL voor DOS
                mov ah,2
                int 21
s5:             mov dx,offset txt4 ; 'bestaat niet.'
                mov ah,9
                int 21
                call rapporteer ; 'printer x/cassettepoort zal w gebruikt'
                                ; 'BC3 suppport is'
                call casaanwezig
                pushf
                mov dx,offset txt5 ; 'niet'
                mov ah,9
                int 21
                popf
                mov dx,offset txt8 ; 'geladen'
                jnz s6
                mov dx,offset txt6 ; 'aangepast'
s6:             mov ah,9
                int 21
                int 20

s3:             mov al,reqmode
                mov es:printer,al
                call rapporteer ; 'printerpoort x/cassettepoort zal w gebr'
                                ; 'BC3 support is'
                call casaanwezig
                jnz s7
                mov dx,offset txt7 ; 'al eerder geladen'
                mov ah,9
                int 21
                int 20

s7:             mov dx,offset newint15
                mov ax,2515
                int 21
                mov dx,offset txt8 ; 'geladen'
                mov ah,9
                int 21
                mov dx,offset entry
                int 27
entry           endp

scanparms       proc near
                push bx
                push cx

                mov bx,offset parms
                mov cl,[bx]
                xor ch,ch
                jcxz s8b
s21:            inc bx
                cmp byte ptr [bx],'/'
                je s22
                loopnz s21
                jmp short s8b

s22:            dec cx
                jcxz s23
                inc bx
                or byte ptr [bx],60
                cmp byte ptr [bx],'p'
                jne s24

                mov al,4
                dec cx
                jcxz s8
                inc bx
                cmp byte ptr [bx],' '
                je s8
                cmp byte ptr [bx],'1'
                jb s25
                cmp byte ptr [bx],'4'
                jae s25
                mov ah,[bx]
                sub ah,'0'
                or al,ah
                jmp short s8

s8a:            mov al,0
s8:             clc
                jmp short s8c
s8b:            stc
s8c:            pop cx
                pop bx
                ret

s24:            cmp byte ptr [bx],'c'
                jne s25
                mov al,0
                jmp s8

s23:            call help
                int 20

s25:            mov dx,offset txt9 ; 'fout in parms'
                mov ah,9
                int 21
                jmp s23
scanparms       endp

help            proc near
                mov dx,offset txt10 ; syntax
                mov ah,9
                int 21
                ret
help            endp

leespoort0      proc near
                ; kijkt of printer no AL beschikbaar is.
                ; on return: CF=1 als poort niet beschikbaar,
                ; anders CF=0 en dx=poortnummer. Het poortnummer wordt ook in
                ; POORT0 gezet in het segment in ES
                push bx
                mov bl,al
                and bl,3        ; strip poort no.
                jz s31
                dec bl
s31:            xor bh,bh
                push bx
                shl bx,1
                push es
                mov ax,40
                mov es,ax
                mov dx,es:[bx+printertabel] ; in biosdata
                pop es
                pop ax
                inc al
                or dx,dx
                stc
                jz s32
                clc
                mov es:poort0,dx
s32:            pop bx
                ret
leespoort0      endp

rapporteer      proc near
                test es:printer,4
                jz s41

                mov dx,offset txt2 ; 'printerpoort'
                mov ah,9
                int 21
                mov al,es:printer
                call leespoort0
                and al,3        ; strip LPT no.
                or al,30        ; maak er een cijfer van
                mov dl,al       ; in DL voor DOS
                mov ah,2        ; afdrukken
                int 21
s42a:           mov dx,offset txt13 ; 'zal worden gebruikt'
                mov ah,9        ; totaal dus: 'Printerpoort x zal worden
                int 21          ; gebruikt'
                jmp short s42

s41:            mov dx,offset txt2a ; 'cassette-aansluiting zal worden gebr'
                mov ah,9
                int 21
                jmp short s42a

s42:            mov dx,offset txt15 ; 'cassette-ondersteuning is'
                mov ah,9
                int 21
                ret
rapporteer      endp

casaanwezig     proc near
                push dx
                mov ah,7        ; lees versie en segment
                int 15
                cmp ax,310
                mov es,dx
                pop dx
                ret
casaanwezig     endp

                .radix 10
txt1            db 'IBM Personal Computer Basicode 3 cassette-ondersteuning.'
                db 13,10
                db 'Een programma van J. Goudsmit.  V1.10.  Datum 25 feb.'
                db ' 1988',13,10,10
                db 'Originele versie (C) 1984 B. Niewold.'
                db 13,10,10,36
txt2            db 'Printerpoort $'
txt2a           db 'Cassette-aansluiting$'
txt4            db ' bestaat niet.',13,10,36
txt13           db ' zal worden gebruikt.',13,10,36
txt15           db 'Cassette-ondersteuning voor BASICODE is $'
txt5            db 'niet $',13,10,36
txt6            db 'aangepast.',13,10,36
txt7            db 'al eerder '
txt8            db 'geladen.',13,10,36
txt9            db '***** Foute parameter(s) ******',13,10,36
txt10           db 'De syntax van dit programma is: CAS [/C | /P[n]]',13,10
                db 'CAS zonder parameters geeft dit scherm.',13,10
                db ' /C voor cassettepoort',13,10
                db ' /P of /Pn voor parallel printerpoort n',13,10
                db 'waarbij n = blanko,1,2 of 3 = LPT nummer.',13,10,36
code            ends
                end begin
