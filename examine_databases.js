const sqlite3 = require('sqlite3').verbose();
const fs = require('fs');
const path = require('path');

// Directorio de bases de datos
const DB_DIR = path.join(__dirname, 'databases');

// Función para obtener el esquema de una base de datos
async function getDatabaseSchema(dbPath) {
  return new Promise((resolve, reject) => {
    const db = new sqlite3.Database(dbPath);
    const schema = {
      tables: {},
      indices: [],
      views: []
    };

    // Obtener todas las tablas
    db.all("SELECT name FROM sqlite_master WHERE type='table'", (err, tables) => {
      if (err) {
        db.close();
        return reject(err);
      }

      let tablesProcessed = 0;
      const totalTables = tables.length;

      tables.forEach(table => {
        // Obtener columnas de la tabla
        db.all(`PRAGMA table_info(${table.name})`, (err, columns) => {
          if (err) {
            db.close();
            return reject(err);
          }

          // Obtener índices de la tabla
          db.all(`PRAGMA index_list(${table.name})`, (err, indices) => {
            if (err) {
              db.close();
              return reject(err);
            }

            schema.tables[table.name] = {
              columns,
              indices: indices.filter(idx => idx.origin === 'c') // c = CREATE INDEX
            };

            tablesProcessed++;

            if (tablesProcessed === totalTables) {
              // Obtener todas las vistas
              db.all("SELECT name FROM sqlite_master WHERE type='view'", (err, views) => {
                if (err) {
                  db.close();
                  return reject(err);
                }
                schema.views = views.map(view => view.name);
                db.close();
                resolve(schema);
              });
            }
          });
        });
      });
    });
  });
}

// Función para obtener datos de muestra de una tabla
async function getTableSampleData(dbPath, tableName, limit = 5) {
  return new Promise((resolve, reject) => {
    const db = new sqlite3.Database(dbPath);

    db.all(`SELECT * FROM ${tableName} LIMIT ${limit}`, (err, rows) => {
      db.close();
      if (err) {
        reject(err);
      } else {
        resolve(rows);
      }
    });
  });
}

// Función para imprimir el esquema de una base de datos
function printDatabaseSchema(dbName, schema) {
  console.log(`\n=== Estructura de la base de datos: ${dbName} ===`);
  console.log(`\n--- Tablas (${Object.keys(schema.tables).length}) ---`);

  Object.keys(schema.tables).forEach(tableName => {
    const table = schema.tables[tableName];
    console.log(`\nTabla: ${tableName}`);
    console.log(`  Columnas (${table.columns.length}):`);
    table.columns.forEach(col => {
      console.log(`    ${col.name} (${col.type}) ${col.notnull ? 'NOT NULL' : ''}${col.pk ? ' PRIMARY KEY' : ''} ${col.dflt_value ? `DEFAULT ${col.dflt_value}` : ''}`);
    });

    if (table.indices.length > 0) {
      console.log(`  Índices (${table.indices.length}):`);
      table.indices.forEach(idx => {
        console.log(`    ${idx.name} ${idx.unique ? '(Único)' : ''}`);
      });
    }
  });

  if (schema.views.length > 0) {
    console.log(`\n--- Vistas (${schema.views.length}) ---`);
    schema.views.forEach(view => console.log(`  ${view}`));
  }
}

// Función principal
async function main() {
  try {
    // Obtener archivos de base de datos
    const dbFiles = fs.readdirSync(DB_DIR).filter(file => file.endsWith('.db'));

    console.log(`Found ${dbFiles.length} databases in ${DB_DIR}`);

    for (const dbFile of dbFiles) {
      const dbPath = path.join(DB_DIR, dbFile);
      
      console.log(`\nProcessing: ${dbFile}`);
      console.log(`Path: ${dbPath}`);

      const stats = fs.statSync(dbPath);
      console.log(`Size: ${(stats.size / 1024).toFixed(2)} KB`);

      const schema = await getDatabaseSchema(dbPath);
      printDatabaseSchema(dbFile, schema);

      // Obtener datos de muestra para cada tabla
      console.log(`\n--- Datos de muestra ---`);
      for (const tableName of Object.keys(schema.tables)) {
        if (tableName !== 'sqlite_sequence' && tableName !== 'sqlite_master') {
          try {
            const sampleData = await getTableSampleData(dbPath, tableName);
            console.log(`\nTabla: ${tableName}`);
            if (sampleData.length === 0) {
              console.log('  Sin datos');
            } else {
              console.log('  Primeros 5 registros:');
              sampleData.forEach((row, idx) => {
                console.log(`    ${idx + 1}:`, JSON.stringify(row, null, 2));
              });
            }
          } catch (err) {
            console.error(`Error al obtener datos de ${tableName}:`, err.message);
          }
        }
      }

      console.log(`\n${'='.repeat(80)}`);
    }

  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

// Ejecutar script
main();
