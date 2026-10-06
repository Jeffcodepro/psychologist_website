# Atualização para 1.2.5 — validações, seletores e espaçamentos

Esta versão reúne as alterações locais anteriores e acrescenta país/bandeira no telefone, validação de números internacionais, nome e sobrenome e formato de e-mail, no navegador e no servidor. Os seletores passam a ter busca e rolagem interna no site e no CMS, sem expandir os painéis de fonte. Contatos antigos continuam acessíveis. Inclui também espaçamentos independentes nas seções e dentro dos cards, com ajustes por dispositivo.

Não há nova migração específica destas validações. Execute as migrações pendentes das revisões anteriores, incluindo o índice `20261002180000_index_contact_submission_limits.rb`, antes de atualizar a web. Nenhum secret novo é necessário; não altere a conta de e-mail que já foi corrigida.

## Primeiro: atualizar o localhost no Mac

1. No terminal em que o Rails está rodando, use `Ctrl+C` para parar o servidor.
2. Em outro terminal, na pasta real do projeto, execute:

```sh
cd /Users/jeffersondossantos/code/Jeffcodepro/psychologist_website
bundle install
bin/rails db:migrate
bin/rails server
```

3. Acesse `http://localhost:3000/contato` sem estar conectado ao painel. Para testar o CMS, use seu acesso privado local em outro perfil do navegador.
4. Confira Brasil (+55), pesquise Portugal ou outro país, informe um número válido e tente também dados incompletos. Um nome só, telefone incompatível com o país ou e-mail sem domínio completo devem ser recusados.
5. Nos campos personalizados do editor, use **Nome e sobrenome**, **Telefone** e **E-mail** como tipos de campo. O campo padrão `full_name` já recebe a validação sem precisar editar ou republicar a página.

As bibliotecas de navegador estão dentro do projeto; não precisa instalar Node/npm nem usar um CDN. `bundle install` instala a nova gem `phonelib`. Reiniciar o Rails é necessário para carregar a dependência.

A validação confere formato e numeração; ela não confirma que a pessoa é dona do número/caixa de e-mail. As regras de reenvio de dez minutos continuam valendo. Evite enviar testes repetidos para a cliente pelo localhost se seu `.env` usa SMTP real; os testes automatizados usam dados fictícios e não enviam e-mail externo.

Para executar os testes de validação, com PostgreSQL local disponível:

```sh
PARALLEL_WORKERS=1 bin/rails test test/models/contact_identity_test.rb test/controllers/contact_validation_test.rb test/controllers/contact_submission_protection_test.rb
PARALLEL_WORKERS=1 bin/rails test test/system/contact_validation_test.rb test/system/contact_submission_test.rb
```

## Como usar os novos espaçamentos

No editor de bloco ou no painel de edição da prévia, abra **Aparência → Desktop / Tablet / Mobile → Espaçamentos**. Use o controle deslizante ou digite o número de pixels:

- **Entre título e texto**: distância entre os dois textos, respeitando a ordem escolhida.
- **Entre imagem e conteúdo**: separação da imagem lateral, acima/abaixo ou inserida entre os textos.
- **Entre botões e conteúdo**: também funciona quando os botões ficam acima ou abaixo do carrossel.
- **Entre cards / carrossel e conteúdo** e **Entre cards**: controles separados para a coleção e seus itens.
- **Entre formulário e conteúdo**: funciona com formulário ao lado, acima ou abaixo.
- **Entre parágrafos**: controla a distância entre parágrafos; a entrelinha continua em Tipografia. No texto, separe parágrafos com uma linha em branco.
- **Respiro acima, abaixo e nas laterais**: espaço interno da seção.

Os padrões gerais continuam disponíveis para preservar as páginas existentes. Os novos controles específicos herdam esses valores quando ficam vazios. `0` é um valor válido, diferente de deixar vazio. Tablet e mobile herdam o desktop quando não têm ajuste próprio.

Dentro de **Editar card → Composição do card → Desktop / Tablet / Mobile**, use **Espaçamentos do card**. Há controles de respiro lateral, título/texto, imagem/conteúdo e botão, com prévia imediata. Limites de 0–40 px ajudam a manter o espaço útil: a caixa continua com até 360 px de largura e 440 px de altura. Muito espaçamento deixa menos espaço para a prévia do texto; o conteúdo completo continua acessível pelo link/leitura do card.

Salve o rascunho, confira a prévia e use **Aprovar e publicar** para refletir os ajustes de conteúdo no site. Para disponibilizar estes novos controles, basta atualizar o código; não precisa alterar banco manualmente nem criar secrets.

## Depois: atualizar VPS/Portainer

## 1. No Mac: salvar e empacotar

Na pasta do projeto:

```sh
cd /Users/jeffersondossantos/code/Jeffcodepro/psychologist_website
git status --short
git add -- Gemfile Gemfile.lock app config db/migrate db/schema.rb test deploy docs vendor README.md
git diff --cached --check
git diff --cached --stat
git ls-files --cached -- .env config/master.key 'config/credentials/*.key'
```

O último comando deve ficar sem saída. Revise as mudanças antes do commit; nunca inclua chaves, `.env` ou links privados.

```sh
git commit -m "Valida formularios e amplia controles de espaco do CMS"
mkdir -p tmp
git archive --format=tar.gz --output=tmp/rosemarydias-source-1.2.5.tar.gz HEAD
tar -tzf tmp/rosemarydias-source-1.2.5.tar.gz app/models/contact_identity.rb config/phone_countries.json vendor/javascript/libphonenumber.js vendor/javascript/tom-select.js app/services/contact_submission_guard.rb app/helpers/section_spacing_helper.rb
shasum -a 256 tmp/rosemarydias-source-1.2.5.tar.gz
```

O pacote usa somente o conteúdo commitado. Se não houver alterações para commitar, confirme que os arquivos acima já estão em HEAD. Não exporte/importe novamente os dados: mantenha o banco atual de produção.

## 2. Pelo SFTP do Termius

Envie `tmp/rosemarydias-source-1.2.5.tar.gz` do Mac para `/opt/rosemarydias/rosemarydias-source-1.2.5.tar.gz` no **banco-de-dados-manager02**.

## 3. No banco-de-dados-manager02: backup e imagem

```sh
ls -lh /opt/rosemarydias/rosemarydias-source-1.2.5.tar.gz
sha256sum /opt/rosemarydias/rosemarydias-source-1.2.5.tar.gz
mkdir -p /opt/rosemarydias/releases
mkdir /opt/rosemarydias/releases/1.2.5
tar -xzf /opt/rosemarydias/rosemarydias-source-1.2.5.tar.gz -C /opt/rosemarydias/releases/1.2.5
cd /opt/rosemarydias/releases/1.2.5
bash deploy/swarm/backup-production.sh
```

Compare o hash com o Mac. Prossiga depois de “Backup concluído” e guarde o backup pelo SFTP fora do servidor. Se a pasta de release já existir, confira seu conteúdo antes de reutilizá-la.

```sh
docker build -t psychologist-website:1.2.5 .
docker image inspect psychologist-website:1.2.5 --format 'Imagem disponível: {{.Id}}'
```

A imagem é local nesse node; preserve a constraint `node.hostname == banco-de-dados-manager02`.

## 4. Portainer: migração primeiro

Na stack **psychologist-release**, preserve a configuração existente e defina a variável:

```text
APP_IMAGE=psychologist-website:1.2.5
```

Se o campo `image:` for fixo, atualize-o para a mesma imagem. Atualize com **Re-pull image desativado**.

No **manager02**:

```sh
docker service ps psychologist-release_migrate --no-trunc
docker service logs --tail 60 psychologist-release_migrate
```

Espere a tarefa da imagem 1.2.5 terminar como **Complete**, sem erro. `0/1` depois de concluir a migração é esperado. Não atualize a web se a migração falhar.

## 5. Portainer: aplicação

Na stack **psychologist-app**, altere `APP_IMAGE` para `psychologist-website:1.2.5` e atualize com **Re-pull image desativado**. Se houver `image:` fixo, altere esse campo.

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

1. Confira o seletor de país e tente um nome só, um telefone curto e um e-mail inválido. Esses envios devem ser recusados. Teste também o scroll e a busca dos seletores no celular e no painel.
2. Envie uma única mensagem válida identificada como teste e confira o recebimento no painel/e-mail. O telefone deve chegar com o código internacional, por exemplo `+55...`.
3. Recarregue o contato e abra outra aba: a confirmação deve permanecer e o formulário deve ficar oculto por dez minutos.
4. Após dez minutos, recarregue: o formulário volta a ficar disponível. O limite de cinco contatos/hora por IP continua valendo.
5. Não faça rajadas de requisições em produção: os cenários de abuso e concorrência são exercitados nos testes locais.

A proteção entra em vigor ao atualizar o código; não precisa republicar as páginas no CMS. Configuração Cloudflare/Redis segue o [guia específico](contact-protection.md).

## Se precisar voltar

Volte a imagem da stack web para a versão registrada em `image.txt` no backup, preservando todos os secrets atuais. O novo índice pode permanecer no banco; não execute `db:rollback` ou restaure um backup inteiro para remover esta proteção. Se também estiver subindo os ajustes das versões 1.2.0–1.2.3, considere a compatibilidade das opções visuais salvas antes de voltar a uma imagem antiga.

Se salvar os novos espaçamentos nos cards, uma imagem antiga pode não reconhecer essas opções durante a edição. Prefira corrigir com uma nova versão; confira a compatibilidade das configurações antes de retornar.

Se você criar campos do novo tipo **Nome e sobrenome**, versões antigas não reconhecerão esse tipo. Antes de voltar para uma imagem antiga, altere esses campos para **Texto curto** no editor e publique, ou use uma versão que já reconheça o novo tipo.

Nenhum commit ou deploy foi executado automaticamente nesta revisão.

## Dependências incorporadas

- `phonelib` 0.10.27: validação no servidor.
- `libphonenumber-js` 1.13.14, metadados completos: validação no navegador.
- Tom Select 2.6.2: listas de seleção.

Os arquivos JavaScript/CSS e as licenças ficam versionados em `vendor/javascript`, `vendor/licenses` e `app/assets/stylesheets/vendor`. O CSS usa `Max()` para compatibilidade com o SassC atual. Mantenha essas bibliotecas e os metadados telefônicos atualizados em futuras revisões.

Fontes: [Phonelib](https://github.com/daddyz/phonelib), [libphonenumber-js](https://github.com/catamphetamine/libphonenumber-js), [Tom Select](https://tom-select.js.org/docs/).

## Verificações realizadas

- 51 testes de servidor: validações, inglês, parâmetros malformados, recebimento, e-mail em modo teste, contatos antigos, limites de envio, concorrência e isolamento de sites.
- 28 testes de navegador: país/bandeira, busca, teclado, rolagem interna em 390 px e desktop, envio Turbo, recarga e regressões dos editores de cards, botões, fontes e campos personalizados.
- Nenhuma falha nos testes acima. Os casos alterados no ajuste final foram executados novamente e passaram.
- Brakeman: zero alertas e zero erros. Auditoria das gems com base atualizada: nenhuma vulnerabilidade conhecida encontrada. Isso não equivale a uma garantia geral de segurança.
- `zeitwerk:check`, sintaxe Ruby/JavaScript, YAML das stacks e `git diff --check` passaram.
- Não foram enviados e-mails externos nem feitas alterações na VPS durante estes testes.

### Complemento: espaçamentos (05/10/2026)

- Verificação final: **46 testes, 702 verificações, zero falhas e zero erros**. Inclui valores por dispositivo, zero pixels, textos em ordem invertida, imagem entre título e parágrafo, botões antes/depois do carrossel, prévia, publicação e herança dos valores do card.
- Nos maiores espaçamentos permitidos do card, o teste confirmou altura de 440 px e botão dentro da caixa. O texto se ajusta à área restante.
- Brakeman novamente sem alertas/erros; carregamento Rails, sintaxe Ruby/JavaScript e YAML das stacks passaram.
- As configurações novas usam os campos JSON já existentes. Não há migração adicional de espaçamento; execute apenas as migrações pendentes já indicadas no roteiro.
