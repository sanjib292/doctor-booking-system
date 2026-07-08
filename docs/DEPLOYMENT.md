# Deployment Guide

## Production Deployment (Docker)

### 1. Server Requirements

- Ubuntu 22.04 LTS
- 4 GB RAM minimum (8 GB recommended)
- 50 GB SSD
- Docker 24+, Docker Compose 2+

### 2. Environment Setup

```bash
# Clone repository
git clone <repo-url> /opt/doctor-booking
cd /opt/doctor-booking

# Create production .env
cp apps/api/.env.example apps/api/.env
nano apps/api/.env  # Fill in all production values

# Generate strong secrets
openssl rand -base64 48  # Use for JWT_ACCESS_SECRET
openssl rand -base64 48  # Use for JWT_REFRESH_SECRET
```

### 3. Deploy

```bash
cd docker

# Build and start all services
POSTGRES_PASSWORD=your_secure_password docker-compose up -d --build

# Run database migrations
docker exec doctor-booking-api npx prisma migrate deploy

# Seed initial data (first deploy only)
docker exec doctor-booking-api node dist/prisma/seed.js

# Check health
curl http://localhost:3000/health
```

### 4. SSL Setup (Certbot)

```bash
# Install certbot
apt install certbot

# Get certificate
certbot certonly --standalone -d api.yourdomain.com

# Update nginx.conf with certificate paths
# Restart nginx
docker-compose restart nginx
```

### 5. Flutter Production Builds

**Android APK (Patient App):**
```bash
cd apps/patient_app
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com/api/v1
```

**Android APK (Doctor App):**
```bash
cd apps/doctor_app
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com/api/v1
```

**Web (Admin Panel):**
```bash
cd apps/admin_panel
flutter build web --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com/api/v1
# Deploy dist/web to Nginx/S3/Vercel
```

## Monitoring

### Health checks
```bash
curl https://api.yourdomain.com/health
```

### Logs
```bash
# API logs
docker logs doctor-booking-api -f

# DB logs
docker logs doctor-booking-postgres -f
```

### Database backup
```bash
# Manual backup
docker exec doctor-booking-postgres pg_dump -U postgres doctor_booking > backup.sql

# Automated daily backup (add to crontab)
0 2 * * * docker exec doctor-booking-postgres pg_dump -U postgres doctor_booking | gzip > /backups/db-$(date +%Y%m%d).sql.gz
```

## Scaling

### Horizontal API scaling
```yaml
# docker-compose.yml
api:
  deploy:
    replicas: 3
```

### Future: Redis for session/cache
When scaling to multiple API instances:
1. Add Redis service to docker-compose
2. Use Redis for slot lock state (instead of DB)
3. Use Redis for rate limiting state

### Future: Read replica
1. Add `DATABASE_URL_REPLICA` for read-only queries
2. Route `SELECT` queries via Prisma to replica
