# Lost & Found Objects Module - Deployment Checklist

**Version:** 1.0.0  
**Status:** Production Ready ✅  
**Last Updated:** November 4, 2026

---

## Pre-Deployment (Day 0)

### System Requirements
- [ ] PostgreSQL 12+ installed
- [ ] PostGIS 3.0+ installed
- [ ] PHP 8.3+ installed
- [ ] Composer installed
- [ ] Flutter SDK 3.13+ installed
- [ ] Node.js 18+ (optional, for npm scripts)

### Verify Installation
```bash
# PostgreSQL
psql --version
# Output: psql (PostgreSQL) 12.x or higher ✓

# PostGIS
psql -U postgres -c "SELECT postgis_version();"
# Output: POSTGIS="3.x.x" ✓

# PHP
php --version
# Output: PHP 8.3.x ✓

# Flutter
flutter --version
# Output: Flutter X.Y.Z ✓
```

---

## Backend Deployment

### 1. Database Setup (PostgreSQL)

```bash
# Create database
createdb lost_found

# Connect and enable PostGIS
psql -U postgres -d lost_found -c "CREATE EXTENSION postgis;"

# Verify PostGIS
psql -U postgres -d lost_found -c "SELECT postgis_version();"
# Expected: postgis_version = "POSTGIS="3.x.x"..."
```

**Checklist:**
- [ ] Database `lost_found` created
- [ ] PostGIS extension enabled
- [ ] Verified with `postgis_version()`

### 2. Laravel Setup

```bash
# Navigate to backend
cd lost_found_api

# Copy environment file
cp .env.example .env

# Edit .env with database credentials
# DB_HOST=127.0.0.1
# DB_PORT=5432
# DB_DATABASE=lost_found
# DB_USERNAME=postgres (or your user)
# DB_PASSWORD=your_password
```

**Checklist:**
- [ ] `.env` file created
- [ ] Database credentials configured
- [ ] APP_KEY generated (if not present)

### 3. Run Migrations

```bash
# Install PHP dependencies
composer install

# Generate app key
php artisan key:generate

# Run migrations (includes PostGIS setup)
php artisan migrate

# Verify tables created
php artisan tinker
>>> DB::table('items')->count();
=> 0
```

**Expected Migration Output:**
```
Migrating: 2014_10_12_000000_create_users_table
Migrated:  2014_10_12_000000_create_users_table (xxx ms)

Migrating: 2026_10_20_135808_add_image_and_secret_question_to_items_table
Migrated:  2026_10_20_135808_add_image_and_secret_question_to_items_table (xxx ms)
```

**Checklist:**
- [ ] All migrations completed
- [ ] Tables created successfully
- [ ] PostGIS extension enabled
- [ ] Spatial indexes created

### 4. Verify PostGIS Spatial Indexes

```bash
# Connect to database
psql -U postgres -d lost_found

# Check spatial index
SELECT * FROM pg_indexes WHERE tablename = 'items' AND indexname LIKE '%location%';
# Expected: items_location_idx | items | GIST | location

# Verify spatial function availability
SELECT ST_DWithin(location, ST_GeographyFromText('SRID=4326;POINT(0 0)'), 10000) FROM items LIMIT 1;
# Expected: Query executes without error
```

**Checklist:**
- [ ] Spatial index `items_location_idx` exists
- [ ] Index type is GIST
- [ ] ST_DWithin function works

### 5. Test API Endpoints

```bash
# Start Laravel dev server
php artisan serve

# Test ping endpoint (no auth)
curl http://localhost:8000/api/ping
# Expected: {"status":"ok","app":"Lost&Found AI"}

# Test auth endpoint
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"phone":"+33612345678","password":"test"}'
# Expected: 200 or 422 (validation error is fine)
```

**Checklist:**
- [ ] API server starts without errors
- [ ] Ping endpoint responds
- [ ] Auth endpoints accessible

---

## Frontend Deployment

### 1. Flutter Setup

```bash
# Navigate to frontend
cd lost_found_ai

# Get dependencies
flutter pub get

# Verify dependencies installed
flutter pub deps --json | grep flutter_map
# Expected: flutter_map version listed
```

**Checklist:**
- [ ] All dependencies installed
- [ ] No pub warnings (except deprecation notes)
- [ ] All required packages present

### 2. Configure API Base URL

Edit `.env` or environment configuration:

```dart
// lib/core/app_config.dart
static const String apiBaseUrl = 'http://localhost:8000/api';
// Change to your backend URL for production
```

**For Production:**
```dart
static const String apiBaseUrl = 'https://api.yourdomain.com/api';
```

**Checklist:**
- [ ] API URL configured correctly
- [ ] Backend accessible from frontend
- [ ] HTTPS used in production

### 3. Build Flutter App

```bash
# iOS build
flutter build ios --release

# Android build
flutter build apk --release

# Web build (optional)
flutter build web --release
```

**Expected Output:**
```
✓ Built build/app/outputs/flutter-apk/app-release.apk
```

**Checklist:**
- [ ] Build completes without errors
- [ ] No security warnings
- [ ] APK/IPA file generated

### 4. Test Flutter App

```bash
# Run in debug mode
flutter run -d <device>

# Or connect to local backend
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

**Manual Test Cases:**
- [ ] App launches successfully
- [ ] Can navigate to objects dashboard
- [ ] Can request location permission
- [ ] Can see map with markers
- [ ] Can create new object (requires auth)
- [ ] Can upload image
- [ ] Can search and filter

---

## Integration Testing

### 1. End-to-End Flow

```bash
# 1. Create user account (via auth endpoints)
curl -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","phone":"+33612345678","password":"test1234"}'

# 2. Get auth token
TOKEN="your_token_from_response"

# 3. Create object
curl -X POST http://localhost:8000/api/items \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "LOST",
    "category": "telephone",
    "title": "Black iPhone 15",
    "description": "Lost in Paris",
    "latitude": 48.8566,
    "longitude": 2.3522,
    "place_label": "Eiffel Tower",
    "occurred_at": "2026-11-04T10:00:00Z",
    "contact_phone": "+33612345678"
  }'

# 4. Search nearby objects
curl "http://localhost:8000/api/items/nearby?latitude=48.8566&longitude=2.3522&radius_km=10" \
  -H "Authorization: Bearer $TOKEN"

# Expected: Object returned with distance_km
```

**Checklist:**
- [ ] User creation works
- [ ] Authentication token issued
- [ ] Object creation succeeds
- [ ] Spatial query returns results
- [ ] Distance calculation accurate

### 2. Image Upload Test

```bash
# Upload object with image
curl -X POST http://localhost:8000/api/items \
  -H "Authorization: Bearer $TOKEN" \
  -F "type=LOST" \
  -F "category=telephone" \
  -F "title=Lost Phone" \
  -F "description=Help me find it" \
  -F "place_label=Paris" \
  -F "occurred_at=2026-11-04T10:00:00Z" \
  -F "latitude=48.8566" \
  -F "longitude=2.3522" \
  -F "image=@/path/to/image.jpg"

# Expected: 201 Created with image_path populated
```

**Checklist:**
- [ ] File upload succeeds
- [ ] Image stored in storage/app/public/items
- [ ] Response includes image_path
- [ ] Image accessible via HTTP

### 3. Performance Test

```sql
-- Test spatial query performance
EXPLAIN ANALYZE
SELECT * FROM items 
WHERE ST_DWithin(location, ST_GeographyFromText('SRID=4326;POINT(2.3522 48.8566)'), 10000)
AND status = 'ACTIVE'
ORDER BY ST_DistanceSphere(location, ST_GeographyFromText('SRID=4326;POINT(2.3522 48.8566)'))
LIMIT 10;

-- Expected execution time: <50ms even with 1M rows
```

**Checklist:**
- [ ] Query uses spatial index (Index Scan)
- [ ] Execution time < 100ms
- [ ] Results returned correctly

---

## Security Verification

### 1. Authentication

- [ ] Login endpoint requires credentials
- [ ] Token returned on successful auth
- [ ] Invalid credentials return 401
- [ ] Expired token returns 401
- [ ] Token stored securely on client

### 2. Authorization

- [ ] Unauthenticated requests return 401
- [ ] Non-verified users return 403 for protected endpoints
- [ ] User can only edit own objects
- [ ] User can only delete own objects
- [ ] Other users cannot modify objects

### 3. Input Validation

- [ ] Empty fields rejected
- [ ] Invalid coordinates rejected
- [ ] File size limit enforced (5MB)
- [ ] String length limits applied
- [ ] SQL injection prevented

### 4. Data Security

- [ ] Images stored outside web root
- [ ] Database credentials not in code
- [ ] API base URL configurable
- [ ] HTTPS enforced in production
- [ ] CORS properly configured

**Checklist:**
- [ ] All security tests passed
- [ ] No obvious vulnerabilities
- [ ] Sensitive data protected

---

## Production Deployment

### 1. Server Setup

```bash
# Example: Ubuntu/Debian

# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install PostgreSQL
sudo apt-get install postgresql postgresql-contrib postgis

# Install PHP
sudo apt-get install php8.3 php8.3-fpm php8.3-pgsql

# Install Nginx
sudo apt-get install nginx

# Clone repository
git clone https://github.com/your-repo/lost-found-api.git
cd lost-found-api

# Install dependencies
composer install --no-dev --optimize-autoloader
```

### 2. Environment Configuration

```bash
# Copy env file
cp .env.example .env

# Edit for production
# - Set APP_ENV=production
# - Set APP_DEBUG=false
# - Configure database credentials
# - Set strong APP_KEY
# - Configure mail settings
# - Set API_URL for frontend
```

### 3. Database Setup

```bash
# Create database user
sudo -u postgres createuser lost_found -P

# Create database
sudo -u postgres createdb -O lost_found lost_found

# Enable PostGIS
sudo -u postgres psql -d lost_found -c "CREATE EXTENSION postgis;"

# Run migrations
php artisan migrate --force
```

### 4. File Permissions

```bash
# Set storage permissions
chmod -R 775 storage
chmod -R 775 bootstrap/cache

# Set ownership
sudo chown -R www-data:www-data storage
sudo chown -R www-data:www-data bootstrap/cache
```

### 5. Web Server Configuration (Nginx)

```nginx
server {
    listen 80;
    server_name api.yourdomain.com;
    root /var/www/lost-found-api/public;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

    # Deny access to sensitive files
    location ~ /\. {
        deny all;
    }
}
```

### 6. SSL Certificate (Let's Encrypt)

```bash
# Install certbot
sudo apt-get install certbot python3-certbot-nginx

# Generate certificate
sudo certbot certonly --nginx -d api.yourdomain.com

# Update Nginx config to use HTTPS
sudo certbot --nginx -d api.yourdomain.com
```

**Checklist:**
- [ ] Server environment prepared
- [ ] PostgreSQL + PostGIS installed
- [ ] PHP configured
- [ ] Database created and seeded
- [ ] File permissions set
- [ ] Web server configured
- [ ] SSL certificate installed
- [ ] Firewall rules configured

---

## Backup & Recovery

### 1. Database Backup

```bash
# Daily backup
pg_dump -U postgres -d lost_found > lost_found_backup_$(date +%Y%m%d).sql

# Compressed backup
pg_dump -U postgres -d lost_found -F c > lost_found_backup_$(date +%Y%m%d).dump

# Automated daily backup (cron)
0 2 * * * pg_dump -U postgres -d lost_found > /backups/lost_found_$(date +\%Y\%m\%d).sql
```

### 2. Database Restore

```bash
# From SQL backup
psql -U postgres -d lost_found < lost_found_backup_20261104.sql

# From custom format
pg_restore -U postgres -d lost_found lost_found_backup_20261104.dump
```

### 3. File Backup

```bash
# Backup storage folder
tar -czf lost_found_storage_$(date +%Y%m%d).tar.gz /var/www/lost-found-api/storage/app/public

# Backup .env
cp .env .env.backup_$(date +%Y%m%d)
```

**Checklist:**
- [ ] Daily backups configured
- [ ] Backup storage secure
- [ ] Recovery procedure tested
- [ ] Backup retention policy set

---

## Post-Deployment Monitoring

### 1. Application Logs

```bash
# View Laravel logs
tail -f storage/logs/laravel.log

# View PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql.log
```

### 2. Performance Monitoring

```bash
# Database query performance
SELECT query, mean_exec_time, calls FROM pg_stat_statements 
WHERE query LIKE '%items%' 
ORDER BY mean_exec_time DESC;

# Slow queries (>1000ms)
SELECT query, mean_exec_time FROM pg_stat_statements 
WHERE mean_exec_time > 1000 
ORDER BY mean_exec_time DESC;
```

### 3. Error Monitoring

```bash
# Monitor error rate
grep -c ERROR storage/logs/laravel.log

# Check for failed requests
grep "Exception\|Error" storage/logs/laravel.log | tail -20
```

**Checklist:**
- [ ] Monitoring systems active
- [ ] Logs being collected
- [ ] Alerts configured
- [ ] Performance baseline established

---

## Rollback Plan

### If Something Goes Wrong

```bash
# 1. Check current status
php artisan migrate:status

# 2. Rollback last migration
php artisan migrate:rollback

# 3. Restore from backup
pg_restore -U postgres -d lost_found lost_found_backup_YYYYMMDD.dump

# 4. Restore code from Git
git revert <commit-hash>
git push

# 5. Clear caches
php artisan cache:clear
php artisan config:clear
php artisan view:clear
```

**Checklist:**
- [ ] Rollback procedure documented
- [ ] Backup verified
- [ ] Git history clean
- [ ] Team notified

---

## Final Sign-Off

- [ ] All pre-deployment checks passed
- [ ] Database configured and tested
- [ ] Backend API operational
- [ ] Frontend builds successfully
- [ ] Integration tests passed
- [ ] Security verification complete
- [ ] Performance acceptable
- [ ] Backups configured
- [ ] Monitoring active
- [ ] Team trained

**Deployment Date:** _______________  
**Deployed By:** _______________  
**Approved By:** _______________  
**Notes:** _______________________________________________________________

---

## Support & Troubleshooting

See `POSTGRESQL_SETUP.md` for:
- Database troubleshooting
- Performance optimization
- Extension issues

See `OBJECTS_MODULE_IMPLEMENTATION.md` for:
- API documentation
- Common issues
- Testing procedures

---

**Version:** 1.0.0  
**Last Updated:** November 4, 2026  
**Status:** Ready for Production ✅
