# Revive Adserver Docker Image
# PHP 8.1 + Nginx + PHP-FPM for GCP Cloud Run deployment

FROM php:8.1-fpm-alpine

# Install system dependencies
RUN apk add --no-cache \
    nginx \
    supervisor \
    freetype-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libwebp-dev \
    libzip-dev \
    icu-dev \
    libxml2-dev \
    oniguruma-dev \
    curl \
    git \
    unzip

# Install PHP extensions required by Revive Adserver
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) \
    gd \
    intl \
    mysqli \
    pdo \
    pdo_mysql \
    zip \
    xml \
    mbstring \
    opcache

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy application files
COPY . .

# Install Composer dependencies (production only)
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Copy Nginx configuration
COPY docker/nginx.conf /etc/nginx/http.d/default.conf

# Copy PHP configuration
COPY docker/php-fpm.ini /usr/local/etc/php/conf.d/custom.ini

# Copy Supervisor configuration
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html \
    && chmod -R 777 /var/www/html/var

# Create required directories
RUN mkdir -p /var/www/html/var/cache \
    /var/www/html/var/plugins \
    /var/www/html/var/templates_compiled \
    /run/nginx \
    && chmod -R 777 /var/www/html/var

# Cloud Run uses PORT environment variable
ENV PORT=8080

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# Start Supervisor (manages both nginx and php-fpm)
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
