# DITTO — Sistema de mapa y coordenadas

> Documento de diseño inicial. Describe el modelo conceptual del mapa, sus coordenadas, la generación de sectores y la diferencia entre el estado real del mundo y la información conocida por cada jugador.
>
> Estado: **propuesta base / pendiente de implementación**.
>
> Última actualización: 2026-09-10.

---

## 1. Objetivo general

El mundo de DITTO se organizará como un mapa 2D dividido en **sectores**. Cada sector contendrá varias **zonas** internas.

La intención es que el servidor conozca desde el principio la **estructura del mapa** —sus límites, coordenadas válidas, número de zonas por sector y reglas de generación—, pero que **no sea necesario poblar todo el mundo al crear el servidor**.

Los sectores se irán materializando de forma progresiva cuando el juego lo necesite. Esto permite que el mundo sea persistente para todos los jugadores sin tener que generar y almacenar de entrada cada localización posible.

La idea central es:

**geometría global predefinida + contenido de sectores generado bajo demanda + conocimiento parcial por jugador**.

---

## 2. Sistema de coordenadas

Una localización completa utiliza tres componentes conceptuales:

1. Coordenada horizontal del sector.
2. Coordenada vertical del sector.
3. Índice de la zona dentro del sector.

La representación legible propuesta es:

```text
B12-3
```

Donde:

- `B12` identifica el **sector** del tablero 2D.
- `3` identifica una **zona concreta dentro de ese sector**.

Por ejemplo:

```text
B12-1
B12-2
B12-3
B12-4
B12-5
```

serían cinco localizaciones distintas pertenecientes al mismo sector `B12`.

Sectores como `B11`, `B13`, `A12` y `C12` son sectores adyacentes a `B12` siguiendo la geometría normal de una cuadrícula 2D.

El número de zonas por sector deberá ser configurable. En los ejemplos de este documento se utilizan **5 zonas por sector**, pero no se considera todavía una constante definitiva del diseño.

---

## 3. Sector y zona son conceptos diferentes

### Sector

Es la unidad geográfica principal del mapa.

Ejemplo:

```text
B12
```

Un sector:

- ocupa una posición única en el tablero 2D;
- contiene varias zonas;
- tiene un **tipo o carácter principal**;
- impone reglas sobre qué tipos de zonas pueden coexistir dentro de él;
- puede estar todavía sin generar o haber sido ya poblado por el backend.

### Zona

Es una localización concreta dentro de un sector.

Ejemplo:

```text
B12-3
```

Cada zona tiene su propio tipo y podrá representar cosas como:

- bunker de jugador;
- bunker abandonado;
- zona de caza;
- lago;
- ruinas;
- otros tipos que se añadan en el futuro.

El jugador interactúa realmente con **zonas**, mientras que el sector sirve como agrupación geográfica y como contexto para las reglas de generación.

---

## 4. Tipo principal de un sector

Cada sector estará caracterizado por una única zona o función **importante/principal**. Esa característica define el **tipo de sector** y condiciona cómo pueden generarse las demás zonas del mismo sector.

Ejemplo:

```text
Sector B12
Tipo principal: PLAYER_BUNKER
```

Si el bunker de un jugador está en:

```text
B12-3
```

entonces `B12` pasa a ser un **sector de bunker/jugador** y la zona `B12-3` contiene su localización principal.

Las otras zonas del sector se generan respetando las reglas asociadas a `PLAYER_BUNKER`.

Una regla fundamental de este tipo sería:

```text
Un sector PLAYER_BUNKER no puede contener más de un bunker de jugador.
```

Por tanto, dos jugadores distintos no pueden tener su bunker principal dentro del mismo sector, aunque ocupasen índices de zona diferentes.

Otros tipos de sector podrán tener reglas diferentes. Por ejemplo, un sector cuyo carácter principal sea `HUNTING` podría permitir:

- varias zonas de caza;
- un bunker abandonado;
- un lago;
- otras localizaciones compatibles.

Por tanto, el **tipo de sector no significa que todas sus zonas sean del mismo tipo**. Es el arquetipo que determina la composición permitida y las probabilidades de generación de sus zonas internas.

---

## 5. El mapa no se puebla completamente al crear el servidor

El backend conoce de entrada:

- dimensiones y límites del mapa;
- coordenadas válidas;
- número de zonas por sector;
- tipos de sector posibles;
- tipos de zona posibles;
- reglas de compatibilidad;
- probabilidades y reglas de generación.

Pero un sector que nunca haya sido necesario puede permanecer **sin poblar**.

Conceptualmente, un sector puede encontrarse al menos en uno de estos estados:

```text
UNGENERATED
POPULATED
```

### `UNGENERATED`

El sector existe como posición válida del mapa, pero el servidor todavía no ha decidido qué localizaciones concretas contiene.

### `POPULATED`

El servidor ya ha generado su composición interna. Desde ese momento esa composición forma parte del estado persistente del mundo y no vuelve a sortearse en reconocimientos posteriores.

Esto significa que el mapa se genera de forma **lazy / on demand**.

---

## 6. Creación de una nueva cuenta

Cuando se crea un nuevo jugador, el backend debe localizar un sector apto que todavía no esté ocupado por otro jugador.

Flujo conceptual:

```text
Nueva cuenta
   ↓
Buscar sector disponible
   ↓
Reservarlo/asignarlo al jugador
   ↓
Convertirlo en sector PLAYER_BUNKER
   ↓
Asignar una de sus zonas al bunker del jugador
   ↓
Persistir la asignación
```

Ejemplo:

```text
Jugador: player_123
Sector: B12
Bunker: B12-3
Sector type: PLAYER_BUNKER
```

A partir de ese momento ningún otro jugador puede recibir ninguna de las demás zonas de `B12` como bunker principal.

La asignación debe ser atómica: dos cuentas creadas simultáneamente no pueden conseguir reservar el mismo sector por una condición de carrera.

### Composición del resto del sector

La asignación de un bunker ya fija como mínimo:

- el sector como `PLAYER_BUNKER`;
- la zona exacta del bunker;
- la exclusividad del sector para ese bunker de jugador.

Queda como decisión de implementación si las demás zonas compatibles del sector se generan inmediatamente al crear el jugador o en el primer momento posterior en que sea necesario conocerlas.

En ambos casos, una vez generadas deberán ser persistentes y respetar las mismas reglas de composición.

---

## 7. Reconocimiento de un sector todavía no poblado

Una misión de reconocimiento puede apuntar a un sector cuyo contenido todavía no haya sido generado.

Cuando la misión se complete:

```text
Reconocimiento de C12
   ↓
¿C12 está poblado?
   ↓ no
Generar C12 usando las reglas del mapa
   ↓
Guardar permanentemente su composición
   ↓
Seleccionar una zona revelable
   ↓
Revelar SOLO esa zona al jugador
```

Ejemplo interno del servidor después de generar `C12`:

```text
C12
├── C12-1  HUNTING
├── C12-2  LAKE
├── C12-3  HUNTING
├── C12-4  ABANDONED_BUNKER
└── C12-5  RUINS
```

El jugador que realizó el reconocimiento **no recibe necesariamente todo ese layout**.

Si el reconocimiento revela únicamente `C12-4`, su conocimiento podría ser simplemente:

```text
C12-4 -> ABANDONED_BUNKER
```

Las demás zonas existen ya en el mundo del servidor, pero continúan ocultas para ese jugador.

---

## 8. Reconocimiento de un sector ya poblado

Si otro jugador ya provocó anteriormente la generación de ese sector, el backend **no vuelve a generar nada**.

Flujo:

```text
Reconocimiento de C12
   ↓
¿C12 está poblado?
   ↓ sí
Leer la composición persistida de C12
   ↓
Seleccionar una zona todavía revelable para ese jugador
   ↓
Actualizar únicamente el conocimiento de ese jugador
```

Por tanto, todos los jugadores comparten un único mundo real.

Dos jugadores que exploran `C12` consultan el mismo `C12`; no tienen versiones privadas o generadas de forma independiente del sector.

---

## 9. Estado real del mundo vs. conocimiento del jugador

Esta separación es fundamental.

### Estado real del mundo

Es información autoritativa del backend.

Incluye, por ejemplo:

- qué sectores han sido poblados;
- el tipo principal de cada sector poblado;
- todas las zonas reales de esos sectores;
- qué jugador ocupa un bunker;
- contenido que todavía ningún jugador ha descubierto.

### Conocimiento del jugador

Es únicamente lo que un jugador concreto ha descubierto.

Por ejemplo, el backend podría saber:

```text
B12-1 = RUINS
B12-2 = HUNTING
B12-3 = PLAYER_BUNKER
B12-4 = LAKE
B12-5 = ABANDONED_BUNKER
```

mientras el jugador solamente conoce:

```text
B12-3 = MY_BUNKER
B12-4 = LAKE
```

La aplicación cliente nunca debe deducir que por existir un sector generado tiene derecho a recibir todas sus zonas.

El backend debe filtrar explícitamente qué información del mapa puede conocer cada jugador.

---

## 10. Persistencia del mundo

Una vez poblado un sector, su contenido debe convertirse en parte permanente del mundo salvo que una futura mecánica de juego modifique explícitamente alguna zona.

Un reconocimiento posterior nunca debe ejecutar otra tirada de generación sobre un sector ya poblado.

Regla principal:

```text
generateSector(coordinate)
```

solo puede materializar un sector si todavía está sin generar.

Si dos eventos intentan generar el mismo sector simultáneamente, el sistema debe garantizar que **solo una composición termina siendo la oficial**. La implementación deberá usar una operación transaccional o mecanismo equivalente.

---

## 11. Reglas de generación

La generación de sectores deberá estar dirigida por datos y reglas, no por condicionales dispersos por las Cloud Functions.

Conceptualmente cada tipo de sector podrá definir:

- zona principal obligatoria;
- mínimo y máximo de cada tipo de zona;
- tipos prohibidos;
- tipos compatibles;
- pesos/probabilidades para rellenar huecos;
- restricciones especiales;
- número de zonas del sector.

Ejemplo conceptual, no definitivo:

```text
PLAYER_BUNKER
- exactamente 1 PLAYER_BUNKER
- 0 bunkers adicionales de jugador
- resto de zonas elegidas entre tipos compatibles

HUNTING
- al menos 1 HUNTING
- puede contener varias HUNTING
- puede coexistir con ABANDONED_BUNKER
- puede coexistir con LAKE
```

Estas reglas determinarán la composición interna cuando un sector se genere por primera vez.

---

## 12. Invariantes del sistema

El diseño debe preservar siempre estas reglas:

1. Una coordenada completa `sector-zona` identifica una única localización del mundo.
2. Un sector mantiene siempre la misma posición en la cuadrícula.
3. Una vez poblado, un sector no se vuelve a sortear por explorarlo otra vez.
4. Todos los jugadores consultan el mismo estado real del mundo.
5. El conocimiento de cada jugador es independiente del estado real del mundo.
6. Un jugador no debe recibir información de zonas que todavía no haya descubierto.
7. Un sector de jugador no puede contener bunkers principales de dos jugadores diferentes.
8. La reserva de sectores de jugador debe ser segura frente a concurrencia.
9. La primera generación de un sector también debe ser segura frente a concurrencia.
10. El tipo principal del sector condiciona la generación de sus zonas, pero no obliga a que todas sean del mismo tipo.

---

## 13. Ejemplo completo

Supongamos un mapa donde `B12` todavía no ha sido usado.

### Paso 1 — creación del jugador A

El backend selecciona `B12` y asigna:

```text
player_A -> B12-3
```

El sector queda reservado como:

```text
B12 -> PLAYER_BUNKER
```

Ningún jugador futuro podrá establecer su bunker principal en `B12`.

### Paso 2 — generación de sus zonas

Cuando corresponda materializar el sector, una composición válida podría ser:

```text
B12-1 = RUINS
B12-2 = HUNTING
B12-3 = PLAYER_BUNKER(player_A)
B12-4 = LAKE
B12-5 = ABANDONED_BUNKER
```

### Paso 3 — otro jugador reconoce B12

El backend ya conoce el layout y no genera uno nuevo.

La misión podría descubrir únicamente:

```text
B12-5 = ABANDONED_BUNKER
```

El jugador B conoce ahora esa zona, pero no necesariamente `B12-1`, `B12-2`, `B12-3` o `B12-4`.

### Paso 4 — otro reconocimiento

Una misión posterior podrá revelar otra zona del mismo layout persistente.

La exploración amplía el **conocimiento**, no recrea el **mundo**.

---

## 14. Modelo conceptual de datos

La implementación concreta en Firestore se decidirá más adelante, pero conceptualmente conviene mantener separadas al menos estas responsabilidades:

```text
WORLD / SECTORS
    verdad autoritativa del mapa

SECTOR / ZONES
    composición real persistente de un sector

PLAYER MAP KNOWLEDGE
    sectores y zonas descubiertos por cada jugador

GENERATION RULES
    reglas configurables usadas para materializar nuevos sectores
```

No se debe guardar el layout oculto dentro de un documento que el cliente pueda leer directamente si las reglas de Firestore permiten obtenerlo completo.

La revelación de mapa debería producirse a través de lógica autoritativa de backend.

---

## 15. Decisiones todavía abiertas

Este documento fija la arquitectura conceptual, pero todavía quedan decisiones que se pueden concretar al implementar:

- dimensiones exactas del mapa;
- si el mapa es finito, ampliable o dividido en regiones;
- número definitivo de zonas por sector;
- formato interno de las coordenadas frente al formato visual `B12-3`;
- convención de letras después de `Z` si el eje lo necesita;
- lista inicial de tipos de sector;
- lista inicial de tipos de zona;
- reglas y pesos de generación de cada tipo de sector;
- criterio para elegir sectores de nuevos jugadores y distancia entre ellos;
- si un sector `PLAYER_BUNKER` genera todas sus zonas en el alta o deja las no necesarias pendientes hasta el primer reconocimiento;
- qué ocurre cuando un reconocimiento ya ha revelado todas las zonas disponibles de un sector;
- si algunas zonas pueden cambiar, agotarse, desaparecer o transformarse por acciones del juego;
- si el conocimiento de mapa puede compartirse entre jugadores en el futuro.

Estas decisiones no cambian la premisa principal: **el mundo real es global y persistente, mientras que su generación es progresiva y su descubrimiento es individual por jugador**.
