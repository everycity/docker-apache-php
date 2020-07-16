ARG phpver

FROM php:${phpver}-apache-buster

# Update and install software
RUN set -ex; \
        \
        apt-get update; \
        apt-get upgrade -y; \
        apt-get install -y \
                msmtp \
                vim \
                telnet \
                unzip \
                mariadb-client \
                wget \
                curl \
                ghostscript \
                fonts-dejavu-core \
                gsfonts \
                fontconfig

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Sort out the env a bit
RUN a2enmod headers

# Email would be useful
COPY msmtprc /etc/msmtprc
COPY php-uploads.ini /usr/local/etc/php/conf.d/uploads.ini
COPY php-sendmail.ini /usr/local/etc/php/conf.d/sendmail.ini

# Most PHP apps need useful extensions, like ImageMagick and what not
# This is inspired from the Wordpress Dockerfile

# https://github.com/docker-library/wordpress/blob/master/php7.2/apache/Dockerfile

RUN echo "a_phpver: ${phpver}"
ENV PHP_VER $phpver
RUN echo "b_phpver: ${phpver}"
RUN echo "b_PHP_VER: ${PHP_VER}"
RUN echo "PHP_VERSION: ${PHP_VERSION}"


# install the PHP extensions we need (https://make.wordpress.org/hosting/handbook/handbook/server-environment/#php-extensions)
RUN set -ex; \
        \
        savedAptMark="$(apt-mark showmanual)"; \
        \
        apt-get update; \
        apt-get install -y --no-install-recommends \
                libfreetype6-dev \
                libjpeg-dev \
                libmagickwand-dev \
                libpng-dev \
                libpq-dev \
                libzip-dev \
                libzip4 \
        ; \
        \
	if [ "x$PHP_VER" = "x7.4" ] ; then \
	        docker-php-ext-configure gd --with-freetype --with-jpeg; \
	else \
		docker-php-ext-configure gd --with-freetype-dir=/usr --with-jpeg-dir=/usr --with-png-dir=/usr; \
	fi; \
	\
        docker-php-ext-install -j "$(nproc)" \
                bcmath \
                exif \
                gd \
                pdo_mysql \
                mysqli \
                opcache \
                zip \
        ; \
        pecl install imagick-3.4.4; \
        docker-php-ext-enable imagick; \
        \
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
        apt-mark auto '.*' > /dev/null; \
        apt-mark manual $savedAptMark; \
        ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
                | awk '/=>/ { print $3 }' \
                | sort -u \
                | xargs -r dpkg-query -S \
                | cut -d: -f1 \
                | sort -u \
                | xargs -rt apt-mark manual; \
        \
        apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
        rm -rf /var/lib/apt/lists/*

# Configure PHP Opcache
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
                echo 'opcache.memory_consumption=128'; \
                echo 'opcache.interned_strings_buffer=8'; \
                echo 'opcache.max_accelerated_files=4000'; \
                echo 'opcache.revalidate_freq=2'; \
                echo 'opcache.fast_shutdown=1'; \
        } > /usr/local/etc/php/conf.d/opcache-recommended.ini

# Log the X-Forwarded-For header
RUN set -eux; \
        a2enmod rewrite expires; \
        \
# https://httpd.apache.org/docs/2.4/mod/mod_remoteip.html
        a2enmod remoteip; \
        { \
                echo 'RemoteIPHeader X-Forwarded-For'; \
# these IP ranges are reserved for "private" use and should thus *usually* be safe inside Docker
                echo 'RemoteIPTrustedProxy 10.0.0.0/8'; \
                echo 'RemoteIPTrustedProxy 172.16.0.0/12'; \
                echo 'RemoteIPTrustedProxy 192.168.0.0/16'; \
                echo 'RemoteIPTrustedProxy 169.254.0.0/16'; \
                echo 'RemoteIPTrustedProxy 127.0.0.0/8'; \
        } > /etc/apache2/conf-available/remoteip.conf; \
        a2enconf remoteip; \
# https://github.com/docker-library/wordpress/issues/383#issuecomment-507886512
# (replace all instances of "%h" with "%a" in LogFormat)
        find /etc/apache2 -type f -name '*.conf' -exec sed -ri 's/([[:space:]]*LogFormat[[:space:]]+"[^"]*)%h([^"]*")/\1%a\2/g' '{}' +

# Fix homedir
RUN sed -i 's/\/var\/www:/\/var\/www\/html:/g' /etc/passwd

# vim:set ft=dockerfile:
