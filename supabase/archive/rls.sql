-- ============================================================================
--  tudu — Row Level Security
-- ============================================================================
--  Ejecutar UNA VEZ en el SQL Editor del dashboard de Supabase.
--
--  SITUACIÓN
--  Todas las tablas viven en el esquema `public`, así que PostgREST las publica
--  automáticamente en la API del proyecto. Sin RLS, cualquiera con la clave
--  `anon` puede leer y escribir TODA la base: usuarios, tarjetas, direcciones,
--  documentos de identidad. Es exactamente el mismo agujero que tenía la vista
--  `admin_allies_kyc_view`, pero sobre las tablas completas.
--
--  ESTRATEGIA
--  Las apps Flutter NO hablan con Supabase directamente: todo pasa por los tres
--  backends de Node, que usan la `service_role_key`. Y la service role se salta
--  RLS por diseño.
--
--  Por eso aquí se activa RLS SIN crear políticas: el resultado es "denegar
--  todo" para `anon` y `authenticated`, mientras los backends siguen operando
--  con normalidad. Es la configuración más restrictiva posible y no rompe nada.
--
--  El día que una app hable directo con Supabase habrá que añadir políticas
--  por `auth.uid()`. Hasta entonces, cerrado.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Datos personales de usuarios
-- ----------------------------------------------------------------------------
alter table public.users                 enable row level security;
alter table public.user_phones           enable row level security;
alter table public.user_addresses        enable row level security;
alter table public.user_cards            enable row level security;
alter table public.search_history        enable row level security;
alter table public.device_sessions       enable row level security;
alter table public.photo_change_requests enable row level security;

-- ----------------------------------------------------------------------------
-- 2. Aliados — incluye los documentos de identidad, lo más sensible del sistema
-- ----------------------------------------------------------------------------
alter table public.allies                enable row level security;
alter table public.ally_service_profiles enable row level security;
alter table public.ally_device_sessions  enable row level security;

-- ----------------------------------------------------------------------------
-- 3. Operación
-- ----------------------------------------------------------------------------
alter table public.services_in_search    enable row level security;
alter table public.services              enable row level security;

-- ----------------------------------------------------------------------------
-- 4. Administradores — contiene los hashes de contraseña
-- ----------------------------------------------------------------------------
alter table public.admins                enable row level security;

-- ----------------------------------------------------------------------------
-- 5. Catálogos geográficos
--    No tienen datos personales, pero tampoco hay razón para exponerlos: las
--    apps los consultan a través de /departments, /cities y /countries.
-- ----------------------------------------------------------------------------
alter table public.departments           enable row level security;
alter table public.cities                enable row level security;
alter table public.countries             enable row level security;

-- ----------------------------------------------------------------------------
--  COMPROBACIÓN
--  Todas las filas deben mostrar rowsecurity = true.
-- ----------------------------------------------------------------------------
select tablename, rowsecurity
  from pg_tables
 where schemaname = 'public'
 order by tablename;

-- ----------------------------------------------------------------------------
--  SI ALGO SE ROMPE
--  Los backends no deberían notar ningún cambio (usan service role). Si alguna
--  pantalla deja de cargar, revertir una tabla concreta con:
--
--    alter table public.<tabla> disable row level security;
--
--  y avisar cuál, porque significaría que algo está entrando con la clave anon.
-- ----------------------------------------------------------------------------
