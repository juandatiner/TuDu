const { rateLimit, ipKeyGenerator } = require('express-rate-limit');

/// Límites de intentos para los endpoints sensibles.
///
/// Sin esto, `/send-otp` queda abierto a que un script queme la cuota de correos
/// de Supabase Auth y use el servicio para spam, y `/verify-otp` a que se pruebe
/// un código de 6 dígitos por fuerza bruta (un millón de combinaciones se agotan
/// rápido si no hay tope).
///
/// La cuenta se lleva por correo, no por IP: varias personas comparten IP detrás
/// de una red móvil, y un atacante cambia de IP con facilidad.
function porCorreo(req) {
  const email = (req.body && req.body.email) || '';
  if (email) return String(email).toLowerCase();

  // Sin correo se cae a la IP, pero pasando por `ipKeyGenerator`: una IPv6
  // cruda permitiría saltarse el límite cambiando de dirección dentro del mismo
  // bloque asignado al usuario.
  return ipKeyGenerator(req.ip);
}

const opcionesComunes = {
  standardHeaders: true,
  legacyHeaders: false,
  // El límite se salta en desarrollo: probar la app no debe agotar la cuota.
  skip: () => process.env.DEV_MODE === 'true'
};

/// Envío de códigos: caro (cuesta un correo real) y fácil de abusar.
const limiteEnvioOtp = rateLimit({
  ...opcionesComunes,
  windowMs: 15 * 60 * 1000,
  max: 5,
  keyGenerator: porCorreo,
  message: {
    error: 'Demasiados códigos solicitados. Intenta de nuevo en 15 minutos.',
    code: 'RATE_LIMITED'
  }
});

/// Verificación: barato de pedir, pero es la puerta de entrada a la cuenta.
const limiteVerificacionOtp = rateLimit({
  ...opcionesComunes,
  windowMs: 15 * 60 * 1000,
  max: 10,
  keyGenerator: porCorreo,
  message: {
    error: 'Demasiados intentos fallidos. Intenta de nuevo en 15 minutos.',
    code: 'RATE_LIMITED'
  }
});

/// Login con contraseña: se limita por IP porque el usuario es el dato que se
/// está adivinando y no sirve como clave de conteo.
const limiteLogin = rateLimit({
  ...opcionesComunes,
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: {
    error: 'Demasiados intentos de acceso. Intenta de nuevo en 15 minutos.',
    code: 'RATE_LIMITED'
  }
});

module.exports = { limiteEnvioOtp, limiteVerificacionOtp, limiteLogin };
