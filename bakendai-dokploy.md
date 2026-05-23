# bakend_ai — VPS usa só `databases/`

## Dokploy — `bakend_ai`

| Campo | Valor |
|--------|--------|
| **Compose Path** (Dokploy) | `docker-compose.dokploy-deploy.yml` |
| Inclui (automático) | `docker-compose.yml` + `docker-compose.dokploy.yml` |
| **Não** usar | `COMPOSE_PROFILES=local-db` nem `bundle-redis` |

## Environment

```env
DB_HOST=iluminys_db
DB_PORT=5432
PG_USER=iluminys
PG_PASSWORD=<mesmo PG_PASSWORD do projeto databases>
PG_DB=iluminys
INGEST_REDIS_URL=redis://iluminys_redis:6379/1
```

## Contentores esperados (só 1)

- `iluminys-bakendai-tr3fuj-api-1` — **sem** `postgres`, **sem** `redis`

## Ordem

1. **databases** (`iluminys_db` healthy)
2. **bakend_ai** redeploy

## PC local

```env
COMPOSE_PROFILES=local-db,bundle-redis
DB_HOST=127.0.0.1
PG_DB=tecconcursos
INGEST_REDIS_URL=redis://redis:6379/0
```
