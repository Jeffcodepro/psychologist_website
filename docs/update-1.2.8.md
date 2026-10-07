# Atualização 1.2.8 — vídeos, imagens e configuração por tela

## O que mudou

- A foto recortada em tamanho **Grande** usa até 600 px e recebe uma coluna maior; a **Média** usa até 400 px. O limite da tela continua respeitado. Vale para o formato sem moldura e para fotos com remoção de fundo ativada.
- **Mídia → Tipo de mídia** permite escolher imagem, YouTube ou arquivo MP4/WebM. Funciona em conteúdo, banner, sequência, card, galeria e card de artigo. O YouTube ganha miniatura assim que o link válido é colado. Arquivos do computador têm prévia antes de salvar.
- O visitante toca em reproduzir para abrir um player completo, com controles e fechamento por botão ou Escape. Não há reprodução automática com som. Sequências que contêm vídeos têm navegação manual; um carrossel de cards pausa quando um vídeo é aberto.
- Os cards mantêm suas dimensões. A posição da mídia e seu overlay continuam nos controles existentes. Em **Enquadramento por tela**, ajuste encaixe, escala e posição do vídeo em Desktop, Tablet e Mobile; o arquivo é compartilhado. A miniatura recebe esse enquadramento; o player abre inteiro para não cortar seus controles.
- **Cards → Layout dos cards por tela**: formato horizontal/vertical, quebra/carrossel, alinhamento, posição, avanço automático e intervalo independentes. Tablet e Mobile podem herdar o Desktop. Os cards por linha são definidos para cada tela. O carrossel permanece compacto e só ganha navegação quando falta espaço.
- Imagens e vídeos idênticos são reaproveitados dentro do mesmo site. Publicar usa vínculos ao original e não faz outro upload. Exclusões respeitam os arquivos ainda utilizados na página pública.

No Cloudinary, o SDK envia vídeos como `resource_type: video`; continua usando `CLOUDINARY_URL`/o secret atual. Não há chave do YouTube nem nova dependência externa. MP4 deve usar um codec compatível com o navegador, como H.264; WebM também é aceito. Limite: **20 MB por vídeo**, **10 MB por imagem** e **60 MB somados por salvamento**. Para vídeos maiores, use YouTube ou comprima antes de enviar. Vídeos privados, removidos ou com incorporação desabilitada pelo proprietário podem não reproduzir no YouTube.

Fontes técnicas: [Cloudinary — upload de imagens e vídeos](https://cloudinary.com/documentation/rails_image_and_video_upload), [YouTube — player incorporado](https://developers.google.com/youtube/player_parameters).

## Localhost

O acesso e o destinatário da conta Rosemary deste banco local já foram alterados para **rosemary.dias.psi@gmail.com**. A senha foi preservada. Isso não altera automaticamente a base da VPS nem a conta usada para autenticar no SMTP.

No projeto:

```bash
bundle install
bin/rails db:migrate
```

Pare o servidor local com `Ctrl+C` e inicie novamente:

```bash
bin/rails server
```

Reiniciar é necessário para carregar a política que permite o player do YouTube. Use o novo e-mail e a mesma senha no painel. No desenvolvimento, o serviço `local` continua funcionando; para usar Cloudinary, configure o serviço e a credencial que você já possui.

## Antes do deploy

Pacote e checksum, na pasta `tmp` do projeto:

- `rosemarydias-source-1.2.8.tar.gz`
- `rosemarydias-source-1.2.8.tar.gz.sha256`

Envie os dois por SFTP para `/opt/rosemarydias/` no **banco-de-dados-manager02**. O pacote contém código, não contém `.env`, senhas, master key, banco ou mídias locais.

Mantenha a imagem anterior disponível para rollback. A alteração de banco adiciona apenas `video_settings` a seções, cards e slides. Não apaga conteúdo e não requer restaurar a base local em produção.

## 1. Preparar, fazer backup e construir no worker

No **banco-de-dados-manager02**, execute o bloco inteiro. Ele interrompe se a pasta da versão já existe, se não encontrar exatamente um web ativo, se o checksum falhar ou se o backup falhar:

```bash
(
  set -euo pipefail
  cd /opt/rosemarydias
  sha256sum -c rosemarydias-source-1.2.8.tar.gz.sha256
  APP_CONTAINER=$(docker ps -q --filter label=com.docker.swarm.service.name=psychologist-app_web --filter status=running)
  if [[ -z "$APP_CONTAINER" || "$APP_CONTAINER" == *$'\n'* ]]; then
    echo 'Esperado exatamente um web ativo neste node.' >&2
    exit 1
  fi
  if [[ -e releases/1.2.8 ]]; then
    echo 'releases/1.2.8 já existe. Confira a tentativa anterior antes de continuar; não sobrescreva uma versão em uso.' >&2
    exit 1
  fi
  mkdir -p releases
  mkdir releases/1.2.8
  tar -xzf rosemarydias-source-1.2.8.tar.gz -C releases/1.2.8
  cd releases/1.2.8
  docker inspect --format '{{.Config.Image}}' "$APP_CONTAINER" > previous-image.txt
  bash deploy/swarm/backup-production.sh
  docker build -t psychologist-website:1.2.8 .
  docker image inspect psychologist-website:1.2.8 --format 'Nova imagem: {{.Id}}'
  cat previous-image.txt
)
```

Baixe a pasta de backup indicada por SFTP e guarde-a fora do servidor. Se apenas o build falhar, entre na pasta criada, confirme o backup e repita somente `docker build -t psychologist-website:1.2.8 .`. Não extraia o pacote novamente sobre uma release já em uso.

## 2. Migração no Portainer

No Portainer, stack **psychologist-release**:

1. Mude `APP_IMAGE` para `psychologist-website:1.2.8`. Se `image:` estiver fixo no YAML, altere essa linha também.
2. Preserve redes, banco e secrets atuais. O exemplo atualizado está em `deploy/swarm/migrate.yml`.
3. Atualize com **Re-pull image desativado**; a imagem é local ao worker.

Confira no worker:

```bash
docker ps -a --filter label=com.docker.swarm.service.name=psychologist-release_migrate --format 'ID={{.ID}} | IMAGEM={{.Image}} | STATUS={{.Status}}'
```

A tarefa da imagem **1.2.8** precisa terminar em **Exited (0)**. Se falhar, consulte `docker logs ID_DA_TAREFA_1_2_8` e não atualize o web ainda. Não confunda tarefas antigas bem-sucedidas com a tarefa desta versão.

## 3. Atualizar a aplicação no Portainer

Na stack **psychologist-app**, altere:

```yaml
image: ${APP_IMAGE:-psychologist-website:1.2.8}
```

Se a variável `APP_IMAGE` estiver preenchida no Portainer, mude-a também para `psychologist-website:1.2.8`; ela prevalece sobre o valor depois de `:-`.

Em `environment`, confira:

```yaml
ACTIVE_STORAGE_SERVICE: cloudinary
CLOUDINARY_URL_FILE: /run/secrets/cloudinary_url
CONTACT_RECIPIENT: rosemary.dias.psi@gmail.com
```

Altere a label de limite de upload para permitir o formulário com vídeos:

```yaml
- traefik.http.middlewares.psychologist-upload.buffering.maxRequestBodyBytes=67108864
```

Preserve a configuração SMTP que já funciona, principalmente a correspondência entre `SMTP_USERNAME` e a senha de aplicativo no secret. O destinatário pode ser diferente da conta que envia. Alterar o login do painel não altera a autenticação do Gmail. Se o SMTP já usa Rosemary, mantenha:

```yaml
SMTP_USERNAME: rosemary.dias.psi@gmail.com
MAILER_FROM: rosemary.dias.psi@gmail.com
```

**Não substitua o YAML inteiro configurado pelos exemplos.** Preserve banco, redes, volumes, domínio, secrets atuais e a restrição para `banco-de-dados-manager02`. Nos exemplos novos, `SMTP_SECRET_NAME` permite indicar o secret existente; não recrie senhas para esta atualização.

Atualize com **Re-pull desativado**. Aguarde o web estabilizar:

```bash
docker ps --filter label=com.docker.swarm.service.name=psychologist-app_web --format 'ID={{.ID}} | IMAGEM={{.Image}} | STATUS={{.Status}}'
```

Deve mostrar **1.2.8** e **healthy**. A atualização pode causar uma breve interrupção. O Portainer precisa estar conectado a um manager saudável; o nome `manager02` não garante que este node seja manager. Build, logs e consulta dos containers podem rodar no worker.

## 4. Trocar o acesso e destinatário também na produção

Execute somente depois de o web 1.2.8 estar saudável:

```bash
APP_CONTAINER=$(docker ps -q --filter label=com.docker.swarm.service.name=psychologist-app_web --filter status=running)
docker exec \
  -e SITE_DOMAIN=rosemarydias.com \
  -e SITE_EMAIL=rosemary.dias.psi@gmail.com \
  "$APP_CONTAINER" /rails/bin/docker-entrypoint bin/rails site:update_email
```

A operação altera, em uma transação, o e-mail do administrador e `Tenant.contact_recipient`, que prevalece sobre a variável de ambiente. A senha e o endereço privado de acesso são preservados. Entre com **rosemary.dias.psi@gmail.com** e a senha atual.

Se houver mais de um administrador, o comando interrompe sem alterar nada. Consulte os administradores apenas desse site e escolha a conta a alterar:

```bash
docker exec "$APP_CONTAINER" /rails/bin/docker-entrypoint bin/rails runner 'site = Tenant.find_by!(domain: "rosemarydias.com"); site.users.where(admin: true).each { |user| puts "#{user.id}: #{user.email}" }'
```

Repita o comando de atualização acrescentando `-e ADMIN_USER_ID=ID_ESCOLHIDO` antes do nome do container. Não altere todas as contas em massa.

## 5. Conferir e publicar o conteúdo

- Confira que Desktop/Tablet/Mobile preservam valores diferentes em Cards.
- Compare uma foto recortada em Média e Grande.
- Cole um link público do YouTube e confira miniatura e reprodução.
- Envie um pequeno MP4/WebM, confira prévia e reprodução no site.
- Salve os rascunhos e use **Publicar site…** para as páginas desejadas.
- Confira o público fora da sessão do administrador e envie um formulário de teste para o destinatário novo. A disponibilidade/autenticação do Gmail deve ser confirmada na VPS; os testes locais não enviam e-mail real.

A auditoria de armazenamento continua disponível:

```bash
docker exec "$APP_CONTAINER" /rails/bin/docker-entrypoint bin/rails media:audit
```

## 6. Manter a atual e a anterior

Faça isso **após validar a nova versão** e guardar o backup externo. O roteiro preserva a versão que estava ativa antes do deploy, mesmo que não seja a 1.2.7.

No worker:

```bash
cd /opt/rosemarydias/releases/1.2.8
PREVIOUS_IMAGE=$(cat previous-image.txt)
PREVIOUS_TAG=${PREVIOUS_IMAGE%%@*}
PREVIOUS_VERSION=${PREVIOUS_TAG##*:}
python3 deploy/swarm/cleanup-releases.py --current 1.2.8 --rollback "$PREVIOUS_VERSION"
```

Essa primeira execução mostra a lista e não exclui nada. Confira se a atual e a anterior aparecem em **Preservar**. As duas imagens e pastas de código precisam existir; se a anterior não estiver no servidor, recupere-a antes da limpeza.

Depois de conferir, aplique:

```bash
python3 deploy/swarm/cleanup-releases.py --current 1.2.8 --rollback "$PREVIOUS_VERSION" --apply
```

A limpeza se limita a releases numéricas antigas de `/opt/rosemarydias/releases`, seus pacotes/checksums na pasta principal, containers antigos parados das duas stacks da aplicação e tags antigas `psychologist-website`. **Não usa prune, não remove volumes, banco, mídias, secrets nem backups.** Não remove tags mais novas, symlinks ou versões referenciadas por outros containers; se houver versões protegidas, pode conservar mais de duas e informa quais. Precisa de Python 3.9+ e Docker no worker. Não execute simultaneamente com outro deploy.

## Rollback

Leia `previous-image.txt` e volte a stack **psychologist-app** para essa imagem, alterando `APP_IMAGE` e qualquer `image:` fixo. Re-pull continua desativado para a imagem local. Confira `healthy`.

Não rode `db:rollback` e não restaure o banco só para voltar o código: a migração é aditiva. A versão anterior pode não exibir vídeos e os novos ajustes por tela; os dados continuam no banco para retornar à 1.2.8. Evite editar/publicar mídias novas durante esse rollback. O e-mail alterado é um dado do banco e continua valendo.

## Validação

Passaram 185 testes Rails (1.634 verificações), 40 testes distintos de navegador e 4 testes do roteiro de limpeza. O carregamento das classes, os YAMLs das stacks e a sintaxe dos scripts foram verificados. O Brakeman não apontou alertas.

A revisão inclui testes de upload local real no navegador, integração Cloudinary simulada sem consumo de créditos, rejeição de links/arquivos inválidos, reutilização de originais, publicação, remoção com proteção da versão pública, formatos por dispositivo e limpeza em diretórios temporários. Nenhum deploy ou arquivo remoto foi apagado durante os testes.
