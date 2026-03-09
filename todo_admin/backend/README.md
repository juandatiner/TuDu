# ToDo Admin Backend

Backend for the ToDo Admin app.

## Installation

```bash
npm install
```

## Initialization

```bash
npm run init-db
```

This will create the `admins.db` database and insert a default admin user:
- Username: admin
- Password: 123
- Email: admin@todoapp.com
- Name: Administrador Principal

## Running the Server

### Development mode with nodemon

```bash
npm run dev
```

### Production mode

```bash
npm start
```

## Configuration

Create a `.env` file based on `.env.example` and modify the configuration if needed.

## Server Configuration

- **Port**: 3003
- **CORS**: Enabled
- **Body Parser**: JSON (50mb limit)
- **Database**: SQLite (`admins.db`)

## API Endpoints

### Health Check
**GET /**
```json
{
  "message": "ToDo Admin Backend is running"
}
```

### Admin Login
**POST /api/admin/login**
```json
{
  "username": "admin",
  "password": "123"
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "id": 1,
    "username": "admin",
    "email": "admin@todoapp.com",
    "name": "Administrador Principal",
    "role": "admin"
  }
}
```

### Get All Admins
**GET /api/admins**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "username": "admin",
      "email": "admin@todoapp.com",
      "name": "Administrador Principal",
      "role": "admin",
      "created_at": "2026-03-09T19:25:05.000Z",
      "updated_at": "2026-03-09T19:25:05.000Z"
    }
  ]
}
```

### Create Admin
**POST /api/admins**
```json
{
  "username": "newadmin",
  "password": "123456",
  "email": "newadmin@todoapp.com",
  "name": "Nuevo Administrador",
  "role": "admin"
}
```

### Update Admin
**PUT /api/admins/:id**
```json
{
  "username": "updatedadmin",
  "email": "updated@todoapp.com",
  "name": "Administrador Actualizado",
  "role": "admin"
}
```

### Delete Admin
**DELETE /api/admins/:id**

### Change Password
**PUT /api/admins/:id/change-password**
```json
{
  "currentPassword": "123",
  "newPassword": "newpassword"
}
```

## Database Structure

### admins Table
| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER | Primary key (auto-increment) |
| username | TEXT | Unique username |
| password | TEXT | Password (plain text - for development purposes) |
| email | TEXT | Unique email address |
| name | TEXT | Full name |
| role | TEXT | Role (default: admin) |
| created_at | DATETIME | Creation timestamp |
| updated_at | DATETIME | Last update timestamp |

## Future Features

- User authentication with JWT
- Password hashing
- Role-based access control
- Configuration management
- Data analytics
- User management
