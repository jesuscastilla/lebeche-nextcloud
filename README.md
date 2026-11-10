# Nextcloud Lebeche — Nube de la asociación

Nube privada de la asociación Lebeche sobre el NAS Synology DS223 (Docker).

- **URL pública:** `https://nube.corrientelebeche.es`
- **Office:** ❌ RETIRADO (10-11-2026) — Nextcloud Office/Collabora desactivado (no iba bien en este NAS); los documentos se editan en local (LibreOffice/Word) y se suben a la nube.
- **Calendario compartido:** Nextcloud Calendar (CalDAV en `https://nube.corrientelebeche.es/remote.php/dav/`)
- **Base de datos:** MariaDB 10 del NAS (puerto 3307, base `nextcloud`)
- **Datos:** `/volume1/nextcloud` (en el NAS)
- **Proyecto Docker en el NAS:** `/volume2/docker/nextcloud/`

## Estructura

| Ruta | Descripción |
|---|---|
| `docker/compose.yaml` | Stack Nextcloud + Collabora (desplegado en el NAS) |
| `docker/apache-mpm.conf` | Límites de Apache (RAM, NAS de 2 GB) |
| `docker/.env.example` | Plantilla de secretos (el `.env` real vive en el NAS, chmod 600) |
| `scripts/` | Cron de Nextcloud y volcado semanal de la BD |
| `docs/GUIA_DESPLIEGUE.md` | Guía completa de despliegue y mantenimiento |

## Despliegue rápido

```bash
# en el NAS (ssh)
cd /volume2/docker/nextcloud
docker compose up -d
docker exec -u www-data nextcloud php occ status
```

Ver `docs/GUIA_DESPLIEGUE.md` para el resto (proxy inverso, DNS, apps, backup).

## Credenciales

Ninguna credencial va en git. Están en `G:\GITHUB\CREDENCIALES.md` (local) y en `/volume2/docker/nextcloud/.env` (NAS).
