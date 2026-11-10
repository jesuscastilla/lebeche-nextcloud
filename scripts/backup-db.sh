#!/bin/sh
# Volcado semanal de la BD de Nextcloud con retención de 7 copias.
# Ejecutar como root desde el Programador de tareas de DSM.
# Credenciales root de MariaDB en G:\GITHUB\CREDENCIALES.md
set -u
DIR=/volume2/Backup_NAS/nextcloud-db
mkdir -p "$DIR"
FECHA=$(date +%Y%m%d)
export MYSQL_PWD='ROOT_MYSQL_PASSWORD'
/usr/local/mariadb10/bin/mysqldump -u root -P 3307 -h 127.0.0.1 --single-transaction --quick nextcloud | gzip > "$DIR/nextcloud-$FECHA.sql.gz"
ls -1t "$DIR"/nextcloud-*.sql.gz | tail -n +8 | xargs -r rm -f
echo "Backup Nextcloud DB: $DIR/nextcloud-$FECHA.sql.gz"
