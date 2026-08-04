const crypto = require('crypto');

/// Sube imágenes a Supabase Storage en vez de guardarlas en base64 dentro de
/// Postgres.
///
/// Una foto en base64 dentro de una columna hace que cada `select *` arrastre
/// megas, engorda las copias de seguridad y gasta ancho de banda aunque solo se
/// quiera el nombre del usuario. En Storage la fila guarda una URL de ~100 bytes.
///
/// COMPATIBILIDAD: si el bucket todavía no existe (falta ejecutar
/// `supabase/storage.sql`) o la subida falla, se devuelve el base64 original y
/// todo sigue funcionando como antes. Así el cambio no rompe nada mientras se
/// hace la migración.

const PREFIJO_DATA_URL = /^data:(image\/[a-zA-Z+]+);base64,/;

/// True si el valor es una imagen en base64 y no una URL ya migrada.
function esBase64(valor) {
  if (typeof valor !== 'string' || valor.length === 0) return false;
  if (valor.startsWith('http://') || valor.startsWith('https://')) return false;
  return true;
}

/// Separa el tipo MIME y los bytes de un `data:` URL o de un base64 pelado.
function decodificar(valor) {
  const coincidencia = valor.match(PREFIJO_DATA_URL);
  const mime = coincidencia ? coincidencia[1] : 'image/jpeg';
  const limpio = valor.replace(PREFIJO_DATA_URL, '');

  return { mime, bytes: Buffer.from(limpio, 'base64') };
}

function extensionDe(mime) {
  if (mime === 'image/png') return 'png';
  if (mime === 'image/webp') return 'webp';
  return 'jpg';
}

/// Nombre de archivo estable por dueño, con sufijo aleatorio para que el CDN no
/// sirva la versión anterior en caché tras un cambio de foto.
function nombreArchivo(dueno, etiqueta, mime) {
  const limpio = String(dueno).toLowerCase().replace(/[^a-z0-9]/g, '_');
  const aleatorio = crypto.randomBytes(6).toString('hex');
  return `${limpio}/${etiqueta}-${aleatorio}.${extensionDe(mime)}`;
}

/// Sube una imagen y devuelve la URL pública (bucket público) o la ruta interna
/// (bucket privado). Si algo falla, devuelve el valor original sin tocar.
async function subirImagen(supabase, { bucket, dueno, etiqueta, valor }) {
  if (!esBase64(valor)) return valor; // ya es una URL: nada que hacer

  try {
    const { mime, bytes } = decodificar(valor);
    const ruta = nombreArchivo(dueno, etiqueta, mime);

    const { error } = await supabase.storage
      .from(bucket)
      .upload(ruta, bytes, { contentType: mime, upsert: true });

    if (error) {
      console.warn(`⚠️  No se pudo subir a Storage (${bucket}): ${error.message}. Se guarda en base64 — ¿falta ejecutar supabase/storage.sql?`);
      return valor;
    }

    // El bucket de avatares es público: se guarda la URL directa.
    // El de KYC es privado: se guarda la ruta y se firma al leerla.
    if (bucket === 'avatars') {
      const { data } = supabase.storage.from(bucket).getPublicUrl(ruta);
      return data.publicUrl;
    }

    return ruta;
  } catch (e) {
    console.warn(`⚠️  Error subiendo imagen a Storage: ${e.message}. Se guarda en base64.`);
    return valor;
  }
}

/// URL temporal para leer un archivo del bucket privado de KYC.
async function urlFirmada(supabase, bucket, ruta, segundos = 3600) {
  if (!ruta || esBase64(ruta) === false && ruta.startsWith('http')) return ruta;

  try {
    const { data, error } = await supabase.storage.from(bucket).createSignedUrl(ruta, segundos);
    if (error) return ruta;
    return data.signedUrl;
  } catch (e) {
    return ruta;
  }
}

module.exports = { subirImagen, urlFirmada, esBase64 };
