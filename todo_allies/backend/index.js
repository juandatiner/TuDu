const express = require('express');
const cors = require('cors');
const mailgun = require('mailgun-js');
const sqlite3 = require('sqlite3').verbose();
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3002;

// Configurar Mailgun
const mg = mailgun({
  apiKey: process.env.MAILGUN_API_KEY,
  domain: process.env.MAILGUN_DOMAIN
});

// Middleware
app.use(cors());
app.use(express.json());

// Almacenamiento temporal de OTPs (en producción usar Redis o DB)
const otpStore = new Map();

// Base de datos SQLite para aliados
const db = new sqlite3.Database('../../databases/allies.db', (err) => {
  if (err) {
    console.error('Error abriendo DB aliados:', err.message);
  } else {
    console.log('Conectado a SQLite DB aliados.');
    db.run(`CREATE TABLE IF NOT EXISTS allies (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT UNIQUE NOT NULL,
      nombre TEXT NOT NULL,
      apellido TEXT NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`, (err) => {
      if (err) {
        console.error('Error creando tabla allies:', err);
      } else {
        console.log('Tabla allies verificada/creada.');
      }
    });
  }
});

// Base de datos SQLite para servicios
const servicesDb = new sqlite3.Database('../../databases/services.db', (err) => {
  if (err) {
    console.error('Error abriendo DB servicios:', err.message);
  } else {
    console.log('Conectado a SQLite DB servicios.');
    servicesDb.run(`CREATE TABLE IF NOT EXISTS services (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`, (err) => {
      if (err) {
        console.error('Error creando tabla services:', err);
      } else {
        console.log('Tabla services verificada/creada.');
        // Insertar datos de ejemplo si no existen
        const sampleServices = [
          'Servicio de hogar',
          'Reparaciones eléctricas',
          'Jardinería',
          'Limpieza',
          'Plomería',
          'Pintura',
          'Carpintería',
          'Electricidad',
          'Fontanería',
          'Mantenimiento general',
        ];
        sampleServices.forEach(name => {
          servicesDb.get(`SELECT id FROM services WHERE name = ?`, [name], (err, row) => {
            if (err) {
              console.error('Error verificando servicio:', err);
            } else if (!row) {
              servicesDb.run(`INSERT INTO services (name) VALUES (?)`, [name]);
            }
          });
        });
        console.log('Verificación de datos de ejemplo completada.');
      }
    });
  }
});

// Generar OTP de 6 dígitos
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// Endpoint para enviar OTP
app.post('/send-otp', async (req, res) => {
  const { email } = req.body;

  if (!email) {
    return res.status(400).json({ error: 'Email es requerido' });
  }

  const otp = generateOTP();
  otpStore.set(email, { otp, timestamp: Date.now() });

  // Modo desarrollo: simular envío
  if (process.env.DEV_MODE === 'true') {
    console.log(`🔥 MODO DESARROLLO - Código OTP para ${email}: ${otp}`);
    console.log(`📧 Este código expira en 10 minutos`);
    return res.json({ message: 'OTP enviado exitosamente (modo desarrollo)' });
  }

  // Modo producción: enviar email real
  const data = {
    from: 'Tu App ToDo <noreply@tuapp.com>',
    to: email,
    subject: 'Código de verificación ToDo',
    text: `Tu código de verificación es: ${otp}. Este código expira en 10 minutos.`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #78BF32;">Código de verificación ToDo</h2>
        <p>Hola,</p>
        <p>Tu código de verificación es:</p>
        <div style="background-color: #f4f4f4; padding: 20px; text-align: center; font-size: 24px; font-weight: bold; margin: 20px 0;">
          ${otp}
        </div>
        <p>Este código expira en 10 minutos.</p>
        <p>Si no solicitaste este código, ignora este mensaje.</p>
      </div>
    `
  };

  try {
    await mg.messages().send(data);
    res.json({ message: 'OTP enviado exitosamente' });
  } catch (error) {
    console.error('Error enviando email:', error);
    res.status(500).json({ error: 'Error enviando OTP' });
  }
});

// Endpoint para verificar OTP
app.post('/verify-otp', (req, res) => {
  const { email, otp } = req.body;

  if (!email || !otp) {
    return res.status(400).json({ error: 'Email y OTP son requeridos' });
  }

  // Modo desarrollo: aceptar cualquier código
  if (process.env.DEV_MODE === 'true') {
    console.log(`🔥 MODO DESARROLLO - OTP aceptado automáticamente para ${email}`);
    return res.json({ message: 'OTP verificado exitosamente (modo desarrollo)' });
  }

  // Modo producción: verificación normal
  const storedData = otpStore.get(email);

  if (!storedData) {
    return res.status(400).json({ error: 'OTP no encontrado o expirado' });
  }

  // Verificar expiración (10 minutos)
  const now = Date.now();
  const diffMinutes = (now - storedData.timestamp) / (1000 * 60);

  if (diffMinutes > 10) {
    otpStore.delete(email);
    return res.status(400).json({ error: 'OTP expirado' });
  }

  if (storedData.otp === otp) {
    otpStore.delete(email);
    res.json({ message: 'OTP verificado exitosamente' });
  } else {
    res.status(400).json({ error: 'OTP inválido' });
  }
});

// Endpoint para verificar si aliado existe
app.post('/check-user', (req, res) => {
  const { email } = req.body;

  if (!email) {
    return res.status(400).json({ error: 'Email es requerido' });
  }

  db.get(`SELECT id, nombre, apellido FROM allies WHERE email = ?`, [email], (err, row) => {
    if (err) {
      return res.status(500).json({ error: 'Error verificando aliado' });
    }
    if (row) {
      res.json({ exists: true, user: row });
    } else {
      res.json({ exists: false });
    }
  });
});

// Endpoint para registrar aliado
app.post('/register-user', (req, res) => {
  const { email, nombre, apellido } = req.body;

  if (!email || !nombre || !apellido) {
    return res.status(400).json({ error: 'Email, nombre y apellido son requeridos' });
  }

  db.run(`INSERT INTO allies (email, nombre, apellido) VALUES (?, ?, ?)`, [email, nombre, apellido], function(err) {
    if (err) {
      if (err.code === 'SQLITE_CONSTRAINT_UNIQUE') {
        return res.status(400).json({ error: 'Aliado ya registrado' });
      }
      return res.status(500).json({ error: 'Error registrando aliado' });
    }
    res.json({ message: 'Aliado registrado exitosamente', id: this.lastID });
  });
});

// Endpoint para obtener todos los servicios
app.get('/services', (req, res) => {
  servicesDb.all(`SELECT id, name FROM services ORDER BY created_at DESC`, [], (err, rows) => {
    if (err) {
      return res.status(500).json({ error: 'Error obteniendo servicios' });
    }
    res.json({ services: rows });
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Servidor corriendo en puerto ${PORT} (accesible desde red)`);
});