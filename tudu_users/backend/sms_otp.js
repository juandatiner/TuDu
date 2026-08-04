// Envío y verificación de códigos OTP por SMS.
//
// Antes esto no existía: /users/phone/send-otp solo simulaba el envío y en
// producción respondía 501. Ahora hay un proveedor real (Twilio) más el
// almacén de códigos que hacía falta para poder comprobarlos.
//
// Los códigos viven en memoria: son de un solo uso y duran 5 minutos, así que
// no vale la pena una tabla. Si el proceso reinicia, la persona pide otro.

const TTL_MS = 5 * 60 * 1000;
const MAX_INTENTOS = 5;

const codigos = new Map(); // email -> { codigo, telefono, expira, intentos }

function generarCodigo() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

/// true si hay credenciales de Twilio configuradas.
function smsConfigurado() {
  return Boolean(
    process.env.TWILIO_ACCOUNT_SID &&
      process.env.TWILIO_AUTH_TOKEN &&
      process.env.TWILIO_FROM
  );
}

async function enviarSms(telefono, texto) {
  const sid = process.env.TWILIO_ACCOUNT_SID;
  const token = process.env.TWILIO_AUTH_TOKEN;

  const respuesta = await fetch(
    `https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`,
    {
      method: 'POST',
      headers: {
        Authorization: 'Basic ' + Buffer.from(`${sid}:${token}`).toString('base64'),
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: new URLSearchParams({
        To: telefono,
        From: process.env.TWILIO_FROM,
        Body: texto
      })
    }
  );

  if (!respuesta.ok) {
    const detalle = await respuesta.text();
    throw new Error(`Twilio ${respuesta.status}: ${detalle}`);
  }
}

/// Genera el código, lo guarda y lo manda por SMS.
async function emitirCodigo(email, telefono) {
  const codigo = generarCodigo();

  await enviarSms(telefono, `Tu código de verificación tudu es ${codigo}. Vence en 5 minutos.`);

  codigos.set(email, {
    codigo,
    telefono,
    expira: Date.now() + TTL_MS,
    intentos: 0
  });
}

/// Comprueba el código contra el teléfono para el que se emitió.
/// Devuelve { ok } o { ok: false, error, code }.
function comprobarCodigo(email, telefono, codigo) {
  const registro = codigos.get(email);

  if (!registro) {
    return { ok: false, error: 'No hay ningún código pendiente', code: 'OTP_NO_SOLICITADO' };
  }

  if (Date.now() > registro.expira) {
    codigos.delete(email);
    return { ok: false, error: 'El código expiró, pide uno nuevo', code: 'OTP_EXPIRADO' };
  }

  // El código vale solo para el número al que se envió: si en la pantalla
  // cambian el teléfono después de pedirlo, hay que pedir otro.
  if (registro.telefono !== telefono) {
    return { ok: false, error: 'El código no corresponde a ese número', code: 'OTP_OTRO_NUMERO' };
  }

  registro.intentos += 1;
  if (registro.intentos > MAX_INTENTOS) {
    codigos.delete(email);
    return { ok: false, error: 'Demasiados intentos, pide un código nuevo', code: 'OTP_BLOQUEADO' };
  }

  if (registro.codigo !== codigo) {
    return { ok: false, error: 'Código incorrecto', code: 'OTP_INVALIDO' };
  }

  codigos.delete(email); // un solo uso
  return { ok: true };
}

// Barrido de códigos vencidos para que el Map no crezca sin fin.
setInterval(() => {
  const ahora = Date.now();
  for (const [email, registro] of codigos) {
    if (ahora > registro.expira) codigos.delete(email);
  }
}, TTL_MS).unref();

module.exports = { smsConfigurado, emitirCodigo, comprobarCodigo };
