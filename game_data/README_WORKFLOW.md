# Flujo después de modificar `game_data`

Guía rápida de comandos para validar y publicar cambios en los JSON de configuración.

Los comandos se ejecutan desde el repositorio DITTO.

## Flujo completo recomendado: un solo comando

Desde la raíz del repositorio puedes validar y desplegar todo con:

```powershell
.\deploy.ps1
```

El script ejecuta, en este orden:

```text
1. comprobaciones previas de Git y herramientas
2. validación de items.json
3. validación de todos los JSON privados de game_data/server/
4. tests de Cloud Functions
5. tests de Flutter
6. flutter analyze
7. build release de Flutter Web
8. deploy de Cloud Functions + reglas de Firestore
9. sincronización exacta de items.json
10. sincronización exacta de game_data/server/
11. deploy de Firebase Hosting
```

Si un comando devuelve un error, el script se detiene inmediatamente y no ejecuta ningún paso posterior.

La fase de validación se completa **antes de modificar Firebase**. De esta forma, un fallo de tests, del analyzer, de los JSON o del build web impide que comience el despliegue.

Los despliegues de Functions, Firestore, datos y Hosting son servicios separados y no forman una transacción atómica. Por eso el orden es conservador: primero se despliega un backend capaz de entender los datos nuevos, después se sincronizan los datos y Hosting queda para el final.

### Solo validar, sin desplegar

```powershell
.\deploy.ps1 -ValidateOnly
```

Ejecuta todas las comprobaciones y el build web, pero no modifica Firebase.

### Desplegar sin reconstruir ni actualizar Hosting

```powershell
.\deploy.ps1 -SkipHosting
```

Valida y despliega backend, reglas y datos, pero omite `flutter build web` y el deploy de Hosting.

El script permite cambios locales sin commit porque durante desarrollo puede ser útil desplegar el working tree actual, pero mostrará una advertencia. En cambio, bloquea el despliegue si existen conflictos Git sin resolver.

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

No hace falta desplegar Cloud Functions si solo has cambiado **valores o entradas que el backend actual ya entiende**.

---

## 3. Si el cambio del JSON introduce una estructura nueva

Ejemplos:

- añadir un nuevo tipo de `resultResolver`;
- añadir un campo nuevo que necesita código para funcionar;
- definir por primera vez la estructura real de `lootTables`;
- cambiar el significado de un campo existente.

En ese caso hay que modificar primero el backend para que entienda tanto el estado anterior como el nuevo cuando sea necesario.

Flujo recomendado:

```powershell
cd functions
npm run sync:server-data:check
npm test
npm run deploy
npm run sync:server-data:exact
```

Es decir:

```text
1. validar JSON
2. probar backend
3. desplegar backend compatible
4. publicar los nuevos datos
```

Así se evita subir a Firestore un formato que las Functions desplegadas todavía no sepan interpretar.

---

## 4. Si también has modificado Flutter

Antes de probar o desplegar la app:

```powershell
cd ..
flutter test
flutter analyze
```

Para probar en Chrome:

```powershell
flutter run -d chrome
```

Si quieres actualizar el Hosting web:

```powershell
flutter build web
firebase deploy --only hosting
```

---

## Resumen rápido

### Todo: validar + desplegar backend, datos y web

```powershell
.\deploy.ps1
```

### Solo comprobar que todo está listo

```powershell
.\deploy.ps1 -ValidateOnly
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

### Cambio de estructura que requiere código nuevo en Functions

```powershell
cd functions
npm run sync:server-data:check
npm test
npm run deploy
npm run sync:server-data:exact
```

## Importante

No uses `sync:*:exact` si el comando `sync:*:check` ha fallado.

Los documentos de `/serverData` son privados y no deben convertirse en datos de cliente. Las probabilidades, reglas ocultas y parámetros autoritativos deben permanecer en `game_data/server/`.
