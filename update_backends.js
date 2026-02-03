const fs = require('fs');
const path = require('path');

// Configuración de rutas
const USERS_BACKEND = path.join(__dirname, 'todo_users', 'backend', 'index.js');
const ALLIES_BACKEND = path.join(__dirname, 'todo_allies', 'backend', 'index.js');

// Plantilla para el código de conexión a la nueva base de datos
const DB_CONNECTION = `// Base de datos SQLite unificada
const db = new sqlite3.Database('../../databases/todo.db', (err) => {
  if (err) {
    console.error('Error abriendo DB unificada:', err.message);
  } else {
    console.log('Conectado a SQLite DB unificada.');
    
    // Verificar tablas existentes (no se crean si no existen)
    db.run(\`CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT UNIQUE NOT NULL,
      nombre TEXT NOT NULL,
      apellido TEXT NOT NULL,
      role TEXT DEFAULT 'user',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )\`);
    
    db.run(\`CREATE TABLE IF NOT EXISTS allies (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT UNIQUE NOT NULL,
      nombre TEXT NOT NULL,
      apellido TEXT NOT NULL,
      role TEXT DEFAULT 'ally',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )\`);
    
    db.run(\`CREATE TABLE IF NOT EXISTS services (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT UNIQUE NOT NULL,
      description TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )\`);
    
    db.run(\`CREATE TABLE IF NOT EXISTS services_in_search (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      time_quantity INTEGER NOT NULL,
      time_unit TEXT NOT NULL,
      budget TEXT NOT NULL,
      worker_info TEXT NOT NULL,
      additional_info TEXT NOT NULL,
      status TEXT DEFAULT 'EN ESPERA',
      assigned BOOLEAN DEFAULT 0,
      ally_id INTEGER,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
      FOREIGN KEY (ally_id) REFERENCES allies(id) ON DELETE SET NULL
    )\`);
    
    db.run(\`CREATE TABLE IF NOT EXISTS ally_services (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      ally_id INTEGER,
      service_id INTEGER,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (ally_id) REFERENCES allies(id) ON DELETE CASCADE,
      FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE CASCADE,
      UNIQUE(ally_id, service_id)
    )\`);
    
    db.run(\`CREATE TABLE IF NOT EXISTS messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sender_id INTEGER,
      receiver_id INTEGER,
      sender_role TEXT NOT NULL,
      receiver_role TEXT NOT NULL,
      service_in_search_id INTEGER,
      message TEXT NOT NULL,
      read BOOLEAN DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (service_in_search_id) REFERENCES services_in_search(id) ON DELETE CASCADE
    )\`);
    
    // Crear índices si no existen
    db.run(\`CREATE INDEX IF NOT EXISTS idx_services_in_search_user ON services_in_search(user_id)\`);
    db.run(\`CREATE INDEX IF NOT EXISTS idx_services_in_search_ally ON services_in_search(ally_id)\`);
    db.run(\`CREATE INDEX IF NOT EXISTS idx_services_in_search_status ON services_in_search(status)\`);
    db.run(\`CREATE INDEX IF NOT EXISTS idx_services_in_search_assigned ON services_in_search(assigned)\`);
    db.run(\`CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id, sender_role)\`);
    db.run(\`CREATE INDEX IF NOT EXISTS idx_messages_receiver ON messages(receiver_id, receiver_role)\`);
    db.run(\`CREATE INDEX IF NOT EXISTS idx_messages_service ON messages(service_in_search_id)\`);
  }
});

// No se necesita una conexión separada para servicios, usamos la unificada
const servicesDb = db;
`;

// Función para actualizar el backend de users
function updateUsersBackend() {
  try {
    let backendCode = fs.readFileSync(USERS_BACKEND, 'utf8');

    // Eliminar conexiones a bases de datos antiguas
    const oldConnections = backendCode.match(/const db = new sqlite3\.Database.*?;[\s\S]*?const servicesDb = new sqlite3\.Database.*?;/s);
    if (oldConnections) {
      backendCode = backendCode.replace(oldConnections[0], DB_CONNECTION);
    }

    // Actualizar consultas para usar la nueva estructura
    backendCode = backendCode.replace(/user_email\s*=\s*\?/g, 'user_id = ?');
    backendCode = backendCode.replace(/SELECT.*FROM services_in_search.*user_email/g, 'SELECT * FROM services_in_search WHERE user_id');
    backendCode = backendCode.replace(/INSERT INTO services_in_search.*user_email/g, 'INSERT INTO services_in_search (user_id');

    // Guardar el código actualizado
    fs.writeFileSync(USERS_BACKEND, backendCode, 'utf8');
    console.log('Backend de users actualizado');
  } catch (err) {
    console.error('Error al actualizar el backend de users:', err.message);
  }
}

// Función para actualizar el backend de allies
function updateAlliesBackend() {
  try {
    let backendCode = fs.readFileSync(ALLIES_BACKEND, 'utf8');

    // Eliminar conexiones a bases de datos antiguas
    const oldConnections = backendCode.match(/const db = new sqlite3\.Database.*?;[\s\S]*?const servicesDb = new sqlite3\.Database.*?;/s);
    if (oldConnections) {
      backendCode = backendCode.replace(oldConnections[0], DB_CONNECTION);
    }

    // Guardar el código actualizado
    fs.writeFileSync(ALLIES_BACKEND, backendCode, 'utf8');
    console.log('Backend de allies actualizado');
  } catch (err) {
    console.error('Error al actualizar el backend de allies:', err.message);
  }
}

// Función para crear respaldos de los backends antiguos
function backupBackends() {
  const USERS_BACKEND_OLD = path.join(__dirname, 'todo_users', 'backend', 'index.js.old');
  const ALLIES_BACKEND_OLD = path.join(__dirname, 'todo_allies', 'backend', 'index.js.old');

  try {
    if (!fs.existsSync(USERS_BACKEND_OLD)) {
      fs.copyFileSync(USERS_BACKEND, USERS_BACKEND_OLD);
    }
    if (!fs.existsSync(ALLIES_BACKEND_OLD)) {
      fs.copyFileSync(ALLIES_BACKEND, ALLIES_BACKEND_OLD);
    }
    console.log('Respaldo de backends completado');
  } catch (err) {
    console.error('Error al crear respaldos:', err.message);
  }
}

// Función principal
function main() {
  console.log('=== Iniciando actualización de backends ===');

  // Crear respaldos de los backends antiguos
  backupBackends();

  // Actualizar cada backend
  updateUsersBackend();
  updateAlliesBackend();

  console.log('=== Actualización completada ===');
  console.log('Backends antiguos respaldados con extensión .old');
}

// Ejecutar
main();
