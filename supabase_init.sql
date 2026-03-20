-- ==============================================================================
-- 🚀 SCRIPT DE INICIALIZACIÓN DE SUPABASE - TUDU
-- ==============================================================================
-- Instrucciones:
-- 1. Ve a Supabase.com -> Entra a tu proyecto (tudu)
-- 2. En el menú de la izquierda, haz clic en "SQL Editor"
-- 3. Haz clic en "New Query"
-- 4. Copia y pega TODO este código allí, y haz clic en "RUN"
-- ==============================================================================

-- 1. Tablas base de ubicación (Estáticas)
CREATE TABLE IF NOT EXISTS countries (
  id BIGSERIAL PRIMARY KEY,
  iso_code TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  dial_code TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS departments (
  id BIGSERIAL PRIMARY KEY,
  name TEXT UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS cities (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  department_id BIGINT REFERENCES departments(id),
  UNIQUE(name, department_id)
);

-- 2. Usuarios
CREATE TABLE IF NOT EXISTS users (
  id           BIGSERIAL PRIMARY KEY,
  email        TEXT UNIQUE NOT NULL,
  nombre       TEXT NOT NULL DEFAULT '',
  apellido     TEXT NOT NULL DEFAULT '',
  role         TEXT NOT NULL DEFAULT 'user',
  avatar_color TEXT DEFAULT '#78BF32',
  avatar_icon  TEXT DEFAULT 'person',
  avatar_image TEXT,
  phone        TEXT,
  genero       TEXT,
  fecha_nacimiento TEXT,
  dark_mode    INTEGER DEFAULT 0,
  language     TEXT DEFAULT 'es',
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_phones (
  id BIGSERIAL PRIMARY KEY,
  user_email TEXT UNIQUE NOT NULL REFERENCES users(email),
  country_code TEXT NOT NULL,
  country_name TEXT,
  phone_number TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS photo_change_requests (
  id                BIGSERIAL PRIMARY KEY,
  user_email        TEXT NOT NULL REFERENCES users(email),
  new_avatar_image  TEXT NOT NULL,
  status            TEXT DEFAULT 'pending',
  read_at           TIMESTAMPTZ,
  rejection_reason  TEXT,
  user_notified     BOOLEAN DEFAULT FALSE,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Aliados
CREATE TABLE IF NOT EXISTS allies (
  id         BIGSERIAL PRIMARY KEY,
  email      TEXT UNIQUE NOT NULL,
  nombre     TEXT NOT NULL DEFAULT '',
  apellido   TEXT NOT NULL DEFAULT '',
  role       TEXT NOT NULL DEFAULT 'ally',
  avatar_color TEXT DEFAULT '#78BF32',
  avatar_icon  TEXT DEFAULT 'person',
  avatar_image TEXT,
  phone        TEXT,
  genero       TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Admins
CREATE TABLE IF NOT EXISTS admins (
  id         BIGSERIAL PRIMARY KEY,
  username   TEXT UNIQUE NOT NULL,
  password   TEXT NOT NULL,
  email      TEXT UNIQUE,
  name       TEXT NOT NULL,
  role       TEXT DEFAULT 'admin',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insertar admin por defecto si no existe
INSERT INTO admins (username, password, name, role)
VALUES ('admin', 'admin123', 'Administrador', 'superadmin')
ON CONFLICT (username) DO NOTHING;

-- 5. Servicios e interacciones
CREATE TABLE IF NOT EXISTS services (
  id          BIGSERIAL PRIMARY KEY,
  name        TEXT UNIQUE NOT NULL,
  description TEXT,
  icon        TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS services_in_search (
  id           BIGSERIAL PRIMARY KEY,
  user_email   TEXT REFERENCES users(email),
  title        TEXT NOT NULL,
  description  TEXT,
  time_quantity INTEGER,
  time_unit    TEXT,
  budget       TEXT,
  worker_info  TEXT,
  status       TEXT DEFAULT 'EN ESPERA',
  assigned     INTEGER DEFAULT 0,
  ally_email   TEXT,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ally_services (
  id         BIGSERIAL PRIMARY KEY,
  ally_email TEXT NOT NULL,
  service_id BIGINT NOT NULL REFERENCES services(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(ally_email, service_id)
);

CREATE TABLE IF NOT EXISTS search_history (
  id         BIGSERIAL PRIMARY KEY,
  user_email TEXT REFERENCES users(email),
  query      TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_sessions (
  id         BIGSERIAL PRIMARY KEY,
  user_email TEXT REFERENCES users(email),
  token      TEXT UNIQUE NOT NULL,
  device     TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_seen  TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- HABILITACIÓN DE ROW LEVEL SECURITY (RLS)
-- ==========================================
ALTER TABLE countries ENABLE ROW LEVEL SECURITY;
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE cities ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_phones ENABLE ROW LEVEL SECURITY;
ALTER TABLE photo_change_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE allies ENABLE ROW LEVEL SECURITY;
ALTER TABLE admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
ALTER TABLE services_in_search ENABLE ROW LEVEL SECURITY;
ALTER TABLE ally_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE search_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;

-- Damos acceso total al backend (usando la Service Role Key)
CREATE POLICY "service_role_all" ON countries FOR ALL USING (TRUE);
CREATE POLICY "service_role_all" ON departments FOR ALL USING (TRUE);
CREATE POLICY "service_role_all" ON cities FOR ALL USING (TRUE);
CREATE POLICY "service_role_all" ON users FOR ALL USING (TRUE);
CREATE POLICY "service_role_all" ON user_phones FOR ALL USING (TRUE);
CREATE POLICY "service_role_all" ON photo_change_requests FOR ALL USING (TRUE);
CREATE POLICY "service_role_all" ON allies FOR ALL USING (TRUE);
CREATE POLICY "service_role_all" ON admins FOR ALL USING (TRUE);
CREATE POLICY "service_role_all" ON services FOR ALL USING (TRUE);
CREATE POLICY "service_role_all" ON services_in_search FOR ALL USING (TRUE);
CREATE POLICY "service_role_all" ON ally_services FOR ALL USING (TRUE);
CREATE POLICY "service_role_all" ON search_history FOR ALL USING (TRUE);
CREATE POLICY "service_role_all" ON user_sessions FOR ALL USING (TRUE);
