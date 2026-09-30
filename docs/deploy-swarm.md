# Deploy no Portainer / Docker Swarm

Destino: **https://rosemarydias.com**. Projeto real: Ruby 3.3.5, Rails 8.1.4, PostgreSQL e imagens em disco. Duas stacks permanentes (`psychologist-db` e `psychologist-app`) e uma temporária para migrações. Não execute seeds ao importar o site local.

## Correção na instalação já em execução

A aplicação e o banco já estão no Swarm. Para aplicar esta correção:

1. No Portainer, abra **Stacks → psychologist-app → Editor** e substitua o conteúdo por [`application.yml`](../deploy/swarm/application.yml).
2. Confira as variáveis em [`variables.env.example`](../deploy/swarm/variables.env.example). O YAML já possui os padrões desta instalação; variáveis preenchidas no Portainer têm prioridade. Use `APP_IMAGE=psychologist-website:1.0.0` e `TRAEFIK_CERTRESOLVER=letsencryptresolver`.
3. Atualize a stack sem habilitar o download forçado da imagem, que foi construída no node `banco-de-dados-manager02`. Não é necessário reconstruir a imagem para esta correção de labels.
4. Não recrie o banco, não repita a importação e não execute migrações apenas por esta mudança de configuração. [`database.yml`](../deploy/swarm/database.yml) continua com os mesmos volumes e secrets; [`migrate.yml`](../deploy/swarm/migrate.yml) permanece reservado às atualizações que precisarem de migração.

A rede da aplicação usa somente `traefik.swarm.network`. No Traefik 3.6.1, misturar essa label com `traefik.docker.network` faz o serviço ser ignorado.

O Traefik é uma instalação compartilhada, administrada fora deste repositório. Na configuração original dele, mantenha o argumento abaixo para preservar a correção aplicada pelo terminal:

```text
--certificatesresolvers.letsencryptresolver.acme.email=jeffersonoliveira1212@gmail.com
```

O valor deve ser o endereço puro, sem formatação Markdown ou `mailto:`. No `manager02`, confirme o argumento aplicado e teste o HTTPS após a atualização:

```sh
docker service inspect traefik_traefik --format '{{range .Spec.TaskTemplate.ContainerSpec.Args}}{{println .}}{{end}}' | grep -F -- '--certificatesresolvers.letsencryptresolver.acme.email='
curl -I https://rosemarydias.com
```

## 1. Variáveis da instalação

Em **Environment variables** da stack no Portainer, preencha os valores de [`variables.env.example`](../deploy/swarm/variables.env.example). Esse arquivo não contém senhas.

| Variável | Valor |
| --- | --- |
| `APP_IMAGE` | `psychologist-website:1.0.0`, construída no node `banco-de-dados-manager02` |
| `APP_HOST` | `rosemarydias.com` |
| `TRAEFIK_PUBLIC_NETWORK` | `network_swarm_public` |
| `TRAEFIK_CERTRESOLVER` | `letsencryptresolver`, já existente no Traefik |
| `TRAEFIK_HTTP_ENTRYPOINT` / `TRAEFIK_HTTPS_ENTRYPOINT` | `web` / `websecure` |

O Gmail e o destinatário estão configurados como `jeffersonoliveira1212@gmail.com`, conforme o ambiente local. Podem ser alterados pelas variáveis `SMTP_USERNAME` e `CONTACT_RECIPIENT`. Um destinatário definido no cadastro do cliente tem prioridade.

## 2. Preparar o Swarm

Esta instalação usa **`banco-de-dados-manager02` para banco, imagem Docker e uploads**, com uma réplica web. As três stacks têm essa restrição por hostname. O Traefik permanece no manager `manager02`. Somente em uma instalação nova, crie a rede privada no manager se ainda não existir:

```sh
docker network inspect psychologist_backend >/dev/null 2>&1 ||
  docker network create --driver overlay --attachable --internal psychologist_backend
```

A rede pública já deve existir e ser compartilhada com o Traefik. No **`banco-de-dados-manager02`**, crie os volumes (ou selecione esse node em Volumes no Portainer):

```sh
docker volume create psychologist_postgres_data
docker volume create psychologist_storage
docker volume create psychologist_rate_limits
```

Mantenha as três stacks nesse hostname enquanto usar a imagem Docker e os volumes locais. Os volumes não migram automaticamente entre nodes. O volume de rate limit preserva os limites de acesso nos reinícios; a configuração usa um único processo Puma. Para várias réplicas, primeiro migre uploads para armazenamento compartilhado e configure Redis para rate limit.

## 3. Secrets e configuração do banco

Em **Secrets → Add secret**, crie:

| Nome exato | Conteúdo |
| --- | --- |
| `psychologist_rails_master_key_v1` | Conteúdo de `config/master.key` local, correspondente ao `config/credentials.yml.enc` incluído na imagem |
| `psychologist_postgres_admin_password_v1` | Uma senha nova e forte para administração do PostgreSQL |
| `psychologist_db_password_v1` | Outra senha nova e forte, exclusiva da conexão Rails |
| `psychologist_smtp_password_v1` | Valor de `SMTP_PASSWORD` local (senha de aplicativo Gmail) |
| `psychologist_openai_api_key_v1` | Valor de `OPENAI_API_KEY` local para manter a tradução com IA |

Cole apenas o valor, sem aspas nem `NOME=`. Não envie o `.env` para a stack. A imagem não contém `.env`, master key, banco ou uploads. O entrypoint lê `/run/secrets` antes de iniciar Rails. O `secret_key_base` já existe nas credentials criptografadas; não precisa gerar outro nem colocá-lo no YAML.

Em **Configs → Add config**, crie `psychologist_db_init_v1` com o conteúdo de [`init-database.sh`](../deploy/swarm/init-database.sh). Ele cria a conta `psychologist` sem privilégios de superusuário. Só roda na inicialização de um volume de banco vazio. Alterar um secret depois não altera automaticamente senhas já gravadas no PostgreSQL.

## 4. Construir a imagem no servidor, sem registry

No projeto local, gere o pacote a partir do código já commitado:

```sh
git archive --format=tar.gz --output=tmp/rosemarydias-source.tar.gz HEAD
```

No Termius, conectado ao `banco-de-dados-manager02`, prepare a pasta:

```sh
mkdir -p /opt/rosemarydias/app
```

Pelo SFTP do Termius, envie `tmp/rosemarydias-source.tar.gz` para `/opt/rosemarydias/`. No terminal desse mesmo node:

```sh
tar -xzf /opt/rosemarydias/rosemarydias-source.tar.gz -C /opt/rosemarydias/app
cd /opt/rosemarydias/app
docker build -t psychologist-website:1.0.0 .
```

A imagem deve existir no node em que a aplicação e a migração executam. Use a mesma tag nas duas stacks e não force o download no Portainer. Nos próximos builds, utilize uma tag nova. Um registry é opcional para este arranjo de um único node da aplicação; para distribuir a imagem entre nodes, será necessário disponibilizá-la em cada destino ou usar um registry.

## 5. Copiar o site local

Pare de editar o CMS durante a exportação para manter banco e imagens coerentes. No projeto local:

```sh
bin/export_deploy
```

O comando informa uma pasta `tmp/deploy-export/DATA/` contendo `database.dump`, `storage.tar.gz`, `manifest.json` e `SHA256SUMS`. Inclui páginas, rascunhos, publicações, configurações, usuários, mensagens e imagens. O original não é alterado. O dump usa o `pg_dump` instalado; nesta máquina ele é versão 17, por isso a stack de destino usa PostgreSQL 17, mesmo que o servidor local seja 15.

Transfira **essa pasta inteira** e o script de restauração pelo SFTP do Termius ao `banco-de-dados-manager02`, em uma pasta privada. Se preferir SCP no computador local:

```sh
scp -r tmp/deploy-export/DATA usuario@SERVIDOR:/CAMINHO_PRIVADO/
scp deploy/swarm/restore-local-data.sh usuario@SERVIDOR:/CAMINHO_PRIVADO/
```

O backup contém dados pessoais e hashes de senha. Guarde em pasta privada; não envie ao Git nem a um diretório público. `.env`, master key e o link privado ficam fora desse pacote. As contas e os hashes de senha são preservados. O link de `tmp/admin-access.txt` continua válido, substituindo apenas `http://localhost:3000` por `https://rosemarydias.com`; guarde-o separadamente.

## 6. Ordem no Portainer

1. Crie a stack **`psychologist-db`** colando [`database.yml`](../deploy/swarm/database.yml). Aguarde o PostgreSQL saudável. Não publique a porta 5432.
2. No terminal do `banco-de-dados-manager02`, execute:

   ```sh
   bash /CAMINHO_PRIVADO/restore-local-data.sh /CAMINHO_PRIVADO/DATA
   ```

   O script verifica os checksums e recusa sobrescrever um banco com tabelas ou um volume de imagens ocupado. Restaura usando o usuário Rails e corrige a permissão das imagens para UID 1000. É uma importação inicial, não um comando de restauração sobre produção existente.
3. Crie **`psychologist-release`** com [`migrate.yml`](../deploy/swarm/migrate.yml) e `APP_IMAGE`. Aguarde a tarefa terminar com **exit code 0 / Complete**, conferindo os logs. O container terminar é esperado. A etapa ajusta o ambiente do banco restaurado para produção e executa migrações uma única vez. Depois remova somente essa stack temporária.
4. Crie **`psychologist-app`** com [`application.yml`](../deploy/swarm/application.yml) e as variáveis do passo 1. Aguarde o healthcheck `/up` saudável. A aplicação não executa migrações nem seeds no boot. Não publique a porta 3000.
5. No DNS, aponte um registro **A** de `rosemarydias.com` para o IP atendido pelo Traefik. Só configure AAAA se houver IPv6 funcional. Traefik precisa receber portas 80/443 e usar seu certresolver existente. `www` não foi incluído: o endereço configurado é `rosemarydias.com`.

O cliente principal já é identificado por `APP_HOST`, preservando o cadastro local. Para futuros domínios, cadastre `Tenant.domain`, configure DNS e adicione regras TLS no Traefik; só mudar o banco não cria roteamento nem certificados.

## 7. Conferir a instalação

Abra o site em janela privada e o CMS pelo link privado. Confirme imagens, artigos, formulários e login. O endereço `/admin` continua protegido, e não existe cadastro público.

No console do container web no Portainer, execute comandos Rails **com o entrypoint**, pois `docker exec` não carrega os secrets automaticamente:

```sh
/rails/bin/docker-entrypoint bin/rails runner 'puts({pages: Page.count, users: User.count, images: ActiveStorage::Blob.count, missing_images: ActiveStorage::Blob.find_each.count { |b| !b.service.exist?(b.key) }, email_ready: EmailDelivery.configured?(Tenant.find_by(primary: true)), translation_ready: ENV["OPENAI_API_KEY"].present?}.to_json)'
```

Compare as contagens com `manifest.json`; `missing_images` deve ser zero. Faça um envio de contato de teste quando quiser validar a entrega externa. Nenhum e-mail é enviado pela importação ou pelo comando acima. Para criar próximos clientes: `/rails/bin/docker-entrypoint bin/provision_tenant` em console interativo.

## Atualização de código: exclusão de blocos e imagens

Estas correções alteram o código Ruby e as views. A imagem `1.0.0` já instalada não recebe essas alterações apenas por atualizar o YAML. Envie o código atualizado ao `banco-de-dados-manager02`, construa uma tag nova e atualize `APP_IMAGE` na stack `psychologist-app`.

No projeto local, inclua os arquivos novos e modificados no commit antes de usar `git archive`; ele empacota somente o conteúdo commitado. Depois envie o pacote pelo SFTP do Termius e, no node da aplicação:

```sh
cd /opt/rosemarydias/app
tar -xzf /opt/rosemarydias/rosemarydias-source.tar.gz -C /opt/rosemarydias/app
docker build -t psychologist-website:1.0.1 .
```

No Portainer, use `APP_IMAGE=psychologist-website:1.0.1` na stack `psychologist-app`, mantendo a mesma restrição de node. Não force o download da imagem. Esta atualização não acrescenta migrações e não exige reimportar banco ou imagens.

Após a atualização, prepare uma vez as versões menores das imagens já existentes. No terminal do `banco-de-dados-manager02`:

```sh
APP_CONTAINER=$(docker ps --filter label=com.docker.swarm.service.name=psychologist-app_web --format '{{.ID}}')
docker exec "$APP_CONTAINER" /rails/bin/docker-entrypoint bin/rails media:prepare
```

O comando é repetível, reaproveita versões já prontas e preserva os originais. A tarefa informa o total de variantes e eventuais falhas sem exibir credenciais. Os próximos uploads solicitam essas versões em segundo plano; o acesso à imagem também pode gerá-la caso ainda não esteja pronta. Elas ficam no volume `psychologist_storage`, junto dos originais, e são servidas em WebP por URLs com cache. O Dockerfile já instala libvips, necessário para esse processamento. No desenvolvimento local, instale libvips também (`brew install vips` no macOS).

Confira no navegador: exclusão confirmada/cancelada na pré-visualização, exclusão do último bloco, permanência do idioma e abertura das imagens da home. A versão publicada só perde o bloco depois de publicar o rascunho.

## Atualizações e backups

Antes de atualizar o código, faça backup do banco e das imagens. Construa uma imagem com tag nova no `banco-de-dados-manager02`, execute novamente a stack temporária de migração com essa tag, aguarde sucesso e atualize a stack da aplicação. `stop-first` evita duas instâncias com arquivos locais durante a troca; haverá uma breve interrupção. Rollback da imagem não desfaz migrações do banco: migrações futuras precisam ser compatíveis com a versão anterior ou ter um plano de restauração.

Agende backup periódico dos dois volumes para fora do servidor e teste a recuperação. Não remova os volumes ao remover stacks. Não use `db:reset`, `db:drop`, `db:seed` nem o script de importação inicial para atualizar o site em produção.

Referências consultadas: [stacks no Swarm](https://docs.docker.com/engine/swarm/stack-deploy/), [Docker Secrets](https://docs.docker.com/engine/swarm/secrets/), [Traefik/Swarm](https://doc.traefik.io/traefik/reference/install-configuration/providers/swarm/), [pg_dump](https://www.postgresql.org/docs/17/app-pgdump.html) e [Rails atrás de proxy HTTPS](https://guides.rubyonrails.org/configuring.html#config-assume-ssl).
