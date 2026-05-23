# Deploy `databases` no Dokploy

Projeto **Compose** separado das apps (`iluminys-web`, `iluminys-bakendai`).  
Postgres (`iluminys_db`), Redis (`iluminys_redis`) e MinIO (`iluminys_minio`) na rede **`iluminys_infra`**.

**Postgres e MinIO não são expostos na internet** — bind `127.0.0.1` no host da VPS. Administração via **túnel SSH**; as apps na mesma rede Docker usam hostnames internos.

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
| `DB_HOST` | Sim | `127.0.0.1` (só localhost na VPS) |
| `DB_PORT` | Sim | `15432` |
| `PG_USER` / `PG_PASSWORD` / `PG_DB` | Sim | Credenciais do Postgres (ver abaixo) |
| `MINIO_ACCESS_KEY` / `MINIO_SECRET_KEY` | Sim | Igual ao projeto **apps** / `backend/.env` |
| `MINIO_PORT_BIND` | Recomendado | `127.0.0.1` (não `0.0.0.0`) |
| `MINIO_SERVER_URL` | Recomendado | `http://127.0.0.1:9000` (consola via túnel) |

**Não** uses `TEC_PG_*` no painel — usa `PG_USER`, `PG_PASSWORD`, `PG_DB`.

| Cenário | `PG_USER` |
|---------|-----------|
| Instalação nova (`docker-compose.dokploy.yml`) | `iluminys` |
| VPS volume legado (`docker-compose.dokploy-vps.yml`) | `tec` (superuser com que o volume foi criado) |

As apps NestJS ligam com **`PG_USER=iluminys`** (utilizador da aplicação na BD), não com o superuser `tec`.

### Túnel SSH (PC → VPS)

```bash
ssh -N \
  -L 15432:127.0.0.1:15432 \
  -L 9000:127.0.0.1:9000 \
  -L 9001:127.0.0.1:9001 \
  root@69.62.66.153
```

- DBeaver: `localhost:15432`, user/senha conforme o teu env (`iluminys` ou `tec` para superuser).
- MinIO Console: `http://127.0.0.1:9001`

## 3. Projeto apps (`iluminys-web`) — MinIO interno

No Environment do **backend** (compose raiz):

```env
MINIO_ENDPOINT=iluminys_minio:9000
# Não definir MINIO_PUBLIC_BASE_URL se o MinIO não for público
```

Ver `env.dokploy.web.example` na raiz do repositório.

## 3b. Projeto scraping (`iluminys-bakendai`) — sync de fotos

A API na porta **9082** grava imagens no MinIO ao receber `POST /v1/ingest/foto`.  
**Não** uses IP público nem `69.62.66.153:9000` — com `MINIO_PORT_BIND=127.0.0.1` isso falha ou forçava exposição pública.

No Environment do projeto **bakendai** (Compose Path: `scraping-questions/docker-compose.dokploy-deploy.yml`):

```env
MINIO_ENDPOINT=iluminys_minio:9000
MINIO_ACCESS_KEY=<igual ao projeto databases>
MINIO_SECRET_KEY=<igual ao projeto databases>
MINIO_BUCKET=iluminys
MINIO_IMAGES_PREFIX=tecconcursos/questoes-imagens
MINIO_SECURE=false
```

Credenciais iguais ao projeto `databases`; endpoint **só** o hostname Docker na rede `iluminys_infra`.  
Se `MINIO_ENDPOINT` existir no painel mas estiver **vazio**, apaga ou preenche — senão o sync de fotos devolve *No host specified*.

## 4. VPS — antes do primeiro deploy no Dokploy

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

## 5. Deploy

1. **Deploy** no projeto `databases` → **Done** (3 serviços healthy).
2. Projeto **iluminys-web** → `env.dokploy.web.example` no Environment.
3. Fechar portas **9000/9001/15432** no firewall da VPS para o mundo (só SSH + apps 9080/9081).

Ordem: `databases` → `iluminys-web`.

## 6. Verificar (na VPS, por SSH)

```bash
docker ps --filter name=iluminys
curl -fsS http://127.0.0.1:9000/minio/health/live
docker exec iluminys_db psql -U iluminys -d iluminys -tAc "SELECT 1"
```

## 7. Schema SQL (só instalação nova)

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
| `PG_PASSWORD is missing` | Env vazia | Preencher `PG_PASSWORD` no painel |
| Postgres não arranca após mudar `PG_USER` | Volume já inicializado com outro superuser | Manter `PG_USER=tec` no legado ou migrar cluster |
| MinIO login falha após mudar env | Volume já criado com credenciais antigas | Alterar user na consola ou alinhar env ao volume |
| Conflito de nome | Contentores antigos a correr | `docker stop/rm` (secção 4) |
| Rede não encontrada | `iluminys_infra` inexistente | `docker network create iluminys_infra` |
| Sync fotos: *No host specified* | `MINIO_ENDPOINT` vazio na API scraping | Secção 3b: `iluminys_minio:9000` + redeploy bakendai |
| Sync fotos: timeout / connection refused | `MINIO_ENDPOINT=IP:9000` com bind `127.0.0.1` | Usar `iluminys_minio:9000`, não IP público |
