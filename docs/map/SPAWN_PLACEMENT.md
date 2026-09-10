# DITTO — Algoritmo de colocación de jugadores

> Especificación detallada del algoritmo de asignación de sectores `PLAYER_BUNKER`.
>
> Estado: **diseño propuesto para primera implementación**.
>
> Última actualización: 2026-09-11.

---

## 1. Objetivo

El algoritmo de spawn debe asignar un sector inicial a cada nueva cuenta de forma que la población:

- nazca cerca del centro de la primera zona poblable;
- crezca de forma compacta y progresiva;
- no coloque dos bunkers demasiado cerca;
- no cree una rejilla visual excesivamente perfecta;
- no coloque jugadores en los bordes físicos `A`, `Z` o cerca del inicio numérico del mundo;
- pueda seguir creciendo indefinidamente hacia números superiores;
- no modifique sectores cuyo contenido ya haya sido resuelto;
- sea seguro ante altas simultáneas.

La estrategia propuesta es un **crecimiento radial con frontera preferente y jitter determinista**.

---

## 2. Configuración inicial propuesta

```text
WORLD_LETTERS = [A, Z]
INITIAL_MAP_NUMBERS = [1, 50]

SPAWN_LETTERS = [D, W]
INITIAL_SPAWN_NUMBERS = [10, 40]
SPAWN_ORIGIN = M25

MIN_PLAYER_DISTANCE = 2.0          // condición estricta: d > 2.0
PREFERRED_LINK_DISTANCE = 4.0     // preferencia, no restricción absoluta
SPAWN_JITTER_MAX = 0.75           // configurable

NEXT_SPAWN_WINDOW = [41, 80]
FOLLOWING_WINDOWS = [81,120], [121,160], ...
```

Los valores son parámetros de diseño y deben vivir en configuración, no dispersos como constantes mágicas por las Cloud Functions.

`SPAWN_ORIGIN = M25` permanece como referencia global aunque la ventana activa avance posteriormente a `[41,80]`, `[81,120]`, etc.

Esto hace que las nuevas ventanas empiecen a llenarse por el extremo más cercano a la población anterior, en lugar de crear una colonia nueva aislada en el centro de cada ventana.

---

## 3. Qué sectores pueden ser candidatos

Para asignar un nuevo jugador se parte de todos los sectores dentro de:

```text
SPAWN_LETTERS × activeSpawnNumberRange
```

Por ejemplo, inicialmente:

```text
[D-W] × [10-40]
```

Un sector candidato debe cumplir **todas** estas condiciones:

1. estar dentro de la banda de letras `D-W`;
2. estar dentro de la ventana numérica de spawn activa;
3. ser una coordenada válida del mundo;
4. no estar reservado por otra operación de alta;
5. no contener ya un `PLAYER_BUNKER`;
6. no haber sido ya poblado/resuelto con otro tipo de sector;
7. poder convertirse legalmente en `PLAYER_BUNKER`;
8. estar a distancia estrictamente mayor que `2.0` de todos los bunkers de jugador existentes.

La regla 6 es importante: el sistema de spawn no debe sobrescribir el mundo ya resuelto. Si un reconocimiento previo generó un sector como `HUNTING`, `LAKE`, `RUINS`, etc., ese sector ya forma parte de la verdad persistente del servidor y deja de ser candidato para un nuevo jugador.

---

## 4. Separación mínima

La separación se calcula usando las coordenadas de **sector**, no la zona interna.

Un candidato `C` es válido únicamente si:

```text
para todo bunker P:
    distance(C, P) > 2.0
```

Como los bunkers ocupan coordenadas enteras de la cuadrícula, para comprobar esta regla no es necesario comparar contra todos los jugadores del servidor.

Un candidato solo puede violar `d > 2` si existe otro bunker en uno de estos desplazamientos relativos:

```text
( 0, 0)
( 1, 0) (-1, 0)
( 0, 1) ( 0,-1)
( 2, 0) (-2, 0)
( 0, 2) ( 0,-2)
( 1, 1) ( 1,-1) (-1, 1) (-1,-1)
```

Es decir, basta comprobar el propio sector y los sectores enteros cuya distancia euclídea sea `<= 2`.

Ejemplos desde `M25`:

```text
M25 -> M27 = 2.0       NO permitido
M25 -> N26 = sqrt(2)   NO permitido
M25 -> N27 = sqrt(5)   SÍ permitido
M25 -> O26 = sqrt(5)   SÍ permitido
M25 -> P25 = 3.0       SÍ permitido
```

Esta comprobación local evita tener que recorrer toda la lista de jugadores para validar cada candidato.

---

## 5. Primer jugador

El primer jugador intenta utilizar directamente:

```text
M25
```

Si `M25` está disponible, se asigna ese sector.

Si por configuración, contenido presembrado o cualquier otra razón `M25` ya no puede utilizarse, se aplica el mismo algoritmo general y se selecciona el candidato válido con mayor prioridad alrededor del origen.

Una vez elegido el sector:

```text
reservar sector
→ convertirlo en PLAYER_BUNKER
→ elegir zona interna del bunker
→ resolver todas las zonas del sector
→ persistir el sector completo
→ revelar al jugador únicamente el conocimiento inicial permitido
```

---

## 6. Frontera preferente de crecimiento

Después del primer jugador, no interesa escoger cualquier hueco de la ventana activa. Se quiere que los nuevos bunkers aparezcan cerca de la población existente.

Se define como **candidato de frontera preferente** aquel candidato válido que además tenga al menos un bunker existente a una distancia menor o igual que:

```text
PREFERRED_LINK_DISTANCE = 4.0
```

Manteniendo siempre la regla dura:

```text
d > 2.0
```

Por tanto, la zona preferida de aparición respecto a algún jugador existente es conceptualmente:

```text
2.0 < d <= 4.0
```

`4.0` no es una restricción absoluta. Es solo una preferencia para conseguir crecimiento compacto.

Si existen candidatos de frontera, el algoritmo elige entre ellos.

Si no existe ninguno pero todavía existen sectores válidos dentro de la ventana, el algoritmo entra en **modo de recuperación** y puede seleccionar un candidato válido más alejado. Así un conjunto de ruinas predefinidas, sectores ya explorados u otros obstáculos nunca bloquea artificialmente el alta de jugadores mientras siga existiendo espacio legal.

---

## 7. Prioridad radial

Entre los candidatos de frontera se favorecen los más próximos al origen global:

```text
SPAWN_ORIGIN = M25
```

Para cada candidato `C` se calcula:

```text
radialDistance(C) = distance(C, M25)
```

La prioridad básica es menor cuanto menor sea esa distancia.

Esto genera un comportamiento natural:

- primero se ocupan posiciones alrededor de `M25`;
- después se forma una corona algo más externa;
- luego otra;
- y así sucesivamente;
- al cambiar a `[41,80]`, las posiciones cercanas a `41` siguen siendo mucho más próximas a `M25` que las cercanas a `80`, por lo que la población continúa desde el frente anterior.

No se reinicia el centro de crecimiento al cambiar de ventana.

---

## 8. Jitter determinista

Si siempre se escogiera estrictamente la coordenada de menor distancia al origen, la distribución podría adquirir patrones demasiado perfectos.

Para romper esa simetría se añade una pequeña perturbación determinista a la prioridad.

Para cada coordenada se calcula:

```text
jitter(C) = hash01(worldSeed, C) * SPAWN_JITTER_MAX
```

Donde:

```text
0 <= hash01(...) < 1
SPAWN_JITTER_MAX = 0.75
```

La puntuación de prioridad queda:

```text
priority(C) = radialDistance(C) + jitter(C)
```

Y se selecciona el candidato con **menor** `priority`.

El jitter debe ser pequeño. Su objetivo es cambiar el orden entre sectores de distancia parecida, no permitir que una coordenada muy lejana adelante a una claramente más cercana.

Se propone inicialmente:

```text
SPAWN_JITTER_MAX = 0.75
```

Este valor puede ajustarse posteriormente.

### ¿Por qué determinista?

En lugar de utilizar `Math.random()` en cada intento, el valor depende de:

- una semilla del mundo;
- la coordenada del sector.

Por tanto, una misma coordenada siempre recibe el mismo jitter dentro del mismo mundo.

Esto aporta:

- distribución visual irregular;
- comportamiento reproducible;
- facilidad para depurar;
- seguridad frente a reintentos de transacciones;
- ausencia de cambios de resultado simplemente porque Firestore haya reejecutado la operación.

---

## 9. Algoritmo completo

### Paso 1 — cargar estado de spawn

Leer al menos:

```text
activeSpawnNumberMin
activeSpawnNumberMax
spawnLetterMin = D
spawnLetterMax = W
spawnOrigin = M25
minimumPlayerDistance = 2.0
preferredLinkDistance = 4.0
worldSeed
```

### Paso 2 — obtener candidatos de la ventana activa

Generar las coordenadas de:

```text
[D-W] × [activeSpawnNumberMin-activeSpawnNumberMax]
```

No es necesario que la lista esté almacenada físicamente como un array gigante. Las coordenadas se pueden derivar de la geometría.

### Paso 3 — eliminar sectores no disponibles

Descartar:

```text
POPULATED
RESERVED
PLAYER_BUNKER
fuera de rango
coordenadas inválidas
```

En la práctica, `PLAYER_BUNKER` ya será `POPULATED`, pero se mantiene la distinción conceptual.

### Paso 4 — aplicar separación mínima

Para cada candidato restante comprobar los sectores vecinos con distancia `<= 2.0`.

Si alguno contiene un bunker de jugador:

```text
candidato = INVALID
```

### Paso 5 — construir frontera preferente

Entre los candidatos válidos, conservar como preferentes aquellos para los que exista al menos un jugador con:

```text
2.0 < distance(C, player) <= 4.0
```

Si existe al menos un candidato preferente:

```text
selectionPool = preferredCandidates
```

Si no existe ninguno:

```text
selectionPool = allValidCandidates
```

### Paso 6 — calcular prioridad

Para cada candidato del pool:

```text
radial = distance(C, M25)
jitter = hash01(worldSeed, C) * 0.75
priority = radial + jitter
```

### Paso 7 — seleccionar

Escoger el candidato con menor prioridad.

En caso extremadamente improbable de empate exacto, desempatar de forma determinista por:

```text
letra
→ número
```

o por un segundo hash estable.

### Paso 8 — reservar y crear el sector de jugador

La selección debe confirmarse de forma atómica:

```text
validar de nuevo
→ reservar
→ asignar jugador
→ resolver sector completo
→ persistir
```

Si la validación falla porque otra alta concurrente acaba de ocupar el sector o una posición incompatible, la operación se reintenta con el nuevo estado.

### Paso 9 — si no existe ningún candidato válido

La ventana está **saturada**.

Entonces:

```text
cerrar ventana actual para nuevas altas
→ avanzar activeSpawnNumberRange
→ ampliar el mapa materializado si es necesario
→ repetir el algoritmo
```

---

## 10. Pseudocódigo

```text
function allocatePlayerSector(playerId):
    repeat:
        state = loadSpawnState()

        candidates = coordinates(
            letters = D..W,
            numbers = state.activeNumberMin..state.activeNumberMax
        )

        valid = []

        for candidate in candidates:
            if sectorIsAlreadyResolvedOrReserved(candidate):
                continue

            if hasPlayerWithinOrAtDistance2(candidate):
                continue

            valid.add(candidate)

        if valid.isEmpty():
            atomicallyAdvanceSpawnWindow(state)
            ensureMapCoversNewWindow()
            continue

        preferred = [
            c in valid
            where hasPlayerAtDistanceBetween(c, 2.0, 4.0)
        ]

        pool = preferred if preferred.isNotEmpty else valid

        chosen = minBy(pool, candidate =>
            distance(candidate, M25)
            + deterministicJitter(worldSeed, candidate, 0.75)
        )

        success = atomicallyReserveAndCreatePlayerSector(
            playerId,
            chosen
        )

        if success:
            return chosen

        // conflicto concurrente: repetir con estado actualizado
```

El pseudocódigo describe comportamiento, no una implementación literal de Firestore.

---

## 11. Ejemplo de crecimiento

### Jugador 1

```text
M25
```

### Jugador 2

No puede aparecer a `d <= 2` de `M25`.

Entre las posiciones más cercanas legalmente posibles están desplazamientos como:

```text
(+1,+2)
(+2,+1)
(-1,+2)
(-2,+1)
...
```

cuya distancia es:

```text
sqrt(5) ≈ 2.236
```

Por ejemplo, `N27` podría ser un candidato válido.

El jitter determina cuál de los candidatos de prioridad similar queda antes.

### Jugadores posteriores

Cada alta añade nuevos sectores posibles alrededor de la frontera del conjunto existente.

El resultado esperado no es:

```text
X..X..X..X
...........
X..X..X..X
```

como patrón rígido perfecto.

Se busca algo más parecido conceptualmente a una mancha irregular:

```text
      X   X
   X        X
      X  X
  X          X
     X   X
```

manteniendo en todos los casos `d > 2`.

---

## 12. Comportamiento al cambiar de ventana

Supongamos:

```text
ventana actual = [10,40]
```

Se declara saturada únicamente cuando **no queda ningún candidato legal** dentro de `D-W × 10-40`.

Entonces se activa:

```text
[41,80]
```

El origen de prioridad sigue siendo:

```text
M25
```

Por ello, dentro de la nueva ventana, una coordenada alrededor de `M41` obtiene mucha más prioridad que una alrededor de `M80`.

La nueva población continúa longitudinalmente desde el frente de la anterior.

La siguiente saturación activa:

```text
[81,120]
```

y así sucesivamente.

---

## 13. Interacción con exploración

Los jugadores pueden explorar fuera de la ventana de spawn activa.

Si un jugador explora un sector futuro y ese sector queda `POPULATED`, el algoritmo de spawn debe respetarlo.

Ejemplo:

```text
activeSpawnRange = [41,80]
sector M45 ya fue explorado y generado como RUINS
```

`M45` ya no puede ser transformado posteriormente en `PLAYER_BUNKER`.

El algoritmo simplemente lo descarta y continúa con otros candidatos.

Así se mantiene la regla fundamental de que el mundo persistente no se reescribe para acomodar nuevas cuentas.

---

## 14. Saturación real vs. ausencia de frontera

Estos conceptos no deben confundirse.

### Sin candidatos de frontera

Puede no existir ningún sector a `2 < d <= 4` de un bunker y, sin embargo, seguir habiendo sectores legales en la ventana.

En ese caso se utiliza el **modo de recuperación** y se selecciona el candidato válido de mayor prioridad global.

### Ventana saturada

Solo se considera saturada cuando:

```text
allValidCandidates.isEmpty()
```

Es decir, no queda ningún sector que cumpla todas las reglas duras.

Solo entonces se avanza a la siguiente ventana numérica.

---

## 15. Concurrencia

La asignación de spawn es una operación poco frecuente comparada con acciones normales de juego, por lo que es aceptable serializar las altas mediante un pequeño estado autoritativo de asignación.

Se propone mantener un documento conceptual similar a:

```text
WORLD_SPAWN_STATE
- activeNumberMin
- activeNumberMax
- revision
- worldSeed
```

Cada alta debe participar en una transacción que lea y actualice ese estado/revisión.

Esto fuerza a que dos asignaciones concurrentes entren en conflicto y una de ellas se reevalúe antes de confirmar.

La operación lógica debe garantizar conjuntamente:

```text
el candidato sigue libre
AND
no apareció entretanto un bunker a d <= 2
AND
la ventana activa sigue siendo la esperada
```

antes de persistir el nuevo `PLAYER_BUNKER`.

Nunca debe confiarse en una comprobación realizada únicamente antes de la transacción.

---

## 16. Coste y optimización

La ventana inicial contiene:

```text
20 letras (D-W)
× 31 números (10-40)
= 620 sectores
```

Por tanto, incluso una primera implementación simple puede permitirse razonar sobre todas las coordenadas de la ventana al producir un spawn. La creación de cuentas no es una operación de alta frecuencia.

Aun así, no conviene traducir automáticamente esos 620 candidatos en cientos de lecturas innecesarias de Firestore.

Optimizaciones posibles:

- derivar las coordenadas en memoria;
- comprobar primero candidatos por orden aproximado de prioridad;
- validar distancia mínima mediante el pequeño vecindario `d <= 2`;
- mantener índices de sectores `POPULATED`/`PLAYER_BUNKER`;
- cachear o persistir una frontera de candidatos si el volumen de altas lo justificase;
- mantener un radio/frente aproximado de crecimiento para no volver a inspeccionar continuamente regiones interiores agotadas.

Estas optimizaciones no deben cambiar el comportamiento conceptual del algoritmo.

La primera implementación debe priorizar simplicidad y corrección; la optimización puede hacerse cuando exista evidencia de que es necesaria.

---

## 17. Razones para elegir este algoritmo

### Crecimiento compacto

La frontera `2 < d <= 4` hace que los nuevos jugadores aparezcan cerca de la población existente.

### Expansión desde el centro

La prioridad respecto a `M25` impide que el sistema salte arbitrariamente a extremos todavía vacíos.

### Aspecto orgánico

El jitter rompe empates y pequeñas simetrías sin dispersar la población.

### Reproducibilidad

El jitter derivado de `worldSeed + coordinate` permite reproducir decisiones y depurar el sistema.

### Robustez ante obstáculos

Si sectores explorados o predefinidos bloquean la frontera, el modo de recuperación evita declarar una falsa saturación.

### Crecimiento longitudinal natural

Mantener `M25` como origen al avanzar a `[41,80]`, `[81,120]`, etc. hace que las nuevas ventanas se llenen empezando por su extremo más cercano al mundo ya poblado.

### Escalabilidad suficiente

La distancia mínima puede validarse localmente y las ventanas tienen un número limitado de candidatos.

---

## 18. Parámetros que deben ser configurables

La implementación no debe acoplar el algoritmo a los valores iniciales.

Como mínimo:

```text
spawnLetterMin = D
spawnLetterMax = W
spawnOriginLetter = M
spawnOriginNumber = 25
minimumPlayerDistance = 2.0
preferredLinkDistance = 4.0
spawnJitterMax = 0.75
initialSpawnNumberMin = 10
initialSpawnNumberMax = 40
subsequentWindowSize = 40
worldSeed
```

Cambiar estos valores debe alterar la distribución sin reescribir la lógica del algoritmo.

---

## 19. Invariantes

La implementación debe preservar siempre:

1. ningún nuevo bunker se asigna fuera de `D-W`;
2. ningún nuevo bunker se asigna fuera de la ventana numérica activa;
3. ningún sector ya `POPULATED` se sobrescribe para crear un jugador;
4. dos bunkers distintos mantienen siempre `distance > 2.0`;
5. la frontera `<= 4.0` es una preferencia, no una condición que pueda bloquear indefinidamente altas;
6. la ventana solo se considera saturada si no queda ningún candidato legal;
7. el jitter nunca sustituye las reglas duras de validez;
8. el jitter es determinista para una misma semilla y coordenada;
9. la asignación final es atómica;
10. el sector de jugador queda completamente resuelto al confirmarse la asignación;
11. el jugador no recibe automáticamente conocimiento de las demás zonas de su sector;
12. la expansión de ventanas avanza únicamente hacia números superiores;
13. el origen `M25` sigue siendo la referencia radial global aunque cambie la ventana activa.

---

## 20. Resumen operativo

```text
Primer jugador -> intentar M25

Siguientes jugadores:
    generar candidatos D-W dentro de la ventana activa
    quitar sectores ya resueltos/reservados
    quitar candidatos con otro jugador a d <= 2

    si no queda ninguno:
        avanzar ventana
        ampliar mapa si hace falta
        repetir

    preferir candidatos con algún jugador a 2 < d <= 4

    prioridad = distancia a M25 + jitter determinista pequeño

    elegir menor prioridad

    validar y reservar atómicamente
    generar todo el sector PLAYER_BUNKER
```

El resultado buscado es una población **compacta, irregular, reproducible y progresiva**, con separación justa entre jugadores y capacidad de crecimiento indefinido por el eje numérico.