const express = require('express');
const cors = require('cors');
const mailgun = require('mailgun-js');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');
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

// Ruta base de las bases de datos
const DB_PATH = path.join(__dirname, '../../databases');

// Conexiones a las bases de datos separadas
const alliesDb = new sqlite3.Database(path.join(DB_PATH, 'allies.db'), (err) => {
  if (err) {
    console.error('Error abriendo allies.db:', err.message);
  } else {
    console.log('Conectado a allies.db');
    // Crear tabla de aliados si no existe
    alliesDb.run(`CREATE TABLE IF NOT EXISTS allies (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT UNIQUE NOT NULL,
      nombre TEXT NOT NULL,
      apellido TEXT NOT NULL,
      role TEXT DEFAULT 'ally',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`, (err) => {
      if (err) {
        console.error('Error creando tabla allies:', err.message);
      } else {
        console.log('Tabla allies lista');
      }
    });
  }
});

const servicesDb = new sqlite3.Database(path.join(DB_PATH, 'services.db'), (err) => {
  if (err) {
    console.error('Error abriendo services.db:', err.message);
  } else {
    console.log('Conectado a services.db');
    // Crear tabla de servicios si no existe
    servicesDb.run(`CREATE TABLE IF NOT EXISTS services (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT UNIQUE NOT NULL,
      description TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`, (err) => {
      if (err) {
        console.error('Error creando tabla services:', err.message);
      } else {
        console.log('Tabla services lista');
      }
    });
    
    // Crear tabla de servicios en búsqueda si no existe
    servicesDb.run(`CREATE TABLE IF NOT EXISTS services_in_search (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      title TEXT NOT NULL,
      description TEXT,
      time_quantity INTEGER,
      time_unit TEXT,
      budget TEXT,
      worker_info TEXT,
      status TEXT DEFAULT 'EN ESPERA',
      assigned INTEGER DEFAULT 0,
      ally_id INTEGER,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`, (err) => {
      if (err) {
        console.error('Error creando tabla services_in_search:', err.message);
      } else {
        console.log('Tabla services_in_search lista');
      }
    });
    
    // Crear tabla de relación aliado-servicio si no existe
    servicesDb.run(`CREATE TABLE IF NOT EXISTS ally_services (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      ally_id INTEGER NOT NULL,
      service_id INTEGER NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(ally_id, service_id)
    )`, (err) => {
      if (err) {
        console.error('Error creando tabla ally_services:', err.message);
      } else {
        console.log('Tabla ally_services lista');
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
    from: 'Tu App tudu <noreply@tuapp.com>',
    to: email,
    subject: 'Código de verificación tudu',
    text: `Tu código de verificación es: ${otp}. Este código expira en 10 minutos.`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #78BF32;">Código de verificación tudu</h2>
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

// Endpoint para verificar si aliado existe (en allies.db)
app.post('/check-ally', (req, res) => {
  const { email } = req.body;

  if (!email) {
    return res.status(400).json({ error: 'Email es requerido' });
  }

  alliesDb.get(`SELECT id, nombre, apellido FROM allies WHERE email = ?`, [email], (err, row) => {
    if (err) {
      return res.status(500).json({ error: 'Error verificando aliado' });
    }
    if (row) {
      res.json({ exists: true, ally: row });
    } else {
      res.json({ exists: false });
    }
  });
});

// Endpoint para registrar aliado (en allies.db)
app.post('/register-ally', (req, res) => {
  const { email, nombre, apellido } = req.body;

  if (!email || !nombre || !apellido) {
    return res.status(400).json({ error: 'Email, nombre y apellido son requeridos' });
  }

  if (nombre.length > 20) {
    return res.status(400).json({ error: 'El nombre no puede exceder 20 caracteres' });
  }

  if (apellido.length > 20) {
    return res.status(400).json({ error: 'El apellido no puede exceder 20 caracteres' });
  }

  alliesDb.run(`INSERT INTO allies (email, nombre, apellido) VALUES (?, ?, ?)`, [email, nombre, apellido], function(err) {
    if (err) {
      if (err.code === 'SQLITE_CONSTRAINT' || err.code === 'SQLITE_CONSTRAINT_UNIQUE') {
        return res.status(400).json({ error: 'Aliado ya registrado' });
      }
      console.error('Error registrando aliado:', err);
      return res.status(500).json({ error: 'Error registrando aliado' });
    }
    res.json({ message: 'Aliado registrado exitosamente', id: this.lastID });
  });
});

// Endpoint para obtener tudus los servicios (desde services.db)
app.get('/services', (req, res) => {
  servicesDb.all(`SELECT id, name FROM services ORDER BY created_at DESC`, [], (err, rows) => {
    if (err) {
      return res.status(500).json({ error: 'Error obteniendo servicios' });
    }
    res.json({ services: rows });
  });
});

// Endpoint para obtener servicios en busca de aliados (sin asignar) - desde services.db
app.get('/services-in-search', (req, res) => {
  servicesDb.all(`SELECT * FROM services_in_search WHERE assigned = 0 ORDER BY created_at DESC`, (err, rows) => {
    if (err) {
      return res.status(500).json({ error: 'Error obteniendo servicios en busca de aliados' });
    }
    res.json({ services_in_search: rows });
  });
});

// Endpoint para marcar un servicio como asignado
app.put('/services-in-search/:id/assign', (req, res) => {
  const { id } = req.params;
  const { ally_email } = req.body;

  if (!ally_email) {
    return res.status(400).json({ error: 'Email del aliado es requerido' });
  }

  // Obtener el ally_id a partir del email (en allies.db)
  alliesDb.get(`SELECT id FROM allies WHERE email = ?`, [ally_email], (err, ally) => {
    if (err) {
      console.error('Error buscando aliado:', err);
      return res.status(500).json({ error: 'Error buscando aliado' });
    }

    if (!ally) {
      return res.status(404).json({ error: 'Aliado no encontrado' });
    }

    // Actualizar en services.db
    servicesDb.run(`UPDATE services_in_search SET assigned = 1, status = 'EN PROCESO', ally_id = ? WHERE id = ?`, [ally.id, id], function(err) {
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

// Endpoint para obtener servicios asignados a un aliado
app.get('/my-services', (req, res) => {
  const { ally_email } = req.query;

  if (!ally_email) {
    return res.status(400).json({ error: 'Email del aliado es requerido' });
  }

  alliesDb.get(`SELECT id FROM allies WHERE email = ?`, [ally_email], (err, ally) => {
    if (err) {
      return res.status(500).json({ error: 'Error buscando aliado' });
    }

    if (!ally) {
      return res.status(404).json({ error: 'Aliado no encontrado' });
    }

    servicesDb.all(`SELECT * FROM services_in_search WHERE ally_id = ? ORDER BY created_at DESC`, [ally.id], (err, rows) => {
      if (err) {
        return res.status(500).json({ error: 'Error obteniendo servicios' });
      }
      res.json({ my_services: rows });
    });
  });
});

// Cerrar conexiones a las bases de datos al terminar la aplicación
process.on('SIGINT', () => {
  alliesDb.close();
  servicesDb.close();
  process.exit(0);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Servidor corriendo en puerto ${PORT} (accesible desde red)`);
  console.log(`Bases de datos conectadas:`);
  console.log(`  - allies.db (aliados)`);
  console.log(`  - services.db (servicios)`);
});
