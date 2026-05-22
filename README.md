# Infraestrutura Iluminys (Postgres, Redis, MinIO)

Stack **isolada** das aplicações (`docker-compose.yml` na raiz). Os volumes persistem aqui; redeploy do backend/web **não** recria nem apaga o banco.

**Deploy no Dokploy:** ver **[DOKPLOY.md](./DOKPLOY.md)** (Compose Path + variáveis Environment).

## Serviços

| Serviço Compose | Container       | Hostname na rede `iluminys_infra` | Porta host (default) |
|-----------------|-----------------|-----------------------------------|----------------------|
| `iluminys_db`   | `iluminys_db`   | `iluminys_db`                     | `127.0.0.1:15432`    |
| `redis`         | `iluminys_redis`| `iluminys_redis`                  | `127.0.0.1:6379`     |
| `minio`         | `iluminys_minio`| `iluminys_minio`                  | `9000` / `9001`      |

Imagem Postgres: `pgvector/pgvector:pg18` (notebooks/RAG).

## Subir (VPS ou local)

```bash
cd databases
cp .env.example .env
# editar PG_PASSWORD, MINIO_ACCESS_KEY, MINIO_SECRET_KEY
docker compose up -d
docker compose ps
```

Schema SQL (uma vez, com túnel ou na VPS):

```bash
export PGHOST=127.0.0.1 PGPORT=15432 PGUSER=iluminys PGPASSWORD='...' PGDATABASE=iluminys
../backend/scripts/provision-iluminys-db.sh
```

(`ILUMINYS_DB_PASSWORD` = mesmo valor que `PG_PASSWORD` em `databases/.env`.)

## Apps (stack separada)

Na raiz do repositório, o `docker-compose.yml` **só** tem backend, web e flutter-web. O backend liga-se à rede externa `iluminys_infra`:

- `DB_HOST=iluminys_db` `DB_PORT=5432`
- `REDIS_URL=redis://iluminys_redis:6379`
- `MINIO_ENDPOINT=iluminys_minio:9000`

Ordem no Dokploy/VPS:

1. Projeto **databases** (este compose) — `docker compose up -d`
2. Projeto **iluminys-web** (compose raiz) — redeploy das apps

## Migração VPS (volumes Dokploy legados)

Na VPS, com o repositório atualizado:

```bash
cd databases
cp .env.vps.example .env
# Ajustar PG_PASSWORD (iluminys) e segredos reais
chmod +x ../databases/scripts/vps-migrate-legacy.sh
../databases/scripts/vps-migrate-legacy.sh
```

Usa `docker-compose.migrate-vps.yml` para montar os volumes antigos:

- `iluminys-bakendai-tr3fuj_pg_data` → `iluminys_db`
- `iluminys-web-ijnbqc_minio_data` → `iluminys_minio`
- `iluminys-web-ijnbqc_redis_data` → `iluminys_redis`

Depois redeploy do projeto **iluminys-web** (compose raiz sem minio/redis) e atualize variáveis no Dokploy.

## Migração desde stack antiga (tudo num compose)

Se o Postgres/Redis/MinIO antigos estavam no mesmo projeto Dokploy:

1. **Backup** do volume Postgres (`pg_dump` ou snapshot do volume Docker).
2. Subir este compose com **mesma** `PG_PASSWORD` e portas.
3. Restaurar dados ou reutilizar volume renomeado (avançado — só se souber o nome do volume antigo).
4. Remover serviços `postgres`/`redis`/`minio` do compose das apps antes do próximo deploy.

## Túnel SSH (PC → VPS)

```bash
ssh -N \
  -L 15432:127.0.0.1:15432 \
  -L 6379:127.0.0.1:6379 \
  -L 9000:127.0.0.1:9000 \
  -L 9001:127.0.0.1:9001 \
  root@SEU_IP
```

No `backend/.env` local: `DB_HOST=127.0.0.1` `DB_PORT=15432`.

## Volumes nomeados

- `iluminys_pg_data`
- `iluminys_redis_data`
- `iluminys_minio_data`

Não usar `docker compose down -v` em produção.
