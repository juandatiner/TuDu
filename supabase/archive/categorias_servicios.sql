-- ============================================================================
--  tudu — Categorías + servicios revisados por admin
-- ============================================================================
--  Ejecutar UNA VEZ en el SQL Editor del dashboard de Supabase.
--
--  POR QUÉ
--  `services` era un catálogo plano (id, name, description, icon) sin
--  categoría, y `POST /services` insertaba directo sin revisión. Ahora un
--  aliado puede proponer una categoría o un servicio nuevo, pero queda en
--  `review_status = 'pending'` hasta que un admin lo aprueba, lo rechaza o lo
--  corrige — mismo patrón que ya usan `photo_change_requests.status` y
--  `allies.kyc_status`, no una tabla de sugerencias aparte.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Categorías (no existían — es el nivel arriba de `services`)
-- ----------------------------------------------------------------------------
create table if not exists categories (
  id bigint generated always as identity primary key,
  name text not null,
  review_status text not null default 'pending', -- 'pending' | 'approved' | 'rejected'
  created_by_ally_email text references allies(email),
  admin_note text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

-- ----------------------------------------------------------------------------
-- 2. `services` gana categoría + estado de revisión
--    Las 10 filas semilla existentes quedan `approved` (nunca pasaron por acá,
--    pero ya están en uso) — los inserts nuevos desde el backend siempre
--    mandan 'pending' explícito.
-- ----------------------------------------------------------------------------
alter table services
  add column if not exists category_id bigint references categories(id),
  add column if not exists review_status text not null default 'approved',
  add column if not exists created_by_ally_email text references allies(email),
  add column if not exists admin_note text,
  add column if not exists reviewed_at timestamptz;

-- ----------------------------------------------------------------------------
-- 3. Pruebas: fotos del servicio propuesto (no existía tabla de portafolio)
-- ----------------------------------------------------------------------------
create table if not exists ally_portfolio_items (
  id bigint generated always as identity primary key,
  service_id bigint not null references services(id),
  ally_email text not null references allies(email),
  image_path text not null, -- URL pública en el bucket 'portfolio' (ver storage_portfolio.sql)
  caption text,
  created_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- 4. RLS — mismo patrón "denegar todo" que rls.sql: los backends usan la
--    service role key y se saltan RLS igual; esto solo cierra el acceso a
--    anon/authenticated directo contra Supabase.
-- ----------------------------------------------------------------------------
alter table categories           enable row level security;
alter table ally_portfolio_items enable row level security;

-- ----------------------------------------------------------------------------
--  COMPROBACIÓN
-- ----------------------------------------------------------------------------
select table_name, column_name, data_type, is_nullable, column_default
  from information_schema.columns
 where table_schema = 'public'
   and table_name in ('categories', 'services', 'ally_portfolio_items')
 order by table_name, ordinal_position;
