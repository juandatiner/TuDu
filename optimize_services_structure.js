const sqlite3 = require('sqlite3').verbose();
const fs = require('fs');
const path = require('path');

// Rutas
const DB_PATH = path.join(__dirname, 'databases', 'todo.db');
const BACKUP_PATH = path.join(__dirname, 'databases', 'todo.db.optimize.backup');

// Crear respaldo antes de optimizar
function backupDatabase() {
  return new Promise((resolve, reject) => {
    if (!fs.existsSync(BACKUP_PATH)) {
      fs.copyFile(DB_PATH, BACKUP_PATH, (err) => {
        if (err) {
          reject(err);
        } else {
          console.log('Respaldo de base de datos creado');
          resolve();
        }
      });
    } else {
      console.log('Respaldo ya existe, continuando');
      resolve();
    }
  });
}

// Optimizar la estructura de servicios para manejar grandes volúmenes
async function optimizeServicesStructure() {
  try {
    console.log('=== Iniciando optimización de estructura de servicios ===');
    
    await backupDatabase();
    
    const db = new sqlite3.Database(DB_PATH);
    
    // 1. Crear una tabla de estados de servicios para normalización
    db.run(`CREATE TABLE IF NOT EXISTS service_statuses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT UNIQUE NOT NULL,
      description TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`, (err) => {
      if (err) console.error('Error creando service_statuses:', err.message);
      else console.log('Tabla service_statuses creada');
    });
    
    // 2. Insertar estados predefinidos
    const statuses = [
      { name: 'EN ESPERA', description: 'Servicio en búsqueda de aliado' },
      { name: 'EN PROCESO', description: 'Servicio asignado y en ejecución' },
      { name: 'TERMINADO', description: 'Servicio completado' },
      { name: 'CANCELADO', description: 'Servicio cancelado por el usuario' },
      { name: 'FINALIZADO', description: 'Servicio finalizado y evaluado' }
    ];
    
    statuses.forEach(status => {
      db.run(
        'INSERT OR IGNORE INTO service_statuses (name, description) VALUES (?, ?)',
        [status.name, status.description],
        (err) => {
          if (err && !err.message.includes('UNIQUE constraint')) {
            console.error('Error insertando estado:', status.name, err.message);
          }
        }
      );
    });
    
    // 3. Optimizar la tabla services_in_search
    // Eliminar la columna status actual y agregar una foreign key a service_statuses
    // Primero, crear una columna temporal para el nuevo estado
    db.run('ALTER TABLE services_in_search ADD COLUMN status_id INTEGER', (err) => {
      if (err && !err.message.includes('duplicate column name')) {
        console.error('Error agregando status_id:', err.message);
      }
    });
    
    // 4. Mapear valores de status a status_id
    statuses.forEach(status => {
      db.run(
        'UPDATE services_in_search SET status_id = (SELECT id FROM service_statuses WHERE name = ?) WHERE status = ?',
        [status.name, status.name],
        (err) => {
          if (err) {
            console.error('Error actualizando status:', status.name, err.message);
          } else {
            console.log(`Status ${status.name} mapeado`);
          }
        }
      );
    });
    
    // 5. Crear índice para status_id para mejorar consultas
    db.run('CREATE INDEX IF NOT EXISTS idx_services_in_search_status_id ON services_in_search(status_id)', (err) => {
      if (err) console.error('Error creando índice para status_id:', err.message);
    });
    
    // 6. Crear tabla para seguimiento de estado de servicios
    db.run(`CREATE TABLE IF NOT EXISTS service_status_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      service_in_search_id INTEGER,
      status_id INTEGER,
      changed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (service_in_search_id) REFERENCES services_in_search(id) ON DELETE CASCADE,
      FOREIGN KEY (status_id) REFERENCES service_statuses(id) ON DELETE SET NULL
    )`, (err) => {
      if (err) console.error('Error creando service_status_history:', err.message);
      else console.log('Tabla service_status_history creada');
    });
    
    // Crear índice para la tabla de historial de estados
    db.run('CREATE INDEX IF NOT EXISTS idx_service_status_history_service ON service_status_history(service_in_search_id)', (err) => {
      if (err) console.error('Error creando índice para service_status_history:', err.message);
    });
    
    // 7. Optimizar la tabla services_in_search con campos adicionales para filtrado
    db.run('ALTER TABLE services_in_search ADD COLUMN urgency INTEGER DEFAULT 1', (err) => {
      if (err && !err.message.includes('duplicate column name')) {
        console.error('Error agregando urgency:', err.message);
      }
    });
    
    db.run('ALTER TABLE services_in_search ADD COLUMN location TEXT', (err) => {
      if (err && !err.message.includes('duplicate column name')) {
        console.error('Error agregando location:', err.message);
      }
    });
    
    // 8. Crear tabla de categorías de servicios para mejorar la organización
    db.run(`CREATE TABLE IF NOT EXISTS service_categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT UNIQUE NOT NULL,
      description TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`, (err) => {
      if (err) console.error('Error creando service_categories:', err.message);
      else console.log('Tabla service_categories creada');
    });
    
    // Insertar categorías predefinidas
    const categories = [
      { name: 'Hogar', description: 'Servicios relacionados con el hogar' },
      { name: 'Construcción', description: 'Servicios de construcción y reparaciones' },
      { name: 'Jardinería', description: 'Servicios de mantenimiento de jardines' },
      { name: 'Limpieza', description: 'Servicios de limpieza' },
      { name: 'Tecnología', description: 'Servicios de tecnología y reparación de dispositivos' },
      { name: 'Diseño', description: 'Servicios de diseño gráfico y web' },
      { name: 'Eventos', description: 'Servicios para eventos' },
      { name: 'Mantenimiento', description: 'Servicios de mantenimiento general' }
    ];
    
    categories.forEach(category => {
      db.run(
        'INSERT OR IGNORE INTO service_categories (name, description) VALUES (?, ?)',
        [category.name, category.description],
        (err) => {
          if (err && !err.message.includes('UNIQUE constraint')) {
            console.error('Error insertando categoría:', category.name, err.message);
          }
        }
      );
    });
    
    // Agregar foreign key a services para categoría
    db.run('ALTER TABLE services ADD COLUMN category_id INTEGER', (err) => {
      if (err && !err.message.includes('duplicate column name')) {
        console.error('Error agregando category_id:', err.message);
      }
    });
    
    // 9. Crear índices adicionales para consultas frecuentes
    db.run('CREATE INDEX IF NOT EXISTS idx_services_category ON services(category_id)', (err) => {
      if (err) console.error('Error creando índice para services.category:', err.message);
    });
    
    db.run('CREATE INDEX IF NOT EXISTS idx_services_in_search_urgency ON services_in_search(urgency)', (err) => {
      if (err) console.error('Error creando índice para urgency:', err.message);
    });
    
    db.run('CREATE INDEX IF NOT EXISTS idx_services_in_search_location ON services_in_search(location)', (err) => {
      if (err) console.error('Error creando índice para location:', err.message);
    });
    
    // 10. Verificar la estructura final
    db.all('SELECT * FROM sqlite_master WHERE type="table" OR type="index" ORDER BY type, name', (err, objects) => {
      if (err) {
        console.error('Error al obtener estructura:', err.message);
      } else {
        console.log('\n=== Estructura final de la base de datos ===');
        
        const tables = objects.filter(obj => obj.type === 'table' && !obj.name.startsWith('sqlite_'));
        const indices = objects.filter(obj => obj.type === 'index' && !obj.name.startsWith('sqlite_'));
        
        console.log(`\nTablas (${tables.length}):`);
        tables.forEach(table => {
          console.log(`  - ${table.name}`);
        });
        
        console.log(`\nÍndices (${indices.length}):`);
        indices.forEach(index => {
          console.log(`  - ${index.name}`);
        });
      }
      
      db.close();
      console.log('\n=== Optimización completada ===');
      console.log(`Respaldo de la base de datos: ${BACKUP_PATH}`);
    });
    
  } catch (error) {
    console.error('Error durante la optimización:', error.message);
    if (error.stack) {
      console.error('Stack trace:', error.stack);
    }
    process.exit(1);
  }
}

// Ejecutar la optimización
optimizeServicesStructure();
