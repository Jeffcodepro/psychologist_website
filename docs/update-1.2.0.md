# Atualizar de 1.1.1 para 1.2.0

Esta versão corrige os resumos cortados, acrescenta composição de imagens e botões por dispositivo, remove `locale` das URLs do admin e adiciona modelos de SEO. **Há uma nova migração de banco**: `card_settings` nos cards. Não é necessário configurar novamente Cloudinary, DNS, master key ou senhas.

## 1. No Mac: salvar e empacotar o código

Na pasta do projeto:

```sh
git status --short
git add -- app config db/migrate db/schema.rb test deploy docs README.md
git diff --cached --check
git diff --cached --stat
git ls-files --cached -- .env config/master.key 'config/credentials/*.key'
```

O último comando deve ficar sem saída. Confira o diff antes de confirmar o commit; não inclua credenciais ou backups.

```sh
git commit -m "Melhora composicao dos cards idiomas do admin e modelos SEO"
mkdir -p tmp
git archive --format=tar.gz --output=tmp/rosemarydias-source-1.2.0.tar.gz HEAD
tar -tzf tmp/rosemarydias-source-1.2.0.tar.gz db/migrate/20261002120000_add_card_settings_to_section_items.rb app/assets/stylesheets/components/_composition.scss
shasum -a 256 tmp/rosemarydias-source-1.2.0.tar.gz
```

O pacote contém apenas o que estiver commitado. Pelo **SFTP do Termius**, envie `tmp/rosemarydias-source-1.2.0.tar.gz` para `/opt/rosemarydias/rosemarydias-source-1.2.0.tar.gz` no **banco-de-dados-manager02**. O arquivo antigo pode permanecer.

## 2. No banco-de-dados-manager02: backup e imagem

```sh
ls -lh /opt/rosemarydias/rosemarydias-source-1.2.0.tar.gz
sha256sum /opt/rosemarydias/rosemarydias-source-1.2.0.tar.gz
mkdir -p /opt/rosemarydias/releases
mkdir /opt/rosemarydias/releases/1.2.0
tar -xzf /opt/rosemarydias/rosemarydias-source-1.2.0.tar.gz -C /opt/rosemarydias/releases/1.2.0
cd /opt/rosemarydias/releases/1.2.0
bash deploy/swarm/backup-production.sh
```

Compare o hash com o do Mac. Pare as edições no CMS durante a atualização. Só prossiga após **Backup concluído**; baixe a pasta indicada pelo SFTP e guarde em local privado. O backup de storage local não inclui os arquivos que já estão no Cloudinary. Preserve o ambiente Cloudinary e os secrets atuais.

```sh
docker build -t psychologist-website:1.2.0 .
docker run --rm --entrypoint /bin/sh psychologist-website:1.2.0 -c 'test -s /rails/db/migrate/20261002120000_add_card_settings_to_section_items.rb && test -s /rails/app/models/concerns/card_presentation.rb'
```

O último comando não deve dar erro. A imagem fica nesse node; as stacks continuam fixadas nele, sem registry.

## 3. Portainer: migrar antes de atualizar o site

Abra **Stacks → psychologist-release → Editor**:

1. Use o conteúdo atualizado de [`deploy/swarm/migrate.yml`](../deploy/swarm/migrate.yml).
2. Em **Environment variables**, ajuste **APP_IMAGE=psychologist-website:1.2.0**. Uma variável antiga sobrescreve o valor padrão do YAML.
3. Preserve os secrets e redes existentes. Atualize com **Re-pull image desativado**.

No terminal do **manager02**:

```sh
docker service ps psychologist-release_migrate --no-trunc
docker service logs --tail 60 psychologist-release_migrate
```

Espere a tarefa da versão **1.2.0** ficar **Complete**, sem erro. Os logs devem mostrar `AddCardSettingsToSectionItems` concluída. `0/1` depois da conclusão é normal para essa tarefa. Se a migração falhar, não avance para a stack web.

## 4. Portainer: atualizar a aplicação

Em **Stacks → psychologist-app → Editor**, use [`deploy/swarm/application-cloudinary.yml`](../deploy/swarm/application-cloudinary.yml) se já usa Cloudinary; caso ainda use disco local, use [`application.yml`](../deploy/swarm/application.yml).

Altere **APP_IMAGE=psychologist-website:1.2.0** nas variáveis dessa stack também. Preserve `APP_HOST=rosemarydias.com`, `ACTIVE_STORAGE_SERVICE`, nome do secret Cloudinary, configurações de e-mail, redes, volumes e demais secrets. Não recrie `psychologist-db` nem importe novamente o banco local. Atualize com **Re-pull image desativado**.

O serviço usa `stop-first`, então haverá uma breve interrupção durante a troca do container.

No **manager02**:

```sh
docker service inspect psychologist-app_web --format 'Imagem: {{.Spec.TaskTemplate.ContainerSpec.Image}}'
docker service ps psychologist-app_web --no-trunc
docker service ls --filter name=psychologist-app_web
```

Confirme **1.2.0**, tarefa **Running** e **1/1** réplica. No **banco-de-dados-manager02**:

```sh
APP_CONTAINER=$(docker ps --filter label=com.docker.swarm.service.name=psychologist-app_web --filter status=running --format '{{.ID}}')
docker exec "$APP_CONTAINER" /rails/bin/docker-entrypoint bin/rails db:abort_if_pending_migrations
```

Este comando deve terminar sem erro. Para conferir a aplicação pública:

```sh
curl -I https://rosemarydias.com
curl -I https://rosemarydias.com/robots.txt
curl -I https://rosemarydias.com/sitemap.xml
```

## 5. Conferir e usar os controles

- **Editar card → Composição do card:** escolha imagem e posição/alinhamento do botão em Desktop, Tablet e Mobile. Tablet/Mobile herdam o padrão até serem personalizados.
- **Editar bloco → Aparência → dispositivo → Posição da imagem:** acima, abaixo, lados, entre título e parágrafo, antes dos botões ou fundo. Também disponíveis pelo controle “Imagem” da prévia. O banner continua sendo a camada de fundo da seção; a fotografia pode ser a camada abaixo do texto.
- Em imagens de fundo da seção, confira contraste usando as cores do título/texto e a sobreposição disponíveis no editor. Em cards com imagem de fundo, o texto fica branco sobre uma sobreposição escura.
- Salve o rascunho, confira os três dispositivos e **publique a página**. A correção dos resumos e URLs vale imediatamente; novas escolhas de composição só chegam ao público após publicar.
- Abra um endereço antigo com `?locale=en`: deve limpar a URL e manter inglês. Navegue entre as páginas da prévia e confirme o idioma.
- **Configurações → SEO** e **Configurar página → SEO:** os botões “Usar modelo” preenchem os campos apenas quando clicados. Revise o conteúdo antes de salvar.

Para a etapa no Google, siga [SEO e indexação](seo-and-indexing.md).

## Se precisar voltar

No Portainer, restaure **APP_IMAGE=psychologist-website:1.1.1** na stack web e atualize com Re-pull desativado. A coluna nova é aditiva e pode permanecer no banco. Não execute `db:rollback`, seeds ou restauração sobre produção apenas para voltar o código. Mantenha a imagem 1.1.1 até validar a nova versão. Os layouts novos só são suportados na 1.2.0; conclua a validação antes de começar a publicar essas novas opções.

## Validação local desta versão

- 100 testes de controllers e modelos passaram (930 verificações).
- 21 cenários distintos de navegador passaram: cards/carrossel, composição, crop, exclusão, idiomas e modelos SEO, em execuções da suíte e dos cenários alterados. A última verificação das alterações visuais passou com 15 testes e 163 verificações.
- Revisão visual em 390, 820 e 1400 px, incluindo resumos completos e sobreposição de camadas. As imagens das capturas de teste são fixtures sintéticas.
- Brakeman: zero alertas e zero erros. Sintaxe dos arquivos de stack, script de backup, Ruby e JavaScript conferida.

A imagem Docker 1.2.0 ainda precisa ser construída no servidor e as etapas de migração/deploy acima precisam ser executadas. Nenhuma alteração foi aplicada a produção por esta revisão.
