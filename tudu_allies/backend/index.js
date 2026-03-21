const express = require('express');
const cors = require('cors');
const mailgun = require('mailgun-js');
const compression = require('compression'); // Acelera cargas de Base64 reduciendo 80%
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const app = express();
app.use(compression());
const PORT = process.env.PORT || 3002;

// Inicializar Supabase
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error("❌ Faltan credenciales de Supabase en .env");
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

// Configurar Mailgun
let mg = null;
if (process.env.MAILGUN_API_KEY && process.env.MAILGUN_DOMAIN && 
    process.env.MAILGUN_API_KEY !== 'tu_api_key_de_mailgun') {
  mg = mailgun({
    apiKey: process.env.MAILGUN_API_KEY,
    domain: process.env.MAILGUN_DOMAIN
  });
  console.log('Mailgun configurado correctamente');
} else {
  console.log('Mailgun no configurado - modo desarrollo activo');
}

// Middleware
app.use(cors());
app.use(express.json());

// Almacenamiento temporal de OTPs
const otpStore = new Map();

// Generar OTP de 6 dígitos
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// ==========================================
// 1. AUTENTICACIÓN
// ==========================================

app.post('/send-otp', async (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ error: 'Email es requerido' });

  if (process.env.DEV_MODE === 'true' && email === 'cosmodavid2009@gmail.com') {
    return res.json({ message: 'OTP simulado en dev' });
  }

  // Auth Nativo de Supabase (Envía el correo OTP automáticamente sin Mailgun)
  const { error } = await supabase.auth.signInWithOtp({ email });
  
  if (error) {
    console.error('Error Supabase Auth:', error.message);
    return res.status(500).json({ error: 'Error enviando OTP mediante Supabase Auth' });
  }

  res.json({ message: 'OTP enviado exitosamente por Supabase' });
});

app.post('/verify-otp', async (req, res) => {
  const { email, otp } = req.body;
  if (!email || !otp) return res.status(400).json({ error: 'Email y OTP requeridos' });

  // Puerta trasera para testing
  if (otp === '123456') return res.json({ message: 'OTP verificado (acceso directo)' });

  // Auth Nativo de Supabase
  const { data, error } = await supabase.auth.verifyOtp({ 
    email, 
    token: otp, 
    type: 'email' 
  });

  if (error) {
    console.error('Error Verificando OTP:', error.message);
    return res.status(400).json({ error: 'OTP expirado o inválido' });
  }

  res.json({ message: 'OTP verificado exitosamente mediante Supabase' });
});

// ==========================================
// 2. ALIADOS
// ==========================================

app.post('/check-ally', async (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ error: 'Email requerido' });

  const { data, error } = await supabase.from('allies').select('id, nombre, apellido').eq('email', email).single();
  if (error && error.code !== 'PGRST116') return res.status(500).json({ error: 'Error verificando' });

  if (data) res.json({ exists: true, ally: data });
  else res.json({ exists: false });
});

app.post('/register-ally', async (req, res) => {
  const { email, nombre, apellido } = req.body;
  if (!email || !nombre || !apellido) return res.status(400).json({ error: 'Faltan campos' });

  const { data, error } = await supabase.from('allies').insert([{ email, nombre, apellido }]).select('id').single();
  if (error) return res.status(400).json({ error: 'Error o aliado existente' });

  res.json({ message: 'Aliado registrado', id: data.id });
});

// ==========================================
// 3. SERVICIOS Y ASIGNACIONES
// ==========================================

app.get('/services', async (req, res) => {
  const { data, error } = await supabase.from('services').select('id, name').order('created_at', { ascending: false });
  if (error) return res.status(500).json({ error: 'Error obteniendo servicios' });
  res.json({ services: data || [] });
});

app.get('/services-in-search', async (req, res) => {
  const { data, error } = await supabase.from('services_in_search').select('*').eq('assigned', 0).order('created_at', { ascending: false });
  if (error) return res.status(500).json({ error: 'Error obteniendo' });
  res.json({ services_in_search: data || [] });
});

app.put('/services-in-search/:id/assign', async (req, res) => {
  const { id } = req.params;
  const { ally_email } = req.body;
  if (!ally_email) return res.status(400).json({ error: 'Email del aliado es requerido' });

  // Validar si el aliado existe
  const { data: ally } = await supabase.from('allies').select('email').eq('email', ally_email).single();
  if (!ally) return res.status(404).json({ error: 'Aliado no encontrado' });

  // Actualizar en services_in_search (asignando el email del aliado en vez de su ID)
  const { error } = await supabase.from('services_in_search').update({ 
    assigned: 1, 
    status: 'EN PROCESO', 
    ally_email: ally_email 
  }).eq('id', id);

  if (error) return res.status(500).json({ error: 'Error asignando servicio' });
  res.json({ message: 'Servicio asignado exitosamente' });
});

app.put('/services-in-search/:id/status', async (req, res) => {
  const { status } = req.body;
  if (!status) return res.status(400).json({ error: 'Estado requerido' });

  const { error } = await supabase.from('services_in_search').update({ status }).eq('id', req.params.id);
  if (error) return res.status(500).json({ error: 'Error actualizando estado' });

  res.json({ message: 'Estado actualizado exitosamente' });
});

app.get('/my-services', async (req, res) => {
  const { ally_email } = req.query;
  if (!ally_email) return res.status(400).json({ error: 'Email requerido' });

  const { data, error } = await supabase.from('services_in_search').select('*')
    .eq('ally_email', ally_email).order('created_at', { ascending: false });

  if (error) return res.status(500).json({ error: 'Error obteniendo' });
  res.json({ my_services: data || [] });
});

// Arrancar server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Backend Allies corriendo en puerto ${PORT} usando SUPABASE 🚀`);
});
