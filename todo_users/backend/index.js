 const express = require('express');
const cors = require('cors');
const mailgun = require('mailgun-js');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');
// const multer = require('multer');
const fs = require('fs');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

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
              'La Guajira', 'Magdalena', 'Meta', 'Nariño', 'Putumayo', 'Quindío', 
              'Risaralda', 'San Andrés y Providencia', 'Santander', 'Sucre', 
              'Tolima', 'Valle del Cauca', 'Vaupés', 'Vichada'
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
        // Insertar ciudades principales si la tabla está vacía
        usersDb.get(`SELECT COUNT(*) as count FROM cities`, (err, row) => {
          if (err) {
            console.error('Error contando ciudades:', err.message);
          } else if (row.count === 0) {
            const cities = [
              // Antioquia
              {'name': 'Medellín', 'department': 'Antioquia'},
              {'name': 'Bello', 'department': 'Antioquia'},
              {'name': 'Itagüí', 'department': 'Antioquia'},
              {'name': 'Envigado', 'department': 'Antioquia'},
              // Bogotá
              {'name': 'Bogotá', 'department': 'Bogotá'},
              // Atlántico
              {'name': 'Barranquilla', 'department': 'Atlántico'},
              // Valle del Cauca
              {'name': 'Cali', 'department': 'Valle del Cauca'},
              // Bolívar
              {'name': 'Cartagena', 'department': 'Bolívar'},
              // Cesar
              {'name': 'Valledupar', 'department': 'Cesar'},
              // Magdalena
              {'name': 'Santa Marta', 'department': 'Magdalena'},
              // Cundinamarca
              {'name': 'Soacha', 'department': 'Cundinamarca'},
              {'name': 'Zipaquirá', 'department': 'Cundinamarca'},
              {'name': 'Facatativá', 'department': 'Cundinamarca'},
              // Santander
              {'name': 'Bucaramanga', 'department': 'Santander'},
              {'name': 'Floridablanca', 'department': 'Santander'},
              {'name': 'Piedecuesta', 'department': 'Santander'},
              // Nariño
              {'name': 'Pasto', 'department': 'Nariño'},
              // Norte de Santander
              {'name': 'Cúcuta', 'department': 'Norte de Santander'},
              // Meta
              {'name': 'Villavicencio', 'department': 'Meta'},
              // Huila
              {'name': 'Neiva', 'department': 'Huila'},
              // Caldas
              {'name': 'Manizales', 'department': 'Caldas'},
              // Risaralda
              {'name': 'Pereira', 'department': 'Risaralda'},
              // Quindío
              {'name': 'Armenia', 'department': 'Quindío'},
              // Tolima
              {'name': 'Ibagué', 'department': 'Tolima'},
              // Boyacá
              {'name': 'Tunja', 'department': 'Boyacá'},
              // Cauca
              {'name': 'Popayán', 'department': 'Cauca'},
              // Casanare
              {'name': 'Yopal', 'department': 'Casanare'},
              // Arauca
              {'name': 'Arauca', 'department': 'Arauca'},
              // Vaupés
              {'name': 'Mitú', 'department': 'Vaupés'},
              // Vichada
              {'name': 'Puerto Carreño', 'department': 'Vichada'},
              // Guainía
              {'name': 'Puerto Inírida', 'department': 'Guainía'},
              // Guaviare
              {'name': 'San José del Guaviare', 'department': 'Guaviare'},
              // Putumayo
              {'name': 'Mocoa', 'department': 'Putumayo'},
              // Caquetá
              {'name': 'Florencia', 'department': 'Caquetá'},
              // Amazonas
              {'name': 'Leticia', 'department': 'Amazonas'},
              // Chocó
              {'name': 'Quibdó', 'department': 'Chocó'},
              // La Guajira
              {'name': 'Riohacha', 'department': 'La Guajira'},
              // Sucre
              {'name': 'Sincelejo', 'department': 'Sucre'},
              // Córdoba
              {'name': 'Montería', 'department': 'Córdoba'},
              // San Andrés y Providencia
              {'name': 'San Andrés', 'department': 'San Andrés y Providencia'}
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
      number_principal INTEGER,
      number_secondary INTEGER,
      number_final INTEGER,
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
    from: 'Tu App ToDo <noreply@tuapp.com>',
    to: email,
    subject: 'Código de verificación ToDo',
    text: `Tu código de verificación es: ${otp}. Este código expira en 10 minutos.`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #78BF32;">Código de verificación ToDo</h2>
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

// Endpoint para obtener todos los servicios (desde services.db)
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
    // Si no se proporciona email, devolver todos los servicios sin asignar
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

// Endpoint para obtener todos los departamentos de Colombia
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

  if (!user_email || !address_name || !department_id || !city_id || !type_via || !number_principal) {
    return res.status(400).json({ error: 'Email de usuario, nombre de direccion, departamento, ciudad, tipo de via y numero principal son requeridos' });
  }

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

  if (!address_name || !department_id || !city_id || !type_via || !number_principal) {
    return res.status(400).json({ error: 'Nombre de direccion, departamento, ciudad, tipo de via y numero principal son requeridos' });
  }

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
  usersDb.get(`SELECT nombre, apellido, avatar_color, avatar_icon, avatar_image, phone FROM users WHERE email = ?`, [email], (err, userRow) => {
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

  if (avatar_color) {
    updates.push('avatar_color = ?');
    values.push(avatar_color);
  }

  if (avatar_icon) {
    updates.push('avatar_icon = ?');
    values.push(avatar_icon);
  }

  if (avatar_image !== undefined) {
    updates.push('avatar_image = ?');
    values.push(avatar_image);
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

// Endpoint para actualizar los datos del usuario (nombre, apellido, teléfono)
app.put('/users/profile/data', (req, res) => {
  const { email, nombre, apellido, phone, country_code, country_name, phone_number } = req.body;

  if (!email) {
    return res.status(400).json({ error: 'Email es requerido' });
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

// Endpoint para obtener todos los países
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

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Servidor corriendo en puerto ${PORT} (accesible desde red)`);
  console.log(`Bases de datos conectadas:`);
  console.log(`  - users.db (usuarios)`);
  console.log(`  - allies.db (aliados)`);
  console.log(`  - services.db (servicios)`);
  console.log(`  - search.db (historial de búsqueda)`);
});
