# docker-apache-php

Docker image for running Apache + PHP with standard set of modules.

Inspired by the official Wordpress Dockerfile.

Ships Composer, plus the following additional PHP extensions:

* imagick
* gd
* pdo_mysql
* mysqli
* opcache
* bcmath
* exif
* zip

We also enable the expires, headers and remoteip Apache2 modules, and log X-Forwarded-For IP.