#!/bin/sh
# Cron de Nextcloud (llamado cada 5 min desde el Programador de tareas de DSM)
# en el NAS como root: docker exec -u www-data nextcloud php -f /var/www/html/cron.php
/usr/local/bin/docker exec -u www-data nextcloud php -f /var/www/html/cron.php
