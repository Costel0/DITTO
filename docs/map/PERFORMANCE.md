# DITTO — Rendimiento y escalabilidad del mapa

> Notas de rendimiento de la primera implementación del backend de mapa.
>
> Última actualización: 2026-09-11.

---

## 1. Principio esperado

La asignación de un nuevo `PLAYER_BUNKER` no debe depender del tamaño total histórico del mundo ni del número total de jugadores existentes.

El sistema consigue esto mediante dos propiedades:

1. la selección se realiza únicamente sobre el **pool de candidatos de la ventana de spawn activa**;
2. la comprobación autoritativa de separación mira únicamente las coordenadas enteras a distancia `<= minimumPlayerDistance` del candidato.

Con la configuración actual:

```text
spawn letters = D-W = 20 filas
ventana inicial = 10-40 = 31 columnas
ventanas posteriores = 40 columnas
minimumPlayerDistance = 2
```

el pool consultado por una asignación individual contiene como máximo aproximadamente:

```text
20 × 40 = 800 candidatos
```

independientemente de que el mundo tenga 80, 8.000 o 800.000 columnas materializadas.

La validación espacial del bunker consulta únicamente el vecindario local. Con distancia mínima `> 2`, existen 13 posiciones enteras a distancia `<= 2`, contando el propio sector. Por tanto, el número de sectores relevantes para validar una asignación es constante.

---

## 2. Optimización de `add-players`

La primera implementación correcta pero poco eficiente hacía, para cada jugador simulado:

```text
leer metadata
→ descargar de nuevo todo el pool activo
→ escoger candidato
→ abrir transacción
→ leer vecinos uno a uno
→ leer candidatos vecinos uno a uno
→ escribir
```

Esto hacía que un comando con `X` jugadores repitiese muchas lecturas de red innecesarias.

La versión optimizada mantiene exactamente el comportamiento **1 jugador = 1 transacción**, pero durante una misma ejecución de:

```text
map add-players --count=X
```

reutiliza en memoria:

- metadata estática de la ventana activa;
- documentos de candidatos de esa ventana.

Después de cada asignación se eliminan del cache local las coordenadas invalidadas por el bunker recién creado.

El pool se vuelve a descargar solamente cuando:

- cambia la ventana activa;
- una transacción detecta que el cache está obsoleto por concurrencia o por otro cambio inesperado.

Por tanto, añadir 100 jugadores ya no implica descargar aproximadamente cientos de candidatos 100 veces.

La selección continúa siendo secuencial. No se asignan varios jugadores en paralelo y cada jugador ve el pool resultante del jugador anterior.

---

## 3. Lecturas de la transacción de asignación

Las lecturas autoritativas necesarias se agrupan mediante `Transaction.getAll(...)` en lugar de solicitar documentos uno a uno.

La transacción comprueba:

- metadata actual;
- candidato elegido;
- sector elegido;
- sectores vecinos relevantes;
- excepcionalmente, candidatos inmediatamente fuera de la ventana activa que ya estén materializados.

Los candidatos vecinos dentro de la ventana activa no se vuelven a leer: el proceso ya conoce cuáles existían al cargar el pool.

Esto reduce especialmente la **latencia de red**, aunque el número lógico de documentos que deben comprobarse siga siendo pequeño y constante.

---

## 4. Expansión y borde entre ventanas

Una ampliación del mapa no debe volver a convertir en candidato una celda situada a `<= 2` de un bunker creado antes de que esa celda existiera.

Por ello, antes de crear nuevas columnas se inspecciona únicamente la franja final del mapa ya existente cuya anchura puede afectar a las nuevas celdas:

```text
ceil(minimumPlayerDistance)
```

Con la configuración actual son las últimas **2 columnas**, es decir, como máximo:

```text
26 × 2 = 52 sectores
```

Esta comprobación es constante respecto al número total de jugadores y al tamaño histórico del mundo.

---

## 5. Complejidad por operación

### Asignar un único jugador real

Respecto al tamaño global del mapa:

```text
O(1) acotado por el tamaño de la ventana activa
```

La consulta del pool devuelve como máximo aproximadamente 800 documentos con la configuración actual. El número total de jugadores fuera de esa ventana no interviene.

En la práctica, una asignación individual seguirá teniendo latencia de Firestore porque requiere una consulta y una transacción remotas.

### `add-players --count=X`

```text
O(X)
```

Debe crecer aproximadamente de forma lineal con **el número de jugadores que se pide crear**, porque deliberadamente se crea uno, se persiste, se modifica el pool y solo entonces se crea el siguiente.

No debería crecer adicionalmente por el número histórico de jugadores ni por el tamaño global del mapa.

Dentro de una misma ventana, el pool se descarga una vez y se reutiliza.

### Inicializar mapa

Para un mapa de 26 filas y `N` columnas:

```text
O(26 × N)
```

Es inevitable: hay que crear físicamente cada sector materializado y los candidatos correspondientes.

Las escrituras se procesan por lotes y ya no se acumula en memoria una lista proporcional al mapa completo.

### Ampliar mapa

Si se añaden `ΔN` nuevas columnas:

```text
O(26 × ΔN)
```

El coste depende de **cuánto se amplía**, no de cuánto mide previamente el mapa.

Además se consultan como máximo las últimas `ceil(minimumPlayerDistance)` columnas existentes para proteger el borde frente a bunkers cercanos.

### Resolver/descubrir un sector

```text
O(1)
```

Se modifica un único sector y se retira su entrada del pool si existe.

No es necesario recorrer el mapa ni otros jugadores.

### Descargar mapa completo

```text
O(total de sectores materializados + total de candidatos)
```

Esta operación **sí empeora necesariamente conforme crece el mundo**, porque su objetivo es precisamente descargar una representación completa del mapa actual.

La exportación de candidatos solicita únicamente sus referencias/IDs, ya que no necesita volver a descargar sus campos internos.

### Render local

```text
O(total de sectores descargados)
```

Es una operación local y normalmente barata, pero un SVG que representa cada celda individual crecerá proporcionalmente al tamaño del mapa.

### `init --force`

Además de reconstruir el mapa, primero elimina las colecciones existentes. Por ello su tiempo depende también del tamaño del mapa anterior.

---

## 6. Qué NO debería empeorar al crecer el servidor

Con la arquitectura actual, estos factores no deberían hacer cada vez más lenta la asignación normal de un jugador:

- que existan miles de jugadores en ventanas antiguas;
- que el eje numérico materializado llegue a valores muy altos;
- que existan muchos sectores poblados lejos de la ventana activa.

La asignación trabaja sobre la ventana activa y sobre un vecindario local fijo.

Sí puede existir una pequeña variación por:

- latencia normal de Firestore;
- reintentos de transacción por concurrencia;
- una ventana de spawn muy vacía o con entradas obsoletas;
- cambio de ventana, porque puede requerir ampliar primero el mapa.

---

## 7. Decisiones que podrían afectar al rendimiento futuro

Si en el futuro se aumenta mucho:

```text
subsequentSpawnWindowSize
```

o se amplía considerablemente la banda `D-W`, la consulta del pool de una asignación individual crecerá con ese rectángulo.

Por ejemplo, el comportamiento actual está acotado porque una ventana posterior tiene unas 800 celdas posibles. Una ventana de 1.000 columnas tendría hasta 20.000 candidatos y ya justificaría otra estructura de selección ponderada.

Mientras mantengamos ventanas de decenas de columnas, no hace falta esa complejidad adicional.

---

## 8. Conclusión

La implementación actual diferencia deliberadamente entre:

- operaciones **locales** del mapa, cuyo coste no depende del mundo completo;
- operaciones **globales** como exportar o materializar celdas, que necesariamente son proporcionales a la cantidad de datos procesada.

La creación de un bunker pertenece al primer grupo. El crecimiento del mundo y de la población histórica no debe convertir progresivamente el alta normal de un jugador en una operación más costosa.
