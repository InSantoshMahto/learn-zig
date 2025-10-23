#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Zig CRUD API with PostgreSQL & Redis      ║${NC}"
echo -e "${GREEN}║            Setup Script                      ║${NC}"
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose is not installed. Please install Docker Compose first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker and Docker Compose are installed${NC}"
echo ""

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo -e "${YELLOW}Creating .env file...${NC}"
    cat > .env << EOF
DATABASE_URL=postgres://postgres:password@localhost:5432/crud_api
REDIS_URL=redis://localhost:6379
PORT=8080
EOF
    echo -e "${GREEN}✓ .env file created${NC}"
else
    echo -e "${YELLOW}⚠ .env file already exists, skipping...${NC}"
fi

echo ""

# Start Docker Compose services
echo -e "${YELLOW}Starting PostgreSQL and Redis services...${NC}"
docker compose up -d

# Wait for services to be ready
echo -e "${YELLOW}Waiting for services to be ready...${NC}"
sleep 5

# Check PostgreSQL
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker compose exec -T postgres pg_isready -U postgres &> /dev/null; then
        echo -e "${GREEN}✓ PostgreSQL is ready${NC}"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo -e "${YELLOW}Waiting for PostgreSQL... ($RETRY_COUNT/$MAX_RETRIES)${NC}"
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}❌ PostgreSQL failed to start${NC}"
    exit 1
fi

# Check Redis
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker compose exec -T redis redis-cli ping &> /dev/null; then
        echo -e "${GREEN}✓ Redis is ready${NC}"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo -e "${YELLOW}Waiting for Redis... ($RETRY_COUNT/$MAX_RETRIES)${NC}"
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}❌ Redis failed to start${NC}"
    exit 1
fi

echo ""

# Run migrations
echo -e "${YELLOW}Running database migrations...${NC}"
docker compose exec -T postgres psql -U postgres -d crud_api < migrations/001_create_users_table.sql

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Migrations completed successfully${NC}"
else
    echo -e "${RED}❌ Migrations failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Setup Completed Successfully!        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Services running:${NC}"
echo -e "  PostgreSQL: ${GREEN}localhost:5432${NC}"
echo -e "  Redis:      ${GREEN}localhost:6379${NC}"
echo ""
echo -e "${YELLOW}Database credentials:${NC}"
echo -e "  User:     ${GREEN}postgres${NC}"
echo -e "  Password: ${GREEN}password${NC}"
echo -e "  Database: ${GREEN}crud_api${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Build the application: ${GREEN}zig build${NC}"
echo -e "  2. Run the application:   ${GREEN}zig build run${NC}"
echo -e "  3. Test the API:          ${GREEN}make curl-test${NC}"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo -e "  View logs:        ${GREEN}docker compose logs -f${NC}"
echo -e "  Stop services:    ${GREEN}docker compose down${NC}"
echo -e "  Database console: ${GREEN}make db-connect${NC}"
echo -e "  Redis console:    ${GREEN}make redis-cli${NC}"
echo ""
