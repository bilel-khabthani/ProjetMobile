#!/bin/sh

set -e

cd /var/www/html

if [ ! -d vendor ]; then
    echo "Installing Composer dependencies..."
    composer install --no-interaction --prefer-dist --no-progress
fi

if [ ! -f .env ]; then
    echo "Creating .env from .env.example..."
    cp .env.example .env
fi

if ! grep -q '^APP_KEY=base64:' .env; then
    echo "Generating application key..."
    php artisan key:generate --force --no-interaction
fi

exec "$@"
