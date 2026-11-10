# Guía de despliegue — Nextcloud Lebeche (NAS Synology DS223)

> Desplegado: 2026-11-10 · NAS `192.168.50.94` (2,5 GbE USB) · Puerto público 443 (proxy inverso DSM)

## 1. Arquitectura

```text
https://nube.corrientelebeche.es
   → Cloudflare (Proxied, SSL Full strict) → router 443 → NAS
   → DSM Reverse Proxy → localhost:8087 → contenedor nextcloud:35.0-apache
        datos: /volume1/nextcloud  (bind mount)
        BD:    MariaDB 10 del NAS, 127.0.0.1:3307, base `nextcloud`

https://office.corrientelebeche.es
   → Cloudflare (Proxied) → DSM Reverse Proxy → localhost:9980 → colabora/code
```

## 2. Base de datos (MariaDB 10 del NAS)

- BD `nextcloud` (utf8mb4) y usuario `nextcloud` con `ALL` sobre `nextcloud.*`.
- Ajustes aplicados el 2026-11-10 (backups `*.bak-20261110`):
  - `/var/packages/MariaDB10/etc/my.cnf`: `innodb_buffer_pool_size = 128M`,
    `max_allowed_packet = 64M`, `transaction_isolation = READ-COMMITTED`
    (en runtime se ve como `tx_isolation`).
  - `/var/packages/MariaDB10/etc/synology.cnf`: `innodb_buffer_pool_size=128M`
    (este fichero se carga después y pisaba el ajuste; OJO tras actualizar MariaDB10).
- ⚠️ Tras cada update del paquete MariaDB10, recomprobar
  `SHOW VARIABLES LIKE '%isolation%'; SELECT @@innodb_buffer_pool_size;`

## 3. Proyecto Docker

- NAS: `/volume2/docker/nextcloud/` (`compose.yaml`, `apache-mpm.conf`, `.env` chmod 600).
- Repo local: `G:\GITHUB\lebeche-nextcloud\docker\`.
- Comandos:

```bash
cd /volume2/docker/nextcloud
sudo docker compose up -d
sudo docker compose pull && sudo docker compose up -d   # actualizar
sudo docker logs -f nextcloud
sudo docker exec -u www-data nextcloud php occ status
```

- Límites de RAM (NAS de 2 GB): Apache prefork 2/1/3/8 (`apache-mpm.conf`);

## 5. DNS (Cloudflare)

| Tipo | Nombre | Contenido | Proxy |
|---|---|---|---|
| CNAME | `nube` | `pelotxo.synology.me` | Proxied |
| CNAME | `office` | `pelotxo.synology.me` | Proxied |

- SSL/TLS: `Full (strict)`.
- Cache Rule: Bypass para `nube.corrientelebeche.es` y `office.corrientelebeche.es`.
- Límite de subida de Cloudflare Free: 100 MB por petición (Nextcloud usa chunking).

## 6. Configuración aplicada (`occ`)

trusted_proxies (127.0.0.1, 172.16.0.0/12, 192.168.50.0/24),
forwarded_for_headers HTTP_X_FORWARDED_FOR, overwriteprotocol https,
overwrite.cli.url https://nube.corrientelebeche.es, overwritehost nube.corrientelebeche.es,
default_phone_region ES, maintenance_window_start 1, logtimezone Europe/Madrid,
memcache.local APCu, background:cron, previews 2048/50, default_quota 20GB,
SMTP Hostalia (smtp.dominioabsoluto.net:587 TLS, monderas@corrientelebeche.es).

## 7. Apps habilitadas

Calendar, Contacts, Mail, Notes, Tasks, Deck, Talk (solo chat), Forms, Polls,
Bookmarks, External storage, Federation, Photos, Activity, richdocuments
(Nextcloud Office).

**Mail:** la cuenta `monderas@corrientelebeche.es` (Hostalia) ya está configurada
para el usuario `monderas` (`occ mail:account:create-imap`). Para más usuarios:
Ajustes → Correo → Añadir cuenta, o `occ mail:account:create-imap` con sus datos.

**No activar** (RAM 2 GB): Full Text Search, Recognize, Talk HPB, OnlyOffice (4 GB), ClamAV.

## 8. Calendario compartido

- Grupo `Monderas`; usuario de prueba `monderas` (password en CREDENCIALES).
- Calendarios creados: `lebeche`, `actividades`, `asambleas`
  (compartirlos con el grupo desde la UI del Calendario).
- CalDAV para Mondera's App: `https://nube.corrientelebeche.es/remote.php/dav/`

## 9. Tareas programadas

Añadidas a `/etc/crontab` (el 2026-11-10):

| Horario | Comando |
|---|---|
| `*/5 * * * *` | `/var/services/homes/pelotxo/scripts/nextcloud-cron.sh` |
| `30 4 * * 0` | `/var/services/homes/pelotxo/scripts/backup-db.sh` |

⚠️ DSM puede regenerar `/etc/crontab` tras cambios de tareas/paquetes: si las líneas
desaparecen, recrearlas también desde Panel de control → Programador de tareas.

## 10. Backup y restauración

- Datos: `/volume1/nextcloud` → pendiente de añadir a HyperBackup hacia
  `/volume2/Backup_NAS` (la replicación Snapshot Replication quedó desactivada).
- BD: volcado semanal a `/volume2/Backup_NAS/nextcloud-db/` (retención 7).
- Restaurar BD: `gunzip < nextcloud-YYYYMMDD.sql.gz | mysql -u root -p nextcloud`.
- Restaurar datos: copiar la carpeta y `occ files:scan --all`.
- **Sin backup offsite**: recomendable USB externo o HyperBackup a la nube.

## 11. Actualizaciones

- Pin `35.0-apache`; para saltar de major, `occ upgrade` con la imagen nueva y
  verificar apps compatibles.
- Collabora: `docker compose pull` mensual (CODE).
- Tras actualizar DSM: revisar proxy inverso (certificados de `ReverseProxy_*`),
  `eth1` (USB 2,5G) y `verificar-salud.sh`.

## 12. Solución de problemas

| Síntoma | Causa | Acción |
|---|---|---|
| `occ` no arranca | BD caída | `synopkg status MariaDB10`; ver `/var/packages/MariaDB10/target/mysql/Pelotxo-NAS.err` |
| 403/“untrusted domain” | dominio no en trusted_domains | `occ config:system:set trusted_domains N --value=...` |
| Office no abre | Collabora caído | `docker ps`; logs; comprobar `occ config:app:get richdocuments wopi_url` |
| kit muere con EINVAL seccomp | kernel Synology | verificar `cap_add`, `seccomp:unconfined`, `--o:security.seccomp=false` |
| Aviso transaction isolation | se perdió el ajuste | recomprobar `SHOW VARIABLES LIKE '%isolation%'` |
| 413 al subir | límite Cloudflare 100 MB | usar cliente de escritorio (chunking) |
| RAM al límite | picos de Apache/LO | revisar `apache-mpm.conf` y `docker stats` |

  Nextcloud `mem_limit 900m`; Collabora `mem_limit 768m`.
- **Colabora en este NAS (ARM64 + kernel Synology):** requiere
  `cap_add: [MKNOD, SYS_ADMIN]`, `security_opt: seccomp:unconfined` y
  `--o:security.seccomp=false` (el filtro seccomp interno da EINVAL y mata los "kit").

## 4. Proxy inverso (DSM)

Panel de control → Portal de inicio de sesión → Avanzado → Proxy inverso:

| Origen | Destino |
|---|---|
| `nube.corrientelebeche.es` : 443 (HTTPS) | `localhost:8087` (HTTP) |
| `office.corrientelebeche.es` : 443 (HTTPS) | `localhost:9980` (HTTP) |

- Certificado: **Cloudflare Origin `*.corrientelebeche.es`** (válido hasta 2041).
- La GUI de DSM 7.4 no expone selector de certificado por regla: el certificado se
  asigna copiando los `.pem` del cert de Cloudflare en
  `/usr/syno/etc/www/certificate/ReverseProxy_<uuid>/` y editando su `cert.conf`
  (ver plantilla de la entrada "Mail Hostalia"). Tras cambiarlo: `nginx -s reload`.
