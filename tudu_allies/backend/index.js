const express = require('express');
const cors = require('cors');
const compression = require('compression'); // Acelera cargas de Base64 reduciendo 80%
const { corsOptions, corsSocket, avisarConfiguracion } = require('./cors_config');
const { subirImagen, urlFirmada } = require('./storage');
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const http = require('http');
const { Server } = require('socket.io');

const app = express();
app.use(compression());
const PORT = process.env.PORT || 3002;
const server = http.createServer(app);

const io = new Server(server, { cors: corsSocket });

// Inicializar Supabase
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error("❌ Faltan credenciales de Supabase en .env");
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

/// Sala privada de un dispositivo, para avisarle solo a él que perdió la sesión.
function salaDispositivo(email, deviceId) {
  return `device:${String(email).toLowerCase()}:${deviceId}`;
}

// Socket.io connection handler para monitoreo de Aliados
io.on('connection', (socket) => {
  const auth = socket.handshake.auth || {};

  const email = socket.data.auth.email;
  const deviceId = socket.data.auth.device_id || auth.device_id;
  socket.join(`ally:${String(email).toLowerCase()}`);
  if (deviceId) socket.join(salaDispositivo(email, deviceId));

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

  console.log(`📱 Conexión en vivo -> Aliado: [${email}] | Equipo: [${deviceName}]`);

  socket.on('disconnect', () => {
    console.log(`🔌 Desconectado -> Aliado: [${email}] | Equipo: [${deviceName}]`);
  });
});

// Middleware
app.use(cors(corsOptions));
app.use(express.json());

const { signSession, requireAuth, createRefreshHandler, authenticateSocket } = require('./auth');
const { limiteEnvioOtp, limiteVerificacionOtp } = require('./rate_limit');

// El socket exige el mismo JWT que la API REST.
io.use(authenticateSocket);

// Código maestro de desarrollo. Solo sirve con DEV_MODE=true.
const OTP_DEV = process.env.DEV_OTP || '123456';

// Rutas sin token: las que sirven para obtenerlo y los catálogos públicos.
const RUTAS_PUBLICAS = [
  '/send-otp',
  '/verify-otp',
  '/check-ally',
  '/services',
  '/categories',
  '/ally-device-session/check',
  '/auth/refresh'
];

function esRutaPublica(path) {
  return RUTAS_PUBLICAS.some(r => path === r || path.startsWith(r + '/'));
}

const CAMPOS_DUENO = ['email', 'ally_email', 'user_email'];

// 1. Todo lo demás exige token válido.
app.use((req, res, next) => {
  if (esRutaPublica(req.path)) return next();
  return requireAuth(req, res, next);
});

// 2. Nadie opera sobre la cuenta de otro.
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

  for (const segmento of decodeURIComponent(req.path).split('/')) {
    if (segmento.includes('@') && segmento.toLowerCase() !== propio) {
      return res.status(403).json({ error: 'No puedes operar sobre otra cuenta', code: 'FORBIDDEN' });
    }
  }

  next();
});

// 3. El área de administración exige rol admin, no basta con estar logueado.
//    El JWT se firma con el mismo secreto en los tres backends, así que el token
//    que emite el panel al iniciar sesión vale también aquí.
app.use('/api/admin', (req, res, next) => {
  if (req.auth && req.auth.role === 'admin') return next();
  return res.status(403).json({ error: 'Se requiere rol de administrador', code: 'NOT_ADMIN' });
});

// Una sesión sin actividad durante este tiempo caduca y vuelve a pedir OTP.
const SESSION_MAX_IDLE_DAYS = 180;

// Un registro de aliado a medias (sin cédula enviada) se descarta pasado este tiempo.
// La ventana existe para que quien cierre la app a mitad del registro y vuelva
// al rato siga donde iba, en vez de tener que escribir todo de nuevo.
const REGISTRO_INCOMPLETO_MAX_DIAS = 7;

function fechaLimiteSesion() {
  return new Date(Date.now() - SESSION_MAX_IDLE_DAYS * 24 * 60 * 60 * 1000).toISOString();
}

function fechaLimiteRegistroIncompleto() {
  return new Date(Date.now() - REGISTRO_INCOMPLETO_MAX_DIAS * 24 * 60 * 60 * 1000).toISOString();
}

// Cierra sesiones de aliado sin actividad reciente.
async function expirarSesionesInactivas() {
  const { data, error } = await supabase
    .from('ally_device_sessions')
    .update({ is_active: 0 })
    .eq('is_active', 1)
    .lt('last_activity', fechaLimiteSesion())
    .select('id');

  if (!error && data && data.length > 0) {
    console.log(`🧹 SESIONES: ${data.length} sesiones de aliado caducadas por ${SESSION_MAX_IDLE_DAYS} días sin actividad.`);
  }
}

// Borra registros de aliado abandonados: viejos y sin cédula enviada nunca.
// Los que están en 'submitted' o 'approved' no se tocan jamás: esa persona ya
// se identificó ante la empresa y solo está esperando respuesta.
async function limpiarRegistrosAbandonados() {
  const { data: abandonados, error } = await supabase
    .from('allies')
    .select('email')
    .not('kyc_status', 'in', '("submitted","approved")')
    .lt('created_at', fechaLimiteRegistroIncompleto());

  if (error || !abandonados || abandonados.length === 0) return;

  const emails = abandonados.map(a => a.email);
  await supabase.from('ally_service_profiles').delete().in('ally_email', emails);
  await supabase.from('allies').delete().in('email', emails);
  console.log(`🧹 REGISTROS: ${emails.length} registros de aliado abandonados (>${REGISTRO_INCOMPLETO_MAX_DIAS} días sin cédula) eliminados.`);
}

/// El mantenimiento real corre en la base con pg_cron (ver `supabase/cron.sql`).
/// Este respaldo en proceso solo se activa con MANTENIMIENTO_EN_PROCESO=true,
/// pensado para desarrollo local: un setInterval muere con el proceso y se
/// duplica si hay varias instancias del backend.
const MANTENIMIENTO_EN_PROCESO = process.env.MANTENIMIENTO_EN_PROCESO === 'true';

function programarMantenimiento(nombre, tarea) {
  if (!MANTENIMIENTO_EN_PROCESO) return;
  tarea();
  setInterval(tarea, 1000 * 60 * 60);
  console.log(`⏱  Mantenimiento en proceso activo: ${nombre} (cada hora). En producción esto lo hace pg_cron.`);
}

programarMantenimiento('caducidad de sesiones', expirarSesionesInactivas);
programarMantenimiento('registros abandonados', limpiarRegistrosAbandonados);

// Almacenamiento temporal de OTPs
const otpStore = new Map();

// Generar OTP de 6 dígitos
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// ==========================================
// 1. AUTENTICACIÓN
// ==========================================

app.post('/send-otp', limiteEnvioOtp, async (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ error: 'Email es requerido' });

  // MODO DESARROLLO: no se envía correo y se entra con el OTP maestro.
  // Solo con DEV_MODE=true, que nunca debe estar puesto en producción.
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

app.post('/verify-otp', limiteVerificacionOtp, async (req, res) => {
  const { email, otp, device_id } = req.body;
  if (!email || !otp) return res.status(400).json({ error: 'Email y OTP requeridos' });

  // MODO DESARROLLO: OTP maestro con cualquier correo, solo si DEV_MODE=true.
  // Antes este atajo estaba SIEMPRE activo y sin condición de entorno: cualquiera
  // entraba a cualquier cuenta escribiendo 123456.
  if (process.env.DEV_MODE === 'true' && otp === OTP_DEV) {
    return res.json({
      message: 'OTP verificado en modo desarrollo',
      ...signSession({ email, role: 'ally', device_id }),
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

  // Identidad probada: se emite el token para el resto de peticiones.
  res.json({
    message: 'OTP verificado exitosamente mediante Supabase',
    ...signSession({ email, role: 'ally', device_id })
  });
});

/// Canjea el refresh token por un acceso nuevo, comprobando contra la base que
/// la sesión de ese dispositivo siga viva. Eso es lo que hace revocable el acceso.
app.post('/auth/refresh', createRefreshHandler(async ({ email, device_id }) => {
  if (!device_id) return false;

  const { data } = await supabase
    .from('ally_device_sessions')
    .select('is_active, last_activity')
    .eq('ally_email', email)
    .eq('device_id', device_id)
    .single();

  if (!data || data.is_active !== 1) return false;
  return data.last_activity >= fechaLimiteSesion();
}));

// ==========================================
// 2. ALIADOS
// ==========================================

app.post('/check-ally', async (req, res) => {
  const { email, on_login } = req.body;
  if (!email) return res.status(400).json({ error: 'Email requerido' });

  const { data: ally, error } = await supabase
    .from('allies')
    .select('id, nombre, apellido, fecha_nacimiento, kyc_status, created_at')
    .eq('email', email)
    .single();
  if (error && error.code !== 'PGRST116') return res.status(500).json({ error: 'Error verificando' });

  if (!ally) {
    return res.json({ exists: false, partial: 'personal', kyc_status: null });
  }

  const kyc = ally.kyc_status || 'pending';
  const identificado = kyc === 'submitted' || kyc === 'approved';

  // Registro abandonado: entró alguna vez, dejó datos a medias y NUNCA llegó a
  // enviar la cédula. Se descarta y arranca limpio desde el formulario, pero
  // solo si además ya pasó la ventana de gracia: quien escribió su nombre,
  // cerró la app y volvió al rato continúa donde iba, sin repetir nada.
  //
  // Se hace únicamente en el login (`on_login`), no en los refrescos de estado,
  // para que un chequeo a mitad del onboarding no borre lo recién guardado.
  const registroVencido = ally.created_at < fechaLimiteRegistroIncompleto();

  if (on_login === true && !identificado && registroVencido) {
    await supabase.from('ally_service_profiles').delete().eq('ally_email', email);
    await supabase.from('allies').delete().eq('email', email);
    console.log(`🧹 Registro incompleto descartado al iniciar sesión: ${email} (kyc_status=${kyc})`);
    return res.json({ exists: false, partial: 'personal', kyc_status: null, reset: true });
  }

  // 1. Sin datos personales mínimos (nombre + apellido) → hay que pedirlos.
  //    `fecha_nacimiento` no entra en esta condición a propósito: si ya nos dio
  //    el nombre, no se lo volvemos a pedir dentro del mismo onboarding.
  if (!ally.nombre || !ally.apellido) {
    return res.json({ exists: false, partial: 'personal', kyc_status: kyc });
  }

  // 2. Ya tiene datos personales. Si todavía no subió cédula, ese es el paso.
  if (!identificado) {
    return res.json({ exists: false, partial: 'kyc', kyc_status: kyc, ally });
  }

  // 3. Documentos ya enviados. Falta el perfil del primer servicio.
  //    La tabla guarda `ally_email`, no `ally_id` — consultar por `ally_id` nunca encontraba nada.
  const { data: services } = await supabase
    .from('ally_service_profiles')
    .select('id')
    .eq('ally_email', email)
    .limit(1);

  const tieneServicio = services && services.length > 0;

  if (!tieneServicio) {
    // Se deja seguir el onboarding sin esperar la aprobación del admin:
    // bloquear acá dejaría al aliado atrapado a mitad del registro.
    return res.json({ exists: false, partial: 'service', kyc_status: kyc, ally });
  }

  // 4. Onboarding completo. Solo entra al home si el admin ya aprobó el KYC;
  //    si no, pantalla de "tu cuenta está siendo verificada" — nunca el formulario otra vez.
  if (kyc !== 'approved') {
    return res.json({ exists: false, partial: 'kyc_pending', kyc_status: kyc, ally });
  }

  return res.json({ exists: true, ally, kyc_status: kyc });
});

app.post('/register-ally', async (req, res) => {
  const { email, nombre, apellido, fecha_nacimiento } = req.body;
  if (!email || !nombre || !apellido) return res.status(400).json({ error: 'Faltan campos' });

  console.log(`📝 Registrando/Actualizando aliado: ${email}`);

  // Usamos upsert para que si ya existe en la tabla 'allies' (por el OTP previo), 
  // simplemente actualicemos sus datos personales.
  // OJO: la tabla `allies` no tiene columna `updated_at`. Escribirla hace que
  // Supabase responda "Could not find the 'updated_at' column" y el registro falle entero.
  const { data, error } = await supabase.from('allies').upsert([{
    email,
    nombre,
    apellido,
    fecha_nacimiento: fecha_nacimiento || null
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

  // Los documentos de identidad van al bucket PRIVADO `kyc`: en la fila queda
  // solo la ruta, y para verlos hay que pedir una URL firmada al backend.
  // Guardarlos en base64 dentro de la tabla los exponía en cualquier `select *`.
  const [frente, reverso, foto] = await Promise.all([
    subirImagen(supabase, { bucket: 'kyc', dueno: email, etiqueta: 'cedula-frente', valor: cedula_frente }),
    subirImagen(supabase, { bucket: 'kyc', dueno: email, etiqueta: 'cedula-reverso', valor: cedula_reverso }),
    subirImagen(supabase, { bucket: 'kyc', dueno: email, etiqueta: 'selfie', valor: selfie })
  ]);

  const { error } = await supabase.from('allies').update({
    kyc_cedula_frente: frente || null,
    kyc_cedula_reverso: reverso || null,
    kyc_selfie: foto || null,
    kyc_status: 'submitted',
    kyc_submitted_at: new Date().toISOString()
  }).eq('email', email);

  if (error) return res.status(500).json({ error: 'Error guardando KYC' });
  res.json({ message: 'Documentos KYC enviados para revisión' });
});

// Guardar perfil del primer servicio del aliado
// El portafolio es por (aliado, servicio): aunque el servicio del catálogo ya
// exista (lo haya propuesto otro aliado), cada aliado prueba con sus propias
// fotos que él hace ese trabajo. Sin esto, un aliado podía ofrecer un servicio
// ajeno sin mostrar nunca evidencia propia.
app.post('/ally-service-profile', async (req, res) => {
  const { email, service_id, nombre_comercial, frase_presentacion, resumen, images } = req.body;
  if (!email || !service_id) return res.status(400).json({ error: 'Faltan campos' });

  const lista = Array.isArray(images) ? images : [];
  if (lista.length > 5) return res.status(400).json({ error: 'Máximo 5 fotos' });

  if (lista.length === 0) {
    // Puede que ya tenga fotos de cuando propuso este mismo servicio nuevo
    // (POST /services, mismo ally_email + service_id) — no se le vuelve a pedir.
    const { count } = await supabase
      .from('ally_portfolio_items')
      .select('id', { count: 'exact', head: true })
      .eq('service_id', service_id)
      .eq('ally_email', email);
    if (!count) return res.status(400).json({ error: 'Sube al menos una foto de un trabajo real que hayas hecho' });
  }

  const { error } = await supabase.from('ally_service_profiles').insert([{
    ally_email: email,
    service_id,
    nombre_comercial: nombre_comercial || null,
    frase_presentacion: frase_presentacion || null,
    resumen: resumen || null,
    created_at: new Date().toISOString()
  }]);

  if (error) return res.status(500).json({ error: 'Error guardando perfil de servicio' });

  const subidas = await Promise.all(
    lista.map((img, i) => subirImagen(supabase, {
      bucket: 'portfolio',
      dueno: email,
      etiqueta: `trabajo-${i}`,
      valor: img
    }))
  );

  const filas = subidas
    .filter(url => url)
    .map(url => ({ service_id, ally_email: email, image_path: url }));

  if (filas.length > 0) {
    const { error: errorFotos } = await supabase.from('ally_portfolio_items').insert(filas);
    if (errorFotos) console.error('Error guardando pruebas del perfil:', errorFotos.message);
  }

  res.json({ message: 'Perfil de servicio creado exitosamente' });
});

// Los servicios propios del aliado — para la pestaña "Mis servicios".
app.get('/ally-service-profiles', async (req, res) => {
  const { ally_email } = req.query;
  if (!ally_email) return res.status(400).json({ error: 'Email requerido' });

  const { data: perfiles, error } = await supabase
    .from('ally_service_profiles')
    .select('*')
    .eq('ally_email', ally_email)
    .order('created_at', { ascending: false });

  if (error) return res.status(500).json({ error: 'Error obteniendo servicios' });
  if (!perfiles || perfiles.length === 0) return res.json({ profiles: [] });

  const serviceIds = [...new Set(perfiles.map(p => p.service_id))];
  const { data: servicios } = await supabase
    .from('services')
    .select('id, name, description, review_status, category_id')
    .in('id', serviceIds);

  const servicioPorId = Object.fromEntries((servicios || []).map(s => [s.id, s]));
  const resultado = perfiles.map(p => ({ ...p, service: servicioPorId[p.service_id] || null }));

  res.json({ profiles: resultado });
});



// ==========================================
//  REVISIÓN DE KYC (PANEL DE ADMINISTRACIÓN)
// ==========================================
//
// Hasta ahora los aliados subían la cédula y quedaban en `submitted` para
// siempre: no existía forma de aprobarlos salvo editar la fila a mano.

/// Estados que el administrador puede asignar al revisar.
const ESTADOS_KYC_REVISION = ['approved', 'rejected'];

/// Lista de aliados para revisar.
/// `?estado=submitted` (por defecto) trae los pendientes; `?estado=todos`, todos.
///
/// No devuelve las imágenes: son megas por aliado y en el listado no se ven.
/// Para eso está el detalle.
app.get('/api/admin/kyc', async (req, res) => {
  const estado = req.query.estado || 'submitted';

  let consulta = supabase
    .from('allies')
    .select('id, email, nombre, apellido, fecha_nacimiento, kyc_status, kyc_submitted_at, kyc_reviewed_at, kyc_reviewer_note, created_at')
    .order('kyc_submitted_at', { ascending: true, nullsFirst: false });

  if (estado !== 'todos') consulta = consulta.eq('kyc_status', estado);

  const { data, error } = await consulta;
  if (error) {
    console.error('Error listando KYC:', error.message);
    return res.status(500).json({ error: 'Error obteniendo solicitudes de verificación' });
  }

  res.json({ success: true, data: data || [] });
});

/// Detalle de un aliado con sus tres documentos listos para mostrar.
///
/// El bucket `kyc` es privado: lo que se guarda en la fila es una ruta, y aquí
/// se cambia por una URL firmada que caduca en una hora. Las filas antiguas
/// guardan base64 y se devuelven tal cual, así el panel funciona con las dos.
app.get('/api/admin/kyc/:email', async (req, res) => {
  const { email } = req.params;

  const { data: ally, error } = await supabase
    .from('allies')
    .select('*')
    .eq('email', email)
    .single();

  if (error || !ally) return res.status(404).json({ error: 'Aliado no encontrado' });

  const [frente, reverso, selfie] = await Promise.all([
    urlFirmada(supabase, 'kyc', ally.kyc_cedula_frente),
    urlFirmada(supabase, 'kyc', ally.kyc_cedula_reverso),
    urlFirmada(supabase, 'kyc', ally.kyc_selfie)
  ]);

  res.json({
    success: true,
    data: {
      id: ally.id,
      email: ally.email,
      nombre: ally.nombre,
      apellido: ally.apellido,
      fecha_nacimiento: ally.fecha_nacimiento,
      phone: ally.phone,
      kyc_status: ally.kyc_status,
      kyc_submitted_at: ally.kyc_submitted_at,
      kyc_reviewed_at: ally.kyc_reviewed_at,
      kyc_reviewer_note: ally.kyc_reviewer_note,
      created_at: ally.created_at,
      cedula_frente: frente,
      cedula_reverso: reverso,
      selfie: selfie
    }
  });
});

/// Aprueba o rechaza la verificación.
///
/// Al rechazar es obligatorio el motivo: el aliado tiene que saber qué corregir,
/// y `check-ally` lo devuelve a la pantalla de subir cédula.
app.put('/api/admin/kyc/:email', async (req, res) => {
  const { email } = req.params;
  const { status, note } = req.body;

  if (!ESTADOS_KYC_REVISION.includes(status)) {
    return res.status(400).json({ error: "El estado debe ser 'approved' o 'rejected'" });
  }

  if (status === 'rejected' && (!note || !note.trim())) {
    return res.status(400).json({ error: 'Al rechazar hay que indicar el motivo' });
  }

  const { data: ally } = await supabase
    .from('allies')
    .select('email, kyc_status')
    .eq('email', email)
    .single();

  if (!ally) return res.status(404).json({ error: 'Aliado no encontrado' });

  if (ally.kyc_status !== 'submitted') {
    return res.status(409).json({
      error: `Este aliado no está pendiente de revisión (estado actual: ${ally.kyc_status})`,
      code: 'NO_PENDIENTE'
    });
  }

  const { error } = await supabase
    .from('allies')
    .update({
      kyc_status: status,
      kyc_reviewed_at: new Date().toISOString(),
      kyc_reviewer_note: note ? note.trim() : null
    })
    .eq('email', email);

  if (error) {
    console.error('Error revisando KYC:', error.message);
    return res.status(500).json({ error: 'Error guardando la revisión' });
  }

  // Avisar al aliado en el momento: su pantalla de espera reacciona sin que
  // tenga que pulsar "Actualizar estado".
  io.to(`ally:${String(email).toLowerCase()}`).emit('kycUpdated', {
    email,
    status,
    note: note ? note.trim() : null
  });

  console.log(`🪪 KYC de ${email}: ${status}${note ? ' — ' + note.trim() : ''}`);
  res.json({ success: true, status });
});

// ==========================================
//  REVISIÓN DE CATEGORÍAS Y SERVICIOS (PANEL DE ADMINISTRACIÓN)
// ==========================================
//
// Mismo patrón que la revisión de KYC de arriba: la fila real vive en
// `services`/`categories` con `review_status`, no en una tabla de sugerencias
// aparte. Cada servicio que un aliado propone —el primero obligatorio del
// onboarding y cualquiera después— pasa por acá antes de ser visible.

const ESTADOS_REVISION = ['approved', 'rejected'];

/// Lista de servicios para revisar, con la categoría y el aliado que lo propuso.
/// `?estado=pending` (por defecto) trae los pendientes; `?estado=todos`, todos.
app.get('/api/admin/services', async (req, res) => {
  const estado = req.query.estado || 'pending';

  let consulta = supabase
    .from('services')
    .select(`
      id, name, description, review_status, admin_note, created_at, reviewed_at,
      created_by_ally_email,
      category:categories ( id, name, review_status ),
      allies ( nombre, apellido, email )
    `)
    .order('created_at', { ascending: true });

  if (estado !== 'todos') consulta = consulta.eq('review_status', estado);

  const { data, error } = await consulta;
  if (error) {
    console.error('Error listando servicios para revisión:', error.message);
    return res.status(500).json({ error: 'Error obteniendo servicios propuestos' });
  }

  // Pruebas de cada servicio, en una sola consulta aparte (más simple que anidar
  // el join con `services` arriba).
  const ids = (data || []).map(s => s.id);
  let fotosPorServicio = {};
  if (ids.length > 0) {
    const { data: fotos } = await supabase
      .from('ally_portfolio_items')
      .select('id, service_id, image_path, caption')
      .in('service_id', ids);

    fotosPorServicio = (fotos || []).reduce((acc, f) => {
      (acc[f.service_id] ||= []).push({ id: f.id, image_path: f.image_path, caption: f.caption });
      return acc;
    }, {});
  }

  const resultado = (data || []).map(s => ({ ...s, portfolio: fotosPorServicio[s.id] || [] }));
  res.json({ success: true, data: resultado });
});

/// Aprueba, rechaza o corrige un servicio propuesto. `name`/`description`/
/// `category_id` sobreescriben lo que puso el aliado (arreglar ortografía o
/// redirigir a una categoría existente que el aliado no encontró).
app.put('/api/admin/services/:id', async (req, res) => {
  const { id } = req.params;
  const { status, name, description, category_id, admin_note } = req.body;

  if (!ESTADOS_REVISION.includes(status)) {
    return res.status(400).json({ error: "El estado debe ser 'approved' o 'rejected'" });
  }
  if (status === 'rejected' && (!admin_note || !admin_note.trim())) {
    return res.status(400).json({ error: 'Al rechazar hay que indicar el motivo' });
  }

  const cambios = {
    review_status: status,
    reviewed_at: new Date().toISOString(),
    admin_note: admin_note ? admin_note.trim() : null
  };
  if (name && name.trim()) cambios.name = name.trim();
  if (description !== undefined) cambios.description = description ? description.trim() : null;
  if (category_id) cambios.category_id = category_id;

  const { data, error } = await supabase
    .from('services')
    .update(cambios)
    .eq('id', id)
    .select('id, name, review_status')
    .single();

  if (error || !data) return res.status(500).json({ error: 'Error guardando la revisión' });

  console.log(`🛠️ Servicio ${id} (${data.name}): ${status}`);
  res.json({ success: true, data });
});

/// Aprueba o rechaza una categoría propuesta por un aliado. Decisión
/// independiente de la del servicio: se puede aprobar la categoría y aun así
/// rechazar el servicio (o al revés).
app.put('/api/admin/categories/:id', async (req, res) => {
  const { id } = req.params;
  const { status, name, admin_note } = req.body;

  if (!ESTADOS_REVISION.includes(status)) {
    return res.status(400).json({ error: "El estado debe ser 'approved' o 'rejected'" });
  }
  if (status === 'rejected' && (!admin_note || !admin_note.trim())) {
    return res.status(400).json({ error: 'Al rechazar hay que indicar el motivo' });
  }

  const cambios = {
    review_status: status,
    reviewed_at: new Date().toISOString(),
    admin_note: admin_note ? admin_note.trim() : null
  };
  if (name && name.trim()) cambios.name = name.trim();

  const { data, error } = await supabase
    .from('categories')
    .update(cambios)
    .eq('id', id)
    .select('id, name, review_status')
    .single();

  if (error || !data) return res.status(500).json({ error: 'Error guardando la revisión' });
  res.json({ success: true, data });
});

/// El admin crea una categoría directo (para precargar el catálogo antes de
/// que ningún aliado la proponga) — entra aprobada de una, sin revisión.
app.post('/api/admin/categories', async (req, res) => {
  const { name } = req.body;
  if (!name || name.trim().length < 2) return res.status(400).json({ error: 'Nombre de categoría requerido' });

  const { data, error } = await supabase.from('categories').insert([{
    name: name.trim(),
    review_status: 'approved',
    reviewed_at: new Date().toISOString()
  }]).select('id, name, review_status').single();

  if (error) return res.status(500).json({ error: 'Error creando categoría' });
  res.status(201).json({ message: 'Categoría creada', data });
});

// ==========================================
// 3. SERVICIOS Y ASIGNACIONES
// ==========================================

// Categorías: nivel arriba de `services`. Igual que un servicio, una categoría
// que propone un aliado queda `pending` hasta que el admin la revisa — salvo
// que la cree el propio admin (POST /api/admin/categories), que entra
// aprobada de una.
app.get('/categories', async (req, res) => {
  const estado = req.query.estado || 'approved';

  let consulta = supabase.from('categories').select('id, name, review_status').order('name');
  if (estado !== 'todos') consulta = consulta.eq('review_status', estado);

  const { data, error } = await consulta;
  if (error) return res.status(500).json({ error: 'Error obteniendo categorías' });
  res.json({ categories: data || [] });
});

// El aliado propone una categoría nueva porque no encontró la suya.
app.post('/categories', async (req, res) => {
  const { name, ally_email } = req.body;
  if (!name || name.trim().length < 2) return res.status(400).json({ error: 'Nombre de categoría requerido' });
  if (!ally_email) return res.status(400).json({ error: 'Email del aliado requerido' });

  const { data, error } = await supabase.from('categories').insert([{
    name: name.trim(),
    review_status: 'pending',
    created_by_ally_email: ally_email
  }]).select('id, name, review_status').single();

  if (error) return res.status(500).json({ error: 'Error creando categoría' });
  res.status(201).json({ message: 'Categoría enviada a revisión', id: data.id, name: data.name, review_status: data.review_status });
});

app.get('/services', async (req, res) => {
  const { category_id, estado } = req.query;

  let consulta = supabase
    .from('services')
    .select('id, name, description, category_id, review_status')
    .order('name');

  const filtroEstado = estado || 'approved';
  if (filtroEstado !== 'todos') consulta = consulta.eq('review_status', filtroEstado);
  if (category_id) consulta = consulta.eq('category_id', category_id);

  const { data, error } = await consulta;
  if (error) return res.status(500).json({ error: 'Error obteniendo servicios' });
  res.json({ services: data || [] });
});

// El aliado propone un servicio nuevo (cuando no lo encuentra en su categoría),
// con pruebas: fotos de trabajos hechos. Queda `pending` — nunca se muestra a
// usuarios ni a otros aliados hasta que el admin lo aprueba.
app.post('/services', async (req, res) => {
  const { name, description, category_id, ally_email, images } = req.body;

  if (!name || name.trim().length < 2) return res.status(400).json({ error: 'Nombre del servicio requerido' });
  if (!category_id) return res.status(400).json({ error: 'Categoría requerida' });
  if (!ally_email) return res.status(400).json({ error: 'Email del aliado requerido' });

  const { data: servicio, error } = await supabase.from('services').insert([{
    name: name.trim(),
    description: description ? description.trim() : null,
    category_id,
    review_status: 'pending',
    created_by_ally_email: ally_email
  }]).select('id, name, description, category_id, review_status').single();

  if (error) {
    console.error('Error creando servicio:', error.message);
    return res.status(500).json({ error: 'Error creando servicio' });
  }

  // Pruebas: 0 a N fotos, bucket público (se ven en la app una vez aprobado).
  const lista = Array.isArray(images) ? images : [];
  if (lista.length > 0) {
    const subidas = await Promise.all(
      lista.map((img, i) => subirImagen(supabase, {
        bucket: 'portfolio',
        dueno: ally_email,
        etiqueta: `trabajo-${i}`,
        valor: img
      }))
    );

    const filas = subidas
      .filter(url => url)
      .map(url => ({ service_id: servicio.id, ally_email, image_path: url }));

    if (filas.length > 0) {
      const { error: errorFotos } = await supabase.from('ally_portfolio_items').insert(filas);
      if (errorFotos) console.error('Error guardando pruebas del servicio:', errorFotos.message);
    }
  }

  res.status(201).json({ message: 'Servicio enviado a revisión', id: servicio.id, name: servicio.name, review_status: servicio.review_status });
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

  // Validar si el aliado existe y ya pasó la revisión de KYC
  const { data: ally } = await supabase.from('allies').select('email, kyc_status').eq('email', ally_email).single();
  if (!ally) return res.status(404).json({ error: 'Aliado no encontrado' });
  if (ally.kyc_status !== 'approved') {
    return res.status(403).json({ error: 'Cuenta en revisión: no puedes tomar solicitudes todavía', code: 'KYC_PENDING' });
  }

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

  const { data: ally } = await supabase.from('allies').select('email').eq('email', email).single();
  if (!ally) return res.status(404).json({ error: 'Aliado no encontrado' });

  const { data: session } = await supabase.from('ally_device_sessions').select('*').eq('ally_email', email).eq('device_id', device_id).single();
  if (session) {
    if (session.is_active === 1 && session.last_activity < fechaLimiteSesion()) {
      await supabase.from('ally_device_sessions').update({ is_active: 0 }).eq('id', session.id);
      return res.json({ requires_verification: true, session_active: false, expired: true });
    }

    if (session.is_active === 1) {
      await supabase.from('ally_device_sessions').update({ last_activity: new Date().toISOString() }).eq('id', session.id);
      return res.json({ requires_verification: false, session_active: true });
    }

    return res.json({ requires_verification: true, session_active: false });
  }

  // Igual que en users: dispositivo desconocido (incluye reinstalación) → siempre OTP.
  const { count } = await supabase.from('ally_device_sessions')
    .select('id', { count: 'exact', head: true })
    .eq('ally_email', email)
    .eq('is_active', 1);

  return res.json({ requires_verification: true, session_active: false, has_other_sessions: count > 0 });
});

app.post('/ally-device-session/register', async (req, res) => {
  const { email, device_id, device_info } = req.body;
  if (!email || !device_id) return res.status(400).json({ error: 'Faltan campos' });
  
  // 1. Cierra todas las demás sesiones de este aliado y les avisa en el acto
  //    por socket, en vez de que ellas pregunten cada 30 segundos.
  const { data: desplazadas } = await supabase.from('ally_device_sessions')
    .update({ is_active: 0 })
    .eq('ally_email', email)
    .neq('device_id', device_id)
    .eq('is_active', 1)
    .select('device_id');

  for (const s of desplazadas || []) {
    io.to(salaDispositivo(email, s.device_id)).emit('sessionClosed', {
      reason: 'other_device',
      device_id: s.device_id
    });
  }

  // 2. Registra o actualiza la actual
  const { data: existing } = await supabase.from('ally_device_sessions').select('id').eq('ally_email', email).eq('device_id', device_id).single();
  
  // Antes no se miraba el error y siempre se respondía `success: true`. Si el
  // insert fallaba (por ejemplo, la clave foránea contra `allies` cuando el
  // aliado no existe), el cliente creía tener sesión y no la tenía.
  const { error } = existing
    ? await supabase.from('ally_device_sessions')
        .update({ device_info, is_active: 1, last_activity: new Date().toISOString() })
        .eq('id', existing.id)
    : await supabase.from('ally_device_sessions')
        .insert([{ ally_email: email, device_id, device_info, is_active: 1, last_activity: new Date().toISOString() }]);

  if (error) {
    console.error('❌ No se pudo registrar la sesión del aliado:', error.message);
    return res.status(500).json({ error: 'No se pudo registrar la sesión', code: 'SESSION_NOT_CREATED' });
  }

  res.json({ success: true });
});

app.get('/ally-device-session/status', async (req, res) => {
  const { email, device_id } = req.query;
  const { data: session } = await supabase.from('ally_device_sessions').select('id, is_active, last_activity').eq('ally_email', email).eq('device_id', device_id).single();

  if (session && session.is_active === 1 && session.last_activity < fechaLimiteSesion()) {
    await supabase.from('ally_device_sessions').update({ is_active: 0 }).eq('id', session.id);
    return res.json({ is_active: false, closed_remotely: false, expired: true });
  }

  if (session && session.is_active === 1) {
    return res.json({ is_active: true, closed_remotely: false });
  }

  // Igual que en users: solo es cierre remoto si otro dispositivo está activo.
  const { count } = await supabase.from('ally_device_sessions')
    .select('id', { count: 'exact', head: true })
    .eq('ally_email', email)
    .eq('is_active', 1)
    .neq('device_id', device_id);

  res.json({ is_active: false, closed_remotely: count > 0 });
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
  const { data: cerradas } = await supabase.from('ally_device_sessions')
    .update({ is_active: 0 })
    .eq('ally_email', email)
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
  console.log(`Backend Allies corriendo en puerto ${PORT} usando SUPABASE 🚀`);
  avisarConfiguracion('allies');
});
