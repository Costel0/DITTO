# DITTO — Sistema de mapa y coordenadas

> Documento de diseño inicial. Describe el modelo conceptual del mapa, sus coordenadas, la generación de sectores, las distancias y la diferencia entre el estado real del mundo y la información conocida por cada jugador.
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

**geometría global predefinida + contenido de sectores generado bajo demanda + conocimiento parcial por jugador + distancias calculadas a nivel de sector**.

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

El jugador interactúa realmente con **zonas**, mientras que el sector sirve como agrupación geográfica, unidad espacial para calcular distancias y contexto para las reglas de generación.

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

Las otras zonas del sector se resuelven respetando las reglas asociadas a `PLAYER_BUNKER`.

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

Por tanto, el **tipo de sector no significa que todas sus zonas sean del mismo tipo**. Es el arquetipo que determina la composición permitida y, cuando corresponda, las probabilidades de generación de sus zonas internas.

---

## 5. El mapa no se puebla completamente al crear el servidor

El backend conoce de entrada:

- dimensiones y límites del mapa;
- coordenadas válidas;
- número de zonas por sector;
- tipos de sector posibles;
- tipos de zona posibles;
- reglas de compatibilidad;
- probabilidades y reglas de generación;
- reglas de cálculo de distancias.

Pero un sector que nunca haya sido necesario puede permanecer **sin poblar**.

Conceptualmente, un sector puede encontrarse al menos en uno de estos estados:

```text
UNGENERATED
POPULATED
```

### `UNGENERATED`

El sector existe como posición válida del mapa, pero el servidor todavía no ha decidido qué localizaciones concretas contiene.

### `POPULATED`

El servidor ya ha generado su composición interna completa. Desde ese momento esa composición forma parte del estado persistente del mundo y no vuelve a sortearse en reconocimientos posteriores.

Esto significa que el mapa se genera de forma **lazy / on demand**.

---

## 6. Creación de una nueva cuenta y sector de jugador

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
Resolver TODAS las zonas del sector
   ↓
Persistir el sector completo
   ↓
Revelar al jugador únicamente la información inicial permitida
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

### 6.1 El sector se resuelve por completo en el momento de asignarlo

Esta regla queda fijada como parte del diseño:

**cuando un sector se asigna a un jugador, el backend genera inmediatamente la composición completa del sector y la persiste.**

No se dejan zonas internas del sector del jugador pendientes para un reconocimiento futuro.

Por ejemplo, el backend podría resolver internamente:

```text
B12-1 = RUINS
B12-2 = HUNTING
B12-3 = PLAYER_BUNKER(player_123)
B12-4 = EMPTY
B12-5 = ABANDONED_BUILDING
```

Sin embargo, que el backend conozca el sector completo **no significa que el jugador lo conozca**. Inicialmente el jugador puede conocer solamente:

```text
B12-3 = MY_BUNKER
```

El resto de zonas permanecen ocultas hasta que alguna mecánica del juego las revele.

### 6.2 Equidad de los sectores de jugador

Los sectores `PLAYER_BUNKER` constituyen la posición inicial de cada jugador y, por tanto, su composición no debe introducir una ventaja o desventaja importante basada simplemente en suerte al crear la cuenta.

Por este motivo, los sectores de jugador **no utilizarán un rate aleatorio de “zonas buenas”** comparable al que puedan utilizar otros tipos de sector.

No queremos que un jugador empiece rodeado de varias localizaciones excepcionalmente beneficiosas mientras otro recibe un sector inicial pobre únicamente por una tirada aleatoria del backend.

Las reglas concretas de composición de `PLAYER_BUNKER` se definirán más adelante, pero deberán buscar una **calidad y valor inicial equivalentes entre jugadores**. Esto puede conseguirse mediante composiciones fijas, grupos equivalentes de zonas o reglas de balance específicas.

La aleatoriedad puede utilizarse para aportar variedad visual o temática siempre que no produzca diferencias materiales relevantes en las oportunidades iniciales.

---

## 7. Reconocimiento de un sector todavía no poblado

Una misión de reconocimiento puede apuntar a un sector cuyo contenido todavía no haya sido generado.

Cuando la misión se complete:

```text
Reconocimiento de C12
   ↓
¿C12 está poblado?
   ↓ no
Generar TODAS las zonas de C12 usando las reglas del mapa
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

Si un jugador, la creación de una cuenta o cualquier otro evento ya provocó anteriormente la generación de ese sector, el backend **no vuelve a generar nada**.

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

Esto se aplica también al propio sector inicial: **el backend conoce todas las zonas del sector del jugador desde la creación de la cuenta, pero el jugador no tiene por qué conocerlas**.

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

Para `PLAYER_BUNKER`, la reserva del sector, la asignación del bunker y la resolución de la composición completa deben tratarse como una única operación lógica segura frente a concurrencia.

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
- reglas de balance;
- número de zonas del sector.

Ejemplo conceptual, no definitivo:

```text
PLAYER_BUNKER
- exactamente 1 PLAYER_BUNKER
- 0 bunkers adicionales de jugador
- todas las zonas se resuelven al crear/asignar el jugador
- composición equilibrada respecto a otros PLAYER_BUNKER
- sin una tirada de calidad que pueda generar grandes ventajas iniciales

HUNTING
- al menos 1 HUNTING
- puede contener varias HUNTING
- puede coexistir con ABANDONED_BUNKER
- puede coexistir con LAKE
- puede utilizar pesos/probabilidades propios
```

Estas reglas determinarán la composición interna cuando un sector se genere por primera vez.

---

## 12. Sistema de distancias

Las distancias del mapa se expresarán mediante **unidades decimales de distancia**.

La distancia normal entre sectores se calcula exclusivamente a partir de las dos coordenadas 2D del sector. El índice de zona (`-1`, `-2`, `-3`, etc.) **no interviene en la distancia entre sectores diferentes**.

### 12.1 Distancia ortogonal entre sectores

Dos sectores contiguos horizontal o verticalmente están separados por exactamente:

```text
1.0 unidad
```

Ejemplos:

```text
B11 -> C11 = 1.0
B11 -> B12 = 1.0
```

### 12.2 Distancia diagonal y triangulación

Para sectores que difieren en ambos ejes se utiliza la distancia euclídea:

```text
d = sqrt((Δx)^2 + (Δy)^2)
```

Por ejemplo:

```text
B11 -> C12
Δx = 1
Δy = 1

d = sqrt(1² + 1²)
  = sqrt(2)
  ≈ 1.4142
```

No se utiliza una distancia de tablero basada en número de casillas recorridas. El desplazamiento diagonal conserva la geometría 2D real del mapa.

### 12.3 Conversión de la coordenada alfabética

Para realizar los cálculos, las letras del eje se interpretan como posiciones consecutivas separadas por una unidad.

Conceptualmente:

```text
A -> 0
B -> 1
C -> 2
D -> 3
...
```

El valor inicial concreto (`A = 0` o `A = 1`) es irrelevante para las distancias, siempre que la diferencia entre letras consecutivas sea `1`.

Si en el futuro se utilizan coordenadas como `AA`, `AB`, etc., deberán continuar la misma secuencia numérica.

### 12.4 Las zonas no alteran la distancia entre sectores distintos

Todas las zonas de un sector comparten la misma posición espacial a efectos de distancia externa.

Por tanto:

```text
B11-1 -> C12-1 = sqrt(2)
B11-1 -> C12-5 = sqrt(2)
B11-4 -> C12-2 = sqrt(2)
```

Las tres distancias son exactamente iguales.

De la misma forma, **todas las zonas de `H27` están a la misma distancia de todas las zonas de `J3`**.

El índice de zona no añade ni resta distancia cuando origen y destino pertenecen a sectores distintos.

### 12.5 Distancia dentro de un mismo sector

Dos zonas diferentes pertenecientes al mismo sector tienen siempre una distancia fija de:

```text
0.1 unidades
```

Por ejemplo:

```text
B12-1 -> B12-2 = 0.1
B12-1 -> B12-3 = 0.1
B12-1 -> B12-5 = 0.1
B12-4 -> B12-5 = 0.1
```

No existe una geometría interna que haga que una zona esté más cerca de otra que una tercera. Las zonas internas son localizaciones discretas del sector, no puntos adicionales de la cuadrícula global.

Una localización comparada consigo misma tiene, naturalmente:

```text
B12-3 -> B12-3 = 0
```

### 12.6 Regla completa de distancia entre zonas

Para dos coordenadas completas `A` y `B`:

```text
si A == B:
    distancia = 0

si sector(A) == sector(B) y zona(A) != zona(B):
    distancia = 0.1

si sector(A) != sector(B):
    distancia = sqrt((xB - xA)^2 + (yB - yA)^2)
```

Esta función debe ser la referencia única para cualquier sistema futuro que dependa de distancia: viajes, duración de expediciones, consumo de recursos, rango de reconocimiento, eventos o cualquier otra mecánica espacial.

---

## 13. Invariantes del sistema

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
11. Al asignar un sector `PLAYER_BUNKER`, todas sus zonas se generan y persisten inmediatamente.
12. Que el backend haya generado una zona no implica que el jugador la conozca.
13. Los sectores iniciales de jugador deben evitar diferencias materiales de calidad producidas por azar.
14. La distancia entre sectores distintos depende únicamente de las coordenadas 2D de sector.
15. El índice de zona nunca modifica la distancia entre sectores distintos.
16. Dos zonas distintas del mismo sector están siempre a `0.1` unidades entre sí.
17. Una localización respecto a sí misma tiene distancia `0`.

---

## 14. Ejemplo completo

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

### Paso 2 — resolución inmediata del sector completo

En la misma operación lógica de asignación, el backend genera todas las zonas de `B12` siguiendo las reglas equilibradas de `PLAYER_BUNKER`.

Una composición conceptual podría ser:

```text
B12-1 = RUINS
B12-2 = HUNTING
B12-3 = PLAYER_BUNKER(player_A)
B12-4 = EMPTY
B12-5 = ABANDONED_BUILDING
```

Esta composición queda persistida inmediatamente.

El jugador A, sin embargo, puede conocer inicialmente únicamente:

```text
B12-3 = MY_BUNKER
```

### Paso 3 — otro jugador reconoce B12

El backend ya conoce el layout y no genera uno nuevo.

La misión podría descubrir únicamente:

```text
B12-5 = ABANDONED_BUILDING
```

El jugador B conoce ahora esa zona, pero no necesariamente `B12-1`, `B12-2`, `B12-3` o `B12-4`.

### Paso 4 — cálculo de distancia

Si se quiere viajar desde:

```text
B12-3 -> C13-1
```

las zonas `3` y `1` no intervienen porque los sectores son diferentes.

```text
Δx = 1
Δy = 1

d = sqrt(2)
  ≈ 1.4142
```

En cambio, un desplazamiento interno:

```text
B12-3 -> B12-5
```

tiene siempre:

```text
d = 0.1
```

La exploración amplía el **conocimiento**, no recrea el **mundo**.

---

## 15. Modelo conceptual de datos

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

DISTANCE RULES
    conversión de coordenadas y cálculo único de distancias
```

No se debe guardar el layout oculto dentro de un documento que el cliente pueda leer directamente si las reglas de Firestore permiten obtenerlo completo.

La revelación de mapa debería producirse a través de lógica autoritativa de backend.

El cálculo de distancia debería centralizarse en una única utilidad del backend/dominio para evitar que distintas mecánicas terminen implementando fórmulas diferentes.

---

## 16. Decisiones todavía abiertas

Este documento fija la arquitectura conceptual, pero todavía quedan decisiones que se pueden concretar al implementar:

- dimensiones exactas del mapa;
- si el mapa es finito, ampliable o dividido en regiones;
- número definitivo de zonas por sector;
- formato interno de las coordenadas frente al formato visual `B12-3`;
- convención de letras después de `Z` si el eje lo necesita;
- lista inicial de tipos de sector;
- lista inicial de tipos de zona;
- reglas y pesos de generación de cada tipo de sector no inicial;
- composición o sistema de equivalencia exacto que garantice el balance de los sectores `PLAYER_BUNKER`;
- criterio para elegir sectores de nuevos jugadores y distancia entre ellos;
- qué ocurre cuando un reconocimiento ya ha revelado todas las zonas disponibles de un sector;
- si algunas zonas pueden cambiar, agotarse, desaparecer o transformarse por acciones del juego;
- si el conocimiento de mapa puede compartirse entre jugadores en el futuro;
- precisión y redondeo utilizado al mostrar distancias al jugador, manteniendo internamente el cálculo sin redondeos prematuros.

Estas decisiones no cambian las premisas principales: **el mundo real es global y persistente, su generación es progresiva, los sectores de jugador se resuelven completamente al asignarse, su descubrimiento es individual por jugador y las distancias se calculan sobre la cuadrícula de sectores**.