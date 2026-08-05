-- Migration unit 1: schema_changes
-- Transaction mode: transactional
-- Boundary reason: default

SET check_function_bodies = false;

DROP EXTENSION pg_net;

CREATE EXTENSION pg_cron WITH SCHEMA pg_catalog;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT DELETE, INSERT, SELECT, UPDATE ON TABLES TO anon;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, USAGE ON SEQUENCES TO anon;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON ROUTINES TO anon;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT DELETE, INSERT, SELECT, UPDATE ON TABLES TO authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, USAGE ON SEQUENCES TO authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON ROUTINES TO authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT DELETE, INSERT, SELECT, UPDATE ON TABLES TO service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, USAGE ON SEQUENCES TO service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON ROUTINES TO service_role;

CREATE SEQUENCE public.admins_id_seq;

CREATE SEQUENCE public.allies_id_seq;

CREATE SEQUENCE public.ally_device_sessions_id_seq AS integer;

CREATE SEQUENCE public.ally_service_profiles_id_seq;

CREATE SEQUENCE public.ally_services_id_seq;

CREATE SEQUENCE public.cities_id_seq;

CREATE SEQUENCE public.countries_id_seq;

CREATE SEQUENCE public.departments_id_seq;

CREATE SEQUENCE public.device_sessions_id_seq;

CREATE SEQUENCE public.photo_change_requests_id_seq;

CREATE SEQUENCE public.search_history_id_seq;

CREATE SEQUENCE public.services_id_seq;

CREATE SEQUENCE public.services_in_search_id_seq;

CREATE SEQUENCE public.user_addresses_id_seq;

CREATE SEQUENCE public.user_cards_id_seq;

CREATE SEQUENCE public.user_phones_id_seq;

CREATE SEQUENCE public.user_sessions_id_seq;

CREATE SEQUENCE public.users_id_seq;

CREATE FUNCTION public.tudu_borrar_cuenta (
  p_email text
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  existe boolean;
begin
  select exists(select 1 from users where email = p_email) into existe;

  if not existe then
    return json_build_object('success', false, 'message', 'Usuario no encontrado');
  end if;

  delete from user_addresses        where user_email = p_email;
  delete from user_phones           where user_email = p_email;
  delete from photo_change_requests where user_email = p_email;
  delete from user_cards            where user_email = p_email;
  delete from device_sessions       where user_email = p_email;
  delete from search_history        where user_email = p_email;
  delete from services_in_search    where user_email = p_email;
  delete from users                 where email      = p_email;

  return json_build_object('success', true, 'message', 'Cuenta eliminada');
end;
$function$;

REVOKE ALL ON FUNCTION public.tudu_borrar_cuenta(text) FROM PUBLIC;

GRANT ALL ON FUNCTION public.tudu_borrar_cuenta(text) TO service_role;

CREATE FUNCTION public.tudu_expirar_sesiones_inactivas()
  RETURNS void
  LANGUAGE sql
  SET search_path TO 'public', 'pg_temp'
  AS $function$
  update device_sessions
     set is_active = 0
   where is_active = 1
     and last_activity < now() - interval '180 days';

  update ally_device_sessions
     set is_active = 0
   where is_active = 1
     and last_activity < now() - interval '180 days';
$function$;

GRANT ALL ON FUNCTION public.tudu_expirar_sesiones_inactivas() TO anon;

GRANT ALL ON FUNCTION public.tudu_expirar_sesiones_inactivas() TO authenticated;

GRANT ALL ON FUNCTION public.tudu_expirar_sesiones_inactivas() TO service_role;

CREATE FUNCTION public.tudu_limpiar_fotos_notificadas()
  RETURNS void
  LANGUAGE sql
  SET search_path TO 'public', 'pg_temp'
  AS $function$
  delete from photo_change_requests where user_notified = true;
$function$;

GRANT ALL ON FUNCTION public.tudu_limpiar_fotos_notificadas() TO anon;

GRANT ALL ON FUNCTION public.tudu_limpiar_fotos_notificadas() TO authenticated;

GRANT ALL ON FUNCTION public.tudu_limpiar_fotos_notificadas() TO service_role;

CREATE FUNCTION public.tudu_limpiar_registros_abandonados()
  RETURNS void
  LANGUAGE plpgsql
  SET search_path TO 'public', 'pg_temp'
  AS $function$
declare
  correos text[];
begin
  select array_agg(email) into correos
    from allies
   where coalesce(kyc_status, 'pending') not in ('submitted', 'approved')
     and created_at < now() - interval '7 days';

  if correos is null then
    return;
  end if;

  delete from ally_service_profiles where ally_email = any(correos);
  delete from allies where email = any(correos);
end;
$function$;

GRANT ALL ON FUNCTION public.tudu_limpiar_registros_abandonados() TO anon;

GRANT ALL ON FUNCTION public.tudu_limpiar_registros_abandonados() TO authenticated;

GRANT ALL ON FUNCTION public.tudu_limpiar_registros_abandonados() TO service_role;

CREATE FUNCTION public.update_updated_at_column()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO 'public', 'pg_temp'
  AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;

GRANT ALL ON FUNCTION public.update_updated_at_column() TO anon;

GRANT ALL ON FUNCTION public.update_updated_at_column() TO authenticated;

GRANT ALL ON FUNCTION public.update_updated_at_column() TO service_role;

CREATE TABLE public.admins (
  id         bigint                   DEFAULT nextval('public.admins_id_seq'::regclass) NOT NULL,
  username   text                     NOT NULL,
  password   text                     NOT NULL,
  email      text,
  name       text                     NOT NULL,
  role       text                     DEFAULT 'admin'::text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

ALTER SEQUENCE public.admins_id_seq OWNED BY public.admins.id;

GRANT ALL ON SEQUENCE public.admins_id_seq TO anon;

GRANT ALL ON SEQUENCE public.admins_id_seq TO authenticated;

GRANT ALL ON SEQUENCE public.admins_id_seq TO service_role;

ALTER TABLE public.admins
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.admins
  ADD CONSTRAINT admins_email_key UNIQUE (email);

ALTER TABLE public.admins
  ADD CONSTRAINT admins_pkey PRIMARY KEY (id);

ALTER TABLE public.admins
  ADD CONSTRAINT admins_username_key UNIQUE (username);

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.admins TO anon;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.admins TO authenticated;

GRANT ALL ON public.admins TO service_role;

CREATE TABLE public.allies (
  id                 bigint                   DEFAULT nextval('public.allies_id_seq'::regclass) NOT NULL,
  email              text                     NOT NULL,
  nombre             text                     DEFAULT ''::text NOT NULL,
  apellido           text                     DEFAULT ''::text NOT NULL,
  role               text                     DEFAULT 'ally'::text NOT NULL,
  avatar_color       text                     DEFAULT '#78BF32'::text,
  avatar_icon        text                     DEFAULT 'person'::text,
  avatar_image       text,
  phone              text,
  genero             text,
  created_at         timestamp with time zone DEFAULT now(),
  fecha_nacimiento   date,
  kyc_status         text                     DEFAULT 'pending'::text,
  kyc_cedula_frente  text,
  kyc_cedula_reverso text,
  kyc_selfie         text,
  kyc_submitted_at   timestamp with time zone,
  kyc_reviewed_at    timestamp with time zone,
  kyc_reviewer_note  text
);

ALTER SEQUENCE public.allies_id_seq OWNED BY public.allies.id;

GRANT ALL ON SEQUENCE public.allies_id_seq TO anon;

GRANT ALL ON SEQUENCE public.allies_id_seq TO authenticated;

GRANT ALL ON SEQUENCE public.allies_id_seq TO service_role;

COMMENT ON COLUMN public.allies.kyc_status IS 'Estados: pending | submitted | approved | rejected';

ALTER TABLE public.allies
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.allies
  ADD CONSTRAINT allies_email_key UNIQUE (email);

ALTER TABLE public.allies
  ADD CONSTRAINT allies_pkey PRIMARY KEY (id);

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.allies TO anon;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.allies TO authenticated;

GRANT ALL ON public.allies TO service_role;

CREATE INDEX idx_allies_email ON public.allies (email);

CREATE INDEX idx_allies_kyc_status ON public.allies (kyc_status);

CREATE TABLE public.ally_device_sessions (
  id            integer                  DEFAULT nextval('public.ally_device_sessions_id_seq'::regclass) NOT NULL,
  ally_email    character varying(255)   NOT NULL,
  device_id     character varying(255)   NOT NULL,
  device_info   jsonb,
  last_activity timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
  is_active     smallint                 DEFAULT 1,
  created_at    timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

ALTER SEQUENCE public.ally_device_sessions_id_seq OWNED BY public.ally_device_sessions.id;

GRANT ALL ON SEQUENCE public.ally_device_sessions_id_seq TO anon;

GRANT ALL ON SEQUENCE public.ally_device_sessions_id_seq TO authenticated;

GRANT ALL ON SEQUENCE public.ally_device_sessions_id_seq TO service_role;

ALTER TABLE public.ally_device_sessions
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.ally_device_sessions
  ADD CONSTRAINT ally_device_sessions_ally_email_fkey FOREIGN KEY (ally_email) REFERENCES public.allies(email) ON DELETE CASCADE;

ALTER TABLE public.ally_device_sessions
  ADD CONSTRAINT ally_device_sessions_pkey PRIMARY KEY (id);

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.ally_device_sessions TO anon;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.ally_device_sessions TO authenticated;

GRANT ALL ON public.ally_device_sessions TO service_role;

CREATE INDEX ally_device_sessions_ally_email_idx ON public.ally_device_sessions (ally_email);

CREATE INDEX ally_device_sessions_active_idx ON public.ally_device_sessions (is_active);

CREATE UNIQUE INDEX ally_device_sessions_unique_idx ON public.ally_device_sessions (ally_email, device_id);

CREATE TABLE public.ally_portfolio_items (
  id         bigint                   GENERATED ALWAYS AS IDENTITY NOT NULL,
  service_id bigint                   NOT NULL,
  ally_email text                     NOT NULL,
  image_path text                     NOT NULL,
  caption    text,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.ally_portfolio_items
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.ally_portfolio_items
  ADD CONSTRAINT ally_portfolio_items_ally_email_fkey FOREIGN KEY (ally_email) REFERENCES public.allies(email);

ALTER TABLE public.ally_portfolio_items
  ADD CONSTRAINT ally_portfolio_items_pkey PRIMARY KEY (id);

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.ally_portfolio_items TO anon;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.ally_portfolio_items TO authenticated;

GRANT ALL ON public.ally_portfolio_items TO service_role;

CREATE TABLE public.ally_service_profiles (
  id                 bigint                   DEFAULT nextval('public.ally_service_profiles_id_seq'::regclass) NOT NULL,
  ally_email         text                     NOT NULL,
  service_id         bigint                   NOT NULL,
  nombre_comercial   text,
  frase_presentacion text,
  resumen            text,
  esta_activo        boolean                  DEFAULT true,
  created_at         timestamp with time zone DEFAULT now(),
  updated_at         timestamp with time zone DEFAULT now()
);

ALTER SEQUENCE public.ally_service_profiles_id_seq OWNED BY public.ally_service_profiles.id;

GRANT ALL ON SEQUENCE public.ally_service_profiles_id_seq TO anon;

GRANT ALL ON SEQUENCE public.ally_service_profiles_id_seq TO authenticated;

GRANT ALL ON SEQUENCE public.ally_service_profiles_id_seq TO service_role;

COMMENT ON TABLE public.ally_service_profiles IS 'Perfil de servicio de cada aliado. Un aliado puede tener múltiples perfiles (uno por servicio).';

ALTER TABLE public.ally_service_profiles
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.ally_service_profiles
  ADD CONSTRAINT ally_service_profiles_ally_email_fkey FOREIGN KEY (ally_email) REFERENCES public.allies(email) ON DELETE CASCADE;

ALTER TABLE public.ally_service_profiles
  ADD CONSTRAINT ally_service_profiles_pkey PRIMARY KEY (id);

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.ally_service_profiles TO anon;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.ally_service_profiles TO authenticated;

GRANT ALL ON public.ally_service_profiles TO service_role;

CREATE INDEX idx_ally_service_profiles_activo ON public.ally_service_profiles (esta_activo);

CREATE INDEX idx_ally_service_profiles_email ON public.ally_service_profiles (ally_email);

CREATE UNIQUE INDEX idx_ally_service_unique ON public.ally_service_profiles (ally_email, service_id);

CREATE INDEX idx_ally_service_profiles_service_id ON public.ally_service_profiles (service_id);

CREATE TRIGGER set_updated_at_ally_service_profiles
  BEFORE UPDATE ON public.ally_service_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TABLE public.ally_services (
  id         bigint                   DEFAULT nextval('public.ally_services_id_seq'::regclass) NOT NULL,
  ally_email text                     NOT NULL,
  service_id bigint                   NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);

ALTER SEQUENCE public.ally_services_id_seq OWNED BY public.ally_services.id;

GRANT ALL ON SEQUENCE public.ally_services_id_seq TO anon;

GRANT ALL ON SEQUENCE public.ally_services_id_seq TO authenticated;

GRANT ALL ON SEQUENCE public.ally_services_id_seq TO service_role;

ALTER TABLE public.ally_services
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.ally_services
  ADD CONSTRAINT ally_services_ally_email_service_id_key UNIQUE (ally_email, service_id);

ALTER TABLE public.ally_services
  ADD CONSTRAINT ally_services_pkey PRIMARY KEY (id);

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.ally_services TO anon;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.ally_services TO authenticated;

GRANT ALL ON public.ally_services TO service_role;

CREATE TABLE public.categories (
  id                    bigint                   GENERATED ALWAYS AS IDENTITY NOT NULL,
  name                  text                     NOT NULL,
  review_status         text                     DEFAULT 'pending'::text NOT NULL,
  created_by_ally_email text,
  admin_note            text,
  created_at            timestamp with time zone DEFAULT now() NOT NULL,
  reviewed_at           timestamp with time zone
);

ALTER TABLE public.categories
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.categories
  ADD CONSTRAINT categories_created_by_ally_email_fkey FOREIGN KEY (created_by_ally_email) REFERENCES public.allies(email);

ALTER TABLE public.categories
  ADD CONSTRAINT categories_pkey PRIMARY KEY (id);

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.categories TO anon;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.categories TO authenticated;

GRANT ALL ON public.categories TO service_role;

CREATE TABLE public.cities (
  id            bigint DEFAULT nextval('public.cities_id_seq'::regclass) NOT NULL,
  name          text   NOT NULL,
  department_id bigint
);

ALTER SEQUENCE public.cities_id_seq OWNED BY public.cities.id;

GRANT ALL ON SEQUENCE public.cities_id_seq TO anon;

GRANT ALL ON SEQUENCE public.cities_id_seq TO authenticated;

GRANT ALL ON SEQUENCE public.cities_id_seq TO service_role;

ALTER TABLE public.cities
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.cities
  ADD CONSTRAINT cities_name_department_id_key UNIQUE (name, department_id);

ALTER TABLE public.cities
  ADD CONSTRAINT cities_pkey PRIMARY KEY (id);

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.cities TO anon;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.cities TO authenticated;

GRANT ALL ON public.cities TO service_role;

CREATE TABLE public.countries (
  id         bigint                   DEFAULT nextval('public.countries_id_seq'::regclass) NOT NULL,
  iso_code   text                     NOT NULL,
  name       text                     NOT NULL,
  dial_code  text                     NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);

ALTER SEQUENCE public.countries_id_seq OWNED BY public.countries.id;

GRANT ALL ON SEQUENCE public.countries_id_seq TO anon;

GRANT ALL ON SEQUENCE public.countries_id_seq TO authenticated;

GRANT ALL ON SEQUENCE public.countries_id_seq TO service_role;

ALTER TABLE public.countries
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.countries
  ADD CONSTRAINT countries_iso_code_key UNIQUE (iso_code);

ALTER TABLE public.countries
  ADD CONSTRAINT countries_pkey PRIMARY KEY (id);

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.countries TO anon;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.countries TO authenticated;

GRANT ALL ON public.countries TO service_role;

CREATE TABLE public.departments (
  id   bigint DEFAULT nextval('public.departments_id_seq'::regclass) NOT NULL,
  name text   NOT NULL
);

ALTER SEQUENCE public.departments_id_seq OWNED BY public.departments.id;

GRANT ALL ON SEQUENCE public.departments_id_seq TO anon;

GRANT ALL ON SEQUENCE public.departments_id_seq TO authenticated;

GRANT ALL ON SEQUENCE public.departments_id_seq TO service_role;

ALTER TABLE public.departments
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.departments
  ADD CONSTRAINT departments_name_key UNIQUE (name);

ALTER TABLE public.departments
  ADD CONSTRAINT departments_pkey PRIMARY KEY (id);

ALTER TABLE public.cities
  ADD CONSTRAINT cities_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id);

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.departments TO anon;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.departments TO authenticated;

GRANT ALL ON public.departments TO service_role;

CREATE TABLE public.device_sessions (
  id                    bigint                   DEFAULT nextval('public.device_sessions_id_seq'::regclass) NOT NULL,
  user_email            text                     NOT NULL,
  device_id             text                     NOT NULL,
  device_info           text,
  is_active             integer                  DEFAULT 1,
  requires_verification integer                  DEFAULT 0,
  last_activity         timestamp with time zone DEFAULT now(),
  created_at            timestamp with time zone DEFAULT now()
);

ALTER SEQUENCE public.device_sessions_id_seq OWNED BY public.device_sessions.id;

GRANT ALL ON SEQUENCE public.device_sessions_id_seq TO anon;

GRANT ALL ON SEQUENCE public.device_sessions_id_seq TO authenticated;

GRANT ALL ON SEQUENCE public.device_sessions_id_seq TO service_role;

ALTER TABLE public.device_sessions
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.device_sessions
  ADD CONSTRAINT device_sessions_pkey PRIMARY KEY (id);

ALTER TABLE public.device_sessions
  ADD CONSTRAINT device_sessions_user_email_device_id_key UNIQUE (user_email, device_id);

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.device_sessions TO anon;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.device_sessions TO authenticated;

GRANT ALL ON public.device_sessions TO service_role;

CREATE TABLE public.photo_change_requests (
  id               bigint                   DEFAULT nextval('public.photo_change_requests_id_seq'::regclass) NOT NULL,
  user_email       text                     NOT NULL,
  new_avatar_image text                     NOT NULL,
  status           text                     DEFAULT 'pending'::text,
  read_at          timestamp with time zone,
  rejection_reason text,
  user_notified    boolean                  DEFAULT false,
  created_at       timestamp with time zone DEFAULT now(),
  updated_at       timestamp with time zone DEFAULT now()
);

ALTER SEQUENCE public.photo_change_requests_id_seq OWNED BY public.photo_change_requests.id;

GRANT ALL ON SEQUENCE public.photo_change_requests_id_seq TO anon;

GRANT ALL ON SEQUENCE public.photo_change_requests_id_seq TO authenticated;

GRANT ALL ON SEQUENCE public.photo_change_requests_id_seq TO service_role;

ALTER TABLE public.photo_change_requests
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.photo_change_requests
  ADD CONSTRAINT photo_change_requests_pkey PRIMARY KEY (id);

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.photo_change_requests TO anon;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.photo_change_requests TO authenticated;

GRANT ALL ON public.photo_change_requests TO service_role;

CREATE TABLE public.search_history (
  id         bigint                   DEFAULT nextval('public.search_history_id_seq'::regclass) NOT NULL,
  user_email text,
  query      text                     NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);

ALTER SEQUENCE public.search_history_id_seq OWNED BY public.search_history.id;

GRANT ALL ON SEQUENCE public.search_history_id_seq TO anon;

GRANT ALL ON SEQUENCE public.search_history_id_seq TO authenticated;

GRANT ALL ON SEQUENCE public.search_history_id_seq TO service_role;

ALTER TABLE public.search_history
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.search_history
  ADD CONSTRAINT search_history_pkey PRIMARY KEY (id);

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.search_history TO anon;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.search_history TO authenticated;

GRANT ALL ON public.search_history TO service_role;

CREATE TABLE public.services (
  id                    bigint                   DEFAULT nextval('public.services_id_seq'::regclass) NOT NULL,
  name                  text                     NOT NULL,
  description           text,
  icon                  text,
  created_at            timestamp with time zone DEFAULT now(),
  category_id           bigint,
  review_status         text                     DEFAULT 'approved'::text NOT NULL,
  created_by_ally_email text,
  admin_note            text,
  reviewed_at           timestamp with time zone
);

ALTER SEQUENCE public.services_id_seq OWNED BY public.services.id;

GRANT ALL ON SEQUENCE public.services_id_seq TO anon;

GRANT ALL ON SEQUENCE public.services_id_seq TO authenticated;

GRANT ALL ON SEQUENCE public.services_id_seq TO service_role;

ALTER TABLE public.services
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.services
  ADD CONSTRAINT services_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id);

ALTER TABLE public.services
  ADD CONSTRAINT services_created_by_ally_email_fkey FOREIGN KEY (created_by_ally_email) REFERENCES public.allies(email);

ALTER TABLE public.services
  ADD CONSTRAINT services_name_key UNIQUE (name);

ALTER TABLE public.services
  ADD CONSTRAINT services_pkey PRIMARY KEY (id);

ALTER TABLE public.ally_portfolio_items
  ADD CONSTRAINT ally_portfolio_items_service_id_fkey FOREIGN KEY (service_id) REFERENCES public.services(id);

ALTER TABLE public.ally_service_profiles
  ADD CONSTRAINT ally_service_profiles_service_id_fkey FOREIGN KEY (service_id) REFERENCES public.services(id) ON DELETE SET NULL;

ALTER TABLE public.ally_services
  ADD CONSTRAINT ally_services_service_id_fkey FOREIGN KEY (service_id) REFERENCES public.services(id);

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.services TO anon;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.services TO authenticated;

GRANT ALL ON public.services TO service_role;

CREATE TABLE public.services_in_search (
  id            bigint                   DEFAULT nextval('public.services_in_search_id_seq'::regclass) NOT NULL,
  user_email    text,
  title         text                     NOT NULL,
  description   text,
  time_quantity integer,
  time_unit     text,
  budget        text,
  worker_info   text,
  status        text                     DEFAULT 'EN ESPERA'::text,
  assigned      integer                  DEFAULT 0,
  ally_email    text,
  created_at    timestamp with time zone DEFAULT now()
);

ALTER SEQUENCE public.services_in_search_id_seq OWNED BY public.services_in_search.id;

GRANT ALL ON SEQUENCE public.services_in_search_id_seq TO anon;

GRANT ALL ON SEQUENCE public.services_in_search_id_seq TO authenticated;

GRANT ALL ON SEQUENCE public.services_in_search_id_seq TO service_role;

ALTER TABLE public.services_in_search
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.services_in_search
  ADD CONSTRAINT services_in_search_pkey PRIMARY KEY (id);

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.services_in_search TO anon;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.services_in_search TO authenticated;

GRANT ALL ON public.services_in_search TO service_role;

CREATE TABLE public.user_addresses (
  id               bigint                   DEFAULT nextval('public.user_addresses_id_seq'::regclass) NOT NULL,
  user_email       text                     NOT NULL,
  address_name     text                     NOT NULL,
  department_id    bigint,
  city_id          bigint,
  type_via         text,
  number_principal text,
  number_secondary text,
  number_final     text,
  additional_info  text,
  address_icon     text,
  created_at       timestamp with time zone DEFAULT now()
);

ALTER SEQUENCE public.user_addresses_id_seq OWNED BY public.user_addresses.id;

GRANT ALL ON SEQUENCE public.user_addresses_id_seq TO anon;

GRANT ALL ON SEQUENCE public.user_addresses_id_seq TO authenticated;

GRANT ALL ON SEQUENCE public.user_addresses_id_seq TO service_role;

ALTER TABLE public.user_addresses
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.user_addresses
  ADD CONSTRAINT user_addresses_city_id_fkey FOREIGN KEY (city_id) REFERENCES public.cities(id);

ALTER TABLE public.user_addresses
  ADD CONSTRAINT user_addresses_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id);

ALTER TABLE public.user_addresses
  ADD CONSTRAINT user_addresses_pkey PRIMARY KEY (id);

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.user_addresses TO anon;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.user_addresses TO authenticated;

GRANT ALL ON public.user_addresses TO service_role;

CREATE TABLE public.user_cards (
  id              bigint                   DEFAULT nextval('public.user_cards_id_seq'::regclass) NOT NULL,
  user_email      text                     NOT NULL,
  card_number     text                     NOT NULL,
  card_holder     text                     NOT NULL,
  expiry_date     text                     NOT NULL,
  card_type       text                     DEFAULT 'visa'::text,
  document_type   text                     DEFAULT 'C.C'::text,
  document_number text,
  card_mode       text                     DEFAULT 'credit'::text,
  is_default      integer                  DEFAULT 0,
  created_at      timestamp with time zone DEFAULT now()
);

ALTER SEQUENCE public.user_cards_id_seq OWNED BY public.user_cards.id;

GRANT ALL ON SEQUENCE public.user_cards_id_seq TO anon;

GRANT ALL ON SEQUENCE public.user_cards_id_seq TO authenticated;

GRANT ALL ON SEQUENCE public.user_cards_id_seq TO service_role;

ALTER TABLE public.user_cards
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.user_cards
  ADD CONSTRAINT user_cards_pkey PRIMARY KEY (id);

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.user_cards TO anon;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.user_cards TO authenticated;

GRANT ALL ON public.user_cards TO service_role;

CREATE TABLE public.user_phones (
  id           bigint                   DEFAULT nextval('public.user_phones_id_seq'::regclass) NOT NULL,
  user_email   text                     NOT NULL,
  country_code text                     NOT NULL,
  country_name text,
  phone_number text                     NOT NULL,
  created_at   timestamp with time zone DEFAULT now()
);

ALTER SEQUENCE public.user_phones_id_seq OWNED BY public.user_phones.id;

GRANT ALL ON SEQUENCE public.user_phones_id_seq TO anon;

GRANT ALL ON SEQUENCE public.user_phones_id_seq TO authenticated;

GRANT ALL ON SEQUENCE public.user_phones_id_seq TO service_role;

ALTER TABLE public.user_phones
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.user_phones
  ADD CONSTRAINT user_phones_pkey PRIMARY KEY (id);

ALTER TABLE public.user_phones
  ADD CONSTRAINT user_phones_user_email_key UNIQUE (user_email);

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.user_phones TO anon;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.user_phones TO authenticated;

GRANT ALL ON public.user_phones TO service_role;

CREATE TABLE public.user_sessions (
  id         bigint                   DEFAULT nextval('public.user_sessions_id_seq'::regclass) NOT NULL,
  user_email text,
  token      text                     NOT NULL,
  device     text,
  created_at timestamp with time zone DEFAULT now(),
  last_seen  timestamp with time zone DEFAULT now()
);

ALTER SEQUENCE public.user_sessions_id_seq OWNED BY public.user_sessions.id;

GRANT ALL ON SEQUENCE public.user_sessions_id_seq TO anon;

GRANT ALL ON SEQUENCE public.user_sessions_id_seq TO authenticated;

GRANT ALL ON SEQUENCE public.user_sessions_id_seq TO service_role;

ALTER TABLE public.user_sessions
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.user_sessions
  ADD CONSTRAINT user_sessions_pkey PRIMARY KEY (id);

ALTER TABLE public.user_sessions
  ADD CONSTRAINT user_sessions_token_key UNIQUE (token);

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.user_sessions TO anon;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.user_sessions TO authenticated;

GRANT ALL ON public.user_sessions TO service_role;

CREATE TABLE public.users (
  id               bigint                   DEFAULT nextval('public.users_id_seq'::regclass) NOT NULL,
  email            text                     NOT NULL,
  nombre           text                     DEFAULT ''::text NOT NULL,
  apellido         text                     DEFAULT ''::text NOT NULL,
  role             text                     DEFAULT 'user'::text NOT NULL,
  avatar_color     text                     DEFAULT '#78BF32'::text,
  avatar_icon      text                     DEFAULT 'person'::text,
  avatar_image     text,
  phone            text,
  genero           text,
  fecha_nacimiento text,
  dark_mode        integer                  DEFAULT 0,
  language         text                     DEFAULT 'es'::text,
  created_at       timestamp with time zone DEFAULT now()
);

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;

GRANT ALL ON SEQUENCE public.users_id_seq TO anon;

GRANT ALL ON SEQUENCE public.users_id_seq TO authenticated;

GRANT ALL ON SEQUENCE public.users_id_seq TO service_role;

ALTER TABLE public.users
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.users
  ADD CONSTRAINT users_email_key UNIQUE (email);

ALTER TABLE public.device_sessions
  ADD CONSTRAINT device_sessions_user_email_fkey FOREIGN KEY (user_email) REFERENCES public.users(email);

ALTER TABLE public.photo_change_requests
  ADD CONSTRAINT photo_change_requests_user_email_fkey FOREIGN KEY (user_email) REFERENCES public.users(email);

ALTER TABLE public.search_history
  ADD CONSTRAINT search_history_user_email_fkey FOREIGN KEY (user_email) REFERENCES public.users(email);

ALTER TABLE public.services_in_search
  ADD CONSTRAINT services_in_search_user_email_fkey FOREIGN KEY (user_email) REFERENCES public.users(email);

ALTER TABLE public.user_addresses
  ADD CONSTRAINT user_addresses_user_email_fkey FOREIGN KEY (user_email) REFERENCES public.users(email);

ALTER TABLE public.user_cards
  ADD CONSTRAINT user_cards_user_email_fkey FOREIGN KEY (user_email) REFERENCES public.users(email);

ALTER TABLE public.user_phones
  ADD CONSTRAINT user_phones_user_email_fkey FOREIGN KEY (user_email) REFERENCES public.users(email);

ALTER TABLE public.user_sessions
  ADD CONSTRAINT user_sessions_user_email_fkey FOREIGN KEY (user_email) REFERENCES public.users(email);

ALTER TABLE public.users
  ADD CONSTRAINT users_pkey PRIMARY KEY (id);

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.users TO anon;

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON public.users TO authenticated;

GRANT ALL ON public.users TO service_role;
