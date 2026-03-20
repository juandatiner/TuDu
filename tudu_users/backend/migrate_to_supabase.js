require('dotenv').config();
const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const { createClient } = require('@supabase/supabase-js');

// 1. Inicializar Supabase
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('❌ Faltan credenciales de Supabase en el archivo .env');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

// 2. Definir conexiones SQLite
const DB_PATH = path.join(__dirname, '../../databases');
const getDb = (name) => new sqlite3.Database(path.join(DB_PATH, name));

const dbConnections = {
  users: getDb('users.db'),
  allies: getDb('allies.db'),
  services: getDb('services.db'),
  search: getDb('search.db'),
  admins: getDb('admins.db'),
};

// Utilidad para extraer datos de SQLite a Promesa
const fetchAll = (db, query) => {
  return new Promise((resolve, reject) => {
    db.all(query, (err, rows) => {
      if (err) reject(err);
      else resolve(rows);
    });
  });
};

// Función para migrar una tabla en lotes
async function migrateTable(dbKey, tableName, supabaseTableName = tableName, transformFn = row => row) {
  const db = dbConnections[dbKey];
  console.log(`\n⏳ Empezando migración de '${tableName}' -> '${supabaseTableName}'...`);
  
  try {
    const rows = await fetchAll(db, `SELECT * FROM ${tableName}`);
    if (rows.length === 0) {
      console.log(`   └─ Tabla vacía, saltando.`);
      return;
    }

    console.log(`   ├─ Encontrados ${rows.length} registros en SQLite.`);
    
    const transformedRows = rows.map(transformFn);
    
    // Insertar en lotes dinámicos (muy pequeños para avatares base64 debido al timeout)
    const isHeavy = tableName === 'photo_change_requests' || tableName === 'users';
    const BATCH_SIZE = isHeavy ? 2 : 50;
    for (let i = 0; i < transformedRows.length; i += BATCH_SIZE) {
      const batch = transformedRows.slice(i, i + BATCH_SIZE);
      const { error } = await supabase.from(supabaseTableName).insert(batch);
      
      if (error) {
        console.error(`   ├─ ❌ Error al insertar lote en ${supabaseTableName}:`, error.message);
        // Mostrar muestra de lo que falló si es útil
        if (error.code === '23505') console.log('      └─ (Registro duplicado ignorado)');
      } else {
        process.stdout.write(`   ├─ Migrados ${Math.min(i + BATCH_SIZE, transformedRows.length)} / ${transformedRows.length} \r`);
      }
    }
    console.log(`   └─ ✅ Migración de '${supabaseTableName}' completada.`);
  } catch (err) {
    if (err.message.includes('no such table')) {
      console.log(`   └─ ⚠️ Tabla ${tableName} no existe en SQLite local. Saltando.`);
    } else {
      console.error(`   └─ ❌ Error crítico:`, err);
    }
  }
}

// 3. Flujo Principal de Migración
async function runMigration() {
  console.log('🚀 INICIANDO MIGRACIÓN A SUPABASE 🚀\n');

  // UBICACIONES
  await migrateTable('users', 'countries');
  await migrateTable('users', 'departments');
  await migrateTable('users', 'cities');

  // USUARIOS
  await migrateTable('users', 'users', 'users', (row) => {
    // Omite columnas obsoletas de SQLite para evitar errores en Supabase
    const { country_code, phone_number, ...rest } = row;
    return rest;
  });
  await migrateTable('users', 'user_phones');
  await migrateTable('users', 'photo_change_requests');

  // ALIADOS
  await migrateTable('allies', 'allies');

  // SERVICIOS
  await migrateTable('services', 'services');
  await migrateTable('services', 'services_in_search', 'services_in_search', (row) => {
    const { user_id, ally_id, ...rest } = row;
    return rest; // omitimos los IDs locales que son ints en lugar de emails
  });
  await migrateTable('services', 'ally_services');

  // BÚSQUEDAS
  await migrateTable('search', 'search_history', 'search_history', (row) => {
    const { search_query, ...rest } = row;
    return { ...rest, query: search_query }; // SQLite usa search_query, Supabase usa query
  });

  // ADMINS
  await migrateTable('admins', 'admins');

  console.log('\n🎉 MIGRACIÓN COMPLETA 🎉\n');

  // Cerrar dbs
  Object.values(dbConnections).forEach(db => db.close());
}

runMigration().catch(err => {
  console.error('\n💥 Error fatal en de la migración:', err);
  process.exit(1);
});
