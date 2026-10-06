# Atualização para 1.2.3

Esta versão organiza o editor de botões com campos compactos, destino junto à ação e amostra ao vivo. Acrescenta posições antes/depois dos cards ou carrossel, cor e intensidade da camada sobre imagens de fundo dos cards, cor do texto sobre a imagem e um mapa de posições do formulário.

Os cards continuam com até 360 px de largura e altura fixa de 440 px. A versão inclui todas as alterações locais das versões 1.2.0–1.2.2, inclusive prévia do recorte, publicação, SEO, idioma, favicon, fontes, espaçamentos e e-mail.

## 1. No Mac: salvar e empacotar o código

Execute no terminal do Mac, na pasta real do projeto:

```sh
cd /Users/jeffersondossantos/code/Jeffcodepro/psychologist_website
git status --short
git add -- app config db/migrate db/schema.rb test deploy docs README.md
git diff --cached --check
git diff --cached --stat
git ls-files --cached -- .env config/master.key 'config/credentials/*.key'
```

O último comando deve ficar **sem saída**. Se aparecer um arquivo, pare e retire-o do Git antes de criar o pacote. Revise o diff; as chaves continuam no `.env`/master key local e nos Docker Secrets existentes.

```sh
git commit -m "Organiza botoes tonalidade dos cards e posicionamento do formulario"
mkdir -p tmp
git archive --format=tar.gz --output=tmp/rosemarydias-source-1.2.3.tar.gz HEAD
tar -tzf tmp/rosemarydias-source-1.2.3.tar.gz app/assets/stylesheets/components/_layout_controls.scss app/javascript/controllers/paired_input_controller.js db/migrate/20261002160000_add_navigation_key_to_sections.rb
shasum -a 256 tmp/rosemarydias-source-1.2.3.tar.gz
```

`git archive HEAD` inclui somente código já commitado. Se o commit disser que não há alterações, confirme que o commit atual já contém os arquivos listados pelo `tar` e prossiga. Não gere um novo export de dados: a atualização usa o banco e as imagens que já estão em produção.

## 2. Pelo SFTP do Termius: enviar o pacote

Conecte ao servidor **banco-de-dados-manager02**, onde a aplicação e a imagem Docker estão instaladas.

- Arquivo do Mac: `psychologist_website/tmp/rosemarydias-source-1.2.3.tar.gz`
- Destino no servidor: `/opt/rosemarydias/rosemarydias-source-1.2.3.tar.gz`

Este nome é diferente dos pacotes antigos. Preserve a imagem anterior e o backup até terminar a validação.

## 3. No terminal de banco-de-dados-manager02: extrair e fazer backup

```sh
ls -lh /opt/rosemarydias/rosemarydias-source-1.2.3.tar.gz
sha256sum /opt/rosemarydias/rosemarydias-source-1.2.3.tar.gz
mkdir -p /opt/rosemarydias/releases
mkdir /opt/rosemarydias/releases/1.2.3
tar -xzf /opt/rosemarydias/rosemarydias-source-1.2.3.tar.gz -C /opt/rosemarydias/releases/1.2.3
cd /opt/rosemarydias/releases/1.2.3
bash deploy/swarm/backup-production.sh
```

Compare o hash do servidor com o do Mac. Se o arquivo não existir ou o hash for diferente, corrija o envio antes de extrair. Se a pasta da versão já existir por uma tentativa anterior, confira seu conteúdo antes de reutilizá-la.

**Prossiga somente depois de “Backup concluído”.** Baixe a pasta informada pelo SFTP e guarde-a em local privado fora do servidor. Pause as edições no CMS durante a atualização. O backup inclui banco e storage local; as imagens já enviadas ao Cloudinary permanecem naquele ambiente.

## 4. No mesmo servidor: construir a imagem

```sh
cd /opt/rosemarydias/releases/1.2.3
docker build -t psychologist-website:1.2.3 .
docker image inspect psychologist-website:1.2.3 --format 'Imagem disponível: {{.Id}}'
docker run --rm --entrypoint /bin/sh psychologist-website:1.2.3 -c 'test -s /rails/app/assets/stylesheets/components/_layout_controls.scss && test -s /rails/app/javascript/controllers/paired_input_controller.js'
```

O último comando deve terminar sem erro. O build compila os assets. As credenciais de produção são lidas dos secrets quando o container inicia, e não precisam ser copiadas para a pasta da versão nem informadas ao build.

A imagem existe localmente neste node. As stacks mantêm `node.hostname == banco-de-dados-manager02`; preserve essa configuração, já que você não está usando registry.

## 5. No Portainer: executar a migração

Abra **Stacks → psychologist-release → Editor** e use o conteúdo de [deploy/swarm/migrate.yml](../deploy/swarm/migrate.yml).

Em **Environment variables**, altere:

```text
APP_IMAGE=psychologist-website:1.2.3
```

Preserve os secrets `rails_master_key` e `db_password` e a rede existente. Atualize a stack com **Re-pull image desativado**.

No terminal do **manager02**, confira:

```sh
docker service ps psychologist-release_migrate --no-trunc
docker service logs --tail 60 psychologist-release_migrate
```

Espere a tarefa **1.2.3** terminar como **Complete**, sem erro. `0/1` após terminar é normal para este serviço de migração. Se a tarefa falhar, não atualize a web.

A 1.2.3 não adiciona migração própria. Esta etapa aplica as migrações anteriores que estiverem pendentes (`card_settings`, `layout_settings` e `navigation_key`). Se já foram aplicadas, o comando só confirma o estado e termina.

## 6. No Portainer: atualizar a aplicação

Abra **Stacks → psychologist-app → Editor** e use [deploy/swarm/application-cloudinary.yml](../deploy/swarm/application-cloudinary.yml).

Nas variáveis **dessa stack**, configure:

```text
APP_IMAGE=psychologist-website:1.2.3
APP_HOST=rosemarydias.com
ACTIVE_STORAGE_SERVICE=cloudinary
```

Preserve os nomes/valores atuais dos secrets de master key, banco, SMTP, OpenAI e Cloudinary; preserve também as redes e os volumes. Esta atualização não pede novas credenciais. Não substitua os dados da cliente pelos exemplos do arquivo de variáveis.

Atualize com **Re-pull image desativado**. A variável `APP_IMAGE` precisa ser alterada nas **duas stacks**; mudar apenas `psychologist-release` não atualiza o site. O deploy usa `stop-first`, portanto ocorre uma breve interrupção durante a troca.

Não execute seeds, importação, recriação de banco ou remoção dos volumes.

## 7. Conferir a versão e o site

No **manager02**:

```sh
docker service inspect psychologist-app_web --format 'Imagem: {{.Spec.TaskTemplate.ContainerSpec.Image}}'
docker service ps psychologist-app_web --no-trunc
docker service ls --filter name=psychologist-app_web
```

Confirme a imagem **psychologist-website:1.2.3**, tarefa **Running** em **banco-de-dados-manager02** e réplica **1/1**.

No **banco-de-dados-manager02**:

```sh
APP_CONTAINER=$(docker ps --filter label=com.docker.swarm.service.name=psychologist-app_web --filter status=running --format '{{.ID}}')
docker exec "$APP_CONTAINER" /rails/bin/docker-entrypoint bin/rails db:abort_if_pending_migrations
curl -I https://rosemarydias.com
```

O primeiro comando deve terminar sem erro. O site deve responder normalmente por HTTPS. Abra-o também em janela anônima e no celular. Recarregue o painel com `Cmd + Shift + R` no Mac para conferir os assets novos.

## 8. Usar os novos ajustes

- **Editar bloco → Botões → Posição dos botões:** escolha “Abaixo dos cards / carrossel” ou “Acima dos cards / carrossel”. O botão fica fora do conjunto, incluindo seus indicadores. As posições junto ao texto continuam disponíveis. Na prévia, o controle “Botões” também oferece essas posições.
- **Editar card → Composição do card → Imagem de fundo:** escolha a cor da camada, sua intensidade e a cor do texto. **0% remove a camada de cor**; 100% a torna opaca. A prévia é atualizada enquanto você ajusta. Tablet/mobile herdam o desktop quando os campos ficam vazios.
- **Editar bloco de contato → Aparência → Formulário:** o mapa permite acima/abaixo à esquerda, ao centro ou à direita, além das posições ao lado do texto. Ajuste também largura e altura na coluna. Abaixo/esquerda/direita ficam mais perceptíveis com largura compacta ou média; “Toda a largura” naturalmente ocupa a linha inteira. O controle “Formulário” da prévia usa o mesmo mapa.
- Os ajustes por dispositivo continuam separados. No celular, posições laterais herdadas do desktop são empilhadas; uma escolha explícita do mobile prevalece.

**Salve o rascunho e publique a página** para que novas escolhas apareçam no site público. A troca da imagem Docker atualiza o código; a publicação no CMS atualiza o conteúdo.

## Se precisar voltar

Se a nova versão não iniciar, consulte `docker service logs --tail 80 psychologist-app_web` no manager. A stack possui rollback automático em falha de atualização. Antes de utilizar os novos controles, também é possível voltar `APP_IMAGE` para a tag registrada em `image.txt` no backup e atualizar a stack web, com Re-pull desativado.

Depois de salvar/publicar as novas posições e cores, a versão anterior pode não reconhecê-las. Antes de voltar a imagem, reverta os botões para posições antigas e remova os novos ajustes dos rascunhos e da publicação, com orientação específica para o estado do banco. Não restaure o banco inteiro nem execute `db:rollback` apenas para trocar a imagem, pois isso pode apagar contatos e alterações recentes.

Nenhum deploy, commit ou envio ao servidor foi executado automaticamente nesta sessão.

## Validação desta revisão

- 45 testes de controllers/modelos, sem falhas: persistência, publicação, herança por dispositivo e rejeição de cores/valores inválidos.
- 38 testes de navegador, sem falhas: editor de botões, posições relativas ao carrossel, formulário, camada de cor, recorte, limites dos cards e regressões de navegação.
- Editor de botões e formulário abaixo/à direita conferidos visualmente com capturas locais.
- YAML das três stacks e `git diff --check` conferidos.

Os testes usam dados locais de teste. Não houve envio de formulário real nem modificação do servidor de produção.
