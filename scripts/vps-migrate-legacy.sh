#!/usr/bin/env bash
# Migra Postgres + MinIO + Redis dos stacks Dokploy legados → databases/ (iluminys_infra).
# Executar na VPS como root, a partir da raiz do repositório clonado.
#
#   ./databases/scripts/vps-migrate-legacy.sh
#
# Pré-requisitos: databases/.env com TEC_PG_PASSWORD, MINIO_*, PG_* (iluminys)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DB_DIR="${ROOT}/databases"
ENV_FILE="${DB_DIR}/.env"

LEGACY_PG=iluminys-bakendai-tr3fuj-postgres-1
LEGACY_MINIO=iluminys-web-ijnbqc-minio-1
LEGACY_REDIS_WEB=iluminys-web-ijnbqc-redis-1
WEB_BACKEND=iluminys-web-ijnbqc-backend-1
SCRAPING_API=iluminys-bakendai-tr3fuj-api-1

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Crie ${ENV_FILE} (copie de .env.example e preencha TEC_PG_PASSWORD, MINIO_*)." >&2
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "${ENV_FILE}"
set +a

compose() {
  docker compose -f "${DB_DIR}/docker-compose.yml" -f "${DB_DIR}/docker-compose.migrate-vps.yml" --env-file "${ENV_FILE}" "$@"
}

echo "==> Parando contentores legados de infra (mantém apps temporariamente paradas se partilharem rede)…"
for c in "${LEGACY_PG}" "${LEGACY_MINIO}" "${LEGACY_REDIS_WEB}"; do
  if docker ps -a --format '{{.Names}}' | grep -qx "${c}"; then
    docker stop "${c}" || true
    echo "    stopped ${c}"
  fi
done

echo "==> Subindo stack databases/ com volumes antigos…"
compose up -d
compose ps

echo "==> Aguardando Postgres…"
for i in $(seq 1 30); do
  if docker exec iluminys_db pg_isready -U "${TEC_PG_USER:-tec}" -d iluminys &>/dev/null; then
    break
  fi
  sleep 2
done
docker exec iluminys_db pg_isready -U "${TEC_PG_USER:-tec}" -d iluminys

CARDS="$(docker exec iluminys_db psql -U "${TEC_PG_USER:-tec}" -d iluminys -tAc 'SELECT COUNT(*) FROM cards' 2>/dev/null || echo '?')"
echo "    cards em iluminys: ${CARDS}"

echo "==> Ligando apps à rede iluminys_infra…"
for c in "${WEB_BACKEND}" "${SCRAPING_API}"; do
  if docker ps --format '{{.Names}}' | grep -qx "${c}"; then
    docker network connect iluminys_infra "${c}" 2>/dev/null || true
    echo "    network connect ${c}"
  fi
done

echo ""
echo "OK — infra em databases/ (iluminys_db, iluminys_minio, iluminys_redis)."
echo ""
echo "Próximo passo OBRIGATÓRIO (Dokploy / compose apps):"
echo "  DB_HOST=iluminys_db  DB_PORT=5432"
echo "  REDIS_URL=redis://iluminys_redis:6379"
echo "  MINIO_ENDPOINT=iluminys_minio:9000"
echo "  (scraping) DB_HOST=iluminys_db  MINIO_ENDPOINT=iluminys_minio:9000"
echo ""
echo "Redeploy iluminys-web SEM minio/redis/postgres embutidos."
echo "Remova contentores legados parados quando o redeploy estiver estável:"
echo "  docker rm ${LEGACY_PG} ${LEGACY_MINIO} ${LEGACY_REDIS_WEB}"
