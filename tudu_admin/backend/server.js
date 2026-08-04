const express = require('express');
const cors = require('cors');
const path = require('path');
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');
const { corsOptions, avisarConfiguracion } = require('./cors_config');

const app = express();
const PORT = process.env.PORT || 3003;

app.use(cors(corsOptions));
app.use(express.json({ limit: '50mb' }));

// Inicializar Supabase
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error("❌ Faltan credenciales de Supabase en .env");
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

// ==========================================
// RUTAS ADMIN
// ==========================================

const bcrypt = require('bcryptjs');
const { signSession, requireAuth, createRefreshHandler } = require('./auth');
const { limiteLogin } = require('./rate_limit');

const BCRYPT_ROUNDS = 10;

/// Un hash de bcrypt siempre empieza por $2a$ / $2b$ / $2y$.
/// Sirve para distinguir las filas viejas, guardadas en texto plano.
function esHash(valor) {
  return typeof valor === 'string' && /^\$2[aby]\$/.test(valor);
}

/// Compara la contraseña recibida contra lo guardado, aceptando las filas
/// heredadas en texto plano para no dejar fuera a nadie durante la migración.
async function passwordCoincide(plano, guardado) {
  if (esHash(guardado)) return bcrypt.compare(plano, guardado);
  return plano === guardado;
}

app.get('/', (req, res) => {
  res.json({ message: 'TuDu Admin Backend is running via Supabase' });
});

// Login de admin
app.post('/api/admin/login', limiteLogin, async (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ error: 'Username and password are required' });
  }

  // Ya no se filtra por contraseña en la consulta: se trae la fila por usuario
  // y se compara el hash en memoria. Comparar con `.eq('password', ...)` obliga
  // a guardar la contraseña en texto plano.
  const { data: row, error } = await supabase
    .from('admins')
    .select('*')
    .eq('username', username)
    .single();

  if (error || !row || !(await passwordCoincide(password, row.password))) {
    return res.status(401).json({ error: 'Invalid username or password' });
  }

  // Migración transparente: la primera vez que un admin heredado entra bien,
  // su contraseña en texto plano se reemplaza por el hash.
  if (!esHash(row.password)) {
    const hash = await bcrypt.hash(password, BCRYPT_ROUNDS);
    await supabase.from('admins').update({ password: hash }).eq('id', row.id);
    console.log(`🔐 Contraseña de '${row.username}' migrada a hash bcrypt.`);
  }

  res.json({
    success: true,
    ...signSession({ email: row.email || row.username, role: 'admin' }),
    data: {
      id: row.id,
      username: row.username,
      email: row.email,
      name: row.name,
      role: row.role
    }
  });
});

/// Canjea el refresh token del panel por un acceso nuevo.
/// El admin no tiene sesiones por dispositivo: se comprueba que la cuenta siga
/// existiendo y conservando el rol.
app.post('/auth/refresh', createRefreshHandler(async ({ email, role }) => {
  if (role !== 'admin') return false;

  const { data } = await supabase
    .from('admins')
    .select('id')
    .or(`email.eq.${email},username.eq.${email}`)
    .limit(1);

  return !!(data && data.length > 0);
}));

// Todo lo que gestiona cuentas de administrador exige token con rol admin.
app.use('/api/admins', requireAuth, (req, res, next) => {
  if (req.auth.role !== 'admin') {
    return res.status(403).json({ error: 'Se requiere rol de administrador', code: 'NOT_ADMIN' });
  }
  next();
});

// Obtener todos los admins
app.get('/api/admins', async (req, res) => {
  const { data, error } = await supabase
    .from('admins')
    .select('id, username, email, name, role, created_at, updated_at');

  if (error) return res.status(500).json({ error: 'Internal server error' });
  res.json({ success: true, data: data || [] });
});

// Crear un nuevo admin
app.post('/api/admins', async (req, res) => {
  const { username, password, email, name, role = 'admin' } = req.body;

  if (!username || !password || !name) {
    return res.status(400).json({ error: 'Username, password and name are required' });
  }

  // Nunca se guarda la contraseña tal cual.
  const hash = await bcrypt.hash(password, BCRYPT_ROUNDS);

  const { data, error } = await supabase
    .from('admins')
    .insert([{ username, password: hash, email, name, role }])
    .select('id, username, email, name, role, created_at, updated_at')
    .single();

  if (error) {
    if (error.code === '23505') {
      return res.status(400).json({ error: 'Username or email already exists' });
    }
    return res.status(500).json({ error: 'Internal server error' });
  }

  res.json({ success: true, data });
});

// Actualizar un admin
app.put('/api/admins/:id', async (req, res) => {
  const { id } = req.params;
  const { username, email, name, role } = req.body;

  const { data, error } = await supabase
    .from('admins')
    .update({ username, email, name, role, updated_at: new Date().toISOString() })
    .eq('id', id)
    .select()
    .single();

  if (error) {
    if (error.code === '23505') {
      return res.status(400).json({ error: 'Username or email already exists' });
    }
    return res.status(500).json({ error: 'Internal server error' });
  }

  if (!data) return res.status(404).json({ error: 'Admin not found' });

  res.json({ success: true, data });
});

// Eliminar un admin
app.delete('/api/admins/:id', async (req, res) => {
  const { error } = await supabase
    .from('admins')
    .delete()
    .eq('id', req.params.id);

  if (error) return res.status(500).json({ error: 'Internal server error' });
  
  res.json({ success: true, message: 'Admin deleted successfully' });
});

// Cambiar contraseña de admin
app.put('/api/admins/:id/change-password', async (req, res) => {
  const { id } = req.params;
  const { currentPassword, newPassword } = req.body;

  if (!currentPassword || !newPassword) {
    return res.status(400).json({ error: 'Current and new passwords are required' });
  }

  const { data: admin } = await supabase
    .from('admins')
    .select('id, password')
    .eq('id', id)
    .single();

  if (!admin || !(await passwordCoincide(currentPassword, admin.password))) {
    return res.status(401).json({ error: 'Current password is incorrect' });
  }

  const hash = await bcrypt.hash(newPassword, BCRYPT_ROUNDS);

  const { error } = await supabase
    .from('admins')
    .update({ password: hash, updated_at: new Date().toISOString() })
    .eq('id', id);

  if (error) return res.status(500).json({ error: 'Internal server error' });

  res.json({ success: true, message: 'Password changed successfully' });
});

// Arrancar server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`TuDu Admin Backend corriendo en puerto ${PORT} usando SUPABASE 🚀`);
  avisarConfiguracion('admin');
});
