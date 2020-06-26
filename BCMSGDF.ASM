                page
                page ,132
                title BCMSGDF basicode-3 bestandsboodschappen met routines

                ; Maakt gebruik van BC.OBJ

                ;=======================================:
                ;             BCMSGDF.OBJ               :
                ;    Een programma van Jac Goudsmit     :
                ;                                       :
                ;              JG  061088               :
                ;=======================================:

                ; N.B.    N=On Entry   X=On Exit

                dosseg
                .model small,BASIC
                .radix 16
                .lall
                .const
Kleur           db 1F
Enter           db 17d,196d,217d,0
Play            db 'Druk op PLAY.',0
Rec             db 'Druk op REC.',0
Blok            db 'Blok no.',0
Laden           db 'wordt ingelezen.',0
Saven           db 'wordt weggeschreven.',0
Foutblok1       db 'gevonden.',0
Foutblok2       db 'werd gezocht.',0
Terug           db 'Spoel cassette terug.',0
Vooruit         db 'Spoel cassette vooruit of wacht tot juiste blok gevonden.'
                db 0
