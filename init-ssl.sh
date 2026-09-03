#!/bin/bash

set -e

# .env fayldan o'qish
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

DOMAIN="${DOMAIN:?Error: DOMAIN is not set in .env}"
EMAIL="${EMAIL:?Error: EMAIL is not set in .env}"

echo "========================================="
echo "  SSL Setup for: $DOMAIN"
echo "  Email: $EMAIL"
echo "========================================="

# 1. Dummy sertifikat yaratish (nginx start bo'lishi uchun)
echo ""
echo "[1/4] Creating dummy certificate..."
docker compose run --rm --entrypoint "" certbot sh -c "
  mkdir -p /etc/letsencrypt/live/$DOMAIN &&
  openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
    -keyout /etc/letsencrypt/live/$DOMAIN/privkey.pem \
    -out /etc/letsencrypt/live/$DOMAIN/fullchain.pem \
    -subj '/CN=localhost'
"

# 2. Nginx'ni ishga tushirish
echo ""
echo "[2/4] Starting nginx..."
docker compose up -d react-app
sleep 3

# 3. Dummy sertifikatni o'chirish
echo ""
echo "[3/4] Removing dummy certificate..."
docker compose run --rm --entrypoint "" certbot sh -c "
  rm -rf /etc/letsencrypt/live/$DOMAIN &&
  rm -rf /etc/letsencrypt/archive/$DOMAIN &&
  rm -rf /etc/letsencrypt/renewal/$DOMAIN.conf
"

# 4. Haqiqiy sertifikat olish
echo ""
echo "[4/4] Requesting real certificate from Let's Encrypt..."
docker compose run --rm certbot certonly \
  --webroot \
  --webroot-path /var/www/certbot \
  --email "$EMAIL" \
  --agree-tos \
  --no-eff-email \
  -d "$DOMAIN"

# 5. Nginx reload
echo ""
echo "Reloading nginx..."
docker compose exec react-app nginx -s reload

echo ""
echo "========================================="
echo "  SSL setup complete!"
echo "  https://$DOMAIN"
echo "========================================="

# Certbot auto-renew container'ni ishga tushirish
docker compose up -d certbot
