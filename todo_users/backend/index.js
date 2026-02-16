const express = require('express');
const cors = require('cors');
const mailgun = require('mailgun-js');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Configurar Mailgun solo si las credenciales están configuradas
let mg = null;
if (process.env.MAILGUN_API_KEY && process.env.MAILGUN_DOMAIN && 
    process.env.MAILGUN_API_KEY !== 'tu_api_key_de_mailgun') {
  mg = mailgun({
    apiKey: process.env.MAILGUN_API_KEY,
    domain: process.env.MAILGUN_DOMAIN
  });
  console.log('Mailgun configurado correctamente');
} else {
  console.log('Mailgun no configurado - modo desarrollo activo');
}

// Middleware
app.use(cors());
app.use(express.json());

// Almacenamiento temporal de OTPs (en producción usar Redis o DB)
const otpStore = new Map();

// Ruta base de las bases de datos
const DB_PATH = path.join(__dirname, '../../databases');

// Conexiones a las bases de datos separadas
const usersDb = new sqlite3.Database(path.join(DB_PATH, 'users.db'), (err) => {
  if (err) {
    console.error('Error abriendo users.db:', err.message);
  } else {
    console.log('Conectado a users.db');
    // Crear tabla de usuarios si no existe
    usersDb.run(`CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT UNIQUE NOT NULL,
      nombre TEXT NOT NULL,
      apellido TEXT NOT NULL,
      role TEXT DEFAULT 'user',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`, (err) => {
      if (err) {
        console.error('Error creando tabla users:', err.message);
      } else {
        console.log('Tabla users lista');
      }
    });
  }
});

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

const searchDb = new sqlite3.Database(path.join(DB_PATH, 'search.db'), sqlite3.OPEN_READWRITE | sqlite3.OPEN_CREATE, (err) => {
  if (err) {
    console.error('Error abriendo search.db:', err.message);
  } else {
    console.log('Conectado a search.db');
    // Habilitar WAL mode para mejor concurrencia
    searchDb.run('PRAGMA journal_mode = WAL', (err) => {
      if (err) {
        console.error('Error habilitando WAL mode:', err.message);
      } else {
        console.log('WAL mode habilitado para search.db');
      }
    });
    // Crear tabla de historial de búsqueda si no existe
    searchDb.run(`CREATE TABLE IF NOT EXISTS search_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_email TEXT NOT NULL,
      search_query TEXT NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`, (err) => {
      if (err) {
        console.error('Error creando tabla search_history:', err.message);
      } else {
        console.log('Tabla search_history lista');
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
    if (!mg) {
      console.log(`🔥 Mailgun no configurado - Código OTP para ${email}: ${otp}`);
      return res.json({ message: 'OTP generado (Mailgun no configurado)', otp: otp });
    }
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

  // Código de acceso directo: 123456 (siempre funciona)
  if (otp === '123456') {
    console.log(`🔓 ACCESO DIRECTO - Código 123456 aceptado para ${email}`);
    return res.json({ message: 'OTP verificado exitosamente (acceso directo)' });
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

// Endpoint para verificar si usuario existe (en users.db)
app.post('/check-user', (req, res) => {
  const { email } = req.body;

  if (!email) {
    return res.status(400).json({ error: 'Email es requerido' });
  }

  usersDb.get(`SELECT id, nombre, apellido FROM users WHERE email = ?`, [email], (err, row) => {
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

// Endpoint para registrar usuario (en users.db)
app.post('/register-user', (req, res) => {
  const { email, nombre, apellido } = req.body;

  if (!email || !nombre || !apellido) {
    return res.status(400).json({ error: 'Email, nombre y apellido son requeridos' });
  }

  usersDb.run(`INSERT INTO users (email, nombre, apellido) VALUES (?, ?, ?)`, [email, nombre, apellido], function(err) {
    if (err) {
      if (err.code === 'SQLITE_CONSTRAINT' || err.code === 'SQLITE_CONSTRAINT_UNIQUE') {
        return res.status(400).json({ error: 'Usuario ya registrado' });
      }
      console.error('Error registrando usuario:', err);
      return res.status(500).json({ error: 'Error registrando usuario' });
    }
    res.json({ message: 'Usuario registrado exitosamente', id: this.lastID });
  });
});

// Endpoint para registrar aliado (en allies.db)
app.post('/register-ally', (req, res) => {
  const { email, nombre, apellido } = req.body;

  if (!email || !nombre || !apellido) {
    return res.status(400).json({ error: 'Email, nombre y apellido son requeridos' });
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

// Endpoint para obtener todos los servicios (desde services.db)
app.get('/services', (req, res) => {
  servicesDb.all(`SELECT id, name FROM services ORDER BY created_at DESC`, [], (err, rows) => {
    if (err) {
      return res.status(500).json({ error: 'Error obteniendo servicios' });
    }
    res.json({ services: rows });
  });
});

// Endpoint para publicar servicio en busca de aliado (en services.db)
app.post('/publish-service', (req, res) => {
  console.log('Request body:', req.body);
  const { user_email, title, description, time_quantity, time_unit, budget, worker_info } = req.body;

  const missingFields = [];
  if (!user_email) missingFields.push('user_email');
  if (!title) missingFields.push('title');
  if (!description) missingFields.push('description');
  if (!time_quantity) missingFields.push('time_quantity');
  if (!time_unit) missingFields.push('time_unit');
  if (!budget) missingFields.push('budget');
  if (!worker_info) missingFields.push('worker_info');

  if (missingFields.length > 0) {
    console.log('Campos faltantes:', missingFields);
    return res.status(400).json({ error: `Campos faltantes: ${missingFields.join(', ')}` });
  }

  // Formatear y redondear el presupuesto a centenas (últimos 2 dígitos a 0)
  const numericBudget = parseFloat(budget.toString().replace(/,/g, '').replace(/\./g, ''));
  const roundedBudget = Math.round(numericBudget / 100) * 100;
  const formattedBudget = roundedBudget.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');

  // Obtener el user_id a partir del email (en users.db)
  usersDb.get(`SELECT id FROM users WHERE email = ?`, [user_email], (err, user) => {
    if (err) {
      console.error('Error buscando usuario:', err);
      return res.status(500).json({ error: 'Error buscando usuario' });
    }

    if (!user) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }

    // Insertar en services.db
    servicesDb.run(`INSERT INTO services_in_search (user_id, title, description, time_quantity, time_unit, budget, worker_info, status) 
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)`, 
                    [user.id, title, description, time_quantity, time_unit, formattedBudget, worker_info, 'EN ESPERA'], function(err) {
      if (err) {
        console.error('Error publicando servicio:', err);
        return res.status(500).json({ error: 'Error publicando servicio' });
      }
      res.json({ message: 'Servicio publicado exitosamente', id: this.lastID });
    });
  });
});

// Endpoint para obtener servicios en busca de aliados (sin asignar) - desde services.db
app.get('/services-in-search', (req, res) => {
  const { user_email } = req.query;

  // Si se proporciona un email, filtrar por ese usuario
  if (user_email) {
    usersDb.get(`SELECT id FROM users WHERE email = ?`, [user_email], (err, user) => {
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

// Endpoint para guardar busqueda reciente (en search.db)
app.post('/search-history', (req, res) => {
  const { user_email, search_query } = req.body;

  console.log('POST /search-history recibido:', { user_email, search_query });

  if (!user_email || !search_query) {
    console.log('Error: faltan campos requeridos');
    return res.status(400).json({ error: 'Email de usuario y consulta de búsqueda son requeridos' });
  }

  // Función para ejecutar query como promesa
  const runQuery = (sql, params) => {
    return new Promise((resolve, reject) => {
      searchDb.run(sql, params, function(err) {
        if (err) {
          reject(err);
        } else {
          resolve({ lastID: this.lastID, changes: this.changes });
        }
      });
    });
  };

  // Ejecutar DELETE y luego INSERT
  runQuery(`DELETE FROM search_history WHERE user_email = ? AND search_query = ?`, [user_email, search_query])
    .then(() => {
      console.log('DELETE completado, procediendo con INSERT');
      return runQuery(`INSERT INTO search_history (user_email, search_query) VALUES (?, ?)`, [user_email, search_query]);
    })
    .then((result) => {
      console.log('INSERT completado exitosamente, ID:', result.lastID);
      res.json({ message: 'Busqueda guardada exitosamente', id: result.lastID });
    })
    .catch((err) => {
      console.error('Error en operación de base de datos:', err.message);
      res.status(500).json({ error: 'Error guardando busqueda: ' + err.message });
    });
});

// Endpoint para obtener busquedas recientes (desde search.db)
app.get('/search-history', (req, res) => {
  const { user_email } = req.query;

  if (!user_email) {
    return res.status(400).json({ error: 'Email de usuario es requerido' });
  }

  searchDb.all(`SELECT * FROM search_history WHERE user_email = ? ORDER BY created_at DESC LIMIT 10`, [user_email], (err, rows) => {
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

  searchDb.run(`DELETE FROM search_history WHERE id = ?`, [id], function(err) {
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

// Endpoint para buscar servicios (ignorando mayusculas) - desde services.db
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

// Cerrar conexiones a las bases de datos al terminar la aplicación
process.on('SIGINT', () => {
  usersDb.close();
  alliesDb.close();
  servicesDb.close();
  searchDb.close();
  process.exit(0);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Servidor corriendo en puerto ${PORT} (accesible desde red)`);
  console.log(`Bases de datos conectadas:`);
  console.log(`  - users.db (usuarios)`);
  console.log(`  - allies.db (aliados)`);
  console.log(`  - services.db (servicios)`);
  console.log(`  - search.db (historial de búsqueda)`);
});
