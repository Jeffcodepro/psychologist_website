#!/bin/bash
set -euo pipefail

# Run on the data node with the two new, empty volumes, before deploying web.
bundle_dir="${1:?Informe a pasta de exportação enviada por SCP}"
bundle_dir="$(cd "$bundle_dir" && pwd)"
for file in database.dump storage.tar.gz manifest.json SHA256SUMS; do
  test -f "$bundle_dir/$file" || { echo "Arquivo ausente: $file" >&2; exit 1; }
done
(cd "$bundle_dir" && sha256sum -c SHA256SUMS)

database_service="${DB_SERVICE_NAME:-psychologist-db_postgres}"
storage_volume="${STORAGE_VOLUME_NAME:-psychologist_storage}"
database_container="$(docker ps --filter "label=com.docker.swarm.service.name=$database_service" --format '{{.ID}}')"
if [ -z "$database_container" ] || [[ "$database_container" == *$'\n'* ]]; then
  echo "Execute no node com exatamente um container da stack psychologist-db/postgres." >&2
  exit 1
fi

docker volume inspect "$storage_volume" >/dev/null
docker run --rm --volume "$storage_volume:/data" alpine:3.22 sh -eu -c \
  'test -z "$(find /data -mindepth 1 ! -name .keep -print -quit)"' || {
  echo "O volume de imagens não está vazio. Restauração cancelada." >&2; exit 1;
}

table_count="$(docker exec "$database_container" psql -U postgres -d psychologist_production -Atc \
  "SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public'")"
if [ "$table_count" != "0" ]; then
  echo "O banco já contém tabelas. Restauração cancelada para preservar os dados." >&2
  exit 1
fi

docker exec -i "$database_container" sh -eu -c '
  export PGPASSWORD="$(cat /run/secrets/db_password)"
  exec pg_restore --host=127.0.0.1 --username=psychologist --dbname=psychologist_production \
    --no-owner --no-acl --exit-on-error --single-transaction
' < "$bundle_dir/database.dump"

docker run --rm -i --volume "$storage_volume:/data" alpine:3.22 sh -eu -c \
  'tar xzf - -C /data; chown -R 1000:1000 /data' < "$bundle_dir/storage.tar.gz"

echo "Banco e imagens restaurados. Execute a stack de migração antes da aplicação."
