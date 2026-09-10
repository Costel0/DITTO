# DITTO — Sistema de mapa, coordenadas y expansión

> Documento de diseño inicial del mundo persistente de DITTO. Define coordenadas, sectores y zonas, generación bajo demanda, conocimiento del jugador, distancias, asignación de bunkers y crecimiento progresivo del mapa.
>
> Estado: **propuesta base / pendiente de implementación**.
>
> Última actualización: 2026-09-10.

---

## 1. Idea general

El mundo de DITTO se organiza como una cuadrícula 2D de **sectores**. Cada sector contiene varias **zonas** internas.

La geometría del mundo existe de forma lógica aunque el backend no haya poblado todavía todos sus sectores. El mundo real es único y compartido por todos los jugadores, pero su contenido se resuelve progresivamente cuando una acción del juego obliga al servidor a hacerlo.

La idea central es:

**mapa global persistente + sectores generados bajo demanda + conocimiento parcial por jugador + expansión progresiva del eje numérico**.

---

## 2. Coordenadas

Una localización completa utiliza tres componentes conceptuales:

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

### 3.1 Eje alfabético: limitado

El eje de letras está limitado al alfabeto inglés:

```text
A ... Z
```

No existen filas posteriores a `Z` ni anteriores a `A`.

Por tanto, el mundo tiene una anchura fija de **26 sectores** en este eje.

### 3.2 Eje numérico: ampliable indefinidamente

El eje numérico comienza en valores positivos y puede crecer indefinidamente:

```text
1, 2, 3, ... 50, 51, 52, ...
```

No existen sectores con números negativos ni se puede atravesar el límite inferior del mapa.

El mapa puede comenzar materializado, por ejemplo, como:

```text
[A-Z] × [1-50]
```

pero `50` **no es el límite real del mundo**. Es únicamente el límite materializado inicialmente.

Si el juego necesita acceder a una coordenada superior, el backend amplía la plantilla creando las nuevas celdas necesarias como sectores vacíos/no generados.

Ejemplo:

```text
Mapa actual: [A-Z] × [1-50]
Un jugador intenta explorar M51
→ el servidor amplía el mapa
→ M51 pasa a ser una coordenada válida
→ los nuevos sectores nacen sin poblar salvo que una acción obligue a generarlos
```

La expansión debe poder realizarse por bloques y no necesariamente una única columna cada vez.

---

## 4. Sector y zona

### Sector

Es la unidad geográfica principal del mapa.

Ejemplo:

```text
B12
```

Un sector:

- tiene una posición única en la cuadrícula;
- contiene varias zonas;
- tiene un tipo o carácter principal;
- puede estar sin generar o ya poblado;
- condiciona las reglas de generación de sus zonas internas.

### Zona

Es una localización concreta dentro del sector.

Ejemplo:

```text
B12-3
```

Una zona puede representar, por ejemplo:

- bunker de jugador;
- bunker abandonado;
- zona de caza;
- lago;
- ruinas;
- edificio abandonado;
- otras localizaciones futuras.

El jugador interactúa con zonas, mientras que el sector sirve como unidad geográfica, unidad de distancia y contexto de generación.

---

## 5. Tipo principal del sector

Cada sector está caracterizado por una función o zona principal que define su **tipo de sector**.

Ejemplo:

```text
B12 -> PLAYER_BUNKER
```

Si el bunker del jugador está en:

```text
B12-3
```

`B12` es un sector de jugador aunque sus otras cuatro zonas puedan ser de tipos distintos.

El tipo de sector determina restricciones, compatibilidades y, cuando corresponda, probabilidades de generación.

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
- puede utilizar probabilidades propias de generación
```

---

## 6. Generación lazy del mundo

El backend conoce las reglas y la geometría, pero no necesita decidir el contenido de todos los sectores al crear el servidor.

Un sector puede encontrarse conceptualmente en:

```text
UNGENERATED
POPULATED
```

### `UNGENERATED`

La coordenada existe, pero el servidor todavía no ha decidido qué zonas contiene.

### `POPULATED`

El servidor ya ha resuelto todas sus zonas y la composición ha quedado persistida como parte del mundo real.

Una vez poblado, un sector **no vuelve a sortearse** por explorarlo de nuevo.

---

## 7. Sectores de jugador

Cuando se crea una cuenta, el backend selecciona un sector válido dentro de la zona actual permitida para nuevos jugadores.

Flujo conceptual:

```text
Nueva cuenta
   ↓
Buscar sector válido para spawn
   ↓
Comprobar separación mínima respecto a otros jugadores
   ↓
Reservar el sector de forma atómica
   ↓
Convertirlo en PLAYER_BUNKER
   ↓
Asignar una zona al bunker
   ↓
Resolver TODAS las zonas del sector
   ↓
Persistir el sector completo
   ↓
Revelar al jugador únicamente su conocimiento inicial
```

### 7.1 Resolución inmediata

Cuando un sector se asigna a un jugador, **todo el sector se resuelve inmediatamente**.

No quedan zonas internas pendientes de generación posterior.

El backend puede saber:

```text
B12-1 = RUINS
B12-2 = HUNTING
B12-3 = PLAYER_BUNKER(player_123)
B12-4 = EMPTY
B12-5 = ABANDONED_BUILDING
```

mientras el jugador conoce inicialmente solo:

```text
B12-3 = MY_BUNKER
```

### 7.2 Equidad inicial

Los sectores `PLAYER_BUNKER` no deben utilizar una tirada aleatoria de calidad que pueda dar a un jugador varias zonas extraordinarias y a otro un sector claramente peor desde el inicio.

La composición exacta se definirá más adelante, pero debe mantener un valor inicial equivalente entre jugadores.

La aleatoriedad puede aportar variedad siempre que no produzca diferencias materiales de ventaja inicial.

---

## 8. Zona permitida para aparición de jugadores

El hecho de que una coordenada exista en el mundo **no significa que pueda recibir un nuevo jugador**.

El servidor mantiene una **zona de spawn o zona poblable activa** destinada exclusivamente a controlar dónde pueden aparecer nuevas cuentas.

Conceptualmente puede definirse mediante:

```text
spawnLetters = [LETTER_MIN, LETTER_MAX]
spawnNumbers = [NUMBER_MIN, NUMBER_MAX]
```

Ejemplo de ventana numérica inicial:

```text
[10, 40]
```

La intención es impedir que un jugador nuevo aparezca demasiado cerca de un borde físico del mapa y tenga menos posibilidades de expansión o exploración que otros jugadores.

### 8.1 Banda de letras

La banda de letras permitida será un subconjunto interior de `[A-Z]`, dejando margen respecto a `A` y `Z`.

El diseño propone que la población comience alrededor de la fila central:

```text
M
```

Por tanto, la configuración definitiva de la banda de letras debe **contener M**.

> Nota de diseño: el ejemplo `[D,J]` no contiene `M`, por lo que no puede utilizarse literalmente al mismo tiempo que `M` sea la fila inicial. Se mantiene como ejemplo del concepto de limitar la banda, pero la configuración concreta deberá corregirse o aclararse antes de implementarla.

### 8.2 Motivo del margen

Un bunker colocado inicialmente muy cerca de `A`, `Z` o del límite numérico inferior tendría una dirección con mucha menos profundidad explorable.

Por ello el spawn se restringe a una zona interior aunque el jugador pueda posteriormente explorar fuera de ella.

La **zona poblable limita el spawn, no el movimiento ni la exploración**.

---

## 9. Crecimiento compacto de la población

Los jugadores no se distribuirán uniformemente por toda la ventana de spawn.

La intención es que la población nazca en una zona central y vaya creciendo de forma compacta hacia fuera.

Por ejemplo, con una ventana numérica inicial `[10,40]`, el centro aproximado es:

```text
25
```

junto con la fila central:

```text
M
```

por lo que el origen conceptual del crecimiento sería aproximadamente:

```text
M25
```

Los primeros jugadores se colocarán alrededor de ese núcleo y los siguientes irán ocupando posiciones cada vez más externas conforme se llene el espacio cercano.

### 9.1 Separación mínima entre jugadores

Dos bunkers de jugadores distintos deben estar separados por una distancia estrictamente mayor que:

```text
2.0
```

Por tanto, una posición candidata `C` solo puede utilizarse si para todos los bunkers existentes `P` se cumple:

```text
distance(C, P) > 2.0
```

La comprobación utiliza la misma distancia euclídea de sectores definida en este documento.

### 9.2 Algoritmo conceptual de colocación

El algoritmo exacto queda pendiente, pero debe respetar estas prioridades:

1. utilizar únicamente sectores dentro de la ventana de spawn activa;
2. excluir sectores ya reservados, incompatibles o no válidos;
3. exigir distancia `> 2.0` respecto a todos los bunkers existentes relevantes;
4. favorecer posiciones cercanas al núcleo ya poblado;
5. expandir progresivamente la población desde el centro hacia los extremos de la ventana;
6. introducir aleatoriedad entre candidatos equivalentes para evitar patrones completamente artificiales.

Una estrategia sencilla sería puntuar los candidatos por cercanía al centro de crecimiento y/o a la frontera de la población existente, manteniendo siempre la separación mínima.

El objetivo no es maximizar la distancia entre jugadores, sino conseguir una población **compacta pero no amontonada**.

---

## 10. Saturación y desplazamiento de la ventana de spawn

Una ventana de spawn se considera saturada cuando ya no existe ningún sector válido en ella que permita colocar un nuevo jugador cumpliendo las restricciones, especialmente la separación mínima `> 2.0`.

Cuando esto ocurra, la zona numérica permitida para nuevos jugadores se desplaza hacia adelante.

Ejemplo conceptual:

```text
Ventana inicial:   [10, 40]
Siguiente ventana: [41, 80]
Siguiente ventana: [81, 120]
...
```

Los intervalos exactos y su posible solapamiento serán configurables; lo importante es que el sistema pueda avanzar indefinidamente por el eje numérico.

### 10.1 Expansión del mapa por saturación

Si la nueva ventana requiere números que todavía no forman parte del mapa materializado, el backend amplía previamente la plantilla con sectores vacíos.

Ejemplo:

```text
Mapa materializado: [1, 50]
Nueva zona de spawn: [41, 80]
→ crear estructura vacía hasta 80
→ los sectores nuevos siguen UNGENERATED
```

No es necesario poblar esas nuevas celdas al ampliarlas.

---

## 11. Expansión del mapa por exploración

La saturación de la zona de spawn no es la única causa de expansión.

Si un jugador intenta explorar una coordenada cuyo número supera el máximo materializado actual, el mapa también se amplía.

Ejemplo:

```text
Máximo actual: 50
Exploración solicitada: H53
→ ampliar plantilla hasta cubrir H53
→ H53 existe como UNGENERATED
→ al resolverse el reconocimiento, poblar H53 si sigue sin generar
```

Así, **la exploración de jugadores y el crecimiento de población pueden ampliar el mundo de forma independiente**.

---

## 12. Sistema de distancias

Las distancias se expresan en unidades decimales.

### 12.1 Entre sectores distintos

La distancia depende exclusivamente de las dos coordenadas del sector:

```text
d = sqrt((Δx)^2 + (Δy)^2)
```

Las letras se convierten a posiciones consecutivas:

```text
A -> 0
B -> 1
C -> 2
...
Z -> 25
```

Ejemplos:

```text
B11 -> C11 = 1.0
B11 -> B12 = 1.0
B11 -> C12 = sqrt(2) ≈ 1.4142
```

### 12.2 El índice de zona no afecta a sectores distintos

Todas las zonas de un mismo sector comparten la misma posición externa.

Por tanto:

```text
B11-1 -> C12-1 = sqrt(2)
B11-1 -> C12-5 = sqrt(2)
B11-4 -> C12-2 = sqrt(2)
```

Y todas las zonas de `H27` están exactamente a la misma distancia de todas las zonas de `J3`.

### 12.3 Dentro de un mismo sector

Dos zonas distintas del mismo sector tienen siempre:

```text
0.1
```

Ejemplos:

```text
B12-1 -> B12-2 = 0.1
B12-1 -> B12-3 = 0.1
B12-1 -> B12-5 = 0.1
```

Una localización respecto a sí misma tiene distancia `0`.

### 12.4 Regla completa

```text
si origen == destino:
    distancia = 0

si sector(origen) == sector(destino):
    distancia = 0.1

si sector(origen) != sector(destino):
    distancia = sqrt((x2-x1)^2 + (y2-y1)^2)
```

Debe existir una única implementación autoritativa de esta función para viajes, exploración, consumo, tiempos, rango y cualquier otra mecánica espacial.

---

## 13. Reconocimiento y población de sectores

Cuando termina un reconocimiento:

```text
Reconocimiento de C12
   ↓
¿C12 está POPULATED?
   ↓ no
Resolver TODAS las zonas de C12
   ↓
Persistir la composición completa
   ↓
Revelar SOLO una zona permitida al jugador
```

Si `C12` ya estaba poblado:

```text
Reconocimiento de C12
   ↓
Leer el layout persistido
   ↓
No regenerar nada
   ↓
Revelar una zona todavía desconocida para ese jugador
```

Todos los jugadores comparten el mismo mundo real.

---

## 14. Estado real vs. conocimiento del jugador

El backend mantiene la verdad autoritativa del mundo:

```text
WORLD / SECTORS
SECTOR / ZONES
```

Mientras que cada jugador mantiene su propio conocimiento:

```text
PLAYER MAP KNOWLEDGE
```

El servidor puede conocer cinco zonas de un sector mientras un jugador conoce solo una.

La aplicación cliente nunca debe recibir automáticamente el layout oculto completo por el simple hecho de que el sector ya exista en Firestore.

La revelación debe ser controlada por backend.

---

## 15. Persistencia y concurrencia

Una vez generado un sector, su composición permanece fija salvo que una futura mecánica modifique explícitamente una zona.

La generación inicial debe ser segura frente a concurrencia.

Especialmente en el alta de una cuenta, deben tratarse como una única operación lógica:

```text
validar candidato
→ comprobar distancia mínima
→ reservar sector
→ asignar bunker
→ generar sector completo
→ persistir
```

Dos altas simultáneas no pueden recibir el mismo sector ni sectores que incumplan la separación mínima por una condición de carrera.

---

## 16. Invariantes principales

1. Una coordenada `sector-zona` identifica una única localización.
2. El eje alfabético está limitado a `A-Z`.
3. El eje numérico no tiene límite superior conceptual.
4. No existen coordenadas numéricas negativas.
5. El límite materializado actual puede ampliarse sin poblar los nuevos sectores.
6. Un sector poblado no se vuelve a sortear.
7. Todos los jugadores comparten el mismo mundo real.
8. El conocimiento del mapa es individual por jugador.
9. Un sector `PLAYER_BUNKER` se resuelve completamente al asignarse.
10. Dos jugadores nunca comparten un mismo sector de bunker.
11. Los sectores iniciales no deben introducir grandes diferencias de calidad por azar.
12. La zona de spawn limita únicamente dónde aparecen nuevos jugadores.
13. Los jugadores pueden explorar fuera de la zona de spawn.
14. Los bunkers nuevos deben mantener distancia estrictamente mayor que `2.0` respecto a los demás bunkers afectados por la regla.
15. La población debe crecer de forma compacta desde una región central hacia los extremos de la ventana activa.
16. Al saturarse una ventana de spawn, el sistema desplaza la ventana hacia números superiores.
17. La exploración también puede provocar expansión del mapa.
18. Entre sectores distintos, la distancia ignora la zona interna.
19. Entre dos zonas distintas del mismo sector, la distancia es siempre `0.1`.

---

## 17. Modelo conceptual de configuración

Sin fijar todavía el JSON definitivo, la configuración global podría contener conceptos como:

```text
MAP
- letters: A-Z
- initialNumberMin: 1
- initialNumberMax: 50
- zonesPerSector: configurable

PLAYER_SPAWN
- letterMin
- letterMax
- initialNumberMin
- initialNumberMax
- centerLetter: M
- minimumPlayerDistance: > 2.0
- expansionWindowSize
- placementStrategy
```

El límite materializado del mapa y la ventana activa de spawn deben almacenarse como conceptos distintos.

---

## 18. Decisiones todavía abiertas

Queda por concretar al implementar:

- número definitivo de zonas por sector;
- banda exacta de letras permitida para spawn;
- corrección del ejemplo `[D,J]` si `M` debe seguir siendo el origen central;
- ventana numérica inicial exacta;
- tamaño y posible solapamiento de las siguientes ventanas (`41-80`, etc.);
- algoritmo y función de puntuación exactos para elegir el siguiente sector de jugador;
- si la distancia mínima se comprueba contra todos los jugadores o puede optimizarse mediante índices espaciales/locales;
- composición exacta que garantiza equidad en `PLAYER_BUNKER`;
- tipos iniciales de sector y zona;
- reglas de generación de sectores no iniciales;
- qué ocurre cuando un jugador ha descubierto todas las zonas de un sector;
- cómo pueden cambiar o agotarse zonas en el futuro;
- precisión mostrada al jugador para distancias.

La arquitectura base queda definida como: **anchura fija A-Z, longitud numérica ampliable, spawn controlado en ventanas interiores, crecimiento compacto de población, sectores generados bajo demanda y mundo persistente compartido**.
