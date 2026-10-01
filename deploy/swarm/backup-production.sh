#!/usr/bin/env bash
# Run on the node hosting both services. Reads data; never stops or restores them.
set -euo pipefail
umask 077

one_container() {
  local service="$1" ids
  ids=$(docker ps --filter "label=com.docker.swarm.service.name=$service" --filter status=running --format '{{.ID}}')
  if [[ -z "$ids" || "$ids" == *$'\n'* ]]; then
    echo "Esperado um container ativo para $service neste node. Nenhum backup criado." >&2
    exit 1
  fi
  printf '%s' "$ids"
}

app_container=$(one_container psychologist-app_web)
db_container=$(one_container psychologist-db_postgres)
backup_root=${1:-/opt/rosemarydias/backups}
mkdir -p "$backup_root"
backup_dir=$(mktemp -d "$backup_root/pre-1.1.1-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")
trap 'echo "Backup incompleto em $backup_dir. Não prossiga com a atualização." >&2' ERR

docker inspect --format '{{.Config.Image}}' "$app_container" > "$backup_dir/image.txt"
docker inspect --format '{{.Image}}' "$app_container" > "$backup_dir/image-id.txt"
docker exec "$db_container" sh -ec '
  export PGPASSWORD="$(cat /run/secrets/postgres_admin_password)"
  exec pg_dump --host=127.0.0.1 --username=postgres --dbname=psychologist_production --format=custom --no-owner --no-acl
' > "$backup_dir/database.dump"
docker exec "$app_container" tar -czf - -C /rails/storage . > "$backup_dir/storage.tar.gz"

test -s "$backup_dir/database.dump"
test -s "$backup_dir/storage.tar.gz"
docker exec -i "$db_container" pg_restore --list < "$backup_dir/database.dump" > /dev/null
tar -tzf "$backup_dir/storage.tar.gz" > /dev/null
(
  cd "$backup_dir"
  sha256sum database.dump storage.tar.gz image.txt image-id.txt > SHA256SUMS
)
trap - ERR
printf 'Backup concluído: %s\n' "$backup_dir"
printf 'Baixe esta pasta pelo SFTP e guarde em local privado fora do servidor.\n'
