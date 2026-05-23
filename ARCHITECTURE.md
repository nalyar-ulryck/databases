# O que pertence ao stack `databases/` (VPS)

## Incluído (produção Iluminys)

| Serviço | Base / uso |
|---------|------------|
| **Postgres** `iluminys_db` | App (`cards`, `decks`, `notebooks`, `generation_jobs`, gamificação) **e** catálogo Tec (`questoes`, `materias`, …) no mesmo DB `iluminys` |
| **Redis** `iluminys_redis` | Bull/SSE do **backend Nest** (DB 0) + fila ingest **bakend_ai** (DB 1) |
| **MinIO** `iluminys_minio` | Object storage (app + imagens de questões conforme env do scraping) |

## Quem liga a `iluminys_infra`

| Projeto Dokploy | Postgres | Redis |
|-----------------|----------|-------|
| **databases** | `iluminys_db` (contentor) | `iluminys_redis` |
| **iluminys-web** (backend) | `DB_HOST=iluminys_db` user `iluminys` | `redis://iluminys_redis:6379` |
| **bakend_ai** (scraping API) | `DB_HOST=iluminys_db` user `tec` (ou `iluminys`) | `redis://iluminys_redis:6379/1` |

**bakend_ai na VPS não tem contentor `postgres`** — só `api` + compose adicional `docker-compose.dokploy.yml`.

## PC local (desenvolvimento)

| Sistema | Postgres |
|---------|----------|
| **scraping-questions** | `COMPOSE_PROFILES=local-db,bundle-redis` → Postgres local `tecconcursos` |
| Sync app | Túnel → VPS `iluminys_db` ou Supabase |

## Volume legado

`iluminys-bakendai-tr3fuj_pg_data` = dados antigos do Postgres partilhado; o projeto **databases** monta esse volume em `iluminys_db` (compose `docker-compose.dokploy-vps.yml`).
