;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@;
;                                                                              ;
;       Jogo Dino - Parte 2                                                    ;
;                                                                              ;
;       Luís H. Fonseca <luis.h.fonseca@tecnico.ulisboa.pt>                    ;
;       Ricardo Antunes <ricardo.g.antunes@tecnico.ulisboa.pt>                 ;
;                                                                              ;
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@;

;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@;
;                                                                              ;
;                                  CONSTANTES                                  ;
;                                                                              ;
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@;

; Portas do temporizador
TIMER_CONTROL   EQU     FFF7h
TIMER_COUNTER   EQU     FFF6h
; Constantes de controlo do temporizador
TIMER_SETSTART  EQU     1
TIMER_INTERVAL  EQU     1

; Portas do terminal
TERM_READ       EQU     FFFFh
TERM_WRITE      EQU     FFFEh
TERM_STATUS     EQU     FFFDh
TERM_CURSOR     EQU     FFFCh
TERM_COLOR      EQU     FFFBh

; Portas do display de 7 segmentos
DISP7_5         EQU     FFEFh
DISP7_4         EQU     FFEEh
DISP7_3         EQU     FFF3h
DISP7_2         EQU     FFF2h
DISP7_1         EQU     FFF1h
DISP7_0         EQU     FFF0h
; Numero de digitos do display
DISP7_SZ        EQU     6

; Porta dos interruptores e masks
INT_MASK        EQU     FFFAh
INT_MASK_KEY0   EQU     0001h
INT_MASK_UP     EQU     0008h
INT_MASK_TIMER  EQU     8000h

; Endereco inicial stack
STACKBASE       EQU     8000h

; Tamanho do terminal
COL_COUNT       EQU     80
ROW_COUNT       EQU     45

; Linha acima da qual o chao e desenhado
FLOOR_LINE      EQU     40

; Altura maxima dos cactos
CACTUS_MAX      EQU     8

; Altura maxima do salto
JUMP_MAX        EQU     10

; Coluna em que o jogador esta
PLAYER_COL      EQU     10

; Cores
COLOR_BG        EQU     0000111000000000b
COLOR_CACTUS    EQU     0000010000011100b
COLOR_DINO      EQU     0000111011100000b
COLOR_FLOOR     EQU     1001000011011000b
COLOR_TEXTBOX   EQU     0000111011111110b

;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@;
;                                                                              ;
;                             VARIAVEIS GLOBAIS                                ;
;                                                                              ;
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@;

                ORIG    0000h

; Tabela com as alturas dos cactos em cada coluna
MAP             TAB     COL_COUNT

; Seed utilizada no gen_cactus
SEED            WORD    5

; Variavel com o endereco da funcao de estado atual
STATE           WORD    state_wait

; Ultima linha e linha atual do jogador
PLAYER_ROW_PREV WORD    FLOOR_LINE
PLAYER_ROW      WORD    FLOOR_LINE

; Numero de updates queued pelo temporizador
TICKS           WORD    0

; O click do key0 ja foi recebido?
KEY0_HANDLED    WORD    1

; O click do up ja foi recebido?
UP_HANDLED      WORD    1

; Tabela com os digitos decimais da pontuacao
SCORE           TAB     DISP7_SZ
; String com as portas para cada digito
DISP7           STR     DISP7_5, DISP7_4, DISP7_3, DISP7_2, DISP7_1, DISP7_0

; Mensagem de inicio de jogo
START_GAME_MSG  STR     'Press 0 to start!', 0
; Mensagem do final de jogo
GAME_OVER_MSG   STR     'G A M E  O V E R', 0

;==============================================================================;
; entry:        Funcao de entrada.                                             ;
;------------------------------------------------------------------------------;
                ORIG    0000h
entry:          MVI     R6, STACKBASE        ; Inicializar stack

                MVI     R4, STATE            ; R4 <- Endereco da variavel STATE
                MVI     R5, TICKS            ; R5 <- Endereco da variavel TICKS
    
                MVI     R1, state_wait       ; Inicializar o estado
                STOR    M[R4], R1
                STOR    M[R5], R0            ; Inicializar TICKS
                MVI     R1, SCORE            ; Inicializar a pontuacao
                STOR    M[R1], R0

                MVI     R1, 1                ; Fazer reset as variaveis de
                MVI     R2, KEY0_HANDLED     ; estado dos botoes
                STOR    M[R2], R1
                MVI     R2, UP_HANDLED
                STOR    M[R2], R1

                MVI     R1, COLOR_BG         ; Apaga o terminal com a cor do
                JAL     term_color           ; background
                JAL     term_clear
                MVI     R1, COL_COUNT
                JAL     draw_floor
                MVI     R1, START_GAME_MSG   ; Desenhar texto do inicio do jogo
                JAL     draw_textbox

                MVI     R1, INT_MASK_KEY0    ; Inicializar interrupts
                MVI     R2, INT_MASK_TIMER
                OR      R1, R1, R2
                MVI     R2, INT_MASK         
                STOR    M[R2], R1
                ENI

                MVI     R2, TIMER_COUNTER    ; Comecar temporizador
                MVI     R1, TIMER_INTERVAL
                STOR    M[R2], R1
                MVI     R2, TIMER_CONTROL
                MVI     R1, TIMER_SETSTART
                STOR    M[R2], R1

.loop:          LOAD    R1, M[R5]            ; Nao fazer nada enquanto
                CMP     R1, R0               ; TICKS conter 0
                BR.Z   .loop

                DSI                          ; Decrementar TICKS (regiao
                LOAD    R1, M[R5]            ; critica)
                DEC     R1
                STOR    M[R5], R1
                ENI

                LOAD    R1, M[R4]            ; R1 <- Endereco da funcao do
                JAL     R1                   ; estado atual
                
                BR      .loop

;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@;
;                                                                              ;
;                            FUNCOES DOS ESTADOS                               ;
;                                                                              ;
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@;

;==============================================================================;
; state_wait:   Funcao do estado 'wait'.                                       ;
;               este estado apenas espera pelo KEY0 ser premido.               ;
;------------------------------------------------------------------------------;
state_wait:     DEC     R6                   ; Preservar contexto
                STOR    M[R6], R7

                JAL     read_key0            ; Verificar se UP foi premido
                CMP     R3, R0
                BR.Z    .skip_change
                  
                MVI     R2, STATE            ; Alterar estado para 'Start'.
                MVI     R1, state_start
                STOR    M[R2], R1

.skip_change:   LOAD    R7, M[R6]            ; Restaurar contexto
                INC     R6
                JMP     R7

;==============================================================================;
; state_start:  Funcao do estado 'Start'.                                      ;
;------------------------------------------------------------------------------;
state_start:    DEC     R6                   ; Preservar contexto
                STOR    M[R6], R7

                MVI     R1, COL_COUNT        ; Apagar o mapa
                MVI     R2, MAP
.clear_map:     STOR    M[R2], R0
                INC     R2
                CMP     R2, R1
                BR.NZ   .clear_map

                MVI     R1, FLOOR_LINE       ; Por o jogador na linha inicial
                MVI     R2, PLAYER_ROW
                STOR    M[R2], R1
                MVI     R2, PLAYER_ROW_PREV
                STOR    M[R2], R1
                
                MVI     R1, COLOR_BG         ; Apaga o terminal com a cor do
                JAL     term_color           ; background
                JAL     term_clear

                MVI     R1, COL_COUNT        ; Desenha o chao
                JAL     draw_floor

                JAL     reset_score          ; Reinicia a pontuacao

                MVI     R2, STATE            ; Mudar para o estado 'Run'
                MVI     R1, state_run
                STOR    M[R2], R1

                MVI     R1, INT_MASK_UP      ; Mudar interrupts
                MVI     R2, INT_MASK_TIMER
                OR      R1, R1, R2
                MVI     R2, INT_MASK         
                STOR    M[R2], R1
                
                LOAD    R7, M[R6]            ; Restaurar contexto
                INC     R6
                JMP     R7

;==============================================================================;
; state_over:   Funcao do estado 'Game Over'.                                  ;
;------------------------------------------------------------------------------;
state_over:     DEC     R6                   ; Preservar contexto
                STOR    M[R6], R7
                
                MVI     R1, GAME_OVER_MSG    ; Desenha mensagem de game over
                JAL     draw_textbox
                
                MVI     R2, STATE            ; Mudar para o estado 'Wait'
                MVI     R1, state_wait
                STOR    M[R2], R1

                MVI     R1, INT_MASK_KEY0    ; Mudar interrupts
                MVI     R2, INT_MASK_TIMER
                OR      R1, R1, R2
                MVI     R2, INT_MASK         
                STOR    M[R2], R1

                DSI                          ; Dar trigger ao interrupt pendente
                ENI                          ; para impedir que o jogo comece
                MVI     R1, KEY0_HANDLED     ; sozinho
                MVI     R2, 1
                STOR    M[R1], R2

                LOAD    R7, M[R6]            ; Restaurar contexto
                INC     R6
                JMP     R7

;==============================================================================;
; state_run:    Funcao do estado 'Run'.                                        ;
;------------------------------------------------------------------------------;
state_run:      DEC     R6                   ; Preservar contexto
                STOR    M[R6], R7

                JAL     read_up              ; Verificar se UP foi premido
                CMP     R3, R0
                BR.Z    .skip_change
                  
                MVI     R2, STATE            ; Alterar estado para 'Jump'.
                MVI     R1, state_jump
                STOR    M[R2], R1

                MVI     R1, INT_MASK_TIMER   ; Mudar interrupts
                MVI     R2, INT_MASK         
                STOR    M[R2], R1

.skip_change:   JAL     draw_game            ; Desenha o jogo

                JAL     update_game          ; Este estado nao tem nenhum
                                             ; comportamento excecional

                LOAD    R7, M[R6]            ; Restaurar contexto
                INC     R6
                JMP     R7

;==============================================================================;
; state_jump:   Funcao do estado 'Jump'.                                       ;
;------------------------------------------------------------------------------;
state_jump:     DEC     R6                   ; Preservar contexto
                STOR    M[R6], R7
                
                JAL     draw_game            ; Desenha o jogo

                MVI     R2, PLAYER_ROW       ; Decrementar linha do jogador, ou
                LOAD    R1, M[R2]            ; seja, faze-lo subir.
                DEC     R1
                STOR    M[R2], R1

                MVI     R3, FLOOR_LINE       ; Verificar o jogador ja chegou a
                MVI     R2, JUMP_MAX         ; altura maxima.
                SUB     R2, R3, R2
                CMP     R1, R2
                BR.NZ   .skip_change
                
                MVI     R2, STATE            ; Alterar estado para 'Fall'.
                MVI     R1, state_fall
                STOR    M[R2], R1

.skip_change:   JAL     update_game          ; Comportamento comum com os
                                             ; estados 'Run' e 'Fall'.

                LOAD    R7, M[R6]            ; Restaurar contexto
                INC     R6
                JMP     R7

;==============================================================================;
; state_fall:   Funcao do estado 'Fall'.                                       ;
;------------------------------------------------------------------------------;                   
state_fall:     DEC     R6                   ; Preservar contexto
                STOR    M[R6], R7

                JAL     draw_game            ; Desenha o jogo

                MVI     R2, PLAYER_ROW       ; Incrementar linha do jogador, ou
                LOAD    R1, M[R2]            ; seja, faze-lo descer.
                INC     R1
                STOR    M[R2], R1

                MVI     R2, FLOOR_LINE       ; Verificar o jogador ja chegou a
                CMP     R1, R2               ; altura minima.
                JMP.NZ  .skip_change
                
                MVI     R2, STATE            ; Alterar estado para 'Run'
                MVI     R1, state_run
                STOR    M[R2], R1

                MVI     R1, INT_MASK_UP      ; Mudar interrupts
                MVI     R2, INT_MASK_TIMER
                OR      R1, R1, R2
                MVI     R2, INT_MASK         
                STOR    M[R2], R1

                DSI                          ; Dar trigger ao interrupt pendente
                ENI                          ; para impedir um salto a mais
                MVI     R1, UP_HANDLED
                MVI     R2, 1
                STOR    M[R1], R2

.skip_change:   JAL     update_game          ; Comportamento comum com os
                                             ; estados 'Run' e 'Jump'.

                LOAD    R7, M[R6]            ; Restaurar contexto
                INC     R6
                JMP     R7

;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@;
;                                                                              ;
;                         FUNCOES DA LOGICA DO JOGO                            ;
;                                                                              ;
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@;

;==============================================================================;
; inc_score:    Incrementa a pontuacao a atualiza o 7 segment display.         ;
;------------------------------------------------------------------------------;
inc_score:      DEC     R6
                STOR    M[R6], R4
                MVI     R4, DISP7_SZ
                DEC     R4
                
.loop:          CMP     R4, R0          ; Se for R4 < 0, sair porque ja nao
                BR.N    .ret            ; existem mais digitos

                MVI     R2, SCORE
                ADD     R2, R2, R4
                LOAD    R1, M[R2]
                MVI     R3, 9
                CMP     R1, R3
                BR.Z    .carry          ; Se o digito for 9, salta

                INC     R1              ; Caso contrario incrementa e retorna
                STOR    M[R2], R1
                MVI     R2, DISP7
                ADD     R2, R2, R4
                LOAD    R3, M[R2]
                STOR    M[R3], R1
                BR      .ret

.carry:         STOR    M[R2], R0       ; O digito e 9, logo, por a 0 e
                MVI     R2, DISP7       ; incrementar o proximo, repetindo o loop
                ADD     R2, R2, R4
                LOAD    R3, M[R2]
                STOR    M[R3], R0
                DEC     R4
                BR.NN   .loop

.ret:           LOAD    R4, M[R6]
                INC     R6
                JMP     R7
                
;==============================================================================;
; reset_score:  Poe o score a 0 e atualiza o 7 segment display.                ;
;------------------------------------------------------------------------------; 
reset_score:    MVI     R3, DISP7_SZ
                DEC     R3

.loop:          MVI     R2, DISP7       ; Enquanto R3 >= 0
                ADD     R2, R2, R3
                LOAD    R1, M[R2]
                STOR    M[R1], R0       ; Escreve 0 no display
             
                MVI     R2, SCORE       ; Poe a pontuacao a 0
                ADD     R2, R2, R3
                STOR    M[R2], R0
                
                DEC     R3
                BR.NN   .loop
                JMP     R7
                
;==============================================================================;
; p_in_cactus:  Verifica se o jogador esta dentro de um cacto.                 ;
;               R1 <- Linha em que o jogador esta.                             ;
;------------------------------------------------------------------------------;
p_in_cactus:    MVI     R2, MAP              ; Carrega altura do cacto onde esta
                MVI     R3, PLAYER_COL       ; o jogador
                ADD     R2, R2, R3
                LOAD    R2, M[R2]
                MVI     R3, FLOOR_LINE       ; Calcula a linha minima a que o
                SUB     R2, R3, R2           ; cacto chega

                MOV     R3, R0               ; Se o jogador nao esta dentro do
                CMP     R1, R2               ; cacto, devolve 0
                JMP.NP  R7
                
                MVI     R3, 1                ; Caso contrario devolve 1
                JMP     R7

;==============================================================================;
; update_map:   Move todos os catos para a esquerda na tabela do mapa, e,      ;
;               se calhar, gera um novo cato na ultima coluna.                 ;
;               R1 <- endereco da primeira coluna                              ;
;               R2 <- numero de colunas                                        ;
;------------------------------------------------------------------------------;
update_map:     DEC     R6                   ; Push R7
                STOR    M[R6], R7
                ADD     R2, R1, R2           ; R2 <- endereço do ultimo elemento
                DEC     R2

.loop:          INC     R1                   ; Copia proximo elemento para o
                LOAD    R3, M[R1]            ; atual
                DEC     R1
                STOR    M[R1], R3
                INC     R1
                CMP     R1, R2
                BR.NZ   .loop                ; Enquanto nao for o ultimo, repete

                DEC     R6                   ; Push R2
                STOR    M[R6], R2
                MVI     R1, CACTUS_MAX       ; Chamar gen_cactus
                JAL     gen_cactus
                LOAD    R2, M[R6]            ; Pop R2
                INC     R6
                STOR    M[R2], R3            ; Atualizar ultimo valor
                LOAD    R7, M[R6]            ; Return
                INC     R6
                JMP     R7

;==============================================================================;
; gen_cactus:   Verifica se um novo cato e gerado e devolve a sua altura.      ;
;               Se nao for gerado um novo cato devolve 0.                      ;
;               R1 <- altura maxima do cacto                                   ;
;------------------------------------------------------------------------------;
gen_cactus:     MVI     R2, SEED
                LOAD    R3, M[R2]

                MVI     R2, 1
                AND     R2, R3, R2           ; R2 <- R3 && 1 (paridade de X)
                SHR     R3                   ; R3 <- R3 >> 1

                CMP     R0, R2
                BR.Z    .par   ; se par
                MVI     R2, b400h
                XOR     R3, R3, R2           ; R3 <- R3 XOR b400h

.par:           MVI     R2, SEED
                STOR    M[R2], R3            ; SEED <- R3

                MVI     R2, 62258
                CMP     R2, R3
                BR.NC   .menor               ; Se R3 < 62258

                DEC     R1                   ; R1 aka altura
                AND     R3, R3, R1
                INC     R3
                JMP     R7                   ; Return (R3 AND altura-1)+1

.menor:         MVI     R3, 0
                JMP     R7                   ; Return R3

;==============================================================================;
; update_game:  Implementa o comportamento comum aos estados 'Run', 'Jump' e   ;
;               'Fall'.                                                        ;
;------------------------------------------------------------------------------;
update_game:    DEC     R6                   ; Preservar o contexto
                STOR    M[R6], R7
                
                JAL     inc_score            ; Incrementa pontuacao do jogador

                MVI     R1, MAP
                MVI     R2, COL_COUNT
                JAL     update_map
                
                MVI     R2, PLAYER_ROW       ; Verificar colisao com cato
                LOAD    R1, M[R2]
                JAL     p_in_cactus
                CMP     R3, R0
                BR.Z    .ret

                MVI     R2, STATE            ; Se houve colisao, muda estado
                MVI     R1, state_over       ; para 'Game Over'
                STOR    M[R2], R1
                
.ret:           LOAD    R7, M[R6]            ; Restaurar contexto
                INC     R6
                JMP     R7

;==============================================================================;
; read_key0:    Verifica se o interrupt KEY0 foi chamado (se sim, devolve 1,   ;
;               senao devolve 0).                                              ;
;------------------------------------------------------------------------------;
read_key0:      MOV     R3, R0
                MVI     R2, KEY0_HANDLED
                DSI                          ; Regiao critica
                LOAD    R1, M[R2]
                CMP     R1, R0
                BR.NZ   .ret                 ; Se foi handled, retorna 0
                INC     R3                   ; Se nao foi, retorna 1
                STOR    M[R2], R3                                               
.ret:           ENI
                JMP     R7

;==============================================================================;
; read_up:      Verifica se o interrupt UP foi chamado (se sim, devolve 1,     ;
;               senao devolve 0).                                              ;
;------------------------------------------------------------------------------;
read_up:        MOV     R3, R0
                MVI     R2, UP_HANDLED
                DSI                          ; Regiao critica
                LOAD    R1, M[R2]
                CMP     R1, R0
                BR.NZ   .ret                 ; Se foi handled, retorna 0
                INC     R3                   ; Se nao foi, retorna 1
                STOR    M[R2], R3                                               
.ret:           ENI
                JMP     R7
                
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@;
;                                                                              ;
;                         FUNCOES DOS GRAFICOS DO JOGO                         ;
;                                                                              ;
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@;

;==============================================================================;
; term_pos:     Posiciona o cursor do terminal na posicao correspondente.      ;
;               R1 <- nova linha                                               ;
;               R2 <- nova coluna                                              ;
;------------------------------------------------------------------------------;
term_pos:       MVI     R3, 8
.loop:          SHL     R1                   ; R1 <- (R1 << 8)
                DEC     R3
                BR.NZ   .loop
                OR      R1, R1, R2           ; R1 <- R1 OR R2
                MVI     R2, TERM_CURSOR
                STOR    M[R2], R1
                JMP     R7

;==============================================================================;
; term_color:   Muda a cor do proximo carater escrito no terminal.             ;
;               R1 <- nova cor                                                 ;
;------------------------------------------------------------------------------;
term_color:     MVI     R2, TERM_COLOR
                STOR    M[R2], R1
                JMP     R7

;==============================================================================;
; term_write:   Escreve um carater na posicao atual do terminal, e             ;
;               avanca a posicao de escrita.                                   ;
;               R1 <- novo carater                                             ;
;------------------------------------------------------------------------------;
term_write:     MVI     R2, TERM_WRITE
                STOR    M[R2], R1
                JMP     R7

;==============================================================================;
; term_clear:   Apaga o terminal (escreve um espaco em todas as posicoes)      ;
;------------------------------------------------------------------------------;
term_clear:     MVI     R1, TERM_CURSOR
                STOR    M[R1], R0            ; Fazer reset ao cursor
                MVI     R1, TERM_WRITE
                MVI     R2, 3600
.loop:          STOR    M[R1], R0
                DEC     R2
                BR.NZ   .loop
                JMP     R7

;==============================================================================;
; draw_many:    Escreve um carater N vezes.                                    ;
;               R1 <- carater                                                  ;
;               R2 <- N                                                        ;
;------------------------------------------------------------------------------;
draw_many:      DEC     R6                   ; Preservar contexto
                STOR    M[R6], R7
                DEC     R6
                STOR    M[R6], R4
                DEC     R6
                STOR    M[R6], R5

                MOV     R4, R1
                MOV     R5, R2

.loop:          MOV     R1, R4              ; Enquanto R5 >= 0, escreve R4 no
                JAL     term_write          ; terminal
                DEC     R5
                BR.NN   .loop

                LOAD    R5, M[R6]            ; Restaurar contexto
                INC     R6
                LOAD    R4, M[R6]
                INC     R6
                LOAD    R7, M[R6]
                INC     R6
                JMP     R7

;==============================================================================;
; draw_cactus:  Desenha um cato no terminal.                                   ;
;               R1 <- altura                                                   ;
;               R2 <- posicao                                                  ;
;------------------------------------------------------------------------------;
draw_cactus:    TEST    R1, R1               ; Se altura = 0, nao faz nada
                JMP.Z   R7
                
                DEC     R6                   ; Preservar contexto
                STOR    M[R6], R7
                DEC     R6
                STOR    M[R6], R4
                DEC     R6
                STOR    M[R6], R5
                
                MVI     R4, FLOOR_LINE       ; R4 contem a linha atual do cato
                                             ; (comeca no fundo)
                SUB     R5, R4, R1           ; R5 contem a linha do topo do cato
                
.loop:          DEC     R6
                STOR    M[R6], R2
                
                CMP     R2, R0
                BR.N    .first_col
                MVI     R3, 79
                CMP     R2, R3
                BR.Z    .last_col
                                             ; Se e uma coluna normal, desenha o
                MOV     R1, R4               ; cato nesta e apaga o cato na
                JAL     term_pos             ; seguinte
                MVI     R1, COLOR_CACTUS
                JAL     term_color
                MVI     R1, '░'
                JAL     term_write
                MVI     R1, COLOR_BG
                JAL     term_color
                MVI     R1, ' '
                JAL     term_write
                BR      .end_if
                                             ; Se e a coluna -1, apaga o cato na
.first_col:     MOV     R1, R4               ; coluna 0
                INC     R2
                JAL     term_pos
                MVI     R1, COLOR_BG
                JAL     term_color
                MVI     R1, ' '
                JAL     term_write
                BR      .end_if          
                                             ; Se e a ultima coluna, desenha o
.last_col:      MOV     R1, R4               ; cato na ultima coluna
                JAL     term_pos
                MVI     R1, COLOR_CACTUS
                JAL     term_color
                MVI     R1, '░'
                JAL     term_write

.end_if:        LOAD    R2, M[R6]
                INC     R6
                
                DEC     R4                   ; Passa para a linha superior
                CMP     R4, R5
                BR.P    .loop                ; Enquanto esta linha < topo
                
                LOAD    R5, M[R6]            ; Restaurar contexto
                INC     R6
                LOAD    R4, M[R6]
                INC     R6
                LOAD    R7, M[R6]
                INC     R6
                JMP     R7
                
;==============================================================================;
; draw_map:     Desenha o mapa no terminal.                                    ;
;               R1 <- endereco da primeira coluna                              ;
;               R2 <- numero de colunas                                        ;
;------------------------------------------------------------------------------;
draw_map:       DEC     R6                   ; Preservar contexto
                STOR    M[R6], R7
                DEC     R6
                STOR    M[R6], R4
                DEC     R6
                STOR    M[R6], R5
                
                MOV     R4, R1               ; R4 <- endereco primeiro elemento
                MOV     R5, R2               ; R5 <- indice atual
                DEC     R5
                
                MVI     R1, CACTUS_MAX
                MVI     R2, -1
                JAL     draw_cactus
                
.loop:          ADD     R1, R4, R5
                LOAD    R1, M[R1]
                MOV     R2, R5
                JAL     draw_cactus
                DEC     R5
                BR.NN   .loop
                
                LOAD    R5, M[R6]            ; Restaurar contexto
                INC     R6
                LOAD    R4, M[R6]
                INC     R6
                LOAD    R7, M[R6]
                INC     R6
                JMP     R7
              
;==============================================================================;
; draw_floor:   Desenha o chao.                                                ;
;               R1 <- numero de colunas                                        ;
;------------------------------------------------------------------------------;
draw_floor:     DEC     R6                   ; Preservar contexto
                STOR    M[R6], R7
                DEC     R6
                STOR    M[R6], R4
                DEC     R6
                STOR    M[R6], R5
                MOV     R4, R1
                DEC     R4
                
                MVI     R1, COLOR_FLOOR     ; Escolher cor do chao
                JAL     term_color
                
                MVI     R1, FLOOR_LINE      ; Posicionar cursor
                INC     R1
                MVI     R2, 0
                JAL     term_pos
                
                MVI     R1, FLOOR_LINE      ; Preparar loop
                MVI     R2, ROW_COUNT
                SUB     R5, R2, R1
                DEC     R5
                DEC     R5

.loop:          MVI     R1, '░'            ; Desenhar linhas ate ao fundo
                MOV     R2, R4             ; do terminal.
                JAL     draw_many
                DEC     R5
                BR.NN   .loop
                
                LOAD    R5, M[R6]          ; Restaurar contexto
                INC     R6
                LOAD    R4, M[R6]
                INC     R6
                LOAD    R7, M[R6]
                INC     R6
                JMP     R7

;==============================================================================;
; clear_player: Apaga o jogador.                                               ;
;               R1 <- linha dos pes                                            ;
;               R2 <- coluna dos pes                                           ;
;------------------------------------------------------------------------------;
clear_player:   DEC     R6                   ; Preservar contexto
                STOR    M[R6], R7
                DEC     R6
                STOR    M[R6], R4
                DEC     R6
                STOR    M[R6], R5
                                             ; Mudar cor
                MOV     R4, R1
                MOV     R5, R2
                MVI     R1, COLOR_BG
                JAL     term_color

                MOV     R1, R4               ; Apagar cauda
                MOV     R2, R5
                JAL     term_pos
                MVI     R1, ' ' 
                JAL     term_write

                DEC     R4
                MOV     R1, R4               ; Apagar pescoco
                MOV     R2, R5
                JAL     term_pos
                MVI     R1, ' '
                JAL     term_write
                
                DEC     R4
                MOV     R1, R4               ; Apagar cabeca
                MOV     R2, R5
                JAL     term_pos
                MVI     R1, ' '
                JAL     term_write
                
                LOAD    R5, M[R6]            ; Restaurar contexto
                INC     R6
                LOAD    R4, M[R6]
                INC     R6
                LOAD    R7, M[R6]
                INC     R6
                JMP     R7

;==============================================================================;
; draw_player:  Desenha o jogador.                                             ;
;               R1 <- linha dos pes                                            ;
;               R2 <- coluna dos pes                                           ;
;------------------------------------------------------------------------------;
draw_player:    DEC     R6                   ; Preservar contexto
                STOR    M[R6], R7
                DEC     R6
                STOR    M[R6], R4
                DEC     R6
                STOR    M[R6], R5
                                             ; Mudar cor
                MOV     R4, R1
                MOV     R5, R2
                MVI     R1, COLOR_DINO
                JAL     term_color
                                             
                MOV     R1, R4               ; Desenhar cauda
                MOV     R2, R5      
                JAL     term_pos
                MVI     R1, '⌡' 
                JAL     term_write

                DEC     R4
                MOV     R1, R4               ; Desenhar corpo
                MOV     R2, R5      
                JAL     term_pos
                MVI     R1, '▲' 
                JAL     term_write

                DEC     R4
                MOV     R1, R4               ; Desenhar cabeca
                MOV     R2, R5
                JAL     term_pos
                MVI     R1, '☺'
                JAL     term_write
                
                LOAD    R5, M[R6]            ; Restaurar contexto
                INC     R6
                LOAD    R4, M[R6]
                INC     R6
                LOAD    R7, M[R6]
                INC     R6
                JMP     R7

;==============================================================================;
; draw_text:    Desenha o texto no terminal.                                   ;
;               R1 <- endereco da string.                                      ;
;------------------------------------------------------------------------------;
draw_text:      DEC     R6                   ; Preservar contexto
                STOR    M[R6], R7
                DEC     R6
                STOR    M[R6], R4

.loop:          LOAD    R1, M[R4]            ; Escrever carateres ate chegar a 0
                INC     R4
                CMP     R1, R0
                BR.Z    .ret
                JAL     term_write
                BR      .loop

.ret:           LOAD    R4, M[R6]            ; Restaurar contexto
                INC     R6
                LOAD    R7, M[R6]
                INC     R6
                JMP     R7
     
;==============================================================================;
; draw_textbox: Desenha uma caixa de texto no centro de ecra.                  ;
;               R1 <- endereco da string.                                      ;
;------------------------------------------------------------------------------;
draw_textbox:   DEC     R6                   ; Preservar contexto
                STOR    M[R6], R7
                DEC     R6
                STOR    M[R6], R4
                DEC     R6
                STOR    M[R6], R5

                MOV     R4, R1
                JAL     str_len              ; Calcular tamanho da string
                DEC     R6
                STOR    M[R6], R3
                
                MVI     R1, COLOR_TEXTBOX
                JAL     term_color

                MVI     R2, COL_COUNT        ; Calcular primeira coluna do texto
                SHR     R2
                SHR     R3
                SUB     R2, R2, R3
                MOV     R5, R2

                MVI     R1, ROW_COUNT        ; Posicionar cursor
                SHR     R1
                DEC     R6
                STOR    M[R6], R1
                JAL     term_pos

                MOV     R1, R4               ; Desenhar texto
                JAL     draw_text

                LOAD    R4, M[R6]            ; R4 <- primeira linha
                INC     R6                   ; R5 <- primeira coluna
                DEC     R4
                DEC     R5
                                             ; Desenhar caixa a volta do texto
                MOV     R1, R4               ; Por cursor no canto superior
                MOV     R2, R5               ; esquerdo
                JAL     term_pos

                MVI     R1, '/'              ; Desenhar canto
                JAL     term_write

                MVI     R1, '-'              ; Desenhar topo da caixa
                LOAD    R2, M[R6]
                DEC     R2
                JAL     draw_many

                MVI     R1, '\'              ; Desenhar canto
                JAL     term_write

                INC     R4                   ; Por cursor no meio esquerdo
                MOV     R1, R4
                MOV     R2, R5
                JAL     term_pos

                MVI     R1, '|'              ; Desenhar lado esquerdo
                JAL     term_write

                LOAD    R1, M[R6]            ; Por cursor no meio direito
                MOV     R2, R5
                ADD     R2, R1, R2
                INC     R2
                MOV     R1, R4
                JAL     term_pos

                MVI     R1, '|'              ; Desenhar lado direito
                JAL     term_write
                
                INC     R4                   ; Por o cursor no canto inferior
                MOV     R1, R4               ; esquerdo
                MOV     R2, R5
                JAL     term_pos

                MVI     R1, '\'              ; Desenhar canto
                JAL     term_write

                MVI     R1, '-'              ; Desenhar fundo da caixa
                LOAD    R2, M[R6]
                DEC     R2
                JAL     draw_many

                MVI     R1, '/'              ; Desenhar canto
                JAL     term_write

                INC     R6                   ; Pop tamanho da string

                LOAD    R5, M[R6]            ; Restaurar contexto
                INC     R6
                LOAD    R4, M[R6]
                INC     R6
                LOAD    R7, M[R6]
                INC     R6
                JMP     R7

;==============================================================================;
; draw_game:    Desenha os elementos comuns aos estados 'Run', 'Jump' e        ;
;               'Fall'.                                                        ;
;------------------------------------------------------------------------------;
draw_game:      DEC     R6                   ; Preservar contexto
                STOR    M[R6], R7

                MVI     R1, MAP              ; Desenha o mapa
                MVI     R2, COL_COUNT
                JAL     draw_map

                MVI     R1, PLAYER_ROW_PREV  ; Apaga o jogador
                LOAD    R1, M[R1]
                MVI     R2, PLAYER_COL
                JAL     clear_player

                MVI     R1, PLAYER_ROW      
                LOAD    R1, M[R1]
                MVI     R2, PLAYER_ROW_PREV  ; Atualizar posicao anterior
                STOR    M[R2], R1
                MVI     R2, PLAYER_COL
                JAL     draw_player          ; Desenha o jogador

                LOAD    R7, M[R6]            ; Restaurar contexto
                INC     R6
                JMP     R7
                
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@;
;                                                                              ;
;                              ROTINAS AUXILIARES                              ;
;                                                                              ;
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@;

;===============================================================================
; str_len:      Calcula o numero de carateres de uma string.
;               R1 <- endereco da string.
;-------------------------------------------------------------------------------
str_len:        MOV     R3, R1
.loop:          LOAD    R2, M[R1]
                INC     R1
                CMP     R2, R0
                BR.NZ   .loop
                SUB     R3, R1, R3
                DEC     R3
                JMP     R7

;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@;
;                                                                              ;
;                       ROTINAS DE INTERRUPCAO AUXILIARES                      ;
;                                                                              ;
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@;

aux_timer_isr:  DEC     R6                   ; Preservar contexto
                STOR    M[R6], R1
                DEC     R6
                STOR    M[R6], R2

                MVI     R2, TIMER_COUNTER    ; Recomecar temporizador
                MVI     R1, TIMER_INTERVAL
                STOR    M[R2], R1
                MVI     R2, TIMER_CONTROL
                MVI     R1, TIMER_SETSTART
                STOR    M[R2], R1

                MVI     R1, TICKS            ; Incrementar TICKS
                LOAD    R2, M[R1]
                INC     R2
                STOR    M[R1], R2

                LOAD    R2, M[R6]            ; Restaurar contexto
                INC     R6
                LOAD    R1, M[R6]
                INC     R6
                JMP     R7

;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@;
;                                                                              ;
;                           ROTINAS DE INTERRUPCAO                             ;
;                                                                              ;
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@;

                ORIG    7F00h
key0_isr:       DEC     R6                   ; Preservar contexto
                STOR    M[R6], R1
                MVI     R1, KEY0_HANDLED     ; Atualizar KEY0_HANDLED
                STOR    M[R1], R0            
                LOAD    R1, M[R6]            ; Restaurar contexto
                INC     R6
                RTI
                
                ORIG    7F30h
up_isr:         DEC     R6                   ; Preservar contexto
                STOR    M[R6], R1
                MVI     R1, UP_HANDLED       ; Atualizar UP_HANDLED
                STOR    M[R1], R0
                LOAD    R1, M[R6]            ; Restaurar contexto
                INC     R6
                RTI

                ORIG    7FF0h
timer_isr:      DEC     R6                   ; Preservar contexto
                STOR    M[R6], R7
                JAL     aux_timer_isr        ; Chamar funcao auxiliar
                LOAD    R7, M[R6]            ; Restaurar contexto
                INC     R6
                RTI
