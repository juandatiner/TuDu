# Informe de Normalización de Bases de Datos

## Descripción del Proyecto
Este informe documenta el proceso de normalización de las bases de datos para la aplicación Todo Allies, separando cada tipo de datos en bases de datos dedicadas según la funcionalidad.

## Resultado Final
Las bases de datos se han estructurado de forma normalizada para separar claramente las responsabilidades de cada entidad:

### 1. users.db - Base de Datos de Usuarios
**Contenido:** Usuarios con rol "user" (clientes)
- **Tabla:** users
- **Columnas:**
  - id (INTEGER PRIMARY KEY AUTOINCREMENT)
  - email (TEXT UNIQUE NOT NULL)
  - nombre (TEXT NOT NULL)
  - apellido (TEXT NOT NULL)
  - role (TEXT DEFAULT "user")
  - created_at (DATETIME DEFAULT CURRENT_TIMESTAMP)
- **Registros:** 2

### 2. allies.db - Base de Datos de Aliados/Empresas
**Contenido:** Aliados con rol "ally" (proveedores de servicios)
- **Tabla:** allies
- **Columnas:**
  - id (INTEGER PRIMARY KEY AUTOINCREMENT)
  - email (TEXT UNIQUE NOT NULL)
  - nombre (TEXT NOT NULL)
  - apellido (TEXT NOT NULL)
  - role (TEXT DEFAULT "ally")
  - created_at (DATETIME DEFAULT CURRENT_TIMESTAMP)
- **Registros:** 0

### 3. services.db - Base de Datos de Servicios
**Contenido:** Servicios y relaciones con aliados
- **Tabla 1:** services
  - **Columnas:**
    - id (INTEGER PRIMARY KEY AUTOINCREMENT)
    - name (TEXT NOT NULL)
    - created_at (DATETIME DEFAULT CURRENT_TIMESTAMP)
    - description (TEXT)
  - **Registros:** 10
  - **Ejemplos:** "Servicio de hogar", "Reparaciones eléctricas", "Limpieza"

- **Tabla 2:** ally_services
  - **Columnas:**
    - id (INTEGER PRIMARY KEY AUTOINCREMENT)
    - ally_id (INTEGER)
    - service_id (INTEGER)
    - created_at (DATETIME DEFAULT CURRENT_TIMESTAMP)
    - FOREIGN KEY (ally_id) REFERENCES allies(id) ON DELETE CASCADE
    - FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE CASCADE
    - UNIQUE(ally_id, service_id)
  - **Registros:** 0

- **Tabla 3:** services_in_search
  - **Columnas:**
    - id (INTEGER PRIMARY KEY AUTOINCREMENT)
    - title (TEXT NOT NULL)
    - description (TEXT NOT NULL)
    - time_quantity (INTEGER NOT NULL)
    - time_unit (TEXT NOT NULL)
    - budget (TEXT NOT NULL)
    - worker_info (TEXT NOT NULL)
    - additional_info (TEXT NOT NULL)
    - status (TEXT DEFAULT 'EN ESPERA')
    - assigned (BOOLEAN DEFAULT 0)
    - created_at (DATETIME DEFAULT CURRENT_TIMESTAMP)
  - **Registros:** 1 (servicio de "Cáma para perros")

### 4. search.db - Base de Datos de Búsquedas
**Contenido:** Servicios en búsqueda, historial de búsqueda y mensajes
- **Tabla 1:** services_in_search
  - **Columnas:**
    - id (INTEGER PRIMARY KEY AUTOINCREMENT)
    - user_id (INTEGER)
    - title (TEXT NOT NULL)
    - description (TEXT NOT NULL)
    - time_quantity (INTEGER NOT NULL)
    - time_unit (TEXT NOT NULL)
    - budget (TEXT NOT NULL)
    - worker_info (TEXT NOT NULL)
    - additional_info (TEXT NOT NULL)
    - status (TEXT DEFAULT 'EN ESPERA')
    - assigned (BOOLEAN DEFAULT 0)
    - ally_id (INTEGER)
    - created_at (DATETIME DEFAULT CURRENT_TIMESTAMP)
    - FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
    - FOREIGN KEY (ally_id) REFERENCES allies(id) ON DELETE SET NULL
  - **Registros:** 0

- **Tabla 2:** search_history
  - **Columnas:**
    - id (INTEGER PRIMARY KEY AUTOINCREMENT)
    - user_email (TEXT NOT NULL)
    - search_query (TEXT NOT NULL)
    - created_at (DATETIME DEFAULT CURRENT_TIMESTAMP)
  - **Registros:** 21

- **Tabla 3:** messages
  - **Columnas:**
    - id (INTEGER PRIMARY KEY AUTOINCREMENT)
    - sender_id (INTEGER)
    - receiver_id (INTEGER)
    - sender_role (TEXT NOT NULL)
    - receiver_role (TEXT NOT NULL)
    - service_in_search_id (INTEGER)
    - message (TEXT NOT NULL)
    - read (BOOLEAN DEFAULT 0)
    - created_at (DATETIME DEFAULT CURRENT_TIMESTAMP)
    - FOREIGN KEY (service_in_search_id) REFERENCES services_in_search(id) ON DELETE CASCADE
  - **Registros:** 0

### 5. transactions.db - Base de Datos de Transacciones
**Contenido:** Transacciones entre usuarios y aliados
- **Tabla:** transactions
- **Columnas:**
  - id (INTEGER PRIMARY KEY AUTOINCREMENT)
  - user_id (INTEGER)
  - ally_id (INTEGER)
  - service_in_search_id (INTEGER)
  - amount REAL NOT NULL
  - status TEXT DEFAULT 'pending'
  - created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  - FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
  - FOREIGN KEY (ally_id) REFERENCES allies(id) ON DELETE SET NULL
  - FOREIGN KEY (service_in_search_id) REFERENCES services_in_search(id) ON DELETE SET NULL
- **Registros:** 0

## Proceso Realizado
1. **Creación de script de normalización:** `normalize_databases.js`
2. **Actualización de tablas existentes:** `update_existing_tables.js` para agregar columnas faltantes
3. **Migración de datos:** Transferencia de datos de la base de datos original a las nuevas bases de datos
4. **Verificación:** Ejecución de `examine_db_structures.js` para confirmar la estructura
5. **Eliminación de la base de datos original:** La base de datos todo.db se ha eliminado ya que no es necesaria

## Notas Importantes
- La normalización separa claramente responsabilidades entre bases de datos
- La base de datos search.db contiene el historial de búsqueda de los usuarios (21 registros)
- La tabla services_in_search en search.db está vacía porque no hay servicios en búsqueda registrados
- La tabla ally_services está vacía porque no hay relaciones entre aliados y servicios registradas

## Arquitectura Actual
La estructura sigue el principio de separación de responsabilidades:
- **Usuarios:** users.db
- **Aliados:** allies.db  
- **Servicios:** services.db
- **Búsquedas:** search.db
- **Transacciones:** transactions.db

Esta arquitectura facilita el mantenimiento y evolución de la aplicación, al separar cada dominio de datos en bases de datos dedicadas.