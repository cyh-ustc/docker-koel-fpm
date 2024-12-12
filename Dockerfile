# The runtime image.
FROM php:8.2-fpm

# The koel version to download
ARG KOEL_VERSION_REF=v7.2.0

# Install vim for easier editing/debugging
RUN apt-get update && apt-get install -y vim

# Download the koel release matching the version and remove anything not necessary for production
RUN curl -L https://github.com/koel/koel/releases/download/${KOEL_VERSION_REF}/koel-${KOEL_VERSION_REF}.tar.gz | tar -xz -C /tmp \
  && cd /tmp/koel/ \
  && rm -rf .editorconfig \
    .eslintignore \
    .eslintrc \
    .git \
    .gitattributes \
    .github \
    .gitignore \
    .gitmodules \
    .gitpod.dockerfile \
    .gitpod.yml \
    api-docs \
    cypress \
    cypress.json \
    nginx.conf.example \
    package.json \
    phpstan.neon.dist \
    phpunit.xml.dist \
    resources/artifacts/ \
    ruleset.xml \
    scripts/ \
    tag.sh \
    vite.config.js


# Install koel runtime dependencies.
RUN apt-get update \
  && apt-get install --yes --no-install-recommends \
    cron \
    libapache2-mod-xsendfile \
    libzip-dev \
    zip \
    ffmpeg \
    rsync \
    locales \
    libpng-dev \
    libjpeg62-turbo-dev \
    libpq-dev \
    libwebp-dev \
  && docker-php-ext-configure gd --with-jpeg --with-webp \
  # https://laravel.com/docs/8.x/deployment#server-requirements
  # ctype, fileinfo, json, mbstring, openssl, tokenizer and xml are already activated in the base image
  && docker-php-ext-install \
    bcmath \
    exif \
    gd \
    pdo \
    pdo_mysql \
    pdo_pgsql \
    pgsql \
    zip \
  && apt-get clean \
  # Create the music volume so it has the correct permissions
  && mkdir /music \
  && chown www-data:www-data /music \
  # Create the search-indexes volume so it has the correct permissions
  && mkdir -p /var/www/koel/storage/search-indexes \
  && chown www-data:www-data /var/www/koel/storage/search-indexes \
  # Set locale to prevent removal of non-ASCII path characters when transcoding with ffmpeg
  # See https://github.com/koel/docker/pull/91
  && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
  && /usr/sbin/locale-gen

# Copy php.ini
COPY ./php.ini "$PHP_INI_DIR/php.ini"
# /usr/local/etc/php/php.ini

# Copy the downloaded release
RUN chown -R www-data:www-data /tmp/koel/ \
  && mkdir -p /var/www/koel \
  && chown -R www-data:www-data /var/www/koel

# Volumes for the music files and search index
# This declaration must be AFTER creating the folders and setting their permissions
# and AFTER changing to non-root user.
# Otherwise, they are owned by root and the user cannot write to them.
VOLUME ["/music", "/var/www/koel/storage/search-indexes"]

ENV FFMPEG_PATH=/usr/bin/ffmpeg \
    MEDIA_PATH=/music \
    STREAMING_METHOD=x-accel-redirect \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Setup bootstrap script.
COPY koel-entrypoint /usr/local/bin/
ENTRYPOINT ["koel-entrypoint"]
CMD ["php-fpm"]

# Check that the homepage is displayed
HEALTHCHECK --interval=5m --timeout=5s \
  CMD curl -f http://localhost:9000/sw.js || exit 1
