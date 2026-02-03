const express = require('express');
const cors = require('cors');
const mailgun = require('mailgun-js');
const sqlite3 = require('sqlite3').verbose();
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

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

// Base de datos SQLite para usuarios
const db = new sqlite3.Database('../../databases/users.db', (err) => {
  if (err) {
    console.error('Error abriendo DB usuarios:', err.message);
  } else {
    console.log('Conectado a SQLite DB usuarios.');
    db.run(`CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT UNIQUE NOT NULL,
      nombre TEXT NOT NULL,
      apellido TEXT NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`, (err) => {
      if (err) {
        console.error('Error creando tabla users:', err);
      } else {
        console.log('Tabla users verificada/creada.');
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
      
        // Crear tabla para servicios en busca de aliados
    servicesDb.run(`CREATE TABLE IF NOT EXISTS services_in_search (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_email TEXT NOT NULL,
          title TEXT NOT NULL,
          description TEXT NOT NULL,
          time_quantity INTEGER NOT NULL,
          time_unit TEXT NOT NULL,
          budget TEXT NOT NULL,
          worker_info TEXT NOT NULL,
          additional_info TEXT NOT NULL,
          status TEXT DEFAULT 'EN ESPERA',
          assigned BOOLEAN DEFAULT 0,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )`, (err) => {
         if (err) {
           console.error('Error creando tabla services_in_search:', err);
         } else {
           console.log('Tabla services_in_search verificada/creada.');

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

// Endpoint para verificar si usuario existe
app.post('/check-user', (req, res) => {
  const { email } = req.body;

  if (!email) {
    return res.status(400).json({ error: 'Email es requerido' });
  }

  db.get(`SELECT id, nombre, apellido FROM users WHERE email = ?`, [email], (err, row) => {
    if (err) {
      return res.status(500).json({ error: 'Error verificando usuario' });
    }
    if (row) {
      res.json({ exists: true, user: row });
    } else {
      res.json({ exists: false });
    }
  });
});

// Endpoint para registrar usuario
app.post('/register-user', (req, res) => {
  const { email, nombre, apellido } = req.body;

  if (!email || !nombre || !apellido) {
    return res.status(400).json({ error: 'Email, nombre y apellido son requeridos' });
  }

  db.run(`INSERT INTO users (email, nombre, apellido) VALUES (?, ?, ?)`, [email, nombre, apellido], function(err) {
    if (err) {
      if (err.code === 'SQLITE_CONSTRAINT_UNIQUE') {
        return res.status(400).json({ error: 'Usuario ya registrado' });
      }
      return res.status(500).json({ error: 'Error registrando usuario' });
    }
    res.json({ message: 'Usuario registrado exitosamente', id: this.lastID });
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

// Endpoint para publicar servicio en busca de aliado
app.post('/publish-service', (req, res) => {
  const { user_email, title, description, time_quantity, time_unit, budget, worker_info, additional_info } = req.body;

  if (!user_email || !title || !description || !time_quantity || !time_unit || !budget || !worker_info || !additional_info) {
    return res.status(400).json({ error: 'Todos los campos son obligatorios' });
  }

  servicesDb.run(`INSERT INTO services_in_search (user_email, title, description, time_quantity, time_unit, budget, worker_info, additional_info, status) 
                  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`, 
                  [user_email, title, description, time_quantity, time_unit, budget, worker_info, additional_info, 'EN ESPERA'], function(err) {
    if (err) {
      console.error('Error publicando servicio:', err);
      return res.status(500).json({ error: 'Error publicando servicio' });
    }
    res.json({ message: 'Servicio publicado exitosamente', id: this.lastID });
  });
});

// Endpoint para obtener servicios en busca de aliados (sin asignar)
app.get('/services-in-search', (req, res) => {
  const { user_email } = req.query;

  // Si se proporciona un email, filtrar por ese usuario
  if (user_email) {
    servicesDb.all(`SELECT * FROM services_in_search WHERE assigned = 0 AND user_email = ? ORDER BY created_at DESC`, [user_email], (err, rows) => {
      if (err) {
        return res.status(500).json({ error: 'Error obteniendo servicios en busca de aliados' });
      }
      res.json({ services_in_search: rows });
    });
  } else {
    // Si no se proporciona email, devolver todos los servicios sin asignar
    servicesDb.all(`SELECT * FROM services_in_search WHERE assigned = 0 ORDER BY created_at DESC`, (err, rows) => {
      if (err) {
        return res.status(500).json({ error: 'Error obteniendo servicios en busca de aliados' });
      }
      res.json({ services_in_search: rows });
    });
  }
});

// Endpoint para marcar un servicio como asignado
app.put('/services-in-search/:id/assign', (req, res) => {
  const { id } = req.params;

  servicesDb.run(`UPDATE services_in_search SET assigned = 1, status = 'En Proceso' WHERE id = ?`, [id], function(err) {
    if (err) {
      console.error('Error asignando servicio:', err);
      return res.status(500).json({ error: 'Error asignando servicio' });
    }
    if (this.changes === 0) {
      return res.status(404).json({ error: 'Servicio no encontrado' });
    }
    res.json({ message: 'Servicio asignado exitosamente' });
  });
});

// Endpoint para actualizar el estado de un servicio
app.put('/services-in-search/:id/status', (req, res) => {
  const { id } = req.params;
  const { status } = req.body;

  if (!status) {
    return res.status(400).json({ error: 'Estado es requerido' });
  }

  servicesDb.run(`UPDATE services_in_search SET status = ? WHERE id = ?`, [status, id], function(err) {
    if (err) {
      console.error('Error actualizando estado:', err);
      return res.status(500).json({ error: 'Error actualizando estado' });
    }
    if (this.changes === 0) {
      return res.status(404).json({ error: 'Servicio no encontrado' });
    }
    res.json({ message: 'Estado actualizado exitosamente' });
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Servidor corriendo en puerto ${PORT} (accesible desde red)`);
});