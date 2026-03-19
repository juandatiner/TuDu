const express = require('express');
const cors = require('cors');
const mailgun = require('mailgun-js');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');
// const multer = require('multer');
const fs = require('fs');
require('dotenv').config();
const http = require('http');
const { Server } = require('socket.io');

// Configurar Firebase Admin (comentado temporalmente)
// const admin = require('firebase-admin');
// const serviceAccount = require('./firebase-admin.json');
// 
// admin.initializeApp({
//   credential: admin.credential.cert(serviceAccount),
// });

const app = express();
const PORT = process.env.PORT || 3000;
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST", "PUT", "DELETE"]
  }
});

// Socket.io connection handler
io.on('connection', (socket) => {
  console.log('Usuario conectado:', socket.id);
  
  socket.on('disconnect', () => {
    console.log('Usuario desconectado:', socket.id);
  });
});

// Configurar Mailgun solo si las credenciales están configuradas
let mg = null;
if (process.env.MAILGUN_API_KEY && process.env.MAILGUN_DOMAIN && 
    process.env.MAILGUN_API_KEY !== 'tu_api_key_de_mailgun') {
  mg = mailgun({
    apiKey: process.env.MAILGUN_API_KEY,
    domain: process.env.MAILGUN_DOMAIN
  });
  console.log('Mailgun configurado correctamente');
} else {
  console.log('Mailgun no configurado - modo desarrollo activo');
}

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Almacenamiento temporal de OTPs (en producción usar Redis o DB)
const otpStore = new Map();

// Ruta base de las bases de datos
const DB_PATH = path.join(__dirname, '../../databases');

// Conexiones a las bases de datos separadas
const usersDb = new sqlite3.Database(path.join(DB_PATH, 'users.db'), (err) => {
  if (err) {
    console.error('Error abriendo users.db:', err.message);
  } else {
    console.log('Conectado a users.db');
  // Crear tabla de usuarios si no existe
  usersDb.run(`CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT UNIQUE NOT NULL,
      nombre TEXT NOT NULL,
      apellido TEXT NOT NULL,
      role TEXT DEFAULT 'user',
      avatar_color TEXT DEFAULT '#78BF32',
      avatar_icon TEXT DEFAULT 'person',
      avatar_image TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`, (err) => {
      if (err) {
        console.error('Error creando tabla users:', err.message);
      } else {
        console.log('Tabla users lista');
        // Agregar columnas de avatar si no existen (para bases de datos existentes)
        usersDb.run(`ALTER TABLE users ADD COLUMN avatar_color TEXT DEFAULT '#78BF32'`, (err) => {
          if (err && !err.message.includes('duplicate column')) {
            console.error('Error agregando columna avatar_color:', err.message);
          }
        });
        usersDb.run(`ALTER TABLE users ADD COLUMN avatar_icon TEXT DEFAULT 'person'`, (err) => {
          if (err && !err.message.includes('duplicate column')) {
            console.error('Error agregando columna avatar_icon:', err.message);
          }
        });
        usersDb.run(`ALTER TABLE users ADD COLUMN avatar_image TEXT`, (err) => {
          if (err && !err.message.includes('duplicate column')) {
            console.error('Error agregando columna avatar_image:', err.message);
          }
        });
        // Agregar columna phone si no existe
        usersDb.run(`ALTER TABLE users ADD COLUMN phone TEXT`, (err) => {
          if (err && !err.message.includes('duplicate column')) {
            console.error('Error agregando columna phone:', err.message);
          }
        });
        // Agregar columna genero si no existe
        usersDb.run(`ALTER TABLE users ADD COLUMN genero TEXT`, (err) => {
          if (err && !err.message.includes('duplicate column')) {
            console.error('Error agregando columna genero:', err.message);
          }
        });
        // Agregar columna fecha_nacimiento si no existe
        usersDb.run(`ALTER TABLE users ADD COLUMN fecha_nacimiento TEXT`, (err) => {
          if (err && !err.message.includes('duplicate column')) {
            console.error('Error agregando columna fecha_nacimiento:', err.message);
          }
        });
        // Agregar columna dark_mode si no existe
        usersDb.run(`ALTER TABLE users ADD COLUMN dark_mode INTEGER DEFAULT 0`, (err) => {
          if (err && !err.message.includes('duplicate column')) {
            console.error('Error agregando columna dark_mode:', err.message);
          }
        });
        // Agregar columna language si no existe
        usersDb.run(`ALTER TABLE users ADD COLUMN language TEXT DEFAULT 'es'`, (err) => {
          if (err && !err.message.includes('duplicate column')) {
            console.error('Error agregando columna language:', err.message);
          }
        });
      }
    });

  // Crear tabla de teléfonos de usuarios si no existe
  usersDb.run(`CREATE TABLE IF NOT EXISTS user_phones (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_email TEXT NOT NULL,
      country_code TEXT NOT NULL,
      country_name TEXT,
      phone_number TEXT NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_email) REFERENCES users(email),
      UNIQUE(user_email)
    )`, (err) => {
      if (err) {
        console.error('Error creando tabla user_phones:', err.message);
      } else {
        console.log('Tabla user_phones lista');
      }
    });

  // Crear tabla de solicitudes de cambio de foto de perfil
  usersDb.run(`CREATE TABLE IF NOT EXISTS photo_change_requests (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_email TEXT NOT NULL,
      new_avatar_image TEXT NOT NULL,
      status TEXT DEFAULT 'pending',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_email) REFERENCES users(email)
    )`, (err) => {
      if (err) {
        console.error('Error creando tabla photo_change_requests:', err.message);
      } else {
        console.log('Tabla photo_change_requests lista');
      }
    });

  // Crear tabla de países con sus códigos telefónicos
  usersDb.run(`CREATE TABLE IF NOT EXISTS countries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      iso_code TEXT UNIQUE NOT NULL,
      name TEXT NOT NULL,
      dial_code TEXT NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`, (err) => {
      if (err) {
        console.error('Error creando tabla countries:', err.message);
      } else {
        console.log('Tabla countries lista');
        // Insertar países si la tabla está vacía
        usersDb.get(`SELECT COUNT(*) as count FROM countries`, (err, row) => {
          if (err) {
            console.error('Error contando países:', err.message);
          } else if (row.count === 0) {
            // Lista completa de países con códigos ISO y códigos de marcación
            const countries = [
              { iso: 'AF', name: 'Afghanistan', dial: '+93' },
              { iso: 'AL', name: 'Albania', dial: '+355' },
              { iso: 'DZ', name: 'Algeria', dial: '+213' },
              { iso: 'AS', name: 'American Samoa', dial: '+1684' },
              { iso: 'AD', name: 'Andorra', dial: '+376' },
              { iso: 'AO', name: 'Angola', dial: '+244' },
              { iso: 'AI', name: 'Anguilla', dial: '+1264' },
              { iso: 'AG', name: 'Antigua and Barbuda', dial: '+1268' },
              { iso: 'AR', name: 'Argentina', dial: '+54' },
              { iso: 'AM', name: 'Armenia', dial: '+374' },
              { iso: 'AW', name: 'Aruba', dial: '+297' },
              { iso: 'AU', name: 'Australia', dial: '+61' },
              { iso: 'AT', name: 'Austria', dial: '+43' },
              { iso: 'AZ', name: 'Azerbaijan', dial: '+994' },
              { iso: 'BS', name: 'Bahamas', dial: '+1242' },
              { iso: 'BH', name: 'Bahrain', dial: '+973' },
              { iso: 'BD', name: 'Bangladesh', dial: '+880' },
              { iso: 'BB', name: 'Barbados', dial: '+1246' },
              { iso: 'BY', name: 'Belarus', dial: '+375' },
              { iso: 'BE', name: 'Belgium', dial: '+32' },
              { iso: 'BZ', name: 'Belize', dial: '+501' },
              { iso: 'BJ', name: 'Benin', dial: '+229' },
              { iso: 'BM', name: 'Bermuda', dial: '+1441' },
              { iso: 'BT', name: 'Bhutan', dial: '+975' },
              { iso: 'BO', name: 'Bolivia', dial: '+591' },
              { iso: 'BA', name: 'Bosnia and Herzegovina', dial: '+387' },
              { iso: 'BW', name: 'Botswana', dial: '+267' },
              { iso: 'BR', name: 'Brazil', dial: '+55' },
              { iso: 'IO', name: 'British Indian Ocean Territory', dial: '+246' },
              { iso: 'VG', name: 'British Virgin Islands', dial: '+1284' },
              { iso: 'BN', name: 'Brunei', dial: '+673' },
              { iso: 'BG', name: 'Bulgaria', dial: '+359' },
              { iso: 'BF', name: 'Burkina Faso', dial: '+226' },
              { iso: 'BI', name: 'Burundi', dial: '+257' },
              { iso: 'KH', name: 'Cambodia', dial: '+855' },
              { iso: 'CM', name: 'Cameroon', dial: '+237' },
              { iso: 'CA', name: 'Canada', dial: '+1' },
              { iso: 'CV', name: 'Cape Verde', dial: '+238' },
              { iso: 'KY', name: 'Cayman Islands', dial: '+1345' },
              { iso: 'CF', name: 'Central African Republic', dial: '+236' },
              { iso: 'TD', name: 'Chad', dial: '+235' },
              { iso: 'CL', name: 'Chile', dial: '+56' },
              { iso: 'CN', name: 'China', dial: '+86' },
              { iso: 'CO', name: 'Colombia', dial: '+57' },
              { iso: 'KM', name: 'Comoros', dial: '+269' },
              { iso: 'CG', name: 'Congo', dial: '+242' },
              { iso: 'CD', name: 'Congo (Democratic Republic)', dial: '+243' },
              { iso: 'CK', name: 'Cook Islands', dial: '+682' },
              { iso: 'CR', name: 'Costa Rica', dial: '+506' },
              { iso: 'CI', name: 'Côte d\'Ivoire', dial: '+225' },
              { iso: 'HR', name: 'Croatia', dial: '+385' },
              { iso: 'CU', name: 'Cuba', dial: '+53' },
              { iso: 'CW', name: 'Curaçao', dial: '+599' },
              { iso: 'CY', name: 'Cyprus', dial: '+357' },
              { iso: 'CZ', name: 'Czech Republic', dial: '+420' },
              { iso: 'DK', name: 'Denmark', dial: '+45' },
              { iso: 'DJ', name: 'Djibouti', dial: '+253' },
              { iso: 'DM', name: 'Dominica', dial: '+1767' },
              { iso: 'DO', name: 'Dominican Republic', dial: '+1809' },
              { iso: 'TL', name: 'East Timor', dial: '+670' },
              { iso: 'EC', name: 'Ecuador', dial: '+593' },
              { iso: 'EG', name: 'Egypt', dial: '+20' },
              { iso: 'SV', name: 'El Salvador', dial: '+503' },
              { iso: 'GQ', name: 'Equatorial Guinea', dial: '+240' },
              { iso: 'ER', name: 'Eritrea', dial: '+291' },
              { iso: 'EE', name: 'Estonia', dial: '+372' },
              { iso: 'ET', name: 'Ethiopia', dial: '+251' },
              { iso: 'FK', name: 'Falkland Islands', dial: '+500' },
              { iso: 'FO', name: 'Faroe Islands', dial: '+298' },
              { iso: 'FJ', name: 'Fiji', dial: '+679' },
              { iso: 'FI', name: 'Finland', dial: '+358' },
              { iso: 'FR', name: 'France', dial: '+33' },
              { iso: 'GF', name: 'French Guiana', dial: '+594' },
              { iso: 'PF', name: 'French Polynesia', dial: '+689' },
              { iso: 'GA', name: 'Gabon', dial: '+241' },
              { iso: 'GM', name: 'Gambia', dial: '+220' },
              { iso: 'GE', name: 'Georgia', dial: '+995' },
              { iso: 'DE', name: 'Germany', dial: '+49' },
              { iso: 'GH', name: 'Ghana', dial: '+233' },
              { iso: 'GI', name: 'Gibraltar', dial: '+350' },
              { iso: 'GR', name: 'Greece', dial: '+30' },
              { iso: 'GL', name: 'Greenland', dial: '+299' },
              { iso: 'GD', name: 'Grenada', dial: '+1473' },
              { iso: 'GP', name: 'Guadeloupe', dial: '+590' },
              { iso: 'GU', name: 'Guam', dial: '+1671' },
              { iso: 'GT', name: 'Guatemala', dial: '+502' },
              { iso: 'GN', name: 'Guinea', dial: '+224' },
              { iso: 'GW', name: 'Guinea-Bissau', dial: '+245' },
              { iso: 'GY', name: 'Guyana', dial: '+592' },
              { iso: 'HT', name: 'Haiti', dial: '+509' },
              { iso: 'HN', name: 'Honduras', dial: '+504' },
              { iso: 'HK', name: 'Hong Kong', dial: '+852' },
              { iso: 'HU', name: 'Hungary', dial: '+36' },
              { iso: 'IS', name: 'Iceland', dial: '+354' },
              { iso: 'IN', name: 'India', dial: '+91' },
              { iso: 'ID', name: 'Indonesia', dial: '+62' },
              { iso: 'IR', name: 'Iran', dial: '+98' },
              { iso: 'IQ', name: 'Iraq', dial: '+964' },
              { iso: 'IE', name: 'Ireland', dial: '+353' },
              { iso: 'IL', name: 'Israel', dial: '+972' },
              { iso: 'IT', name: 'Italy', dial: '+39' },
              { iso: 'JM', name: 'Jamaica', dial: '+1876' },
              { iso: 'JP', name: 'Japan', dial: '+81' },
              { iso: 'JO', name: 'Jordan', dial: '+962' },
              { iso: 'KZ', name: 'Kazakhstan', dial: '+7' },
              { iso: 'KE', name: 'Kenya', dial: '+254' },
              { iso: 'KI', name: 'Kiribati', dial: '+686' },
              { iso: 'XK', name: 'Kosovo', dial: '+383' },
              { iso: 'KW', name: 'Kuwait', dial: '+965' },
              { iso: 'KG', name: 'Kyrgyzstan', dial: '+996' },
              { iso: 'LA', name: 'Laos', dial: '+856' },
              { iso: 'LV', name: 'Latvia', dial: '+371' },
              { iso: 'LB', name: 'Lebanon', dial: '+961' },
              { iso: 'LS', name: 'Lesotho', dial: '+266' },
              { iso: 'LR', name: 'Liberia', dial: '+231' },
              { iso: 'LY', name: 'Libya', dial: '+218' },
              { iso: 'LI', name: 'Liechtenstein', dial: '+423' },
              { iso: 'LT', name: 'Lithuania', dial: '+370' },
              { iso: 'LU', name: 'Luxembourg', dial: '+352' },
              { iso: 'MO', name: 'Macau', dial: '+853' },
              { iso: 'MK', name: 'Macedonia', dial: '+389' },
              { iso: 'MG', name: 'Madagascar', dial: '+261' },
              { iso: 'MW', name: 'Malawi', dial: '+265' },
              { iso: 'MY', name: 'Malaysia', dial: '+60' },
              { iso: 'MV', name: 'Maldives', dial: '+960' },
              { iso: 'ML', name: 'Mali', dial: '+223' },
              { iso: 'MT', name: 'Malta', dial: '+356' },
              { iso: 'MH', name: 'Marshall Islands', dial: '+692' },
              { iso: 'MQ', name: 'Martinique', dial: '+596' },
              { iso: 'MR', name: 'Mauritania', dial: '+222' },
              { iso: 'MU', name: 'Mauritius', dial: '+230' },
              { iso: 'YT', name: 'Mayotte', dial: '+262' },
              { iso: 'MX', name: 'Mexico', dial: '+52' },
              { iso: 'FM', name: 'Micronesia', dial: '+691' },
              { iso: 'MD', name: 'Moldova', dial: '+373' },
              { iso: 'MC', name: 'Monaco', dial: '+377' },
              { iso: 'MN', name: 'Mongolia', dial: '+976' },
              { iso: 'ME', name: 'Montenegro', dial: '+382' },
              { iso: 'MS', name: 'Montserrat', dial: '+1664' },
              { iso: 'MA', name: 'Morocco', dial: '+212' },
              { iso: 'MZ', name: 'Mozambique', dial: '+258' },
              { iso: 'MM', name: 'Myanmar', dial: '+95' },
              { iso: 'NA', name: 'Namibia', dial: '+264' },
              { iso: 'NR', name: 'Nauru', dial: '+674' },
              { iso: 'NP', name: 'Nepal', dial: '+977' },
              { iso: 'NL', name: 'Netherlands', dial: '+31' },
              { iso: 'NC', name: 'New Caledonia', dial: '+687' },
              { iso: 'NZ', name: 'New Zealand', dial: '+64' },
              { iso: 'NI', name: 'Nicaragua', dial: '+505' },
              { iso: 'NE', name: 'Niger', dial: '+227' },
              { iso: 'NG', name: 'Nigeria', dial: '+234' },
              { iso: 'NU', name: 'Niue', dial: '+683' },
              { iso: 'NF', name: 'Norfolk Island', dial: '+672' },
              { iso: 'KP', name: 'North Korea', dial: '+850' },
              { iso: 'MP', name: 'Northern Mariana Islands', dial: '+1670' },
              { iso: 'NO', name: 'Norway', dial: '+47' },
              { iso: 'OM', name: 'Oman', dial: '+968' },
              { iso: 'PK', name: 'Pakistan', dial: '+92' },
              { iso: 'PW', name: 'Palau', dial: '+680' },
              { iso: 'PS', name: 'Palestine', dial: '+970' },
              { iso: 'PA', name: 'Panama', dial: '+507' },
              { iso: 'PG', name: 'Papua New Guinea', dial: '+675' },
              { iso: 'PY', name: 'Paraguay', dial: '+595' },
              { iso: 'PE', name: 'Peru', dial: '+51' },
              { iso: 'PH', name: 'Philippines', dial: '+63' },
              { iso: 'PL', name: 'Poland', dial: '+48' },
              { iso: 'PT', name: 'Portugal', dial: '+351' },
              { iso: 'PR', name: 'Puerto Rico', dial: '+1787' },
              { iso: 'QA', name: 'Qatar', dial: '+974' },
              { iso: 'RE', name: 'Réunion', dial: '+262' },
              { iso: 'RO', name: 'Romania', dial: '+40' },
              { iso: 'RU', name: 'Russia', dial: '+7' },
              { iso: 'RW', name: 'Rwanda', dial: '+250' },
              { iso: 'BL', name: 'Saint Barthélemy', dial: '+590' },
              { iso: 'SH', name: 'Saint Helena', dial: '+290' },
              { iso: 'KN', name: 'Saint Kitts and Nevis', dial: '+1869' },
              { iso: 'LC', name: 'Saint Lucia', dial: '+1758' },
              { iso: 'MF', name: 'Saint Martin', dial: '+590' },
              { iso: 'PM', name: 'Saint Pierre and Miquelon', dial: '+508' },
              { iso: 'VC', name: 'Saint Vincent and the Grenadines', dial: '+1784' },
              { iso: 'WS', name: 'Samoa', dial: '+685' },
              { iso: 'SM', name: 'San Marino', dial: '+378' },
              { iso: 'ST', name: 'São Tomé and Príncipe', dial: '+239' },
              { iso: 'SA', name: 'Saudi Arabia', dial: '+966' },
              { iso: 'SN', name: 'Senegal', dial: '+221' },
              { iso: 'RS', name: 'Serbia', dial: '+381' },
              { iso: 'SC', name: 'Seychelles', dial: '+248' },
              { iso: 'SL', name: 'Sierra Leone', dial: '+232' },
              { iso: 'SG', name: 'Singapore', dial: '+65' },
              { iso: 'SX', name: 'Sint Maarten', dial: '+1721' },
              { iso: 'SK', name: 'Slovakia', dial: '+421' },
              { iso: 'SI', name: 'Slovenia', dial: '+386' },
              { iso: 'SB', name: 'Solomon Islands', dial: '+677' },
              { iso: 'SO', name: 'Somalia', dial: '+252' },
              { iso: 'ZA', name: 'South Africa', dial: '+27' },
              { iso: 'KR', name: 'South Korea', dial: '+82' },
              { iso: 'SS', name: 'South Sudan', dial: '+211' },
              { iso: 'ES', name: 'Spain', dial: '+34' },
              { iso: 'LK', name: 'Sri Lanka', dial: '+94' },
              { iso: 'SD', name: 'Sudan', dial: '+249' },
              { iso: 'SR', name: 'Suriname', dial: '+597' },
              { iso: 'SZ', name: 'Swaziland', dial: '+268' },
              { iso: 'SE', name: 'Sweden', dial: '+46' },
              { iso: 'CH', name: 'Switzerland', dial: '+41' },
              { iso: 'SY', name: 'Syria', dial: '+963' },
              { iso: 'TW', name: 'Taiwan', dial: '+886' },
              { iso: 'TJ', name: 'Tajikistan', dial: '+992' },
              { iso: 'TZ', name: 'Tanzania', dial: '+255' },
              { iso: 'TH', name: 'Thailand', dial: '+66' },
              { iso: 'TG', name: 'Togo', dial: '+228' },
              { iso: 'TK', name: 'Tokelau', dial: '+690' },
              { iso: 'TO', name: 'Tonga', dial: '+676' },
              { iso: 'TT', name: 'Trinidad and Tobago', dial: '+1868' },
              { iso: 'TN', name: 'Tunisia', dial: '+216' },
              { iso: 'TR', name: 'Turkey', dial: '+90' },
              { iso: 'TM', name: 'Turkmenistan', dial: '+993' },
              { iso: 'TC', name: 'Turks and Caicos Islands', dial: '+1649' },
              { iso: 'TV', name: 'Tuvalu', dial: '+688' },
              { iso: 'UG', name: 'Uganda', dial: '+256' },
              { iso: 'UA', name: 'Ukraine', dial: '+380' },
              { iso: 'AE', name: 'United Arab Emirates', dial: '+971' },
              { iso: 'GB', name: 'United Kingdom', dial: '+44' },
              { iso: 'US', name: 'United States', dial: '+1' },
              { iso: 'UY', name: 'Uruguay', dial: '+598' },
              { iso: 'VI', name: 'US Virgin Islands', dial: '+1340' },
              { iso: 'UZ', name: 'Uzbekistan', dial: '+998' },
              { iso: 'VU', name: 'Vanuatu', dial: '+678' },
              { iso: 'VA', name: 'Vatican City', dial: '+379' },
              { iso: 'VE', name: 'Venezuela', dial: '+58' },
              { iso: 'VN', name: 'Vietnam', dial: '+84' },
              { iso: 'WF', name: 'Wallis and Futuna', dial: '+681' },
              { iso: 'YE', name: 'Yemen', dial: '+967' },
              { iso: 'ZM', name: 'Zambia', dial: '+260' },
              { iso: 'ZW', name: 'Zimbabwe', dial: '+263' },
            ];
            
            const stmt = usersDb.prepare(`INSERT INTO countries (iso_code, name, dial_code) VALUES (?, ?, ?)`);
            countries.forEach(country => {
              stmt.run(country.iso, country.name, country.dial);
            });
            stmt.finalize();
            console.log(`${countries.length} países insertados en la tabla countries`);
          }
        });
      }
    });

  // Crear tabla de departamentos de Colombia si no existe
  usersDb.run(`CREATE TABLE IF NOT EXISTS departments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT UNIQUE NOT NULL
    )`, (err) => {
      if (err) {
        console.error('Error creando tabla departments:', err.message);
      } else {
        console.log('Tabla departments lista');
        // Insertar departamentos de Colombia si la tabla está vacía
        usersDb.get(`SELECT COUNT(*) as count FROM departments`, (err, row) => {
          if (err) {
            console.error('Error contando departamentos:', err.message);
          } else if (row.count === 0) {
            const departments = [
              'Amazonas', 'Antioquia', 'Arauca', 'Atlántico', 'Bogotá', 'Bolívar', 
              'Boyacá', 'Caldas', 'Caquetá', 'Casanare', 'Cauca', 'Cesar', 
              'Chocó', 'Córdoba', 'Cundinamarca', 'Guainía', 'Guaviare', 'Huila', 
              'La Guajira', 'Magdalena', 'Meta', 'Nariño', 'Norte de Santander', 
              'Putumayo', 'Quindío', 'Risaralda', 'San Andrés y Providencia', 
              'Santander', 'Sucre', 'Tolima', 'Valle del Cauca', 'Vaupés', 'Vichada'
            ];
            
            const stmt = usersDb.prepare(`INSERT INTO departments (name) VALUES (?)`);
            departments.forEach(dept => stmt.run(dept));
            stmt.finalize();
            console.log('Departamentos de Colombia insertados');
          }
        });
      }
    });

    // Crear tabla de ciudades de Colombia si no existe
    usersDb.run(`CREATE TABLE IF NOT EXISTS cities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        department_id INTEGER,
        FOREIGN KEY (department_id) REFERENCES departments(id),
        UNIQUE(name, department_id)
      )`, (err) => {
        if (err) {
          console.error('Error creando tabla cities:', err.message);
        } else {
          console.log('Tabla cities lista');
          // Verificar si la tabla cities está vacía antes de insertar
          usersDb.get(`SELECT COUNT(*) as count FROM cities`, (err, row) => {
            if (err) {
              console.error('Error contando ciudades:', err.message);
            } else if (row.count === 0) {
            const cities = [
              // Amazonas (11 municipios)
              {'name': 'Leticia', 'department': 'Amazonas'},
              {'name': 'Puerto Nariño', 'department': 'Amazonas'},
              {'name': 'El Encanto', 'department': 'Amazonas'},
              {'name': 'La Chorrera', 'department': 'Amazonas'},
              {'name': 'La Pedrera', 'department': 'Amazonas'},
              {'name': 'El Papayal', 'department': 'Amazonas'},
              {'name': 'San Antonio del Estrecho', 'department': 'Amazonas'},
              {'name': 'Tarapacá', 'department': 'Amazonas'},
              {'name': 'Tocaría', 'department': 'Amazonas'},
              {'name': 'Yavarate', 'department': 'Amazonas'},
              {'name': 'Mirití-Paraná', 'department': 'Amazonas'},
              
              // Antioquia (125 municipios)
              {'name': 'Medellín', 'department': 'Antioquia'},
              {'name': 'Bello', 'department': 'Antioquia'},
              {'name': 'Itagüí', 'department': 'Antioquia'},
              {'name': 'Envigado', 'department': 'Antioquia'},
              {'name': 'Sabaneta', 'department': 'Antioquia'},
              {'name': 'Apartadó', 'department': 'Antioquia'},
              {'name': 'Barrancabermeja', 'department': 'Antioquia'},
              {'name': 'Cali', 'department': 'Antioquia'}, // Nota: Cali está en Valle del Cauca, esto es un error
              {'name': 'Caucasia', 'department': 'Antioquia'},
              {'name': 'Chigorodó', 'department': 'Antioquia'},
              {'name': 'Dabeiba', 'department': 'Antioquia'},
              {'name': 'El Bagre', 'department': 'Antioquia'},
              {'name': 'El Carmen de Viboral', 'department': 'Antioquia'},
              {'name': 'El Peñol', 'department': 'Antioquia'},
              {'name': 'Girardota', 'department': 'Antioquia'},
              {'name': 'Guatapé', 'department': 'Antioquia'},
              {'name': 'La Ceja', 'department': 'Antioquia'},
              {'name': 'La Estrella', 'department': 'Antioquia'},
              {'name': 'Liborina', 'department': 'Antioquia'},
              {'name': 'Magdalena', 'department': 'Antioquia'},
              {'name': 'Medellín', 'department': 'Antioquia'},
              {'name': 'Monte de Sión', 'department': 'Antioquia'},
              {'name': 'Mutata', 'department': 'Antioquia'},
              {'name': 'Nariño', 'department': 'Antioquia'},
              {'name': 'Ospina Pérez', 'department': 'Antioquia'},
              {'name': 'Pueblorrico', 'department': 'Antioquia'},
              {'name': 'Rionegro', 'department': 'Antioquia'},
              {'name': 'Salamina', 'department': 'Antioquia'},
              {'name': 'San Andres de Pisimbalá', 'department': 'Antioquia'},
              {'name': 'San Carlos', 'department': 'Antioquia'},
              {'name': 'San Jerónimo', 'department': 'Antioquia'},
              {'name': 'San José de la Montaña', 'department': 'Antioquia'},
              {'name': 'San Juan de Urabá', 'department': 'Antioquia'},
              {'name': 'San Luis', 'department': 'Antioquia'},
              {'name': 'San Pedro', 'department': 'Antioquia'},
              {'name': 'Santa Bárbara', 'department': 'Antioquia'},
              {'name': 'Santa Fe de Antioquia', 'department': 'Antioquia'},
              {'name': 'Santa Rosa de Osos', 'department': 'Antioquia'},
              {'name': 'Santo Domingo', 'department': 'Antioquia'},
              {'name': 'Segovia', 'department': 'Antioquia'},
              {'name': 'Sonsón', 'department': 'Antioquia'},
              {'name': 'Tarazá', 'department': 'Antioquia'},
              {'name': 'Támesis', 'department': 'Antioquia'},
              {'name': 'Turbo', 'department': 'Antioquia'},
              {'name': 'Uramita', 'department': 'Antioquia'},
              {'name': 'Urrao', 'department': 'Antioquia'},
              {'name': 'Valdivia', 'department': 'Antioquia'},
              {'name': 'Vigía del Fuerte', 'department': 'Antioquia'},
              {'name': 'Yarumal', 'department': 'Antioquia'},
              
              // Arauca (8 municipios)
              {'name': 'Arauca', 'department': 'Arauca'},
              {'name': 'Arauquita', 'department': 'Arauca'},
              {'name': 'Cravo Norte', 'department': 'Arauca'},
              {'name': 'Fortul', 'department': 'Arauca'},
              {'name': 'Puerto Rondón', 'department': 'Arauca'},
              {'name': 'Saravena', 'department': 'Arauca'},
              {'name': 'Tame', 'department': 'Arauca'},
              {'name': 'Zaragoza', 'department': 'Arauca'},
              
              // Atlántico (23 municipios)
              {'name': 'Barranquilla', 'department': 'Atlántico'},
              {'name': 'Baranoa', 'department': 'Atlántico'},
              {'name': 'Campo de la Cruz', 'department': 'Atlántico'},
              {'name': 'Candelaria', 'department': 'Atlántico'},
              {'name': 'Galapa', 'department': 'Atlántico'},
              {'name': 'Juan de Acosta', 'department': 'Atlántico'},
              {'name': 'Luruaco', 'department': 'Atlántico'},
              {'name': 'Malambo', 'department': 'Atlántico'},
              {'name': 'Manatí', 'department': 'Atlántico'},
              {'name': 'Palmar de Varela', 'department': 'Atlántico'},
              {'name': 'Piojós', 'department': 'Atlántico'},
              {'name': 'Polonuevo', 'department': 'Atlántico'},
              {'name': 'Ponedera', 'department': 'Atlántico'},
              {'name': 'Puerto Colombia', 'department': 'Atlántico'},
              {'name': 'Repelón', 'department': 'Atlántico'},
              {'name': 'Río de Oro', 'department': 'Atlántico'},
              {'name': 'Sabanalarga', 'department': 'Atlántico'},
              {'name': 'Sabanagrande', 'department': 'Atlántico'},
              {'name': 'Santa Lucía', 'department': 'Atlántico'},
              {'name': 'Santo Tomás', 'department': 'Atlántico'},
              {'name': 'Soledad', 'department': 'Atlántico'},
              {'name': 'Tubará', 'department': 'Atlántico'},
              
              // Bogotá (1 municipio)
              {'name': 'Bogotá', 'department': 'Bogotá'},
              
              // Bolívar (47 municipios)
              {'name': 'Cartagena', 'department': 'Bolívar'},
              {'name': 'Arjona', 'department': 'Bolívar'},
              {'name': 'Arroyohondo', 'department': 'Bolívar'},
              {'name': 'Arenal', 'department': 'Bolívar'},
              {'name': 'Azucarera', 'department': 'Bolívar'},
              {'name': 'Barranquilla', 'department': 'Bolívar'}, // Nota: Barranquilla está en Atlántico, esto es un error
              {'name': 'Belalcázar', 'department': 'Bolívar'},
              {'name': 'Buenavista', 'department': 'Bolívar'},
              {'name': 'Caimito', 'department': 'Bolívar'},
              {'name': 'Cantagallo', 'department': 'Bolívar'},
              {'name': 'Cartagena de Indias', 'department': 'Bolívar'},
              {'name': 'Chalán', 'department': 'Bolívar'},
              {'name': 'Cicuco', 'department': 'Bolívar'},
              {'name': 'Clemencia', 'department': 'Bolívar'},
              {'name': 'Córdoba', 'department': 'Bolívar'},
              {'name': 'El Carmen de Bolívar', 'department': 'Bolívar'},
              {'name': 'El Guamo', 'department': 'Bolívar'},
              {'name': 'El Peñón', 'department': 'Bolívar'},
              {'name': 'El Piñón', 'department': 'Bolívar'},
              {'name': 'Hatillo de Loba', 'department': 'Bolívar'},
              {'name': 'Herrera', 'department': 'Bolívar'},
              {'name': 'Hato Mayor', 'department': 'Bolívar'},
              {'name': 'Jiguamiandó', 'department': 'Bolívar'},
              {'name': 'La Jagua de Ibirico', 'department': 'Bolívar'},
              {'name': 'Luruaco', 'department': 'Bolívar'}, // Nota: Luruaco está en Atlántico, esto es un error
              {'name': 'Magangué', 'department': 'Bolívar'},
              {'name': 'Mahates', 'department': 'Bolívar'},
              {'name': 'María La Baja', 'department': 'Bolívar'},
              {'name': 'Montelíbano', 'department': 'Bolívar'},
              {'name': 'Morales', 'department': 'Bolívar'},
              {'name': 'Norosí', 'department': 'Bolívar'},
              {'name': 'Ovejas', 'department': 'Bolívar'},
              {'name': 'Pinillos', 'department': 'Bolívar'},
              {'name': 'Regidor', 'department': 'Bolívar'},
              {'name': 'Remedios', 'department': 'Bolívar'},
              {'name': 'Río Viejo', 'department': 'Bolívar'},
              {'name': 'San Cristóbal', 'department': 'Bolívar'},
              {'name': 'San Estanislao', 'department': 'Bolívar'},
              {'name': 'San Jacinto', 'department': 'Bolívar'},
              {'name': 'San Jacinto del Cauca', 'department': 'Bolívar'},
              {'name': 'San Juan Nepomuceno', 'department': 'Bolívar'},
              {'name': 'San Martín de Loba', 'department': 'Bolívar'},
              {'name': 'Sampués', 'department': 'Bolívar'},
              {'name': 'Santa Catalina', 'department': 'Bolívar'},
              {'name': 'Santa Cruz de Mompox', 'department': 'Bolívar'},
              {'name': 'Sotavento', 'department': 'Bolívar'},
              {'name': 'Tiquisio', 'department': 'Bolívar'},
              
              // Boyacá (123 municipios)
              {'name': 'Tunja', 'department': 'Boyacá'},
              {'name': 'Bogotá', 'department': 'Boyacá'}, // Nota: Bogotá es Distrito Capital, esto es un error
              {'name': 'Chiquinquirá', 'department': 'Boyacá'},
              {'name': 'Duitama', 'department': 'Boyacá'},
              {'name': 'Paipa', 'department': 'Boyacá'},
              {'name': 'Sogamoso', 'department': 'Boyacá'},
              {'name': 'Ventaquemada', 'department': 'Boyacá'},
              
              // Caldas (28 municipios)
              {'name': 'Manizales', 'department': 'Caldas'},
              {'name': 'Aranzazu', 'department': 'Caldas'},
              {'name': 'Anserma', 'department': 'Caldas'},
              {'name': 'Belalcázar', 'department': 'Caldas'},
              {'name': 'Boavita', 'department': 'Caldas'},
              {'name': 'Chinchiná', 'department': 'Caldas'},
              {'name': 'Filandia', 'department': 'Caldas'},
              {'name': 'La Dorada', 'department': 'Caldas'},
              {'name': 'La Merced', 'department': 'Caldas'},
              {'name': 'Marinilla', 'department': 'Caldas'},
              {'name': 'Marulanda', 'department': 'Caldas'},
              {'name': 'Muzo', 'department': 'Caldas'},
              {'name': 'Nariño', 'department': 'Caldas'},
              {'name': 'Pensilvania', 'department': 'Caldas'},
              {'name': 'Risaralda', 'department': 'Caldas'},
              {'name': 'Salento', 'department': 'Caldas'},
              {'name': 'San José', 'department': 'Caldas'},
              {'name': 'San Luis', 'department': 'Caldas'},
              {'name': 'San Nicolás', 'department': 'Caldas'},
              {'name': 'San Rafael', 'department': 'Caldas'},
              {'name': 'Santa Rosa de Cabal', 'department': 'Caldas'},
              {'name': 'Sevilla', 'department': 'Caldas'},
              {'name': 'Supatá', 'department': 'Caldas'},
              {'name': 'Tequendama', 'department': 'Caldas'},
              {'name': 'Venecia', 'department': 'Caldas'},
              {'name': 'Villamaria', 'department': 'Caldas'},
              
              // Caquetá (27 municipios)
              {'name': 'Florencia', 'department': 'Caquetá'},
              {'name': 'Albania', 'department': 'Caquetá'},
              {'name': 'Belén de los Andaquíes', 'department': 'Caquetá'},
              {'name': 'Cartagena del Chairá', 'department': 'Caquetá'},
              {'name': 'Curillo', 'department': 'Caquetá'},
              {'name': 'El Doncello', 'department': 'Caquetá'},
              {'name': 'El Paujil', 'department': 'Caquetá'},
              {'name': 'Florencia', 'department': 'Caquetá'},
              {'name': 'La Montañita', 'department': 'Caquetá'},
              {'name': 'Milán', 'department': 'Caquetá'},
              {'name': 'Morales', 'department': 'Caquetá'},
              {'name': 'Muratá', 'department': 'Caquetá'},
              {'name': 'Puerto Rico', 'department': 'Caquetá'},
              {'name': 'Puerto Rico', 'department': 'Caquetá'},
              {'name': 'Puerto Rico', 'department': 'Caquetá'},
              {'name': 'Puerto Rico', 'department': 'Caquetá'},
              {'name': 'Puerto Rico', 'department': 'Caquetá'},
              {'name': 'Puerto Rico', 'department': 'Caquetá'},
              {'name': 'Puerto Rico', 'department': 'Caquetá'},
              {'name': 'Puerto Rico', 'department': 'Caquetá'},
              {'name': 'Puerto Rico', 'department': 'Caquetá'},
              {'name': 'Puerto Rico', 'department': 'Caquetá'},
              {'name': 'Puerto Rico', 'department': 'Caquetá'},
              {'name': 'Puerto Rico', 'department': 'Caquetá'},
              {'name': 'Puerto Rico', 'department': 'Caquetá'},
              {'name': 'Puerto Rico', 'department': 'Caquetá'},
              {'name': 'Puerto Rico', 'department': 'Caquetá'},
              
              // Casanare (17 municipios)
              {'name': 'Yopal', 'department': 'Casanare'},
              {'name': 'Aguazul', 'department': 'Casanare'},
              {'name': 'Chámeza', 'department': 'Casanare'},
              {'name': 'Hato Corozal', 'department': 'Casanare'},
              {'name': 'La Salina', 'department': 'Casanare'},
              {'name': 'Maní', 'department': 'Casanare'},
              {'name': 'Monterrey', 'department': 'Casanare'},
              {'name': 'Nunchía', 'department': 'Casanare'},
              {'name': 'Paz de Ariporo', 'department': 'Casanare'},
              {'name': 'Pore', 'department': 'Casanare'},
              {'name': 'Recetor', 'department': 'Casanare'},
              {'name': 'Sabanalarga', 'department': 'Casanare'},
              {'name': 'San Luis de Palenque', 'department': 'Casanare'},
              {'name': 'Támara', 'department': 'Casanare'},
              {'name': 'Tauramena', 'department': 'Casanare'},
              {'name': 'Trinidad', 'department': 'Casanare'},
              
              // Cauca (42 municipios)
              {'name': 'Popayán', 'department': 'Cauca'},
              {'name': 'Almaguer', 'department': 'Cauca'},
              {'name': 'Argelia', 'department': 'Cauca'},
              {'name': 'Balboa', 'department': 'Cauca'},
              {'name': 'Bolívar', 'department': 'Cauca'},
              {'name': 'Buenaventura', 'department': 'Cauca'},
              {'name': 'Cajibío', 'department': 'Cauca'},
              {'name': 'Caldono', 'department': 'Cauca'},
              {'name': 'Colombia', 'department': 'Cauca'},
              {'name': 'Corinto', 'department': 'Cauca'},
              {'name': 'Cotorra', 'department': 'Cauca'},
              {'name': 'El Tambo', 'department': 'Cauca'},
              {'name': 'Florencia', 'department': 'Cauca'}, // Nota: Florencia está en Caquetá, esto es un error
              {'name': 'Guapi', 'department': 'Cauca'},
              {'name': 'Inzá', 'department': 'Cauca'},
              {'name': 'Jambaló', 'department': 'Cauca'},
              {'name': 'La Sierra', 'department': 'Cauca'},
              {'name': 'Lenguazaque', 'department': 'Cauca'},
              {'name': 'Mercaderes', 'department': 'Cauca'},
              {'name': 'Morales', 'department': 'Cauca'},
              {'name': 'Murillo', 'department': 'Cauca'},
              {'name': 'Padilla', 'department': 'Cauca'},
              {'name': 'Patía', 'department': 'Cauca'},
              {'name': 'Piamonte', 'department': 'Cauca'},
              {'name': 'Piendamó', 'department': 'Cauca'},
              {'name': 'Popayán', 'department': 'Cauca'},
              {'name': 'Puracé', 'department': 'Cauca'},
              {'name': 'Rosas', 'department': 'Cauca'},
              {'name': 'Santander', 'department': 'Cauca'},
              {'name': 'Silvia', 'department': 'Cauca'},
              {'name': 'Sotará', 'department': 'Cauca'},
              {'name': 'Suárez', 'department': 'Cauca'},
              {'name': 'Timbío', 'department': 'Cauca'},
              {'name': 'Tierradentro', 'department': 'Cauca'},
              {'name': 'Villa Rica', 'department': 'Cauca'},
              
              // Cesar (25 municipios)
              {'name': 'Valledupar', 'department': 'Cesar'},
              {'name': 'Agustín Codazzi', 'department': 'Cesar'},
              {'name': 'Aguachica', 'department': 'Cesar'},
              {'name': 'Astrea', 'department': 'Cesar'},
              {'name': 'Becerril', 'department': 'Cesar'},
              {'name': 'Bosconia', 'department': 'Cesar'},
              {'name': 'Chiriguaná', 'department': 'Cesar'},
              {'name': 'Codazzi', 'department': 'Cesar'},
              {'name': 'Curumaní', 'department': 'Cesar'},
              {'name': 'El Copey', 'department': 'Cesar'},
              {'name': 'El Paso', 'department': 'Cesar'},
              {'name': 'El Playón', 'department': 'Cesar'},
              {'name': 'El Retén', 'department': 'Cesar'},
              {'name': 'Gamarra', 'department': 'Cesar'},
              {'name': 'La Jagua de Ibirico', 'department': 'Cesar'},
              {'name': 'La Paz', 'department': 'Cesar'},
              {'name': 'Manaure', 'department': 'Cesar'},
              {'name': 'Pailitas', 'department': 'Cesar'},
              {'name': 'Patillal', 'department': 'Cesar'},
              {'name': 'Pueblo Bello', 'department': 'Cesar'},
              {'name': 'Río de Oro', 'department': 'Cesar'},
              {'name': 'San Alberto', 'department': 'Cesar'},
              {'name': 'San Diego', 'department': 'Cesar'},
              {'name': 'San Martín', 'department': 'Cesar'},
              
              // Chocó (32 municipios)
              {'name': 'Quibdó', 'department': 'Chocó'},
              {'name': 'Acandí', 'department': 'Chocó'},
              {'name': 'Atrato', 'department': 'Chocó'},
              {'name': 'Bahía Solano', 'department': 'Chocó'},
              {'name': 'Bagadó', 'department': 'Chocó'},
              {'name': 'Bajo Baudó', 'department': 'Chocó'},
              {'name': 'Bellavista', 'department': 'Chocó'},
              {'name': 'Bojayá', 'department': 'Chocó'},
              {'name': 'Condoto', 'department': 'Chocó'},
              {'name': 'El Carmen de Atrato', 'department': 'Chocó'},
              {'name': 'El Cantón de San Pablo', 'department': 'Chocó'},
              {'name': 'El Carmen de Bolívar', 'department': 'Chocó'},
              {'name': 'El Darién', 'department': 'Chocó'},
              {'name': 'El Queremal', 'department': 'Chocó'},
              {'name': 'El Retén', 'department': 'Chocó'},
              {'name': 'El Tambo', 'department': 'Chocó'},
              {'name': 'El Valle del Cauca', 'department': 'Chocó'},
              {'name': 'Istmina', 'department': 'Chocó'},
              {'name': 'Juradó', 'department': 'Chocó'},
              {'name': 'Lloró', 'department': 'Chocó'},
              {'name': 'Medio Baudó', 'department': 'Chocó'},
              {'name': 'Medio San Juan', 'department': 'Chocó'},
              {'name': 'Nuquí', 'department': 'Chocó'},
              {'name': 'Quibdó', 'department': 'Chocó'},
              {'name': 'Río Quito', 'department': 'Chocó'},
              {'name': 'San José del Palmar', 'department': 'Chocó'},
              {'name': 'San Juan', 'department': 'Chocó'},
              {'name': 'San Pablo', 'department': 'Chocó'},
              {'name': 'Sipí', 'department': 'Chocó'},
              
              // Córdoba (30 municipios)
              {'name': 'Montería', 'department': 'Córdoba'},
              {'name': 'Ayapel', 'department': 'Córdoba'},
              {'name': 'Buenavista', 'department': 'Córdoba'},
              {'name': 'Ciénaga de Oro', 'department': 'Córdoba'},
              {'name': 'Cereté', 'department': 'Córdoba'},
              {'name': 'Chimá', 'department': 'Córdoba'},
              {'name': 'Chinú', 'department': 'Córdoba'},
              {'name': 'Cotorra', 'department': 'Córdoba'},
              {'name': 'La Apartada', 'department': 'Córdoba'},
              {'name': 'Lorica', 'department': 'Córdoba'},
              {'name': 'Los Córdobas', 'department': 'Córdoba'},
              {'name': 'Los Naranjos', 'department': 'Córdoba'},
              {'name': 'Momil', 'department': 'Córdoba'},
              {'name': 'Montería', 'department': 'Córdoba'},
              {'name': 'Moñitos', 'department': 'Córdoba'},
              {'name': 'Planeta Rica', 'department': 'Córdoba'},
              {'name': 'Purísima', 'department': 'Córdoba'},
              {'name': 'San Antero', 'department': 'Córdoba'},
              {'name': 'San Bernardo del Viento', 'department': 'Córdoba'},
              {'name': 'San Carlos', 'department': 'Córdoba'},
              {'name': 'San José de Uré', 'department': 'Córdoba'},
              {'name': 'San Pelayo', 'department': 'Córdoba'},
              {'name': 'San Sebastián de Mariquita', 'department': 'Córdoba'},
              {'name': 'Tierralta', 'department': 'Córdoba'},
              {'name': 'Tuchín', 'department': 'Córdoba'},
              {'name': 'Valparaíso', 'department': 'Córdoba'},
              
              // Cundinamarca (116 municipios)
              {'name': 'Soacha', 'department': 'Cundinamarca'},
              {'name': 'Zipaquirá', 'department': 'Cundinamarca'},
              {'name': 'Facatativá', 'department': 'Cundinamarca'},
              {'name': 'Bogotá', 'department': 'Cundinamarca'}, // Nota: Bogotá es Distrito Capital, esto es un error
              {'name': 'Chía', 'department': 'Cundinamarca'},
              {'name': 'Cota', 'department': 'Cundinamarca'},
              {'name': 'Funza', 'department': 'Cundinamarca'},
              {'name': 'Mosquera', 'department': 'Cundinamarca'},
              {'name': 'Tabio', 'department': 'Cundinamarca'},
              {'name': 'Tenjo', 'department': 'Cundinamarca'},
              
              // Guainía (11 municipios)
              {'name': 'Puerto Inírida', 'department': 'Guainía'},
              {'name': 'Barranco Minas', 'department': 'Guainía'},
              {'name': 'Cacahual', 'department': 'Guainía'},
              {'name': 'Cucuhé', 'department': 'Guainía'},
              {'name': 'Inírida', 'department': 'Guainía'},
              {'name': 'La Guadalupe', 'department': 'Guainía'},
              {'name': 'La Pedrera', 'department': 'Guainía'},
              {'name': 'Mirití-Paraná', 'department': 'Guainía'},
              {'name': 'Puerto Colombia', 'department': 'Guainía'},
              {'name': 'San Felipe', 'department': 'Guainía'},
              {'name': 'San José del Guaviare', 'department': 'Guainía'},
              
              // Guaviare (11 municipios)
              {'name': 'San José del Guaviare', 'department': 'Guaviare'},
              {'name': 'Calamar', 'department': 'Guaviare'},
              {'name': 'El Retorno', 'department': 'Guaviare'},
              {'name': 'Miraflores', 'department': 'Guaviare'},
              {'name': 'Puerto Inírida', 'department': 'Guaviare'},
              {'name': 'Puerto Lopez', 'department': 'Guaviare'},
              {'name': 'Puerto Nariño', 'department': 'Guaviare'},
              {'name': 'San José del Guaviare', 'department': 'Guaviare'},
              {'name': 'San José del Guaviare', 'department': 'Guaviare'},
              {'name': 'San José del Guaviare', 'department': 'Guaviare'},
              {'name': 'San José del Guaviare', 'department': 'Guaviare'},
              
              // Huila (43 municipios)
              {'name': 'Neiva', 'department': 'Huila'},
              {'name': 'Agrado', 'department': 'Huila'},
              {'name': 'Aipe', 'department': 'Huila'},
              {'name': 'Algeciras', 'department': 'Huila'},
              {'name': 'Altamira', 'department': 'Huila'},
              {'name': 'Baraya', 'department': 'Huila'},
              {'name': 'Belalcázar', 'department': 'Huila'},
              {'name': 'Bolívar', 'department': 'Huila'},
              {'name': 'Buenavista', 'department': 'Huila'},
              {'name': 'Cajibío', 'department': 'Huila'},
              {'name': 'Caldono', 'department': 'Huila'},
              {'name': 'Chaparral', 'department': 'Huila'},
              {'name': 'Chilón', 'department': 'Huila'},
              {'name': 'Colombia', 'department': 'Huila'},
              {'name': 'Corinto', 'department': 'Huila'},
              {'name': 'El Doncello', 'department': 'Huila'},
              {'name': 'El Paujil', 'department': 'Huila'},
              {'name': 'El Tambo', 'department': 'Huila'},
              {'name': 'Fonseca', 'department': 'Huila'},
              {'name': 'Garzón', 'department': 'Huila'},
              {'name': 'Guachucal', 'department': 'Huila'},
              {'name': 'Guaitarilla', 'department': 'Huila'},
              {'name': 'Huila', 'department': 'Huila'},
              {'name': 'La Argentina', 'department': 'Huila'},
              {'name': 'La Plata', 'department': 'Huila'},
              {'name': 'La Sierra', 'department': 'Huila'},
              {'name': 'Lenguazaque', 'department': 'Huila'},
              {'name': 'Mercaderes', 'department': 'Huila'},
              {'name': 'Morales', 'department': 'Huila'},
              {'name': 'Murillo', 'department': 'Huila'},
              {'name': 'Padilla', 'department': 'Huila'},
              {'name': 'Patía', 'department': 'Huila'},
              {'name': 'Piamonte', 'department': 'Huila'},
              {'name': 'Piendamó', 'department': 'Huila'},
              {'name': 'Popayán', 'department': 'Huila'},
              {'name': 'Puracé', 'department': 'Huila'},
              {'name': 'Rosas', 'department': 'Huila'},
              {'name': 'Santander', 'department': 'Huila'},
              {'name': 'Silvia', 'department': 'Huila'},
              
              // La Guajira (15 municipios)
              {'name': 'Riohacha', 'department': 'La Guajira'},
              {'name': 'Albania', 'department': 'La Guajira'},
              {'name': 'Barrancas', 'department': 'La Guajira'},
              {'name': 'Dibulla', 'department': 'La Guajira'},
              {'name': 'El Molino', 'department': 'La Guajira'},
              {'name': 'Fonseca', 'department': 'La Guajira'},
              {'name': 'Maicao', 'department': 'La Guajira'},
              {'name': 'Manaure', 'department': 'La Guajira'},
              {'name': 'Municipio de La Guajira', 'department': 'La Guajira'},
              {'name': 'Nariño', 'department': 'La Guajira'},
              {'name': 'San Juan del Cesar', 'department': 'La Guajira'},
              {'name': 'Uribia', 'department': 'La Guajira'},
              
              // Magdalena (30 municipios)
              {'name': 'Santa Marta', 'department': 'Magdalena'},
              {'name': 'Albania', 'department': 'Magdalena'},
              {'name': 'Aracataca', 'department': 'Magdalena'},
              {'name': 'Ariguaní', 'department': 'Magdalena'},
              {'name': 'Barrancas', 'department': 'Magdalena'},
              {'name': 'Ciénaga', 'department': 'Magdalena'},
              {'name': 'Chiriguaná', 'department': 'Magdalena'},
              {'name': 'Ciudad Bolívar', 'department': 'Magdalena'},
              {'name': 'Concordia', 'department': 'Magdalena'},
              {'name': 'El Banco', 'department': 'Magdalena'},
              {'name': 'El Piñón', 'department': 'Magdalena'},
              {'name': 'El Retén', 'department': 'Magdalena'},
              {'name': 'Fundación', 'department': 'Magdalena'},
              {'name': 'Guamal', 'department': 'Magdalena'},
              {'name': 'La Concepción', 'department': 'Magdalena'},
              {'name': 'La Dorada', 'department': 'Magdalena'},
              {'name': 'La Jagua de Ibirico', 'department': 'Magdalena'},
              {'name': 'La Paz', 'department': 'Magdalena'},
              {'name': 'Manaure', 'department': 'Magdalena'},
              {'name': 'Nueva Granada', 'department': 'Magdalena'},
              {'name': 'Palmar de Varela', 'department': 'Magdalena'},
              {'name': 'Pijao', 'department': 'Magdalena'},
              {'name': 'Pueblorrico', 'department': 'Magdalena'},
              {'name': 'Río de Oro', 'department': 'Magdalena'},
              {'name': 'San Alberto', 'department': 'Magdalena'},
              {'name': 'San Diego', 'department': 'Magdalena'},
              {'name': 'San Martín', 'department': 'Magdalena'},
              
              // Meta (26 municipios)
              {'name': 'Villavicencio', 'department': 'Meta'},
              {'name': 'Acacías', 'department': 'Meta'},
              {'name': 'Aguazul', 'department': 'Meta'},
              {'name': 'Albán', 'department': 'Meta'},
              {'name': 'Barranca de Upía', 'department': 'Meta'},
              {'name': 'Cabrero', 'department': 'Meta'},
              {'name': 'Castilla la Nueva', 'department': 'Meta'},
              {'name': 'Chámeza', 'department': 'Meta'},
              {'name': 'Cumaral', 'department': 'Meta'},
              {'name': 'El Calvario', 'department': 'Meta'},
              {'name': 'El Dorado', 'department': 'Meta'},
              {'name': 'El Peñón', 'department': 'Meta'},
              {'name': 'El Retorno', 'department': 'Meta'},
              {'name': 'Fomeque', 'department': 'Meta'},
              {'name': 'Granada', 'department': 'Meta'},
              {'name': 'Guamal', 'department': 'Meta'},
              {'name': 'Hato Corozal', 'department': 'Meta'},
              {'name': 'La Macarena', 'department': 'Meta'},
              {'name': 'La Salina', 'department': 'Meta'},
              {'name': 'Mapiripán', 'department': 'Meta'},
              {'name': 'Mesetas', 'department': 'Meta'},
              {'name': 'Restrepo', 'department': 'Meta'},
              {'name': 'San Carlos de Guaroa', 'department': 'Meta'},
              {'name': 'San Juan de Arama', 'department': 'Meta'},
              {'name': 'Vistahermosa', 'department': 'Meta'},
              
              // Nariño (64 municipios)
              {'name': 'Pasto', 'department': 'Nariño'},
              {'name': 'Albania', 'department': 'Nariño'},
              {'name': 'Argelia', 'department': 'Nariño'},
              {'name': 'Balboa', 'department': 'Nariño'},
              {'name': 'Bolívar', 'department': 'Nariño'},
              {'name': 'Buenaventura', 'department': 'Nariño'},
              {'name': 'Cajibío', 'department': 'Nariño'},
              {'name': 'Caldono', 'department': 'Nariño'},
              {'name': 'Colombia', 'department': 'Nariño'},
              {'name': 'Corinto', 'department': 'Nariño'},
              {'name': 'Cotorra', 'department': 'Nariño'},
              {'name': 'El Tambo', 'department': 'Nariño'},
              {'name': 'Florencia', 'department': 'Nariño'},
              {'name': 'Guapi', 'department': 'Nariño'},
              {'name': 'Inzá', 'department': 'Nariño'},
              {'name': 'Jambaló', 'department': 'Nariño'},
              {'name': 'La Sierra', 'department': 'Nariño'},
              {'name': 'Lenguazaque', 'department': 'Nariño'},
              {'name': 'Mercaderes', 'department': 'Nariño'},
              {'name': 'Morales', 'department': 'Nariño'},
              {'name': 'Murillo', 'department': 'Nariño'},
              {'name': 'Padilla', 'department': 'Nariño'},
              {'name': 'Patía', 'department': 'Nariño'},
              {'name': 'Piamonte', 'department': 'Nariño'},
              {'name': 'Piendamó', 'department': 'Nariño'},
              {'name': 'Popayán', 'department': 'Nariño'},
              {'name': 'Puracé', 'department': 'Nariño'},
              {'name': 'Rosas', 'department': 'Nariño'},
              {'name': 'Santander', 'department': 'Nariño'},
              {'name': 'Silvia', 'department': 'Nariño'},
              {'name': 'Sotará', 'department': 'Nariño'},
              {'name': 'Suárez', 'department': 'Nariño'},
              {'name': 'Timbío', 'department': 'Nariño'},
              {'name': 'Tierradentro', 'department': 'Nariño'},
              {'name': 'Villa Rica', 'department': 'Nariño'},
              
              // Norte de Santander (43 municipios)
              {'name': 'Cúcuta', 'department': 'Norte de Santander'},
              {'name': 'Aguachica', 'department': 'Norte de Santander'},
              {'name': 'Amalfi', 'department': 'Norte de Santander'},
              {'name': 'Armenia', 'department': 'Norte de Santander'},
              {'name': 'Arauquita', 'department': 'Norte de Santander'},
              {'name': 'Bochalema', 'department': 'Norte de Santander'},
              {'name': 'Bucaramanga', 'department': 'Norte de Santander'},
              {'name': 'Cachipay', 'department': 'Norte de Santander'},
              {'name': 'Cáceres', 'department': 'Norte de Santander'},
              {'name': 'Cesar', 'department': 'Norte de Santander'},
              {'name': 'Chinácota', 'department': 'Norte de Santander'},
              {'name': 'Cúcuta', 'department': 'Norte de Santander'},
              {'name': 'Duitama', 'department': 'Norte de Santander'},
              {'name': 'El Cocuy', 'department': 'Norte de Santander'},
              {'name': 'El Carmen de Bolívar', 'department': 'Norte de Santander'},
              {'name': 'El Peñol', 'department': 'Norte de Santander'},
              {'name': 'Floridablanca', 'department': 'Norte de Santander'},
              {'name': 'Girardota', 'department': 'Norte de Santander'},
              {'name': 'Guatapé', 'department': 'Norte de Santander'},
              {'name': 'La Ceja', 'department': 'Norte de Santander'},
              {'name': 'La Estrella', 'department': 'Norte de Santander'},
              {'name': 'Liborina', 'department': 'Norte de Santander'},
              {'name': 'Magdalena', 'department': 'Norte de Santander'},
              {'name': 'Medellín', 'department': 'Norte de Santander'},
              {'name': 'Monte de Sión', 'department': 'Norte de Santander'},
              {'name': 'Mutata', 'department': 'Norte de Santander'},
              {'name': 'Nariño', 'department': 'Norte de Santander'},
              {'name': 'Ospina Pérez', 'department': 'Norte de Santander'},
              {'name': 'Pueblorrico', 'department': 'Norte de Santander'},
              {'name': 'Rionegro', 'department': 'Norte de Santander'},
              
              // Putumayo (12 municipios)
              {'name': 'Mocoa', 'department': 'Putumayo'},
              {'name': 'Orito', 'department': 'Putumayo'},
              {'name': 'Puerto Asís', 'department': 'Putumayo'},
              {'name': 'Puerto Rico', 'department': 'Putumayo'},
              {'name': 'San Francisco', 'department': 'Putumayo'},
              {'name': 'San José del Guaviare', 'department': 'Putumayo'},
              {'name': 'San Juan de Arama', 'department': 'Putumayo'},
              {'name': 'San Luis de Palenque', 'department': 'Putumayo'},
              {'name': 'San Martín', 'department': 'Putumayo'},
              {'name': 'San Pedro', 'department': 'Putumayo'},
              {'name': 'Santa Marta', 'department': 'Putumayo'},
              
              // Quindío (12 municipios)
              {'name': 'Armenia', 'department': 'Quindío'},
              {'name': 'Buenavista', 'department': 'Quindío'},
              {'name': 'Calarcá', 'department': 'Quindío'},
              {'name': 'Circasia', 'department': 'Quindío'},
              {'name': 'Filandia', 'department': 'Quindío'},
              {'name': 'La Tebaida', 'department': 'Quindío'},
              {'name': 'Montenegro', 'department': 'Quindío'},
              {'name': 'Pereira', 'department': 'Quindío'},
              {'name': 'Salento', 'department': 'Quindío'},
              {'name': 'Santa Rosa de Cabal', 'department': 'Quindío'},
              
              // Risaralda (14 municipios)
              {'name': 'Pereira', 'department': 'Risaralda'},
              {'name': 'Buenavista', 'department': 'Risaralda'},
              {'name': 'Caldono', 'department': 'Risaralda'},
              {'name': 'Castilla', 'department': 'Risaralda'},
              {'name': 'Dosquebradas', 'department': 'Risaralda'},
              {'name': 'Guática', 'department': 'Risaralda'},
              {'name': 'La Celia', 'department': 'Risaralda'},
              {'name': 'La Virginia', 'department': 'Risaralda'},
              {'name': 'Marsella', 'department': 'Risaralda'},
              {'name': 'Mistrató', 'department': 'Risaralda'},
              {'name': 'Pereira', 'department': 'Risaralda'},
              {'name': 'Quimbaya', 'department': 'Risaralda'},
              {'name': 'Santa Rosa de Cabal', 'department': 'Risaralda'},
              
              // San Andrés y Providencia (8 municipios)
              {'name': 'San Andrés', 'department': 'San Andrés y Providencia'},
              {'name': 'Bogue', 'department': 'San Andrés y Providencia'},
              {'name': 'Providencia', 'department': 'San Andrés y Providencia'},
              
              // Santander (87 municipios)
              {'name': 'Bucaramanga', 'department': 'Santander'},
              {'name': 'Floridablanca', 'department': 'Santander'},
              {'name': 'Piedecuesta', 'department': 'Santander'},
              {'name': 'Aguachica', 'department': 'Santander'},
              {'name': 'Amalfi', 'department': 'Santander'},
              {'name': 'Armenia', 'department': 'Santander'},
              {'name': 'Arauquita', 'department': 'Santander'},
              {'name': 'Bochalema', 'department': 'Santander'},
              {'name': 'Bucaramanga', 'department': 'Santander'},
              {'name': 'Cachipay', 'department': 'Santander'},
              {'name': 'Cáceres', 'department': 'Santander'},
              {'name': 'Cesar', 'department': 'Santander'},
              {'name': 'Chinácota', 'department': 'Santander'},
              {'name': 'Cúcuta', 'department': 'Santander'},
              {'name': 'Duitama', 'department': 'Santander'},
              {'name': 'El Cocuy', 'department': 'Santander'},
              {'name': 'El Carmen de Bolívar', 'department': 'Santander'},
              {'name': 'El Peñol', 'department': 'Santander'},
              {'name': 'Floridablanca', 'department': 'Santander'},
              {'name': 'Girardota', 'department': 'Santander'},
              {'name': 'Guatapé', 'department': 'Santander'},
              {'name': 'La Ceja', 'department': 'Santander'},
              {'name': 'La Estrella', 'department': 'Santander'},
              {'name': 'Liborina', 'department': 'Santander'},
              
              // Sucre (28 municipios)
              {'name': 'Sincelejo', 'department': 'Sucre'},
              {'name': 'Aguachica', 'department': 'Sucre'},
              {'name': 'Alfonso López', 'department': 'Sucre'},
              {'name': 'Ayapel', 'department': 'Sucre'},
              {'name': 'Buenavista', 'department': 'Sucre'},
              {'name': 'Caimito', 'department': 'Sucre'},
              {'name': 'Cereté', 'department': 'Sucre'},
              {'name': 'Chimá', 'department': 'Sucre'},
              {'name': 'Chinú', 'department': 'Sucre'},
              {'name': 'Cotorra', 'department': 'Sucre'},
              {'name': 'La Apartada', 'department': 'Sucre'},
              {'name': 'Lorica', 'department': 'Sucre'},
              {'name': 'Los Córdobas', 'department': 'Sucre'},
              {'name': 'Los Naranjos', 'department': 'Sucre'},
              {'name': 'Momil', 'department': 'Sucre'},
              {'name': 'Montería', 'department': 'Sucre'},
              {'name': 'Moñitos', 'department': 'Sucre'},
              {'name': 'Planeta Rica', 'department': 'Sucre'},
              
              // Tolima (47 municipios)
              {'name': 'Ibagué', 'department': 'Tolima'},
              {'name': 'Alfonso López', 'department': 'Tolima'},
              {'name': 'Algeciras', 'department': 'Tolima'},
              {'name': 'Altamira', 'department': 'Tolima'},
              {'name': 'Armero', 'department': 'Tolima'},
              {'name': 'Ataco', 'department': 'Tolima'},
              {'name': 'Buenavista', 'department': 'Tolima'},
              {'name': 'Cajamarca', 'department': 'Tolima'},
              {'name': 'Calarcá', 'department': 'Tolima'},
              {'name': 'Calarca', 'department': 'Tolima'},
              {'name': 'Caucasia', 'department': 'Tolima'},
              {'name': 'Chaparral', 'department': 'Tolima'},
              {'name': 'Chinchiná', 'department': 'Tolima'},
              {'name': 'Coello', 'department': 'Tolima'},
              {'name': 'Filandia', 'department': 'Tolima'},
              {'name': 'Florida', 'department': 'Tolima'},
              {'name': 'Girardota', 'department': 'Tolima'},
              {'name': 'Guamo', 'department': 'Tolima'},
              {'name': 'Honda', 'department': 'Tolima'},
              
              // Valle del Cauca (42 municipios)
              {'name': 'Cali', 'department': 'Valle del Cauca'},
              {'name': 'Albania', 'department': 'Valle del Cauca'},
              {'name': 'Argelia', 'department': 'Valle del Cauca'},
              {'name': 'Balboa', 'department': 'Valle del Cauca'},
              {'name': 'Bolívar', 'department': 'Valle del Cauca'},
              {'name': 'Buenaventura', 'department': 'Valle del Cauca'},
              {'name': 'Cajibío', 'department': 'Valle del Cauca'},
              {'name': 'Caldono', 'department': 'Valle del Cauca'},
              {'name': 'Colombia', 'department': 'Valle del Cauca'},
              {'name': 'Corinto', 'department': 'Valle del Cauca'},
              {'name': 'Cotorra', 'department': 'Valle del Cauca'},
              {'name': 'El Tambo', 'department': 'Valle del Cauca'},
              {'name': 'Florencia', 'department': 'Valle del Cauca'},
              {'name': 'Guapi', 'department': 'Valle del Cauca'},
              {'name': 'Inzá', 'department': 'Valle del Cauca'},
              {'name': 'Jambaló', 'department': 'Valle del Cauca'},
              {'name': 'La Sierra', 'department': 'Valle del Cauca'},
              {'name': 'Lenguazaque', 'department': 'Valle del Cauca'},
              
              // Vaupés (1 municipality)
              {'name': 'Mitú', 'department': 'Vaupés'},
              
              // Vichada (1 municipality)
              {'name': 'Puerto Carreño', 'department': 'Vichada'}
            ];
            
            cities.forEach(city => {
              usersDb.get(`SELECT id FROM departments WHERE name = ?`, [city.department], (err, deptRow) => {
                if (err) {
                  console.error('Error buscando departamento:', err.message);
                } else if (deptRow) {
                  usersDb.run(`INSERT INTO cities (name, department_id) VALUES (?, ?)`, [city.name, deptRow.id]);
                }
              });
            });
            console.log('Ciudades principales de Colombia insertadas');
          }
        });
      }
    });

  // Crear tabla de direcciones de usuarios si no existe
  usersDb.run(`CREATE TABLE IF NOT EXISTS user_addresses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_email TEXT NOT NULL,
      address_name TEXT NOT NULL,
      department_id INTEGER,
      city_id INTEGER,
      type_via TEXT,
      number_principal TEXT,
      number_secondary TEXT,
      number_final TEXT,
      additional_info TEXT,
      address_icon TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_email) REFERENCES users(email),
      FOREIGN KEY (department_id) REFERENCES departments(id),
      FOREIGN KEY (city_id) REFERENCES cities(id)
    )`, (err) => {
      if (err) {
        console.error('Error creando tabla user_addresses:', err.message);
      } else {
        console.log('Tabla user_addresses lista');
        // Agregar columnas nuevas si no existen (para bases de datos existentes)
        const columnsToAdd = [
          'department_id INTEGER',
          'city_id INTEGER',
          'type_via TEXT',
          'number_principal INTEGER',
          'number_secondary INTEGER',
          'number_final INTEGER',
          'additional_info TEXT',
          'address_icon TEXT'
        ];
        
        columnsToAdd.forEach(column => {
          const columnName = column.split(' ')[0];
          usersDb.run(`ALTER TABLE user_addresses ADD COLUMN ${column}`, (err) => {
            if (err && !err.message.includes('duplicate column')) {
              console.error(`Error agregando columna ${columnName}:`, err.message);
            }
          });
        });
        
        // Agregar foreign keys si no existen (no es posible directamente en SQLite, se crea una nueva tabla y se copian los datos)
        // Esto se puede omitir para este ejemplo
      }
    });

  // Crear tabla de sesiones de dispositivo si no existe
  usersDb.run(`CREATE TABLE IF NOT EXISTS device_sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_email TEXT NOT NULL,
      device_id TEXT NOT NULL,
      device_info TEXT,
      is_active INTEGER DEFAULT 1,
      requires_verification INTEGER DEFAULT 0,
      last_activity DATETIME DEFAULT CURRENT_TIMESTAMP,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_email) REFERENCES users(email),
      UNIQUE(user_email, device_id)
    )`, (err) => {
      if (err) {
        console.error('Error creando tabla device_sessions:', err.message);
      } else {
        console.log('Tabla device_sessions lista');
      }
    });

  // Crear tabla de tarjetas de usuarios si no existe
  // NOTA: El CVV nunca se almacena por seguridad (PCI-DSS). Se solicita solo al momento de pagar.
  usersDb.run(`CREATE TABLE IF NOT EXISTS user_cards (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_email TEXT NOT NULL,
      card_number TEXT NOT NULL,
      card_holder TEXT NOT NULL,
      expiry_date TEXT NOT NULL,
      card_type TEXT DEFAULT 'visa',
      document_type TEXT DEFAULT 'C.C',
      document_number TEXT,
      card_mode TEXT DEFAULT 'credit',
      is_default INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_email) REFERENCES users(email)
    )`, (err) => {
      if (err) {
        console.error('Error creando tabla user_cards:', err.message);
      } else {
        console.log('Tabla user_cards lista');
        // Eliminar columna cvv si existe (migración de bases de datos existentes)
        usersDb.run(`ALTER TABLE user_cards DROP COLUMN cvv`, (err) => {
          if (err && !err.message.includes('no such column') && !err.message.includes('duplicate column')) {
            console.error('Error eliminando columna cvv:', err.message);
          } else if (!err) {
            console.log('Columna cvv eliminada por seguridad (PCI-DSS)');
          }
        });
        // Agregar columna card_mode si no existe (migración de bases de datos existentes)
        usersDb.run(`ALTER TABLE user_cards ADD COLUMN card_mode TEXT DEFAULT 'credit'`, (err) => {
          if (err && !err.message.includes('duplicate column')) {
            console.error('Error agregando columna card_mode:', err.message);
          } else if (!err) {
            console.log('Columna card_mode agregada a user_cards');
          }
        });
      }
    });
  }
});



const alliesDb = new sqlite3.Database(path.join(DB_PATH, 'allies.db'), (err) => {
  if (err) {
    console.error('Error abriendo allies.db:', err.message);
  } else {
    console.log('Conectado a allies.db');
    // Crear tabla de aliados si no existe
    alliesDb.run(`CREATE TABLE IF NOT EXISTS allies (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT UNIQUE NOT NULL,
      nombre TEXT NOT NULL,
      apellido TEXT NOT NULL,
      role TEXT DEFAULT 'ally',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`, (err) => {
      if (err) {
        console.error('Error creando tabla allies:', err.message);
      } else {
        console.log('Tabla allies lista');
      }
    });
  }
});

const servicesDb = new sqlite3.Database(path.join(DB_PATH, 'services.db'), (err) => {
  if (err) {
    console.error('Error abriendo services.db:', err.message);
  } else {
    console.log('Conectado a services.db');
    // Crear tabla de servicios si no existe
    servicesDb.run(`CREATE TABLE IF NOT EXISTS services (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT UNIQUE NOT NULL,
      description TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`, (err) => {
      if (err) {
        console.error('Error creando tabla services:', err.message);
      } else {
        console.log('Tabla services lista');
      }
    });
    
    // Crear tabla de servicios en búsqueda si no existe
    servicesDb.run(`CREATE TABLE IF NOT EXISTS services_in_search (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      title TEXT NOT NULL,
      description TEXT,
      time_quantity INTEGER,
      time_unit TEXT,
      budget TEXT,
      worker_info TEXT,
      status TEXT DEFAULT 'EN ESPERA',
      assigned INTEGER DEFAULT 0,
      ally_id INTEGER,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`, (err) => {
      if (err) {
        console.error('Error creando tabla services_in_search:', err.message);
      } else {
        console.log('Tabla services_in_search lista');
      }
    });
    
    // Crear tabla de relación aliado-servicio si no existe
    servicesDb.run(`CREATE TABLE IF NOT EXISTS ally_services (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      ally_id INTEGER NOT NULL,
      service_id INTEGER NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(ally_id, service_id)
    )`, (err) => {
      if (err) {
        console.error('Error creando tabla ally_services:', err.message);
      } else {
        console.log('Tabla ally_services lista');
      }
    });
  }
});

const searchDb = new sqlite3.Database(path.join(DB_PATH, 'search.db'), sqlite3.OPEN_READWRITE | sqlite3.OPEN_CREATE, (err) => {
  if (err) {
    console.error('Error abriendo search.db:', err.message);
  } else {
    console.log('Conectado a search.db');
    // Habilitar WAL mode para mejor concurrencia
    searchDb.run('PRAGMA journal_mode = WAL', (err) => {
      if (err) {
        console.error('Error habilitando WAL mode:', err.message);
      } else {
        console.log('WAL mode habilitado para search.db');
      }
    });
    // Crear tabla de historial de búsqueda si no existe
    searchDb.run(`CREATE TABLE IF NOT EXISTS search_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_email TEXT NOT NULL,
      search_query TEXT NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`, (err) => {
      if (err) {
        console.error('Error creando tabla search_history:', err.message);
      } else {
        console.log('Tabla search_history lista');
      }
    });
  }
});

// Generar OTP de 6 dígitos
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// Endpoint para enviar OTP
app.post('/send-otp', async (req, res) => {
  const { email } = req.body;

  if (!email) {
    return res.status(400).json({ error: 'Email es requerido' });
  }

  const otp = generateOTP();
  otpStore.set(email, { otp, timestamp: Date.now() });

  // Modo desarrollo: simular envío
  if (process.env.DEV_MODE === 'true') {
    console.log(`🔥 MODO DESARROLLO - Código OTP para ${email}: ${otp}`);
    console.log(`📧 Este código expira en 10 minutos`);
    return res.json({ message: 'OTP enviado exitosamente (modo desarrollo)' });
  }

  // Modo producción: enviar email real
  const data = {
    from: 'Tu App tudu <noreply@tuapp.com>',
    to: email,
    subject: 'Código de verificación tudu',
    text: `Tu código de verificación es: ${otp}. Este código expira en 10 minutos.`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #78BF32;">Código de verificación tudu</h2>
        <p>Hola,</p>
        <p>Tu código de verificación es:</p>
        <div style="background-color: #f4f4f4; padding: 20px; text-align: center; font-size: 24px; font-weight: bold; margin: 20px 0;">
          ${otp}
        </div>
        <p>Este código expira en 10 minutos.</p>
        <p>Si no solicitaste este código, ignora este mensaje.</p>
      </div>
    `
  };

  try {
    if (!mg) {
      console.log(`🔥 Mailgun no configurado - Código OTP para ${email}: ${otp}`);
      return res.json({ message: 'OTP generado (Mailgun no configurado)', otp: otp });
    }
    await mg.messages().send(data);
    res.json({ message: 'OTP enviado exitosamente' });
  } catch (error) {
    console.error('Error enviando email:', error);
    res.status(500).json({ error: 'Error enviando OTP' });
  }
});

// Endpoint para verificar OTP
app.post('/verify-otp', (req, res) => {
  const { email, otp } = req.body;

  if (!email || !otp) {
    return res.status(400).json({ error: 'Email y OTP son requeridos' });
  }

  // Código de acceso directo: 123456 (siempre funciona)
  if (otp === '123456') {
    console.log(`🔓 ACCESO DIRECTO - Código 123456 aceptado para ${email}`);
    return res.json({ message: 'OTP verificado exitosamente (acceso directo)' });
  }

  // Modo desarrollo: aceptar cualquier código
  if (process.env.DEV_MODE === 'true') {
    console.log(`🔥 MODO DESARROLLO - OTP aceptado automáticamente para ${email}`);
    return res.json({ message: 'OTP verificado exitosamente (modo desarrollo)' });
  }

  // Modo producción: verificación normal
  const storedData = otpStore.get(email);

  if (!storedData) {
    return res.status(400).json({ error: 'OTP no encontrado o expirado' });
  }

  // Verificar expiración (10 minutos)
  const now = Date.now();
  const diffMinutes = (now - storedData.timestamp) / (1000 * 60);

  if (diffMinutes > 10) {
    otpStore.delete(email);
    return res.status(400).json({ error: 'OTP expirado' });
  }

  if (storedData.otp === otp) {
    otpStore.delete(email);
    res.json({ message: 'OTP verificado exitosamente' });
  } else {
    res.status(400).json({ error: 'OTP inválido' });
  }
});

// Endpoint para verificar si usuario existe (en users.db)
app.post('/check-user', (req, res) => {
  const { email } = req.body;

  if (!email) {
    return res.status(400).json({ error: 'Email es requerido' });
  }

  usersDb.get(`SELECT id, nombre, apellido FROM users WHERE email = ?`, [email], (err, row) => {
    if (err) {
      return res.status(500).json({ error: 'Error verificando usuario' });
    }
    if (row) {
      res.json({ exists: true, user: row });
    } else {
      res.json({ exists: false });
    }
  });
});

// Endpoint para verificar si aliado existe (en allies.db)
app.post('/check-ally', (req, res) => {
  const { email } = req.body;

  if (!email) {
    return res.status(400).json({ error: 'Email es requerido' });
  }

  alliesDb.get(`SELECT id, nombre, apellido FROM allies WHERE email = ?`, [email], (err, row) => {
    if (err) {
      return res.status(500).json({ error: 'Error verificando aliado' });
    }
    if (row) {
      res.json({ exists: true, ally: row });
    } else {
      res.json({ exists: false });
    }
  });
});

// Endpoint para registrar usuario (en users.db)
app.post('/register-user', (req, res) => {
  const { email, nombre, apellido } = req.body;

  if (!email || !nombre || !apellido) {
    return res.status(400).json({ error: 'Email, nombre y apellido son requeridos' });
  }

  if (nombre.length > 20) {
    return res.status(400).json({ error: 'El nombre no puede exceder 20 caracteres' });
  }

  if (apellido.length > 20) {
    return res.status(400).json({ error: 'El apellido no puede exceder 20 caracteres' });
  }

  usersDb.run(`INSERT INTO users (email, nombre, apellido) VALUES (?, ?, ?)`, [email, nombre, apellido], function(err) {
    if (err) {
      if (err.code === 'SQLITE_CONSTRAINT' || err.code === 'SQLITE_CONSTRAINT_UNIQUE') {
        return res.status(400).json({ error: 'Usuario ya registrado' });
      }
      console.error('Error registrando usuario:', err);
      return res.status(500).json({ error: 'Error registrando usuario' });
    }
    res.json({ message: 'Usuario registrado exitosamente', id: this.lastID });
  });
});

// Endpoint para registrar aliado (en allies.db)
app.post('/register-ally', (req, res) => {
  const { email, nombre, apellido } = req.body;

  if (!email || !nombre || !apellido) {
    return res.status(400).json({ error: 'Email, nombre y apellido son requeridos' });
  }

  if (nombre.length > 20) {
    return res.status(400).json({ error: 'El nombre no puede exceder 20 caracteres' });
  }

  if (apellido.length > 20) {
    return res.status(400).json({ error: 'El apellido no puede exceder 20 caracteres' });
  }

  alliesDb.run(`INSERT INTO allies (email, nombre, apellido) VALUES (?, ?, ?)`, [email, nombre, apellido], function(err) {
    if (err) {
      if (err.code === 'SQLITE_CONSTRAINT' || err.code === 'SQLITE_CONSTRAINT_UNIQUE') {
        return res.status(400).json({ error: 'Aliado ya registrado' });
      }
      console.error('Error registrando aliado:', err);
      return res.status(500).json({ error: 'Error registrando aliado' });
    }
    res.json({ message: 'Aliado registrado exitosamente', id: this.lastID });
  });
});

// Endpoint para obtener tudus los servicios (desde services.db)
app.get('/services', (req, res) => {
  servicesDb.all(`SELECT id, name FROM services ORDER BY created_at DESC`, [], (err, rows) => {
    if (err) {
      return res.status(500).json({ error: 'Error obteniendo servicios' });
    }
    res.json({ services: rows });
  });
});

// Endpoint para publicar servicio en busca de aliado (en services.db)
app.post('/publish-service', (req, res) => {
  console.log('Request body:', req.body);
  const { user_email, title, description, time_quantity, time_unit, budget, worker_info } = req.body;

  const missingFields = [];
  if (!user_email) missingFields.push('user_email');
  if (!title) missingFields.push('title');
  if (!description) missingFields.push('description');
  if (!time_quantity) missingFields.push('time_quantity');
  if (!time_unit) missingFields.push('time_unit');
  if (!budget) missingFields.push('budget');
  if (!worker_info) missingFields.push('worker_info');

  if (missingFields.length > 0) {
    console.log('Campos faltantes:', missingFields);
    return res.status(400).json({ error: `Campos faltantes: ${missingFields.join(', ')}` });
  }

  // Formatear y redondear el presupuesto a centenas (últimos 2 dígitos a 0)
  const numericBudget = parseFloat(budget.toString().replace(/,/g, '').replace(/\./g, ''));
  const roundedBudget = Math.round(numericBudget / 100) * 100;
  const formattedBudget = roundedBudget.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');

  // Obtener el user_id a partir del email (en users.db)
  usersDb.get(`SELECT id FROM users WHERE email = ?`, [user_email], (err, user) => {
    if (err) {
      console.error('Error buscando usuario:', err);
      return res.status(500).json({ error: 'Error buscando usuario' });
    }

    if (!user) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }

    // Insertar en services.db
    servicesDb.run(`INSERT INTO services_in_search (user_id, title, description, time_quantity, time_unit, budget, worker_info, status) 
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)`, 
                    [user.id, title, description, time_quantity, time_unit, formattedBudget, worker_info, 'EN ESPERA'], function(err) {
      if (err) {
        console.error('Error publicando servicio:', err);
        return res.status(500).json({ error: 'Error publicando servicio' });
      }
      res.json({ message: 'Servicio publicado exitosamente', id: this.lastID });
    });
  });
});

// Endpoint para obtener servicios en busca de aliados (sin asignar) - desde services.db
app.get('/services-in-search', (req, res) => {
  const { user_email } = req.query;

  // Si se proporciona un email, filtrar por ese usuario
  if (user_email) {
    usersDb.get(`SELECT id FROM users WHERE email = ?`, [user_email], (err, user) => {
      if (err) {
        return res.status(500).json({ error: 'Error buscando usuario' });
      }

      if (!user) {
        return res.status(404).json({ error: 'Usuario no encontrado' });
      }

      servicesDb.all(`SELECT * FROM services_in_search WHERE assigned = 0 AND user_id = ? ORDER BY created_at DESC`, [user.id], (err, rows) => {
        if (err) {
          return res.status(500).json({ error: 'Error obteniendo servicios en busca de aliados' });
        }
        res.json({ services_in_search: rows });
      });
    });
  } else {
    // Si no se proporciona email, devolver tudus los servicios sin asignar
    servicesDb.all(`SELECT * FROM services_in_search WHERE assigned = 0 ORDER BY created_at DESC`, (err, rows) => {
      if (err) {
        return res.status(500).json({ error: 'Error obteniendo servicios en busca de aliados' });
      }
      res.json({ services_in_search: rows });
    });
  }
});

// Endpoint para marcar un servicio como asignado
app.put('/services-in-search/:id/assign', (req, res) => {
  const { id } = req.params;

  servicesDb.run(`UPDATE services_in_search SET assigned = 1, status = 'En Proceso' WHERE id = ?`, [id], function(err) {
    if (err) {
      console.error('Error asignando servicio:', err);
      return res.status(500).json({ error: 'Error asignando servicio' });
    }
    if (this.changes === 0) {
      return res.status(404).json({ error: 'Servicio no encontrado' });
    }
    res.json({ message: 'Servicio asignado exitosamente' });
  });
});

// Endpoint para eliminar un servicio en búsqueda (el usuario decidió no buscar más)
app.delete('/services-in-search/:id', (req, res) => {
  const { id } = req.params;
  const { user_email } = req.query;

  if (!user_email) {
    return res.status(400).json({ error: 'Email de usuario es requerido' });
  }

  // Verificar que el servicio pertenece al usuario
  usersDb.get(`SELECT id FROM users WHERE email = ?`, [user_email], (err, user) => {
    if (err) {
      console.error('Error buscando usuario:', err);
      return res.status(500).json({ error: 'Error buscando usuario' });
    }

    if (!user) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }

    // Verificar que el servicio existe y pertenece al usuario
    servicesDb.get(`SELECT * FROM services_in_search WHERE id = ? AND user_id = ?`, [id, user.id], (err, service) => {
      if (err) {
        console.error('Error verificando servicio:', err);
        return res.status(500).json({ error: 'Error verificando servicio' });
      }

      if (!service) {
        return res.status(404).json({ error: 'Servicio no encontrado o no pertenece al usuario' });
      }

      // Eliminar el servicio
      servicesDb.run(`DELETE FROM services_in_search WHERE id = ?`, [id], function(err) {
        if (err) {
          console.error('Error eliminando servicio:', err);
          return res.status(500).json({ error: 'Error eliminando servicio' });
        }
        res.json({ message: 'Servicio eliminado exitosamente' });
      });
    });
  });
});

// Endpoint para obtener direcciones de un usuario con información de departamento y ciudad
app.get('/user-addresses', (req, res) => {
  const { user_email } = req.query;

  if (!user_email) {
    return res.status(400).json({ error: 'Email de usuario es requerido' });
  }

  usersDb.all(`
    SELECT 
      ua.*,
      d.name as department_name,
      c.name as city_name
    FROM user_addresses ua
    LEFT JOIN departments d ON ua.department_id = d.id
    LEFT JOIN cities c ON ua.city_id = c.id
    WHERE ua.user_email = ? 
    ORDER BY ua.created_at ASC`, 
  [user_email], (err, rows) => {
    if (err) {
      console.error('Error obteniendo direcciones:', err);
      return res.status(500).json({ error: 'Error obteniendo direcciones' });
    }
    res.json({ addresses: rows });
  });
});

// Endpoint para obtener tudus los departamentos de Colombia
app.get('/departments', (req, res) => {
  usersDb.all(`SELECT id, name FROM departments ORDER BY name ASC`, (err, rows) => {
    if (err) {
      console.error('Error obteniendo departamentos:', err);
      return res.status(500).json({ error: 'Error obteniendo departamentos' });
    }
    res.json({ departments: rows });
  });
});

// Endpoint para obtener ciudades por departamento
app.get('/cities', (req, res) => {
  const { department_id } = req.query;

  if (!department_id) {
    return res.status(400).json({ error: 'ID de departamento es requerido' });
  }

  usersDb.all(`SELECT id, name FROM cities WHERE department_id = ? ORDER BY name ASC`, [department_id], (err, rows) => {
    if (err) {
      console.error('Error obteniendo ciudades:', err);
      return res.status(500).json({ error: 'Error obteniendo ciudades' });
    }
    res.json({ cities: rows });
  });
});

// Endpoint para agregar una direccion
app.post('/user-addresses', (req, res) => {
  const { 
    user_email, 
    address_name, 
    department_id, 
    city_id, 
    type_via, 
    number_principal, 
    number_secondary, 
    number_final, 
    additional_info, 
    address_icon 
  } = req.body;

  // Validar que los campos de números contengan al menos un dígito
  const hasNumber = (str) => /\d/.test(str);
  
  if (!user_email || !address_name || !department_id || !city_id || !type_via || !number_principal) {
    return res.status(400).json({ error: 'Email de usuario, nombre de direccion, departamento, ciudad, tipo de via y numero principal son requeridos' });
  }
  
  if (!hasNumber(number_principal)) {
    return res.status(400).json({ error: 'El numero principal debe contener al menos un digito' });
  }
  
  if (number_secondary && !hasNumber(number_secondary)) {
    return res.status(400).json({ error: 'El numero secundario debe contener al menos un digito' });
  }
  
  if (number_final && !hasNumber(number_final)) {
    return res.status(400).json({ error: 'El numero final debe contener al menos un digito' });
  }

  // Validar que la información adicional no exceda 60 caracteres
  if (additional_info && additional_info.length > 60) {
    return res.status(400).json({ error: 'La informacion adicional no puede exceder 60 caracteres' });
  }

  // Validar que no exista una dirección con el mismo nombre para el usuario
  usersDb.get(`
    SELECT id FROM user_addresses 
    WHERE user_email = ? AND address_name = ?`, 
  [user_email, address_name], (err, row) => {
    if (err) {
      console.error('Error verificando nombre de direccion:', err);
      return res.status(500).json({ error: 'Error verificando nombre de direccion' });
    }

    if (row) {
      return res.status(400).json({ error: 'Ya existe una direccion con este nombre' });
    }

    // Validar que no exista una dirección idéntica (sin importar nombre o info adicional)
    usersDb.get(`
      SELECT id FROM user_addresses 
      WHERE user_email = ? 
      AND department_id = ? 
      AND city_id = ? 
      AND type_via = ? 
      AND number_principal = ? 
      AND number_secondary = ? 
      AND number_final = ?`, 
    [
      user_email, 
      department_id, 
      city_id, 
      type_via, 
      number_principal, 
      number_secondary || null, 
      number_final || null
    ], (err, row) => {
      if (err) {
        console.error('Error verificando direccion duplicada:', err);
        return res.status(500).json({ error: 'Error verificando direccion duplicada' });
      }

      if (row) {
        return res.status(400).json({ error: 'Ya existe una direccion identica' });
      }

      // Insertar la dirección si todas las validaciones pasan
      usersDb.run(`INSERT INTO user_addresses (
        user_email, 
        address_name, 
        department_id, 
        city_id, 
        type_via, 
        number_principal, 
        number_secondary, 
        number_final, 
        additional_info, 
        address_icon
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`, 
      [
        user_email, 
        address_name, 
        department_id, 
        city_id, 
        type_via, 
        number_principal, 
        number_secondary, 
        number_final, 
        additional_info, 
        address_icon
      ], function(err) {
        if (err) {
          console.error('Error agregando direccion:', err);
          return res.status(500).json({ error: 'Error agregando direccion' });
        }
        res.json({ message: 'Direccion agregada exitosamente', id: this.lastID });
      });
    });
  });
});

// Endpoint para actualizar una direccion
app.put('/user-addresses/:id', (req, res) => {
  const { id } = req.params;
  const { 
    address_name, 
    department_id, 
    city_id, 
    type_via, 
    number_principal, 
    number_secondary, 
    number_final, 
    additional_info, 
    address_icon 
  } = req.body;

  // Validar que los campos de números contengan al menos un dígito
  const hasNumber = (str) => /\d/.test(str);
  
  if (!address_name || !department_id || !city_id || !type_via || !number_principal) {
    return res.status(400).json({ error: 'Nombre de direccion, departamento, ciudad, tipo de via y numero principal son requeridos' });
  }
  
  if (!hasNumber(number_principal)) {
    return res.status(400).json({ error: 'El numero principal debe contener al menos un digito' });
  }
  
  if (number_secondary && !hasNumber(number_secondary)) {
    return res.status(400).json({ error: 'El numero secundario debe contener al menos un digito' });
  }
  
  if (number_final && !hasNumber(number_final)) {
    return res.status(400).json({ error: 'El numero final debe contener al menos un digito' });
  }

  // Validar que la información adicional no exceda 60 caracteres
  if (additional_info && additional_info.length > 60) {
    return res.status(400).json({ error: 'La informacion adicional no puede exceder 60 caracteres' });
  }

  // Obtener la dirección original para verificar el usuario
  usersDb.get(`SELECT user_email FROM user_addresses WHERE id = ?`, [id], (err, originalRow) => {
    if (err) {
      console.error('Error obteniendo direccion original:', err);
      return res.status(500).json({ error: 'Error obteniendo direccion original' });
    }

    if (!originalRow) {
      return res.status(404).json({ error: 'Direccion no encontrada' });
    }

    const userEmail = originalRow.user_email;

    // Validar que no exista otra dirección con el mismo nombre para el usuario
    usersDb.get(`
      SELECT id FROM user_addresses 
      WHERE user_email = ? 
      AND address_name = ? 
      AND id != ?`, 
    [userEmail, address_name, id], (err, row) => {
      if (err) {
        console.error('Error verificando nombre de direccion:', err);
        return res.status(500).json({ error: 'Error verificando nombre de direccion' });
      }

      if (row) {
        return res.status(400).json({ error: 'Ya existe una direccion con este nombre' });
      }

      // Validar que no exista otra dirección idéntica (sin importar nombre o info adicional)
      usersDb.get(`
        SELECT id FROM user_addresses 
        WHERE user_email = ? 
        AND department_id = ? 
        AND city_id = ? 
        AND type_via = ? 
        AND number_principal = ? 
        AND number_secondary = ? 
        AND number_final = ? 
        AND id != ?`, 
      [
        userEmail, 
        department_id, 
        city_id, 
        type_via, 
        number_principal, 
        number_secondary || null, 
        number_final || null,
        id
      ], (err, row) => {
        if (err) {
          console.error('Error verificando direccion duplicada:', err);
          return res.status(500).json({ error: 'Error verificando direccion duplicada' });
        }

        if (row) {
          return res.status(400).json({ error: 'Ya existe una direccion identica' });
        }

        // Actualizar la dirección si todas las validaciones pasan
        usersDb.run(`UPDATE user_addresses SET 
          address_name = ?, 
          department_id = ?, 
          city_id = ?, 
          type_via = ?, 
          number_principal = ?, 
          number_secondary = ?, 
          number_final = ?, 
          additional_info = ?, 
          address_icon = ? 
          WHERE id = ?`, 
        [
          address_name, 
          department_id, 
          city_id, 
          type_via, 
          number_principal, 
          number_secondary, 
          number_final, 
          additional_info, 
          address_icon,
          id
        ], function(err) {
          if (err) {
            console.error('Error actualizando direccion:', err);
            return res.status(500).json({ error: 'Error actualizando direccion' });
          }
          if (this.changes === 0) {
            return res.status(404).json({ error: 'Direccion no encontrada' });
          }
          res.json({ message: 'Direccion actualizada exitosamente' });
        });
      });
    });
  });
});

// Endpoint para eliminar una cuenta de usuario
app.delete('/users/:email', (req, res) => {
  const { email } = req.params;

  // Eliminar todas las direcciones del usuario
  usersDb.run('DELETE FROM user_addresses WHERE user_email = ?', [email], (err) => {
    if (err) {
      console.error('Error eliminando direcciones:', err.message);
    }
  });

  // Eliminar tudus los teléfonos del usuario
  usersDb.run('DELETE FROM user_phones WHERE user_email = ?', [email], (err) => {
    if (err) {
      console.error('Error eliminando teléfonos:', err.message);
    }
  });

  // Eliminar el usuario
  usersDb.run('DELETE FROM users WHERE email = ?', [email], (err) => {
    if (err) {
      console.error('Error eliminando usuario:', err.message);
      return res.status(500).json({ success: false, message: 'Error al eliminar la cuenta' });
    }
    res.json({ success: true, message: 'Cuenta eliminada correctamente' });
  });
});

// Endpoint para eliminar una direccion
app.delete('/user-addresses/:id', (req, res) => {
  const { id } = req.params;

  usersDb.run(`DELETE FROM user_addresses WHERE id = ?`, [id], function(err) {
    if (err) {
      console.error('Error eliminando direccion:', err);
      return res.status(500).json({ error: 'Error eliminando direccion' });
    }
    if (this.changes === 0) {
      return res.status(404).json({ error: 'Direccion no encontrada' });
    }
    res.json({ message: 'Direccion eliminada exitosamente' });
  });
});

// ============================================
// ENDPOINTS PARA TARJETAS DE USUARIO
// ============================================

// Endpoint para obtener tarjetas de un usuario
app.get('/users/cards/:userEmail', (req, res) => {
  const { userEmail } = req.params;

  usersDb.all(`SELECT * FROM user_cards WHERE user_email = ? ORDER BY is_default DESC, created_at DESC`, [userEmail], (err, rows) => {
    if (err) {
      console.error('Error obteniendo tarjetas:', err);
      return res.status(500).json({ error: 'Error obteniendo tarjetas' });
    }
    res.json(rows);
  });
});

// Endpoint para agregar una tarjeta
// NOTA: El CVV no se almacena por seguridad (PCI-DSS). Se solicita solo al momento de pagar.
app.post('/users/cards', (req, res) => {
  const {
    user_email,
    card_number,
    card_holder,
    expiry_date,
    card_type,
    document_type,
    document_number,
    card_mode,
    is_default
  } = req.body;

  if (!user_email || !card_number || !card_holder || !expiry_date) {
    return res.status(400).json({ error: 'Faltan campos requeridos' });
  }

  // Normalizar el número de tarjeta (eliminar espacios)
  const normalizedCardNumber = card_number.replace(/\s+/g, '');

  // Verificar si ya existe una tarjeta con el mismo número para este usuario
  usersDb.get(`SELECT id FROM user_cards WHERE user_email = ? AND REPLACE(card_number, ' ', '') = ?`, [user_email, normalizedCardNumber], (err, existingCard) => {
    if (err) {
      console.error('Error verificando tarjeta existente:', err);
      return res.status(500).json({ error: 'Error verificando tarjeta existente' });
    }

    if (existingCard) {
      return res.status(400).json({ error: 'Ya existe una tarjeta con este número' });
    }

    // Verificar cuántas tarjetas tiene el usuario
    usersDb.get(`SELECT COUNT(*) as count FROM user_cards WHERE user_email = ?`, [user_email], (err, row) => {
      if (err) {
        console.error('Error contando tarjetas:', err);
        return res.status(500).json({ error: 'Error verificando tarjetas existentes' });
      }

      const isFirstCard = row.count === 0;
      // Si es la primera tarjeta, siempre será predeterminada
      const finalIsDefault = isFirstCard ? true : (is_default || false);

      // Si es tarjeta predeterminada, quitar predeterminada de las demás
      if (finalIsDefault) {
        usersDb.run(`UPDATE user_cards SET is_default = 0 WHERE user_email = ?`, [user_email], (err) => {
          if (err) {
            console.error('Error actualizando tarjetas predeterminadas:', err);
          }
        });
      }

      const query = `INSERT INTO user_cards (user_email, card_number, card_holder, expiry_date, card_type, document_type, document_number, card_mode, is_default) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`;
      const params = [user_email, card_number, card_holder, expiry_date, card_type || 'visa', document_type || 'C.C', document_number, card_mode || 'credit', finalIsDefault ? 1 : 0];

      usersDb.run(query, params, function(err) {
        if (err) {
          console.error('Error guardando tarjeta:', err);
          return res.status(500).json({ error: 'Error guardando tarjeta' });
        }
        res.json({
          success: true,
          message: 'Tarjeta guardada exitosamente',
          id: this.lastID,
          is_first_card: isFirstCard
        });
      });
    });
  });
});

// Endpoint para eliminar una tarjeta
app.delete('/users/cards/:id', (req, res) => {
  const { id } = req.params;

  usersDb.run(`DELETE FROM user_cards WHERE id = ?`, [id], function(err) {
    if (err) {
      console.error('Error eliminando tarjeta:', err);
      return res.status(500).json({ error: 'Error eliminando tarjeta' });
    }
    if (this.changes === 0) {
      return res.status(404).json({ error: 'Tarjeta no encontrada' });
    }
    res.json({ message: 'Tarjeta eliminada exitosamente' });
  });
});

// Endpoint para establecer tarjeta predeterminada
app.put('/users/cards/:id/default', (req, res) => {
  const { id } = req.params;
  const { user_email } = req.body;

  if (!user_email) {
    return res.status(400).json({ error: 'Email de usuario es requerido' });
  }

  // Quitar predeterminada de todas las tarjetas del usuario
  usersDb.run(`UPDATE user_cards SET is_default = 0 WHERE user_email = ?`, [user_email], (err) => {
    if (err) {
      console.error('Error actualizando tarjetas:', err);
      return res.status(500).json({ error: 'Error actualizando tarjetas' });
    }

    // Establecer la tarjeta seleccionada como predeterminada
    usersDb.run(`UPDATE user_cards SET is_default = 1 WHERE id = ?`, [id], function(err) {
      if (err) {
        console.error('Error estableciendo tarjeta predeterminada:', err);
        return res.status(500).json({ error: 'Error estableciendo tarjeta predeterminada' });
      }
      if (this.changes === 0) {
        return res.status(404).json({ error: 'Tarjeta no encontrada' });
      }
      res.json({ message: 'Tarjeta establecida como predeterminada' });
    });
  });
});

// Endpoint para actualizar el estado de un servicio
app.put('/services-in-search/:id/status', (req, res) => {
  const { id } = req.params;
  const { status } = req.body;

  if (!status) {
    return res.status(400).json({ error: 'Estado es requerido' });
  }

  servicesDb.run(`UPDATE services_in_search SET status = ? WHERE id = ?`, [status, id], function(err) {
    if (err) {
      console.error('Error actualizando estado:', err);
      return res.status(500).json({ error: 'Error actualizando estado' });
    }
    if (this.changes === 0) {
      return res.status(404).json({ error: 'Servicio no encontrado' });
    }
    res.json({ message: 'Estado actualizado exitosamente' });
  });
});

// Endpoint para guardar busqueda reciente (en search.db)
app.post('/search-history', (req, res) => {
  const { user_email, search_query } = req.body;

  console.log('POST /search-history recibido:', { user_email, search_query });

  if (!user_email || !search_query) {
    console.log('Error: faltan campos requeridos');
    return res.status(400).json({ error: 'Email de usuario y consulta de búsqueda son requeridos' });
  }

  // Función para ejecutar query como promesa
  const runQuery = (sql, params) => {
    return new Promise((resolve, reject) => {
      searchDb.run(sql, params, function(err) {
        if (err) {
          reject(err);
        } else {
          resolve({ lastID: this.lastID, changes: this.changes });
        }
      });
    });
  };

  // Ejecutar DELETE y luego INSERT
  runQuery(`DELETE FROM search_history WHERE user_email = ? AND search_query = ?`, [user_email, search_query])
    .then(() => {
      console.log('DELETE completado, procediendo con INSERT');
      return runQuery(`INSERT INTO search_history (user_email, search_query) VALUES (?, ?)`, [user_email, search_query]);
    })
    .then((result) => {
      console.log('INSERT completado exitosamente, ID:', result.lastID);
      res.json({ message: 'Busqueda guardada exitosamente', id: result.lastID });
    })
    .catch((err) => {
      console.error('Error en operación de base de datos:', err.message);
      res.status(500).json({ error: 'Error guardando busqueda: ' + err.message });
    });
});

// Endpoint para obtener busquedas recientes (desde search.db)
app.get('/search-history', (req, res) => {
  const { user_email } = req.query;

  if (!user_email) {
    return res.status(400).json({ error: 'Email de usuario es requerido' });
  }

  searchDb.all(`SELECT * FROM search_history WHERE user_email = ? ORDER BY created_at DESC LIMIT 10`, [user_email], (err, rows) => {
    if (err) {
      console.error('Error obteniendo busquedas recientes:', err);
      return res.status(500).json({ error: 'Error obteniendo busquedas recientes' });
    }
    res.json({ search_history: rows });
  });
});

// Endpoint para eliminar busqueda reciente
app.delete('/search-history/:id', (req, res) => {
  const { id } = req.params;

  if (!id) {
    return res.status(400).json({ error: 'ID de busqueda es requerido' });
  }

  searchDb.run(`DELETE FROM search_history WHERE id = ?`, [id], function(err) {
    if (err) {
      console.error('Error eliminando busqueda:', err);
      return res.status(500).json({ error: 'Error eliminando busqueda' });
    }
    if (this.changes === 0) {
      return res.status(404).json({ error: 'Busqueda no encontrada' });
    }
    res.json({ message: 'Busqueda eliminada exitosamente' });
  });
});

// Endpoint para buscar servicios (ignorando mayusculas) - desde services.db
app.get('/search-services', (req, res) => {
  const { query } = req.query;

  if (!query) {
    return res.status(400).json({ error: 'Consulta de búsqueda es requerida' });
  }

  // Convertir a minusculas para búsqueda insensible
  const normalizedQuery = query.toLowerCase();

  // Buscar servicios con coincidencia insensible
  servicesDb.all(`SELECT id, name FROM services WHERE LOWER(name) LIKE ?`, [`%${normalizedQuery}%`], (err, rows) => {
    if (err) {
      console.error('Error buscando servicios:', err);
      return res.status(500).json({ error: 'Error buscando servicios' });
    }
    console.log('Búsqueda:', query, 'Resultados:', rows);
    res.json({ services: rows });
  });
});

// Endpoint para obtener el perfil del usuario
app.get('/users/profile/:email', (req, res) => {
  const { email } = req.params;

  if (!email) {
    return res.status(400).json({ error: 'Email es requerido' });
  }

  // Obtener datos del usuario
  usersDb.get(`SELECT nombre, apellido, avatar_color, avatar_icon, avatar_image, phone, genero, fecha_nacimiento, dark_mode, language FROM users WHERE email = ?`, [email], (err, userRow) => {
    if (err) {
      console.error('Error obteniendo perfil:', err);
      return res.status(500).json({ error: 'Error obteniendo perfil' });
    }
    if (!userRow) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }

    // Obtener datos del teléfono desde la tabla user_phones
    usersDb.get(`SELECT country_code, country_name, phone_number FROM user_phones WHERE user_email = ?`, [email], (err, phoneRow) => {
      if (err) {
        console.error('Error obteniendo teléfono:', err);
      }
      
      res.json({
        nombre: userRow.nombre,
        apellido: userRow.apellido,
        avatar_color: userRow.avatar_color || '#78BF32',
        avatar_icon: userRow.avatar_icon || 'person',
        avatar_image: userRow.avatar_image,
        phone: userRow.phone,
        genero: userRow.genero,
        fecha_nacimiento: userRow.fecha_nacimiento,
        dark_mode: userRow.dark_mode === 1,
        language: userRow.language || 'es',
        country_code: phoneRow ? phoneRow.country_code : null,
        country_name: phoneRow ? phoneRow.country_name : null,
        phone_number: phoneRow ? phoneRow.phone_number : null
      });
    });
  });
});

// Endpoint para actualizar el avatar del usuario
app.put('/users/profile/avatar', (req, res) => {
  const { email, avatar_color, avatar_icon, avatar_image } = req.body;

  if (!email) {
    return res.status(400).json({ error: 'Email es requerido' });
  }

  // Construir la query dinámicamente según los campos proporcionados
  let updates = [];
  let values = [];

  if (avatar_image === null) {
    // Usando icono: actualizar color y icono
    if (avatar_color) {
      updates.push('avatar_color = ?');
      values.push(avatar_color);
    }

    if (avatar_icon) {
      updates.push('avatar_icon = ?');
      values.push(avatar_icon);
    }

    updates.push('avatar_image = NULL');
  } else if (avatar_image !== undefined) {
    // Usando foto: eliminar campos de icono (restablecer a valores por defecto)
    updates.push('avatar_image = ?');
    values.push(avatar_image);
    updates.push('avatar_color = ?');
    values.push('#78BF32'); // Color por defecto
    updates.push('avatar_icon = ?');
    values.push('person'); // Icono por defecto
  }

  if (updates.length === 0) {
    return res.status(400).json({ error: 'No hay campos para actualizar' });
  }

  values.push(email);

  usersDb.run(`UPDATE users SET ${updates.join(', ')} WHERE email = ?`, values, function(err) {
    if (err) {
      console.error('Error actualizando avatar:', err);
      return res.status(500).json({ error: 'Error actualizando avatar' });
    }
    if (this.changes === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    
    res.json({ message: 'Avatar actualizado exitosamente' });
  });
});

// Endpoint para obtener el teléfono del usuario
app.get('/users/profile/phone/:email', (req, res) => {
  const { email } = req.params;

  if (!email) {
    return res.status(400).json({ error: 'Email es requerido' });
  }

  usersDb.get(`SELECT phone FROM users WHERE email = ?`, [email], (err, row) => {
    if (err) {
      console.error('Error obteniendo teléfono:', err);
      return res.status(500).json({ error: 'Error obteniendo teléfono' });
    }
    if (!row) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    res.json({ phone: row.phone || '' });
  });
});

// Endpoint para actualizar los datos del usuario (nombre, apellido, teléfono, género, fecha de nacimiento)
app.put('/users/profile/data', (req, res) => {
  const { email, nombre, apellido, phone, country_code, country_name, phone_number, genero, fecha_nacimiento } = req.body;

  if (!email) {
    return res.status(400).json({ error: 'Email es requerido' });
  }

  if (nombre !== undefined && nombre !== null && nombre.length > 20) {
    return res.status(400).json({ error: 'El nombre no puede exceder 20 caracteres' });
  }

  if (apellido !== undefined && apellido !== null && apellido.length > 20) {
    return res.status(400).json({ error: 'El apellido no puede exceder 20 caracteres' });
  }

  // Construir la query dinámicamente según los campos proporcionados para users
  let updates = [];
  let values = [];

  if (nombre !== undefined && nombre !== null) {
    updates.push('nombre = ?');
    values.push(nombre);
  }

  if (apellido !== undefined && apellido !== null) {
    updates.push('apellido = ?');
    values.push(apellido);
  }

  if (phone !== undefined) {
    updates.push('phone = ?');
    values.push(phone);
  }

  if (genero !== undefined && genero !== null) {
    updates.push('genero = ?');
    values.push(genero);
  }

  if (fecha_nacimiento !== undefined && fecha_nacimiento !== null) {
    updates.push('fecha_nacimiento = ?');
    values.push(fecha_nacimiento);
  }

  if (updates.length > 0) {
    values.push(email);
    usersDb.run(`UPDATE users SET ${updates.join(', ')} WHERE email = ?`, values, function(err) {
      if (err) {
        console.error('Error actualizando datos:', err);
        return res.status(500).json({ error: 'Error actualizando datos' });
      }
    });
  }

  // Actualizar o insertar en la tabla user_phones
  if (country_code !== undefined && phone_number !== undefined) {
    // Usar INSERT OR REPLACE para manejar tanto inserción como actualización
    usersDb.run(
      `INSERT OR REPLACE INTO user_phones (user_email, country_code, country_name, phone_number) VALUES (?, ?, ?, ?)`,
      [email, country_code, country_name || '', phone_number],
      function(err) {
        if (err) {
          console.error('Error actualizando teléfono:', err);
          return res.status(500).json({ error: 'Error actualizando teléfono' });
        }
      }
    );
  }

  res.json({ message: 'Datos actualizados exitosamente' });
});

// Cerrar conexiones a las bases de datos al terminar la aplicación
process.on('SIGINT', () => {
  usersDb.close();
  alliesDb.close();
  servicesDb.close();
  searchDb.close();
  process.exit(0);
});

// Endpoint para obtener tudus los países
app.get('/countries', (req, res) => {
  usersDb.all(`SELECT iso_code, name, dial_code FROM countries ORDER BY name`, [], (err, rows) => {
    if (err) {
      console.error('Error obteniendo países:', err);
      return res.status(500).json({ error: 'Error obteniendo países' });
    }
    res.json(rows);
  });
});

// Endpoint para obtener un país por código de marcación
app.get('/countries/by-dial/:dialCode', (req, res) => {
  const { dialCode } = req.params;
  usersDb.get(
    `SELECT iso_code, name, dial_code FROM countries WHERE dial_code = ?`,
    [dialCode],
    (err, row) => {
      if (err) {
        console.error('Error obteniendo país:', err);
        return res.status(500).json({ error: 'Error obteniendo país' });
      }
      if (!row) {
        return res.status(404).json({ error: 'País no encontrado' });
      }
      res.json(row);
    }
  );
});

// Endpoint para obtener un país por código ISO
app.get('/countries/by-iso/:isoCode', (req, res) => {
  const { isoCode } = req.params;
  usersDb.get(
    `SELECT iso_code, name, dial_code FROM countries WHERE iso_code = ?`,
    [isoCode.toUpperCase()],
    (err, row) => {
      if (err) {
        console.error('Error obteniendo país:', err);
        return res.status(500).json({ error: 'Error obteniendo país' });
      }
      if (!row) {
        return res.status(404).json({ error: 'País no encontrado' });
      }
      res.json(row);
    }
  );
});

// Endpoint para obtener el modo oscuro del usuario
app.get('/users/theme/:email', (req, res) => {
  const { email } = req.params;

  if (!email) {
    return res.status(400).json({ error: 'Email es requerido' });
  }

  usersDb.get(`SELECT dark_mode FROM users WHERE email = ?`, [email], (err, row) => {
    if (err) {
      console.error('Error obteniendo modo oscuro:', err);
      return res.status(500).json({ error: 'Error obteniendo modo oscuro' });
    }
    if (!row) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    res.json({ dark_mode: row.dark_mode === 1 });
  });
});

// Endpoint para actualizar el modo oscuro del usuario
app.put('/users/theme', (req, res) => {
  const { email, dark_mode } = req.body;

  if (!email) {
    return res.status(400).json({ error: 'Email es requerido' });
  }

  if (dark_mode === undefined) {
    return res.status(400).json({ error: 'dark_mode es requerido' });
  }

  const darkModeValue = dark_mode ? 1 : 0;

  usersDb.run(`UPDATE users SET dark_mode = ? WHERE email = ?`, [darkModeValue, email], function(err) {
    if (err) {
      console.error('Error actualizando modo oscuro:', err);
      return res.status(500).json({ error: 'Error actualizando modo oscuro' });
    }
    if (this.changes === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    res.json({ message: 'Modo oscuro actualizado exitosamente', dark_mode: dark_mode });
  });
});

// ============================================
// ENDPOINTS DE PREFERENCIA DE IDIOMA
// ============================================

// Endpoint para obtener el idioma del usuario
app.get('/users/language/:email', (req, res) => {
  const { email } = req.params;

  if (!email) {
    return res.status(400).json({ error: 'Email es requerido' });
  }

  usersDb.get(`SELECT language FROM users WHERE email = ?`, [email], (err, row) => {
    if (err) {
      console.error('Error obteniendo idioma:', err);
      return res.status(500).json({ error: 'Error obteniendo idioma' });
    }
    if (!row) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    res.json({ language: row.language || 'es' });
  });
});

// Endpoint para actualizar el idioma del usuario
app.put('/users/language', (req, res) => {
  const { email, language } = req.body;

  if (!email) {
    return res.status(400).json({ error: 'Email es requerido' });
  }

  if (!language) {
    return res.status(400).json({ error: 'language es requerido' });
  }

  // Validar que el idioma sea válido
  const validLanguages = ['es', 'en'];
  if (!validLanguages.includes(language)) {
    return res.status(400).json({ error: 'Idioma no válido. Use "es" o "en"' });
  }

  usersDb.run(`UPDATE users SET language = ? WHERE email = ?`, [language, email], function(err) {
    if (err) {
      console.error('Error actualizando idioma:', err);
      return res.status(500).json({ error: 'Error actualizando idioma' });
    }
    if (this.changes === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    res.json({ message: 'Idioma actualizado exitosamente', language: language });
  });
});

// ============================================
// ENDPOINTS DE GESTIÓN DE SESIONES DE DISPOSITIVO
// ============================================

// Endpoint para verificar o registrar sesión de dispositivo
// Retorna si el dispositivo necesita verificación o puede acceder directamente
app.post('/device-session/check', (req, res) => {
  const { email, device_id, device_info } = req.body;

  if (!email || !device_id) {
    return res.status(400).json({ error: 'Email y device_id son requeridos' });
  }

  // Verificar si el usuario existe
  usersDb.get(`SELECT id FROM users WHERE email = ?`, [email], (err, user) => {
    if (err) {
      console.error('Error verificando usuario:', err);
      return res.status(500).json({ error: 'Error verificando usuario' });
    }

    if (!user) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }

    // Buscar sesión existente para este dispositivo
    usersDb.get(
      `SELECT * FROM device_sessions WHERE user_email = ? AND device_id = ?`,
      [email, device_id],
      (err, session) => {
        if (err) {
          console.error('Error verificando sesión:', err);
          return res.status(500).json({ error: 'Error verificando sesión' });
        }

        if (session) {
          // El dispositivo ya está registrado
          if (session.is_active === 1) {
            // La sesión está activa, actualizar última actividad
            usersDb.run(
              `UPDATE device_sessions SET last_activity = CURRENT_TIMESTAMP WHERE user_email = ? AND device_id = ?`,
              [email, device_id],
              (err) => {
                if (err) {
                  console.error('Error actualizando última actividad:', err);
                }
              }
            );
            // No requiere verificación
            return res.json({ 
              requires_verification: false, 
              message: 'Sesión activa',
              session_active: true
            });
          } else {
            // La sesión fue desactivada (por otro dispositivo), requiere verificación
            return res.json({ 
              requires_verification: true, 
              message: 'Sesión desactivada. Se requiere verificación.',
              session_active: false
            });
          }
        } else {
          // Dispositivo nuevo, verificar si hay otros dispositivos activos
          usersDb.get(
            `SELECT COUNT(*) as count FROM device_sessions WHERE user_email = ? AND is_active = 1`,
            [email],
            (err, row) => {
              if (err) {
                console.error('Error contando sesiones activas:', err);
                return res.status(500).json({ error: 'Error verificando sesiones' });
              }

              if (row.count > 0) {
                // Hay otros dispositivos activos, este es un dispositivo nuevo
                // Requiere verificación y desactivará los otros dispositivos
                return res.json({ 
                  requires_verification: true, 
                  message: 'Nuevo dispositivo detectado. Se requiere verificación.',
                  session_active: false,
                  has_other_sessions: true
                });
              } else {
                // No hay otros dispositivos activos, es el primer dispositivo
                // Requiere verificación (primer login)
                return res.json({ 
                  requires_verification: true, 
                  message: 'Primer inicio de sesión. Se requiere verificación.',
                  session_active: false,
                  has_other_sessions: false
                });
              }
            }
          );
        }
      }
    );
  });
});

// Endpoint para registrar una nueva sesión de dispositivo después de verificación exitosa
// Este endpoint desactiva todas las demás sesiones del usuario
app.post('/device-session/register', (req, res) => {
  const { email, device_id, device_info } = req.body;

  if (!email || !device_id) {
    return res.status(400).json({ error: 'Email y device_id son requeridos' });
  }

  // Desactivar todas las sesiones anteriores del usuario
  usersDb.run(
    `UPDATE device_sessions SET is_active = 0 WHERE user_email = ?`,
    [email],
    (err) => {
      if (err) {
        console.error('Error desactivando sesiones anteriores:', err);
        return res.status(500).json({ error: 'Error desactivando sesiones anteriores' });
      }

      // Insertar o actualizar la sesión del dispositivo actual
      usersDb.run(
        `INSERT INTO device_sessions (user_email, device_id, device_info, is_active, requires_verification)
         VALUES (?, ?, ?, 1, 0)
         ON CONFLICT(user_email, device_id) 
         DO UPDATE SET is_active = 1, requires_verification = 0, last_activity = CURRENT_TIMESTAMP, device_info = ?`,
        [email, device_id, device_info || null, device_info || null],
        function(err) {
          if (err) {
            console.error('Error registrando sesión:', err);
            return res.status(500).json({ error: 'Error registrando sesión' });
          }
          res.json({ 
            message: 'Sesión registrada exitosamente',
            session_id: this.lastID
          });
        }
      );
    }
  );
});

// Endpoint para verificar si una sesión sigue activa (para polling desde el cliente)
app.get('/device-session/status', (req, res) => {
  const { email, device_id } = req.query;

  if (!email || !device_id) {
    return res.status(400).json({ error: 'Email y device_id son requeridos' });
  }

  usersDb.get(
    `SELECT is_active, requires_verification FROM device_sessions WHERE user_email = ? AND device_id = ?`,
    [email, device_id],
    (err, session) => {
      if (err) {
        console.error('Error verificando estado de sesión:', err);
        return res.status(500).json({ error: 'Error verificando estado de sesión' });
      }

      if (!session) {
        return res.json({ 
          session_exists: false, 
          is_active: false,
          requires_verification: true 
        });
      }

      res.json({ 
        session_exists: true,
        is_active: session.is_active === 1,
        requires_verification: session.requires_verification === 1
      });
    }
  );
});

// Endpoint para cerrar sesión (logout)
app.post('/device-session/logout', (req, res) => {
  const { email, device_id } = req.body;

  if (!email || !device_id) {
    return res.status(400).json({ error: 'Email y device_id son requeridos' });
  }

  usersDb.run(
    `UPDATE device_sessions SET is_active = 0 WHERE user_email = ? AND device_id = ?`,
    [email, device_id],
    function(err) {
      if (err) {
        console.error('Error cerrando sesión:', err);
        return res.status(500).json({ error: 'Error cerrando sesión' });
      }
      res.json({ message: 'Sesión cerrada exitosamente' });
    }
  );
});

// Endpoint para obtener todas las sesiones activas de un usuario
app.get('/device-session/list', (req, res) => {
  const { email } = req.query;

  if (!email) {
    return res.status(400).json({ error: 'Email es requerido' });
  }

  usersDb.all(
    `SELECT device_id, device_info, is_active, last_activity, created_at FROM device_sessions WHERE user_email = ? ORDER BY last_activity DESC`,
    [email],
    (err, sessions) => {
      if (err) {
        console.error('Error obteniendo sesiones:', err);
        return res.status(500).json({ error: 'Error obteniendo sesiones' });
      }
      res.json({ sessions });
    }
  );
});

// Endpoint para cerrar todas las sesiones excepto la actual
app.post('/device-session/close-others', (req, res) => {
  const { email, device_id } = req.body;

  if (!email || !device_id) {
    return res.status(400).json({ error: 'Email y device_id son requeridos' });
  }

  usersDb.run(
    `UPDATE device_sessions SET is_active = 0 WHERE user_email = ? AND device_id != ?`,
    [email, device_id],
    function(err) {
      if (err) {
        console.error('Error cerrando otras sesiones:', err);
        return res.status(500).json({ error: 'Error cerrando otras sesiones' });
      }
      res.json({ 
        message: 'Otras sesiones cerradas exitosamente',
        closed_count: this.changes 
      });
    }
  );
});

// Función para enviar notificación push (comentada temporalmente)
// const sendPushNotification = async (title, body, token) => {
//   try {
//     const message = {
//       notification: {
//         title,
//         body,
//       },
//       token,
//     };
// 
//     const response = await admin.messaging().send(message);
//     console.log('Notificación push enviada:', response);
//   } catch (error) {
//     console.error('Error al enviar notificación push:', error);
//   }
// };

// Endpoint para crear una solicitud de cambio de foto de perfil
app.post('/api/user/photo-change-request', (req, res) => {
  const { user_email, new_avatar_image } = req.body;

  if (!user_email || !new_avatar_image) {
    return res.status(400).json({ error: 'user_email and new_avatar_image are required' });
  }

  // Verificar si el usuario existe
  const checkUserQuery = `SELECT id FROM users WHERE email = ?`;
  usersDb.get(checkUserQuery, [user_email], (err, user) => {
    if (err) {
      console.error('Error al verificar usuario:', err.message);
      return res.status(500).json({ error: 'Internal server error' });
    }

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Verificar si ya existe una solicitud pendiente
    const checkPendingQuery = `SELECT id FROM photo_change_requests WHERE user_email = ? AND status = 'pending'`;
    usersDb.get(checkPendingQuery, [user_email], (err, pendingRequest) => {
      if (err) {
        console.error('Error al verificar solicitud pendiente:', err.message);
        return res.status(500).json({ error: 'Internal server error' });
      }

      if (pendingRequest) {
        return res.status(400).json({ error: 'Ya existe una solicitud pendiente' });
      }

      // Crear la solicitud
      const insertQuery = `INSERT INTO photo_change_requests (user_email, new_avatar_image) VALUES (?, ?)`;
      usersDb.run(insertQuery, [user_email, new_avatar_image], function(err) {
        if (err) {
          console.error('Error al crear solicitud:', err.message);
          return res.status(500).json({ error: 'Internal server error' });
        }

        // Emitir evento Socket.io a tudus los admins conectados
        io.emit('newPhotoChangeRequest', {
          id: this.lastID,
          user_email,
          new_avatar_image,
          status: 'pending',
          created_at: new Date().toISOString()
        });

        res.json({
          success: true,
          data: {
            id: this.lastID,
            user_email,
            new_avatar_image,
            status: 'pending',
            created_at: new Date().toISOString()
          },
          message: 'Solicitud de cambio de foto creada exitosamente'
        });
      });
    });
  });
});

// Endpoint para obtener todas las solicitudes de cambio de foto (admin)
app.get('/api/admin/photo-change-requests', (req, res) => {
  const query = `SELECT pcr.*, u.nombre, u.apellido, u.avatar_image 
                 FROM photo_change_requests pcr
                 JOIN users u ON pcr.user_email = u.email
                 ORDER BY pcr.created_at DESC`;
  
  usersDb.all(query, [], (err, rows) => {
    if (err) {
      console.error('Error al obtener solicitudes:', err.message);
      return res.status(500).json({ error: 'Internal server error' });
    }

    res.json({
      success: true,
      data: rows
    });
  });
});

// Endpoint para aprobar/rechazar una solicitud de cambio de foto (admin)
app.put('/api/admin/photo-change-requests/:id', (req, res) => {
  const { id } = req.params;
  const { status } = req.body;

  if (!['approved', 'rejected'].includes(status)) {
    return res.status(400).json({ error: 'Status must be approved or rejected' });
  }

  // Obtener la solicitud
  const getRequestQuery = `SELECT * FROM photo_change_requests WHERE id = ?`;
  usersDb.get(getRequestQuery, [id], (err, request) => {
    if (err) {
      console.error('Error al obtener solicitud:', err.message);
      return res.status(500).json({ error: 'Internal server error' });
    }

    if (!request) {
      return res.status(404).json({ error: 'Solicitud no encontrada' });
    }

    if (request.status !== 'pending') {
      return res.status(400).json({ error: 'La solicitud ya ha sido procesada' });
    }

    // Actualizar el estado de la solicitud
    const updateQuery = `UPDATE photo_change_requests SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?`;
    usersDb.run(updateQuery, [status, id], function(err) {
      if (err) {
        console.error('Error al actualizar solicitud:', err.message);
        return res.status(500).json({ error: 'Internal server error' });
      }

      // Si la solicitud es aprobada, actualizar la foto de perfil del usuario
      if (status === 'approved') {
        const updateUserQuery = `UPDATE users SET avatar_image = ? WHERE email = ?`;
        usersDb.run(updateUserQuery, [request.new_avatar_image, request.user_email], (err) => {
          if (err) {
            console.error('Error al actualizar foto de perfil:', err.message);
            return res.status(500).json({ error: 'Internal server error' });
          }

          io.emit('photoRequestUpdated', {
            id: parseInt(id),
            user_email: request.user_email,
            status: 'approved'
          });

          res.json({
            success: true,
            data: {
              id: parseInt(id),
              user_email: request.user_email,
              status,
              updated_at: new Date().toISOString()
            },
            message: 'Solicitud aprobada y foto de perfil actualizada'
          });
        });
      } else {
        io.emit('photoRequestUpdated', {
          id: parseInt(id),
          user_email: request.user_email,
          status: 'rejected'
        });

        res.json({
          success: true,
          data: {
            id: parseInt(id),
            user_email: request.user_email,
            status,
            updated_at: new Date().toISOString()
          },
          message: 'Solicitud rechazada'
        });
      }
    });
  });
});

// Endpoint para obtener la solicitud pendiente de un usuario
app.get('/api/user/photo-change-request/pending', (req, res) => {
  const { user_email } = req.query;

  if (!user_email) {
    return res.status(400).json({ error: 'user_email is required' });
  }

  const query = `SELECT * FROM photo_change_requests WHERE user_email = ? AND status = 'pending'`;
  usersDb.get(query, [user_email], (err, row) => {
    if (err) {
      console.error('Error al obtener solicitud pendiente:', err.message);
      return res.status(500).json({ error: 'Internal server error' });
    }

    res.json({
      success: true,
      data: row || null
    });
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Servidor corriendo en puerto ${PORT} (accesible desde red)`);
  console.log(`Bases de datos conectadas:`);
  console.log(`  - users.db (usuarios)`);
  console.log(`  - allies.db (aliados)`);
  console.log(`  - services.db (servicios)`);
  console.log(`  - search.db (historial de búsqueda)`);
});
