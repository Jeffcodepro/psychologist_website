# Atualizar para 1.1.1: publicação, SEO e Cloudinary

Esta atualização não acrescenta migrações de banco. O roteiro preserva o banco e os uploads existentes. O container web será substituído no deploy e novamente na ativação do Cloudinary (`stop-first`), causando uma breve interrupção em cada etapa. Publicar conteúdo depois disso não exige reconstruir a imagem Docker nem reiniciar a stack.

## O que muda

- O Traefik atende `rosemarydias.com` e `www.rosemarydias.com`, com HTTPS para ambos. A aplicação redireciona `www` para o endereço principal.
- A leitura pública mantém a mesma versão dos blocos, cards e imagens durante toda a resposta, mesmo com uma publicação concorrente. Publicar deixa de reenfileirar a geração de versões das mesmas imagens. O processamento local em segundo plano fica limitado a uma tarefa por vez.
- Sitemap por cliente, `robots.txt`, canonical, Open Graph e dados estruturados de site/autora/artigos. Os campos de SEO existentes do CMS alimentam os metadados. Rascunhos e páginas de outros clientes ficam fora do sitemap.
- Português e inglês usam o mesmo endereço, sem `?locale=`. A escolha fica em um cookie do navegador por um ano. Links antigos com esse parâmetro salvam a preferência e redirecionam ao endereço limpo. O sitemap e o canonical têm uma URL por página. Visitantes sem preferência recebem português; o inglês não possui uma URL separada para indexação. Esse comportamento também é descrito na [documentação do Google sobre sites multilíngues](https://developers.google.com/search/docs/specialty/international/managing-multi-regional-sites).
- O Cloudinary armazena os originais e entrega versões adaptadas à tela pela CDN. O recorte, zoom, posição e filtros continuam definidos no CMS. Imagens locais continuam funcionando durante a transição.

As otimizações de consultas (99 → 17 no cenário medido), a separação de acesso por domínio e a recuperação de senha por cliente também estão incluídas. Veja o [relatório de testes](performance-security-2026-10-01.md).

## 1. Cloudinary

No console Cloudinary, selecione o **Product Environment** que será usado em produção. Anote seu **Cloud name**. Abra **Settings → API Keys** (ou a página API Keys do ambiente) e copie a variável de conexão, no formato:

```text
cloudinary://API_KEY:API_SECRET@CLOUD_NAME
```

Teste real local em 01/10/2026: autenticação, upload pelo Active Storage, download do original com checksum idêntico, entrega otimizada em WebP (HTTP 200) e exclusão do arquivo temporário passaram. Antes de liberar a permissão `create`, a autenticação já passava, mas o upload falhava. Portanto, `media:check_cloudinary` sozinho não comprova permissão de envio.

Use o valor real somente no `.env` e no Docker Secret. Não coloque credenciais no YAML, Git, conversa ou comando de terminal. Para esta integração, não é necessário criar um preset de upload público/unsigned: os uploads são autenticados pelo servidor e continuam passando pelas validações do CMS. Não configure transformações que alterem o original no preset padrão desse ambiente; a migração compara o checksum dos originais.

## 2. Desenvolvimento local

No Mac, dentro do projeto:

```sh
bundle install
bin/rails server
```

Por padrão o desenvolvimento continua usando `ACTIVE_STORAGE_SERVICE=local`. Para testar Cloudinary localmente, use **outro Product Environment**, separado de produção, e configure no `.env`:

```dotenv
ACTIVE_STORAGE_SERVICE=cloudinary
CLOUDINARY_URL=cloudinary://API_KEY:API_SECRET@CLOUD_NAME_DE_TESTES
```

Substitua os marcadores e reinicie Rails. Confirme a conexão com `bin/rails media:check_cloudinary` e o ciclo completo com `bin/rails runner script/cloudinary_smoke.rb`. O segundo comando cria e remove uma imagem sintética; não salva registros no banco nem edita páginas. A tarefa `media:check_cloudinary` não envia imagens nem imprime a credencial. `bin/rails media:migrate_to_cloudinary` migra as imagens desse banco local; é opcional. Como o banco de produção foi clonado do local, usar a mesma conta/ambiente Cloudinary nas duas cópias pode fazer uma exclusão local afetar o arquivo usado em produção. Mantenha desenvolvimento local ou use ambientes Cloudinary separados.

## 3. Preparar o código no Mac

Esta é uma atualização de código, não uma nova instalação. Não execute novamente `bin/export_deploy`, seeds ou importação do banco local sobre produção. O conteúdo atual, as contas, mensagens e imagens do servidor devem ser preservados.

Na pasta do projeto, salve os arquivos atualizados em um commit; `git archive` só inclui arquivos commitados:

```sh
git status --short
git add -A -- app config lib script test deploy docs public Gemfile Gemfile.lock README.md bin/docker-entrypoint .env.example
git diff --cached --check
git diff --cached --stat
git ls-files --cached -- .env config/master.key 'config/credentials/*.key'
```

O último comando deve ficar sem saída. Não prossiga se ele listar algum arquivo privado. O `.env.example` deve conter apenas modelos de configuração. Confira o resumo e finalize:

```sh
git commit -m "Atualiza Cloudinary SEO idiomas desempenho e isolamento de sites"
mkdir -p tmp
git archive --format=tar.gz --output=tmp/rosemarydias-source-1.1.1.tar.gz HEAD
tar -tzf tmp/rosemarydias-source-1.1.1.tar.gz script/cloudinary_smoke.rb app/services/public_content_loader.rb app/controllers/language_preferences_controller.rb deploy/swarm/application-cloudinary.yml deploy/swarm/backup-production.sh
shasum -a 256 tmp/rosemarydias-source-1.1.1.tar.gz
```

Os cinco arquivos devem ser listados. Se essa tag já foi usada com outro código, escolha outra também no nome do pacote, diretório, build e `APP_IMAGE`. Pelo SFTP do Termius, envie:

- Mac: `psychologist_website/tmp/rosemarydias-source-1.1.1.tar.gz`.
- **banco-de-dados-manager02**: `/opt/rosemarydias/rosemarydias-source-1.1.1.tar.gz`.

O arquivo antigo pode permanecer; esta atualização usa um nome novo. Não envie `.env` nem `master.key` junto com o código.

## 4. Backup e build no banco-de-dados-manager02

No Termius, conecte ao **banco-de-dados-manager02**, onde rodam web e PostgreSQL. Confira o hash contra o resultado do Mac e extraia em um diretório novo:

```sh
sha256sum /opt/rosemarydias/rosemarydias-source-1.1.1.tar.gz
mkdir -p /opt/rosemarydias/releases
mkdir /opt/rosemarydias/releases/1.1.1
tar -xzf /opt/rosemarydias/rosemarydias-source-1.1.1.tar.gz -C /opt/rosemarydias/releases/1.1.1
cd /opt/rosemarydias/releases/1.1.1
```

Se o diretório já existir, confira a versão antes de continuar; não extraia sobre código antigo. Deixe o CMS sem edições durante o backup e a migração das imagens. Faça backup antes de atualizar o serviço:

```sh
bash deploy/swarm/backup-production.sh
```

O script detecta os dois containers locais, usa `pg_dump` do próprio PostgreSQL 17, copia o volume local de imagens e confere a leitura dos arquivos. Salva também a tag e o ID da imagem atual. Só prossiga se imprimir **Backup concluído**. Ele não para containers nem restaura dados. Baixe a pasta privada informada pelo SFTP e guarde fora do servidor. Assets que já estejam no Cloudinary não fazem parte do backup de disco. Preserve também os secrets existentes e uma cópia do YAML/variáveis atuais do Portainer. A sintaxe do script foi verificada localmente; o backup real só acontece quando você o executar no servidor.

Construa a imagem nesse mesmo node:

```sh
docker build -t psychologist-website:1.1.1 .
docker run --rm --entrypoint /bin/sh psychologist-website:1.1.1 -c 'test -s /rails/script/cloudinary_smoke.rb && test -s /rails/app/services/public_content_loader.rb && test -s /rails/lib/tasks/media.rake && test ! -e /rails/public/robots.txt'
```

O último comando verifica o conteúdo da imagem sem carregar secrets ou conectar ao banco. Nenhum registry é necessário para este fluxo, pois a stack permanece presa ao node onde você construiu a imagem. Não aumente réplicas/distribua para outros nodes sem distribuir também a imagem e preparar o armazenamento e rate limit compartilhados.

## 5. Secret e stack no Portainer: primeiro o código

Em **Secrets → Add secret**, crie:

```text
Name: psychologist_cloudinary_url_v1
Secret: o valor cloudinary://... completo do ambiente de produção
```

Cole somente o valor, sem `CLOUDINARY_URL=`, aspas ou formatação Markdown. Se esse secret já existir com a credencial correta, reutilize-o. Secrets não são editados no lugar: para trocar o valor, crie `psychologist_cloudinary_url_v2` e use esse nome em `CLOUDINARY_SECRET_NAME`. Não altere a master key, senha do banco ou os demais secrets desta atualização.

Abra **Stacks → psychologist-app → Editor** e use o YAML completo de [`deploy/swarm/application-cloudinary.yml`](../deploy/swarm/application-cloudinary.yml). Preserve personalizações de SMTP, destinatário e outros domínios/routers. Na área de variáveis do Portainer, defina nesta primeira etapa:

```dotenv
APP_IMAGE=psychologist-website:1.1.1
APP_HOST=rosemarydias.com
ACTIVE_STORAGE_SERVICE=local
CLOUDINARY_SECRET_NAME=psychologist_cloudinary_url_v1
TRAEFIK_PUBLIC_NETWORK=network_swarm_public
TRAEFIK_CERTRESOLVER=letsencryptresolver
TRAEFIK_HTTP_ENTRYPOINT=web
TRAEFIK_HTTPS_ENTRYPOINT=websecure
```

É intencional manter `local` agora: o código novo já sabe ler os dois serviços, e a credencial fica montada para testar antes de mudar os uploads. A variável é obrigatória nesta etapa, pois o YAML Cloudinary assume `cloudinary` quando ela está ausente.

Atualize a stack com **Re-pull image desativado**. Ela usa o mesmo banco, volumes, redes e master key. Não atualize nem recrie `psychologist-db`; não rode importação ou seeds. Não há novas migrações de esquema neste conjunto de alterações. Caso seu servidor esteja em uma versão ainda anterior, confira `db:abort_if_pending_migrations` após subir o código e trate as migrações pendentes antes de continuar.

No **manager02**, confirme imagem `1.1.1`, `1/1` réplicas e tarefa `Running`:

```sh
docker service ls --filter name=psychologist-app_web
docker service ps psychologist-app_web --no-trunc
```

## 6. DNS e HTTPS

No Cloudflare, mantenha:

| Tipo | Nome | Destino |
| --- | --- | --- |
| A | @ | 178.105.117.125 |
| CNAME | www | rosemarydias.com |

O DNS com `www` já apontava ao servidor na verificação de 01/10/2026; o erro observado era no certificado HTTPS. As novas regras do Traefik incluem os dois nomes para emissão do certificado. Não use o modo SSL Flexible. Se ativar o proxy Cloudflare, use Full (strict) depois que o certificado da origem estiver válido. Mantenha portas 80 e 443 disponíveis ao Traefik e sem regra que bloqueie o desafio ACME. A aplicação já envia cabeçalhos para não compartilhar cache de HTML/admin entre visitantes; não aplique uma regra Cache Everything que ignore esses cabeçalhos.

Depois da atualização:

```sh
curl -I https://rosemarydias.com
curl -I https://www.rosemarydias.com
```

Esperado: `200` no domínio principal; `301` com `Location: https://rosemarydias.com/` no `www`, sem erro de certificado. Se o certificado continuar falhando, consulte os logs do Traefik no manager (`docker service logs --since 10m --tail 100 traefik_traefik`) para conferir o desafio do certresolver; não desative a verificação TLS.

## 7. Testar no servidor, migrar e ativar Cloudinary

No **banco-de-dados-manager02**, após o container novo estar saudável:

```sh
APP_CONTAINER=$(docker ps --filter label=com.docker.swarm.service.name=psychologist-app_web --filter status=running --format '{{.ID}}')
docker exec "$APP_CONTAINER" /rails/bin/docker-entrypoint bin/rails db:abort_if_pending_migrations
docker exec "$APP_CONTAINER" /rails/bin/docker-entrypoint bin/rails media:check_cloudinary
docker exec "$APP_CONTAINER" /rails/bin/docker-entrypoint bin/rails runner script/cloudinary_smoke.rb
```

O teste completo precisa mostrar `upload: ok`, HTTP 200 para original e versão otimizada, `checksum_matches: true`, `cleanup: ok` e `removed_from_storage: true`. Se aparecer `missing permissions ... create`, confira as permissões da chave/ambiente; não migre nem ative novos uploads até resolver. Se a limpeza falhar, o identificador do arquivo de teste é salvo em `/rails/tmp/cloudinary-smoke-cleanup.txt` para removê-lo depois no Cloudinary.

Com o teste completo aprovado, mantenha o CMS sem alterações, confira a quantidade, simule e migre:

```sh
docker exec "$APP_CONTAINER" /rails/bin/docker-entrypoint bin/rails media:status
docker exec -e DRY_RUN=1 "$APP_CONTAINER" /rails/bin/docker-entrypoint bin/rails media:migrate_to_cloudinary
docker exec "$APP_CONTAINER" /rails/bin/docker-entrypoint bin/rails media:migrate_to_cloudinary
docker exec "$APP_CONTAINER" /rails/bin/docker-entrypoint bin/rails media:status
```

Cada original é copiado e verificado por checksum antes de receber `service_name=cloudinary`. IDs e vínculos permanecem. Arquivos locais ficam preservados. Se houver falha, aquele arquivo continua local; as cópias verificadas não são repetidas ao executar novamente. Não remova o volume `psychologist_storage`. A tarefa percorre imagens de todos os sites desse banco.

Quando terminar sem falhas, no Portainer altere apenas:

```dotenv
ACTIVE_STORAGE_SERVICE=cloudinary
```

Atualize novamente `psychologist-app`, mantendo a mesma imagem `1.1.1` e **Re-pull image desativado**. Após a troca, recalcule `APP_CONTAINER`, pois o ID mudou, e confirme o serviço padrão:

```sh
APP_CONTAINER=$(docker ps --filter label=com.docker.swarm.service.name=psychologist-app_web --filter status=running --format '{{.ID}}')
docker exec "$APP_CONTAINER" /rails/bin/docker-entrypoint bin/rails runner 'puts Rails.application.config.active_storage.service'
```

Esperado: `cloudinary`. A partir daí, novos uploads vão para o Cloudinary. Confira no navegador logo, fotos, recorte/zoom, cartões e a aba Network: as imagens migradas devem vir de `res.cloudinary.com`. `media:prepare` continua disponível para arquivos locais e ignora os remotos.

## 8. Conferir o site e alterar conteúdo

Em uma janela anônima, confira a página inicial, artigos, formulário, português/inglês sem `?locale=` e imagens no mobile. No link privado, teste a edição de um rascunho, a prévia e a publicação; confirme o resultado na janela anônima. O navegador logado no CMS permanece no painel por regra da aplicação.

Para trocar fotos, textos e blocos depois do deploy, use o CMS e clique em **Aprovar e publicar**. Essas mudanças de conteúdo não precisam de novo build. Alterações de código precisam de um novo pacote/imagem; alterar `.env` no Mac não altera o servidor. Não reimporte o banco local para transportar mudanças de conteúdo sobre o banco vivo de produção.

## 9. Google Search Console

Depois que o site estiver acessível, entre no [Google Search Console](https://search.google.com/search-console), adicione a propriedade de domínio `rosemarydias.com` e copie o registro TXT de verificação para o DNS Cloudflare. Após verificar:

1. Abra `https://rosemarydias.com/robots.txt` e `https://rosemarydias.com/sitemap.xml`; ambos devem responder normalmente.
2. Em **Sitemaps**, envie `https://rosemarydias.com/sitemap.xml`.
3. Em **Inspeção de URL**, inspecione `https://rosemarydias.com/`, faça o teste ao vivo e solicite indexação. Repita para as páginas principais e artigos.
4. No CMS, mantenha títulos e descrições de SEO específicos de cada página, nome da profissional e textos reais. Publique os rascunhos que devem aparecer nas buscas.

Aparecer nos resultados depende do rastreamento e da avaliação do Google; não é instantâneo nem garantido pelo sitemap. O sitemap se atualiza quando as páginas são publicadas, sem reenviar manualmente a cada edição.

## Recuperação e diagnóstico

Para voltar ao disco usando esta versão, execute `bin/rails media:restore_local` com o entrypoint no container ainda configurado com o secret Cloudinary. Ele copia de volta também os novos uploads e verifica os arquivos. Quando terminar com zero falhas, configure `ACTIVE_STORAGE_SERVICE=local`, mantendo o código `1.1.1` e recalculando o ID do container após a atualização da stack. Não volte para uma imagem anterior sem suporte Cloudinary enquanto houver imagens referenciando esse serviço. Os arquivos remotos são preservados.

Se o acesso cair ao publicar mesmo após esta atualização, no manager confira `docker service ps psychologist-app_web --no-trunc` e `docker service logs --since 10m --tail 100 psychologist-app_web`. Registre o horário e o erro HTTP (404/500/502/503). Isso diferencia reinício/falta de memória de erro Rails ou roteamento; o teste público inicial confirmou `200` sem `www`, mas não reproduziu a interrupção no servidor durante sua publicação.

Referências: [Docker Secrets](https://docs.docker.com/engine/swarm/secrets/), [edição de stacks no Portainer](https://docs.portainer.io/user/docker/stacks/edit), [pg_dump](https://www.postgresql.org/docs/17/app-pgdump.html), [Cloudinary e Active Storage](https://cloudinary.com/documentation/rails_activestorage), [Google: criar/enviar sitemap](https://developers.google.com/search/docs/crawling-indexing/sitemaps/build-sitemap), [Google: solicitar novo rastreamento](https://developers.google.com/search/docs/crawling-indexing/ask-google-to-recrawl).
