# Paquete de personalización para Boy172/P-Slice-fork

Este paquete añade un flujo de trabajo de GitHub Actions para:
- copiar archivos Haxe personalizados a `source/`;
- aplicar parches `.patch`;
- ejecutar scripts Bash personalizados;
- compilar Android;
- guardar el APK y el registro de compilación como artefactos;
- opcionalmente guardar los cambios aplicados en `source/` en la rama actual.

## Instalación

1. Descomprime este paquete en la raíz de `Boy172/P-Slice-fork`.
2. Combina las carpetas del paquete con las del repositorio.
3. Sube los archivos y carpetas a la rama `master`.
4. En GitHub abre **Actions** y ejecuta **P-Slice Custom Android Build**.
5. Descarga `P-Slice-Android-*` al finalizar.

## Cómo añadir modificaciones

### Archivos Haxe o recursos fuente
Pon cada archivo dentro de `custom/source/` respetando la ruta que debe tener dentro de `source/`.

Ejemplo:
`custom/source/funkin/graphics/framebuffer/SpriteCopy.hx`

El script lo copiará a:
`source/funkin/graphics/framebuffer/SpriteCopy.hx`

### Parches
Coloca parches Git `.patch` en `custom/patches/`. Se aplican en orden alfabético.

### Scripts
Coloca scripts Bash `.sh` en `custom/scripts/`. Se ejecutan en orden alfabético después de copiar los archivos y aplicar los parches.

## Guardar cambios en el repositorio

Al ejecutar manualmente el Workflow, puedes activar:
**Guardar los cambios aplicados dentro de source/ en la rama actual**.

Por defecto está desactivado. Si lo activas, el Workflow necesita permiso de escritura y creará un commit en la rama que ejecutó el Workflow.

## Importante

- El APK solo se considera generado si el paso de compilación termina correctamente y se encuentra un `.apk` dentro de `export/`.
- Este paquete usa el setup documentado por el repositorio (`setup/Unix.sh`) cuando no existe `hmm.json`. Si la configuración de dependencias de tu rama cambia, habrá que adaptar ese paso.
- Los seis archivos Haxe incluidos se copian como archivos fuente; este paquete no garantiza que compilen sin ajustes. La compilación de Actions será la prueba de compatibilidad real con las versiones de Haxe, OpenFL, Flixel y FlxAnimate instaladas por el fork.
- Revisa el registro `android-build.log` si la compilación falla.
