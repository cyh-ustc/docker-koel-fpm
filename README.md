docker-koel-fpm
===========

A docker image with only the bare essentials needed to run [koel]. It includes a php-fpm runtime with required extensions.

It can be serverd by an nginx container.

## Usage

/!\ This container does not include a database. It **requires** another container to handle the database.

Since [Koel supports many databases][koel-requirements] you are free to choose any Docker image that hosts one of those databases.

docker-koel-fpm (this image) has only been tested with MySQL, so we'll use MySQL in examples below.

(I have tried sqlite but failed to login)


### Build docker

```bash
docker build -t koel:fpm .
```

### First run

On the first run, you will need to:

1. Generate `APP_KEY`
2. Create an admin user
3. Initialize the database

All these steps are achieved by running `koel:init` once:

Replace `<container_name_for_koel>` in the command by the actual container name.

```bash
docker exec -it <container_name_for_koel> bash
# Once inside the container, you can run commands:
$ php artisan koel:init --no-assets
```

Create a database container. Here we will use [mysql].

```bash
docker run -d --name database \
    -e MYSQL_ROOT_PASSWORD=<root_password> \
    -e MYSQL_DATABASE=koel \
    -e MYSQL_USER=koel \
    -e MYSQL_PASSWORD=<koel_password> \
    mysql/mysql-server:5.7
```

Create the koel-fom container on the same network so they can communicate

```bash
docker run -d  --name koel \
    -v `pwd`/koel/html:/var/www/koel \
    -v `pwd`/koel/music:/music \
    --link mysql:mysql \
    koel:fpm
```

The same applies for the first run. See the [First run section](#first-run).





### workdir /var/www/koel

Since you may use many php-fpm instances, the rootdir is `/var/www/koel` rather than `/var/www/html`. All koel files will be here. If you `exec` into the container, this will be your current directory.

### nginx example

nginx docker

```bash
docker run --name nginx \
	   --restart=always \
	   -p 443:443 \
	   -p 80:80 \
	   --link koel \
	   -v `pwd`/koel/music:/music \
	   -v `pwd`/koel/html:/var/www/koel \
	   -v `pwd`/nginx/conf/nginx.conf:/etc/nginx/nginx.conf \
	   -v `pwd`/nginx/conf/sites-enabled:/etc/nginx/sites-enabled \
	   -v `pwd`/nginx/www:/var/www \
	   -d nginx
```

nginx conf

```bash
server {
    listen 80;
    server_name koel.xxx.yyy.zzz;
    return 301 https://$server_name:443$request_uri;
}
server {
    listen 443;
    server_name koel.xxx.yyy.zzz;
    ssl on;
    ssl_certificate  YOURKEYFILE;
    ssl_certificate_key  YOURKEYFILE;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2; # Dropping SSLv3, ref: POODLE
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DHE;
  root            /var/www/koel/public;
  index           index.php;

  gzip            on;
  gzip_types      text/plain text/css application/x-javascript text/xml application/xml application/xml+rss text/javascript application/json;
  gzip_comp_level  9;
  client_max_body_size 512M;
  location /media/ {
    internal;

    alias       $upstream_http_x_media_root;

  }

  location / {
    try_files   $uri $uri/ /index.php?$args;
  }

  location ~ \.php$ {
    try_files $uri $uri/ /index.php?$args;

    fastcgi_param     PATH_INFO $fastcgi_path_info;
    fastcgi_param     PATH_TRANSLATED $document_root$fastcgi_path_info;
    fastcgi_param     SCRIPT_FILENAME $document_root$fastcgi_script_name;

    fastcgi_pass              koel:9000;
    fastcgi_index             index.php;
    fastcgi_split_path_info   ^(.+\.php)(/.+)$;
    fastcgi_intercept_errors  on;
    include                   fastcgi_params;
  }
}

```
