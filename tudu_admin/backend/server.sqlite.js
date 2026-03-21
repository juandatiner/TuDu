const express = require('express');
const cors = require('cors');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3002;

app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Ruta base de las bases de datos
const DB_PATH = path.join(__dirname, '../../databases');
const adminsDb = new sqlite3.Database(path.join(DB_PATH, 'admins.db'), (err) => {
  if (err) {
    console.error('Error abriendo admins.db:', err.message);
  } else {
    console.log('Conectado a admins.db');
  }
});

const usersDb = new sqlite3.Database(path.join(DB_PATH, 'users.db'), (err) => {
  if (err) {
    console.error('Error abriendo users.db:', err.message);
  } else {
    console.log('Conectado a users.db');
  }
});

const servicesDb = new sqlite3.Database(path.join(DB_PATH, 'services.db'), (err) => {
  if (err) {
    console.error('Error abriendo services.db:', err.message);
  } else {
    console.log('Conectado a services.db');
  }
});

// Rutas
app.get('/', (req, res) => {
  res.json({ message: 'TuDu Admin Backend is running' });
});

// Login de admin
app.post('/api/admin/login', (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ error: 'Username and password are required' });
  }

  const query = `SELECT * FROM admins WHERE username = ? AND password = ?`;
  adminsDb.get(query, [username, password], (err, row) => {
    if (err) {
      console.error('Error al buscar admin:', err.message);
      return res.status(500).json({ error: 'Internal server error' });
    }

    if (row) {
      res.json({
        success: true,
        data: {
          id: row.id,
          username: row.username,
          email: row.email,
          name: row.name,
          role: row.role
        }
      });
    } else {
      res.status(401).json({ error: 'Invalid username or password' });
    }
  });
});

// Obtener tudus los admins
app.get('/api/admins', (req, res) => {
  const query = `SELECT id, username, email, name, role, created_at, updated_at FROM admins`;
  adminsDb.all(query, [], (err, rows) => {
    if (err) {
      console.error('Error al obtener admins:', err.message);
      return res.status(500).json({ error: 'Internal server error' });
    }
    res.json({ success: true, data: rows });
  });
});

// Crear un nuevo admin
app.post('/api/admins', (req, res) => {
  const { username, password, email, name, role = 'admin' } = req.body;

  if (!username || !password || !name) {
    return res.status(400).json({ error: 'Username, password and name are required' });
  }

  const query = `INSERT INTO admins (username, password, email, name, role) VALUES (?, ?, ?, ?, ?)`;
  adminsDb.run(query, [username, password, email, name, role], function(err) {
    if (err) {
      console.error('Error al crear admin:', err.message);
      if (err.message.includes('UNIQUE')) {
        return res.status(400).json({ error: 'Username or email already exists' });
      }
      return res.status(500).json({ error: 'Internal server error' });
    }

    res.json({
      success: true,
      data: {
        id: this.lastID,
        username,
        email,
        name,
        role
      }
    });
  });
});

// Actualizar un admin
app.put('/api/admins/:id', (req, res) => {
  const { id } = req.params;
  const { username, email, name, role } = req.body;

  const query = `UPDATE admins SET username = ?, email = ?, name = ?, role = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?`;
  adminsDb.run(query, [username, email, name, role, id], function(err) {
    if (err) {
      console.error('Error al actualizar admin:', err.message);
      if (err.message.includes('UNIQUE')) {
        return res.status(400).json({ error: 'Username or email already exists' });
      }
      return res.status(500).json({ error: 'Internal server error' });
    }

    if (this.changes === 0) {
      return res.status(404).json({ error: 'Admin not found' });
    }

    res.json({
      success: true,
      data: {
        id: parseInt(id),
        username,
        email,
        name,
        role
      }
    });
  });
});

// Eliminar un admin
app.delete('/api/admins/:id', (req, res) => {
  const { id } = req.params;

  const query = `DELETE FROM admins WHERE id = ?`;
  adminsDb.run(query, [id], function(err) {
    if (err) {
      console.error('Error al eliminar admin:', err.message);
      return res.status(500).json({ error: 'Internal server error' });
    }

    if (this.changes === 0) {
      return res.status(404).json({ error: 'Admin not found' });
    }

    res.json({ success: true, message: 'Admin deleted successfully' });
  });
});

// Cambiar contraseña de admin
app.put('/api/admins/:id/change-password', (req, res) => {
  const { id } = req.params;
  const { currentPassword, newPassword } = req.body;

  if (!currentPassword || !newPassword) {
    return res.status(400).json({ error: 'Current and new passwords are required' });
  }

  const checkPasswordQuery = `SELECT * FROM admins WHERE id = ? AND password = ?`;
  adminsDb.get(checkPasswordQuery, [id, currentPassword], (err, row) => {
    if (err) {
      console.error('Error al verificar contraseña:', err.message);
      return res.status(500).json({ error: 'Internal server error' });
    }

    if (!row) {
      return res.status(401).json({ error: 'Current password is incorrect' });
    }

    const updatePasswordQuery = `UPDATE admins SET password = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?`;
    adminsDb.run(updatePasswordQuery, [newPassword, id], function(err) {
      if (err) {
        console.error('Error al actualizar contraseña:', err.message);
        return res.status(500).json({ error: 'Internal server error' });
      }

      res.json({ success: true, message: 'Password changed successfully' });
    });
  });
});

// Endpoints para aliados (users)

// Enviar OTP
app.post('/send-otp', (req, res) => {
  const { email } = req.body;
  
  if (!email) {
    return res.status(400).json({ error: 'Email is required' });
  }
  
  // Simulación de envío de OTP
  console.log(`OTP sent to ${email}`);
  
  res.json({ success: true, message: 'OTP sent successfully' });
});

// Verificar OTP
app.post('/verify-otp', (req, res) => {
  const { email, otp } = req.body;
  
  if (!email || !otp) {
    return res.status(400).json({ error: 'Email and OTP are required' });
  }
  
  // Verificación simple (si el OTP es '123456')
  if (otp === '123456') {
    res.json({ success: true, message: 'OTP verified successfully' });
  } else {
    res.status(400).json({ error: 'Invalid OTP' });
  }
});

// Verificar si aliado existe
app.post('/check-ally', (req, res) => {
  const { email } = req.body;
  
  if (!email) {
    return res.status(400).json({ error: 'Email is required' });
  }
  
  // Consulta a users.db para verificar si el email existe
  const query = `SELECT * FROM users WHERE email = ?`;
  usersDb.get(query, [email], (err, row) => {
    if (err) {
      console.error('Error checking user:', err.message);
      return res.status(500).json({ error: 'Internal server error' });
    }
    
    res.json({ success: true, exists: !!row });
  });
});

// Registrar aliado
app.post('/register-ally', (req, res) => {
  const { email, nombre, apellido } = req.body;
  
  if (!email || !nombre || !apellido) {
    return res.status(400).json({ error: 'Email, nombre, and apellido are required' });
  }
  
  // Consultar si el email ya existe
  const checkQuery = `SELECT * FROM users WHERE email = ?`;
  usersDb.get(checkQuery, [email], (err, row) => {
    if (err) {
      console.error('Error checking user:', err.message);
      return res.status(500).json({ error: 'Internal server error' });
    }
    
    if (row) {
      return res.status(400).json({ error: 'Email already registered' });
    }
    
    // Insertar nuevo usuario
    const insertQuery = `INSERT INTO users (email, nombre, apellido, created_at, updated_at) VALUES (?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)`;
    usersDb.run(insertQuery, [email, nombre, apellido], function(err) {
      if (err) {
        console.error('Error registering user:', err.message);
        return res.status(500).json({ error: 'Internal server error' });
      }
      
      res.json({
        success: true,
        data: {
          id: this.lastID,
          email,
          nombre,
          apellido
        }
      });
    });
  });
});

// Obtener servicios
app.get('/services', (req, res) => {
  const query = `SELECT * FROM services`;
  servicesDb.all(query, [], (err, rows) => {
    if (err) {
      console.error('Error retrieving services:', err.message);
      return res.status(500).json({ error: 'Internal server error' });
    }
    
    res.json({ success: true, data: rows });
  });
});

const server = app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});

// Manejo de señales para cerrar el servidor correctamente
process.on('SIGINT', () => {
  console.log('\nShutting down server...');
  server.close(() => {
    console.log('Server closed');
    adminsDb.close((err) => {
      if (err) {
        console.error('Error closing database:', err.message);
      } else {
        console.log('Database connection closed');
      }
      process.exit(0);
    });
  });
});

process.on('SIGTERM', () => {
  console.log('\nShutting down server...');
  server.close(() => {
    console.log('Server closed');
    adminsDb.close((err) => {
      if (err) {
        console.error('Error closing database:', err.message);
      } else {
        console.log('Database connection closed');
      }
      process.exit(0);
    });
  });
});
