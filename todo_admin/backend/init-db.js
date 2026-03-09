const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const DB_PATH = path.join(__dirname, '../../databases');
const DB_FILE = path.join(DB_PATH, 'admins.db');

const db = new sqlite3.Database(DB_FILE, (err) => {
  if (err) {
    console.error('Error opening admins.db:', err.message);
  } else {
    console.log('Connected to admins.db');
    createTables();
  }
});

function createTables() {
  // Crear tabla de admins
  db.run(`CREATE TABLE IF NOT EXISTS admins (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    email TEXT UNIQUE,
    name TEXT NOT NULL,
    role TEXT DEFAULT 'admin',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`, (err) => {
    if (err) {
      console.error('Error creating admins table:', err.message);
    } else {
      console.log('Admins table ready');
      insertDefaultAdmin();
    }
  });
}

function insertDefaultAdmin() {
  db.get(`SELECT COUNT(*) as count FROM admins`, (err, row) => {
    if (err) {
      console.error('Error counting admins:', err.message);
    } else if (row.count === 0) {
      const defaultAdmin = {
        username: 'admin',
        password: '123',
        email: 'admin@todoapp.com',
        name: 'Administrador Principal'
      };

      db.run(`INSERT INTO admins (username, password, email, name) VALUES (?, ?, ?, ?)`,
        [defaultAdmin.username, defaultAdmin.password, defaultAdmin.email, defaultAdmin.name],
        (err) => {
          if (err) {
            console.error('Error inserting default admin:', err.message);
          } else {
            console.log('Default admin user created successfully');
          }
        }
      );
    } else {
      console.log('Admin users already exist');
    }
  });
}

// Cerrar la conexión cuando el script termine
process.on('SIGINT', () => {
  db.close((err) => {
    if (err) {
      console.error('Error closing database:', err.message);
    } else {
      console.log('Database connection closed');
    }
    process.exit(0);
  });
});

// Ejecutar el script y cerrar la conexión
setTimeout(() => {
  db.close((err) => {
    if (err) {
      console.error('Error closing database:', err.message);
    } else {
      console.log('Database connection closed');
    }
    process.exit(0);
  });
}, 1000);
