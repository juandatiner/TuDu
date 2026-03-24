const express = require('express');
const cors = require('cors');
const mailgun = require('mailgun-js');
const compression = require('compression'); // Acelera cargas de Base64 reduciendo 80%
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const http = require('http');
const { Server } = require('socket.io');

const app = express();
app.use(compression());
const PORT = process.env.PORT || 3002;
const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST", "PUT", "DELETE"]
  }
});

// Inicializar Supabase
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error("❌ Faltan credenciales de Supabase en .env");
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

// Socket.io connection handler para monitoreo de Aliados
io.on('connection', (socket) => {
  const auth = socket.handshake.auth || {};
  console.log('--- NUEVA CONEXIÓN SOCKET ---');
  console.log('Recibido Auth:', auth);
  
  let email = auth.email || 'Desconocido';
  let deviceName = 'Cliente Web o Emulador';

  try {
    if (auth.device && typeof auth.device === 'string' && auth.device !== '{}') {
      const devInfo = JSON.parse(auth.device);
      deviceName = devInfo.model || devInfo.name || devInfo.platform || deviceName;
    } else if (auth.device && typeof auth.device === 'object') {
      deviceName = auth.device.model || auth.device.name || auth.device.platform || deviceName;
    }
  } catch(e) {
    console.error('Error parseando device info:', e);
  }

  if (email !== 'Desconocido') {
    console.log(`📱 Conexión en vivo -> Aliado: [${email}] | Equipo: [${deviceName}]`);
  } else {
    console.log(`💻 Conexión en vivo -> Panel o Anónimo | ID: ${socket.id}`);
  }

  socket.on('disconnect', () => {
    if (email !== 'Desconocido') {
      console.log(`🔌 Desconectado -> Aliado: [${email}] | Equipo: [${deviceName}]`);
    } else {
      console.log(`🔌 Desconectado -> Panel o Anónimo`);
    }
  });
});

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

  const { data: ally, error } = await supabase.from('allies').select('id, nombre, apellido, fecha_nacimiento').eq('email', email).single();
  if (error && error.code !== 'PGRST116') return res.status(500).json({ error: 'Error verificando' });

  if (ally && ally.nombre && ally.apellido && ally.fecha_nacimiento) {
    // Si tiene perfil personal, vemos si tiene al menos un servicio creado
    const { data: services } = await supabase.from('ally_service_profiles').select('id').eq('ally_id', ally.id).limit(1);
    
    if (services && services.length > 0) {
      return res.json({ exists: true, ally });
    } else {
      // Tiene datos personales pero no servicios
      return res.json({ exists: false, partial: 'service' });
    }
  } else {
    // No tiene datos personales o están incompletos
    return res.json({ exists: false, partial: 'personal' });
  }
});

app.post('/register-ally', async (req, res) => {
  const { email, nombre, apellido, fecha_nacimiento } = req.body;
  if (!email || !nombre || !apellido) return res.status(400).json({ error: 'Faltan campos' });

  console.log(`📝 Registrando/Actualizando aliado: ${email}`);

  // Usamos upsert para que si ya existe en la tabla 'allies' (por el OTP previo), 
  // simplemente actualicemos sus datos personales.
  const { data, error } = await supabase.from('allies').upsert([{ 
    email, 
    nombre, 
    apellido, 
    fecha_nacimiento: fecha_nacimiento || null,
    updated_at: new Date().toISOString()
  }], { 
    onConflict: 'email',
    ignoreDuplicates: false 
  }).select('id').single();

  if (error) {
    console.error('❌ Error Supabase al registrar aliado:', error);
    return res.status(400).json({ 
      error: `Error guardando datos: ${error.message || 'Error desconocido'}` 
    });
  }

  res.json({ message: 'Aliado registrado correctamente', id: data.id });
});

// Subir documentos KYC
app.post('/ally-kyc', async (req, res) => {
  const { email, cedula_frente, cedula_reverso, selfie } = req.body;
  if (!email) return res.status(400).json({ error: 'Email requerido' });

  const { error } = await supabase.from('allies').update({ 
    kyc_cedula_frente: cedula_frente || null,
    kyc_cedula_reverso: cedula_reverso || null,
    kyc_selfie: selfie || null,
    kyc_status: 'submitted',
    kyc_submitted_at: new Date().toISOString()
  }).eq('email', email);

  if (error) return res.status(500).json({ error: 'Error guardando KYC' });
  res.json({ message: 'Documentos KYC enviados para revisión' });
});

// Guardar perfil del primer servicio del aliado
app.post('/ally-service-profile', async (req, res) => {
  const { email, service_id, nombre_comercial, frase_presentacion, resumen } = req.body;
  if (!email || !service_id) return res.status(400).json({ error: 'Faltan campos' });

  const { error } = await supabase.from('ally_service_profiles').insert([{
    ally_email: email,
    service_id,
    nombre_comercial: nombre_comercial || null,
    frase_presentacion: frase_presentacion || null,
    resumen: resumen || null,
    created_at: new Date().toISOString()
  }]);

  if (error) return res.status(500).json({ error: 'Error guardando perfil de servicio' });
  res.json({ message: 'Perfil de servicio creado exitosamente' });
});



// ==========================================
// 3. SERVICIOS Y ASIGNACIONES
// ==========================================

app.get('/services', async (req, res) => {
  const { data, error } = await supabase.from('services').select('id, name').order('created_at', { ascending: false });
  if (error) return res.status(500).json({ error: 'Error obteniendo servicios' });
  res.json({ services: data || [] });
});

// Crear nuevo servicio (cuando el aliado no encuentra el suyo)
app.post('/services', async (req, res) => {
  const { name } = req.body;
  if (!name || name.trim().length < 2) return res.status(400).json({ error: 'Nombre del servicio requerido' });

  const { data, error } = await supabase.from('services').insert([{ name: name.trim() }]).select('id, name').single();
  if (error) return res.status(500).json({ error: 'Error creando servicio' });
  res.status(201).json({ message: 'Servicio creado', id: data.id, name: data.name });
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

// ==========================================
// 4. SESIONES DE DISPOSITIVO PARA ALIADOS
// ==========================================

app.post('/ally-device-session/check', async (req, res) => {
  const { email, device_id, device_info } = req.body;
  if (!email || !device_id) return res.status(400).json({ error: 'Faltan campos' });

  // Bypass de prueba: Cosmodavid siempre pide OTP para testing, igual que en users
  if (email === 'cosmodavid2009@gmail.com') {
    return res.json({ requires_verification: true, session_active: false });
  }

  const { data: ally } = await supabase.from('allies').select('email').eq('email', email).single();
  if (!ally) return res.status(404).json({ error: 'Aliado no encontrado' });

  const { data: session } = await supabase.from('ally_device_sessions').select('*').eq('ally_email', email).eq('device_id', device_id).single();
  if (session) {
    if (session.is_active === 1) {
      await supabase.from('ally_device_sessions').update({ last_activity: new Date().toISOString() }).eq('id', session.id);
      return res.json({ requires_verification: false, session_active: true });
    } else {
      return res.json({ requires_verification: true, session_active: false });
    }
  } else {
    const { count } = await supabase.from('ally_device_sessions').select('*', { count: 'exact', head: true }).eq('ally_email', email).eq('is_active', 1);
    return res.json({ requires_verification: count > 0, session_active: false });
  }
});

app.post('/ally-device-session/register', async (req, res) => {
  const { email, device_id, device_info } = req.body;
  if (!email || !device_id) return res.status(400).json({ error: 'Faltan campos' });
  
  // 1. Cierra todas las demás sesiones de este aliado
  await supabase.from('ally_device_sessions')
    .update({ is_active: 0 })
    .eq('ally_email', email)
    .neq('device_id', device_id);

  // 2. Registra o actualiza la actual
  const { data: existing } = await supabase.from('ally_device_sessions').select('id').eq('ally_email', email).eq('device_id', device_id).single();
  
  if (existing) {
    await supabase.from('ally_device_sessions').update({ device_info, is_active: 1, last_activity: new Date().toISOString() }).eq('id', existing.id);
  } else {
    await supabase.from('ally_device_sessions').insert([{ ally_email: email, device_id, device_info, is_active: 1, last_activity: new Date().toISOString() }]);
  }

  res.json({ success: true });
});

app.get('/ally-device-session/status', async (req, res) => {
  const { email, device_id } = req.query;
  const { data: session } = await supabase.from('ally_device_sessions').select('is_active').eq('ally_email', email).eq('device_id', device_id).single();
  if (session) {
    res.json({ is_active: session.is_active === 1 });
  } else {
    res.json({ is_active: false });
  }
});

app.post('/ally-device-session/logout', async (req, res) => {
  const { email, device_id } = req.body;
  await supabase.from('ally_device_sessions').update({ is_active: 0 }).eq('ally_email', email).eq('device_id', device_id);
  res.json({ success: true });
});

app.get('/ally-device-session/list', async (req, res) => {
  const { email, current_device_id } = req.query;
  const { data } = await supabase.from('ally_device_sessions').select('*').eq('ally_email', email).order('last_activity', { ascending: false });
  
  const sessions = (data || []).map(row => ({
    id: row.id, device_id: row.device_id, device_info: row.device_info, last_activity: row.last_activity, is_active: row.is_active, is_current: row.device_id === current_device_id
  }));
  res.json({ sessions });
});

app.post('/ally-device-session/close-others', async (req, res) => {
  const { email, keep_device_id } = req.body;
  await supabase.from('ally_device_sessions').update({ is_active: 0 }).eq('ally_email', email).neq('device_id', keep_device_id);
  res.json({ success: true });
});


// Arrancar server permanentemente
server.listen(PORT, '0.0.0.0', () => {
  console.log(`Backend Allies corriendo en puerto ${PORT} usando SUPABASE 🚀`);
});
