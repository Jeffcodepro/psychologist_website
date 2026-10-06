# Atualização 1.2.1

Inclui correção do carrossel público, indicadores de paginação, quatro modelos de SEO em português/inglês, favicon automático da logo, seletores compactos, posição do formulário e espaçamentos por dispositivo. Também inclui as melhorias de cards, imagens e URLs da versão 1.2.0 caso você ainda esteja na 1.1.1.

**Há uma nova migração**: `layout_settings` em `sections`. Rode a stack de migração antes da aplicação. As migrações anteriores pendentes também serão executadas. Nenhuma nova senha, chave, rede ou serviço é necessário.

## 1. No Mac

Na pasta do projeto, revise e salve as alterações antes de criar o pacote:

```sh
git status --short
git add -- app config db/migrate db/schema.rb test deploy docs README.md
git diff --cached --check
git diff --cached --stat
git ls-files --cached -- .env config/master.key 'config/credentials/*.key'
```

O último comando deve ficar sem saída. Confira o diff; não adicione credenciais, backups ou exportações.

```sh
git commit -m "Corrige carrossel publico e melhora editor formulario SEO e favicon"
mkdir -p tmp
git archive --format=tar.gz --output=tmp/rosemarydias-source-1.2.1.tar.gz HEAD
tar -tzf tmp/rosemarydias-source-1.2.1.tar.gz db/migrate/20261002140000_add_layout_settings_to_sections.rb app/controllers/favicons_controller.rb
shasum -a 256 tmp/rosemarydias-source-1.2.1.tar.gz
```

Pelo **SFTP do Termius**, envie esse arquivo para `/opt/rosemarydias/rosemarydias-source-1.2.1.tar.gz` no servidor **banco-de-dados-manager02**.

## 2. No terminal de banco-de-dados-manager02

```sh
ls -lh /opt/rosemarydias/rosemarydias-source-1.2.1.tar.gz
sha256sum /opt/rosemarydias/rosemarydias-source-1.2.1.tar.gz
mkdir /opt/rosemarydias/releases/1.2.1
tar -xzf /opt/rosemarydias/rosemarydias-source-1.2.1.tar.gz -C /opt/rosemarydias/releases/1.2.1
cd /opt/rosemarydias/releases/1.2.1
bash deploy/swarm/backup-production.sh
```

Compare os hashes. Só prossiga com “Backup concluído”; baixe a pasta indicada e guarde-a fora do servidor. Pause as edições no CMS durante a atualização. O backup de storage local não contém imagens que já estão no Cloudinary; preserve também esse ambiente.

```sh
docker build -t psychologist-website:1.2.1 .
docker run --rm --entrypoint /bin/sh psychologist-website:1.2.1 -c 'test -s /rails/db/migrate/20261002140000_add_layout_settings_to_sections.rb && test -s /rails/app/controllers/favicons_controller.rb'
```

O último comando deve terminar sem erro. A imagem está nesse node; as stacks continuam fixadas nele.

## 3. No Portainer: primeiro a migração

Em **Stacks → psychologist-release**, use [`deploy/swarm/migrate.yml`](../deploy/swarm/migrate.yml).

- Em **Environment variables**, defina `APP_IMAGE=psychologist-website:1.2.1`.
- Preserve os secrets e redes existentes.
- Atualize com **Re-pull image desativado**.

No terminal do **manager02**:

```sh
docker service ps psychologist-release_migrate --no-trunc
docker service logs --tail 60 psychologist-release_migrate
```

Espere a tarefa da imagem **1.2.1** ficar **Complete**, sem erro. Os logs devem mostrar `AddLayoutSettingsToSections` concluída. `0/1` após terminar é normal nessa stack temporária. Se falhar, pare aqui.

## 4. No Portainer: depois a aplicação

Em **Stacks → psychologist-app**, use [`application-cloudinary.yml`](../deploy/swarm/application-cloudinary.yml) se já usa Cloudinary; para disco local use [`application.yml`](../deploy/swarm/application.yml).

Defina `APP_IMAGE=psychologist-website:1.2.1` nas variáveis **dessa stack também**. Uma variável antiga sobrescreve a tag padrão do arquivo. Preserve `APP_HOST=rosemarydias.com`, storage, e-mail, secrets, redes e volumes. Atualize com **Re-pull image desativado**.

Não recrie o banco nem rode seeds/importação. A troca usa `stop-first`, com uma breve interrupção.

No **manager02**:

```sh
docker service inspect psychologist-app_web --format 'Imagem: {{.Spec.TaskTemplate.ContainerSpec.Image}}'
docker service ps psychologist-app_web --no-trunc
docker service ls --filter name=psychologist-app_web
```

Confirme imagem **1.2.1**, tarefa **Running** e **1/1** réplica.

No **banco-de-dados-manager02**:

```sh
APP_CONTAINER=$(docker ps --filter label=com.docker.swarm.service.name=psychologist-app_web --filter status=running --format '{{.ID}}')
docker exec "$APP_CONTAINER" /rails/bin/docker-entrypoint bin/rails db:abort_if_pending_migrations
curl -I https://rosemarydias.com
curl -I https://rosemarydias.com/favicon.png
```

Com a logo cadastrada, o favicon responde `200` e `Content-Type: image/png`. Se não houver logo, a resposta é `404` até cadastrá-la. Reinicie também seu `bin/rails server` local para carregar as alterações do Simple Form.

## 5. Onde usar os controles

- **Carrossel:** respeita a quantidade de colunas configurada em cada tela. Os pontos abaixo alternam as páginas. Quando todos os cards cabem, não há paginação nem avanço automático. As setas continuam nas laterais; a pausa fica em um pequeno ícone no canto superior direito.
- **Editar bloco → Aparência → Desktop/Tablet/Mobile:** ajuste os espaçamentos em pixels. Tablet e mobile herdam a base até serem personalizados; limpe um campo de override para voltar ao padrão.
- **Bloco de contato → Aparência → Formulário:** escolha acima/abaixo/esquerda/direita, largura e alinhamento. No mobile, lados herdados do desktop ficam empilhados; uma escolha explícita no mobile é respeitada. Na prévia, o controle “Formulário” também permite mover.
- **Fonte:** escolha pelo seletor; a amostra é atualizada sem expandir o painel.
- **SEO da página e do site:** escolha um dos quatro modelos e clique em “Aplicar modelo”, ou aplique apenas título/descrição. Os textos continuam editáveis. Confira se o conteúdo representa o trabalho da cliente antes de salvar.
- **Favicon:** usa automaticamente a logo em Configurações. A imagem é enquadrada em um quadrado, preservando a proporção. O navegador pode demorar para atualizar um favicon já armazenado; confira em uma nova aba.

Salve os blocos e **publique a página** para os novos ajustes aparecerem no site público. Valide em uma janela sem login e em mobile. As correções do carrossel e do favicon são aplicadas ao instalar a versão.

O Google decide quando rastrear novamente e como exibir título, descrição e favicon; modelos não garantem posição no ranking. Para Search Console e sitemap, veja [SEO e indexação](seo-and-indexing.md). Requisitos oficiais de favicon: https://developers.google.com/search/docs/appearance/favicon-in-search.

## Se precisar voltar

Use a tag anterior registrada em `image.txt` no backup como `APP_IMAGE` na stack web, com Re-pull desativado. Mantenha a imagem antiga até validar. A migração é aditiva: não apague a coluna nem execute `db:rollback`, seeds ou restauração por causa de uma troca de imagem. O código antigo não oferece os controles novos.

Nenhuma alteração de produção é executada por este guia automaticamente.

## Validação local

- Controllers e modelos: 106 testes, 979 verificações, sem falhas.
- Navegador: 15 testes, 172 verificações, sem falhas; carrossel público, paginação, autoplay, teclado, movimento do formulário, fontes, SEO e regressões de composição de imagens/cards.
- Favicon: PNG quadrado, cache condicional, troca da logo, sessão administrativa e isolamento por site.
- Brakeman: zero alertas e zero erros. Stacks YAML e diff conferidos.
- Migração aplicada ao banco local. Produção ainda depende das etapas acima.
