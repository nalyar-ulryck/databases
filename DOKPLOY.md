# Deploy `databases` no Dokploy

Projeto **Compose** separado das apps (`iluminys-web`, `iluminys-bakendai`).  
Postgres (`iluminys_db`), Redis (`iluminys_redis`) e MinIO (`iluminys_minio`) na rede **`iluminys_infra`**.

## 1. Criar o projeto

| Campo | Valor |
|--------|--------|
| Tipo | **Docker Compose** |
| Nome | `databases` (ou `iluminys-databases`) |
| Repositório | `mnemo_flutter` (mesmo das apps) |
| Branch | `main` / a sua branch |
| **Compose Path** | `databases/docker-compose.dokploy-vps.yml` **(VPS 69.62.66.153)** |
| | ou `databases/docker-compose.dokploy.yml` **(instalação nova)** |

O deploy falha se o **Compose Path** apontar para `docker-compose.yml` na raiz (esse ficheiro é só das apps).

## 2. Environment (obrigatório)

Aba **Environment** → copiar de `databases/env.dokploy.example` e preencher:

| Variável | Obrigatório | Notas |
|----------|-------------|--------|
| `DB_HOST` | Sim | `127.0.0.1` na VPS (bind + túnel SSH no PC) |
| `DB_PORT` | Sim | `15432` |
| `PG_USER` / `PG_PASSWORD` / `PG_DB` | Sim | Login **iluminys** (apps e DBeaver no PC) |
| `MINIO_SECRET_KEY` | Sim | Ex.: `minioadmin` |

**Não** precisa de `TEC_PG_*` no painel — volume legado usa superuser `tec` só dentro de `docker-compose.dokploy-vps.yml`.

Sem `PG_PASSWORD` / `MINIO_SECRET_KEY` o compose novo falha; no VPS legado o Postgres sobe mesmo sem `PG_PASSWORD` no painel (senha `tec` está no ficheiro compose).

## 3. VPS — antes do primeiro deploy no Dokploy

Já existem contentores `iluminys_db`, `iluminys_minio`, `iluminys_redis` criados à mão? Pare e remova para o Dokploy gerir:

```bash
docker stop iluminys_db iluminys_minio iluminys_redis
docker rm iluminys_db iluminys_minio iluminys_redis
```

Os **volumes** (`iluminys-bakendai-tr3fuj_pg_data`, etc.) **não** apagar.

Rede `iluminys_infra` deve existir (o compose VPS marca `external: true`). Se não existir:

```bash
docker network create iluminys_infra
```

## 4. Deploy

1. **Deploy** no projeto `databases` → **Done** (3 serviços healthy).
2. Projeto **iluminys-web** → copiar `env.dokploy.web.example` (raiz do repo) para Environment.
3. Projeto **iluminys-bakendai** → `scraping-questions/env.dokploy.example` + compose adicional `docker-compose.dokploy.yml`. Ver [bakendai-dokploy.md](./bakendai-dokploy.md).

Ordem: `databases` → `iluminys-web` (scraping independente).

## 5. Verificar

```bash
docker ps --filter name=iluminys
docker exec iluminys_db psql -U tec -d iluminys -tAc "SELECT COUNT(*) FROM cards"
curl -fsS http://127.0.0.1:9000/minio/health/live
```

## 6. Schema SQL (só instalação nova)

Com `docker-compose.dokploy.yml` e volume vazio:

```bash
export PGHOST=127.0.0.1 PGPORT=15432 PGUSER=iluminys PGPASSWORD='...' PGDATABASE=iluminys
./backend/scripts/provision-iluminys-db.sh
```

Na VPS com volume migrado, **não** correr de novo (dados já existem).

## Ficheiros

| Ficheiro | Uso |
|----------|-----|
| `docker-compose.dokploy.yml` | VPS nova / volumes novos |
| `docker-compose.dokploy-vps.yml` | VPS atual com volumes Dokploy legados |
| `docker-compose.yml` | Dev local (`docker compose up`) |
| `env.dokploy.example` | Variáveis do painel |

## Erro comum no Dokploy

| Sintoma | Causa | Solução |
|---------|--------|---------|
| Deploy Error no 1.º commit | Compose Path errado ou env vazia | Path `databases/docker-compose.dokploy-vps.yml` + senhas no Environment |
| `PG_PASSWORD is missing` | Sintaxe `:?` no compose antigo | Usar ficheiros `docker-compose.dokploy*.yml` desta pasta |
| Conflito de nome | Contentores antigos a correr | `docker stop/rm` (secção 3) |
| Rede não encontrada | `iluminys_infra` inexistente | `docker network create iluminys_infra` |
