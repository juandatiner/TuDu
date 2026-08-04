const jwt = require('jsonwebtoken');

// El secreto JAMÁS debe tener un valor por defecto: si falta, el proceso no
// arranca. Un secreto adivinable equivale a no tener auth.
const JWT_SECRET = process.env.JWT_SECRET;

// Dos tokens, a propósito:
//
//  - ACCESO: corto. Es el que viaja en cada petición, así que es el que se
//    puede filtrar. Al durar poco, un token robado sirve minutos, no meses.
//  - REFRESCO: largo. Solo se usa contra /auth/refresh para pedir un acceso
//    nuevo. Es lo que evita que el usuario tenga que re-verificarse cada rato.
//
// La ventaja real no es la comodidad: es poder REVOCAR. Al refrescar se
// comprueba contra la base que la sesión de ese dispositivo siga activa, así
// que cerrar sesión deja de tener efecto solo "en teoría" — a lo sumo en
// ACCESS_EXPIRES_IN el intruso queda fuera de verdad.
const ACCESS_EXPIRES_IN = process.env.ACCESS_TOKEN_TTL || '30m';
const REFRESH_EXPIRES_IN = process.env.REFRESH_TOKEN_TTL || '180d';

if (!JWT_SECRET) {
  console.error('❌ Falta JWT_SECRET en .env — sin él no se pueden firmar sesiones.');
  process.exit(1);
}

/// Token de acceso: el que se manda en `Authorization: Bearer`.
function signToken({ email, role = 'user', device_id = null }) {
  return jwt.sign({ email, role, device_id, type: 'access' }, JWT_SECRET, {
    expiresIn: ACCESS_EXPIRES_IN
  });
}

/// Token de refresco: solo sirve para pedir un acceso nuevo.
function signRefreshToken({ email, role = 'user', device_id = null }) {
  return jwt.sign({ email, role, device_id, type: 'refresh' }, JWT_SECRET, {
    expiresIn: REFRESH_EXPIRES_IN
  });
}

/// Emite la pareja completa. Es lo que devuelve el login / verificación de OTP.
function signSession({ email, role = 'user', device_id = null }) {
  return {
    token: signToken({ email, role, device_id }),
    refresh_token: signRefreshToken({ email, role, device_id }),
    expires_in: ACCESS_EXPIRES_IN
  };
}

function verifyToken(token, tipoEsperado = 'access') {
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    // Un token de refresco no puede usarse como si fuera de acceso: si no se
    // comprueba el tipo, el token largo valdría para todo y no habría ganado nada.
    if (payload.type !== tipoEsperado) return null;
    return payload;
  } catch (e) {
    return null;
  }
}

/// Middleware: exige un `Authorization: Bearer <token>` de acceso válido.
function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;

  if (!token) {
    return res.status(401).json({ error: 'Falta el token de sesión', code: 'NO_TOKEN' });
  }

  const payload = verifyToken(token, 'access');
  if (!payload) {
    // TOKEN_EXPIRED le dice al cliente que intente refrescar antes de rendirse.
    return res.status(401).json({ error: 'Sesión inválida o expirada', code: 'TOKEN_EXPIRED' });
  }

  req.auth = payload;
  next();
}

/// Construye el handler de POST /auth/refresh.
///
/// [sesionSigueActiva] recibe ({ email, device_id, role }) y debe devolver true
/// solo si esa sesión sigue viva en la base. Cada backend lo resuelve contra su
/// propia tabla; el admin no tiene sesiones por dispositivo y devuelve true.
function createRefreshHandler(sesionSigueActiva) {
  return async (req, res) => {
    const { refresh_token } = req.body || {};

    if (!refresh_token) {
      return res.status(400).json({ error: 'Falta el refresh_token', code: 'NO_REFRESH_TOKEN' });
    }

    const payload = verifyToken(refresh_token, 'refresh');
    if (!payload) {
      return res.status(401).json({ error: 'Refresh token inválido o expirado', code: 'INVALID_REFRESH' });
    }

    // Acá está la revocación real: aunque el token sea válido criptográficamente,
    // si la sesión ya no está activa en la base, no se renueva nada.
    const activa = await sesionSigueActiva(payload);
    if (!activa) {
      return res.status(401).json({ error: 'La sesión fue cerrada', code: 'SESSION_REVOKED' });
    }

    const datos = { email: payload.email, role: payload.role, device_id: payload.device_id };

    // Rotación: cada refresco entrega también un refresh nuevo, para que un
    // token viejo filtrado tenga una ventana de uso acotada.
    res.json(signSession(datos));
  };
}

/// Valida el token de acceso que llega en el handshake de Socket.io.
function authenticateSocket(socket, next) {
  const token = socket.handshake.auth && socket.handshake.auth.token;
  const payload = token ? verifyToken(token, 'access') : null;

  if (!payload) {
    return next(new Error('unauthorized'));
  }

  socket.data.auth = payload;
  next();
}

module.exports = {
  signToken,
  signRefreshToken,
  signSession,
  verifyToken,
  requireAuth,
  createRefreshHandler,
  authenticateSocket,
  ACCESS_EXPIRES_IN,
  REFRESH_EXPIRES_IN
};
