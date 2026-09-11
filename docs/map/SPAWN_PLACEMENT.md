# DITTO — Algoritmo de colocación de jugadores

> Especificación detallada del sistema persistente de candidatos para asignar sectores `PLAYER_BUNKER`.
>
> Estado: **diseño propuesto para primera implementación**.
>
> Última actualización: 2026-09-11.

---

## 1. Objetivo

La asignación de bunkers iniciales debe cumplir simultáneamente estos objetivos:

- concentrar los primeros jugadores alrededor de `M25`;
- hacer que la población se expanda progresivamente desde ese núcleo;
- mantener una separación estrictamente mayor que `2.0` entre bunkers;
- evitar una distribución completamente determinista o geométricamente perfecta;
- impedir que una celda ya descubierta/poblada por el mundo se reutilice como spawn de jugador;
- evitar recalcular toda la cuadrícula cada vez que se registra una cuenta;
- permitir que el mapa crezca indefinidamente por el eje numérico;
- ser compatible con altas concurrentes.

La estrategia elegida es un **pool persistente de candidatos con prioridad estática y selección aleatoria ponderada**.

La idea clave es que cada celda candidata recibe su valor de prioridad una sola vez cuando entra en el mapa/pool. Después el sistema únicamente elimina candidatos conforme dejan de ser válidos y utiliza sus prioridades ya calculadas para elegir nuevos sectores.

---

## 2. Configuración base

```text
WORLD_LETTERS = [A, Z]
INITIAL_MAP_NUMBERS = [1, 50]

SPAWN_LETTERS = [D, W]
INITIAL_SPAWN_NUMBERS = [10, 40]
SPAWN_ORIGIN = M25

MIN_PLAYER_DISTANCE = 2.0
```

La condición entre bunkers es estricta:

```text
distance(playerA, playerB) > 2.0
```

La banda `D-W` deja margen respecto a los límites físicos `A` y `Z`.

La ventana numérica inicial `[10,40]` deja margen respecto al límite inferior del mundo y sitúa `M25` aproximadamente en el centro de la primera región de aparición.

---

## 3. Concepto de pool de candidatos

El backend mantiene un conjunto lógico persistente de sectores que todavía pueden utilizarse como `PLAYER_BUNKER`.

Cada entrada contiene como mínimo:

```text
coordinate
priorityWeight
```

Ejemplo conceptual:

```text
M25 -> 1.0000
N25 -> 0.5000
M26 -> 0.5000
N26 -> 0.4142
...
```

Los valores exactos del ejemplo dependen de la fórmula de proximidad elegida.

La palabra **lista** o **pool** describe el concepto. En Firestore no es obligatorio guardar todos los candidatos como un único array dentro de un solo documento. La implementación podrá utilizar una colección o estructura equivalente para evitar límites de tamaño y contención de escrituras.

Lo importante es que el servidor pueda:

1. conocer qué sectores siguen siendo candidatos;
2. recuperar su peso de prioridad;
3. eliminar candidatos cuando dejan de ser válidos;
4. añadir nuevos candidatos cuando se amplía el mapa.

---

## 4. Prioridad basada en proximidad a M25

Cada candidato recibe una prioridad en función de su **proximidad** a:

```text
SPAWN_ORIGIN = M25
```

No se utiliza la distancia directamente como valor a maximizar. Se utiliza una función inversa: cuanto más cerca de `M25`, mayor peso tiene la celda.

Una fórmula adecuada es:

```text
priorityWeight(C) = 1 / (1 + distance(C, M25))^alpha
```

con:

```text
alpha > 0
```

Inicialmente puede utilizarse:

```text
alpha = 1
```

Por ejemplo:

```text
M25   d = 0       weight = 1.0000
M26   d = 1       weight = 0.5000
N26   d = sqrt(2) weight ≈ 0.4142
M27   d = 2       weight ≈ 0.3333
M30   d = 5       weight ≈ 0.1667
```

### 4.1 Por qué `1 / (1 + d)` y no `1 / d`

La fórmula estricta `1 / d` no está definida en `M25`, porque allí:

```text
d = 0
```

Añadir `1` al denominador conserva exactamente el comportamiento buscado —más proximidad implica mayor prioridad— y produce un valor máximo finito de `1` en el origen.

### 4.2 Parámetro `alpha`

`alpha` controla cuánto favorecemos el centro.

```text
alpha pequeño -> distribución más dispersa
alpha grande  -> concentración más fuerte alrededor de M25
```

Debe ser configurable para poder ajustar el comportamiento con simulaciones sin modificar código.

### 4.3 La prioridad es estática

Una vez calculado:

```text
priorityWeight(M32)
```

ese valor no cambia porque aparezcan nuevos jugadores, porque se descubran otros sectores o porque avance el tiempo.

La prioridad depende únicamente de:

```text
coordenada del sector
+
SPAWN_ORIGIN
+
alpha
```

Por tanto se calcula una sola vez cuando la celda entra en el pool.

---

## 5. Construcción inicial del pool

Al inicializar el servidor se materializa inicialmente el mapa:

```text
[A-Z] × [1-50]
```

Pero el pool de spawn no necesita incluir todo el mapa. Solo incluye celdas que pertenecen a la zona permitida para nuevos jugadores.

Inicialmente:

```text
[D-W] × [10-40]
```

Para cada sector `C` de esa región:

```text
1. comprobar que es apto para spawn;
2. calcular distance(C, M25);
3. calcular priorityWeight(C);
4. persistir C dentro del pool.
```

Este trabajo se realiza una sola vez para esas celdas.

---

## 6. Selección de una posición para un nuevo jugador

Cuando se crea una cuenta no se recalculan prioridades ni se vuelve a analizar geométricamente toda la ventana.

Se parte del pool persistente actual.

Si contiene candidatos:

```text
C1 con peso w1
C2 con peso w2
...
Cn con peso wn
```

se calcula:

```text
W = w1 + w2 + ... + wn
```

La probabilidad de elegir `Ci` es:

```text
P(Ci) = wi / W
```

Esto es una **selección aleatoria ponderada** o ruleta ponderada.

Ejemplo simple:

```text
A -> weight 10
B -> weight 5
C -> weight 1

Total = 16

P(A) = 10/16 = 62.5%
P(B) =  5/16 = 31.25%
P(C) =  1/16 = 6.25%
```

La celda más cercana no gana automáticamente, pero tiene más posibilidades de ser elegida.

Eso permite que el crecimiento sea:

- claramente concentrado alrededor de `M25`;
- progresivo;
- irregular;
- diferente entre mundos/servidores;
- sin necesidad de jitter artificial ni de recalcular puntuaciones dinámicas.

---

## 7. Primer jugador

`M25` tiene el peso máximo porque su distancia al origen es `0`.

No es necesario forzar que el primer jugador esté exactamente en `M25` si se quiere respetar al 100 % la ruleta desde el inicio.

Sin embargo, si se desea garantizar un núcleo idéntico entre servidores, puede establecerse una excepción simple:

```text
si no existe ningún PLAYER_BUNKER:
    elegir M25 si sigue disponible
```

Esta decisión puede mantenerse configurable.

El diseño principal no depende de ella: incluso sin excepción, `M25` y sus alrededores son las celdas con mayor probabilidad.

---

## 8. Qué hace que una celda salga del pool

Una entrada desaparece del pool en cuanto deja de ser legal como futura ubicación de jugador.

Hay dos causas principales.

### 8.1 Sector descubierto o poblado

Cuando cualquier mecánica resuelve un sector que todavía estaba en el pool, ese sector se elimina inmediatamente.

Ejemplo:

```text
H28 está en el pool
↓
un jugador completa un reconocimiento de H28
↓
el backend genera H28 como HUNTING
↓
H28 se elimina del pool de spawn
```

No importa qué tipo de sector haya generado el reconocimiento. El hecho relevante es que `H28` ya forma parte de la verdad persistente del mundo y no debe sobrescribirse posteriormente para colocar un bunker.

Regla:

```text
sector pasa de UNGENERATED a POPULATED
=> removeFromSpawnPool(sector)
```

### 8.2 Aparición de un bunker

Cuando una celda `B` se asigna como `PLAYER_BUNKER`, se elimina:

```text
B
```

y además se eliminan del pool todas las coordenadas que violarían la distancia mínima respecto a `B`.

Como la condición legal es:

```text
d > 2.0
```

se eliminan todas las celdas con:

```text
d <= 2.0
```

respecto al nuevo bunker.

---

## 9. Vecindario que se invalida al crear un bunker

Con coordenadas enteras, los desplazamientos cuyo valor euclídeo es `<= 2` son:

```text
             (0,+2)

      (-1,+1) (0,+1) (+1,+1)

(-2,0) (-1,0) (0,0) (+1,0) (+2,0)

      (-1,-1) (0,-1) (+1,-1)

             (0,-2)
```

Por tanto, cada nuevo bunker invalida como máximo **13 posiciones** del pool, contando su propio sector.

Ejemplo con bunker en `M25`:

```text
M25  eliminado
L25  eliminado
N25  eliminado
M24  eliminado
M26  eliminado
K25  eliminado
O25  eliminado
M23  eliminado
M27  eliminado
L24  eliminado
L26  eliminado
N24  eliminado
N26  eliminado
```

Posiciones como:

```text
N27
O26
```

tienen distancia `sqrt(5) ≈ 2.236`, por lo que siguen siendo legales.

Esta invalidación permite garantizar la separación sin tener que recalcular distancias contra todos los bunkers en cada alta.

---

## 10. Flujo completo de alta

```text
Nueva cuenta
   ↓
Leer candidatos disponibles del pool activo
   ↓
Seleccionar aleatoriamente según priorityWeight
   ↓
Revalidar la celda de forma transaccional
   ↓
Reservarla para el jugador
   ↓
Eliminar del pool la celda elegida
   ↓
Eliminar del pool las posiciones a distancia <= 2
   ↓
Convertir el sector en PLAYER_BUNKER
   ↓
Resolver TODAS las zonas del sector
   ↓
Persistir el sector completo
   ↓
Revelar al jugador únicamente el conocimiento inicial permitido
```

Las modificaciones de reserva e invalidación deben ser seguras frente a concurrencia.

---

## 11. Concurrencia

Dos jugadores pueden registrarse prácticamente al mismo tiempo.

El sistema no puede permitir este escenario:

```text
alta A elige M25
alta B elige N26
ambas validan antes de que la otra escriba
```

porque `M25` y `N26` están a `sqrt(2)` y violarían la distancia mínima.

Por ello la selección aleatoria puede realizarse fuera de la transacción, pero antes de confirmar debe existir una validación atómica que garantice que:

- la celda elegida sigue en el pool;
- no ha sido reservada;
- no ha sido poblada por otra acción;
- ningún bunker concurrente acaba de invalidarla.

Si falla:

```text
abortar intento
→ cargar pool actualizado
→ volver a seleccionar
```

La implementación exacta se decidirá al diseñar Firestore, pero la garantía funcional es obligatoria.

---

## 12. Interacción con la exploración

La exploración y el spawn comparten el mismo mundo.

Si una misión de reconocimiento descubre una celda que estaba disponible para futuros jugadores:

```text
UNGENERATED -> POPULATED
```

esa coordenada sale del pool.

No se recalculan los pesos de las demás.

Ejemplo:

```text
pool contiene:
M30, M31, N30, N31, ...

un jugador reconoce N31

nuevo pool:
M30, M31, N30, ...
```

El resto conserva exactamente el mismo `priorityWeight` que ya tenía.

Esto significa que la exploración de los jugadores modifica qué posiciones siguen disponibles, pero no modifica la función de preferencia global.

---

## 13. Expansión del mapa

El mapa es infinito hacia números positivos.

Si el mapa pasa, por ejemplo, de:

```text
[A-Z] × [1-50]
```

a:

```text
[A-Z] × [1-80]
```

las nuevas celdas se crean como `UNGENERATED`.

Para las nuevas celdas que además formen parte de una región actualmente o futuramente permitida para spawn:

```text
1. calcular priorityWeight una sola vez;
2. comprobar si ya están invalidadas por bunkers existentes;
3. comprobar si ya fueron pobladas durante la expansión/exploración;
4. si siguen siendo válidas, añadirlas al pool.
```

### 13.1 Importante en los límites entre ventanas

Supongamos que existe un bunker en:

```text
M40
```

y posteriormente se crean candidatos de `[41,80]`.

Celdas nuevas como:

```text
M41
M42
N41
L41
```

pueden caer dentro del radio prohibido de `M40`.

Por tanto, al añadir nuevas celdas al pool no basta con calcular su prioridad: también deben excluirse aquellas que ya sean incompatibles con bunkers existentes.

Este chequeo solo se realiza una vez cuando las nuevas celdas se incorporan.

---

## 14. Ventanas de spawn y saturación

La primera ventana propuesta es:

```text
[D-W] × [10-40]
```

Mientras exista al menos una entrada válida de esa ventana en el pool, los nuevos jugadores se seleccionan de ella.

Cuando no queda ninguna:

```text
activeSpawnPool == empty
```

la ventana está saturada.

Entonces se activa la siguiente región numérica, por ejemplo:

```text
[41-80]
```

Si todavía no está materializada:

```text
expandir mapa hasta 80
→ calcular prioridades de las nuevas candidatas
→ excluir las ya incompatibles
→ persistir nuevas entradas
```

Después la selección continúa exactamente con el mismo mecanismo.

El origen de prioridad sigue siendo siempre:

```text
M25
```

Por tanto, dentro de `[41,80]` las posiciones próximas a `41` tienen naturalmente mayor peso que las próximas a `80`. Esto hace que el crecimiento longitudinal tienda a continuar desde la población anterior.

---

## 15. Por qué no recalcular la prioridad al aparecer jugadores

El objetivo del peso no es medir dónde está actualmente la población, sino definir una preferencia global y estable de expansión desde el núcleo inicial.

Por tanto:

```text
nuevo bunker
=> elimina candidatos incompatibles
=> NO modifica pesos del resto
```

Esto tiene varias ventajas:

- el coste de cálculo de prioridades ocurre una sola vez;
- el estado es fácil de depurar;
- la aparición de un jugador no obliga a reordenar cientos de sectores;
- la exploración no provoca cascadas de recálculos;
- la aleatoriedad ponderada ya produce irregularidad suficiente;
- el comportamiento global sigue favoreciendo el centro.

---

## 16. Pseudocódigo conceptual

### Inicialización

```text
function initializeSpawnPool():
    for coordinate in D..W × 10..40:
        if coordinate can be candidate:
            weight = proximityWeight(coordinate, M25)
            persistCandidate(coordinate, weight)
```

### Proximidad

```text
function proximityWeight(coordinate, origin):
    d = sectorDistance(coordinate, origin)
    return 1 / (1 + d)^alpha
```

### Reconocimiento

```text
function onSectorPopulated(coordinate):
    removeCandidateIfPresent(coordinate)
```

### Alta de jugador

```text
function allocatePlayerSector(playerId):
    loop:
        candidates = loadActiveSpawnCandidates()

        if candidates is empty:
            advanceSpawnWindowAndExpandMap()
            continue

        chosen = weightedRandom(
            candidates,
            weight = candidate.priorityWeight
        )

        success = atomically:
            verify chosen is still candidate
            reserve chosen
            remove chosen from pool
            remove every candidate within distance <= 2 of chosen
            create PLAYER_BUNKER for playerId
            resolve all zones of chosen sector

        if success:
            return chosen

        // otro proceso modificó el estado; repetir
```

### Expansión

```text
function addNewSpawnCoordinates(newCoordinates):
    for coordinate in newCoordinates:
        if coordinate already populated:
            continue

        if exists PLAYER_BUNKER at distance <= 2:
            continue

        weight = proximityWeight(coordinate, M25)
        persistCandidate(coordinate, weight)
```

---

## 17. Persistencia recomendada

Conceptualmente el sistema habla de una lista persistente, pero no se recomienda asumir desde el diseño que todo deba guardarse en un único array de Firestore.

Una forma lógica sería:

```text
SPAWN_STATE
- activeNumberMin
- activeNumberMax
- origin = M25
- alpha
- minimumPlayerDistance = 2.0

SPAWN_CANDIDATES
- coordinate
- priorityWeight
- windowId / numberRange
```

Cuando una celda deja de ser candidata puede:

- eliminarse físicamente de `SPAWN_CANDIDATES`; o
- marcarse como no disponible si posteriormente interesa conservar auditoría.

Para la primera implementación, eliminarla físicamente simplifica la lectura del pool.

La estructura concreta deberá diseñarse teniendo en cuenta consultas, transacciones y límites de Firestore, pero no cambia el algoritmo.

---

## 18. Propiedades del algoritmo

### Cálculo único

La prioridad de una celda se calcula una sola vez al incorporarse al pool.

### Crecimiento central

Las celdas próximas a `M25` tienen más peso.

### Aleatoriedad natural

No se elige siempre el sector de mayor prioridad; se sortea proporcionalmente a los pesos.

### Separación garantizada

Cada bunker elimina todas las posiciones a `d <= 2`.

### Respeto del mundo descubierto

Cada sector poblado por exploración se elimina del pool.

### Escalabilidad

Las altas no necesitan recalcular la cuadrícula completa.

### Expansión infinita

Las nuevas celdas reciben su peso cuando se materializan y después funcionan igual que las iniciales.

---

## 19. Decisiones configurables pendientes

El algoritmo queda definido, pero todavía podremos ajustar mediante simulación:

- valor exacto de `alpha`;
- si el primer jugador se fuerza a `M25` o también se sortea;
- tamaño exacto de las ventanas posteriores;
- si las ventanas tienen o no solapamiento;
- estructura concreta de persistencia en Firestore;
- estrategia eficiente para hacer la selección ponderada cuando el pool sea grande;
- si conviene eliminar físicamente candidatos o conservarlos con estado;
- cómo auditar/reconstruir el pool si alguna vez fuese necesario.

Estas decisiones no alteran la regla principal:

**cada celda recibe una prioridad estática basada en su proximidad a M25, el pool persiste únicamente las posiciones todavía disponibles y cada nuevo jugador se elige mediante probabilidad proporcional a esa prioridad.**
