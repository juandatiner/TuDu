# Informe de Migración de Bases de Datos ToDo

## Resumen General

Se ha completado la migración exitosa de las bases de datos SQLite antiguas a una nueva estructura unificada y escalable. La migración ha mejorado la organización, seguridad y rendimiento del sistema.

## Estructura Anterior vs. Nueva

### Bases de Datos Antiguas (3 separadas)
- `users.db`: Almacenaba información de usuarios
- `allies.db`: Almacenaba información de aliados
- `services.db`: Almacenaba servicios y servicios en búsqueda

### Nueva Base de Datos Unificada (todo.db)
- Una sola base de datos con todas las tablas relacionadas
- Relaciones foreign key definidas para mantener la integridad referencial
- Índices optimizados para consultas frecuentes

## Tablas y Campos

### 1. users
- Almacena información de usuarios
- **Campos**: id, email (unique), nombre, apellido, role (default: user), created_at
- **Índices**: Primary key (id)

### 2. allies
- Almacena información de aliados
- **Campos**: id, email (unique), nombre, apellido, role (default: ally), created_at
- **Índices**: Primary key (id)

### 3. services
- Almacena tipos de servicios disponibles
- **Campos**: id, name (unique), description, created_at
- **Índices**: Primary key (id), name (unique)

### 4. services_in_search
- Almacena servicios en busca de aliados
- **Campos**: id, user_id, title, description, time_quantity, time_unit, budget, worker_info, additional_info, status (default: EN ESPERA), assigned (default: 0), ally_id, created_at
- **Índices**: Primary key (id), idx_services_in_search_user, idx_services_in_search_ally, idx_services_in_search_status, idx_services_in_search_assigned
- **Foreign Keys**: user_id → users(id), ally_id → allies(id)

### 5. ally_services
- Almacena la relación entre aliados y servicios (especializaciones)
- **Campos**: id, ally_id, service_id, created_at
- **Índices**: Primary key (id)
- **Foreign Keys**: ally_id → allies(id), service_id → services(id)
- **Unique Constraint**: (ally_id, service_id)

### 6. messages
- Almacena mensajes entre usuarios y aliados
- **Campos**: id, sender_id, receiver_id, sender_role, receiver_role, service_in_search_id, message, read (default: 0), created_at
- **Índices**: Primary key (id), idx_messages_sender, idx_messages_receiver, idx_messages_service
- **Foreign Keys**: service_in_search_id → services_in_search(id)

## Datos Migrados

### Resumen de Registro
- **Usuarios**: 2 registros migrados
- **Aliados**: 5 registros migrados
- **Servicios**: 10 registros migrados
- **Servicios en búsqueda**: 7 registros migrados

### Datos de Muestra

#### Usuarios
1. id: 8, email: cosmodavid2009@gmail.com, nombre: Juan, apellido: Rincón
2. id: 9, email: cosmodavid2009@gmail.co, nombre: Juan, apellido: Rincón

#### Aliados
1. id: 1, email: test@test.com, nombre: Test, apellido: User
2. id: 2, email: test3@test.com, nombre: Test, apellido: User
3. id: 3, email: cosmodavid2009@gmail.com, nombre: Juan, apellido: Carlos

#### Servicios
1. id: 1, name: Servicio de hogar
2. id: 2, name: Reparaciones eléctricas
3. id: 3, name: Limpieza

#### Servicios en búsqueda
1. id: 1, user_id: null, title: Juanito el programador, status: TERMINADO
2. id: 2, user_id: null, title: Decoraciones lindas, status: CANCELADO
3. id: 3, user_id: null, title: Cámara para perros, status: EN ESPERA

## Optimización y Mejoras

### 1. Relaciones y Integridad Referencial
- Se definieron foreign keys para todas las relaciones entre tablas
- Se establecieron acciones de cascada para mantener la integridad

### 2. Índices
- Índices creados para optimizar consultas frecuentes:
  - idx_services_in_search_user
  - idx_services_in_search_ally
  - idx_services_in_search_status
  - idx_services_in_search_assigned
  - idx_messages_sender
  - idx_messages_receiver
  - idx_messages_service

### 3. Normalización
- Se normalizó la base de datos para reducir redundancias
- Se separaron conceptos en tablas independientes

## Pruebas Realizadas

### 1. Creación de la estructura
✅ Tablas y campos correctamente definidos

### 2. Migración de datos
✅ Todos los registros migrados con éxito

### 3. Integridad referencial
✅ Foreign keys válidas
✅ Relaciones entre tables funcionando

### 4. Consultas básicas
✅ Select, insert, update, delete funcionales

## Respaldo de Datos Antiguos

Las bases de datos originales se han respaldado en el directorio `/databases_old/`:
- `databases_old/users.db`
- `databases_old/allies.db`
- `databases_old/services.db`

## Tamaño de la Base de Datos

- Tamaño de la nueva base de datos: 76 KB
- Tamaño optimizado para rendimiento

## Conclusión

La migración se ha completado exitosamente. La nueva estructura es:
- Más escalable
- Mejor organizada
- Más segura
- Más eficiente para consultas
- Fácil de mantener

Se recomienda usar la nueva base de datos `todo.db` para todas las operaciones futuras.
