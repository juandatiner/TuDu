const express = require('express');
const cors = require('cors');
const path = require('path');
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const app = express();
const PORT = process.env.PORT || 3003;

app.use(cors());
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

app.get('/', (req, res) => {
  res.json({ message: 'TuDu Admin Backend is running via Supabase' });
});

// Login de admin
app.post('/api/admin/login', async (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ error: 'Username and password are required' });
  }

  const { data: row, error } = await supabase
    .from('admins')
    .select('*')
    .eq('username', username)
    .eq('password', password)
    .single();

  if (error || !row) {
    return res.status(401).json({ error: 'Invalid username or password' });
  }

  res.json({
    success: true,
    data: {
      id: row.id,
      username: row.username,
      email: row.email,
      name: row.name,
      role: row.role
    }
  });
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

  const { data, error } = await supabase
    .from('admins')
    .insert([{ username, password, email, name, role }])
    .select()
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
    .select('id')
    .eq('id', id)
    .eq('password', currentPassword)
    .single();

  if (!admin) {
    return res.status(401).json({ error: 'Current password is incorrect' });
  }

  const { error } = await supabase
    .from('admins')
    .update({ password: newPassword, updated_at: new Date().toISOString() })
    .eq('id', id);

  if (error) return res.status(500).json({ error: 'Internal server error' });

  res.json({ success: true, message: 'Password changed successfully' });
});

// Arrancar server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`TuDu Admin Backend corriendo en puerto ${PORT} usando SUPABASE 🚀`);
});
