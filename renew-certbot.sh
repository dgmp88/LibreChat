#!/bin/bash

# Certbot renewal script for LibreChat
# This script follows the steps documented in my-readme.md

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/deploy-compose.yml"

echo "=========================================="
echo "Certbot Renewal Script"
echo "=========================================="
echo ""

# Step 1: Docker compose down
echo "[1/4] Stopping Docker Compose..."
cd "$SCRIPT_DIR"
if docker compose -f "$COMPOSE_FILE" ps -q | grep -q .; then
    docker compose -f "$COMPOSE_FILE" down
    echo "✓ Docker Compose stopped"
else
    echo "✓ Docker Compose was already stopped"
fi
echo ""

# Step 2: Stop nginx (pain in the arse - try multiple methods)
echo "[2/4] Stopping nginx (trying multiple methods)..."
sudo systemctl stop nginx 2>/dev/null || echo "  - systemctl stop: nginx not running via systemctl"
sudo nginx -s quit 2>/dev/null || echo "  - nginx -s quit: no nginx process found"
sudo nginx -s stop 2>/dev/null || echo "  - nginx -s stop: no nginx process found"
sudo /etc/init.d/nginx stop 2>/dev/null || echo "  - init.d stop: nginx not running via init.d"

# Wait a moment for processes to stop
sleep 2

# Check if anything is still using port 80
if sudo lsof -i :80 >/dev/null 2>&1; then
    echo "  Warning: Port 80 is still in use. Attempting to kill processes..."
    sudo lsof -i :80 | grep -v COMMAND | awk '{print $2}' | sort -u | while read pid; do
        if [ ! -z "$pid" ]; then
            echo "    Killing process $pid"
            sudo kill -9 "$pid" 2>/dev/null || true
        fi
    done
    sleep 2
fi

# Final check
if sudo lsof -i :80 >/dev/null 2>&1; then
    echo "  ⚠ Warning: Port 80 may still be in use. Check manually with: sudo lsof -i :80"
else
    echo "✓ Port 80 is free"
fi
echo ""

# Step 3: Renew certbot
echo "[3/4] Renewing certificates with certbot..."
if sudo certbot renew; then
    echo "✓ Certificates renewed successfully"
else
    echo "✗ Certbot renewal failed!"
    exit 1
fi
echo ""

# Step 4: Stop nginx again (certbot may have started it)
echo "[4/4] Ensuring nginx is stopped (certbot may have restarted it)..."
sudo systemctl stop nginx 2>/dev/null || true
sleep 2

# Kill any nginx processes that might be holding port 80
if sudo lsof -i :80 >/dev/null 2>&1; then
    echo "  Killing nginx processes holding port 80..."
    sudo pkill -9 nginx 2>/dev/null || true
    sleep 2
fi

# Step 5: Restart Docker Compose
echo "[5/5] Restarting Docker Compose..."
cd "$SCRIPT_DIR"
if docker compose -f "$COMPOSE_FILE" up -d; then
    echo "✓ Docker Compose started successfully"
else
    echo "✗ Failed to start Docker Compose!"
    exit 1
fi
echo ""

# Final status check
echo "=========================================="
echo "Final Status Check"
echo "=========================================="
docker compose -f "$COMPOSE_FILE" ps
echo ""

# Check if port 80 is now bound by docker
if docker ps --format '{{.Names}}' | grep -q LibreChat-NGINX; then
    echo "✓ LibreChat-NGINX container is running"
else
    echo "⚠ Warning: LibreChat-NGINX container may not be running"
fi

echo ""
echo "=========================================="
echo "Certbot renewal completed!"
echo "=========================================="

