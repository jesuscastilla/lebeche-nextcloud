# Nextcloud Lebeche — Nube privada de la asociación

Instancia autohospedada de **Nextcloud** para la **Asociación Cultural y Vecinal Lebeche** (Salobreña, Granada), desplegada sobre Docker en un servidor NAS Synology DS223.

[![Nextcloud](https://img.shields.io/badge/Nextcloud-Hub-0082C9?style=flat-square&logo=nextcloud&logoColor=white)](https://nextcloud.com/)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=flat-square&logo=docker&logoColor=white)](https://www.docker.com/)
[![Database](https://img.shields.io/badge/Database-MariaDB%2010-003545?style=flat-square&logo=mariadb&logoColor=white)](https://mariadb.org/)
[![Live Service](https://img.shields.io/badge/URL-nube.corrientelebeche.es-brightgreen?style=flat-square)](https://nube.corrientelebeche.es)

---

## ☁️ Servicios activos

- **URL pública:** [https://nube.corrientelebeche.es](https://nube.corrientelebeche.es)
- **Almacenamiento y archivos:** Sincronización de documentos asociativos por comisiones y grupos de trabajo.
- **Calendarios compartidos (CalDAV):** `https://nube.corrientelebeche.es/remote.php/dav/` (utilizado por las organizadoras).
- **Libreta de contactos compartida (CardDAV):** Directorio unificado de socias y entidades.
- **Correo integrado:** Cliente Nextcloud Mail conectado al servicio de correo asociativo.
- **Base de datos:** MariaDB 10 dedicada (base `nextcloud` en puerto 3307).

---

## 📁 Estructura del repositorio

```text
lebeche-nextcloud/
├── docker/
│   ├── compose.yaml          # Stack Docker para Nextcloud (Container Manager)
│   ├── apache-mpm.conf       # Afinamiento de límites Apache MPM (optimizado para 2 GB RAM)
│   ├── php-nas.ini           # Configuración PHP (OPcache y límites de subida)
│   └── .env.example          # Plantilla de variables de entorno
├── scripts/
│   ├── nextcloud-cron.sh     # Ejecución periódica del cron interno de Nextcloud (occ)
│   └── backup-db.sh          # Volcado automático periódico de la base MariaDB
└── docs/
    └── GUIA_DESPLIEGUE.md    # Guía completa paso a paso de despliegue, proxy inverso y SSL
```

---

## 🚀 Despliegue y operación rápida

El despliegue en producción se realiza en el NAS a través de Container Manager / SSH:

```bash
# 1. Situarse en el directorio del proyecto en el servidor
cd /volume1/docker/nextcloud

# 2. Levantar el stack de contenedores
docker compose up -d

# 3. Comprobar el estado de Nextcloud con occ
docker exec -u www-data nextcloud php occ status
```

Para instrucciones detalladas sobre la configuración del Proxy Inverso de DSM, certificados Cloudflare Origin y afinamiento de memoria, consulta [`docs/GUIA_DESPLIEGUE.md`](docs/GUIA_DESPLIEGUE.md).

---

## 🔒 Gestión de secretos y seguridad

- **No versionar credenciales:** El archivo `.env` real vive únicamente en el servidor de producción con permisos estrictos (`chmod 600`) y está excluido de Git vía `.gitignore`.
- **Plantilla pública:** Usa `docker/.env.example` para generar tu entorno local o de pruebas.
- **Copias de seguridad:** La base de datos y el directorio de datos (`/volume1/nextcloud`) se respaldan mediante tareas programadas automáticas.

---

## 🔗 Repositorios relacionados

| Proyecto | Descripción |
|---|---|
| [documentacion-lebeche](https://github.com/jesuscastilla/documentacion-lebeche) | Manuales operativos y guías de uso para Monderas |
| [lebeche-web](https://github.com/jesuscastilla/lebeche-web) | Portal web oficial de la asociación |
| [lebeche-correo](https://github.com/jesuscastilla/lebeche-correo) | Infraestructura de correo y newsletter |
