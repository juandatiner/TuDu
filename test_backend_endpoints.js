const axios = require('axios');

// Configuración de los backends
const USERS_API_BASE = 'http://localhost:3000';
const ALLIES_API_BASE = 'http://localhost:3002';

// Función para testear endpoints de users backend
async function testUsersBackend() {
  console.log('🧪 Testing Users Backend (port 3000)...');
  
  try {
    // Test 1: Enviar OTP
    console.log('\n1. Prueba: Enviar OTP');
    const sendOtpResponse = await axios.post(`${USERS_API_BASE}/send-otp`, {
      email: 'test@example.com'
    });
    console.log('✅ Success:', sendOtpResponse.data.message);
    
    // Test 2: Verificar OTP
    console.log('\n2. Prueba: Verificar OTP');
    const verifyOtpResponse = await axios.post(`${USERS_API_BASE}/verify-otp`, {
      email: 'test@example.com',
      otp: '123456'
    });
    console.log('✅ Success:', verifyOtpResponse.data.message);
    
    // Test 3: Obtener servicios
    console.log('\n3. Prueba: Obtener servicios');
    const servicesResponse = await axios.get(`${USERS_API_BASE}/services`);
    console.log('✅ Success: Total servicios:', servicesResponse.data.length);
    
    // Test 4: Obtener perfil de usuario
    console.log('\n4. Prueba: Obtener perfil de usuario');
    const profileResponse = await axios.get(`${USERS_API_BASE}/user/profile`, {
      params: { email: 'test@example.com' }
    });
    console.log('✅ Success: Perfil encontrado');
    
    // Test 5: Obtener servicios de usuario
    console.log('\n5. Prueba: Obtener servicios de usuario');
    const userServicesResponse = await axios.get(`${USERS_API_BASE}/user/services`, {
      params: { email: 'test@example.com' }
    });
    console.log('✅ Success: Total servicios de usuario:', userServicesResponse.data.length);
    
    console.log('\n✅ Users Backend: Todos los endpoints testados correctamente!');
    return true;
    
  } catch (error) {
    console.error('\n❌ Error en Users Backend:', error.response?.data?.error || error.message);
    return false;
  }
}

// Función para testear endpoints de allies backend
async function testAlliesBackend() {
  console.log('🧪 Testing Allies Backend (port 3002)...');
  
  try {
    // Test 1: Enviar OTP
    console.log('\n1. Prueba: Enviar OTP');
    const sendOtpResponse = await axios.post(`${ALLIES_API_BASE}/send-otp`, {
      email: 'ally@example.com'
    });
    console.log('✅ Success:', sendOtpResponse.data.message);
    
    // Test 2: Verificar OTP
    console.log('\n2. Prueba: Verificar OTP');
    const verifyOtpResponse = await axios.post(`${ALLIES_API_BASE}/verify-otp`, {
      email: 'ally@example.com',
      otp: '123456'
    });
    console.log('✅ Success:', verifyOtpResponse.data.message);
    
    // Test 3: Obtener servicios del aliado
    console.log('\n3. Prueba: Obtener servicios del aliado');
    const servicesResponse = await axios.get(`${ALLIES_API_BASE}/services`, {
      params: { email: 'ally@example.com' }
    });
    console.log('✅ Success: Total servicios del aliado:', servicesResponse.data.length);
    
    // Test 4: Obtener perfil de aliado
    console.log('\n4. Prueba: Obtener perfil de aliado');
    const profileResponse = await axios.get(`${ALLIES_API_BASE}/allies/profile`, {
      params: { email: 'ally@example.com' }
    });
    console.log('✅ Success: Perfil encontrado');
    
    console.log('\n✅ Allies Backend: Todos los endpoints testados correctamente!');
    return true;
    
  } catch (error) {
    console.error('\n❌ Error en Allies Backend:', error.response?.data?.error || error.message);
    return false;
  }
}

// Función principal de testing
async function runAllTests() {
  console.log('🚀 Iniciando pruebas de los backends...');
  console.log('=' . repeat(50));
  
  const usersOk = await testUsersBackend();
  console.log('=' . repeat(50));
  
  const alliesOk = await testAlliesBackend();
  console.log('=' . repeat(50));
  
  if (usersOk && alliesOk) {
    console.log('🎉 TODO: Todos los backends están funcionando correctamente!');
  } else {
    console.log('⚠️  ALERTA: Algunos endpoints no están funcionando correctamente');
  }
}

// Ejecutar pruebas
runAllTests().catch(err => {
  console.error('❌ Error general:', err.message);
});
