# Download koel's released archive
FROM alpine:3.13.2 as release-downloader

# The koel version to download
ARG KOEL_VERSION_REF=v5.0.2

# Install curl to download the release tar.gz
RUN apk add --no-cache curl

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
    composer.lock \
    cypress \
    cypress.json \
    nginx.conf.example \
    package.json \
    phpstan.neon.dist \
    phpunit.xml.dist \
    resources/artifacts/ \
    resources/assets/ \
    ruleset.xml \
    tag.sh \
    tests \
    webpack.config.js \
    webpack.mix.js \
    yarn.lock

# The runtime image.
FROM php:fpm

# Install koel runtime dependencies.
RUN apt-get update && \
  apt-get install --yes --no-install-recommends \
    rsync \
    libapache2-mod-xsendfile \
    libzip-dev \
    zip \
    ffmpeg \
    libpng-dev \
    libjpeg62-turbo-dev \
  && docker-php-ext-configure gd --with-jpeg \
  # https://laravel.com/docs/8.x/deployment#server-requirements
  # ctype, fileinfo, json, mbstring, openssl, PDO, tokenizer and xml are already activated in the base image
  && docker-php-ext-install \
    bcmath \
    exif \
    gd \
    pdo_mysql \
    zip \
  && apt-get clean \
  # Create the music volume so it has the correct permissions
  && mkdir /music \
  && chown www-data:www-data /music

# Copy php.ini
COPY ./php.ini "$PHP_INI_DIR/php.ini"
# /usr/local/etc/php/php.ini

# Copy the downloaded release
COPY --from=release-downloader --chown=www-data:www-data /tmp/koel /tmp/koel

# Volumes for the music files and search index
# This declaration must be AFTER creating the folders and setting their permissions
# and AFTER changing to non-root user.
# Otherwise, they are owned by root and the user cannot write to them.
VOLUME ["/music", "/var/www/koel/storage/search-indexes", "/var/www/koel"]

ENV FFMPEG_PATH=/usr/bin/ffmpeg \
    MEDIA_PATH=/music \
    STREAMING_METHOD=x-accel-redirect

# Setup bootstrap script.
COPY koel-entrypoint /usr/local/bin/
ENTRYPOINT ["koel-entrypoint"]
CMD ["php-fpm"]
