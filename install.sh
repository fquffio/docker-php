#!/bin/bash
set -e

if [[ -z "$1" ]]; then
    echo 'Missing PHP version!'
    exit 1
fi
phpVersion="$1"

###########################################################
### List of dependencies and extensions to be installed ###
###########################################################
buildDeps=" \
    libbz2-dev \
    libmemcached-dev \
    libsasl2-dev \
"
runtimeDeps=" \
    curl \
    git \
    libfreetype6-dev \
    libicu-dev \
    libjpeg-dev \
    libldap2-dev \
    libmemcachedutil2 \
    libpq-dev \
    libxml2-dev \
"
pearExtensions=" \
    bcmath \
    bz2 \
    calendar \
    iconv \
    intl \
    mbstring \
    mysqli \
    pdo_mysql \
    pdo_pgsql \
    pgsql \
    soap \
    zip \
"
peclExtensions=" \
    redis \
"

#####################################
### Version-specific adjustements ###
#####################################
if [[ $phpVersion != "5.4."* ]]; then
    # PHP > 5.4
    pearExtensions="${pearExtensions} opcache"
fi
if [[ $phpVersion == "5."* ]]; then
    # PHP 5.x
    runtimeDeps="${runtimeDeps} php-pear"
    pearExtensions="${pearExtensions} mysql"
    peclExtensions="${peclExtensions} memcached-2.2.0"
else
    # PHP 7.x
    peclExtensions="${peclExtensions} memcached"
fi
if [[ $phpVersion != "7.2."* ]]; then
    # PHP < 7.2
    buildDeps="${buildDeps} libmysqlclient-dev"
    runtimeDeps="${runtimeDeps} libmcrypt-dev libpng12-dev"
    pearExtensions="${pearExtensions} mcrypt"
else
    # PHP 7.2
    buildDeps="${buildDeps} default-libmysqlclient-dev"
    runtimeDeps="${runtimeDeps} libpng-dev"
fi

#############
### Debug ###
#############
echo "BUILD DEPENDENCIES   : ${buildDeps}"
echo "RUNTIME DEPENDENCIES : ${runtimeDeps}"
echo "PEAR EXTENSIONS      : ${pearExtensions}"
echo "PECL EXTENSIONS      : ${peclExtensions}"

####################
### APT Packages ###
####################
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y $buildDeps $runtimeDeps

#######################
### PEAR Extensions ###
#######################
docker-php-ext-install $pearExtensions
docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/
docker-php-ext-install gd
docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/
docker-php-ext-install ldap

#######################
### PECL Extensions ###
#######################
pecl install $peclExtensions
docker-php-ext-enable memcached.so redis.so

###############
### Cleanup ###
###############
apt-get purge -y --auto-remove $buildDeps
rm -r /var/lib/apt/lists/*

##########################
### Apache mod_rewrite ###
##########################
if [[ `command -v a2enmod` ]]; then
    a2enmod rewrite
fi

################
### Composer ###
################
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
