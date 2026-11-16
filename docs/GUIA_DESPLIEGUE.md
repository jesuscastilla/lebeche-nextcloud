# Guía de despliegue — Nextcloud Lebeche (NAS Synology DS223)

> Desplegado: 2026-11-10 · NAS `192.168.50.94` (2,5 GbE USB) · Puerto público 443 (proxy inverso DSM)

## 1. Arquitectura

```text
https://nube.corrientelebeche.es
   → Cloudflare (Proxied, SSL Full strict) → router 443 → NAS
   → DSM Reverse Proxy → localhost:8087 → contenedor nextcloud:35.0-apache
        datos: /volume1/nextcloud  (bind mount)
        BD:    MariaDB 10 del NAS, 127.0.0.1:3307, base `nextcloud`
```

> ❌ **Nextcloud Office (Collabora) RETIRADO el 10-11-2026** (contenedor, imagen,
> apps `richdocuments`/`office` y proxy `office.corrientelebeche.es` eliminados):
> no iba bien en este NAS de 2 GB. Los ajustes para reintentarlo están en el
> histórico de git de este repo.

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
  Nextcloud `mem_limit 900m`.
- **JIT de OPcache desactivado (10-11-2026):** montado `php-nas.ini` como
  `/usr/local/etc/php/conf.d/zz-nas.ini` (SIGSEGV de mod_php con PHP 8.5 tras
  cambios de apps). No reactivar.
- **Office retirado (10-11-2026):** el servicio `collabora` ya no está en el compose.

## 4. Proxy inverso (DSM)

Panel de control → Portal de inicio de sesión → Avanzado → Proxy inverso:

| Origen | Destino |
|---|---|
| `nube.corrientelebeche.es` : 443 (HTTPS) | `localhost:8087` (HTTP) |

~~`office.corrientelebeche.es` → `localhost:9980`~~ (eliminada 10-11-2026).

- Certificado: **Cloudflare Origin `*.corrientelebeche.es`** (válido hasta 2041).
- La GUI de DSM 7.4 no expone selector de certificado por regla: el certificado se
  asigna copiando los `.pem` del cert de Cloudflare en
  `/usr/syno/etc/www/certificate/ReverseProxy_<uuid>/` y editando su `cert.conf`
  (ver plantilla de la entrada "Mail Hostalia"). Tras cambiarlo: `nginx -s reload`.

## 5. DNS (Cloudflare)

| Tipo | Nombre | Contenido | Proxy |
|---|---|---|---|
| CNAME | `nube` | `pelotxo.synology.me` | Proxied |
| CNAME | `office` | `pelotxo.synology.me` | ⚠️ retirado (borrable) |

- SSL/TLS: `Full (strict)`.
- Cache Rule: Bypass para `nube.corrientelebeche.es` (y `office` si vuelve).
- Límite de subida de Cloudflare Free: 100 MB por petición (Nextcloud usa chunking).

## 6. Configuración aplicada (`occ`)

trusted_proxies (127.0.0.1, 172.16.0.0/12, 192.168.50.0/24),
forwarded_for_headers HTTP_X_FORWARDED_FOR, overwriteprotocol https,
overwrite.cli.url https://nube.corrientelebeche.es, overwritehost nube.corrientelebeche.es,

## 7. Apps habilitadas (44)

Calendar, Contacts, Mail, Tasks, Forms, Polls, Photos, Activity + núcleo (Files, DAV,
Sharing, Versiones, Papelera, Visor, 2FA, Texto...).

**Eliminadas (10-11-2026):** `notes`, `deck`, `spreed` (Talk), `bookmarks`, `richdocuments`.
**Deshabilitadas:** `office`, `federation`, `recommendations`, `related_resources`,
`weather_status`, `user_status`, `support`, `survey_client`, `webhook_listeners`,
`contactsinteraction`, `files_external`, `admin_audit`, `encryption`, `serverinfo`,
`suspicious_login`, `systemtags`, `twofactor_nextcloud_notification`, `user_ldap`,
`nextcloud_announcements`.
No deshabilitables (núcleo): `federatedfilesharing`, `cloud_federation_api`,
`lookup_server_connector`, `profile`, `workflowengine`.

**Mail:** la cuenta `monderas@corrientelebeche.es` (Hostalia) ya está configurada
para el usuario `monderas` (`occ mail:account:create-imap`). Para más usuarios:
Ajustes → Correo → Añadir cuenta, o `occ mail:account:create-imap` con sus datos.

**No activar** (RAM 2 GB): Full Text Search, Recognize, Talk HPB, OnlyOffice (4 GB), ClamAV.

## 8. Calendario compartido

- Grupo `Monderas`; usuario `monderas` (password en CREDENCIALES).
- Calendarios `lebeche`, `actividades`, `asambleas` **compartidos con el grupo
  `Monderas` (lectura/escritura)** — se comparten por **POST** al calendario con XML
  `{http://owncloud.org/ns}share` (ver histórico de git / CONTEXT.md), no con PROPPATCH.
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
- Tras actualizar DSM: revisar proxy inverso (certificados de `ReverseProxy_*`),
  `eth1` (USB 2,5G) y `verificar-salud.sh`.

## 12. Solución de problemas

| Síntoma | Causa | Acción |
|---|---|---|
| `occ` no arranca | BD caída | `synopkg status MariaDB10`; ver `/var/packages/MariaDB10/target/mysql/Pelotxo-NAS.err` |
| 403/“untrusted domain” | dominio no en trusted_domains | `occ config:system:set trusted_domains N --value=...` |
| Aviso transaction isolation | se perdió el ajuste | recomprobar `SHOW VARIABLES LIKE '%isolation%'` |
| 413 al subir | límite Cloudflare 100 MB | usar cliente de escritorio (chunking) |
| 502 en `nube` + “Empty reply” en el puerto 8087 | segfault de mod_php (`AH00051`) | `docker restart nextcloud`; si reincide, JIT off vía `docker/php-nas.ini` (ya montado, 10-11-2026) |
| RAM al límite | picos de Apache | revisar `apache-mpm.conf` y `docker stats` |
| “Login is invalid because files already exist for this user” al recrear un usuario | datadir huérfano | mover `data/<usuario>` antes de `occ user:add` |

default_phone_region ES, maintenance_window_start 1, logtimezone Europe/Madrid,
memcache.local APCu, background:cron, previews 2048/50, default_quota 20GB,
SMTP Hostalia (smtp.dominioabsoluto.net:587 TLS, monderas@corrientelebeche.es).

## 13. Talk + TURN (coturn) — reuniones pequeñas

- Contenedor `coturn` en `/volume2/docker/coturn/` (`compose.yaml` + `turnserver.conf`,
  chown nobody, `network_mode: host`): escucha 3478 TCP/UDP, relay 50000-50100 UDP,
  `relay-ip=192.168.50.94`, `external-ip=<IP pública>/192.168.50.94`, auth por
  **shared secret** (en `turnserver.conf`).
- Talk: `occ talk:turn:add turn pelotxo.synology.me:3478 udp,tcp --secret=<secret>`
  y `occ talk:stun:add pelotxo.synology.me:3478`.
- Router: reenviar **3478 TCP/UDP** y **50000–50100 UDP** → `192.168.50.94`.
  Si cambia la IP pública, actualizar `external-ip` y reiniciar el contenedor.
- Verificado 15-11-2026 contra la IP pública (TCP 3478 y UDP STUN responden).
- **Sin HPB**: vale para grupos pequeños (3-8 personas). Para congresos/grupos grandes,
  montar `nextcloud-spreed-signaling` (+ Redis) en un servidor auxiliar con más RAM.

## 14. Correo compartido de Hostalia (todas las cuentas)

- Crear buzón para una usuaria:
  `occ mail:account:create-imap <uid> "Correo Lebeche" monderas@corrientelebeche.es
  imap.dominioabsoluto.net 993 ssl monderas@corrientelebeche.es <pass> smtp.dominioabsoluto.net
  587 tls monderas@corrientelebeche.es <pass> password`
- Provisionamiento automático: `~/scripts/mail-provision.sh` (recorre el grupo `Monderas`
  y crea el buzón donde falte) + crontab diario 05:15. Las cuentas nuevas del grupo lo
  reciben automáticamente.

## 15. Equipos (Teams) visibles con solicitud de admisión

- `occ circles:manage:config <circle_id> VISIBLE OPEN JOINREQUEST` — el equipo aparece a
  todas las usuarias y cualquiera puede solicitar unirse (confirmación de un moderador).
- Para desactivar un flag, prefijar con guion bajo (p. ej. `_OPEN`).
## 16. Redis (memcache: locking y caché distribuida)

- Servicio `redis` en el compose (`redis:7-alpine`, `--save "" --appendonly no`,
  `--maxmemory 128mb --maxmemory-policy allkeys-lru`, `mem_limit 128m`).
- Configuración:

```bash
occ config:system:set memcache.distributed --value='\OC\Memcache\Redis'
occ config:system:set memcache.locking --value='\OC\Memcache\Redis'
occ config:system:set redis host --value=nextcloud-redis
occ config:system:set redis port --type=integer --value=6379
# luego: docker compose restart nextcloud
```

- Verificar: `docker exec nextcloud-redis redis-cli ping` (PONG) y `dbsize` > 0.
- Nota 16-11-2026: HPB externo de Spreed Cloud eliminado (`talk:signaling:delete`);
  Talk usa solo el TURN propio (coturn).
## 17. Office (OnlyOffice) y Talk HPB en el PC auxiliar (16-11-2026)

- **OnlyOffice** corre en el PC auxiliar ZimaOS (`192.168.50.95:9980`, compose en
  `/tmp/lebeche/onlyoffice`, volumen nombrado `onlyoffice_data`, JWT habilitado).
  En el NAS:

```bash
occ app:install onlyoffice && occ app:enable onlyoffice
occ config:app:set onlyoffice DocumentServerUrl --value="https://office.corrientelebeche.es"
occ config:app:set onlyoffice jwt_secret --value=<JWT>   # mismo que el compose
occ onlyoffice:documentserver --check                    # debe decir "successfully connected"
```

- **Talk HPB** en el PC auxiliar (`192.168.50.95:8081`, imagen
  `strukturag/nextcloud-spreed-signaling`, backend `https://nube.corrientelebeche.es`,
  HASH_KEY/BLOCK_KEY/SHARED_SECRET persistentes por env). En el NAS:

```bash
occ talk:signaling:add https://signaling.corrientelebeche.es/ <SHARED_SECRET> --verify
occ talk:signaling:list
```

- **Proxy inverso DSM 7.4**: bloques `server{}` en el w3conf de
  `/usr/local/etc/nginx/sites-available/` (el JSON `ReverseProxy.json` solo no aplica).
  El nginx de DSM **elimina la cabecera `Upgrade` del cliente** → en `location /spreed`
  se fijan `proxy_set_header Upgrade "websocket"` y `Connection "Upgrade"`.
  HSTS `max-age=15552000` en `nube`, `office` y `signaling`. Certs de origen: los de
  `pelotxo.synology.me` (Cloudflare modo Full).
- **Nota importante (16-11-2026)**: `DocumentServerInternalUrl` **debe acabar en `/`**
  (`http://192.168.50.95:9980/`); sin barra, la app genera URLs rotas
  (`...:9980converter`) y fallan las miniaturas/conversiones.
- La app **oculta sus opciones de "Nuevo"** (Documento/Hoja/Presentación en el menú «+»
  de Archivos) cuando `config:app:get onlyoffice settingsError` no está vacío: basta con
  que el `onlyoffice:documentserver --check` falle una vez (p. ej., por un corte de DNS)
  para que desaparezcan. Si el check vuelve a pasar, el error se limpia solo.