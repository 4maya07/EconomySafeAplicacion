# Despliegue de EconomySafe en GitHub Pages

Este documento resume el proceso operativo para construir y publicar la versión web en GitHub Pages, además de acciones de contingencia si ocurre un fallo.

## Requisitos previos
- Flutter SDK 3.24+ instalado y en la ruta `PATH`.
- Acceso al repositorio `4maya07/EconomySafeAplicacion` con permisos de escritura.
- Autenticación de Git configurada (token o SSH).

## Pasos de despliegue manual
1. Verifica que el entorno esté limpio:
   ```powershell
   git status -sb
   ```
   Asegúrate de no tener cambios sin guardar o guárdalos con un commit/stash.
2. Construye la versión web con el `base-href` correcto para GitHub Pages:
   ```powershell
   flutter clean
   flutter build web --release --base-href /EconomySafeAplicacion/
   ```
3. Cambia a la rama `gh-pages` y limpia los artefactos previos:
   ```powershell
   git checkout gh-pages
   Get-ChildItem -Force | Where-Object { $_.Name -notin '.git','build','.gitignore' } | Remove-Item -Recurse -Force
   ```
4. Copia el contenido generado a la raíz de `gh-pages`:
   ```powershell
   Copy-Item -Recurse -Path ..\build\web\* -Destination . -Force
   Remove-Item -Recurse -Force ..\build
   ```
5. Publica los cambios:
   ```powershell
   git add .
   git commit -m "Deploy web build"
   git push origin gh-pages
   ```
6. Regresa a la rama de desarrollo y recupera tus cambios guardados si usaste `stash`:
   ```powershell
   git checkout main
   git stash pop   # Solo si hiciste stash
   ```
7. Espera unos minutos a que GitHub Pages regenere el sitio y verifica en:
   `https://4maya07.github.io/EconomySafeAplicacion/`

## Verificaciones posteriores
- Recargar la aplicación con `Ctrl+Shift+R` (Windows) o `Cmd+Shift+R` (macOS) para forzar la actualización del service worker.
- Abrir la consola del navegador y confirmar que no hay errores 404 ni bloqueos de red.
- Probar el flujo de recuperación de contraseña desde un enlace enviado por Supabase.

## Plan de contingencia
- **Página en blanco o recursos 404**: ejecutar `flutter build web --release --base-href /EconomySafeAplicacion/` y desplegar de nuevo. Limpiar caché y service worker (en Chrome: `chrome://serviceworker-internals` > unregister).
- **Service worker viejo**: incrementar el número de versión del build (`flutter clean` + rebuild) y pedir a los usuarios recargar forzadamente.
- **URL de recuperación inválida**: revisar en `lib/datos/supabase/auth_repositorio.dart` que `redirectTo` apunte a `https://4maya07.github.io/EconomySafeAplicacion/#/recuperar` y volver a enviar el correo.
- **Fallo del build**: ejecutar `flutter doctor` para validar el entorno y reinstalar dependencias con `flutter pub get`.

## Próximos pasos sugeridos
- Automatizar el despliegue con GitHub Actions usando el mismo comando de build y publicación.
- Documentar pruebas manuales mínimas (login, PIN, recuperación) antes de cada despliegue.
