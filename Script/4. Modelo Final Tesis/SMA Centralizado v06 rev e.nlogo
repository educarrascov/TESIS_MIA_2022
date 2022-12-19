;;to do:
;;[3:15 p. m., 19/5/2022] Gustavo Jara Valdés: 1. ajustar el códio para usar la librería subsumption de canessa
;;[3:15 p. m., 19/5/2022] Gustavo Jara Valdés: 2. cambiar los objetos entreda por monitores (reflejan mejor que son métricas)
;;   - Aplicar breads para especializar por tipo de objeto
;;   - Ordenar código para demostrar capas de la arquitectura subsunción y aplicación reactiva de los drones (Aplicar librería by Canessa)
;;   - Calcular trayectoria de la embarcación para que el dron lo intercepte (no lo siga sino que siga su trayectoria)
;;   - Dejar paramétricos los valores de administración de energía
;;   - Ajustar el modelo de administración de energía para que siempre haya al menos 1 dron en vuelo
;;   - Hacer que los barcos rojos (de proyección) no pasen por sobre el buque
;;   - Ajustar rutina de desviación de embarcaciones para que no intercepten (choquen) con el buque
;;   - Hacer wrap de las embarcaciones sin dejar el mundo como toroide
;;   - Revisar rutina de acercamiento de embarcaciones por el este y oeste (se acercan mucho al buque)


;; velocidades
;; Drones: 12.8 mt/s = 46 Km/h = 0,8 puntos/tick          rango: 7 a 8
;; Embarcaciones: 9,4 nudos 4.8 mt/seg = 17,4 km/hora     rango: 1 a 3
;; Energía:
;;      Consumo: 100% es para 800 ticks (13.3 min) -> cada tick (seg) en vuelo consume 1/8 de almacenamiento
;;      Recarga: Cada tick para cada drone aterrizado recarga 1.2 (2 min para carga total desde 0) y despega cuando alcanza un 75%
;;      En vuelo: Regresa a la torre de control con una holgura de 10%

;;
;; Extensiones Netlogo
;;
extensions [array]   ; Para manejo de arregos

;;
;; Breads
;;
directed-link-breed [mi-directed-links mi-directed-link]

;;
;; Variables globales
;;
globals [
  q-size-objeto
  q-size-drone
  id-primer-drone ;
  q-size-torre-control
  q-visibles                 ; Cantidad de turtles totales (drones + objetos NO nocivos + objetos nocivos)
  k-lejania-borde
  k-lejanía-torre-control    ; el radio de lejanía a la torre de control
  b-primer-paso-simulacion
  k-perimetro-radar          ; el radio de alcance del radar
  x-initial-position-drone
  y-initial-position-drone
  x-initial-position-store
  y-initial-position-store
  x-initial-position-label-store
  y-initial-position-label-store
  k-consumo-por-tick
  k-recarga-por-tick
  k-holgura-regreso-a-torre
  k_almacenamiento-minimo
  b-blink-drone
  k-blink-drone
  n-blink-count

  ; Para estadísticas
  total-dr
  prom-dr
  dev-est-dr
  total-objetivos
  prom-objetivos
  dev-est-objetivos
  total-tpo-vuelo
  prom-tpo-vuelo
  dev-est-tpo-vuelo
  total-consumo
  prom-consumo
  dev-est-consumo
]

;;
;; Propiedades para los turtles
;;
turtles-own [
  tipo                 ; torre-control, objeto o drone
  subtipo              ; solo para tipo objeto: NO-nocivo o nocivo
  id-origen            ; solo para tipo drone, contiene el id del último objeto asignado en la ruta (origen)
  id-destino           ; solo para tipo drone, contiene el id del último objeto asignado en la ruta (destino)
  id-drone-asignado    ; solo para tipo objeto, contiene el id del drone asignado
  estado               ; Para tipo drone y objeto
  estado-energia       ; Para tipo drone
  distancia            ; solo para tipo objetos
  distancia-recorrida  ; solo para tipo drone, en metros
  tiempo-vuelo         ; solo para tipo drone, en segundos
  objetivos            ; solo para tipo drone, en cantidad
  consumo              ; solo para tipo drone, en watts
  b-en-perimetro-radar ; solo para tipo objeto
  velocidad            ; Para tipo drone y objeto
  almacenamiento       ; 0 a 100%
]

;;
;; Propiedades para los links
;;
links-own [
  id-origen-link
  id-destino-link
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;
;; SIMULACIÓN
;;
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;
;; GO !!!
;;
to go
  main-simulation
  tick
end

;;
;; 1 tick on-demmand
;;
to go-1-tick
  go
end

;;
;; Simulación
;;
to main-simulation
  ; Aplicar probabilidad de perder un drone
  ask turtles with [tipo = "drone" and subtipo = "inspector"][
    if estado = "en-ruta" [
      ;if (random(100 + 1) * random(aplicar-prob-en-n-ticks + 1) < probabilidad-perder-drone)[
      if precision ((random 10000 + 1) / 100) 2 <= probabilidad-perder-drone[
        set estado "perdido"
        set color gray
      ]
    ]
  ]

  ; Energía
  if administracion-energia [
    ask turtles with [tipo = "drone" and subtipo = "inspector"][
      ifelse estado = "en-ruta" [
        ; consumo
        set almacenamiento precision (almacenamiento - k-consumo-por-tick) 4
        set consumo precision (consumo + k-consumo-por-tick + random 4) 4
      ]
      [
        if estado = "aterrizado" [
          ; recarga
          set almacenamiento precision(almacenamiento + k-recarga-por-tick) 4
          if almacenamiento > 100 [
            set almacenamiento 100
          ]
        ]
      ]
      F-despliega-almacenamiento who
    ]
  ]

  ; mostrar/ocultar links de comunicaciones
  ask turtles with [tipo = "drone" and subtipo = "inspector"][
    let tmp-id-drone who
    let tmp-x xcor
    let tmp-y ycor
    let tmp-estado estado
    ask links with [id-origen-link = tmp-id-drone and id-destino-link = 0][
      ;ifelse ((F-distancia-2coordenadas tmp-x tmp-y 0 0) <= k-lejanía-torre-control / 3 * 2)[
      ifelse (tmp-estado = "aterrizado" or tmp-estado = "perdido")[
        hide-link
      ]
      [
        show-link
      ]
    ]
  ]

  ; movimiento de los objetos
  ask turtles with [tipo = "object" and estado = "non-inspected"][
    ;pendown
    forward precision (velocidad / 10) 1

    ; para non-inspected
    if estado = "non-inspected" [
      ; determinar si está en el perimetro del radar
      ifelse (F-dentro-del-perimetro xcor ycor)[
        set b-en-perimetro-radar true
        set color black
      ]
      [
        set b-en-perimetro-radar false
        set color gray
      ]

      ; determinar si llegó a los bordes para hacerlo rebotar
      ; superior
      if (ycor > max-pycor - k-lejania-borde)[
        set heading (random 180) + 90
      ]
      ; inferior
      if (ycor * -1 > max-pycor - k-lejania-borde)[
        ifelse (random(100) < 50)[
          set heading (random 90)
        ]
        [
          set heading (random 90) + 270
        ]
      ]
      ; derecha
      if (xcor > max-pxcor - k-lejania-borde)[
        set heading (random 180) + 180
      ]
      ; izquierda
      if (xcor * -1 > max-pxcor - k-lejania-borde)[
        set heading (random 180)
      ]
    ]
    ;
    ; determinar si se acerca al perímetro del buque para cambiarle la dirección non-insected e inspected-referential
    ;
    if F-distancia-2coordenadas xcor ycor 0 0 <= k-lejanía-torre-control [
      let tmp-menor-distancia 0
      let tmp-menor-cardinal ""
      let tmp-distancia-al-norte F-distancia-2coordenadas xcor ycor 0 k-lejanía-torre-control
      let tmp-distancia-al-sur F-distancia-2coordenadas xcor ycor 0 (k-lejanía-torre-control * -1)
      ifelse tmp-distancia-al-norte < tmp-distancia-al-sur
      [
        set tmp-menor-distancia tmp-distancia-al-norte
        set tmp-menor-cardinal "N"
      ]
      [
        set tmp-menor-distancia tmp-distancia-al-sur
        set tmp-menor-cardinal "S"
      ]
      let tmp-distancia-al-este F-distancia-2coordenadas xcor ycor k-lejanía-torre-control 0
      if tmp-distancia-al-este <  tmp-menor-distancia
      [
        set tmp-menor-distancia tmp-distancia-al-este
        set tmp-menor-cardinal "E"
      ]
      let tmp-distancia-al-oeste F-distancia-2coordenadas xcor ycor (k-lejanía-torre-control * -1) 0
      if tmp-distancia-al-oeste <  tmp-menor-distancia
      [
        set tmp-menor-distancia tmp-distancia-al-oeste
        set tmp-menor-cardinal "O"
      ]
      let k-holgura 10
      let tmp-b-asignado false
      if (tmp-menor-cardinal = "N") [
        ;pendown
        if (xcor >= 0 - k-holgura and not tmp-b-asignado)[
          ifelse (heading >= 180 and heading <= 180 + 45) [
            set tmp-b-asignado true
            set heading heading - 90
          ]
          [
            if (heading >= 180 + 45 and heading <= 270) [
              set tmp-b-asignado true
              set heading heading + 90
            ]
          ]
        ]
        if (xcor <= 0 + k-holgura and not tmp-b-asignado)[
          ifelse (heading >= 90 and heading <= 90 + 45) [
            set tmp-b-asignado true
            set heading heading - 90
          ]
          [
            if (heading >= 90 + 45 and heading <= 180) [
              set tmp-b-asignado true
              set heading heading + 90
            ]
          ]
        ]
      ]
      if (tmp-menor-cardinal = "S") [
        ;pendown
        if (xcor >= 0 - k-holgura and heading >= 270 and heading <= 270 + 45) [
          ;set color red
          set heading heading - 90
        ]
        if (xcor >= 0 - k-holgura and heading >= 270 + 45 and heading <= 360) [
          ;set color violet
          set heading heading + 90
        ]
        if (xcor <= 0 + k-holgura and heading >= 0 and heading <= 45) [
          ;set color red
          set heading heading - 90
        ]
        if (xcor <= 0 + k-holgura and heading >= 45 and heading <= 90) [
          ;set color violet
          set heading heading + 90
        ]
      ]
      if (tmp-menor-cardinal = "E") [
        ;pendown
        if (ycor >= 0 - k-holgura and heading >= 180 and heading <= 180 + 45) [
          ;set color red
          set heading heading - 90
        ]
        if (ycor >= 0 - k-holgura and heading >= 180 + 45 and heading <= 270) [
          ;set color violet
          set heading heading + 90
        ]
        if (ycor <= 0 + k-holgura and heading >= 270 and heading <= 270 + 45) [
          ;set color red
          set heading heading - 90
        ]
        if (ycor <= 0 + k-holgura and heading >= 270 + 45 and heading <= 360) [
          ;set color violet
          set heading heading + 90
        ]
      ]
      if (tmp-menor-cardinal = "O") [
        ;pendown
        if (ycor >= 0 - k-holgura and heading >= 90 and heading <= 90 + 45) [
          ;set color red
          set heading heading - 90
        ]
        if (ycor >= 0 - k-holgura and heading >= 90 + 45 and heading <= 180) [
          ;set color violet
          set heading heading + 90
        ]
        if (ycor <= 0 + k-holgura and heading >= 0 and heading <= 45) [
          ;set color red
          set heading heading - 90
        ]
        if (ycor <= 0 + k-holgura and heading >= 45 and heading <= 90) [
          ;set color violet
          set heading heading + 90
        ]
      ]
    ]
  ]

  ; movimiento de los objetos referenciales
  ask turtles with [tipo = "object" and estado = "inspected-referential"][
    let tmp-velocidad -1
    ask turtle (who - q-embarcaciones)[
      set tmp-velocidad velocidad
    ]
    forward precision (tmp-velocidad / 10) 1
  ]

  ; recorremos los drones en ruta para que avancen a su objetivo
  let b-actualiza-estadisticas false
  ask turtles with [tipo = "drone" and subtipo = "inspector" and estado = "en-ruta"][
  ;ask turtles with [tipo = "drone" and subtipo = "inspector"][
    let tmp-xcor-drone xcor
    let tmp-ycor-drone ycor
    if estado = "en-ruta" [
      set distancia-recorrida distancia-recorrida + velocidad ; en mt, velocidad en mt/seg
      set tiempo-vuelo tiempo-vuelo + 1 ; 1 tick = 1 seg
      ;set consumo consumo + (k-consumo-tick)
      set b-actualiza-estadisticas true
      forward precision (velocidad / 10) 1
      F-actualizar-xy-almacenamiento who
    ]

    let tmp-id-drone who
    let tmp-id-origen id-origen
    let tmp-id-destino id-destino
    let tmp-color color
    let b-aterrizar false
    let tmp-estado "en-ruta"
    let b-ajustar-heading false
    let tmp-heading -1
    let tmp-xcor-destino -1
    let tmp-ycor-destino -1
    ask turtle id-destino [
      set tmp-xcor-destino xcor
      set tmp-ycor-destino ycor
      ifelse (F-rango round(tmp-xcor-drone) round(tmp-ycor-drone) xcor ycor 2)[  ; Drone llegó al objeto ?
        ; si el drone llega a su punto origen, lo aterrizamos
        ifelse (tmp-id-drone - q-drones = tmp-id-destino) [ ; regresó a la torre de control ?
          set b-aterrizar true
          set tmp-estado "aterrizado"
          set tmp-xcor-drone xcor
          set tmp-ycor-drone ycor

          ; Borrar link del objeto anterior al drone
          ;F-elimina-link tmp-id-origen tmp-id-drone

          ; crear link del objeto actual al drone
          ;F-crea-link tmp-id-origen tmp-id-drone tmp-color 1.5

          ; aterrizarlo mirando al norte
          ask turtles with [who = tmp-id-drone][
            set heading 0 ; Finaliza mirando al norte (todo: no lo deja aterrizado al norte)
          ]
        ]
        [ ; else, implica que encontró un objeto
          ;
          ; Inspeccionarlo para determinar nivel de nocividad
          ;
          set estado "inspected"
          ask turtle tmp-id-drone [
            set objetivos objetivos + 1
          ]
          ; determinar nocividad en base a una probabilidad
          ifelse (random(100) <= probabilidad-nocividad) [
            set subtipo "nocive"
            set color red
            F-dibuja-circulo xcor ycor q-size-drone / 2 * 1.1 color 1.6 true ; lo marcamos con un cículo rojo
          ]
          [
            set subtipo "non-nocive"
            set color green - 1
            set size q-size-drone / 3 * 2
            F-dibuja-circulo xcor ycor q-size-drone / 3 color 1 true ; lo marcamos con un cículo rojo
          ]
          let tmp-subtipo subtipo

          ;
          ; Ajustar links
          ;

          ; Crear link desde el objeto anterior al actual
          ;F-crea-link tmp-id-origen tmp-id-destino tmp-color 1.5

          ; Borrar link del objeto anterior al drone
          ;F-elimina-link tmp-id-origen tmp-id-drone

          ; crear link del objeto actual al drone
          ;F-crea-link tmp-id-destino tmp-id-drone tmp-color 0.4

          ; el destino inspeccionado ahora pasa a ser el origen
          ask turtles with [who = tmp-id-drone][
            set id-origen tmp-id-destino
          ]

          ;
          ; hablitar objeto referencial asociado que continue el movimiento
          ;
          if (tmp-subtipo = "nocive")[
            let tmp-heading-al-inspeccionar heading
            ask turtle (who + q-embarcaciones) [
              set estado "inspected-referential"
              set xcor tmp-xcor-destino
              set ycor tmp-ycor-destino
              set heading tmp-heading-al-inspeccionar
              set shape "boat 3"
              ifelse tmp-subtipo = "nocive" [
                set color red
              ]
              [
                set color grey + 1
              ]
              show-turtle
            ]

            ; crear link entre el objeto inspeccionado y su referencial
            ifelse (subtipo = "nocive")[
              F-crea-link tmp-id-destino tmp-id-destino + q-embarcaciones red + 1 0.1 "discontinuo"
            ]
            [
              F-crea-link tmp-id-destino tmp-id-destino + q-embarcaciones grey + 1 0.1 "discontinuo"
            ]
          ]
        ]
      ]
      [ ; como no ha llegado el drone a destino, ajustamos precisión en su dirección
        set b-ajustar-heading true
        set tmp-heading F-direction tmp-xcor-drone tmp-ycor-drone tmp-xcor-destino tmp-ycor-destino
      ]
      ;
      ; buscar nuevo objetivo, ajustar rutas y calibrar direcciones
      ;
      ;F-asigna-mas-cercano-OBJ
    ]
    if (b-aterrizar)[
      set estado tmp-estado
      set xcor tmp-xcor-drone
      set ycor tmp-ycor-drone
      F-actualizar-xy-almacenamiento tmp-id-drone
    ]
    if (b-ajustar-heading)[
      set estado tmp-estado
      set heading tmp-heading
    ]
  ]

  ; actualiza estadísticas
  if (b-actualiza-estadisticas)[
    let tmp-total-dr 0
    let tmp-total-tpo-vuelo 0
    let tmp-total-objetivos 0
    let tmp-total-consumo 0
    ask turtles with [tipo = "drone" and subtipo = "inspector"][
      set tmp-total-dr tmp-total-dr + distancia-recorrida
      set tmp-total-tpo-vuelo tmp-total-tpo-vuelo + tiempo-vuelo
      set tmp-total-objetivos tmp-total-objetivos + objetivos
      set tmp-total-consumo tmp-total-consumo + consumo
    ]
    set total-dr tmp-total-dr
    set total-tpo-vuelo tmp-total-tpo-vuelo
    set total-objetivos tmp-total-objetivos
    set total-consumo tmp-total-consumo
    set prom-dr precision (total-dr / q-drones) 1
    set prom-tpo-vuelo precision (total-tpo-vuelo / q-drones) 1
    set prom-objetivos precision (total-objetivos / q-drones) 1
    set prom-consumo precision (total-consumo / q-drones) 1
    ifelse q-drones > 1 [
      set dev-est-dr precision (standard-deviation [distancia-recorrida] of turtles with [tipo = "drone" and subtipo = "inspector"]) 1
      set dev-est-tpo-vuelo precision (standard-deviation [tiempo-vuelo] of turtles with [tipo = "drone" and subtipo = "inspector"]) 1
      set dev-est-objetivos precision (standard-deviation [objetivos] of turtles with [tipo = "drone" and subtipo = "inspector"]) 1
      set dev-est-consumo precision (standard-deviation [consumo] of turtles with [tipo = "drone" and subtipo = "inspector"]) 1
    ]
    [
      set dev-est-dr 0
      set dev-est-tpo-vuelo 0
      set dev-est-objetivos 0
      set dev-est-consumo 0
    ]
  ]
  ;
  ; buscar nuevo objetivo, ajustar rutas y calibrar direcciones
  ;
  F-asigna-mas-cercano-OBJ
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;
;; CONFIGURACIÓN INICIAL
;;
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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
  set q-size-objeto 11
  set q-size-drone 10
  set q-size-torre-control 10
  set id-primer-drone 1 + q-embarcaciones * 2 + q-drones
  set k-lejania-borde 5
  set k-lejanía-torre-control 45
  set b-primer-paso-simulacion false
  set k-perimetro-radar max-pxcor - k-lejania-borde * 2
  ;set k-consumo-por-tick 1 / 8
  set k-consumo-por-tick 0.0303 ; equivalente a autonomía de a 3300 ticks, si 1 tick = 1 seg -> 55 minutos
  ;set k-recarga-por-tick 1.2 ; estaba en 1 / 12
  set k-recarga-por-tick 0.1818 ; equivalente a recarga en 550 ticks, si 1 tick = 1 seg -> 9,2 minutos
  set k-holgura-regreso-a-torre 10
  set k_almacenamiento-minimo 75

  ; blink a drones durante carga
  set b-blink-drone true
  set k-blink-drone 20
  set n-blink-count 0

  ; posición inicial de drones
  ; abscisa (x) posición inicial drones
  set x-initial-position-drone array:from-list n-values 5 [0]
  ;array:set x-initial-position-drone 0 -10
  ;array:set x-initial-position-drone 1 10
  array:set x-initial-position-drone 0 -9
  array:set x-initial-position-drone 1 9
  ;array:set x-initial-position-drone 2 -6
  ;array:set x-initial-position-drone 3 6
  array:set x-initial-position-drone 2 -8
  array:set x-initial-position-drone 3 7.8
  array:set x-initial-position-drone 4 0
  ; ordenada (y) posición inicial drones
  set y-initial-position-drone array:from-list n-values 5 [0]
  array:set y-initial-position-drone 0 q-size-drone * -1
  array:set y-initial-position-drone 1 q-size-drone * -1
  ;array:set y-initial-position-drone 2 q-size-drone * 1.6
  ;array:set y-initial-position-drone 3 q-size-drone * 1.6
  array:set y-initial-position-drone 2 q-size-drone * 1.2
  array:set y-initial-position-drone 3 q-size-drone * 1.2
  ;array:set y-initial-position-drone 4 q-size-drone * -2.5
  array:set y-initial-position-drone 4 q-size-drone * -2

  ; posición inicial de los stores
  ; abscisa (x) posición inicial stores
  set x-initial-position-store array:from-list n-values 5 [0]
  array:set x-initial-position-store 0 max-pxcor * -1 + q-size-drone / 2
  array:set x-initial-position-store 1 max-pxcor - q-size-drone / 2
  array:set x-initial-position-store 2 max-pxcor * -1 + q-size-drone / 2
  array:set x-initial-position-store 3 max-pxcor - q-size-drone / 2
  array:set x-initial-position-store 4 0

  ; ordenada (y) posición inicial stores
  set y-initial-position-store array:from-list n-values 5 [0]
  array:set y-initial-position-store 0 max-pycor * -1 + q-size-drone / 2
  array:set y-initial-position-store 1 max-pycor * -1 + q-size-drone / 2
  array:set y-initial-position-store 2 max-pycor - q-size-drone / 2
  array:set y-initial-position-store 3 max-pycor - q-size-drone / 2
  array:set y-initial-position-store 4 max-pycor * -1 + q-size-drone / 2

  ; posición inicial de los stores (labels)
  ; abscisa (x) posición inicial stores (labels)
  let tmp-x-label-ajuste 6
  let tmp-x-label-ajuste-rigth -4
  set x-initial-position-label-store array:from-list n-values 5 [0]
  array:set x-initial-position-label-store 0 max-pxcor * -1 + q-size-drone / 2 + (q-size-drone + tmp-x-label-ajuste)
  array:set x-initial-position-label-store 1 max-pxcor - q-size-drone / 2 - (q-size-drone + tmp-x-label-ajuste + tmp-x-label-ajuste-rigth)
  array:set x-initial-position-label-store 2 max-pxcor * -1 + q-size-drone / 2 + (q-size-drone + tmp-x-label-ajuste)
  array:set x-initial-position-label-store 3 max-pxcor - q-size-drone / 2 - (q-size-drone + tmp-x-label-ajuste + tmp-x-label-ajuste-rigth)
  array:set x-initial-position-label-store 4 0 + (q-size-drone + tmp-x-label-ajuste)

  ; ordenada (y) posición inicial stores (labels)
  set y-initial-position-label-store array:from-list n-values 5 [0]
  let tmp-y-label-ajuste 2
  array:set y-initial-position-label-store 0 max-pycor * -1 + q-size-drone / 2 + tmp-y-label-ajuste
  array:set y-initial-position-label-store 1 max-pycor * -1 + q-size-drone / 2 + tmp-y-label-ajuste
  array:set y-initial-position-label-store 2 max-pycor - q-size-drone / 2 + tmp-y-label-ajuste
  array:set y-initial-position-label-store 3 max-pycor - q-size-drone / 2 + tmp-y-label-ajuste
  array:set y-initial-position-label-store 4 max-pycor * -1 + q-size-drone / 2 + tmp-y-label-ajuste

  ; mundo
  ask patches [set pcolor white - 3]
  ;ask patches [set pcolor 86]

  ; Cantidades de objetos
  ;set q-embarcaciones-nocivos round(q-embarcaciones-NO-nocivos * porc-objetos-nocivos / 100)
  ;set q-embarcaciones q-embarcaciones-NO-nocivos + q-embarcaciones-nocivos
  set q-visibles 1 + q-drones + q-embarcaciones
end

;;
;; Configuración de turtles
;;
to setup_turtles
  ;; Torre de control
  create-turtles 1 [
    set tipo "torre-control"
    set subtipo ""
    setxy 0 0
    set color gray - 3
    set size q-size-torre-control
    set shape "torre-control"
  ]

  ;; Objetos
  let rec 0
  create-turtles q-embarcaciones [
    set tipo "object"
    set subtipo ""
    set id-drone-asignado -1
    set size q-size-objeto
    move-to one-of patches
    ; Ubicarlo en posición permitida
    while [not F-coordenada-permitida xcor ycor][
      ;set xcor random max-pxcor * 2 - max-pxcor
      ;set ycor random max-pycor * 2 - max-pycor
      move-to one-of patches
    ]
    set estado "non-inspected"
    set distancia max-pxcor * 4 ; distancia grande para que entre la primera vez
    set shape "boat 3"
    ; determinar si está en el perimetro del radar
    ifelse (F-dentro-del-perimetro xcor ycor)[
      set b-en-perimetro-radar true
      set color black
    ]
    [
      set b-en-perimetro-radar false
      set color gray
    ]
    ;set velocidad random(3) + 3 ; Entre 3 a 5
    ifelse (F-dentro-del-perimetro xcor ycor) [
      ifelse (random(101) > 30) [
        set velocidad random(3) + 1 ; Entre 1 a 3
      ]
      [
        set velocidad 0
      ]
    ]
    [
        set velocidad random(3) + 1 ; Sie está fuera del perímetro siempre en movimiento, entre 1 a 3
    ]
    set rec rec + 1
  ]

  ;; Objetos referenciales
  set rec 0
  create-turtles q-embarcaciones [
    set tipo "object"
    set subtipo "referential"
    set size q-size-objeto / 2
    set estado "non-inspected-referential"
    set shape "boat 3"
    hide-turtle
  ]

  ; crear drones de marca inicial (pistas de aterrizaje)
  let q-old-turtles count turtles + 1
  create-turtles q-drones [
    set tipo "drone"
    set subtipo "initial"
    set color gray
    set size q-size-drone
    ;set xcor q-drones / -2 * q-size-drone + (who + 1 - q-old-turtles + 0.5) * q-size-drone
    ;set ycor q-size-drone * -1.5
    set xcor array:item x-initial-position-drone (who - q-embarcaciones * 2 - 1)
    set ycor array:item y-initial-position-drone (who - q-embarcaciones * 2 - 1)

    set heading 0 ; comienza mirando al norte
    set shape "pista-elicoptero2"
  ]

  ;; Drones oficiales
  create-turtles q-drones [
    set tipo "drone"
    set subtipo "inspector"
    set color F-color-ruta (who + 1 - q-old-turtles - q-drones)
    set size q-size-drone
    ;set xcor q-drones / -2 * q-size-drone + (who + 1 - q-old-turtles - q-drones + 0.5) * q-size-drone * 3
    ;set ycor q-size-drone * -1.5
    let tmp-xcor -1
    let tmp-ycor -1
    ask turtle (who - q-drones)[
      set tmp-xcor xcor
      set tmp-ycor ycor
    ]
    set xcor tmp-xcor
    set ycor tmp-ycor
    set shape "drone3"

    ; primera asignación
    set id-origen (who - q-drones) ; El initial correspondiente a cada drone, el destino se determinará por distancia
    set id-destino -1
    set estado "aterrizado"
    set heading 0 ; comienza mirando al norte
    set distancia-recorrida 0
    set tiempo-vuelo 0
    set objetivos 0
    set consumo 0
    set velocidad random(2) + 7 ; Entre 7 a 8 / Se divide por 10 al aplicar
    set almacenamiento random(101) + 0 ; de 0 a 100
    ; crea link de comunicaciones
    F-crea-link who 0 gray + 4 0.5 "comunicacion3"
    let tmp-id-drone who
    ask links with [id-origen-link = tmp-id-drone and id-destino-link = 0][
      hide-link
    ]
    pendown
    set pen-size 3.5
  ]

  ;; Shape almacenamiento para drones
  create-turtles q-drones [
    set tipo "drone"
    set subtipo "store"
    set color F-color-ruta (who + 1 - q-old-turtles - q-drones * 2)
    ;set size q-size-drone
    set size q-size-drone / 5 * 3
    set shape "store 000"
    ;set xcor array:item x-initial-position-store (who - q-embarcaciones * 2 - q-drones * 2 - 1)
    ;set ycor array:item y-initial-position-store (who - q-embarcaciones * 2 - q-drones * 2 - 1)
    set xcor [xcor] of turtle (who - q-drones)
    set ycor ([ycor] of turtle (who - q-drones)) - q-size-drone / 5 * 4;
    ifelse administracion-energia [
      show-turtle
    ]
    [
      hide-turtle
    ]
  ]

  ;; Labels almacenamiento para drones
  create-turtles q-drones [
    set tipo "drone"
    set subtipo "label-store"
    ;set label-color F-color-ruta (who + 1 - q-old-turtles - q-drones * 3)
    set label-color black
    set size q-size-drone
    set shape "nothing"
    ;set xcor array:item x-initial-position-label-store (who - q-embarcaciones * 2 - q-drones * 3 - 1)
    ;set ycor array:item y-initial-position-label-store (who - q-embarcaciones * 2 - q-drones * 3 - 1)
    set xcor ([xcor] of turtle (who - q-drones * 2)) - q-size-drone / 9
    set ycor ([ycor] of turtle (who - q-drones * 2)) - q-size-drone / 8 * 7
    ifelse administracion-energia [
      show-turtle
    ]
    [
      hide-turtle
    ]
  ]

  if administracion-energia [
    ;; Actualiza despligue de almacenamiento
    ask turtles with [tipo = "drone" and subtipo = "inspector"][
      F-despliega-almacenamiento who
    ]
  ]

  ;; Para dibujos
  create-turtles 1 [
    set tipo "dibujo"
    set subtipo ""
    ;hide-turtle
  ]

  ; dibujar perímetro de la torre de control
  ;F-dibuja-circulo 0 0 k-lejanía-torre-control - 2 gray - 1 1 false

  ; dibuja buque
  F-dibuja-buque

  ; dibujar perímetro del radar
  F-dibuja-circulo 0 0 k-perimetro-radar - 2 black 1 false
end

;;
;; Asignar drones a objetos - planificación de rutas (el más cerca primero)
;;
to setup_drones_to_objetos
  ; primer link entre inspector e initial
;  ask turtles with [tipo = "drone" and subtipo = "inspector"][
;    F-crea-link id-origen who color 1
;  ]

  ; asignar el drone más cercano a cada objeto
  F-asigna-mas-cercano-OBJ

  ; inician mirando al norte
  ask turtles with [tipo = "drone" and subtipo = "inspector"][
      set heading 0 ; comienza mirando al norte
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;
;;  FUNCIONES
;;
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;
;; Asigna objeto más cercano
;;
to F-asigna-mas-cercano-OBJ
  if administracion-energia [
    ; Para hacer blink a drones descargados cada n ticks
    set n-blink-count n-blink-count + 1
    ifelse b-blink-drone [
      if n-blink-count = k-blink-drone [
        set b-blink-drone false
        set n-blink-count 0
      ]
    ]
    [
      if n-blink-count = k-blink-drone [
        set b-blink-drone true
        set n-blink-count 0
      ]
    ]

    ; dejamos aterrizados los que no han pasado un umbral mínimo de almacenamiento
    ask turtles with [tipo = "drone" and subtipo = "inspector"][
      ifelse estado = "en-ruta" [
        ifelse estado-energia = "volviendo-a-recargar" [
          ifelse b-blink-drone [
            set shape "drone3-border"
          ]
          [
            set shape "drone3"
          ]
        ]
        [
          ; determinar si le queda energía para volver a la torre de control a recargar
          let tmp-xcor-origen -1
          let tmp-ycor-origen -1
          ask turtle (who - q-drones) [
            set tmp-xcor-origen xcor
            set tmp-ycor-origen ycor
          ]
          let tmp-distancia-a-origen F-distancia-2coordenadas xcor ycor tmp-xcor-origen tmp-ycor-origen
          let tmp-energia-requerida (tmp-distancia-a-origen * k-consumo-por-tick) + k-holgura-regreso-a-torre
          ;let tmp-energia-requerida (tmp-distancia-a-origen * k-consumo-por-tick) * (1 + k-holgura-regreso-a-torre / 100)
          ;show (word "w: " tmp-distancia-a-origen)
          ;show (word "k/t:" k-consumo-por-tick)

          ;show (word "e-r:" tmp-energia-requerida)
          ;set tmp-energia-requerida tmp-energia-requerida * 1.5
          ;show (word "e-r:" tmp-energia-requerida)
          ;show (word "alm: " almacenamiento)

          ifelse tmp-energia-requerida >= almacenamiento [
            set estado-energia "volviendo-a-recargar"
            ifelse b-blink-drone [
              set shape "drone3-border"
            ]
            [
              set shape "drone3"
            ]
          ]
          [
            set estado-energia "ok"
            set shape "drone3"
          ]
        ]
      ]
      [
        if estado = "aterrizado" [
          ifelse almacenamiento >= k_almacenamiento-minimo [
            set estado-energia "ok"
            set shape "drone3"
          ]
          [
            set estado-energia "bajo-umbral"
            ifelse b-blink-drone [
              set shape "drone3-border"
            ]
            [
              set shape "drone3"
            ]
          ]
        ]
      ]
    ]
  ]

  ; para cada objeto determinamos cual es el dron más cercano
  ask turtles with [tipo = "object" and estado = "non-inspected" and b-en-perimetro-radar][
    let tmp-xcor-objeto xcor
    let tmp-ycor-objeto ycor
    let b-entro false
    let distancia-menor max-pxcor * 4 ; distancia grande para que entre la primera vez
    let tmp-id-drone-a-asignar -1
    ; recorremos los drones para determinar el más cercano
    ask turtles with [tipo = "drone" and subtipo = "inspector" and estado != "perdido" and (estado-energia = "ok" or not administracion-energia)][
      let distancia-objeto-a-drone F-distancia-2coordenadas tmp-xcor-objeto tmp-ycor-objeto xcor ycor ; obtenemos la distancia efectiva entre el objeto y cada drone
      if distancia-objeto-a-drone < distancia-menor [
        set distancia-menor distancia-objeto-a-drone
        set tmp-id-drone-a-asignar who
        set b-entro true
      ]
    ]
    if (b-entro)[
      ; asignamos al objeto el drone
      set id-drone-asignado tmp-id-drone-a-asignar
      set distancia distancia-menor
    ]
  ]

  ; ahora para cada drone determinamos cual es el objeto más cercano
  ask turtles with [tipo = "drone" and subtipo = "inspector" and estado != "perdido"][
    let tmp-id-drone who
    let b-entro false
    let tmp-id-objeto-a-asignar -1
    if estado-energia = "ok" or not administracion-energia [
      let distancia-menor max-pxcor * 4 ; distancia grande para que entre la primera vez
      ask turtles with [tipo = "object" and estado = "non-inspected" and b-en-perimetro-radar and id-drone-asignado = tmp-id-drone][
        if distancia < distancia-menor [
          set distancia-menor distancia
          set tmp-id-objeto-a-asignar who
          set b-entro true
        ]
      ]
    ]
    if estado-energia = "volviendo-a-recargar" [
      set tmp-id-objeto-a-asignar who - q-drones
      set b-entro true
    ]
    ifelse (b-entro)[
      set estado "en-ruta"
      ; asignamos al drone el objeto
      set id-destino tmp-id-objeto-a-asignar
      let tmp-xcor-destino -1
      let tmp-ycor-destino -1
      ask turtles with [who = tmp-id-objeto-a-asignar][ ; todo: no funciona con id-destino (revisar porque)
        set tmp-xcor-destino xcor
        set tmp-ycor-destino ycor
      ]

      ; asignamos el ánuglo de recorrido (desde el eje y (norte) hacia la izquierda (este)
      set heading F-direction xcor ycor tmp-xcor-destino tmp-ycor-destino
    ]
    [
      ; Como no tiene más objetos, lo hacemos volver a la torre de control
      set tmp-id-objeto-a-asignar who - q-drones
      ; asignamos al drone el objeto
      set id-destino tmp-id-objeto-a-asignar
      let tmp-xcor-destino -1
      let tmp-ycor-destino -1
      ask turtles with [who = tmp-id-objeto-a-asignar][ ; todo: no funciona con id-destino (revisar porque)
        set tmp-xcor-destino xcor
        set tmp-ycor-destino ycor
      ]

      ; asignamos el ánuglo de recorrido (desde el eje y (norte) hacia la izquierda (este)
      set heading F-direction xcor ycor tmp-xcor-destino tmp-ycor-destino
    ]
  ]

  ; poner labels para depuración
  if labels [
    ask turtles with [tipo = "drone" and subtipo = "inspector"][
      set label (word who " o:" id-destino " " estado " e:" estado-energia)
    ]
      ask turtles with [tipo = "object" and estado = "non-inspected"][
      set label (word who " d:" id-drone-asignado)
    ]
  ]
end

;;
;; Calcula la dirección en que se debe dirigir un drone
;;
to-report F-direction [x1 y1 x2 y2]
  let dir-direction -1
  ; exceciones para calcular la dirección en casos en que y1 = y2 o x2 = x1
  ifelse (x1 = x2)[
    ifelse (y1 < y2)[
      set dir-direction 0
    ]
    [
      set dir-direction 180
    ]
  ]
  [
    ifelse (y1 = y2)[
      ifelse (x1 < x2)[
        set dir-direction 90
      ]
      [
        set dir-direction 270
      ]
    ]
    [
      ; saltadas las excepciones calculamos basado en arcotangente.  Para Netlogo los ángulos comienzan desde el norte hacia el este
      set dir-direction atan (x2 - x1) (y2 - y1)
    ]
  ]
  report dir-direction
end

;;
;; Función para establecer color de ruta para cada drone
;;
to-report F-color-ruta [rec-drone]
  let tmp-color-ruta random 140
  ifelse rec-drone = 0 [
    set tmp-color-ruta 26 ; naranjo
  ]
  [
    ifelse rec-drone = 1 [
      set tmp-color-ruta yellow
    ]
    [
      ifelse rec-drone = 2 [
        set tmp-color-ruta violet
      ]
      [
        ifelse rec-drone = 3 [
          set tmp-color-ruta green
        ]
        [
          if rec-drone = 4 [
            set tmp-color-ruta blue
          ]
        ]
      ]
    ]
  ]
  report tmp-color-ruta
end

;;
;; Devuelve true si la posición es permitida sino false
;;
to-report F-coordenada-permitida [x y]
  let coordenada-permitida true
  ; abscisas (x) no permitidas cerca del borde
  if (x > max-pxcor - k-lejania-borde  or x < max-pxcor * -1 + k-lejania-borde)[
    set coordenada-permitida false
  ]
  ; ordenadas (y) no permitidas cerca del borde
  if (y > max-pycor - k-lejania-borde or y < max-pycor * -1 + k-lejania-borde)[
    set coordenada-permitida false
  ]
  ; coordenadas no permitidas cerca del perímetro del la torre de control
  let tmp-distancia F-distancia-2coordenadas x y 0 0
  ;if (x >= 0 and x < k-lejanía-torre-control  and y >= 0 and y < k-lejanía-torre-control) or (x >= 0 and x < k-lejanía-torre-control and y <= 0 and y > k-lejanía-torre-control * -1) or (x <= 0 and x > k-lejanía-torre-control * -1 and y >= 0 and y < k-lejanía-torre-control) or (x <= 0 and x > k-lejanía-torre-control * -1 and y <= 0 and y > k-lejanía-torre-control * -1)[
  if tmp-distancia <=  k-lejanía-torre-control  [
    set coordenada-permitida false
  ]
  report coordenada-permitida
end

;;
;; Dibuja un círculo
;;
to F-dibuja-circulo [x y radio color-perimetro size-perimetro linea-continua]
;  create-turtles 1 [
;    set tipo "tmp"
;    set xcor x + radio
;    set ycor y
;    set heading 0
;  ]
  ask turtles with [tipo = "dibujo"][
    let n-discontinuo 3
    penup
    set xcor x + radio
    set ycor y
    set heading 0
    pendown
    set color color-perimetro
    set pen-size size-perimetro
    let i 0
    let switch-pen true
    repeat 360 [
      if (not linea-continua)[
        if (int(i / n-discontinuo) = i / n-discontinuo)[
          set switch-pen not switch-pen
          ifelse (switch-pen)[
            penup
          ]
          [
            pendown
          ]
        ]
      ]
      forward 0.175 * radio / 10
      left 1
      set i i + 1
    ]
  ]
  ask turtles with[tipo = "tmp"][
    die
  ]
end

;;
;; Dibuja contorno del buque
;;
to F-dibuja-buque
  ask turtles with [tipo = "dibujo"][
    set color black
    penup

    set xcor -7
    set ycor -35
    set pen-size 2
    pendown
    set heading 90
    forward 14
    penup

    set xcor 0
    set ycor 35
    pendown
    set heading 135
    repeat 81 [
      forward 0.95
      right 1
    ]
    penup

    set xcor 0
    set ycor 35
    pendown
    set heading 225
    repeat 80 [
      forward 0.95
      left 1
    ]
    penup

    ;pendown
    ;forward 15
  ]
end

;;
;; Creación de links
;;
to F-crea-link [lnk-id-origen lnk-id-destino lnk-color lnk-thinkness lnk-shape]

  ask turtle lnk-id-origen [
    create-mi-directed-link-to turtle lnk-id-destino [
      set id-origen-link lnk-id-origen
      set id-destino-link lnk-id-destino
      set color lnk-color
      set thickness lnk-thinkness
      set shape lnk-shape
    ]
  ]
end

;;
;; Eliminación de links
;;
to F-elimina-link [lnk-id-origen lnk-id-destino]
  ask links with [id-origen-link = lnk-id-origen and id-destino-link = lnk-id-destino][
    die
  ]
end

;;
;; Función distancia entre 2 puntos
;;
to-report F-distancia-2coordenadas [x1 y1 x2 y2]
  ;show (word x1 " " y1 " " x2 " " y2)
  report sqrt(((x2 - x1) ^ 2) + ((y2 - y1) ^ 2))
end
;;
;; evalaur siun dron está cerca de un objeto
;;
to-report F-rango [x-drone y-drone x-obj y-obj rango]
  report (x-obj >= x-drone - rango and x-obj <= x-drone + rango) and (y-obj >= y-drone - rango and y-obj <= y-drone + rango)
end

;;
;; Determinar si un obejto está dentro del perímetro del radar
;;
to-report F-dentro-del-perimetro [x y]
  let b-report false
  if (F-distancia-2coordenadas x y 0 0 <= k-perimetro-radar)[
    set b-report true
  ]
  report b-report
end
;;
;; Despliega shape y label de almacenamiento
;;
to F-despliega-almacenamiento [id-drone]
  ; label
  let tmp-almacenamiento -1
  ask turtles with [who = id-drone][
    set tmp-almacenamiento almacenamiento
  ]
  ask turtles with [who = id-drone + q-drones * 2][
    set label (word (precision tmp-almacenamiento 0) "%")
  ]
  ; shape
  ask turtles with [who = id-drone + q-drones][
    ifelse tmp-almacenamiento >= 95 [
      set shape "store 100"
    ]
    [
      ifelse tmp-almacenamiento >= 85 [
        set shape "store 090"
      ]
      [
        ifelse tmp-almacenamiento >= 70 [
          set shape "store 075"
        ]
        [
          ifelse tmp-almacenamiento >= 45 [
            set shape "store 050"
          ]
          [
            ifelse tmp-almacenamiento >= 20 [
              set shape "store 025"
            ]
            [
              ifelse tmp-almacenamiento >= 7 [
                set shape "store 010"
              ]
              [
                set shape "store 000"
              ]
            ]
          ]
        ]
      ]
    ]
  ]
end

;;
;; Actuazliar coordenadas del shape y label de almacenamiento
;;
to F-actualizar-xy-almacenamiento [id-drone]
  let tmp-xcor-drone [xcor] of turtle (id-drone)
  let tmp-ycor-drone [ycor] of turtle (id-drone)
  if (administracion-energia)[
    ; Actualizar coordenada del shape de almacenamiento
    ask turtle (id-drone + q-drones) [
      set xcor tmp-xcor-drone;
      set ycor tmp-ycor-drone - q-size-drone / 5 * 4;
    ]

    ; Actualizar coordenada del label de almacenamiento
    ask turtle (id-drone + q-drones * 2) [
      set xcor tmp-xcor-drone - q-size-drone / 9
      set ycor tmp-ycor-drone - q-size-drone / 8 * 7
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
226
11
961
747
-1
-1
3.45
1
11
1
1
1
0
0
0
1
-105
105
-105
105
1
1
1
ticks
30.0

BUTTON
13
17
77
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
14
63
212
96
q-drones
q-drones
1
5
3.0
1
1
NIL
HORIZONTAL

SLIDER
14
102
211
135
q-embarcaciones
q-embarcaciones
5
200
50.0
1
1
NIL
HORIZONTAL

SLIDER
15
142
211
175
probabilidad-nocividad
probabilidad-nocividad
0
100
3.0
1
1
%
HORIZONTAL

PLOT
1001
95
1425
397
Distancia recorrida (metros)
Segundos
Metros recorridos
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"dron 1" 1.0 0 -955883 true "" "ask turtle id-primer-drone [plot distancia-recorrida]"
"dron 2" 1.0 0 -1184463 true "" "ask turtle (id-primer-drone + 1) [plot distancia-recorrida]"
"dron 3" 1.0 0 -8630108 true "" "ask turtle (id-primer-drone + 2) [plot distancia-recorrida]"
"dron 4" 1.0 0 -10899396 true "" "ask turtle (id-primer-drone + 3) [plot distancia-recorrida]"
"dron 5" 1.0 0 -13345367 true "" "ask turtle (id-primer-drone + 4) [plot distancia-recorrida]"

PLOT
1001
454
1424
735
Tiempo de vuelo (segundos)
Segundos transcurridos
Segundos vuelo
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"dron 1" 1.0 0 -955883 true "" "ask turtle id-primer-drone [plot tiempo-vuelo]"
"dron 2" 1.0 0 -1184463 true "" "ask turtle (id-primer-drone + 1) [plot tiempo-vuelo]"
"dron 3" 1.0 0 -8630108 true "" "ask turtle (id-primer-drone + 2) [plot tiempo-vuelo]"
"dron 4" 1.0 0 -10899396 true "" "ask turtle (id-primer-drone + 3) [plot tiempo-vuelo]"
"dron 5" 1.0 0 -13345367 true "" "ask turtle (id-primer-drone + 4) [plot tiempo-vuelo]"

SWITCH
226
751
422
784
administracion-energia
administracion-energia
0
1
-1000

SWITCH
426
751
619
784
labels
labels
1
1
-1000

PLOT
1432
96
1855
397
Objetivos alcanzados por dron (cantidades)
Segundos
Cantidad objetivos alcanzados
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"dron 1" 1.0 0 -955883 true "" "ask turtle (id-primer-drone) [plot objetivos]"
"dron 2" 1.0 0 -1184463 true "" "ask turtle (id-primer-drone + 1) [plot objetivos]"
"dron 3" 1.0 0 -8630108 true "" "ask turtle (id-primer-drone + 2) [plot objetivos]"
"dron 4" 1.0 0 -10899396 true "" "ask turtle (id-primer-drone + 3) [plot objetivos]"
"dron 5" 1.0 0 -13345367 true "" "ask turtle (id-primer-drone + 4) [plot objetivos]"

PLOT
1432
454
1855
734
Consumo (watts)
Ticks
Watts
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"dron 1" 1.0 0 -955883 true "" "ask turtle (id-primer-drone) [plot consumo]"
"dron 2" 1.0 0 -1184463 true "" "ask turtle (id-primer-drone + 1) [plot consumo]"
"dron 3" 1.0 0 -8630108 true "" "ask turtle (id-primer-drone + 2) [plot consumo]"
"dron 4" 1.0 0 -10899396 true "" "ask turtle (id-primer-drone + 3) [plot consumo]"
"dron 5" 1.0 0 -13345367 true "" "ask turtle (id-primer-drone + 4) [plot consumo]"

SLIDER
15
181
211
214
probabilidad-perder-drone
probabilidad-perder-drone
0
100
0.01
0.01
1
%
HORIZONTAL

MONITOR
1001
399
1139
444
Total distancia recorrida
total-dr
17
1
11

MONITOR
1141
399
1282
444
Promedio distancia recorrida
prom-dr
17
1
11

MONITOR
1284
399
1425
444
Desv-est distancia recorrida
dev-est-dr
17
1
11

MONITOR
1432
400
1568
445
Total objetivos
total-objetivos
17
1
11

MONITOR
1712
400
1855
445
Desv-est objetivos
dev-est-objetivos
17
1
11

MONITOR
1571
400
1710
445
Promedio objetivos
prom-objetivos
17
1
11

MONITOR
1001
737
1138
782
Total tiempo vuelo
total-tpo-vuelo
17
1
11

MONITOR
1140
737
1284
782
Promedio tiempo vuelo
prom-tpo-vuelo
17
1
11

MONITOR
1287
737
1424
782
Desv-est tiempo vuelo
dev-est-tpo-vuelo
17
1
11

MONITOR
1432
736
1568
781
Total consumo
total-consumo
17
1
11

MONITOR
1571
736
1721
781
Promedio consumo
prom-consumo
17
1
11

MONITOR
1723
736
1855
781
Desv-est consumo
dev-est-consumo
17
1
11

MONITOR
1001
11
1428
92
Tiempo medio de inspección (segundos)
total-tpo-vuelo / total-objetivos
2
1
20

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

boat 3
false
0
Polygon -1 true false 48 162 75 207 208 207 275 162
Rectangle -6459832 true false 135 32 142 162
Polygon -13345367 true false 135 34 116 49 130 47 132 48 134 49
Polygon -7500403 true true 143 37 157 45 173 59 187 79 202 109 205 130 203 147 189 156 143 156 146 142 155 123 155 102 154 88 150 62
Polygon -7500403 true true 134 66 127 78 124 96 126 111 131 139 133 147 95 147 98 131 103 106 111 71

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

box 1
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -13840069 false 150 285 150 135
Line -13840069 false 150 135 15 75
Line -13840069 false 150 135 285 75
Line -13840069 false 15 75 150 15
Line -13840069 false 150 15 285 75
Line -13840069 false 15 75 15 225
Line -13840069 false 15 225 150 285
Line -13840069 false 150 285 285 225
Line -13840069 false 285 75 285 225

box 2
false
0
Polygon -7500403 true true 150 285 270 225 270 90 150 150
Polygon -13791810 true false 150 150 30 90 150 30 270 90
Polygon -13345367 true false 30 90 30 225 150 285 150 150

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

circle 3
false
0
Circle -7500403 false true 15 15 270
Circle -7500403 false true 30 30 240

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

drone
false
0
Circle -7500403 true true 13 13 92
Circle -16777216 true false 26 26 67
Circle -7500403 true true 193 13 92
Circle -16777216 true false 206 26 67
Circle -7500403 true true 13 193 92
Circle -7500403 true true 193 193 92
Circle -16777216 true false 206 206 67
Circle -16777216 true false 26 206 67
Rectangle -7500403 true true 120 75 180 225
Polygon -7500403 true true 90 210 120 195 120 210 105 225 90 210
Polygon -7500403 true true 210 210 180 195 180 210 195 225 210 210
Polygon -7500403 true true 210 90 180 105 180 90 195 75 210 90
Polygon -7500403 true true 90 90 120 105 120 90 105 75 90 90

drone3
false
0
Circle -7500403 true true -2 -2 152
Circle -16777216 true false 41 41 67
Circle -7500403 true true 150 0 148
Circle -16777216 true false 191 41 67
Circle -7500403 true true 0 150 148
Circle -7500403 true true 150 150 148
Circle -16777216 true false 191 191 67
Circle -16777216 true false 41 191 67
Rectangle -7500403 true true 120 75 180 225
Rectangle -16777216 true false 135 120 165 195
Line -7500403 true 15 75 300 75
Line -7500403 true 75 15 75 285
Line -7500403 true 225 15 225 270
Line -7500403 true 30 225 270 225
Line -7500403 true 120 195 30 255
Line -7500403 true 45 195 105 255
Line -7500403 true 45 45 105 105
Line -7500403 true 45 105 105 45
Line -7500403 true 195 45 255 105
Line -7500403 true 195 105 255 45
Line -7500403 true 195 195 255 255
Line -7500403 true 195 255 255 195

drone3-border
false
1
Circle -7500403 true false 13 13 122
Circle -16777216 true false 41 41 67
Circle -7500403 true false 163 13 122
Circle -16777216 true false 191 41 67
Circle -7500403 true false 13 163 122
Circle -7500403 true false 165 165 118
Circle -16777216 true false 191 191 67
Circle -16777216 true false 41 191 67
Rectangle -7500403 true false 120 75 180 225
Rectangle -16777216 true false 135 120 165 195
Line -7500403 false 15 75 300 75
Line -7500403 false 75 0 75 270
Line -7500403 false 225 15 225 270
Line -7500403 false 30 225 270 225
Line -7500403 false 120 195 30 255
Line -7500403 false 45 195 105 255
Line -7500403 false 45 45 105 105
Line -7500403 false 45 105 105 45
Line -7500403 false 195 45 255 105
Line -7500403 false 195 105 255 45
Line -7500403 false 195 195 255 255
Line -7500403 false 195 255 255 195
Circle -2674135 false true 15 15 120
Circle -2674135 false true 165 165 120
Circle -2674135 false true 165 15 120
Circle -2674135 false true 15 165 120
Line -2674135 true 180 120 180 180
Line -2674135 true 135 225 165 225
Line -2674135 true 120 120 120 180
Line -2674135 true 135 75 165 75
Circle -2674135 false true 45 45 60
Circle -2674135 false true 195 195 60
Circle -2674135 false true 45 195 60
Circle -2674135 false true 195 45 60
Rectangle -2674135 false true 135 120 165 195

drone4
true
0
Circle -7500403 true true -2 -2 152
Circle -16777216 true false 30 30 88
Circle -7500403 true true 150 0 148
Circle -16777216 true false 180 30 88
Circle -7500403 true true 0 150 148
Circle -7500403 true true 150 150 148
Circle -16777216 true false 180 180 88
Circle -16777216 true false 30 180 88
Rectangle -7500403 true true 120 75 180 225
Rectangle -16777216 true false 135 120 165 195
Line -7500403 true 15 75 300 75
Line -7500403 true 75 15 75 285
Line -7500403 true 225 15 225 270
Line -7500403 true 30 225 270 225
Line -7500403 true 120 195 30 255
Line -7500403 true 30 180 105 255
Line -7500403 true 30 30 105 105
Line -7500403 true 45 105 105 45
Line -7500403 true 180 30 255 105
Line -7500403 true 180 105 255 45
Line -7500403 true 180 180 255 255
Line -7500403 true 195 255 255 195
Rectangle -7500403 true true 135 150 180 180

drone5
true
0
Circle -7500403 true true 0 0 148
Circle -16777216 true false 30 30 88
Circle -7500403 true true 148 -2 152
Circle -16777216 true false 180 30 88
Circle -7500403 true true 0 150 148
Circle -7500403 true true 148 148 152
Circle -16777216 true false 180 180 88
Circle -16777216 true false 30 180 88
Rectangle -7500403 true true 120 45 180 225
Rectangle -16777216 true false 135 135 165 195
Line -7500403 true 0 75 300 75
Line -7500403 true 75 0 75 270
Line -7500403 true 225 15 225 270
Line -7500403 true 15 225 270 225
Line -7500403 true 120 195 30 255
Line -7500403 true 45 195 105 255
Line -7500403 true 30 30 105 105
Line -7500403 true 45 105 105 45
Line -7500403 true 195 45 255 105
Line -7500403 true 180 105 270 45
Line -7500403 true 180 180 255 255
Line -7500403 true 195 255 255 195
Polygon -7500403 true true 120 45 150 0 180 45 120 45

drone7
true
0
Circle -7500403 true true 15 30 118
Circle -16777216 true false 30 45 88
Circle -7500403 true true 163 28 122
Circle -16777216 true false 180 45 88
Circle -7500403 true true 15 165 118
Circle -7500403 true true 163 163 122
Circle -16777216 true false 180 180 88
Circle -16777216 true false 30 180 88
Rectangle -7500403 true true 120 75 180 240
Rectangle -16777216 true false 135 150 165 195
Line -7500403 true 30 90 270 90
Line -7500403 true 75 30 75 270
Line -7500403 true 225 30 225 270
Line -7500403 true 15 225 270 225
Line -7500403 true 120 195 30 255
Line -7500403 true 45 195 105 255
Line -7500403 true 45 60 120 135
Line -7500403 true 45 120 105 60
Line -7500403 true 180 45 255 120
Line -7500403 true 180 120 270 60
Line -7500403 true 180 180 255 255
Line -7500403 true 195 255 255 195
Polygon -7500403 true true 120 75 150 30 180 75 165 75
Rectangle -16777216 true false 135 105 165 120

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

nothing
true
0

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

pista-elicoptero
false
0
Circle -7500403 false true 15 15 270
Circle -7500403 false true 30 30 240
Rectangle -7500403 true true 105 75 120 225
Rectangle -7500403 true true 180 75 195 225
Rectangle -7500403 true true 120 135 195 150

pista-elicoptero2
false
0
Circle -7500403 false true 15 15 270
Circle -7500403 false true 30 30 240
Rectangle -7500403 true true 105 90 120 210
Rectangle -7500403 true true 180 90 195 210
Rectangle -7500403 true true 120 135 195 150

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

store 000
false
1
Rectangle -1 false false 0 0 300 300

store 010
false
1
Rectangle -2674135 true true 0 270 300 300
Rectangle -1 false false 0 0 300 300

store 025
false
1
Rectangle -2674135 true true 0 270 300 300
Rectangle -2674135 true true 0 225 300 255
Rectangle -1 false false 0 0 300 300

store 050
false
1
Rectangle -2674135 true true 0 270 300 300
Rectangle -2674135 true true 0 225 300 255
Rectangle -2674135 true true 0 180 300 210
Rectangle -2674135 true true 0 150 300 165
Rectangle -1 false false 0 0 300 300

store 075
false
1
Rectangle -2674135 true true 0 270 300 300
Rectangle -2674135 true true 0 225 300 255
Rectangle -2674135 true true 0 180 300 210
Rectangle -2674135 true true 0 135 300 165
Rectangle -2674135 true true 0 90 300 120
Rectangle -2674135 true true 0 45 300 75
Rectangle -1 false false 0 0 300 300

store 090
false
1
Rectangle -2674135 true true 0 270 300 300
Rectangle -2674135 true true 0 225 300 255
Rectangle -2674135 true true 0 180 300 210
Rectangle -2674135 true true 0 135 300 165
Rectangle -2674135 true true 0 90 300 120
Rectangle -2674135 true true 0 45 300 75
Rectangle -2674135 true true 0 15 300 30
Rectangle -1 false false 0 0 300 300

store 100
false
1
Rectangle -1 false false 0 0 300 300
Rectangle -2674135 true true 0 270 300 300
Rectangle -2674135 true true 0 225 300 255
Rectangle -2674135 true true 0 180 300 210
Rectangle -2674135 true true 0 135 300 165
Rectangle -2674135 true true 0 90 300 120
Rectangle -2674135 true true 0 45 300 75
Rectangle -2674135 true true 0 0 300 30
Rectangle -1 false false 0 0 300 300

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

torre-control
false
0
Polygon -7500403 true true 150 45 240 270 225 285 150 45
Polygon -7500403 true true 150 45 60 270 75 285 150 45
Line -7500403 true 90 255 210 225
Line -7500403 true 105 195 210 225
Line -7500403 true 105 195 195 165
Line -7500403 true 120 135 195 165
Line -7500403 true 120 135 180 120
Line -7500403 true 135 90 180 120
Line -7500403 true 135 90 165 60
Polygon -7500403 true true 195 45 195 45 195 30 180 15 165 15 165 30 180 45 165 60 165 75 180 75 195 60 195 30
Polygon -7500403 true true 105 45 105 45 105 30 120 15 135 15 135 30 120 45 135 60 135 75 120 75 105 60 105 30
Polygon -7500403 true true 195 0 195 0 210 0 240 30 240 60 210 90 195 90 195 75 210 75 225 60 225 30 210 15 195 15 195 0
Polygon -7500403 true true 105 0 105 0 90 0 60 30 60 60 90 90 105 90 105 75 90 75 75 60 75 30 90 15 105 15 105 0

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

comunicacion
0.0
-0.2 1 2.0 2.0
0.0 1 1.0 0.0
0.2 1 2.0 2.0
link direction
true
0
Polygon -2674135 true false 270 165 240 195 195 210 150 225 150 225 150 210 150 210 240 180 255 165 255 165
Polygon -2674135 true false 30 165 60 195 105 210 150 225 150 225 150 210 150 210 60 180 45 165 45 165
Polygon -2674135 true false 15 210 45 240 90 255 135 270 165 270 165 255 135 255 45 225 30 210 30 210
Polygon -2674135 true false 285 210 255 240 210 255 165 270 135 270 135 255 165 255 255 225 270 210 270 210
Polygon -2674135 true false 240 135 210 165 165 180 150 180 150 180 150 165 165 165 210 150 225 135 225 135
Polygon -2674135 true false 60 135 90 165 135 180 150 180 150 180 150 165 135 165 90 150 75 135 75 135
Polygon -2674135 true false 210 105 180 135 150 135 150 135 150 120 150 120 150 120 180 120 195 105 195 105
Polygon -2674135 true false 90 105 120 135 150 135 150 135 150 120 150 120 150 120 120 120 105 105 105 105
Polygon -2674135 true false 120 75 135 90 165 90 150 105 150 105 180 75 180 75 150 75 135 75 135 75
Polygon -2674135 true false 135 45 135 30 165 30 165 45 165 45 165 45 165 45 150 45 135 45 135 45

comunicacion2
0.0
-0.2 1 2.0 2.0
0.0 1 1.0 0.0
0.2 1 2.0 2.0
link direction
true
0
Polygon -16777216 true false 270 165 240 195 195 210 150 225 150 225 150 210 150 210 240 180 255 165 255 165
Polygon -16777216 true false 30 165 60 195 105 210 150 225 150 225 150 210 150 210 60 180 45 165 45 165
Polygon -16777216 true false 15 210 45 240 90 255 135 270 165 270 165 255 135 255 45 225 30 210 30 210
Polygon -16777216 true false 285 210 255 240 210 255 165 270 135 270 135 255 165 255 255 225 270 210 270 210
Polygon -16777216 true false 240 135 210 165 165 180 150 180 150 180 150 165 165 165 210 150 225 135 225 135
Polygon -16777216 true false 60 135 90 165 135 180 150 180 150 180 150 165 135 165 90 150 75 135 75 135
Polygon -16777216 true false 210 105 180 135 150 135 150 135 150 120 150 120 150 120 180 120 195 105 195 105
Polygon -16777216 true false 90 105 120 135 150 135 150 135 150 120 150 120 150 120 120 120 105 105 105 105
Polygon -16777216 true false 120 75 135 90 165 90 150 105 150 105 180 75 180 75 150 75 135 75 135 75
Polygon -16777216 true false 135 45 135 30 165 30 165 45 165 45 165 45 165 45 150 45 135 45 135 45

comunicacion3
0.0
-0.2 1 4.0 4.0
0.0 1 1.0 0.0
0.2 1 4.0 4.0
link direction
true
0
Polygon -16777216 true false 270 165 240 195 195 210 150 225 150 225 150 210 150 210 240 180 255 165 255 165
Polygon -16777216 true false 30 165 60 195 105 210 150 225 150 225 150 210 150 210 60 180 45 165 45 165
Polygon -16777216 true false 15 210 45 240 90 255 135 270 165 270 165 255 135 255 45 225 30 210 30 210
Polygon -16777216 true false 285 210 255 240 210 255 165 270 135 270 135 255 165 255 255 225 270 210 270 210
Polygon -16777216 true false 240 135 210 165 165 180 150 180 150 180 150 165 165 165 210 150 225 135 225 135
Polygon -16777216 true false 60 135 90 165 135 180 150 180 150 180 150 165 135 165 90 150 75 135 75 135

discontinuo
0.0
-0.2 1 4.0 4.0
0.0 1 1.0 0.0
0.2 1 4.0 4.0
link direction
true
0

discontinuo-old
0.0
-0.2 1 4.0 4.0
0.0 1 4.0 4.0
0.2 1 4.0 4.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
