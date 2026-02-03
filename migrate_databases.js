const sqlite3 = require('sqlite3').verbose();
const fs = require('fs');
const path = require('path');

// Directorios
const DB_DIR = path.join(__dirname, 'databases');
const OLD_DB_DIR = path.join(__dirname, 'databases_old');

// Crear directorio para respaldos si no existe
if (!fs.existsSync(OLD_DB_DIR)) {
  fs.mkdirSync(OLD_DB_DIR);
}

// Nombre de la nueva base de datos unificada
const NEW_DB_PATH = path.join(DB_DIR, 'todo.db');

// Función para respaldar bases de datos antiguas
function backupOldDatabase(oldPath, newPath) {
  return new Promise((resolve, reject) => {
    fs.copyFile(oldPath, newPath, (err) => {
      if (err) {
        reject(err);
      } else {
        resolve();
      }
    });
  });
}

// Función para crear la nueva estructura de base de datos
function createNewDatabase() {
  return new Promise((resolve, reject) => {
    const db = new sqlite3.Database(NEW_DB_PATH, (err) => {
      if (err) {
        return reject(err);
      }

      // Crear tablas
      const createTables = `
        -- Tabla de usuarios
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          email TEXT UNIQUE NOT NULL,
          nombre TEXT NOT NULL,
          apellido TEXT NOT NULL,
          role TEXT DEFAULT 'user',
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        -- Tabla de aliados
        CREATE TABLE IF NOT EXISTS allies (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          email TEXT UNIQUE NOT NULL,
          nombre TEXT NOT NULL,
          apellido TEXT NOT NULL,
          role TEXT DEFAULT 'ally',
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        -- Tabla de servicios
        CREATE TABLE IF NOT EXISTS services (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT UNIQUE NOT NULL,
          description TEXT,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        -- Tabla de servicios en busca de aliados (con relación a usuario)
        CREATE TABLE IF NOT EXISTS services_in_search (
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
        );

        -- Índices para optimizar consultas
        CREATE INDEX IF NOT EXISTS idx_services_in_search_user ON services_in_search(user_id);
        CREATE INDEX IF NOT EXISTS idx_services_in_search_ally ON services_in_search(ally_id);
        CREATE INDEX IF NOT EXISTS idx_services_in_search_status ON services_in_search(status);
        CREATE INDEX IF NOT EXISTS idx_services_in_search_assigned ON services_in_search(assigned);

        -- Tabla de relación entre aliados y servicios (especializaciones)
        CREATE TABLE IF NOT EXISTS ally_services (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ally_id INTEGER,
          service_id INTEGER,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (ally_id) REFERENCES allies(id) ON DELETE CASCADE,
          FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE CASCADE,
          UNIQUE(ally_id, service_id)
        );

        -- Tabla de mensajes entre usuarios y aliados
        CREATE TABLE IF NOT EXISTS messages (
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
        );

        -- Índices para optimizar mensajes
        CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id, sender_role);
        CREATE INDEX IF NOT EXISTS idx_messages_receiver ON messages(receiver_id, receiver_role);
        CREATE INDEX IF NOT EXISTS idx_messages_service ON messages(service_in_search_id);
      `;

      db.exec(createTables, (err) => {
        if (err) {
          db.close();
          return reject(err);
        }
        console.log('Estructura de base de datos creada');
        resolve(db);
      });
    });
  });
}

// Función para migrar datos desde la antigua base de datos de users
function migrateUsersData(newDb) {
  return new Promise((resolve, reject) => {
    const oldDb = new sqlite3.Database(path.join(DB_DIR, 'users.db'));

    oldDb.all('SELECT * FROM users', (err, users) => {
      if (err) {
        oldDb.close();
        return reject(err);
      }

      let usersMigrated = 0;
      const totalUsers = users.length;

      if (totalUsers === 0) {
        oldDb.close();
        return resolve();
      }

      users.forEach(user => {
        newDb.run(
          'INSERT OR IGNORE INTO users (id, email, nombre, apellido, created_at) VALUES (?, ?, ?, ?, ?)',
          [user.id, user.email, user.nombre, user.apellido, user.created_at],
          (err) => {
            if (err) {
              console.error('Error migrando usuario:', user.email, err.message);
            } else {
              console.log('Usuario migrado:', user.email);
            }
            usersMigrated++;
            if (usersMigrated === totalUsers) {
              oldDb.close();
              resolve();
            }
          }
        );
      });
    });
  });
}

// Función para migrar datos desde la antigua base de datos de allies
function migrateAlliesData(newDb) {
  return new Promise((resolve, reject) => {
    const oldDb = new sqlite3.Database(path.join(DB_DIR, 'allies.db'));

    oldDb.all('SELECT * FROM allies', (err, allies) => {
      if (err) {
        oldDb.close();
        return reject(err);
      }

      let alliesMigrated = 0;
      const totalAllies = allies.length;

      if (totalAllies === 0) {
        oldDb.close();
        return resolve();
      }

      allies.forEach(ally => {
        newDb.run(
          'INSERT OR IGNORE INTO allies (id, email, nombre, apellido, created_at) VALUES (?, ?, ?, ?, ?)',
          [ally.id, ally.email, ally.nombre, ally.apellido, ally.created_at],
          (err) => {
            if (err) {
              console.error('Error migrando aliado:', ally.email, err.message);
            } else {
              console.log('Aliado migrado:', ally.email);
            }
            alliesMigrated++;
            if (alliesMigrated === totalAllies) {
              oldDb.close();
              resolve();
            }
          }
        );
      });
    });
  });
}

// Función para migrar datos desde la antigua base de datos de services
function migrateServicesData(newDb) {
  return new Promise((resolve, reject) => {
    const oldDb = new sqlite3.Database(path.join(DB_DIR, 'services.db'));

    // Migrar servicios
    oldDb.all('SELECT * FROM services', (err, services) => {
      if (err) {
        oldDb.close();
        return reject(err);
      }

      let servicesMigrated = 0;
      const totalServices = services.length;

      if (totalServices === 0) {
        // Continuar con servicios_in_search
        migrateServicesInSearchData(newDb, oldDb, resolve, reject);
      } else {
        services.forEach(service => {
          newDb.run(
            'INSERT OR IGNORE INTO services (id, name, created_at) VALUES (?, ?, ?)',
            [service.id, service.name, service.created_at],
            (err) => {
              if (err) {
                console.error('Error migrando servicio:', service.name, err.message);
              } else {
                console.log('Servicio migrado:', service.name);
              }
              servicesMigrated++;
              if (servicesMigrated === totalServices) {
                // Migrar servicios_in_search
                migrateServicesInSearchData(newDb, oldDb, resolve, reject);
              }
            }
          );
        });
      }
    });
  });
}

// Función auxiliar para migrar servicios_in_search
function migrateServicesInSearchData(newDb, oldDb, resolve, reject) {
  oldDb.all('SELECT * FROM services_in_search', (err, servicesInSearch) => {
    if (err) {
      oldDb.close();
      return reject(err);
    }

    let servicesInSearchMigrated = 0;
    const totalServicesInSearch = servicesInSearch.length;

    if (totalServicesInSearch === 0) {
      oldDb.close();
      return resolve();
    }

    servicesInSearch.forEach(service => {
      // Obtener user_id usando el email
      newDb.get(
        'SELECT id FROM users WHERE email = ?',
        [service.user_email],
        (err, user) => {
          const userId = user ? user.id : null;
          
          newDb.run(
            `INSERT OR IGNORE INTO services_in_search 
            (id, user_id, title, description, time_quantity, time_unit, budget, worker_info, additional_info, status, assigned, created_at) 
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [
              service.id,
              userId,
              service.title,
              service.description,
              service.time_quantity,
              service.time_unit,
              service.budget,
              service.worker_info,
              service.additional_info,
              service.status,
              service.assigned,
              service.created_at
            ],
            (err) => {
              if (err) {
                console.error('Error migrando servicio en busca:', service.title, err.message);
              } else {
                console.log('Servicio en busca migrado:', service.title);
              }
              servicesInSearchMigrated++;
              if (servicesInSearchMigrated === totalServicesInSearch) {
                oldDb.close();
                resolve();
              }
            }
          );
        }
      );
    });
  });
}

// Función para insertar servicios de ejemplo si la tabla está vacía
function insertSampleServices(newDb) {
  return new Promise((resolve, reject) => {
    newDb.get('SELECT COUNT(*) as count FROM services', (err, row) => {
      if (err) {
        return reject(err);
      }

      if (row.count === 0) {
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
          'Diseño gráfico',
          'Desarrollo web',
          'Marketing digital',
          'Fotografía',
          'Video edición'
        ];

        let servicesInserted = 0;
        const totalServices = sampleServices.length;

        sampleServices.forEach(name => {
          newDb.run(
            'INSERT INTO services (name) VALUES (?)',
            [name],
            (err) => {
              if (err) {
                console.error('Error insertando servicio de ejemplo:', name, err.message);
              } else {
                console.log('Servicio de ejemplo insertado:', name);
              }
              servicesInserted++;
              if (servicesInserted === totalServices) {
                resolve();
              }
            }
          );
        });
      } else {
        resolve();
      }
    });
  });
}

// Función para verificar la migración
function verifyMigration(newDb) {
  return new Promise((resolve, reject) => {
    const counts = {};

    newDb.get('SELECT COUNT(*) as count FROM users', (err, row) => {
      if (err) return reject(err);
      counts.users = row.count;

      newDb.get('SELECT COUNT(*) as count FROM allies', (err, row) => {
        if (err) return reject(err);
        counts.allies = row.count;

        newDb.get('SELECT COUNT(*) as count FROM services', (err, row) => {
          if (err) return reject(err);
          counts.services = row.count;

          newDb.get('SELECT COUNT(*) as count FROM services_in_search', (err, row) => {
            if (err) return reject(err);
            counts.servicesInSearch = row.count;

            console.log('\n=== Verificación de Migración ===');
            console.log(`Usuarios: ${counts.users}`);
            console.log(`Aliados: ${counts.allies}`);
            console.log(`Servicios: ${counts.services}`);
            console.log(`Servicios en búsqueda: ${counts.servicesInSearch}`);
            resolve(counts);
          });
        });
      });
    });
  });
}

// Función principal de migración
async function main() {
  try {
    console.log('=== Iniciando migración ===');

    // Crear respaldos de las bases de datos antiguas
    console.log('\n1. Creando respaldos de bases de datos antiguas...');
    await Promise.all([
      backupOldDatabase(path.join(DB_DIR, 'users.db'), path.join(OLD_DB_DIR, 'users.db')),
      backupOldDatabase(path.join(DB_DIR, 'allies.db'), path.join(OLD_DB_DIR, 'allies.db')),
      backupOldDatabase(path.join(DB_DIR, 'services.db'), path.join(OLD_DB_DIR, 'services.db'))
    ]);
    console.log('✓ Respaldo completado');

    // Crear nueva base de datos
    console.log('\n2. Creando nueva estructura de base de datos...');
    const newDb = await createNewDatabase();
    console.log('✓ Estructura creada');

    // Migrar datos
    console.log('\n3. Migrando datos...');
    await Promise.all([
      migrateUsersData(newDb),
      migrateAlliesData(newDb),
      migrateServicesData(newDb)
    ]);
    console.log('✓ Migración de datos completada');

    // Insertar servicios de ejemplo si la tabla está vacía
    console.log('\n4. Insertando servicios de ejemplo...');
    await insertSampleServices(newDb);

    // Verificar migración
    const counts = await verifyMigration(newDb);

    console.log('\n=== Migración completada exitosamente ===');
    console.log(`Nueva base de datos: ${NEW_DB_PATH}`);
    console.log('Bases de datos antiguas respaldadas en: /databases_old/');

    newDb.close();

  } catch (error) {
    console.error('\n❌ Error durante la migración:', error.message);
    if (error.stack) {
      console.error('Stack trace:', error.stack);
    }
    process.exit(1);
  }
}

// Ejecutar migración
main();
