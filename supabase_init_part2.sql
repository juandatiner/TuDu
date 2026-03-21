-- ==============================================================================
-- 🚀 SCRIPT DE INICIALIZACIÓN PARTE 2 - TUDU
-- Faltaron estas 3 tablas vitales (Tarjetas, Direcciones y Sesiones)
-- Cópialo y ejecútalo en el SQL Editor de Supabase igual que antes.
-- ==============================================================================

-- 1. Direcciones de Usuario
CREATE TABLE IF NOT EXISTS user_addresses (
  id BIGSERIAL PRIMARY KEY,
  user_email TEXT NOT NULL REFERENCES users(email),
  address_name TEXT NOT NULL,
  department_id BIGINT REFERENCES departments(id),
  city_id BIGINT REFERENCES cities(id),
  type_via TEXT,
  number_principal TEXT,
  number_secondary TEXT,
  number_final TEXT,
  additional_info TEXT,
  address_icon TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Tarjetas de Usuario
CREATE TABLE IF NOT EXISTS user_cards (
  id BIGSERIAL PRIMARY KEY,
  user_email TEXT NOT NULL REFERENCES users(email),
  card_number TEXT NOT NULL,
  card_holder TEXT NOT NULL,
  expiry_date TEXT NOT NULL,
  card_type TEXT DEFAULT 'visa',
  document_type TEXT DEFAULT 'C.C',
  document_number TEXT,
  card_mode TEXT DEFAULT 'credit',
  is_default INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Sesiones de Dispositivos (Device Sessions)
CREATE TABLE IF NOT EXISTS device_sessions (
  id BIGSERIAL PRIMARY KEY,
  user_email TEXT NOT NULL REFERENCES users(email),
  device_id TEXT NOT NULL,
  device_info TEXT,
  is_active INTEGER DEFAULT 1,
  requires_verification INTEGER DEFAULT 0,
  last_activity TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_email, device_id)
);

-- Habilitar RLS estricto pero dar permiso al Backend
ALTER TABLE user_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "service_role_all" ON user_addresses FOR ALL USING (TRUE);
CREATE POLICY "service_role_all" ON user_cards FOR ALL USING (TRUE);
CREATE POLICY "service_role_all" ON device_sessions FOR ALL USING (TRUE);
