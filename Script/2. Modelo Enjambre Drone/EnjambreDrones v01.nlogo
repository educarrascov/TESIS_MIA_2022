;;
;; Extensiones Netlogo
;;
extensions [array]   ; Para manejo de arregos

;;
;; Variables globales
;;
globals [
  q-size-objeto
  q-size-drone
  q-size-torre-control
  q-objetos  ; Cantidad de turtles objetos (NO nocivos + nocivos)
  q-visibles ; Cantidad de turtles totales (drones + objetos NO nocivos + objetos nocivos)
  x-lejano   ; coordenada x (abscisa) del punto más lejano del centroide del mundo
  y-lejano   ; coordenada y (ordenada) del punto más lejano del centroide del mundo
]

;;
;; Propiedades para los turtles
;;
turtles-own [
  tipo               ; torre-control, objeto o drone
  subtipo            ; solo para tipo objeto: NO-nocivo o nocivo
  id-last            ; solo para tipo drone, contiene el id del último objeto asignado a la ruta
  xcor-last          ; solo para tipo drone, contiene la coordenada x (abscisa) del último objeto asignado a la ruta
  ycor-last          ; solo para tipo drone, contiene la coordenada y (ordenada) del último objeto asignado a la ruta
  id-area-asignada   ; solo para tipo drone, contiene el id de la zona asignada
  id-drone-asignado  ; solo para tipo objeto, contiene el id del drone asignado
  prioridad          ; solo para tipo objeto, contiene orden de la ruta
]

;;
;; Propiedades para los links
;;
links-own [
  tipo-link          ;
  id-drone           ; drone de la ruta
]

;;
;; GO !!!
;;
to go
  ;show "GO!!!"
  tick
end

;;
;; 1 tick on-demmand
;;
to go-1-tick
  go
end

;;
;; Configuración inicial
;;
to setup
  clear-all
  setup_globals
  setup_turtles
  setup_drones_to_objetos
  reset-ticks
end

;;
;; Configuracion de variables iniciales
;;
to setup_globals
  ; comportamiento
  set q-size-objeto 7
  set q-size-drone 10
  set q-size-torre-control 15

  ; mundo
  ask patches [set pcolor white - 3]

  ; bordes
  set q-objetos-nocivos round(q-objetos-NO-nocivos * porc-objetos-nocivos / 100)
  set q-objetos q-objetos-NO-nocivos + q-objetos-nocivos
  set q-visibles 1 + q-drones + q-objetos-NO-nocivos + q-objetos-nocivos

  ; arreglos para áreas
  set x-lejano array:from-list n-values 4 [0]
  set y-lejano array:from-list n-values 4 [0]

  ; Area 1 (arriba a la izquierda)
  array:set x-lejano 0 max-pxcor * -1
  array:set y-lejano 0 max-pycor


  ; Area 2 (arriba a la derecha)
  array:set x-lejano 1 max-pxcor
  array:set y-lejano 1 max-pycor

  ; Area 3 (abajo a la derecha)
  array:set x-lejano 2 max-pxcor
  array:set y-lejano 2 max-pycor * -1

  ; Area 4 (abajo a la izquierda)
  array:set x-lejano 3 max-pxcor * -1
  array:set y-lejano 3 max-pycor * -1

  ;print x-lejano
  ;print y-lejano
end

;;
;; Configuración de turtles
;;
to setup_turtles
  ;; Drones
  set-default-shape turtles "wheel"
  let rec 0
  while [rec < q-drones]
  [
    create-turtles 1 [
      set tipo "drone"
      set subtipo ""
      set xcor-last -1
      set ycor-last -1
      set id-area-asignada -1
      set id-drone-asignado -1
      set prioridad -1
      set prioridad -1
      set color blue
      set size q-size-drone
      move-to one-of patches
    ]
    set rec rec + 1
  ]

  ;; Objetos NO nocivos
  set-default-shape turtles "box"
  set rec 0
  while [rec < q-objetos-NO-nocivos]
  [
    create-turtles 1 [
      set tipo "objeto"
      set subtipo "NO-nocivo"
      set xcor-last -1
      set ycor-last -1
      set id-area-asignada -1
      set id-drone-asignado -1
      set prioridad -1
      set color green
      set size q-size-objeto
      move-to one-of patches
    ]
    set rec rec + 1
  ]

  ;; Objetos nocivos
  set-default-shape turtles "box"
  set rec 0
  while [rec < q-objetos-nocivos]
  [
    create-turtles 1 [
      set tipo "objeto"
      set subtipo "NO-nocivo"
      set xcor-last -1
      set ycor-last -1
      set id-area-asignada -1
      set id-drone-asignado -1
      set prioridad -1
      set color red
      set size q-size-objeto
      move-to one-of patches
    ]
    set rec rec + 1
  ]

  ;; Torre de control
  set-default-shape turtles "hexagonal prism"
  create-turtles 1 [
    set tipo "torre-control"
    set subtipo ""
    set xcor-last -1
    set ycor-last -1
    set id-area-asignada -1
    set id-drone-asignado -1
    set prioridad -1
    setxy 0 0
    set color gray
    set size q-size-torre-control
  ]
end

;;
;; Asignar drones a objetos - planificación de rutas (el más cerca primero)
;;
to setup_drones_to_objetos
  ; nos mantenemos en un ciclo global, mientras queden objetos por asignar a alguna ruta
  let b-quedan-objetos true ; para usar mientras queden objetos por asignar
  let prioridad-recorrido 0
  let xcor-drone -1
  let ycor-drone -1
  while [b-quedan-objetos]
  [
    ; recorremos drones para determinar cual es el objeto más cercano y que no esté asignado previamente a alguna ruta
    let rec-drone 0
    while [rec-drone < q-drones]
    [
      ; recorremos objetos para determinar el más cercano
      let rec-objeto 0
      let distancia-menor max-pxcor * 4 ; distancia grande para que entre la primera vez
      let id-objeto-a-asignar -1
      let b-entro false
      while [rec-objeto < q-visibles][
        ; verificamos si el drone tiene la menor distancia al punto lejano
        ask turtle rec-objeto [
          if tipo = "objeto" and id-drone-asignado = -1 ; es objeto y no tiene drone asignado
          [
            ifelse prioridad-recorrido = 0 [ ; primera vez para cada drone
              ask turtle rec-drone [
                set xcor-drone xcor
                set ycor-drone ycor
              ]
            ]
            [
              ask turtle rec-drone [
                set xcor-drone xcor-last
                set ycor-drone ycor-last
              ]
            ]
            let distancia-drone-a-objeto F-distancia-2coordenadas xcor-drone ycor-drone xcor ycor ; obtenemos la distancia efectiva entre el dron y el objeto
            show (word "rec-drone:" rec-drone " rec-objeto:" rec-objeto " distancia: " distancia-drone-a-objeto)
            if distancia-drone-a-objeto < distancia-menor [
              set distancia-menor distancia-drone-a-objeto
              set id-objeto-a-asignar rec-objeto
              set b-entro true
            ]
          ]
        ]
        set rec-objeto rec-objeto + 1
      ]
      ; asignamos el dron al objeto
      ifelse  b-entro [
        ; creamos link
        ifelse prioridad-recorrido = 0 [ ; primera asignación por drone ?
          ask turtle rec-drone [
            ask turtles with [who = id-objeto-a-asignar][create-link-with turtle rec-drone]
            ask links with [tipo-link != "ok"][
              set tipo-link "ok"
              set id-drone rec-drone
              set thickness 1
              set color F-color-ruta rec-drone
            ]
          ]
        ]
        [
          ; obtenemos el último id asignado al drone
          ask turtle rec-drone [
            let id-tmp id-last
            ask turtle id-tmp [
              ask turtles with [who = id-objeto-a-asignar][create-link-with turtle id-tmp]
              ask links with [tipo-link != "ok"][
                set tipo-link "ok"
                set id-drone rec-drone
                set thickness 1
                set color F-color-ruta rec-drone
              ]
            ]
          ]
        ]

        ; asignar objeto al drone
        show (word "Objeto asignado: " id-objeto-a-asignar)
        ask turtle id-objeto-a-asignar [
          set id-drone-asignado rec-drone
          set prioridad prioridad-recorrido
          set label (word prioridad)
          ; registramos en el dron los datos del objeto asignado, datos para link en la sigueinte pasada
          let xcor-last-objeto xcor
          let ycor-last-objeto ycor
          let id-last-objeto who
          ask turtle rec-drone [
            set xcor-last xcor-last-objeto
            set ycor-last ycor-last-objeto
            set id-last id-last-objeto
          ]
        ]

      ]
      [
        set b-quedan-objetos false
      ]
      set rec-drone rec-drone + 1
    ]
    set prioridad-recorrido prioridad-recorrido + 1
  ]
end

;;
;; Función distancia entre 2 puntos
;;
to-report F-distancia-2coordenadas [x1 y1 x2 y2]
  ;show (word x1 " " y1 " " x2 " " y2)
  report sqrt( ((x2 - x1) ^ 2) + ((y2 - y1) ^ 2))
end

;;
;; Función para establecer color de ruta para cada drone
;;
to-report F-color-ruta [rec-drone]
  let color-ruta random 140
  ifelse rec-drone = 0 [
    set color-ruta gray
  ]
  [
    ifelse rec-drone = 1 [
      set color-ruta yellow
    ]
    [
    ifelse rec-drone = 2 [
      set color-ruta violet
    ]
    [
      set color-ruta turquoise
    ]
    ]
  ]
  report color-ruta
end
@#$#@#$#@
GRAPHICS-WINDOW
226
15
953
743
-1
-1
2.8
1
15
1
1
1
0
0
0
1
-128
128
-128
128
0
0
1
ticks
30.0

BUTTON
14
17
78
50
NIL
Setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
81
17
145
50
NIL
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
149
17
213
50
1 tick
go-1-tick
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
16
63
212
96
q-drones
q-drones
1
4
4.0
1
1
NIL
HORIZONTAL

SLIDER
16
102
212
135
q-objetos-NO-nocivos
q-objetos-NO-nocivos
0
200
40.0
1
1
NIL
HORIZONTAL

SLIDER
16
142
211
175
porc-objetos-nocivos
porc-objetos-nocivos
0
100
20.0
1
1
%
HORIZONTAL

INPUTBOX
16
179
117
239
q-objetos-nocivos
8.0
1
0
Number

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

hexagonal prism
false
0
Rectangle -7500403 true true 90 90 210 270
Polygon -1 true false 210 270 255 240 255 60 210 90
Polygon -13345367 true false 90 90 45 60 45 240 90 270
Polygon -11221820 true false 45 60 90 30 210 30 255 60 210 90 90 90

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
NetLogo 6.2.1
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
