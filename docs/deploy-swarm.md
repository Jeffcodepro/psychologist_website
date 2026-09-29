# Deploy no Portainer / Docker Swarm

Destino: **https://rosemarydias.com**. Projeto real: Ruby 3.3.5, Rails 8.1.4, PostgreSQL e imagens em disco. Duas stacks permanentes (`psychologist-db` e `psychologist-app`) e uma temporária para migrações. Não execute seeds ao importar o site local.

## 1. Valores que faltam

Em **Environment variables** da stack no Portainer, preencha os valores de [`variables.env.example`](../deploy/swarm/variables.env.example). Esse arquivo não contém senhas.

| Variável | Valor |
| --- | --- |
| `APP_IMAGE` | Seu registry/repositório com tag, por exemplo `ghcr.io/SEU_USUARIO/psychologist-website:1.0.0` |
| `APP_HOST` | `rosemarydias.com` |
| `TRAEFIK_PUBLIC_NETWORK` | `network_swarm_public`, se este for o nome no seu Swarm |
| `TRAEFIK_CERTRESOLVER` | Nome exato existente no Traefik; não é um novo certificado |
| `TRAEFIK_HTTP_ENTRYPOINT` / `TRAEFIK_HTTPS_ENTRYPOINT` | `web` / `websecure`, ou os nomes da sua instalação |

O Gmail e o destinatário estão configurados como `jeffersonoliveira1212@gmail.com`, conforme o ambiente local. Podem ser alterados pelas variáveis `SMTP_USERNAME` e `CONTACT_RECIPIENT`. Um destinatário definido no cadastro do cliente tem prioridade.

## 2. Preparar o Swarm

Esta primeira instalação usa **um node para banco e imagens**, com uma réplica web. No manager, escolha o node e marque-o:

```sh
docker node update --label-add psychologist_db=true --label-add psychologist_app=true NOME_DO_NODE
docker network create --driver overlay --attachable --internal psychologist_backend
```

A rede pública já deve existir e ser compartilhada com o Traefik. No **node escolhido**, crie os volumes (ou selecione esse node em Volumes no Portainer):

```sh
docker volume create psychologist_postgres_data
docker volume create psychologist_storage
docker volume create psychologist_rate_limits
```

Não marque outros nodes com essas labels enquanto usar volumes locais. Os volumes não migram automaticamente entre nodes. O volume de rate limit preserva os limites de acesso nos reinícios; a configuração usa um único processo Puma. Para várias réplicas, primeiro migre uploads para armazenamento compartilhado e configure Redis para rate limit.

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

## 4. Construir e enviar a imagem

No computador com este projeto e Docker em execução, use uma tag nova. Para VPS Intel/AMD:

```sh
docker login ghcr.io
docker buildx build --platform linux/amd64 \
  --tag ghcr.io/SEU_USUARIO/psychologist-website:1.0.0 --push .
```

Use seu registry real. Para VPS ARM, troque por `linux/arm64`. O Swarm recebe uma imagem pronta; ele não faz o build do Dockerfile. Se a imagem for privada, cadastre as credenciais do registry no Portainer. Informe a mesma tag em `APP_IMAGE` nas stacks de migração e aplicação.

## 5. Copiar o site local

Pare de editar o CMS durante a exportação para manter banco e imagens coerentes. No projeto local:

```sh
bin/export_deploy
```

O comando informa uma pasta `tmp/deploy-export/DATA/` contendo `database.dump`, `storage.tar.gz`, `manifest.json` e `SHA256SUMS`. Inclui páginas, rascunhos, publicações, configurações, usuários, mensagens e imagens. O original não é alterado. O dump usa o `pg_dump` instalado; nesta máquina ele é versão 17, por isso a stack de destino usa PostgreSQL 17, mesmo que o servidor local seja 15.

Transfira **essa pasta inteira** e o script de restauração por SSH/SCP ao node escolhido:

```sh
scp -r tmp/deploy-export/DATA usuario@SERVIDOR:/CAMINHO_PRIVADO/
scp deploy/swarm/restore-local-data.sh usuario@SERVIDOR:/CAMINHO_PRIVADO/
```

O backup contém dados pessoais e hashes de senha. Guarde em pasta privada; não envie ao Git nem a um diretório público. `.env`, master key e o link privado ficam fora desse pacote. As contas e os hashes de senha são preservados. O link de `tmp/admin-access.txt` continua válido, substituindo apenas `http://localhost:3000` por `https://rosemarydias.com`; guarde-o separadamente.

## 6. Ordem no Portainer

1. Crie a stack **`psychologist-db`** colando [`database.yml`](../deploy/swarm/database.yml). Aguarde o PostgreSQL saudável. Não publique a porta 5432.
2. No terminal do node escolhido, execute:

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

## Atualizações e backups

Antes de atualizar, faça backup do banco e das imagens. Publique uma tag nova, execute novamente a stack temporária de migração com essa tag, aguarde sucesso e atualize a stack da aplicação. `stop-first` evita duas instâncias com arquivos locais durante a troca; haverá uma breve interrupção. Rollback da imagem não desfaz migrações do banco: migrações futuras precisam ser compatíveis com a versão anterior ou ter um plano de restauração.

Agende backup periódico dos dois volumes para fora do servidor e teste a recuperação. Não remova os volumes ao remover stacks. Não use `db:reset`, `db:drop`, `db:seed` nem o script de importação inicial para atualizar o site em produção.

Referências consultadas: [stacks no Swarm](https://docs.docker.com/engine/swarm/stack-deploy/), [Docker Secrets](https://docs.docker.com/engine/swarm/secrets/), [Traefik/Swarm](https://doc.traefik.io/traefik/reference/install-configuration/providers/swarm/), [pg_dump](https://www.postgresql.org/docs/17/app-pgdump.html) e [Rails atrás de proxy HTTPS](https://guides.rubyonrails.org/configuring.html#config-assume-ssl).
