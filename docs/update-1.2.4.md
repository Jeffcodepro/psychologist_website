# Atualização para 1.2.4 — controle de formulários

Esta revisão mantém a confirmação ao recarregar, bloqueia reenvios por dez minutos, limita contatos por IP/e-mail e serializa a verificação para impedir duplicatas simultâneas. Inclui as alterações locais anteriores de cards, botões e formulário. Veja os critérios e a configuração externa em [proteção do formulário](contact-protection.md).

Há uma nova migração que acrescenta um índice, sem alterar contatos: `20261002180000_index_contact_submission_limits.rb`. O Rails aplicará também migrações anteriores ainda pendentes.

## 1. No Mac: salvar e empacotar

Na pasta do projeto:

```sh
cd /Users/jeffersondossantos/code/Jeffcodepro/psychologist_website
git status --short
git add -- app config db/migrate db/schema.rb test deploy docs README.md
git diff --cached --check
git diff --cached --stat
git ls-files --cached -- .env config/master.key 'config/credentials/*.key'
```

O último comando deve ficar sem saída. Revise as mudanças antes do commit; nunca inclua chaves, `.env` ou links privados.

```sh
git commit -m "Protege formularios contra reenvios e envios simultaneos"
mkdir -p tmp
git archive --format=tar.gz --output=tmp/rosemarydias-source-1.2.4.tar.gz HEAD
tar -tzf tmp/rosemarydias-source-1.2.4.tar.gz app/services/contact_submission_guard.rb db/migrate/20261002180000_index_contact_submission_limits.rb
shasum -a 256 tmp/rosemarydias-source-1.2.4.tar.gz
```

O pacote usa somente o conteúdo commitado. Se não houver alterações para commitar, confirme que os arquivos acima já estão em HEAD. Não exporte/importe novamente os dados: mantenha o banco atual de produção.

## 2. Pelo SFTP do Termius

Envie `tmp/rosemarydias-source-1.2.4.tar.gz` do Mac para `/opt/rosemarydias/rosemarydias-source-1.2.4.tar.gz` no **banco-de-dados-manager02**.

## 3. No banco-de-dados-manager02: backup e imagem

```sh
ls -lh /opt/rosemarydias/rosemarydias-source-1.2.4.tar.gz
sha256sum /opt/rosemarydias/rosemarydias-source-1.2.4.tar.gz
mkdir -p /opt/rosemarydias/releases
mkdir /opt/rosemarydias/releases/1.2.4
tar -xzf /opt/rosemarydias/rosemarydias-source-1.2.4.tar.gz -C /opt/rosemarydias/releases/1.2.4
cd /opt/rosemarydias/releases/1.2.4
bash deploy/swarm/backup-production.sh
```

Compare o hash com o Mac. Prossiga depois de “Backup concluído” e guarde o backup pelo SFTP fora do servidor. Se a pasta de release já existir, confira seu conteúdo antes de reutilizá-la.

```sh
docker build -t psychologist-website:1.2.4 .
docker image inspect psychologist-website:1.2.4 --format 'Imagem disponível: {{.Id}}'
```

A imagem é local nesse node; preserve a constraint `node.hostname == banco-de-dados-manager02`.

## 4. Portainer: migração primeiro

Na stack **psychologist-release**, preserve a configuração existente e defina a variável:

```text
APP_IMAGE=psychologist-website:1.2.4
```

Se o campo `image:` for fixo, atualize-o para a mesma imagem. Atualize com **Re-pull image desativado**.

No **manager02**:

```sh
docker service ps psychologist-release_migrate --no-trunc
docker service logs --tail 60 psychologist-release_migrate
```

Espere a tarefa da imagem 1.2.4 terminar como **Complete**, sem erro. `0/1` depois de concluir a migração é esperado. Não atualize a web se a migração falhar.

## 5. Portainer: aplicação

Na stack **psychologist-app**, altere `APP_IMAGE` para `psychologist-website:1.2.4` e atualize com **Re-pull image desativado**. Se houver `image:` fixo, altere esse campo.

**Preserve a stack atual que acabou de receber a configuração correta de e-mail.** Não substitua essa stack inteira pelos exemplos locais de instalação: mantenha `SMTP_USERNAME`, `MAILER_FROM`, `CONTACT_RECIPIENT` e o secret SMTP que foi validado (por exemplo, `psychologist_smtp_password_v4`). Mantenha também Cloudinary, master key, banco, redes e volumes. Não é necessário criar outro secret para esta atualização.

O `stop-first` provoca uma breve interrupção ao trocar o container. Não execute seeds, importação de dados ou recriação de volumes.

## 6. Validar

No **manager02**:

```sh
docker service inspect psychologist-app_web --format 'Imagem: {{.Spec.TaskTemplate.ContainerSpec.Image}}'
docker service ps psychologist-app_web --no-trunc
```

No **banco-de-dados-manager02**:

```sh
APP_CONTAINER=$(docker ps --filter label=com.docker.swarm.service.name=psychologist-app_web --filter status=running --format '{{.ID}}')
docker exec "$APP_CONTAINER" /rails/bin/docker-entrypoint bin/rails db:abort_if_pending_migrations
curl -I https://rosemarydias.com
```

No navegador sem login administrativo:

1. Envie uma única mensagem identificada como teste e confira o recebimento no painel/e-mail.
2. Recarregue o contato e abra outra aba: a confirmação deve permanecer e o formulário deve ficar oculto por dez minutos.
3. Após dez minutos, recarregue: o formulário volta a ficar disponível. O limite de cinco contatos/hora por IP continua valendo.
4. Não faça rajadas de requisições em produção: os cenários de abuso e concorrência são exercitados nos testes locais.

A proteção entra em vigor ao atualizar o código; não precisa republicar as páginas no CMS. Configuração Cloudflare/Redis segue o [guia específico](contact-protection.md).

## Se precisar voltar

Volte a imagem da stack web para a versão registrada em `image.txt` no backup, preservando todos os secrets atuais. O novo índice pode permanecer no banco; não execute `db:rollback` ou restaure um backup inteiro para remover esta proteção. Se também estiver subindo os ajustes das versões 1.2.0–1.2.3, considere a compatibilidade das opções visuais salvas antes de voltar a uma imagem antiga.

Nenhum commit ou deploy foi executado automaticamente nesta revisão.

## Verificação local desta revisão

- 39 testes de servidor, 286 verificações: recarga, sessão nova, troca de IP/e-mail, expiração, janela horária, tentativas inválidas, honeypot, CSRF, isolamento e concorrência.
- 6 testes de navegador, 66 verificações: confirmação após envio Turbo, recarga completa, nova aba e regressões do editor/formulário.
- Nenhuma falha ou erro nesses testes. E-mails externos não são enviados pelo ambiente de teste.
- Brakeman: zero erros e zero alertas. `zeitwerk:check`, sintaxe YAML das stacks e `git diff --check` passaram.
- Migração do índice aplicada no banco de desenvolvimento local. Produção ainda precisa da atualização descrita acima.

Estes resultados validam os cenários testados; não são garantia contra todo ataque DDoS nem uma medição de capacidade do servidor de produção.
