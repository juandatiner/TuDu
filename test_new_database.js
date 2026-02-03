const sqlite3 = require('sqlite3').verbose();
const path = require('path');

// Ruta de la nueva base de datos
const DB_PATH = path.join(__dirname, 'databases', 'todo.db');

// Función para obtener información detallada de la base de datos
async function testDatabase() {
  return new Promise((resolve, reject) => {
    const db = new sqlite3.Database(DB_PATH);

    console.log('=== Prueba de la nueva base de datos ===');
    console.log(`Ruta: ${DB_PATH}`);
    console.log(`Estado: Conectada`);

    // Obtener versión de SQLite
    db.get("PRAGMA user_version", (err, row) => {
      if (err) {
        db.close();
        return reject(err);
      }

      console.log(`Versión SQLite: ${row.user_version}`);

      // Obtener todas las tablas
      db.all("SELECT name, type FROM sqlite_master WHERE type='table' OR type='view' ORDER BY type, name", (err, schema) => {
        if (err) {
          db.close();
          return reject(err);
        }

        console.log(`\n--- Estructura de la base de datos ---`);
        const tables = schema.filter(item => item.type === 'table' && item.name !== 'sqlite_sequence');
        const views = schema.filter(item => item.type === 'view');

        console.log(`Tablas (${tables.length}):`);
        tables.forEach(table => {
          console.log(`  - ${table.name}`);
        });

        if (views.length > 0) {
          console.log(`Vistas (${views.length}):`);
          views.forEach(view => {
            console.log(`  - ${view.name}`);
          });
        }

        // Verificar relaciones (foreign keys) y indices
        console.log(`\n--- Relaciones y Índices ---`);
        
        // Verificar que todas las llaves foráneas existan
        const tablesToCheck = ['services_in_search', 'ally_services', 'messages'];
        
        tablesToCheck.forEach(tableName => {
          // Obtener índices para cada tabla
          db.all(`PRAGMA index_list(${tableName})`, (err, indexes) => {
            if (err) {
              console.error(`Error al obtener índices para ${tableName}:`, err.message);
              return;
            }

            if (indexes.length > 0) {
              console.log(`\nTabla ${tableName}:`);
              indexes.forEach(index => {
                if (index.origin === 'c') { // c = CREATE INDEX
                  console.log(`  Índice: ${index.name} (${index.unique ? 'Único' : 'Normal'})`);
                }
              });

              // Obtener foreign keys para la tabla
              db.all(`PRAGMA foreign_key_list(${tableName})`, (err, foreignKeys) => {
                if (err) {
                  console.error(`Error al obtener foreign keys para ${tableName}:`, err.message);
                  return;
                }

                foreignKeys.forEach(fk => {
                  console.log(`  FK: ${fk.from} -> ${fk.table}.${fk.to} (${fk.on_delete || 'NO ACTION'}, ${fk.on_update || 'NO ACTION'})`);
                });
              });
            }
          });
        });

        // Verificar la integridad de los datos
        console.log(`\n--- Integridad de datos ---`);

        // Verificar que service_in_search tenga el campo user_id
        db.all(`PRAGMA table_info(services_in_search)`, (err, fields) => {
          if (err) {
            console.error('Error al obtener campos de services_in_search:', err.message);
          } else {
            const hasUserId = fields.some(field => field.name === 'user_id');
            const hasAllyId = fields.some(field => field.name === 'ally_id');
            console.log(`services_in_search tiene user_id: ${hasUserId}`);
            console.log(`services_in_search tiene ally_id: ${hasAllyId}`);
          }
        });

        // Obtener datos de muestra de cada tabla
        console.log(`\n--- Datos de muestra ---`);

        const sampleQueries = [
          { name: 'users', query: 'SELECT id, email, nombre, apellido, role, created_at FROM users LIMIT 3' },
          { name: 'allies', query: 'SELECT id, email, nombre, apellido, role, created_at FROM allies LIMIT 3' },
          { name: 'services', query: 'SELECT id, name, created_at FROM services LIMIT 3' },
          { name: 'services_in_search', query: 'SELECT id, user_id, title, status, created_at FROM services_in_search LIMIT 3' },
        ];

        let completedQueries = 0;
        const totalQueries = sampleQueries.length;

        sampleQueries.forEach(query => {
          db.all(query.query, (err, rows) => {
            if (err) {
              console.error(`Error al obtener datos de ${query.name}:`, err.message);
            } else {
              console.log(`\nTabla: ${query.name} (${rows.length} registros)`);
              rows.forEach(row => {
                console.log(`  ${JSON.stringify(row)}`);
              });
            }

            completedQueries++;
            if (completedQueries === totalQueries) {
              // Verificar la relación entre services_in_search y users
              db.all(
                `SELECT s.id, s.title, u.email 
                 FROM services_in_search s 
                 LEFT JOIN users u ON s.user_id = u.id 
                 WHERE u.id IS NULL AND s.user_id IS NOT NULL`,
                (err, rows) => {
                  if (err) {
                    console.error('Error al verificar relaciones:', err.message);
                  } else {
                    if (rows.length > 0) {
                      console.log(`\n❌ Alerta: ${rows.length} registros en services_in_search con user_id inválido`);
                    } else {
                      console.log(`\n✅ Relación services_in_search → users es válida`);
                    }
                  }

                  db.close();
                  console.log(`\n=== Prueba completada ===`);
                  resolve();
                }
              );
            }
          });
        });
      });
    });
  });
}

// Función para calcular el tamaño de la base de datos
function getDatabaseSize() {
  const fs = require('fs');
  try {
    const stats = fs.statSync(DB_PATH);
    console.log(`\nTamaño de la base de datos: ${(stats.size / 1024).toFixed(2)} KB`);
  } catch (err) {
    console.error('Error al obtener tamaño de la base de datos:', err.message);
  }
}

// Ejecutar pruebas
async function main() {
  try {
    getDatabaseSize();
    await testDatabase();
  } catch (error) {
    console.error('Error durante la prueba:', error.message);
    if (error.stack) {
      console.error('Stack trace:', error.stack);
    }
    process.exit(1);
  }
}

main();
