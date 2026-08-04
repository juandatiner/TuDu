const express = require('express');
const cors = require('cors');
const path = require('path');
require('dotenv').config();
const http = require('http');
const { Server } = require('socket.io');
const { createClient } = require('@supabase/supabase-js');
const compression = require('compression'); // Compresión Zlib para B64

const app = express();
const PORT = process.env.PORT || 3000;
const server = http.createServer(app);

app.use(compression()); // Comprime los inmensos JSON con Base64 hasta un 80% antes de enviarlos por red
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

const { signSession, requireAuth, createRefreshHandler, authenticateSocket } = require('./auth');

// Código maestro de desarrollo. Solo sirve con DEV_MODE=true.
const OTP_DEV = process.env.DEV_OTP || '123456';

// Rutas que se pueden llamar SIN token, porque son justo las que sirven para
// obtenerlo o son catálogos públicos sin datos personales.
const RUTAS_PUBLICAS = [
  '/send-otp',
  '/verify-otp',
  '/check-user',
  '/check-ally',
  '/departments',
  '/cities',
  '/countries',
  '/services',
  '/search-services',
  '/device-session/check',
  '/auth/refresh'
];

function esRutaPublica(path) {
  return RUTAS_PUBLICAS.some(r => path === r || path.startsWith(r + '/'));
}

// Campos por los que un endpoint identifica al dueño de los datos.
const CAMPOS_DUENO = ['email', 'user_email', 'userEmail', 'ally_email'];

// 1. Todo lo que no sea ruta pública exige token válido.
app.use((req, res, next) => {
  if (esRutaPublica(req.path)) return next();
  return requireAuth(req, res, next);
});

// 2. Con token en mano, nadie puede operar sobre el correo de otro.
//    El rol `admin` sí puede: el panel gestiona cuentas ajenas por definición.
app.use((req, res, next) => {
  if (esRutaPublica(req.path) || !req.auth) return next();
  if (req.auth.role === 'admin') return next();

  const propio = String(req.auth.email).toLowerCase();

  const fuentes = { ...req.query, ...req.body };
  for (const campo of CAMPOS_DUENO) {
    const valor = fuentes[campo];
    if (valor && String(valor).toLowerCase() !== propio) {
      return res.status(403).json({ error: 'No puedes operar sobre otra cuenta', code: 'FORBIDDEN' });
    }
  }

  // Los emails que viajan en la URL (`/users/profile/:email`, `/users/:email`,
  // `/users/cards/:userEmail`) no están en req.params todavía: este middleware
  // corre antes de que Express resuelva la ruta. Se leen del path directamente.
  for (const segmento of decodeURIComponent(req.path).split('/')) {
    if (segmento.includes('@') && segmento.toLowerCase() !== propio) {
      return res.status(403).json({ error: 'No puedes operar sobre otra cuenta', code: 'FORBIDDEN' });
    }
  }

  next();
});

/// Comprueba que la FILA sobre la que se opera pertenezca a quien pide.
///
/// Los middlewares de arriba solo miran el correo cuando viaja en el cuerpo, la
/// query o la URL. Los endpoints que operan por `:id` (tarjetas, direcciones,
/// historial…) no lo llevan: sin esto, cualquiera con un token válido podía
/// borrar la tarjeta de otro probando números de id.
function requireOwnRow(tabla, columnaDueno = 'user_email') {
  return async (req, res, next) => {
    if (req.auth && req.auth.role === 'admin') return next();

    const { data, error } = await supabase
      .from(tabla)
      .select(columnaDueno)
      .eq('id', req.params.id)
      .single();

    if (error || !data) {
      return res.status(404).json({ error: 'No encontrado', code: 'NOT_FOUND' });
    }

    if (String(data[columnaDueno]).toLowerCase() !== String(req.auth.email).toLowerCase()) {
      return res.status(403).json({ error: 'No puedes operar sobre otra cuenta', code: 'FORBIDDEN' });
    }

    next();
  };
}

// 3. El área de administración exige rol admin, no basta con estar logueado.
app.use('/api/admin', (req, res, next) => {
  if (req.auth && req.auth.role === 'admin') return next();
  return res.status(403).json({ error: 'Se requiere rol de administrador', code: 'NOT_ADMIN' });
});

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

// El socket ya no acepta a cualquiera: exige el mismo JWT que la API REST.
io.use(authenticateSocket);

/// Sala privada de un dispositivo concreto. Permite avisarle solo a él que su
/// sesión fue cerrada, sin molestar a los demás equipos de la misma cuenta.
function salaDispositivo(email, deviceId) {
  return `device:${String(email).toLowerCase()}:${deviceId}`;
}

// Socket.io connection handler
io.on('connection', (socket) => {
  const auth = socket.handshake.auth || {};
  const email = socket.data.auth.email;
  const deviceId = socket.data.auth.device_id || auth.device_id;
  let deviceName = 'Cliente Web o Emulador';

  try {
    if (auth.device && auth.device !== '{}') {
      const devInfo = JSON.parse(auth.device);
      deviceName = devInfo.model || devInfo.name || devInfo.platform || deviceName;
    }
  } catch(e) {}

  // Sala por cuenta (avisos generales) y sala por dispositivo (cierre de sesión).
  socket.join(`user:${String(email).toLowerCase()}`);
  if (deviceId) socket.join(salaDispositivo(email, deviceId));

  console.log(`📱 Conexión en vivo -> Usuario: [${email}] | Equipo: [${deviceName}] | Rol: ${socket.data.auth.role}`);

  socket.on('disconnect', () => {
    console.log(`🔌 Desconectado -> Usuario: [${email}] | Equipo: [${deviceName}]`);
  });
});

// ==========================================
// 1. AUTENTICACIÓN Y REGISTRO
// ==========================================

app.post('/send-otp', async (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ error: 'Email es requerido' });

  // MODO DESARROLLO: no se manda ningún correo y se entra con el OTP maestro.
  // Se activa solo con DEV_MODE=true en el .env, que NUNCA debe estar puesto
  // en el servidor de producción.
  if (process.env.DEV_MODE === 'true') {
    console.log(`🔓 DEV_MODE: OTP omitido para ${email} — usar el código ${OTP_DEV}`);
    return res.json({ message: 'OTP simulado en modo desarrollo', dev_mode: true });
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
  const { email, otp, device_id } = req.body;
  if (!email || !otp) return res.status(400).json({ error: 'Email y OTP requeridos' });

  // MODO DESARROLLO: el OTP maestro entra con cualquier correo.
  // Protegido por DEV_MODE — con la variable apagada este atajo no existe.
  if (process.env.DEV_MODE === 'true' && otp === OTP_DEV) {
    return res.json({
      message: 'OTP verificado en modo desarrollo',
      ...signSession({ email, role: 'user', device_id }),
      dev_mode: true
    });
  }

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

  // A partir de acá la identidad está probada: se emite el token que el cliente
  // mandará en `Authorization: Bearer` en todas las peticiones siguientes.
  res.json({
    message: 'OTP verificado exitosamente mediante Supabase',
    ...signSession({ email, role: 'user', device_id })
  });
});

/// Canjea el refresh token por un acceso nuevo.
///
/// No basta con que el refresh sea válido: la sesión de ese dispositivo tiene
/// que seguir activa en `device_sessions`. Así, cerrar sesión desde otro equipo
/// corta de verdad al intruso en cuanto vence su token de acceso.
app.post('/auth/refresh', createRefreshHandler(async ({ email, device_id }) => {
  if (!device_id) return false;

  const { data } = await supabase
    .from('device_sessions')
    .select('is_active, last_activity')
    .eq('user_email', email)
    .eq('device_id', device_id)
    .single();

  if (!data || data.is_active !== 1) return false;
  return data.last_activity >= fechaLimiteSesion();
}));

app.post('/check-user', async (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ error: 'Email es requerido' });

  const { data, error } = await supabase.from('users').select('id, nombre, apellido').eq('email', email).single();
  if (error && error.code !== 'PGRST116') return res.status(500).json({ error: 'Error verificando usuario' });

  if (data) res.json({ exists: true, user: data });
  else res.json({ exists: false });
});

app.post('/check-ally', async (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ error: 'Email es requerido' });

  const { data, error } = await supabase.from('allies').select('id, nombre, apellido').eq('email', email).single();
  if (error && error.code !== 'PGRST116') return res.status(500).json({ error: 'Error verificando aliado' });

  if (data) res.json({ exists: true, ally: data });
  else res.json({ exists: false });
});

app.post('/register-user', async (req, res) => {
  const { email, nombre, apellido } = req.body;
  if (!email || !nombre || !apellido) return res.status(400).json({ error: 'Faltan campos' });

  const { data, error } = await supabase.from('users').insert([{ email, nombre, apellido }]).select('id').single();
  if (error) return res.status(400).json({ error: 'Error registrando o usuario ya existe' });

  res.json({ message: 'Usuario registrado', id: data.id });
});

app.post('/register-ally', async (req, res) => {
  const { email, nombre, apellido } = req.body;
  if (!email || !nombre || !apellido) return res.status(400).json({ error: 'Faltan campos' });

  const { data, error } = await supabase.from('allies').insert([{ email, nombre, apellido }]).select('id').single();
  if (error) return res.status(400).json({ error: 'Error registrando o aliado ya existe' });

  res.json({ message: 'Aliado registrado', id: data.id });
});

// ==========================================
// 2. PERFIL DE USUARIO Y FOTOS
// ==========================================

app.get('/users/profile/:email', async (req, res) => {
  const { email } = req.params;
  if (!email) return res.status(400).json({ error: 'Email requerido' });

  const selectFields = req.query.lite === 'true'
    ? 'nombre, apellido, avatar_color, avatar_icon, phone, genero, fecha_nacimiento, dark_mode, language'
    : '*';

  const [userRes, phoneRes] = await Promise.all([
    supabase.from('users').select(selectFields).eq('email', email).single(),
    supabase.from('user_phones').select('*').eq('user_email', email).single()
  ]);
  
  const user = userRes.data;
  if (userRes.error || !user) return res.status(404).json({ error: 'Usuario no encontrado' });
  const phone = phoneRes.data;

  res.json({
    nombre: user.nombre,
    apellido: user.apellido,
    avatar_color: user.avatar_color,
    avatar_icon: user.avatar_icon,
    avatar_image: user.avatar_image,
    phone: user.phone,
    genero: user.genero,
    fecha_nacimiento: user.fecha_nacimiento,
    dark_mode: user.dark_mode === 1,
    language: user.language,
    country_code: phone ? phone.country_code : null,
    country_name: phone ? phone.country_name : null,
    phone_number: phone ? phone.phone_number : null
  });
});

app.put('/users/profile/avatar', async (req, res) => {
  const { email, avatar_color, avatar_icon, avatar_image } = req.body;
  if (!email) return res.status(400).json({ error: 'Email requerido' });

  let updateData = {};
  if (avatar_image === null) {
    if (avatar_color) updateData.avatar_color = avatar_color;
    if (avatar_icon) updateData.avatar_icon = avatar_icon;
    updateData.avatar_image = null;
  } else if (avatar_image !== undefined) {
    updateData.avatar_image = avatar_image;
    updateData.avatar_color = '#78BF32';
    updateData.avatar_icon = 'person';
  }

  if (Object.keys(updateData).length === 0) return res.status(400).json({ error: 'Sin datos' });

  const { error } = await supabase.from('users').update(updateData).eq('email', email);
  if (error) return res.status(500).json({ error: 'Error actualizando avatar' });

  res.json({ message: 'Avatar actualizado' });
});

app.put('/users/profile/data', async (req, res) => {
  const { email, nombre, apellido, phone, country_code, country_name, phone_number, genero, fecha_nacimiento } = req.body;
  if (!email) return res.status(400).json({ error: 'Email requerido' });

  let userUpdates = {};
  if (nombre) userUpdates.nombre = nombre;
  if (apellido) userUpdates.apellido = apellido;
  if (phone) userUpdates.phone = phone;
  if (genero) userUpdates.genero = genero;
  if (fecha_nacimiento) userUpdates.fecha_nacimiento = fecha_nacimiento;

  if (Object.keys(userUpdates).length > 0) {
    await supabase.from('users').update(userUpdates).eq('email', email);
  }

  if (country_code && phone_number) {
    // Upsert nativo de Supabase — 1 sola query, usa la constraint UNIQUE de user_email
    await supabase.from('user_phones').upsert(
      { user_email: email, country_code, country_name, phone_number },
      { onConflict: 'user_email' }
    );
  }
  res.json({ message: 'Datos actualizados' });
});

// ==========================================
// 3. LIMPIEZA DE FOTOS (PETICIÓN ESPECIAL)
// ==========================================

// Limpia automáticamente las viejas request_photos marcadas como notificadas para no ocupar espacio base64
async function cleanupOldPhotoRequests() {
  const { data, error } = await supabase
    .from('photo_change_requests')
    .delete()
    .eq('user_notified', true)
    .select('id');
  
  if (!error && data && data.length > 0) {
    console.log(`🧹 LIMPIEZA: Se borraron ${data.length} historiales inútiles de cambios de foto.`);
  }
}
/// Los trabajos periódicos de verdad viven en la base (pg_cron), no acá:
/// ver `supabase/cron.sql`. Un `setInterval` muere con el proceso y se duplica
/// si hay más de una instancia del backend.
///
/// Este respaldo en proceso solo se activa con MANTENIMIENTO_EN_PROCESO=true,
/// pensado para desarrollo local, donde no hay cron corriendo.
const MANTENIMIENTO_EN_PROCESO = process.env.MANTENIMIENTO_EN_PROCESO === 'true';

function programarMantenimiento(nombre, tarea) {
  if (!MANTENIMIENTO_EN_PROCESO) return;
  tarea();
  setInterval(tarea, 1000 * 60 * 60);
  console.log(`⏱  Mantenimiento en proceso activo: ${nombre} (cada hora). En producción esto lo hace pg_cron.`);
}

programarMantenimiento('limpieza de fotos', cleanupOldPhotoRequests);

// Una sesión sin actividad durante este tiempo se considera muerta y pide OTP otra vez.
// Solo caduca la sesión: NO se borra nada del usuario ni de sus servicios publicados.
const SESSION_MAX_IDLE_DAYS = 180;

function fechaLimiteSesion() {
  return new Date(Date.now() - SESSION_MAX_IDLE_DAYS * 24 * 60 * 60 * 1000).toISOString();
}

// Cierra las sesiones que llevan más de SESSION_MAX_IDLE_DAYS sin usarse.
async function expirarSesionesInactivas() {
  const { data, error } = await supabase
    .from('device_sessions')
    .update({ is_active: 0 })
    .eq('is_active', 1)
    .lt('last_activity', fechaLimiteSesion())
    .select('id');

  if (!error && data && data.length > 0) {
    console.log(`🧹 SESIONES: ${data.length} sesiones caducadas por ${SESSION_MAX_IDLE_DAYS} días sin actividad.`);
  }
}
programarMantenimiento('caducidad de sesiones', expirarSesionesInactivas);

// Endpoint para obtener si hay notificaciones pendientes (y limpiar tras notificar)
app.get('/api/user/photo-change-request/unnotified', async (req, res) => {
  const { user_email } = req.query;
  const { data, error } = await supabase
    .from('photo_change_requests')
    .select('*')
    .eq('user_email', user_email)
    .neq('status', 'pending')
    .eq('user_notified', false)
    .limit(1)
    .single();

  res.json({ success: true, data: data || null });
});

app.put('/api/user/photo-change-request/mark-notified/:id', requireOwnRow('photo_change_requests'), async (req, res) => {
  const { id } = req.params;
  await supabase.from('photo_change_requests').update({ user_notified: true }).eq('id', id);
  
  // Limpiar inmediatamente después de notificar para mantener ligera la DB
  cleanupOldPhotoRequests();
  
  res.json({ success: true, message: 'Notificado' });
});

app.post('/api/user/photo-change-request', async (req, res) => {
  const { user_email, new_avatar_image } = req.body;
  if (!user_email || !new_avatar_image) return res.status(400).json({ error: 'Faltan datos' });

  // Borrar previas pendientes
  await supabase.from('photo_change_requests').delete().eq('user_email', user_email).eq('status', 'pending');
  
  const { data, error } = await supabase.from('photo_change_requests')
    .insert([{ user_email, new_avatar_image, status: 'pending' }]).select().single();
    
  if (error) return res.status(500).json({ error: 'Error creando solicitud' });

  // Notificar al admin via socket
  io.emit('newPhotoChangeRequest', data);
  res.json({ success: true, data });
});

// ==========================================
// 4. DIRECCIONES Y UBICACIONES
// ==========================================

app.get('/departments', async (req, res) => {
  const { data, error } = await supabase.from('departments').select('id, name').order('name');
  res.json({ departments: data || [] });
});

app.get('/cities', async (req, res) => {
  const { department_id } = req.query;
  if (!department_id) return res.status(400).json({ error: 'ID departamento requerido' });

  const { data, error } = await supabase.from('cities').select('id, name').eq('department_id', department_id).order('name');
  res.json({ cities: data || [] });
});

app.get('/countries', async (req, res) => {
  const { data } = await supabase.from('countries').select('*').order('name');
  res.json(data || []);
});

app.get('/user-addresses', async (req, res) => {
  const { user_email } = req.query;
  
  // En Supabase podemos hacer JOIN muy fácil usando sintaxis anidada:
  const { data, error } = await supabase
    .from('user_addresses')
    .select(`*, departments ( name ), cities ( name )`)
    .eq('user_email', user_email)
    .order('created_at', { ascending: true });

  if (error) return res.status(500).json({ error: 'Error obteniendo direcciones' });

  // Formatear igual que expected backend anterior
  const addresses = data.map(addr => ({
    ...addr,
    department_name: addr.departments?.name,
    city_name: addr.cities?.name
  }));
  
  res.json({ addresses });
});


// ==========================================
// 5. DIRECCIONES CRUD COMPLETO
// ==========================================

const hasNumber = (str) => /\d/.test(str || '');

app.post('/user-addresses', async (req, res) => {
  const { user_email, address_name, department_id, city_id, type_via, number_principal, number_secondary, number_final, additional_info, address_icon } = req.body;
  if (!user_email || !address_name || !department_id || !city_id || !type_via || !number_principal) {
    return res.status(400).json({ error: 'Faltan campos requeridos' });
  }
  if (!hasNumber(number_principal)) return res.status(400).json({ error: 'Número principal inválido' });

  // Validar si existe una dirección con el mismo nombre
  const { data: existingName } = await supabase.from('user_addresses').select('id').eq('user_email', user_email).eq('address_name', address_name).single();
  if (existingName) return res.status(400).json({ error: 'Ya existe una direccion con este nombre' });

  const { data, error } = await supabase.from('user_addresses').insert([{
    user_email, address_name, department_id, city_id, type_via, number_principal, number_secondary, number_final, additional_info, address_icon
  }]).select().single();
  
  if (error) return res.status(500).json({ error: 'Error agregando dirección' });
  res.json({ message: 'Direccion agregada exitosamente', id: data.id });
});

app.put('/user-addresses/:id', requireOwnRow('user_addresses'), async (req, res) => {
  const { id } = req.params;
  const { address_name, department_id, city_id, type_via, number_principal, number_secondary, number_final, additional_info, address_icon } = req.body;
  
  if (!hasNumber(number_principal)) return res.status(400).json({ error: 'Número principal inválido' });

  // Validar propiedad y duplicidad
  const { data: address } = await supabase.from('user_addresses').select('user_email').eq('id', id).single();
  if (!address) return res.status(404).json({ error: 'Dirección no encontrada' });

  const { data: exist } = await supabase.from('user_addresses').select('id').eq('user_email', address.user_email).eq('address_name', address_name).neq('id', id).single();
  if (exist) return res.status(400).json({ error: 'Ya existe una direccion con este nombre' });

  await supabase.from('user_addresses').update({
    address_name, department_id, city_id, type_via, number_principal, number_secondary, number_final, additional_info, address_icon
  }).eq('id', id);

  res.json({ message: 'Direccion actualizada exitosamente' });
});

app.delete('/user-addresses/:id', requireOwnRow('user_addresses'), async (req, res) => {
  const { error } = await supabase.from('user_addresses').delete().eq('id', req.params.id);
  if (error) return res.status(500).json({ error: 'Error al eliminar' });
  res.json({ message: 'Direccion eliminada exitosamente' });
});

// ==========================================
// 6. TARJETAS DE USUARIO
// ==========================================

app.get('/users/cards/:userEmail', async (req, res) => {
  const { data, error } = await supabase.from('user_cards').select('*').eq('user_email', req.params.userEmail).order('is_default', { ascending: false }).order('created_at', { ascending: false });
  if (error) return res.status(500).json({ error: 'Error obteniendo tarjetas' });
  res.json(data || []);
});

app.post('/users/cards', async (req, res) => {
  const { user_email, card_number, card_holder, expiry_date, card_type, document_type, document_number, card_mode, is_default } = req.body;
  
  if (!user_email || !card_number || !card_holder || !expiry_date) return res.status(400).json({ error: 'Faltan campos' });

  const normalizedCard = card_number.replace(/\s+/g, '');
  const { data: exist } = await supabase.from('user_cards').select('id').eq('user_email', user_email).like('card_number', `%${normalizedCard.slice(-4)}`).single(); // Simplificado para check de existencia aprox
  if (exist) return res.status(400).json({ error: 'Ya existe una tarjeta similar' });

  const { count } = await supabase.from('user_cards').select('*', { count: 'exact', head: true }).eq('user_email', user_email);
  const isFirstCard = count === 0;
  const finalIsDefault = isFirstCard ? 1 : (is_default ? 1 : 0);

  if (finalIsDefault) await supabase.from('user_cards').update({ is_default: 0 }).eq('user_email', user_email);

  const maskedCard = `**** **** **** ${normalizedCard.slice(-4)}`;

  const { data, error } = await supabase.from('user_cards').insert([{
    user_email, card_number: maskedCard, card_holder, expiry_date, card_type: card_type || 'visa', document_type: document_type || 'C.C', document_number, card_mode: card_mode || 'credit', is_default: finalIsDefault
  }]).select('id').single();

  if (error) return res.status(500).json({ error: 'Error guardando tarjeta' });
  res.json({ success: true, message: 'Tarjeta guardada', id: data.id, is_first_card: isFirstCard });
});

app.delete('/users/cards/:id', requireOwnRow('user_cards'), async (req, res) => {
  const { error } = await supabase.from('user_cards').delete().eq('id', req.params.id);
  if (error) return res.status(500).json({ error: 'Error eliminando tarjeta' });
  res.json({ message: 'Tarjeta eliminada exitosamente' });
});

app.put('/users/cards/:id/default', requireOwnRow('user_cards'), async (req, res) => {
  const { user_email } = req.body;
  if (!user_email) return res.status(400).json({ error: 'Email requerido' });

  await supabase.from('user_cards').update({ is_default: 0 }).eq('user_email', user_email);
  await supabase.from('user_cards').update({ is_default: 1 }).eq('id', req.params.id);
  res.json({ message: 'Tarjeta establecida como predeterminada' });
});

// ==========================================
// 7. SERVICIOS Y BÚSQUEDAS (PUBLICACIÓN)
// ==========================================

app.get('/services', async (req, res) => {
  const { data, error } = await supabase.from('services').select('id, name').order('created_at', { ascending: false });
  res.json({ services: data || [] });
});

app.post('/publish-service', async (req, res) => {
  const { user_email, title, description, time_quantity, time_unit, budget, worker_info } = req.body;
  
  // Parsear budget a entero redondeado (como estaba en SQLite)
  const numericBudget = parseFloat(budget.toString().replace(/,/g, '').replace(/\./g, ''));
  const roundedBudget = Math.round(numericBudget / 100) * 100;
  const formattedBudget = roundedBudget.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');

  const { data, error } = await supabase.from('services_in_search').insert([{
    user_email, title, description, time_quantity, time_unit, budget: formattedBudget, worker_info, status: 'EN ESPERA'
  }]).select('id').single();

  if (error) return res.status(500).json({ error: 'Error publicando' });
  res.json({ message: 'Servicio publicado', id: data.id });
});

app.get('/services-in-search', async (req, res) => {
  const { user_email } = req.query;
  let query = supabase.from('services_in_search').select('*').eq('assigned', 0).order('created_at', { ascending: false });
  if (user_email) query = query.eq('user_email', user_email);

  const { data, error } = await query;
  res.json({ services_in_search: data || [] });
});

app.put('/services-in-search/:id/assign', async (req, res) => {
  const { error } = await supabase.from('services_in_search').update({ assigned: 1, status: 'En Proceso' }).eq('id', req.params.id);
  if (error) return res.status(500).json({ error: 'Error asignando' });
  res.json({ message: 'Asignado exitosamente' });
});

app.delete('/services-in-search/:id', requireOwnRow('services_in_search'), async (req, res) => {
  const { user_email } = req.query;
  if (!user_email) return res.status(400).json({ error: 'Email requerido' });

  const { error } = await supabase.from('services_in_search').delete().eq('id', req.params.id).eq('user_email', user_email);
  if (error) return res.status(500).json({ error: 'Error borrando' });
  res.json({ message: 'Eliminado exitosamente' });
});

app.put('/services-in-search/:id/status', requireOwnRow('services_in_search'), async (req, res) => {
  const { status } = req.body;
  const { error } = await supabase.from('services_in_search').update({ status }).eq('id', req.params.id);
  if (error) return res.status(500).json({ error: 'Error actualizando estado' });
  res.json({ message: 'Estado actualizado' });
});


// ==========================================
// 8. BÚSQUEDAS RECIENTES
// ==========================================

app.post('/search-history', async (req, res) => {
  const { user_email, search_query } = req.body;
  if (!user_email || !search_query) return res.status(400).json({ error: 'Faltan campos' });

  // Delete first to maintain unique search history without conflict
  await supabase.from('search_history').delete().eq('user_email', user_email).eq('query', search_query);
  
  const { data, error } = await supabase.from('search_history').insert([{ user_email, query: search_query }]).select('id').single();
  if (error) return res.status(500).json({ error: 'Error guardando búsqueda' });
  
  res.json({ message: 'Busqueda guardada exitosamente', id: data.id });
});

app.get('/search-history', async (req, res) => {
  const { user_email } = req.query;
  const { data, error } = await supabase.from('search_history').select('*').eq('user_email', user_email).order('created_at', { ascending: false }).limit(10);
  if (error) return res.status(500).json({ error: 'Error obteniendo' });

  // Map back property name purely for client compatibility
  res.json({ search_history: (data || []).map(r => ({ ...r, search_query: r.query })) });
});

app.delete('/search-history/:id', requireOwnRow('search_history'), async (req, res) => {
  const { error } = await supabase.from('search_history').delete().eq('id', req.params.id);
  if (error) return res.status(500).json({ error: 'Error eliminando' });
  res.json({ message: 'Eliminado exitosamente' });
});

app.get('/search-services', async (req, res) => {
  const { query } = req.query;
  if (!query) return res.status(400).json({ error: 'Consulta requerida' });

  // Insensible case search
  const { data, error } = await supabase.from('services').select('id, name').ilike('name', `%${query}%`);
  res.json({ services: data || [] });
});

// ==========================================
// 9. ADMIN Y MAS RUTAS DE FOTOS
// ==========================================

app.get('/api/admin/photo-change-requests', async (req, res) => {
  const { data, error } = await supabase
    .from('photo_change_requests')
    .select(`*, users ( nombre, apellido, avatar_image )`)
    .order('created_at', { ascending: false });
    
  if (error) return res.status(500).json({ error: 'Error interno' });

  // Map para mantener exactamente la estructura original SQLite que esperaba el ADMIN frontend
  const requests = (data || []).map(row => ({
    id: row.id,
    user_email: row.user_email,
    new_avatar_image: row.new_avatar_image,
    status: row.status,
    read: row.read_at !== null,
    created_at: row.created_at,
    nombre: row.users?.nombre,
    apellido: row.users?.apellido,
    avatar_image: row.users?.avatar_image,
    read_at: row.read_at,
    rejection_reason: row.rejection_reason,
    user_notified: row.user_notified
  }));
  res.json({ success: true, data: requests });
});

app.put('/api/admin/photo-change-requests/:id', async (req, res) => {
  const { id } = req.params;
  const { status, rejection_reason } = req.body;
  
  if (!['approved', 'rejected'].includes(status)) return res.status(400).json({ error: 'Acción inválida' });

  const { data: request, error: fetchErr } = await supabase.from('photo_change_requests').select('*').eq('id', id).single();
  if (fetchErr || !request) return res.status(404).json({ error: 'No encontrado' });

  // Actualizar tabla requests
  await supabase.from('photo_change_requests').update({ status, rejection_reason: rejection_reason || null, updated_at: new Date().toISOString() }).eq('id', id);

  if (status === 'approved') {
    await supabase.from('users').update({ avatar_image: request.new_avatar_image, avatar_color: '#78BF32', avatar_icon: 'person' }).eq('email', request.user_email);
    io.emit('photoRequestUpdated', { 
      id: parseInt(id), 
      user_email: request.user_email, 
      status: 'approved', 
      new_avatar_image: request.new_avatar_image // Crítico para Flutter Provider
    });
  } else {
    io.emit('photoRequestUpdated', { id: parseInt(id), user_email: request.user_email, status: 'rejected', rejection_reason });
  }
  
  res.json({ success: true, message: `Solicitud ${status}` });
});

app.put('/api/admin/photo-change-requests/:id/read', async (req, res) => {
  await supabase.from('photo_change_requests').update({ read_at: new Date().toISOString() }).eq('id', req.params.id).eq('status', 'pending').is('read_at', null);
  res.json({ success: true });
});

app.get('/api/user/photo-change-request/pending', async (req, res) => {
  const { user_email } = req.query;
  const { data } = await supabase.from('photo_change_requests')
    .select('id, status, rejection_reason, created_at')
    .eq('user_email', user_email)
    .eq('status', 'pending')
    .limit(1)
    .single();
    
  res.json({ success: true, data: data || null });
});

app.delete('/users/:email', async (req, res) => {
  const { email } = req.params;
  // Supabase takes care of cascade deleting if FK constraints are set perfectly, 
  // but let's delete explicitly logic just in case if FK lacks ON DELETE CASCADE
  await supabase.from('user_addresses').delete().eq('user_email', email);
  await supabase.from('user_phones').delete().eq('user_email', email);
  await supabase.from('photo_change_requests').delete().eq('user_email', email);
  await supabase.from('user_cards').delete().eq('user_email', email);
  await supabase.from('device_sessions').delete().eq('user_email', email);
  await supabase.from('search_history').delete().eq('user_email', email);
  
  const { error } = await supabase.from('users').delete().eq('email', email);
  if (error) return res.status(500).json({ success: false, message: 'Error eliminando' });
  res.json({ success: true, message: 'Cuenta eliminada' });
});

// ==========================================
// 10. SESIONES DE DISPOSITIVO
// ==========================================

app.post('/device-session/check', async (req, res) => {
  const { email, device_id, device_info } = req.body;
  if (!email || !device_id) return res.status(400).json({ error: 'Faltan campos' });

  const { data: user } = await supabase.from('users').select('id').eq('email', email).single();
  if (!user) return res.status(404).json({ error: 'Usuario no encontrado' });

  const { data: session } = await supabase.from('device_sessions').select('*').eq('user_email', email).eq('device_id', device_id).single();
  if (session) {
    // Caducada por inactividad: se cierra en el momento, sin esperar al job horario.
    if (session.is_active === 1 && session.last_activity < fechaLimiteSesion()) {
      await supabase.from('device_sessions').update({ is_active: 0 }).eq('id', session.id);
      return res.json({ requires_verification: true, session_active: false, expired: true });
    }

    if (session.is_active === 1) {
      await supabase.from('device_sessions').update({ last_activity: new Date().toISOString() }).eq('id', session.id);
      return res.json({ requires_verification: false, session_active: true });
    }

    return res.json({ requires_verification: true, session_active: false });
  }

  // Dispositivo desconocido: siempre OTP. Cubre el primer ingreso y también
  // el caso de desinstalar/reinstalar la app, que borra el device_id local y
  // por lo tanto debe tratarse como un dispositivo nuevo.
  const { count } = await supabase.from('device_sessions')
    .select('id', { count: 'exact', head: true })
    .eq('user_email', email)
    .eq('is_active', 1);

  return res.json({ requires_verification: true, session_active: false, has_other_sessions: count > 0 });
});

app.post('/device-session/register', async (req, res) => {
  const { email, device_id, device_info } = req.body;
  
  // 1. Cierra automáticamente cualquier otra sesión vieja de este correo
  const { data: desplazadas } = await supabase.from('device_sessions')
    .update({ is_active: 0 })
    .eq('user_email', email)
    .neq('device_id', device_id)
    .eq('is_active', 1)
    .select('device_id');

  // 2. Upsert del dispositivo que acaba de acceder — 1 sola query
  await supabase.from('device_sessions').upsert(
    { user_email: email, device_id, device_info, is_active: 1, last_activity: new Date().toISOString() },
    { onConflict: 'user_email,device_id' }
  );

  // 3. Avisar en el acto a los equipos desplazados, en vez de que ellos
  //    pregunten cada 30 segundos. El aviso llega solo a su sala.
  for (const s of desplazadas || []) {
    io.to(salaDispositivo(email, s.device_id)).emit('sessionClosed', {
      reason: 'other_device',
      device_id: s.device_id
    });
  }

  res.json({ success: true, closed_sessions: (desplazadas || []).length });
});

app.get('/device-session/status', async (req, res) => {
  const { email, device_id } = req.query;
  const { data: session } = await supabase.from('device_sessions').select('id, is_active, last_activity').eq('user_email', email).eq('device_id', device_id).single();

  if (session && session.is_active === 1 && session.last_activity < fechaLimiteSesion()) {
    // Caducó por inactividad: no es un cierre remoto, es tiempo cumplido.
    await supabase.from('device_sessions').update({ is_active: 0 }).eq('id', session.id);
    return res.json({ is_active: false, closed_remotely: false, expired: true });
  }

  if (session && session.is_active === 1) {
    return res.json({ is_active: true, closed_remotely: false });
  }

  // Solo es un cierre remoto si OTRO dispositivo tiene la sesión activa ahora mismo.
  // Sin fila, o sin ningún otro activo, es simplemente "no hay sesión": el cliente
  // debe volver al login sin acusar de que entraron desde otro lado.
  const { count } = await supabase.from('device_sessions')
    .select('id', { count: 'exact', head: true })
    .eq('user_email', email)
    .eq('is_active', 1)
    .neq('device_id', device_id);

  res.json({ is_active: false, closed_remotely: count > 0 });
});

app.post('/device-session/logout', async (req, res) => {
  const { email, device_id } = req.body;
  await supabase.from('device_sessions').update({ is_active: 0 }).eq('user_email', email).eq('device_id', device_id);
  res.json({ success: true });
});

app.get('/device-session/list', async (req, res) => {
  const { email, current_device_id } = req.query;
  const { data } = await supabase.from('device_sessions').select('*').eq('user_email', email).order('last_activity', { ascending: false });
  
  const sessions = (data || []).map(row => ({
    id: row.id, device_id: row.device_id, device_info: row.device_info, last_activity: row.last_activity, is_active: row.is_active, is_current: row.device_id === current_device_id
  }));
  res.json({ sessions });
});

app.post('/device-session/close-others', async (req, res) => {
  const { email, keep_device_id } = req.body;
  const { data: cerradas } = await supabase.from('device_sessions')
    .update({ is_active: 0 })
    .eq('user_email', email)
    .neq('device_id', keep_device_id)
    .eq('is_active', 1)
    .select('device_id');

  for (const s of cerradas || []) {
    io.to(salaDispositivo(email, s.device_id)).emit('sessionClosed', {
      reason: 'closed_by_user',
      device_id: s.device_id
    });
  }

  res.json({ success: true, closed_count: (cerradas || []).length });
});


// Arrancar server permanentemente
server.listen(PORT, '0.0.0.0', () => {
  console.log(`Backend Users corriendo en puerto ${PORT} usando SUPABASE 🚀`);
});
