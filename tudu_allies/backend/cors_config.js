/// Configuración de CORS.
///
/// `origin: "*"` deja que cualquier página web llame a la API desde el navegador
/// de un usuario. Para apps móviles no cambia nada (no mandan cabecera `Origin`),
/// pero en cuanto exista un panel web o alguien abra la API al navegador, es la
/// puerta para que un sitio ajeno actúe en nombre de tus usuarios.
///
/// Con `CORS_ORIGINS` definido en el .env (lista separada por comas) solo se
/// aceptan esos dominios. Sin la variable se mantiene el comodín, para no romper
/// el desarrollo local.
///
///   CORS_ORIGINS=https://panel.tudu.com,https://tudu.com
const origenesPermitidos = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map(o => o.trim())
  .filter(Boolean);

const restringido = origenesPermitidos.length > 0;

function comprobarOrigen(origin, callback) {
  // Sin cabecera `Origin`: peticiones de app móvil, curl o servidor a servidor.
  // No son ataques CSRF porque no las origina un navegador con sesión ajena.
  if (!origin) return callback(null, true);

  if (origenesPermitidos.includes(origin)) return callback(null, true);

  return callback(new Error(`Origen no permitido por CORS: ${origin}`));
}

const corsOptions = restringido
  ? { origin: comprobarOrigen, credentials: true }
  : { origin: '*' };

const corsSocket = restringido
  ? { origin: origenesPermitidos, methods: ['GET', 'POST', 'PUT', 'DELETE'], credentials: true }
  : { origin: '*', methods: ['GET', 'POST', 'PUT', 'DELETE'] };

function avisarConfiguracion(nombre) {
  if (restringido) {
    console.log(`🔒 CORS restringido en ${nombre} a: ${origenesPermitidos.join(', ')}`);
  } else {
    console.log(`⚠️  CORS abierto (*) en ${nombre}. Define CORS_ORIGINS antes de producción.`);
  }
}

module.exports = { corsOptions, corsSocket, avisarConfiguracion };
