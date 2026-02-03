const sqlite3 = require('sqlite3').verbose();
const fs = require('fs');
const path = require('path');

// Directorio de bases de datos
const DB_DIR = path.join(__dirname, 'databases');

// Función para vaciar tablas de una base de datos excepto services
async function clearTablesExceptServices(dbPath, dbName) {
  return new Promise((resolve, reject) => {
    const db = new sqlite3.Database(dbPath);
    
    // Obtener todas las tablas de la base de datos
    db.all("SELECT name FROM sqlite_master WHERE type='table'", (err, tables) => {
      if (err) {
        db.close();
        return reject(err);
      }

      // Filtrar tablas para excluir: services, sqlite_sequence y sqlite_master
      const tablesToClear = tables.filter(table => {
        return table.name !== 'services' && 
               table.name !== 'sqlite_sequence' && 
               table.name !== 'sqlite_master';
      });

      if (tablesToClear.length === 0) {
        console.log(`[${dbName}] No hay tablas para vaciar (solo 'services' existe)`);
        db.close();
        return resolve();
      }

      console.log(`[${dbName}] Tablas a vaciar: ${tablesToClear.map(t => t.name).join(', ')}`);

      // Ejecutar DELETE en cada tabla
      let tablesProcessed = 0;
      const totalTables = tablesToClear.length;

      tablesToClear.forEach(table => {
        db.run(`DELETE FROM ${table.name}`, (err) => {
          if (err) {
            db.close();
            return reject(err);
          }

          tablesProcessed++;

          console.log(`[${dbName}] Tabla '${table.name}' vaciada exitosamente`);

          if (tablesProcessed === totalTables) {
            // Reiniciar secuencia de autoincremento para las tablas vaciadas
            db.run("UPDATE sqlite_sequence SET seq = 0 WHERE name IN (?)", 
              [tablesToClear.map(t => t.name)], (err) => {
                if (err) {
                  db.close();
                  return reject(err);
                }
                db.close();
                console.log(`[${dbName}] Reiniciado de secuencias completado`);
                resolve();
              });
          }
        });
      });
    });
  });
}

// Función principal
async function main() {
  try {
    // Obtener archivos de base de datos
    const dbFiles = fs.readdirSync(DB_DIR).filter(file => file.endsWith('.db'));

    console.log(`=== Iniciando proceso de vaciado de tablas ===`);
    console.log(`Encontradas ${dbFiles.length} bases de datos en ${DB_DIR}`);
    console.log('');

    for (const dbFile of dbFiles) {
      const dbPath = path.join(DB_DIR, dbFile);
      
      console.log(`=== Procesando: ${dbFile} ===`);
      
      await clearTablesExceptServices(dbPath, dbFile);
      
      console.log('');
    }

    console.log(`=== Proceso completado exitosamente ===`);

  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

// Ejecutar script
main();