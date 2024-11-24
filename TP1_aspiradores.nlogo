turtles-own [energia lixo-recolhido capacidade-max localizacao-lixo localizacao-carregador tempo-despejo tempo-recarga energia-recarga ocupado total-lixo-recolhido idas-ao-carregador]
patches-own [potencial]
breed [aspiradores aspirador]
globals [lixo carregadores obstaculos total-idas-carregador total-idas-deposito]

to setup
  set total-idas-deposito 0

  clear-all
  reset-ticks
  create-aspiradores num_aspiradores
  setup-ambiente
  ask aspiradores [
    set total-lixo-recolhido 0
    set idas-ao-carregador 0
    set ocupado false
    set energia energia_asp
    set capacidade-max capacidade
    set tempo-despejo tempo-para-despejo
    set tempo-recarga tempo-para-recarga
    set energia-recarga energia-para-recarga
    set lixo-recolhido 0
    set shape "truck"
    setxy random-xcor random-ycor
    set localizacao-lixo nobody
    set localizacao-carregador nobody
    atualizar-cor
  ]
end

to go
  if (ticks >= max-ticks or count aspiradores = 0 or count patches with [pcolor = red] <= 0) [stop]

  if campo-potencial [ aplicar-campo-potencial ]

  ask aspiradores [
    if mostrar_energia [ set label energia ]
    if mostrar_lixo [ set label lixo-recolhido ]

    ; Lógica de recarga e despejo
    ifelse ocupado [
      ; Se o tempo de recarga terminou, reseta energia
      if pcolor = blue[
        ifelse (tempo-recarga <= 0) [
          set energia energia_asp
          set ocupado false
          set tempo-recarga tempo-para-recarga
        ]  [
          set tempo-recarga tempo-recarga - 1
        ]
      ]

      ; Se o tempo de despejo terminou, reseta lixo recolhido
      if pcolor = green [
        ifelse (tempo-despejo <= 0) [
          set lixo-recolhido 0
          set ocupado false
          set tempo-despejo tempo-para-despejo
          set total-idas-deposito total-idas-deposito + 1
        ]  [
          set tempo-despejo tempo-despejo - 1
        ]
      ]
    ] [
      if not ocupado [
        ifelse (energia <= energia-recarga) [
          procurar_carregador
        ] [
          ifelse (lixo-recolhido >= capacidade-max) [
            procurar_zona_despejo
          ] [
            ifelse kamikaze [
              ifelse ticks >= max-ticks / 2 [
                procura_lixo
              ] [
                coleta_lixo
              ]
              mover
            ] [
              ifelse campo-potencial [
                mover-com-potencial
              ] [
                mover
              ]
              coleta_lixo
              verifica_capacidade
              verifica_energia
            ]
          ]
        ]
      ]
    ]

    verifica_energia
    verificar_carregador_nas_vizinhancas
    troca_informacao
    atualizar-cor
  ]

  tick
end

to aplicar-campo-potencial
  ask patches [
    set potencial ifelse-value (pcolor = red) [0] [10000]
  ]
  repeat 10 [
    ask patches [
      let vizinhos neighbors4 with [pcolor != white]
      if any? vizinhos [
        let menor-potencial min [potencial] of vizinhos
        if potencial > menor-potencial + 1 [
          set potencial menor-potencial + 1
        ]
      ]
    ]
  ]
end

to mover-com-potencial
  let melhor-patch min-one-of neighbors4 with [pcolor != white] [potencial]
  if melhor-patch != nobody [ mover-para melhor-patch ]
end

to mover
  let proximo-passo one-of neighbors4 with [pcolor != white]
  if proximo-passo != nobody [
    move-to proximo-passo
    if not (pcolor = blue or pcolor = green) [
      set energia energia - 1  ; Reduz a energia ao mover
    ]
  ]
end

to mover-para [target]
  let proximo-patch min-one-of (neighbors4 with [pcolor != white]) [distance target]

  if proximo-patch != nobody [
    face proximo-patch
    move-to proximo-patch
    if not (pcolor = blue or pcolor = green) [
      set energia energia - 1  ; Reduz a energia ao mover
    ]
  ]
end

to procurar_carregador
  if energia <= energia-recarga [
    ifelse usar-carregador-mais-proximo [
      ; Mover para o carregador mais próximo
      let estacao-mais-proxima min-one-of patches with [pcolor = blue] [distance myself]
      if estacao-mais-proxima != nobody [
        mover-para estacao-mais-proxima
        if pcolor = blue [ recarregar ]
        set idas-ao-carregador idas-ao-carregador + 1
        set total-idas-carregador total-idas-carregador + 1
      ]
    ][
      ifelse localizacao-carregador != nobody [
        let estacao-mais-proxima localizacao-carregador
        mover-para estacao-mais-proxima
        if pcolor = blue [ recarregar ]
        set idas-ao-carregador idas-ao-carregador + 1
        set total-idas-carregador total-idas-carregador + 1
      ][
        ; Se usar-carregador-mais-proximo está desativado, mover aleatoriamente
        let proximo-passo one-of neighbors4 with [pcolor != white]
        if proximo-passo != nobody [
          move-to proximo-passo
          set energia energia - 1 ; Reduz a energia ao mover
        ]
      ]
    ]
  ]
end

to procurar_zona_despejo
  ifelse localizacao-lixo != nobody [
    ; Se o agente sabe onde está a zona de despejo, mover para lá
    mover-para localizacao-lixo
    if pcolor = green [
      despejar_lixo
    ]
  ][
    ; Se o agente não sabe, procurar a zona de despejo mais próxima
    ifelse usar-zona-despejo [
      let zona-mais-proxima min-one-of patches with [pcolor = green] [distance myself]
      if zona-mais-proxima != nobody [
        set localizacao-lixo zona-mais-proxima
        mover-para zona-mais-proxima
      ]
    ][
      ; Mover aleatoriamente enquanto não sabe onde está a zona de despejo
      let proximo-passo one-of neighbors4 with [pcolor != white]
      if proximo-passo != nobody [
        move-to proximo-passo
        set energia energia - 1
      ]
    ]
  ]
end

to procura_lixo
  let lixo-restante patches with [pcolor = red]
  if any? lixo-restante [
    let lixo-mais-proximo min-one-of lixo-restante [distance myself]
    face lixo-mais-proximo
    fd 1
    coleta_lixo
  ]
end

to verifica_energia
  if energia <= 0 [
    ask patch-here [ set pcolor white ]
    die
  ]
end

to setup-ambiente
  set lixo perc_lixo
  set carregadores num_carregadores
  set obstaculos num_obstaculos

  let num-lixo floor (perc_lixo * count patches / 100)
  ask n-of num-lixo patches [ set pcolor red ]

  ask n-of num_carregadores patches with [pcolor = black] [ set pcolor blue ]
  ask n-of num_obstaculos patches with [pcolor = black] [ set pcolor white ]

  let centro-x random-xcor
  let centro-y random-ycor
  ask patches with [
    pxcor >= centro-x - 1 and pxcor <= centro-x + 1 and
    pycor >= centro-y - 1 and pycor <= centro-y + 1
  ] [ set pcolor green ]
end

to troca_informacao
  let vizinhos other aspiradores in-radius 1 ; Encontra os agentes dentro da vizinhança
  if any? vizinhos [
    let vizinho one-of vizinhos

    ; Compartilhar localização do carregador
    if localizacao-carregador != nobody [
      ask vizinho [
        set localizacao-carregador [localizacao-carregador] of myself ; Compartilha a localização do carregador
      ]
    ]

    ; Compartilhar localização da zona de despejo
    if localizacao-lixo != nobody [
      ask vizinho [
        set localizacao-lixo [localizacao-lixo] of myself ; Compartilha a localização da zona de despejo
      ]
    ]
  ]
end

to atualizar-cor
  set color ifelse-value (energia > 50) [green] [ifelse-value (energia > 25) [yellow] [red]]
end

to coleta_lixo
  ifelse limpeza-em-area [
    ask neighbors [
      if pcolor = red [ set pcolor black ask myself [
        set lixo-recolhido lixo-recolhido + 1
        set total-lixo-recolhido total-lixo-recolhido + 1
        ]
      ]
    ]
  ][
    if pcolor = red and lixo-recolhido < capacidade-max [
      set pcolor black
      set lixo-recolhido lixo-recolhido + 1
      set total-lixo-recolhido total-lixo-recolhido + 1
    ]
  ]
end

to verifica_capacidade
  if lixo-recolhido >= capacidade-max [ procurar_zona_despejo ]
end

to verificar_carregador_nas_vizinhancas
  let vizinhos neighbors4

  ; Verificar se está numa zona de carregador (azul)
  if pcolor = blue [ set localizacao-carregador patch-here ]
  if any? (vizinhos with [pcolor = blue]) [
    set localizacao-carregador one-of (vizinhos with [pcolor = blue])
  ]

  ; Verificar se está numa zona de despejo (verde)
  if pcolor = green [ set localizacao-lixo patch-here ]
  if any? (vizinhos with [pcolor = green]) [
    set localizacao-lixo one-of (vizinhos with [pcolor = green])
  ]
end

to recarregar
  if pcolor = blue [ ; Verifica se o agente está na zona de carregador
    ifelse tempo-recarga > 0 [
      set ocupado true
      set tempo-recarga tempo-recarga - 1
    ][
      set energia energia_asp
      set ocupado false
      set tempo-recarga tempo-para-recarga
    ]
  ]
end

to despejar_lixo
  if pcolor = green [ ; Verifica se o agente está na zona de despejo
    ifelse tempo-despejo > 0 [
      set ocupado true
      set tempo-despejo tempo-despejo - 1
    ][
      set lixo-recolhido 0
      set ocupado false
      set tempo-despejo tempo-para-despejo
      set total-idas-deposito total-idas-deposito + 1
    ]
  ]
end

to-report total-de-idas-ao-deposito
  report total-idas-deposito
end

to-report total-de-idas-carregador
  report total-idas-carregador
end
@#$#@#$#@
GRAPHICS-WINDOW
482
10
919
448
-1
-1
13.0
1
10
1
1
1
0
0
0
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
306
400
369
433
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
230
400
294
433
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
9
10
181
43
num_aspiradores
num_aspiradores
1
20
10.0
1
1
NIL
HORIZONTAL

SLIDER
192
10
364
43
capacidade
capacidade
1
30
10.0
1
1
NIL
HORIZONTAL

SLIDER
8
54
180
87
energia_asp
energia_asp
1
100
100.0
1
1
NIL
HORIZONTAL

SLIDER
193
54
365
87
perc_lixo
perc_lixo
0
60
60.0
1
1
NIL
HORIZONTAL

SLIDER
8
97
180
130
num_carregadores
num_carregadores
0
5
5.0
1
1
NIL
HORIZONTAL

SLIDER
193
97
365
130
num_obstaculos
num_obstaculos
0
100
70.0
1
1
NIL
HORIZONTAL

SLIDER
194
143
366
176
tempo-para-despejo
tempo-para-despejo
0
20
7.0
1
1
NIL
HORIZONTAL

SLIDER
8
187
180
220
tempo-para-recarga
tempo-para-recarga
0
20
10.0
1
1
NIL
HORIZONTAL

SLIDER
8
143
180
176
energia-para-recarga
energia-para-recarga
0
100
25.0
1
1
NIL
HORIZONTAL

PLOT
10
286
210
436
Nº agentes vs quantidade lixo
Ticks
Amount
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"agentes" 1.0 0 -13840069 true "" "plot count turtles"
"lixo" 1.0 0 -2674135 true "" "plot count patches with [pcolor = red]"

MONITOR
9
230
102
275
Nº de agentes
count turtles
17
1
11

MONITOR
123
231
180
276
Lixo
count patches with [pcolor = red]
17
1
11

INPUTBOX
199
191
354
251
max-ticks
10000.0
1
0
Number

SWITCH
7
496
112
529
kamikaze
kamikaze
1
1
-1000

SWITCH
6
456
153
489
mostrar_energia
mostrar_energia
0
1
-1000

SWITCH
165
457
388
490
usar-carregador-mais-proximo
usar-carregador-mais-proximo
1
1
-1000

SWITCH
122
497
265
530
limpeza-em-area
limpeza-em-area
1
1
-1000

SWITCH
278
498
424
531
campo-potencial
campo-potencial
1
1
-1000

SWITCH
434
498
593
531
usar-zona-despejo
usar-zona-despejo
1
1
-1000

MONITOR
229
334
378
379
NIL
total-de-idas-carregador
3
1
11

SWITCH
396
457
520
490
mostrar_lixo
mostrar_lixo
1
1
-1000

MONITOR
229
277
383
322
NIL
total-de-idas-ao-deposito
3
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
