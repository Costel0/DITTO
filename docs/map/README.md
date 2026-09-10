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

No existen coordenadas numéricas negativas ni `0` como sector jugable si se mantiene esta convención.

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

Cuando se crea una cuenta, el backend busca un sector válido dentro de la ventana activa de spawn.

El flujo es:

```text
buscar candidato
→ comprobar separación
→ reservar atómicamente
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

La banda alfabética inicial queda fijada en:

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

El origen inicial del crecimiento es:

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

Por ejemplo:

```text
M25 -> M27 = 2.0        NO permitido
M25 -> N26 = sqrt(2)    NO permitido
M25 -> N27 = sqrt(5)    SÍ permitido
M25 -> O26 = sqrt(5)    SÍ permitido
M25 -> P25 = 3.0        SÍ permitido
```

Como las coordenadas de sector son enteras, validar `d > 2` puede hacerse comprobando únicamente el pequeño vecindario del candidato cuya distancia sea `<= 2`, sin recorrer todos los jugadores del servidor.

---

## 10. Algoritmo de colocación propuesto

La estrategia elegida para la primera implementación es un **crecimiento radial con frontera preferente y jitter determinista**.

### 10.1 Primer jugador

Se intenta colocar en:

```text
M25
```

Si no está disponible se utiliza el candidato válido de mayor prioridad alrededor de ese origen.

### 10.2 Candidatos válidos

Un sector solo puede recibir un jugador si:

- está en `D-W`;
- está en la ventana numérica activa;
- no está reservado;
- no está ya `POPULATED`;
- puede convertirse legalmente en `PLAYER_BUNKER`;
- mantiene `d > 2` respecto a todos los bunkers existentes.

Un sector que ya fue resuelto por reconocimiento no se sobrescribe para acomodar un jugador nuevo.

### 10.3 Frontera preferente

Entre los candidatos válidos se prefieren aquellos que tengan algún jugador existente a:

```text
2.0 < d <= 4.0
```

El `4.0` es una preferencia, no una regla dura.

Esto hace que la población vaya creciendo desde los jugadores ya existentes en vez de saltar a posiciones aisladas.

Si no hay candidatos en esa frontera pero siguen existiendo posiciones legales en la ventana, se usa el mejor candidato global. De esta forma obstáculos o sectores ya explorados no bloquean artificialmente el sistema.

### 10.4 Prioridad radial

Los candidatos preferentes se ordenan principalmente por distancia al origen global:

```text
M25
```

Cuanto más cerca de `M25`, mayor prioridad.

El origen no cambia cuando se avanza a ventanas posteriores. Esto es importante para que `[41-80]` empiece a poblarse cerca de `41` y continúe físicamente el crecimiento anterior, en vez de iniciar otra colonia aislada cerca de `60`.

### 10.5 Jitter determinista

Para evitar un patrón geométrico demasiado perfecto se añade una pequeña perturbación estable:

```text
jitter(C) = hash01(worldSeed, coordinate) * 0.75
priority(C) = distance(C, M25) + jitter(C)
```

Se elige la prioridad más baja.

El jitter es pequeño: altera el orden entre sectores parecidos, pero no permite que sectores mucho más lejanos adelanten al frente de crecimiento.

Al derivarse de `worldSeed + coordinate`, el resultado es reproducible y seguro frente a reintentos de transacciones.

La especificación completa, pseudocódigo, concurrencia y optimizaciones se encuentra en [`SPAWN_PLACEMENT.md`](./SPAWN_PLACEMENT.md).

---

## 11. Saturación y siguientes ventanas

Una ventana solo está saturada cuando **no queda ningún sector legal** para un nuevo jugador.

La ausencia de candidatos cercanos a la frontera `<= 4` no significa saturación: primero se comprueba si existen otros candidatos válidos.

Cuando `[10-40]` se satura, se avanza conceptualmente a:

```text
[41-80]
```

Después:

```text
[81-120]
[121-160]
...
```

El tamaño de las ventanas posteriores debe ser configurable.

Si una nueva ventana supera el máximo actualmente materializado, el backend amplía el mapa con sectores `UNGENERATED` antes de utilizarlos.

---

## 12. Sistema de distancias

Las distancias se expresan en unidades decimales.

### 12.1 Sectores distintos

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

### 12.2 Zonas de sectores distintos

El índice de zona no afecta a la distancia externa:

```text
B11-1 -> C12-1 = sqrt(2)
B11-1 -> C12-5 = sqrt(2)
B11-4 -> C12-2 = sqrt(2)
```

Todas las zonas de `H27` están a la misma distancia de todas las zonas de `J3`.

### 12.3 Zonas del mismo sector

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

## 13. Reconocimiento

Cuando termina un reconocimiento sobre un sector `UNGENERATED`:

```text
resolver TODAS sus zonas
→ persistir la composición completa
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

## 14. Estado real vs. conocimiento

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

## 15. Persistencia y concurrencia

Un sector ya resuelto no se vuelve a generar salvo que una futura mecánica modifique explícitamente su estado.

El alta de una cuenta debe tratar como una única operación lógica:

```text
leer estado de spawn
→ elegir candidato
→ revalidar separación
→ reservar
→ asignar jugador
→ generar sector completo
→ persistir
```

Dos altas simultáneas no pueden obtener el mismo sector ni dos sectores que incumplan `d > 2`.

La especificación de spawn propone un estado autoritativo con revisión/transacción para serializar de forma segura esta operación, que tiene una frecuencia muy baja comparada con las acciones normales de juego.

---

## 16. Configuración conceptual

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
- preferredLinkDistance = 4.0
- jitterMax = 0.75
- subsequentWindowSize = 40
- worldSeed
```

El máximo materializado del mapa y la ventana activa de spawn son conceptos distintos y deben almacenarse por separado.

---

## 17. Invariantes principales

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
11. Los nuevos jugadores aparecen únicamente en la banda `D-W` y en la ventana numérica activa.
12. La zona de spawn no limita movimiento ni exploración.
13. Dos bunkers distintos mantienen siempre `d > 2.0`.
14. Se prefiere crecimiento próximo a jugadores existentes, sin convertirlo en una restricción que pueda bloquear altas.
15. La población crece desde `M25` hacia fuera.
16. El jitter solo rompe simetrías; nunca invalida las reglas duras.
17. Una ventana solo se declara saturada cuando no queda ningún candidato legal.
18. Las siguientes ventanas avanzan hacia números superiores.
19. La exploración también puede ampliar el mapa independientemente del spawn.
20. Entre sectores distintos, la distancia ignora el índice de zona.
21. Dos zonas distintas del mismo sector están siempre a `0.1`.
22. La asignación final de un sector de jugador debe ser atómica.

---

## 18. Documentos relacionados

- [`SPAWN_PLACEMENT.md`](./SPAWN_PLACEMENT.md): algoritmo detallado de colocación de jugadores, frontera de crecimiento, jitter, pseudocódigo, concurrencia y optimización.

La arquitectura resultante es: **mundo persistente de anchura fija `A-Z`, longitud numérica ampliable, jugadores restringidos inicialmente a `D-W`, crecimiento compacto desde `M25`, separación estricta `> 2`, sectores resueltos bajo demanda y conocimiento parcial por jugador**.