const http = require('http');

// Función para hacer peticiones HTTP simplificada
function httpRequest(options, data = null) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try {
          const parsedBody = JSON.parse(body);
          resolve({ statusCode: res.statusCode, data: parsedBody });
        } catch (error) {
          resolve({ statusCode: res.statusCode, data: body });
        }
      });
    });
    
    req.on('error', reject);
    
    if (data) {
      req.write(JSON.stringify(data));
    }
    req.end();
  });
}

// Pruebas para Users Backend (puerto 3000)
async function testUsersBackend() {
  console.log('🧪 Testing Users Backend (http://localhost:3000)...');
  
  try {
    // Prueba 1: Enviar OTP
    console.log('\n1. Enviar OTP');
    const sendOtpOptions = {
      hostname: 'localhost',
      port: 3000,
      path: '/send-otp',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      }
    };
    const sendOtpResponse = await httpRequest(sendOtpOptions, { email: 'test@example.com' });
    console.log(`✅ Status: ${sendOtpResponse.statusCode}`);
    console.log(`   Respuesta: ${JSON.stringify(sendOtpResponse.data)}`);
    
    // Prueba 2: Verificar OTP
    console.log('\n2. Verificar OTP');
    const verifyOtpOptions = {
      hostname: 'localhost',
      port: 3000,
      path: '/verify-otp',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      }
    };
    const verifyOtpResponse = await httpRequest(verifyOtpOptions, { 
      email: 'test@example.com', 
      otp: '123456' 
    });
    console.log(`✅ Status: ${verifyOtpResponse.statusCode}`);
    console.log(`   Respuesta: ${JSON.stringify(verifyOtpResponse.data)}`);
    
    // Prueba 3: Obtener servicios
    console.log('\n3. Obtener servicios');
    const servicesOptions = {
      hostname: 'localhost',
      port: 3000,
      path: '/services',
      method: 'GET'
    };
    const servicesResponse = await httpRequest(servicesOptions);
    console.log(`✅ Status: ${servicesResponse.statusCode}`);
    console.log(`   Respuesta: ${JSON.stringify(servicesResponse.data)}`);
    
    // Prueba 4: Obtener perfil de usuario
    console.log('\n4. Obtener perfil de usuario');
    const profileOptions = {
      hostname: 'localhost',
      port: 3000,
      path: '/user/profile?email=test@example.com',
      method: 'GET'
    };
    const profileResponse = await httpRequest(profileOptions);
    console.log(`✅ Status: ${profileResponse.statusCode}`);
    console.log(`   Respuesta: ${JSON.stringify(profileResponse.data)}`);
    
    console.log('\n✅ Users Backend: Todas las pruebas pasaron');
    return true;
    
  } catch (error) {
    console.error('\n❌ Error en Users Backend:', error.message);
    return false;
  }
}

// Pruebas para Allies Backend (puerto 3002)
async function testAlliesBackend() {
  console.log('🧪 Testing Allies Backend (http://localhost:3002)...');
  
  try {
    // Prueba 1: Enviar OTP
    console.log('\n1. Enviar OTP');
    const sendOtpOptions = {
      hostname: 'localhost',
      port: 3002,
      path: '/send-otp',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      }
    };
    const sendOtpResponse = await httpRequest(sendOtpOptions, { email: 'ally@example.com' });
    console.log(`✅ Status: ${sendOtpResponse.statusCode}`);
    console.log(`   Respuesta: ${JSON.stringify(sendOtpResponse.data)}`);
    
    // Prueba 2: Verificar OTP
    console.log('\n2. Verificar OTP');
    const verifyOtpOptions = {
      hostname: 'localhost',
      port: 3002,
      path: '/verify-otp',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      }
    };
    const verifyOtpResponse = await httpRequest(verifyOtpOptions, { 
      email: 'ally@example.com', 
      otp: '123456' 
    });
    console.log(`✅ Status: ${verifyOtpResponse.statusCode}`);
    console.log(`   Respuesta: ${JSON.stringify(verifyOtpResponse.data)}`);
    
    // Prueba 3: Obtener servicios del aliado
    console.log('\n3. Obtener servicios del aliado');
    const servicesOptions = {
      hostname: 'localhost',
      port: 3002,
      path: '/services?email=ally@example.com',
      method: 'GET'
    };
    const servicesResponse = await httpRequest(servicesOptions);
    console.log(`✅ Status: ${servicesResponse.statusCode}`);
    console.log(`   Respuesta: ${JSON.stringify(servicesResponse.data)}`);
    
    console.log('\n✅ Allies Backend: Todas las pruebas pasaron');
    return true;
    
  } catch (error) {
    console.error('\n❌ Error en Allies Backend:', error.message);
    return false;
  }
}

// Verificar base de datos unificada
async function checkDatabase() {
  console.log('📊 Verificando base de datos unificada...');
  try {
    const sqlite3 = require('sqlite3').verbose();
    const path = require('path');
    const dbPath = path.join(__dirname, 'databases', 'todo.db');
    
    return new Promise((resolve, reject) => {
      const db = new sqlite3.Database(dbPath, (err) => {
        if (err) {
          return reject(err);
        }
        
        // Verificar tablas
        db.all("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'", (err, tables) => {
          if (err) {
            db.close();
            return reject(err);
          }
          
          console.log(`✅ Base de datos conectada`);
          console.log(`✅ Tablas encontradas: ${tables.length}`);
          tables.forEach(table => console.log(`   - ${table.name}`));
          
          // Verificar datos de prueba
          db.all("SELECT COUNT(*) as count FROM users", (err, result) => {
            if (err) {
              db.close();
              return reject(err);
            }
            console.log(`✅ Usuarios: ${result[0].count}`);
            
            db.all("SELECT COUNT(*) as count FROM allies", (err, result) => {
              if (err) {
                db.close();
                return reject(err);
              }
              console.log(`✅ Aliados: ${result[0].count}`);
              
              db.all("SELECT COUNT(*) as count FROM services_in_search", (err, result) => {
                if (err) {
                  db.close();
                  return reject(err);
                }
                console.log(`✅ Servicios en búsqueda: ${result[0].count}`);
                db.close();
                resolve(true);
              });
            });
          });
        });
      });
    });
    
  } catch (error) {
    console.error('\n❌ Error en base de datos:', error.message);
    return false;
  }
}

// Ejecutar todas las pruebas
async function runAllTests() {
  console.log('🚀 Iniciando pruebas...');
  console.log('=' . repeat(50));
  
  const dbOk = await checkDatabase();
  console.log('=' . repeat(50));
  
  if (dbOk) {
    const usersOk = await testUsersBackend();
    console.log('=' . repeat(50));
    
    const alliesOk = await testAlliesBackend();
    console.log('=' . repeat(50));
    
    if (usersOk && alliesOk) {
      console.log('🎉 TODO: Backends y base de datos funcionando correctamente!');
    } else {
      console.log('⚠️  ALERTA: Algunos endpoints no respondieron');
    }
  } else {
    console.log('❌ Error en la base de datos');
  }
}

runAllTests().catch(err => {
  console.error('❌ Error general:', err);
});
