# Deployment Guide

This guide covers deploying the Zig CRUD API to production environments.

## Table of Contents

1. [Production Checklist](#production-checklist)
2. [Docker Deployment](#docker-deployment)
3. [Cloud Deployment](#cloud-deployment)
4. [Environment Configuration](#environment-configuration)
5. [Security Hardening](#security-hardening)
6. [Monitoring & Logging](#monitoring--logging)
7. [Backup & Recovery](#backup--recovery)
8. [Performance Tuning](#performance-tuning)

## Production Checklist

Before deploying to production, ensure:

- [ ] Environment variables configured
- [ ] Database migrations run
- [ ] SSL/TLS certificates installed
- [ ] Firewall rules configured
- [ ] Backup strategy implemented
- [ ] Monitoring setup
- [ ] Load testing completed
- [ ] Security audit performed
- [ ] Documentation updated
- [ ] Rollback plan ready

## Docker Deployment

### Build Production Image

```bash
# Build optimized image
docker build -t zig-crud-api:latest .

# Tag for registry
docker tag zig-crud-api:latest your-registry.com/zig-crud-api:v1.0.0

# Push to registry
docker push your-registry.com/zig-crud-api:v1.0.0
```

### Docker Compose Production Setup

Create `docker-compose.prod.yml`:

```yaml
version: '3.8'

services:
  api:
    image: your-registry.com/zig-crud-api:v1.0.0
    restart: always
    ports:
      - "8080:8080"
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=${REDIS_URL}
      - PORT=8080
    depends_on:
      - postgres
      - redis
    networks:
      - app-network
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: '1'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M

  postgres:
    image: postgres:18-alpine
    restart: always
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./migrations:/docker-entrypoint-initdb.d:ro
    networks:
      - app-network
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G

  redis:
    image: redis:8-alpine
    restart: always
    command: redis-server --requirepass ${REDIS_PASSWORD} --maxmemory 256mb --maxmemory-policy allkeys-lru
    volumes:
      - redis_data:/data
    networks:
      - app-network
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M

  nginx:
    image: nginx:alpine
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - api
    networks:
      - app-network

volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local

networks:
  app-network:
    driver: bridge
```

### Nginx Configuration

Create `nginx.conf`:

```nginx
events {
    worker_connections 1024;
}

http {
    upstream api_backend {
        least_conn;
        server api:8080 max_fails=3 fail_timeout=30s;
    }

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
    limit_conn_zone $binary_remote_addr zone=addr:10m;

    server {
        listen 80;
        server_name your-domain.com;
        
        # Redirect to HTTPS
        return 301 https://$server_name$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name your-domain.com;

        # SSL Configuration
        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;

        # Security Headers
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;

        # Logging
        access_log /var/log/nginx/api_access.log;
        error_log /var/log/nginx/api_error.log;

        # Rate limiting
        limit_req zone=api_limit burst=20 nodelay;
        limit_conn addr 10;

        location / {
            proxy_pass http://api_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Timeouts
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }

        location /health {
            proxy_pass http://api_backend/health;
            access_log off;
        }
    }
}
```

### Deploy with Docker Compose

```bash
# Create production environment file
cp .env.example .env.prod
# Edit .env.prod with production values

# Deploy
docker compose -f docker-compose.prod.yml up -d

# View logs
docker compose -f docker-compose.prod.yml logs -f

# Scale API instances
docker compose -f docker-compose.prod.yml up -d --scale api=5
```

## Cloud Deployment

### AWS EC2 Deployment

#### 1. Launch EC2 Instance

```bash
# Use Amazon Linux 2 or Ubuntu 22.04 LTS
# Instance type: t3.medium or larger
# Security group: Allow ports 80, 443, 22
```

#### 2. Install Dependencies

```bash
# Update system
sudo yum update -y  # Amazon Linux
# or
sudo apt update && sudo apt upgrade -y  # Ubuntu

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker
```

#### 3. Deploy Application

```bash
# Clone repository
git clone <your-repo>
cd learn-zig

# Configure environment
sudo nano .env.prod

# Deploy
sudo docker compose -f docker-compose.prod.yml up -d
```

#### 4. Setup SSL with Let's Encrypt

```bash
# Install certbot
sudo yum install certbot python3-certbot-nginx  # Amazon Linux
# or
sudo apt install certbot python3-certbot-nginx  # Ubuntu

# Obtain certificate
sudo certbot --nginx -d your-domain.com

# Auto-renewal
sudo systemctl enable certbot.timer
```

### AWS ECS Deployment

#### 1. Create Task Definition

```json
{
  "family": "zig-crud-api",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "containerDefinitions": [
    {
      "name": "api",
      "image": "your-registry/zig-crud-api:latest",
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "PORT",
          "value": "8080"
        }
      ],
      "secrets": [
        {
          "name": "DATABASE_URL",
          "valueFrom": "arn:aws:secretsmanager:region:account:secret:db-url"
        },
        {
          "name": "REDIS_URL",
          "valueFrom": "arn:aws:secretsmanager:region:account:secret:redis-url"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/zig-crud-api",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "api"
        }
      }
    }
  ]
}
```

#### 2. Create ECS Service

```bash
aws ecs create-service \
  --cluster production \
  --service-name zig-crud-api \
  --task-definition zig-crud-api:1 \
  --desired-count 3 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx],assignPublicIp=ENABLED}" \
  --load-balancers "targetGroupArn=arn:aws:elasticloadbalancing:...,containerName=api,containerPort=8080"
```

### Google Cloud Run

```bash
# Build and push to GCR
gcloud builds submit --tag gcr.io/PROJECT_ID/zig-crud-api

# Deploy to Cloud Run
gcloud run deploy zig-crud-api \
  --image gcr.io/PROJECT_ID/zig-crud-api \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars DATABASE_URL=postgresql://... \
  --set-env-vars REDIS_URL=redis://... \
  --memory 512Mi \
  --cpu 1 \
  --min-instances 1 \
  --max-instances 10
```

### Kubernetes Deployment

Create `k8s/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zig-crud-api
  labels:
    app: zig-crud-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: zig-crud-api
  template:
    metadata:
      labels:
        app: zig-crud-api
    spec:
      containers:
      - name: api
        image: your-registry/zig-crud-api:latest
        ports:
        - containerPort: 8080
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: api-secrets
              key: database-url
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: api-secrets
              key: redis-url
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: zig-crud-api
spec:
  selector:
    app: zig-crud-api
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
  type: LoadBalancer
```

Deploy:

```bash
kubectl apply -f k8s/deployment.yaml
kubectl get services zig-crud-api
```

## Environment Configuration

### Production Environment Variables

Create `.env.prod`:

```env
# Database
DATABASE_URL=postgresql://user:password@postgres-host:5432/crud_api?sslmode=require

# Redis
REDIS_URL=redis://:password@redis-host:6379

# Server
PORT=8080

# Optional: Connection pool size
DB_POOL_SIZE=10
```

### Secrets Management

#### AWS Secrets Manager

```bash
# Store secret
aws secretsmanager create-secret \
  --name prod/api/database-url \
  --secret-string "postgresql://..."

# Retrieve in application
# Use AWS SDK or environment variables from ECS/Lambda
```

#### HashiCorp Vault

```bash
# Store secret
vault kv put secret/api/prod database_url="postgresql://..."

# Retrieve
vault kv get -field=database_url secret/api/prod
```

## Security Hardening

### 1. Use Strong Passwords

```bash
# Generate secure passwords
openssl rand -base64 32
```

### 2. Enable SSL/TLS

```nginx
# Enforce HTTPS
server {
    listen 80;
    return 301 https://$server_name$request_uri;
}
```

### 3. Firewall Configuration

```bash
# UFW (Ubuntu)
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# AWS Security Group
# Inbound rules:
# - SSH (22) from your IP only
# - HTTP (80) from 0.0.0.0/0
# - HTTPS (443) from 0.0.0.0/0
# - PostgreSQL (5432) from API security group only
```

### 4. Database Security

```sql
-- Create read-only user for reporting
CREATE USER readonly WITH PASSWORD 'secure_password';
GRANT CONNECT ON DATABASE crud_api TO readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly;

-- Create application user with limited permissions
CREATE USER api_user WITH PASSWORD 'secure_password';
GRANT CONNECT ON DATABASE crud_api TO api_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO api_user;
```

### 5. Redis Security

```conf
# redis.conf
requirepass your_strong_password
bind 127.0.0.1 ::1
protected-mode yes
```

### 6. Rate Limiting

Implement in Nginx (shown above) or application level.

## Monitoring & Logging

### Prometheus Metrics

Add metrics endpoint to your application:

```zig
// Future enhancement
// Expose /metrics endpoint with:
// - Request count
// - Response time
// - Error rate
// - Database connection pool stats
```

### Logging Setup

#### Centralized Logging with ELK Stack

```yaml
# docker-compose.logging.yml
version: '3.8'

services:
  elasticsearch:
    image: elasticsearch:8.11.0
    environment:
      - discovery.type=single-node
    volumes:
      - es_data:/usr/share/elasticsearch/data
    
  logstash:
    image: logstash:8.11.0
    volumes:
      - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf
    depends_on:
      - elasticsearch
  
  kibana:
    image: kibana:8.11.0
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch

volumes:
  es_data:
```

#### CloudWatch (AWS)

```bash
# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
sudo rpm -U ./amazon-cloudwatch-agent.rpm

# Configure
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json
```

### Health Checks

```bash
# Create health check script
#!/bin/bash
HEALTH_URL="http://localhost:8080/health"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $HEALTH_URL)

if [ $RESPONSE -eq 200 ]; then
    echo "OK"
    exit 0
else
    echo "FAIL: HTTP $RESPONSE"
    exit 1
fi
```

## Backup & Recovery

### Database Backups

#### Automated PostgreSQL Backups

```bash
#!/bin/bash
# backup.sh

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/postgres"
DB_NAME="crud_api"

# Create backup
docker compose exec -T postgres pg_dump -U postgres $DB_NAME | gzip > $BACKUP_DIR/backup_$DATE.sql.gz

# Delete backups older than 30 days
find $BACKUP_DIR -name "backup_*.sql.gz" -mtime +30 -delete

# Upload to S3
aws s3 cp $BACKUP_DIR/backup_$DATE.sql.gz s3://your-backup-bucket/postgres/
```

#### Cron Job

```bash
# Add to crontab
crontab -e

# Daily backup at 2 AM
0 2 * * * /path/to/backup.sh >> /var/log/backup.log 2>&1
```

### Database Restore

```bash
# Restore from backup
gunzip -c backup_20240101_020000.sql.gz | \
docker compose exec -T postgres psql -U postgres -d crud_api
```

### Redis Persistence

```conf
# redis.conf
save 900 1      # Save after 900 seconds if at least 1 key changed
save 300 10     # Save after 300 seconds if at least 10 keys changed
save 60 10000   # Save after 60 seconds if at least 10000 keys changed

appendonly yes  # Enable AOF persistence
```

## Performance Tuning

### PostgreSQL Optimization

```sql
-- postgresql.conf
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 4MB
min_wal_size = 1GB
max_wal_size = 4GB
```

### Redis Optimization

```conf
# redis.conf
maxmemory 256mb
maxmemory-policy allkeys-lru
tcp-backlog 511
timeout 300
tcp-keepalive 300
```

### Application Tuning

Increase connection pool size:

```zig
// In main.zig
const pg_pool = try PgPool.init(allocator, cfg.database_url, 20); // Increased from 5
```

## Troubleshooting

### Common Issues

#### High Memory Usage

```bash
# Check memory usage
docker stats

# Limit container memory
docker update --memory 512m container_name
```

#### Database Connection Pool Exhausted

```bash
# Check active connections
docker compose exec postgres psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"

# Increase pool size in application
```

#### Cache Not Working

```bash
# Check Redis connectivity
docker compose exec api redis-cli -h redis ping

# Monitor cache hits/misses
docker compose exec redis redis-cli INFO stats
```

## Rollback Strategy

### Docker Rollback

```bash
# Keep previous images
docker tag zig-crud-api:latest zig-crud-api:previous

# Rollback
docker compose -f docker-compose.prod.yml down
docker tag zig-crud-api:previous zig-crud-api:latest
docker compose -f docker-compose.prod.yml up -d
```

### Database Migration Rollback

Create down migrations for each up migration:

```sql
-- migrations/001_create_users_table.down.sql
DROP INDEX IF EXISTS idx_users_email;
DROP TABLE IF EXISTS users;
```

## Maintenance Windows

### Schedule Maintenance

```bash
# Announce maintenance 24-48 hours in advance
# Update during low traffic periods (2-4 AM)

# Example maintenance script
#!/bin/bash
echo "Starting maintenance..."

# Stop traffic (update load balancer or use maintenance page)
# Update application
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d

# Run migrations
docker compose -f docker-compose.prod.yml exec postgres psql -U postgres -d crud_api < migrations/new_migration.sql

# Verify health
curl http://localhost:8080/health

# Resume traffic
echo "Maintenance complete"
```

---

**For support, contact your DevOps team or open an issue on GitHub.**