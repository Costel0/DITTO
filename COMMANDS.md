# DITTO — Comandos del proyecto

Referencia rápida de los comandos administrativos y de despliegue disponibles actualmente.

> Los comandos que acceden directamente a Firebase usan las credenciales administrativas locales (`Application Default Credentials` / `GOOGLE_APPLICATION_CREDENTIALS`) y el proyecto por defecto de `.firebaserc`, salvo que se indique `--project=ID`.

## Mapa

Ejecutar desde la raíz del repositorio en Windows con `map.cmd`.

```powershell
.\map.cmd init
```
Inicializa el mapa y el índice de spawn con la configuración por defecto.

```powershell
.\map.cmd init --force
```
Borra el mapa existente y lo reconstruye desde cero. Es destructivo.

Opciones útiles:

```powershell
.\map.cmd init --force --max=50 --alpha=2
```
`--max` define el máximo numérico materializado inicialmente y `--alpha` controla cuánto favorece el spawn las posiciones cercanas a `M25`.

```powershell
.\map.cmd expand --max=80
```
Amplía el mapa hasta el número indicado sin regenerar lo ya existente.

```powershell
.\map.cmd add-players --count=100
```
Añade jugadores simulados uno a uno usando el mismo algoritmo de asignación del mapa. No crea cuentas de Firebase Auth.

```powershell
.\map.cmd download
```
Descarga el mapa actual a `functions/map_exports/latest_map.json`, sustituyendo la descarga anterior.

```powershell
.\map.cmd download --format=both
```
Genera/sustituye `latest_map.json` y `latest_map.csv`.

```powershell
.\map.cmd download --out=../mi_mapa --format=both
```
Exporta a una ruta/nombre específico cuando se quiere conservar una copia histórica.

```powershell
.\map.cmd render
```
Lee `latest_map.json`, genera/sustituye `latest_map.svg` y lo abre con el visor/navegador predeterminado. Es completamente local y no consume Firebase.

```powershell
.\map.cmd render --open=false
```
Genera la imagen sin abrirla.

```powershell
.\map.cmd set-sector --sector=H28 --type=HUNTING
```
Fuerza el tipo principal de un sector concreto. El sector queda `POPULATED` y sale del pool de spawn. No permite crear ni sobrescribir `PLAYER_BUNKER`.

```powershell
.\map.cmd set-zone --sector=H28 --zone=3 --type=LAKE
```
Fuerza el tipo de una zona concreta de un sector ya poblado. No permite sobrescribir la zona de bunker de un jugador. Si el sector todavía es `UNGENERATED`, primero hay que usar `set-sector`.

En PowerShell/Linux/macOS existen equivalentes:

```text
.\map.ps1 ...
bash ./map.sh ...
```

## Datos de usuarios

```powershell
.\users.cmd clear-data --confirm=DELETE
```
Borra recursivamente de Firestore toda la información bajo `users/{uid}` para todas las cuentas, incluidos estados, Survivors y subcolecciones.

**No borra las cuentas de Firebase Authentication.** Tampoco modifica el mapa compartido.

Para dejar un entorno de pruebas completamente limpio, normalmente se usarán ambos comandos:

```powershell
.\users.cmd clear-data --confirm=DELETE
.\map.cmd init --force
```

También existen:

```text
.\users.ps1 ...
bash ./users.sh ...
```

## Despliegue

```powershell
.\easy_deploy.cmd
```
Genera localizaciones, compila Flutter Web en release y despliega **solo Firebase Hosting**. Útil cuando no se han cambiado Functions/reglas/datos de servidor.

```powershell
.\hard_deploy.cmd
```
Flujo completo: instala dependencias exactas de Functions, valida catálogos, ejecuta tests de Functions y Flutter, ejecuta analyzer, compila Web, despliega Cloud Functions + reglas de Firestore, sincroniza datos públicos/privados y despliega Hosting.

```powershell
.\hard_deploy.cmd -ValidateOnly
```
Ejecuta toda la validación y los tests pero no modifica Firebase.

```powershell
.\hard_deploy.cmd -SkipHosting
```
Ejecuta el flujo completo de backend/datos omitiendo build y deploy de Hosting.

## Functions / npm

Desde `functions/`:

```bash
npm test
```
Ejecuta los tests Node de Cloud Functions y módulos backend.

```bash
npm run serve
```
Arranca emuladores de Functions y Firestore.

```bash
npm run deploy
```
Despliega Cloud Functions.

### Catálogo público de items

```bash
npm run sync:items:check
```
Valida qué cambiaría sin escribir en Firestore.

```bash
npm run sync:items
```
Sincroniza el catálogo sin borrar entradas extra.

```bash
npm run sync:items:exact
```
Sincroniza exactamente el catálogo y elimina entradas remotas que ya no estén definidas localmente.

### Datos privados del servidor

```bash
npm run sync:server-data:check
```
Valida la sincronización de configuración/datos privados sin escribir.

```bash
npm run sync:server-data
```
Sincroniza datos privados sin eliminar entradas extra.

```bash
npm run sync:server-data:exact
```
Sincroniza exactamente los datos privados y poda entradas remotas sobrantes.

### Aliases de administración

Desde `functions/` también se pueden usar directamente:

```bash
npm run map -- init
npm run map -- expand --max=80
npm run map -- add-players --count=100
npm run map -- download
npm run map -- render
npm run map:set-sector -- --sector=H28 --type=HUNTING
npm run map:set-zone -- --sector=H28 --zone=3 --type=LAKE
npm run users:clear-data -- --confirm=DELETE
```

Para uso habitual en Windows se recomienda preferir los wrappers de raíz (`map.cmd`, `users.cmd`, `easy_deploy.cmd`, `hard_deploy.cmd`) porque evitan tener que cambiar manualmente de directorio.
