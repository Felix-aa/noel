FROM php:8.1-fpm

ENV DEBIAN_FRONTEND=noninteractive

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# add basic tools
RUN set -e && \
    apt-get update && \
    apt-get upgrade -y --no-install-recommends && \
    apt-get auto-remove -y && \
    apt-get install -y --no-install-recommends ssh bash vim git unzip nginx supervisor cron libicu-dev libssl-dev && \
    docker-php-ext-install intl && \
    docker-php-ext-install pdo_mysql && \
    docker-php-ext-install opcache

    
# Install Symfony CLI
RUN curl -sS https://get.symfony.com/cli/installer | bash && \
    mv /root/.symfony5/bin/symfony /usr/local/bin/symfony

# Configure supervisord
COPY docker/supervisord.conf /etc/supervisor/supervisord.conf

# Install packages and remove default server definition
RUN rm /etc/nginx/sites-available/default  ; \
    rm /etc/nginx/sites-enabled/default

# Configure nginx
COPY docker/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY docker/fpm-pool.conf /usr/local/etc/php-fpm.conf

#Install Xdebug
RUN pecl install xdebug && \
    docker-php-ext-enable xdebug
COPY docker/docker-php-ext-xdebug.ini "$PHP_INI_DIR/conf.d/docker-php-ext-xdebug.ini"

# Configure PHP
COPY docker/php.ini "$PHP_INI_DIR/php.ini"

# Setup document root
RUN mkdir -p /app

# Add application
COPY . /app

# Set Workdir to new app folder
WORKDIR /app

# pull in dependencies
RUN composer --working-dir=/app install -o

# Expose the port nginx is reachable on
EXPOSE 80

# Set up wait-for-it script
COPY docker/wait-for-it.sh /usr/local/bin
RUN chmod +x /usr/local/bin/wait-for-it.sh

# Trigger entrypoint script
COPY docker/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
RUN ln -s /usr/local/bin/docker-entrypoint.sh / # backwards compat
CMD ["docker-entrypoint.sh"]

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:80/fpm-ping
