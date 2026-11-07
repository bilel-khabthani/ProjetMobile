FROM laravelsail/php84-composer:latest

RUN apt-get update \
    && apt-get install -y --no-install-recommends libpq-dev \
    && docker-php-ext-install pdo_pgsql \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html

COPY docker/entrypoint.sh /usr/local/bin/lostfound-entrypoint
RUN chmod +x /usr/local/bin/lostfound-entrypoint

ENTRYPOINT ["lostfound-entrypoint"]
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]
