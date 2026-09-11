# DITTO — Sistema de mapa, coordenadas y expansión

> Documento principal de diseño del mundo persistente de DITTO. Define coordenadas, sectores y zonas, generación bajo demanda, conocimiento del jugador, distancias, asignación de bunkers y crecimiento progresivo del mapa.
>
> Estado: **propuesta base / pendiente de implementación**.
>
> Última actualización: 2026-09-11.

La especificación detallada del algoritmo de colocación de nuevos jugadores está en [`SPAWN_PLACEMENT.md`](./SPAWN_PLACEMENT.md).

---

## 1. Idea general

El mundo de DITTO se organiza como una cuadrícula 2D de **sectores**. Cada sector contiene varias **zonas** internas.

La geometría del mundo existe lógicamente aunque el backend no haya poblado todavía todos sus sectores. El mundo real es único y compartido por todos los jugadores, pero su contenido se resuelve progresivamente cuando una acción obliga al servidor a hacerlo.

La arquitectura base es:

**mapa global persistente + sectores generados bajo demanda + conocimiento parcial por jugador + expansión progresiva del eje numérico**.

---

## 2. Coordenadas

Una localización completa usa tres componentes:

1. letra del sector;
2. número del sector;
3. índice de zona dentro del sector.

Ejemplo:

```text
B12-3
```

- `B12` identifica el sector.
- `3` identifica una zona concreta dentro de ese sector.

Con cinco zonas por sector existirían, por ejemplo:

```text
B12-1
B12-2
B12-3
B12-4
B12-5
```

El número de zonas por sector será configurable.

---

## 3. Forma global del mapa

### 3.1 Eje alfabético

El eje de letras está limitado al alfabeto inglés:

```text
A ... Z
```

No existen filas anteriores a `A` ni posteriores a `Z`.

La anchura física del mundo es por tanto de **26 sectores**.

### 3.2 Eje numérico

El eje numérico comienza en `1` y no tiene límite superior conceptual:

```text
1, 2, 3, ... 50, 51, 52, ...
```

No existen coordenadas numéricas negativas.

El servidor puede comenzar con una plantilla materializada de:

```text
[A-Z] × [1-50]
```

pero `50` no es el límite real del mundo.

Si una acción necesita una coordenada superior, el backend amplía la plantilla con nuevos sectores vacíos/no generados.

Ejemplo:

```text
máximo materializado = 50
un jugador intenta explorar H53
→ ampliar mapa hasta cubrir 53
→ H53 existe como UNGENERATED
→ el reconocimiento puede resolverlo después
```

La expansión puede realizarse por bloques para evitar ampliaciones de una única columna cada vez.

---

## 4. Sector y zona

Un **sector** es una posición de la cuadrícula, por ejemplo `B12`.

Una **zona** es una localización interna concreta, por ejemplo `B12-3`.

Un sector:

- tiene una posición única;
- contiene varias zonas;
- tiene un tipo principal;
- puede estar sin generar o poblado;
- condiciona qué zonas internas puede contener.

Una zona puede representar, por ejemplo:

- bunker de jugador;
- bunker abandonado;
- zona de caza;
- lago;
- ruinas;
- edificio abandonado;
- futuras localizaciones.

El jugador interactúa con zonas; el sector actúa como unidad geográfica, unidad externa de distancia y contexto de generación.

---

## 5. Tipo principal de sector

Cada sector tiene un **tipo principal** que condiciona su composición.

Ejemplo:

```text
B12 -> PLAYER_BUNKER
```

Si el bunker está en `B12-3`, `B12` es un sector de jugador aunque las otras zonas sean de tipos distintos.

Ejemplos conceptuales:

```text
PLAYER_BUNKER
- exactamente 1 bunker de jugador
- nunca puede alojar un segundo jugador
- todas sus zonas se resuelven al asignarlo
- composición inicial equilibrada entre jugadores

HUNTING
- puede contener varias zonas de caza
- puede coexistir con otros tipos compatibles
- puede utilizar probabilidades propias
```

El tipo principal no obliga a que todas las zonas del sector sean iguales.

---

## 6. Generación lazy

Un sector puede estar conceptualmente en:

```text
UNGENERATED
POPULATED
```

### `UNGENERATED`

La coordenada existe, pero el backend todavía no ha decidido su contenido.

### `POPULATED`

El backend ha resuelto todas sus zonas y ha persistido la composición como parte del mundo real.

Una vez poblado, un sector no se vuelve a sortear por explorarlo otra vez.

---

## 7. Sectores de jugador

Cuando se crea una cuenta, el backend obtiene un sector del pool persistente de candidatos de spawn.

El flujo conceptual es:

```text
leer candidatos disponibles
→ seleccionar uno por probabilidad ponderada
→ revalidar/reservar atómicamente
→ eliminar candidato y vecinos incompatibles del pool
→ convertir en PLAYER_BUNKER
→ asignar zona del bunker
→ resolver TODAS las zonas del sector
→ persistir
→ revelar únicamente el conocimiento inicial permitido
```

### 7.1 Resolución inmediata

Al asignar un sector a un jugador se resuelve **todo el sector inmediatamente**.

Por ejemplo, el servidor puede saber:

```text
M25-1 = RUINS
M25-2 = EMPTY
M25-3 = PLAYER_BUNKER(player_123)
M25-4 = HUNTING
M25-5 = ABANDONED_BUILDING
```

mientras el jugador conoce inicialmente únicamente:

```text
M25-3 = MY_BUNKER
```

### 7.2 Equidad inicial

Los sectores `PLAYER_BUNKER` no deben tener una tirada aleatoria de calidad capaz de dar una ventaja material a unos jugadores respecto a otros desde la creación de la cuenta.

Su composición puede variar, pero el valor inicial debe ser equivalente.

---

## 8. Banda y ventana de spawn

La zona en la que pueden aparecer jugadores es independiente de la parte del mapa que exista o haya sido explorada.

La banda alfabética queda fijada inicialmente en:

```text
[D-W]
```

Esto deja margen respecto a los límites físicos `A` y `Z`.

La primera ventana numérica propuesta es:

```text
[10-40]
```

Por tanto, la primera región de spawn es:

```text
[D-W] × [10-40]
```

El origen global de prioridad es:

```text
M25
```

La ventana de spawn **solo limita dónde aparecen nuevas cuentas**. No limita exploración, viajes ni contenido del mundo.

Los márgenes existen para evitar que un jugador aparezca inicialmente demasiado cerca de un borde físico y tenga menos espacio disponible en una dirección.

---

## 9. Separación mínima de jugadores

Dos bunkers distintos deben cumplir siempre:

```text
distance(playerA, playerB) > 2.0
```

La desigualdad es estricta.

Ejemplos:

```text
M25 -> M27 = 2.0        NO permitido
M25 -> N26 = sqrt(2)    NO permitido
M25 -> N27 = sqrt(5)    SÍ permitido
M25 -> O26 = sqrt(5)    SÍ permitido
M25 -> P25 = 3.0        SÍ permitido
```

Como las coordenadas de sector son enteras, un bunker nuevo invalida únicamente su propio sector y las posiciones enteras situadas a distancia `<= 2`.

Eso equivale como máximo a 13 posiciones:

```text
             (0,+2)

      (-1,+1) (0,+1) (+1,+1)

(-2,0) (-1,0) (0,0) (+1,0) (+2,0)

      (-1,-1) (0,-1) (+1,-1)

             (0,-2)
```

Estas entradas se eliminan directamente del pool de candidatos cuando se crea el bunker.

---

## 10. Pool persistente de candidatos

La estrategia elegida sustituye el cálculo dinámico de candidatos en cada alta por un **pool persistente**.

Cada sector que todavía puede utilizarse como bunker de un nuevo jugador tiene una entrada lógica con, como mínimo:

```text
coordinate
priorityWeight
```

La prioridad se calcula una única vez cuando la celda entra en el pool.

Inicialmente el pool se construye sobre:

```text
[D-W] × [10-40]
```

No es necesario almacenar el pool como un único array de Firestore. El término “lista” describe el conjunto lógico; la implementación puede utilizar una colección o una estructura equivalente.

---

## 11. Prioridad por proximidad a M25

La prioridad depende exclusivamente de la proximidad de cada sector al origen global:

```text
M25
```

Cuanto más cerca del origen, mayor peso.

Una función adecuada es:

```text
priorityWeight(C) = 1 / (1 + distance(C, M25))^alpha
```

Con `alpha = 1`:

```text
M25   distancia = 0        peso = 1.0000
M26   distancia = 1        peso = 0.5000
N26   distancia = sqrt(2)  peso ≈ 0.4142
M27   distancia = 2        peso ≈ 0.3333
M30   distancia = 5        peso ≈ 0.1667
```

Se utiliza `1 + distancia` en el denominador para evitar la división por cero en `M25`.

`alpha` será configurable: valores mayores concentran más la población alrededor del centro; valores menores producen una expansión más dispersa.

La prioridad es **estática**. No se recalcula cuando aparecen jugadores ni cuando se descubren otros sectores.

---

## 12. Selección aleatoria ponderada

Para crear un nuevo jugador se toma el pool actual y se escoge una coordenada aleatoriamente con probabilidad proporcional a su peso.

Si los candidatos tienen pesos:

```text
C1 -> w1
C2 -> w2
...
Cn -> wn
```

entonces:

```text
P(Ci) = wi / (w1 + w2 + ... + wn)
```

Ejemplo:

```text
A -> peso 10
B -> peso 5
C -> peso 1

P(A) = 10/16 = 62.5%
P(B) = 5/16  = 31.25%
P(C) = 1/16  = 6.25%
```

Así, los sectores cercanos a `M25` tienen muchas más probabilidades de ser elegidos, pero no se selecciona siempre el más cercano.

Esto produce una expansión compacta e irregular de manera natural, sin necesidad de jitter ni de recalcular una frontera dinámica.

---

## 13. Cuándo se elimina una celda del pool

Una celda deja de ser candidata en cuanto ya no pueda convertirse legalmente en sector de jugador.

### 13.1 Sector descubierto/poblado

Si un reconocimiento u otra mecánica transforma un sector del pool de:

```text
UNGENERATED -> POPULATED
```

se elimina inmediatamente del pool.

Ejemplo:

```text
H28 estaba disponible para spawn
→ un jugador reconoce H28
→ H28 se resuelve como HUNTING
→ H28 se elimina del pool
```

El spawn nunca sobrescribe un sector ya resuelto.

### 13.2 Nuevo bunker

Si se asigna un bunker en `M25`, se elimina del pool:

- `M25`;
- todas las celdas del pool cuya distancia a `M25` sea `<= 2`.

Así la propia estructura del pool mantiene la separación mínima.

Los pesos de todas las demás entradas permanecen intactos.

---

## 14. Saturación y siguientes ventanas

Una ventana se considera saturada cuando ya no queda ninguna entrada válida en su pool activo.

Cuando `[10-40]` se agota, se avanza conceptualmente a:

```text
[41-80]
```

Después:

```text
[81-120]
[121-160]
...
```

El tamaño exacto de las ventanas posteriores será configurable.

Si la nueva ventana supera el máximo materializado, el backend amplía primero el mapa con sectores `UNGENERATED`.

Para cada nueva celda apta para spawn:

```text
calcular priorityWeight una sola vez
→ comprobar que no esté ya poblada
→ comprobar que no esté a distancia <= 2 de un bunker existente
→ añadirla al pool si sigue siendo válida
```

El origen continúa siendo siempre `M25`. Por eso, al abrir `[41-80]`, las posiciones próximas a `41` tienen naturalmente más probabilidad que las próximas a `80`, manteniendo la continuidad de la expansión.

---

## 15. Expansión por exploración

La exploración puede ampliar el mapa aunque la ventana de spawn actual todavía no esté saturada.

Ejemplo:

```text
máximo materializado = 50
jugador explora H53
→ ampliar mapa
→ H53 nace UNGENERATED
→ al completar reconocimiento, resolver H53
```

Si durante una expansión aparecen celdas que podrían formar parte de una ventana de spawn presente o futura, su prioridad puede calcularse cuando se incorporen al correspondiente pool.

La expansión del mundo y el avance de ventanas de spawn son mecanismos relacionados pero independientes.

---

## 16. Sistema de distancias

Las distancias se expresan en unidades decimales.

### 16.1 Sectores distintos

Se usa distancia euclídea:

```text
d = sqrt((Δx)^2 + (Δy)^2)
```

Las letras se convierten a posiciones consecutivas:

```text
A -> 0
B -> 1
...
Z -> 25
```

Ejemplos:

```text
B11 -> C11 = 1.0
B11 -> B12 = 1.0
B11 -> C12 = sqrt(2) ≈ 1.4142
```

### 16.2 Zonas de sectores distintos

El índice de zona no afecta a la distancia externa:

```text
B11-1 -> C12-1 = sqrt(2)
B11-1 -> C12-5 = sqrt(2)
B11-4 -> C12-2 = sqrt(2)
```

Todas las zonas de `H27` están a la misma distancia de todas las zonas de `J3`.

### 16.3 Zonas del mismo sector

Dos zonas diferentes del mismo sector están siempre a:

```text
0.1
```

La misma localización respecto a sí misma está a `0`.

Regla completa:

```text
si origen == destino:
    distancia = 0

si sector(origen) == sector(destino):
    distancia = 0.1

si sector(origen) != sector(destino):
    distancia = sqrt((x2-x1)^2 + (y2-y1)^2)
```

Debe existir una única implementación autoritativa de esta función.

---

## 17. Reconocimiento

Cuando termina un reconocimiento sobre un sector `UNGENERATED`:

```text
resolver TODAS sus zonas
→ persistir la composición completa
→ eliminarlo del pool de spawn si estaba presente
→ revelar SOLO una zona permitida al jugador
```

Si el sector ya estaba `POPULATED`:

```text
leer layout persistido
→ no regenerar nada
→ revelar una zona todavía desconocida para ese jugador
```

Todos los jugadores comparten el mismo mundo real.

---

## 18. Estado real vs. conocimiento

El backend mantiene la verdad completa:

```text
WORLD / SECTORS
SECTOR / ZONES
```

Cada jugador mantiene únicamente su conocimiento:

```text
PLAYER MAP KNOWLEDGE
```

Que el backend conozca cinco zonas de un sector no implica que el cliente tenga derecho a recibirlas.

La revelación debe controlarse desde backend.

---

## 19. Persistencia y concurrencia

Un sector ya resuelto no se vuelve a generar salvo que una futura mecánica modifique explícitamente su estado.

En el alta de una cuenta, la selección aleatoria puede calcularse sobre una lectura del pool, pero la confirmación final debe ser segura frente a concurrencia.

La operación lógica debe garantizar:

```text
candidato sigue disponible
→ reservarlo
→ eliminarlo del pool
→ eliminar vecinos a d <= 2
→ asignar jugador
→ generar sector completo
→ persistir
```

Si otra alta o un reconocimiento modifica el candidato antes de confirmar, el intento se aborta y se realiza una nueva selección sobre el pool actualizado.

Dos altas simultáneas no pueden obtener el mismo sector ni dos sectores que incumplan `d > 2`.

---

## 20. Configuración conceptual

Como mínimo, el sistema debería permitir configurar:

```text
MAP
- letters = A-Z
- initialNumberMin = 1
- initialNumberMax = 50
- zonesPerSector

PLAYER_SPAWN
- letterMin = D
- letterMax = W
- originLetter = M
- originNumber = 25
- initialNumberMin = 10
- initialNumberMax = 40
- minimumPlayerDistance = 2.0
- proximityAlpha = 1.0
- subsequentWindowSize = 40
```

El máximo materializado del mapa y la ventana activa de spawn son conceptos distintos y deben almacenarse por separado.

---

## 21. Invariantes principales

1. Una coordenada `sector-zona` identifica una única localización.
2. El eje alfabético está limitado a `A-Z`.
3. El eje numérico empieza en `1` y no tiene límite superior conceptual.
4. Ampliar el mapa no implica poblar los nuevos sectores.
5. Un sector `POPULATED` no se vuelve a sortear.
6. Todos los jugadores comparten el mismo mundo real.
7. El conocimiento del mapa es individual por jugador.
8. Un sector `PLAYER_BUNKER` se resuelve completamente al asignarse.
9. Dos jugadores nunca comparten sector de bunker.
10. Los sectores iniciales no introducen grandes diferencias de calidad por azar.
11. Los nuevos jugadores aparecen únicamente en `D-W` y dentro de la ventana numérica activa.
12. La zona de spawn no limita movimiento ni exploración.
13. Dos bunkers distintos mantienen siempre `d > 2.0`.
14. Cada celda candidata recibe una prioridad estática basada en su proximidad a `M25`.
15. La prioridad se calcula una sola vez cuando la celda entra en el pool.
16. La selección de spawn es aleatoria con probabilidad proporcional al peso de prioridad.
17. Un sector que pasa a `POPULATED` se elimina del pool de spawn.
18. Un bunker elimina del pool su sector y todos los candidatos a `d <= 2`.
19. El resto de pesos no se recalcula al aparecer un bunker.
20. Una ventana se considera saturada cuando su pool queda sin candidatos.
21. Las ventanas siguientes avanzan hacia números superiores.
22. La exploración también puede ampliar el mapa independientemente del spawn.
23. Entre sectores distintos, la distancia ignora el índice de zona.
24. Dos zonas distintas del mismo sector están siempre a `0.1`.
25. La asignación final de un sector de jugador debe ser atómica.

---

## 22. Documentos relacionados

- [`SPAWN_PLACEMENT.md`](./SPAWN_PLACEMENT.md): especificación detallada del pool persistente de candidatos, función de proximidad, selección ponderada, invalidación por descubrimiento/bunker, expansión y concurrencia.

La arquitectura resultante es: **mundo persistente de anchura fija `A-Z`, longitud numérica ampliable, jugadores restringidos inicialmente a `D-W`, pool persistente de candidatos ponderado por proximidad a `M25`, separación estricta `> 2`, sectores resueltos bajo demanda y conocimiento parcial por jugador**.
