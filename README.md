# ACERCA – Gestión interna

Aplicación administrativa privada publicada con GitHub Pages y conectada a Supabase. Las personas trabajadoras no tienen cuentas de acceso.

## Acceso y configuración

- El acceso usa Supabase Auth con correo y contraseña. No hay registro público.
- `supabase-config.js` contiene la URL del proyecto y su clave Publishable. Nunca añadas una clave `service_role` ni otra clave secreta al repositorio.
- La función `public.is_acerca_admin()` y las políticas RLS autorizan las operaciones administrativas.
- Las páginas públicas de GitHub Pages muestran el acceso; los datos se leen solo después de validar la sesión y la autorización del administrador.

## Base de datos

En una instalación nueva, crea primero `public.workers` con `supabase/workers.sql`, ejecuta después `supabase/acerca-modules.sql` y finalmente `supabase/acerca-payroll-analysis.sql` desde Supabase SQL Editor. Los scripts son idempotentes y conservan los registros existentes. La aplicación requiere las políticas RLS activas.

El esquema incluye sociedades editables, trabajadores, vacaciones, permisos y ausencias, incidencias, partners, horas extra y pagos. Las fichas de trabajadores no se borran desde el cliente; se marca la fecha de baja para conservar el historial. Los periodos de vacaciones sí se pueden eliminar desde su detalle, con confirmación.

Los pagos previstos por primera nómina mensual completa se generan una sola vez. La persona debe estar activa hasta el último día del mes. El pago de formación se muestra sin cuantía; cada incentivo Partner es de 100 €. Los pagos aparecen en Pagos adicionales por su mes de nómina y se pueden marcar abonados al cierre del mes.

El apartado Análisis permite filtrar registros por fechas, área y sociedad, seleccionar campos y usar la opción de impresión del navegador para guardar el informe en PDF.

La importación de trabajadores busca encabezados compatibles en todas las hojas del Excel, acepta fechas de Excel y fechas de texto en formato español o estadounidense, detecta duplicados y permite asignar sociedades nuevas o con otro nombre al catálogo antes de guardar. La navegación agrupa las áreas de personas y pagos, manteniendo sus datos y operaciones en las pestañas de cada área.

## Publicación

El workflow `.github/workflows/deploy.yml` publica la rama `main` en GitHub Pages. La aplicación se sirve desde:

`https://davidacerca.github.io/CONTROL-PLANTILLA/`

## Alcance actual

La autenticación, las políticas de datos, la gestión de trabajadores, vacaciones y pagos previstos están configuradas. Los informes usan los datos del sistema. Revisa los módulos de permisos, incidencias y gestión económica contra los requisitos internos antes de utilizarlos como fuente de decisiones laborales o contables.
