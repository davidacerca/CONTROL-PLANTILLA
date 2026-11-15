# ACERCA – Gestión interna

Aplicación administrativa privada publicada con GitHub Pages y conectada a Supabase. Las personas trabajadoras no tienen cuentas de acceso.

## Acceso y configuración

- El acceso usa Supabase Auth con correo y contraseña. No hay registro público.
- `supabase-config.js` contiene la URL del proyecto y su clave Publishable. Nunca añadas una clave `service_role` ni otra clave secreta al repositorio.
- La función `public.is_acerca_admin()` y las políticas RLS autorizan las operaciones administrativas.
- Las páginas públicas de GitHub Pages muestran el acceso; los datos se leen solo después de validar la sesión y la autorización del administrador.

## Base de datos

En una instalación nueva, crea primero `public.workers` con `supabase/workers.sql` y ejecuta después `supabase/acerca-modules.sql` desde Supabase SQL Editor. El segundo script es idempotente y conserva los registros existentes. Activa RLS y aplica políticas antes de usar la aplicación.

El esquema incluye sociedades editables, trabajadores, vacaciones, permisos y ausencias, incidencias, partners, horas extra y pagos. Las fichas de trabajadores no se borran desde el cliente; se marca la fecha de baja para conservar el historial.

## Publicación

El workflow `.github/workflows/deploy.yml` publica la rama `main` en GitHub Pages. La aplicación se sirve desde:

`https://davidacerca.github.io/CONTROL-PLANTILLA/`

## Alcance actual

La autenticación, las políticas de las tablas existentes y la publicación están configuradas. Trabajadores y vacaciones están en desarrollo funcional. Revisa cada módulo contra los requisitos antes de utilizarlo con datos laborales reales; las reglas del bono y otras condiciones pendientes aún necesitan definición.
