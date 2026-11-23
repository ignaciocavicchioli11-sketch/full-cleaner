-- =====================================================================
-- Full Cleaner · Gestión interna — estructura de la base de datos
-- Se ejecuta una sola vez en un proyecto nuevo de Supabase.
-- Solo usuarios con sesión iniciada (creados por el administrador)
-- pueden leer o modificar datos.
-- =====================================================================

-- ---------- Ajustes generales (listas de prendas, categorías, etc.) ----------
create table if not exists public.config (
  id          text primary key,
  data        jsonb not null default '{}'::jsonb,
  actualizado timestamptz default now()
);

-- ---------- Trabajadores ----------
create table if not exists public.trabajadores (
  id            text primary key,
  nombre        text not null,
  rut           text,
  division      text check (division in ('bsf', 'kovacs')),
  grupo         text,
  lugar         text,
  cargo         text,
  fecha_ingreso date,
  tallas        jsonb not null default '{}'::jsonb,
  telefono      text,
  notas         text,
  activo        boolean not null default true,
  fecha_baja    date,
  motivo_baja   text,
  origen        text,
  creado        timestamptz not null default now(),
  actualizado   timestamptz,
  creado_por    uuid default auth.uid()
);

-- ---------- Entregas de ropa y EPP (con firma digital) ----------
create table if not exists public.entregas (
  id                text primary key,
  trabajador_id     text references public.trabajadores(id) on delete set null,
  trabajador_nombre text,
  division          text,
  grupo             text,
  fecha             date not null,
  items             jsonb not null default '[]'::jsonb,
  firma             jsonb,
  papel             boolean not null default false,
  nota              text,
  origen            text,
  creado            timestamptz not null default now(),
  creado_por        uuid default auth.uid(),
  creado_por_email  text default (auth.jwt() ->> 'email'),
  firmado_el        timestamptz
);
alter table public.entregas add column if not exists firmado_el timestamptz;
alter table public.trabajadores add column if not exists lugar text;
create index if not exists entregas_trabajador_idx on public.entregas (trabajador_id, fecha desc);

-- ---------- Gastos (facturas) ----------
create table if not exists public.gastos (
  id            text primary key,
  fecha         date,
  proveedor     text,
  rut_proveedor text,
  numero        text,
  categoria     text,
  division      text check (division in ('bsf', 'kovacs', 'general')),
  neto          bigint not null default 0,
  iva           bigint not null default 0,
  total         bigint not null default 0,
  detalle       text,
  revisado      boolean not null default false,
  foto_path     text,
  forma_pago    text,
  origen        text,
  creado        timestamptz not null default now(),
  actualizado   timestamptz,
  creado_por    uuid default auth.uid()
);
create index if not exists gastos_fecha_idx on public.gastos (fecha desc);

-- ---------- Seguridad: solo usuarios con sesión iniciada ----------
alter table public.config       enable row level security;
alter table public.trabajadores enable row level security;
alter table public.entregas     enable row level security;
alter table public.gastos       enable row level security;

do $$
declare t text;
begin
  foreach t in array array['config', 'trabajadores', 'entregas', 'gastos'] loop
    execute format('drop policy if exists "usuarios_leen" on public.%I', t);
    execute format('drop policy if exists "usuarios_crean" on public.%I', t);
    execute format('drop policy if exists "usuarios_editan" on public.%I', t);
    execute format('drop policy if exists "usuarios_borran" on public.%I', t);
    execute format('create policy "usuarios_leen" on public.%I for select to authenticated using (true)', t);
    execute format('create policy "usuarios_crean" on public.%I for insert to authenticated with check (true)', t);
    execute format('create policy "usuarios_editan" on public.%I for update to authenticated using (true) with check (true)', t);
    execute format('create policy "usuarios_borran" on public.%I for delete to authenticated using (true)', t);
  end loop;
end $$;

-- Nadie sin sesión puede tocar las tablas.
revoke all on public.config, public.trabajadores, public.entregas, public.gastos from anon;
grant select, insert, update, delete on public.config, public.trabajadores, public.entregas, public.gastos to authenticated;

-- ---------- Cambios en vivo (para que todos vean lo mismo al instante) ----------
do $$
begin
  begin alter publication supabase_realtime add table public.trabajadores; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.entregas;     exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.gastos;       exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.config;       exception when duplicate_object then null; end;
end $$;

-- ---------- Fotos de facturas (almacenamiento privado) ----------
insert into storage.buckets (id, name, public)
values ('facturas', 'facturas', false)
on conflict (id) do nothing;

drop policy if exists "facturas_leer"   on storage.objects;
drop policy if exists "facturas_subir"  on storage.objects;
drop policy if exists "facturas_editar" on storage.objects;
drop policy if exists "facturas_borrar" on storage.objects;
create policy "facturas_leer"   on storage.objects for select to authenticated using (bucket_id = 'facturas');
create policy "facturas_subir"  on storage.objects for insert to authenticated with check (bucket_id = 'facturas');
create policy "facturas_editar" on storage.objects for update to authenticated using (bucket_id = 'facturas');
create policy "facturas_borrar" on storage.objects for delete to authenticated using (bucket_id = 'facturas');
