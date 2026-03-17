# tudu Application Ecosystem - Complete Technical Blueprint

## 1. PROJECT OVERVIEW

The tudu ecosystem is a multi-platform, multi-role application designed to connect users (clients) with service providers (allies) through a seamless, location-based service marketplace. The system supports three primary applications:

### 1.1 Application Architecture
- **App Users** (tudu_users/): Main user-facing application for clients
- **App Allies** (tudu_allies/): Provider-facing application for service providers
- **App Admin** (tudu_admin/): Administrative dashboard for platform management

## 2. SYSTEM ARCHITECTURE

### 2.1 High-Level Architecture
```
┌──────────────────────┐    ┌──────────────────────┐    ┌──────────────────────┐
│   tudu Users App     │    │   tudu Allies App    │    │   tudu Admin App     │
│  (Flutter - Multi)   │    │  (Flutter - Multi)   │    │  (Flutter - Multi)   │
└────────┬─────────────┘    └────────┬─────────────┘    └────────┬─────────────┘
         │                           │                           │
         ▼                           ▼                           ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    Backend API Layer (Express.js)                  │
├──────────────────────────────────────────────────────────────────────┤
│ - Users Backend (Port 3000)                                        │
│ - Allies Backend (Port 3002)                                       │
│ - Admin Backend (Port 3003)                                        │
└────────┬────────────────────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    Database Layer (SQLite3)                         │
├──────────────────────────────────────────────────────────────────────┤
│ - users.db: User profiles and authentication                        │
│ - allies.db: Ally profiles and authentication                       │
│ - services.db: Services catalog and service-in-search records       │
│ - search.db: Search history and messages                            │
│ - admins.db: Admin user management                                  │
└──────────────────────────────────────────────────────────────────────┘
```

## 3. DATABASE SCHEMAS

### 3.1 Database Structure Overview
All databases are SQLite3 files located in the `/Users/juanda/tudu/databases/` directory.

---

### 3.2 users.db - User Profiles Database
**Purpose**: Store user (client) information and authentication data

**Table: users**
```sql
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT UNIQUE NOT NULL,
    nombre TEXT NOT NULL,
    apellido TEXT NOT NULL,
    role TEXT DEFAULT 'user',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

**Fields**:
- `id`: Unique identifier (auto-increment)
- `email`: User's email (unique)
- `nombre`: First name (max 20 characters)
- `apellido`: Last name (max 20 characters)
- `role`: User role (default: 'user')
- `created_at`: Registration timestamp

**Sample Data**:
- Records: 2 users
- Email validation: Yes (unique constraint)

---

### 3.3 allies.db - Ally/Provider Database
**Purpose**: Store service provider information and authentication data

**Table: allies**
```sql
CREATE TABLE IF NOT EXISTS allies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT UNIQUE NOT NULL,
    nombre TEXT NOT NULL,
    apellido TEXT NOT NULL,
    role TEXT DEFAULT 'ally',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

**Fields**:
- `id`: Unique identifier (auto-increment)
- `email`: Ally's email (unique)
- `nombre`: First name (max 20 characters)
- `apellido`: Last name (max 20 characters)
- `role`: User role (default: 'ally')
- `created_at`: Registration timestamp

**Sample Data**:
- Records: 0 allies

---

### 3.4 services.db - Services and Service Requests Database
**Purpose**: Manage available services, service requests, and ally-service relationships

**Table: services** (Service Catalog)
```sql
CREATE TABLE IF NOT EXISTS services (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    description TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

**Fields**:
- `id`: Unique identifier (auto-increment)
- `name`: Service name (unique)
- `description`: Service description
- `created_at`: Creation timestamp

**Sample Data**:
- Records: 10 services
- Examples: "Servicio de hogar", "Reparaciones eléctricas", "Limpieza"

---

**Table: services_in_search** (Service Requests)
```sql
CREATE TABLE IF NOT EXISTS services_in_search (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    title TEXT NOT NULL,
    description TEXT,
    time_quantity INTEGER,
    time_unit TEXT,
    budget TEXT,
    worker_info TEXT,
    additional_info TEXT,
    status TEXT DEFAULT 'EN ESPERA',
    assigned INTEGER DEFAULT 0,
    ally_id INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

**Fields**:
- `id`: Unique identifier (auto-increment)
- `user_id`: ID of user making the request (FK to users.id)
- `title`: Request title
- `description`: Detailed description
- `time_quantity`: Required time quantity
- `time_unit`: Time unit (hours, days, etc.)
- `budget`: Budget range
- `worker_info`: Required worker qualifications
- `additional_info`: Additional details
- `status`: Current status (EN ESPERA, EN PROCESO, COMPLETADO)
- `assigned`: Assignment status (0 = unassigned, 1 = assigned)
- `ally_id`: ID of assigned ally (FK to allies.id)
- `created_at`: Creation timestamp

**Sample Data**:
- Records: 1 service (Cáma para perros)

---

**Table: ally_services** (Ally-Service Relationships)
```sql
CREATE TABLE IF NOT EXISTS ally_services (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ally_id INTEGER NOT NULL,
    service_id INTEGER NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(ally_id, service_id)
);
```

**Fields**:
- `id`: Unique identifier (auto-increment)
- `ally_id`: ID of the ally (FK to allies.id)
- `service_id`: ID of the service (FK to services.id)
- `created_at`: Relationship creation timestamp

**Constraints**:
- Unique constraint on (ally_id, service_id) to prevent duplicates

**Sample Data**:
- Records: 0 relationships

---

### 3.5 search.db - Search History and Messaging Database
**Purpose**: Track user search history and manage communication between users and allies

**Table: search_history**
```sql
CREATE TABLE IF NOT EXISTS search_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_email TEXT NOT NULL,
    search_query TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

**Fields**:
- `id`: Unique identifier (auto-increment)
- `user_email`: Email of user who performed the search
- `search_query`: Search terms used
- `created_at`: Search timestamp

**Sample Data**:
- Records: 21 search history entries

---

**Table: messages**
```sql
CREATE TABLE IF NOT EXISTS messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sender_id INTEGER,
    receiver_id INTEGER,
    sender_role TEXT NOT NULL,
    receiver_role TEXT NOT NULL,
    service_in_search_id INTEGER,
    message TEXT NOT NULL,
    read BOOLEAN DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (service_in_search_id) REFERENCES services_in_search(id) ON DELETE CASCADE
);
```

**Fields**:
- `id`: Unique identifier (auto-increment)
- `sender_id`: ID of message sender
- `receiver_id`: ID of message receiver
- `sender_role`: Role of sender ('user' or 'ally')
- `receiver_role`: Role of receiver ('user' or 'ally')
- `service_in_search_id`: ID of related service request
- `message`: Message content
- `read`: Read status (0 = unread, 1 = read)
- `created_at`: Message timestamp

**Constraints**:
- Foreign key constraint to services_in_search (cascade delete)

**Sample Data**:
- Records: 0 messages

---

### 3.6 admins.db - Admin User Management Database
**Purpose**: Manage platform administrators and their roles

**Table: admins**
```sql
CREATE TABLE IF NOT EXISTS admins (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    email TEXT UNIQUE,
    name TEXT NOT NULL,
    role TEXT DEFAULT 'admin',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

**Fields**:
- `id`: Unique identifier (auto-increment)
- `username`: Admin username (unique)
- `password`: Admin password (plain text)
- `email`: Admin email (unique)
- `name`: Full name
- `role`: Role (default: 'admin')
- `created_at`: Creation timestamp
- `updated_at`: Last update timestamp

**Default Admin**:
- Username: admin
- Password: 123
- Email: admin@tuduapp.com
- Name: Administrador Principal

---

## 4. BACKEND ARCHITECTURE

### 4.1 Backend Structure

#### 4.1.1 Users Backend (tudu_users/backend/)
**File**: `index.js`
**Port**: 3002
**Dependencies**:
- express: ^4.18.2
- cors: ^2.8.5
- dotenv: ^16.6.1
- sqlite3: ^5.1.7
- mailgun-js: ^0.22.0 (for OTP emails)
- firebase-admin: For additional features

**Database Connections**:
- users.db
- services.db
- search.db

**Key Features**:
- OTP-based authentication
- User registration and verification
- Service publishing and searching
- Search history management
- User profiles and settings

---

#### 4.1.2 Allies Backend (tudu_allies/backend/)
**File**: `index.js`
**Port**: 3002
**Dependencies**:
- express: ^4.18.2
- cors: ^2.8.5
- dotenv: ^16.6.1
- sqlite3: ^5.1.7
- mailgun-js: ^0.22.0 (for OTP emails)

**Database Connections**:
- allies.db
- services.db

**Key Features**:
- OTP-based authentication
- Ally registration and verification
- Service assignment and management
- Service status updates
- Ally profiles and settings

---

#### 4.1.3 Admin Backend (tudu_admin/backend/)
**File**: `server.js`
**Port**: 3003
**Dependencies**:
- express: ^4.18.2
- cors: ^2.8.5
- dotenv: ^16.6.1
- sqlite3: ^5.1.7

**Database Connections**:
- admins.db

**Key Features**:
- Admin user management
- Admin profile management
- Password change functionality

---

### 4.2 API ENDPOINTS

#### 4.2.1 Users App Endpoints
```
POST /send-otp - Send OTP code to user email
POST /verify-otp - Verify OTP code
POST /check-user - Check if user exists
POST /register-user - Register new user
GET /services - Get all available services
POST /publish-service - Publish a service request
GET /services-in-search - Get unassigned service requests
POST /search-history - Save search history
GET /search-history - Get user search history
DELETE /search-history/:id - Delete search history item
GET /search-services - Search for services
```

#### 4.2.2 Allies App Endpoints
```
POST /send-otp - Send OTP code to ally email
POST /verify-otp - Verify OTP code
POST /check-ally - Check if ally exists
POST /register-ally - Register new ally
GET /services - Get all available services
GET /services-in-search - Get unassigned service requests
PUT /services-in-search/:id/assign - Assign service to ally
PUT /services-in-search/:id/status - Update service status
GET /my-services - Get services assigned to ally
```

#### 4.2.3 Admin App Endpoints
```
POST /api/admin/login - Admin login
GET /api/admins - Get all admin users
POST /api/admins - Create new admin
PUT /api/admins/:id - Update admin details
DELETE /api/admins/:id - Delete admin
PUT /api/admins/:id/change-password - Change admin password
```

---

## 5. FRONTEND APPLICATIONS

### 5.1 App Users (tudu_users/users/)

#### 5.1.1 Main Features
- **Onboarding**: Initial app introduction
- **Authentication**: Phone/email login with OTP verification
- **Home Screen**: Service discovery and quick actions
- **Search**: Advanced service search with filters
- **Profile**: User profile management
  - Personal data management
  - Address management
  - Payment card management
  - Settings (language, theme)
- **Services**: Browse all available services
- **Service Detail**: View service details and provider information
- **Publish Service**: Create and publish service requests
- **My Services**: Manage published service requests
- **Search History**: View and manage search history

#### 5.1.2 Core Screens
- `onboarding_screen.dart`: App introduction
- `login_screen.dart`: User login
- `otp_screen.dart`: OTP verification
- `registration_screen.dart`: User registration
- `home_screen.dart`: Main dashboard
- `search_screen.dart`: Service search
- `all_services_screen.dart`: Browse all services
- `service_detail_screen.dart`: Service details
- `publish_service_screen.dart`: Create service request
- `user_services_screen.dart`: Manage published services
- `profile_screen.dart`: User profile
- `user_personal_data_screen.dart`: Personal information
- `user_addresses_screen.dart`: Address management
- `user_cards_screen.dart`: Payment card management
- `appearance_screen.dart`: Theme and appearance
- `language_screen.dart`: Language selection

#### 5.1.3 Configuration
**File**: `config.dart`
- Base URL: http://10.150.102.86:3000
- Environment detection for emulators/simulators
- Device type detection

#### 5.1.4 Dependencies
- flutter/material.dart
- cupertino_icons
- http
- device_info_plus
- shared_preferences
- intl
- connectivity_plus
- url_launcher
- etc.

---

### 5.2 App Allies (tudu_allies/allies/)

#### 5.2.1 Main Features
- **Onboarding**: Initial app introduction
- **Authentication**: Phone/email login with OTP verification
- **Dashboard**: View service requests and statistics
- **Services in Search**: Browse unassigned service requests
- **My Services**: Manage assigned services
- **Service Assignment**: Accept service requests
- **Service Status**: Update service progress
- **Profile**: Ally profile management

#### 5.2.2 Core Screens
- `onboarding_screen.dart`: App introduction
- `login_screen.dart`: Ally login
- `otp_screen.dart`: OTP verification
- `registration_screen.dart`: Ally registration
- `dashboard_screen.dart`: Main dashboard
- `services_in_search_screen.dart`: Browse unassigned services
- `my_services_screen.dart`: Manage assigned services

#### 5.2.3 Configuration
**File**: `config.dart`
- Base URL: http://10.150.102.86:3002
- Environment detection for emulators/simulators

#### 5.2.4 Dependencies
- flutter/material.dart
- cupertino_icons
- http
- device_info_plus
- shared_preferences

---

### 5.3 App Admin (tudu_admin/admin/)

#### 5.3.1 Main Features
- **Onboarding**: Initial app introduction
- **Authentication**: Admin login
- **Dashboard**: Admin dashboard with platform statistics
- **Admin Management**: Create, read, update, delete admin users
- **Profile Management**: Update admin profile
- **Password Change**: Change admin password
- **Photo Change Requests**: Manage photo change requests

#### 5.3.2 Core Screens
- `onboarding_screen.dart`: App introduction
- `login_screen.dart`: Admin login
- `dashboard_screen.dart`: Main dashboard
- `photo_change_requests_screen.dart`: Photo request management

#### 5.3.3 Configuration
**File**: `config.dart`
- Base URL: http://10.150.102.86:3000 (or 3003 for admin)
- Environment detection for emulators/simulators
- Device type detection

#### 5.3.4 Branding Colors
- Primary: #78BF32 (Green)
- Secondary: #595959 (Gray)
- Background: #F4F2F2 (Light Gray)
- Text: #78BF32 (Green)
- White: #FFFFFF
- Black: #000000
- Red: #F44336

#### 5.3.5 Dependencies
- flutter/material.dart
- cupertino_icons
- http
- device_info_plus
- shared_preferences

---

## 6. AUTHENTICATION & SECURITY

### 6.1 OTP System
- **Generation**: 6-digit random code
- **Storage**: In-memory Map (Node.js)
- **Expiration**: 10 minutes
- **Delivery**: Mailgun email service
- **Development Mode**: Auto-accept any OTP

### 6.2 Security Considerations
- **Password Storage**: Plain text (weak - needs improvement)
- **CORS**: Enabled for all origins
- **Rate Limiting**: Not implemented
- **HTTPS**: Not configured

### 6.3 Development Features
- DEV_MODE environment variable for testing
- Auto-accept OTP in development
- Console logging of OTP codes

---

## 7. WORKFLOW & BUSINESS LOGIC

### 7.1 User Journey
1. **Onboarding**: User downloads app, views introduction
2. **Authentication**:
   - Enters email/phone number
   - Receives OTP via email
   - Verifies OTP
3. **Registration**:
   - If new user, completes registration
   - Enters name, email, phone
4. **Service Discovery**:
   - Browses services or searches
   - Views service details
5. **Publish Request**:
   - Creates service request
   - Specifies details (time, budget, requirements)
6. **Service Matching**:
   - Allies browse unassigned requests
   - Ally accepts request
7. **Execution**:
   - User and ally communicate
   - Service is performed
8. **Completion**:
   - Service status updated to completed
   - Feedback and rating

### 7.2 Ally Journey
1. **Onboarding**: Ally downloads app, views introduction
2. **Authentication**: Same as user flow
3. **Registration**: Enters business information
4. **Service Browsing**:
   - Views unassigned service requests
   - Filters by service type, location
5. **Accepting Requests**:
   - Accepts a service request
   - Service status becomes "EN PROCESO"
6. **Execution**:
   - Communicates with user
7. **Completion**: Updates status to completed

---

## 8. DEPLOYMENT & CONFIGURATION

### 8.1 Environment Variables

#### Users Backend (.env)
```env
PORT=3000
MAILGUN_API_KEY=your_api_key
MAILGUN_DOMAIN=your_domain
DEV_MODE=true
```

#### Allies Backend (.env)
```env
PORT=3002
MAILGUN_API_KEY=your_api_key
MAILGUN_DOMAIN=your_domain
DEV_MODE=true
```

#### Admin Backend (.env)
```env
PORT=3003
```

### 8.2 Database Initialization

#### Users Backend
```bash
cd tudu_users/backend
npm install
npm run init-db  # (if exists)
npm start
```

#### Allies Backend
```bash
cd tudu_allies/backend
npm install
npm start
```

#### Admin Backend
```bash
cd tudu_admin/backend
npm install
npm run init-db  # Creates admins table and default admin
npm start
```

### 8.3 Frontend Configuration

All apps require the correct IP address in `config.dart`:
```dart
static const String localIpAddress = '10.150.102.86';  // Change to your local IP
```

---

## 9. PROJECT STRUCTURE

```
/Users/juanda/tudu/
├── databases/
│   ├── users.db
│   ├── allies.db
│   ├── services.db
│   ├── search.db
│   └── admins.db
├── tudu_users/
│   ├── backend/
│   │   ├── index.js
│   │   ├── package.json
│   │   └── .env.example
│   └── users/
│       ├── lib/
│       │   ├── main.dart
│       │   ├── config.dart
│       │   ├── models/
│       │   ├── providers/
│       │   ├── screens/
│       │   └── services/
│       ├── pubspec.yaml
│       └── assets/
├── tudu_allies/
│   ├── backend/
│   │   ├── index.js
│   │   ├── package.json
│   │   └── .env.example
│   └── allies/
│       ├── lib/
│       │   ├── main.dart
│       │   ├── config.dart
│       │   ├── models/
│       │   └── screens/
│       ├── pubspec.yaml
│       └── assets/
└── tudu_admin/
    ├── backend/
    │   ├── server.js
    │   ├── init-db.js
    │   ├── package.json
    │   └── .env.example
    └── admin/
        ├── lib/
        │   ├── main.dart
        │   ├── config.dart
        │   └── screens/
        ├── pubspec.yaml
        └── assets/
```

---

## 10. KEY DATA

### 10.1 Database Statistics
- **users.db**: 2 users registered
- **allies.db**: 0 allies registered
- **services.db**: 10 services available
- **search.db**: 21 search history records
- **admins.db**: 1 admin user (default)

### 10.2 Services Catalog
1. Servicio de hogar
2. Reparaciones eléctricas
3. Limpieza
4. Reparaciones plúmbicas
5. Jardinería
6. Mantenimiento de aire acondicionado
7. Reparación de electrodomésticos
8. Carpintería
9. Pintura
10. Otros

---

## 11. LIMITATIONS & IMPROVEMENTS

### 11.1 Security Improvements
- **Password Hashing**: Implement bcrypt for password storage
- **HTTPS**: Enable TLS/SSL
- **Rate Limiting**: Add rate limiting to API endpoints
- **Input Validation**: Strengthen input validation
- **CORS Configuration**: Restrict origins

### 11.2 Performance Improvements
- **Database Indexing**: Add indexes to frequently queried fields
- **Caching**: Implement Redis for caching
- **Query Optimization**: Optimize complex queries
- **File Storage**: Use cloud storage for files

### 11.3 Feature Improvements
- **Real-time Communication**: Add WebSocket support
- **Push Notifications**: Implement Firebase Cloud Messaging
- **Location Services**: Improve location-based features
- **Payment Integration**: Add payment processing
- **Reviews & Ratings**: Implement review system

### 11.4 Testing
- **Unit Tests**: Add backend unit tests
- **Integration Tests**: Test API endpoints
- **UI Tests**: Add Flutter widget tests

---

## 12. TECHNICAL STACK

### Backend
- **Runtime**: Node.js
- **Framework**: Express.js
- **Database**: SQLite3
- **Email Service**: Mailgun
- **Environment**: Development (localhost)

### Frontend
- **Framework**: Flutter (Dart)
- **Platforms**: Android, iOS, Web, Desktop
- **State Management**: Provider/ChangeNotifier
- **Local Storage**: SharedPreferences

### Tools
- **IDE**: VSCode
- **Version Control**: Git
- **Package Manager**: npm (Node), pub (Flutter)
