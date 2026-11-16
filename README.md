# Full Cleaner · Gestión interna

App web interna de Full Cleaner: registro del personal (Bodegas San Francisco y Kovacs), entregas de ropa y EPP con firma digital, y gastos por factura.

- **App:** un solo archivo, `index.html` (HTML + CSS + JavaScript, sin compilación). Se publica con GitHub Pages.
- **Datos y usuarios:** Supabase (base de datos Postgres, inicio de sesión con correo y contraseña, y almacenamiento privado para las fotos de las facturas).
- **Estructura de la base de datos:** `supabase/setup.sql`.

Este repositorio no contiene datos de trabajadores ni de facturas: esos viven en Supabase y solo los ven usuarios con sesión iniciada.

## Agregar un usuario
En Supabase: **Authentication → Users → Add user → Create new user**, con correo y contraseña, y marcando **Auto Confirm User**. Luego la persona puede cambiar su contraseña en **Ajustes** dentro de la app.
