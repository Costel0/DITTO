# Flujo después de modificar `game_data`

Guía rápida de comandos para validar y publicar cambios en los JSON de configuración.

Los comandos se ejecutan desde la raíz del repositorio DITTO.

## Despliegues rápidos

### Hard deploy: validar y desplegar todo

```powershell
.\hard_deploy.cmd
```

Ejecuta, en este orden:

```text
1. comprobaciones previas de Git y herramientas
2. npm ci en functions/
3. validación de items.json
4. validación de todos los JSON privados de game_data/server/
5. tests de Cloud Functions
6. tests de Flutter
7. flutter analyze
8. build release de Flutter Web
9. deploy de Cloud Functions + reglas de Firestore
10. sincronización exacta de items.json
11. sincronización exacta de game_data/server/
12. deploy de Firebase Hosting
```

Si un comando devuelve un error, el script se detiene inmediatamente y no ejecuta ningún paso posterior.

La fase de validación se completa antes de modificar Firebase. Los despliegues de Functions, Firestore, datos y Hosting son servicios separados y no forman una transacción atómica; por eso el orden es conservador.

También puede usarse directamente el PowerShell:

```powershell
.\hard_deploy.ps1
```

#### Solo validar, sin desplegar

```powershell
.\hard_deploy.cmd -ValidateOnly
```

Ejecuta todas las comprobaciones y el build web, pero no modifica Firebase.

#### Desplegar sin Hosting

```powershell
.\hard_deploy.cmd -SkipHosting
```

Valida y despliega backend, reglas y datos, pero omite el build y despliegue de Hosting.

El script permite cambios locales sin commit, aunque mostrará una advertencia. Sí bloquea el despliegue si existen conflictos Git sin resolver.

### Easy deploy: actualizar solo la web

```powershell
.\easy_deploy.cmd
```

Hace únicamente:

```text
1. flutter build web --release
2. firebase deploy --only hosting
```

No ejecuta tests ni analyzer y no toca:

- Cloud Functions;
- reglas de Firestore;
- `items.json`;
- `game_data/server/`;
- ningún dato de Firestore.

Si el build web falla, Hosting no se despliega.

También puede usarse directamente:

```powershell
.\easy_deploy.ps1
```

---

## 1. Si has modificado `game_data/items.json`

```powershell
cd functions
npm run sync:items:check
```

Si la validación termina correctamente, publica el catálogo:

```powershell
npm run sync:items:exact
```

Qué hace cada comando:

- `sync:items:check`: valida el JSON sin modificar Firestore.
- `sync:items:exact`: sincroniza `items.json` con `/items` y elimina del catálogo remoto los objetos que ya no existan en el JSON local.

No hace falta desplegar Cloud Functions ni Hosting si únicamente has cambiado datos compatibles de `items.json`.

---

## 2. Si has modificado cualquier JSON de `game_data/server/`

Incluye actualmente:

```text
job_tasks.json
loot_tables.json
server_config.json
```

Primero valida todos los datos privados:

```powershell
cd functions
npm run sync:server-data:check
```

Después ejecuta los tests del backend:

```powershell
npm test
```

Si ambos comandos terminan correctamente, publica la configuración:

```powershell
npm run sync:server-data:exact
```

Qué hace cada comando:

- `sync:server-data:check`: valida los JSON privados sin escribir en Firestore.
- `npm test`: comprueba la lógica de Functions relacionada con estas estructuras.
- `sync:server-data:exact`: sincroniza los archivos de `game_data/server/` con `/serverData/*` y elimina documentos remotos que ya no tengan un JSON local correspondiente.

No hace falta desplegar Cloud Functions si solo has cambiado valores o entradas que el backend actual ya entiende.

---

## 3. Si el cambio del JSON introduce una estructura nueva

Ejemplos:

- añadir un nuevo tipo de `resultResolver`;
- añadir un campo nuevo que necesita código para funcionar;
- definir por primera vez la estructura real de `lootTables`;
- cambiar el significado de un campo existente.

En ese caso hay que modificar primero el backend para que entienda tanto el estado anterior como el nuevo cuando sea necesario.

La opción recomendada es:

```powershell
.\hard_deploy.cmd
```

El orden interno garantiza que Functions se despliegue antes de publicar el nuevo formato de `serverData`.

Si se hace manualmente:

```powershell
cd functions
npm run sync:server-data:check
npm test
npm run deploy
npm run sync:server-data:exact
```

---

## 4. Si solo has modificado Flutter y quieres actualizar la web

La opción rápida es:

```powershell
.\easy_deploy.cmd
```

Manual equivalente:

```powershell
flutter build web --release
firebase deploy --only hosting
```

Para probar localmente antes:

```powershell
flutter run -d chrome
```

---

## Resumen rápido

### Todo: validar + desplegar backend, datos y web

```powershell
.\hard_deploy.cmd
```

### Solo comprobar que todo está listo

```powershell
.\hard_deploy.cmd -ValidateOnly
```

### Solo actualizar la web de Hosting

```powershell
.\easy_deploy.cmd
```

### Solo `items.json`

```powershell
cd functions
npm run sync:items:check
npm run sync:items:exact
```

### Solo configuración de `game_data/server/`

```powershell
cd functions
npm run sync:server-data:check
npm test
npm run sync:server-data:exact
```

## Importante

No uses `sync:*:exact` si el comando `sync:*:check` ha fallado.

Los documentos de `/serverData` son privados y no deben convertirse en datos de cliente. Las probabilidades, reglas ocultas y parámetros autoritativos deben permanecer en `game_data/server/`.
