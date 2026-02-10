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

// Base de datos SQLite unificada
const db = new sqlite3.Database('../../databases/todo.db', (err) => {
  if (err) {
    console.error('Error abriendo DB unificada:', err.message);
  } else {
    console.log('Conectado a SQLite DB unificada.');
    // Crear tabla de busquedas recientes si no existe
    db.run(`CREATE TABLE IF NOT EXISTS search_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_email TEXT NOT NULL,
      search_query TEXT NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`, (err) => {
      if (err) {
        console.error('Error creando tabla search_history:', err.message);
      } else {
        console.log('Tabla search_history listo');
      }
    });
  }
});

// No se necesita una conexión separada para servicios, usamos la unificada
const servicesDb = db;

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

  // Obtener el user_id a partir del email
  db.get(`SELECT id FROM users WHERE email = ?`, [user_email], (err, user) => {
    if (err) {
      console.error('Error buscando usuario:', err);
      return res.status(500).json({ error: 'Error buscando usuario' });
    }

    if (!user) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }

    servicesDb.run(`INSERT INTO services_in_search (user_id, title, description, time_quantity, time_unit, budget, worker_info, additional_info, status) 
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`, 
                    [user.id, title, description, time_quantity, time_unit, budget, worker_info, additional_info, 'EN ESPERA'], function(err) {
      if (err) {
        console.error('Error publicando servicio:', err);
        return res.status(500).json({ error: 'Error publicando servicio' });
      }
      res.json({ message: 'Servicio publicado exitosamente', id: this.lastID });
    });
  });
});

// Endpoint para obtener servicios en busca de aliados (sin asignar)
app.get('/services-in-search', (req, res) => {
  const { user_email } = req.query;

  // Si se proporciona un email, filtrar por ese usuario
  if (user_email) {
    db.get(`SELECT id FROM users WHERE email = ?`, [user_email], (err, user) => {
      if (err) {
        return res.status(500).json({ error: 'Error buscando usuario' });
      }

      if (!user) {
        return res.status(404).json({ error: 'Usuario no encontrado' });
      }

      servicesDb.all(`SELECT * FROM services_in_search WHERE assigned = 0 AND user_id = ? ORDER BY created_at DESC`, [user.id], (err, rows) => {
        if (err) {
          return res.status(500).json({ error: 'Error obteniendo servicios en busca de aliados' });
        }
        res.json({ services_in_search: rows });
      });
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

// Endpoint para guardar busqueda reciente
app.post('/search-history', (req, res) => {
  const { user_email, search_query } = req.body;

  if (!user_email || !search_query) {
    return res.status(400).json({ error: 'Email de usuario y consulta de búsqueda son requeridos' });
  }

  // Eliminar busqueda duplicada si existe
  db.run(`DELETE FROM search_history WHERE user_email = ? AND search_query = ?`, [user_email, search_query], (err) => {
    if (err) {
      console.error('Error eliminando busqueda duplicada:', err);
      return res.status(500).json({ error: 'Error eliminando busqueda duplicada' });
    }

    // Guardar nueva busqueda
    db.run(`INSERT INTO search_history (user_email, search_query) VALUES (?, ?)`, [user_email, search_query], function(err) {
      if (err) {
        console.error('Error guardando busqueda reciente:', err);
        return res.status(500).json({ error: 'Error guardando busqueda reciente' });
      }
      res.json({ message: 'Busqueda guardada exitosamente', id: this.lastID });
    });
  });
});

// Endpoint para obtener busquedas recientes
app.get('/search-history', (req, res) => {
  const { user_email } = req.query;

  if (!user_email) {
    return res.status(400).json({ error: 'Email de usuario es requerido' });
  }

  db.all(`SELECT * FROM search_history WHERE user_email = ? ORDER BY created_at DESC LIMIT 10`, [user_email], (err, rows) => {
    if (err) {
      console.error('Error obteniendo busquedas recientes:', err);
      return res.status(500).json({ error: 'Error obteniendo busquedas recientes' });
    }
    res.json({ search_history: rows });
  });
});

// Endpoint para eliminar busqueda reciente
app.delete('/search-history/:id', (req, res) => {
  const { id } = req.params;

  if (!id) {
    return res.status(400).json({ error: 'ID de busqueda es requerido' });
  }

  db.run(`DELETE FROM search_history WHERE id = ?`, [id], function(err) {
    if (err) {
      console.error('Error eliminando busqueda:', err);
      return res.status(500).json({ error: 'Error eliminando busqueda' });
    }
    if (this.changes === 0) {
      return res.status(404).json({ error: 'Busqueda no encontrada' });
    }
    res.json({ message: 'Busqueda eliminada exitosamente' });
  });
});

// Endpoint para buscar servicios (ignorando mayusculas)
app.get('/search-services', (req, res) => {
  const { query } = req.query;

  if (!query) {
    return res.status(400).json({ error: 'Consulta de búsqueda es requerida' });
  }

  // Convertir a minusculas para búsqueda insensible
  const normalizedQuery = query.toLowerCase();

  // Buscar servicios con coincidencia insensible
  servicesDb.all(`SELECT id, name FROM services WHERE LOWER(name) LIKE ?`, [`%${normalizedQuery}%`], (err, rows) => {
    if (err) {
      console.error('Error buscando servicios:', err);
      return res.status(500).json({ error: 'Error buscando servicios' });
    }
    console.log('Búsqueda:', query, 'Resultados:', rows);
    res.json({ services: rows });
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Servidor corriendo en puerto ${PORT} (accesible desde red)`);
  console.log(`Para acceder a la base de datos: http://localhost:${PORT}/services-in-search`);
});
