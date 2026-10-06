# Atualização 1.2.2

Esta versão reorganiza o seletor visual de posições, restaura os cards compactos no desktop/tablet, deixa os pontos de paginação somente no mobile, reformula o e-mail de contato e acrescenta botões com cores, tamanho, formato e seleção de uma seção de destino.

Também inclui os ajustes anteriores da 1.2.0/1.2.1: composição de imagens e cards, remoção do locale na URL administrativa, modelos de SEO, favicon da logo, fontes, posição do formulário e espaçamentos.

**Execute a migração antes de atualizar a aplicação.** A nova coluna `sections.navigation_key` mantém os links de seções estáveis após republicar. As migrações de cards e espaçamentos anteriores também serão executadas se estiverem pendentes. Não são necessários novos secrets, serviços, redes ou credenciais de e-mail/Cloudinary.

## 1. No Mac: criar o pacote atualizado

Na pasta do projeto:

```sh
git status --short
git add -- app config db/migrate db/schema.rb test deploy docs README.md
git diff --cached --check
git diff --cached --stat
git ls-files --cached -- .env config/master.key 'config/credentials/*.key'
```

O último comando deve ficar sem saída. Revise as alterações antes do commit. Não inclua credenciais, backups ou exportações.

```sh
git commit -m "Ajusta carrossel responsivo posicoes botoes e email de contato"
mkdir -p tmp
git archive --format=tar.gz --output=tmp/rosemarydias-source-1.2.2.tar.gz HEAD
tar -tzf tmp/rosemarydias-source-1.2.2.tar.gz db/migrate/20261002160000_add_navigation_key_to_sections.rb app/assets/stylesheets/components/_interaction_refinements.scss
shasum -a 256 tmp/rosemarydias-source-1.2.2.tar.gz
```

`git archive HEAD` inclui somente arquivos já commitados. Pelo **SFTP do Termius**, envie o pacote para:

```text
Servidor: banco-de-dados-manager02
Destino: /opt/rosemarydias/rosemarydias-source-1.2.2.tar.gz
```

## 2. No terminal de banco-de-dados-manager02: backup e imagem

```sh
ls -lh /opt/rosemarydias/rosemarydias-source-1.2.2.tar.gz
sha256sum /opt/rosemarydias/rosemarydias-source-1.2.2.tar.gz
mkdir /opt/rosemarydias/releases/1.2.2
tar -xzf /opt/rosemarydias/rosemarydias-source-1.2.2.tar.gz -C /opt/rosemarydias/releases/1.2.2
cd /opt/rosemarydias/releases/1.2.2
bash deploy/swarm/backup-production.sh
```

Compare o hash com o do Mac. Só prossiga depois de “Backup concluído”. Baixe a pasta indicada e guarde-a fora do servidor. Pause as edições no CMS durante a atualização. O backup de storage local não contém imagens que já estão no Cloudinary; preserve esse ambiente também.

```sh
docker build -t psychologist-website:1.2.2 .
docker run --rm --entrypoint /bin/sh psychologist-website:1.2.2 -c 'test -s /rails/db/migrate/20261002160000_add_navigation_key_to_sections.rb && test -s /rails/app/assets/stylesheets/components/_interaction_refinements.scss'
```

O último comando termina sem saída e sem erro. A imagem foi criada nesse node; mantenha a aplicação e a migração fixadas nele pelas constraints existentes.

## 3. No Portainer: atualizar psychologist-release

Abra **Stacks → psychologist-release** e use o conteúdo de [deploy/swarm/migrate.yml](../deploy/swarm/migrate.yml).

- Em **Environment variables**, defina `APP_IMAGE=psychologist-website:1.2.2`.
- Preserve os secrets e redes existentes.
- Atualize com **Re-pull image desativado**.

No terminal do **manager02**:

```sh
docker service ps psychologist-release_migrate --no-trunc
docker service logs --tail 60 psychologist-release_migrate
```

Espere a tarefa da imagem **1.2.2** ficar **Complete**, sem erro. Os logs devem mostrar `AddNavigationKeyToSections` concluída; podem aparecer também as migrações de versões anteriores. `0/1` após terminar é normal para essa stack de migração. Se houver erro, pare nessa etapa.

## 4. No Portainer: atualizar psychologist-app

Abra **Stacks → psychologist-app** e use [application-cloudinary.yml](../deploy/swarm/application-cloudinary.yml), pois seu Cloudinary já está funcionando. A alternativa para disco local continua em [application.yml](../deploy/swarm/application.yml).

Defina `APP_IMAGE=psychologist-website:1.2.2` nas variáveis **dessa stack também**. Uma variável antiga sobrescreve a tag padrão do YAML. Preserve `APP_HOST=rosemarydias.com`, storage, e-mail, secrets, redes e volumes. Atualize com **Re-pull image desativado**.

Não recrie o banco nem execute seeds/importação. A troca usa `stop-first`, com uma breve interrupção.

No **manager02**:

```sh
docker service inspect psychologist-app_web --format 'Imagem: {{.Spec.TaskTemplate.ContainerSpec.Image}}'
docker service ps psychologist-app_web --no-trunc
docker service ls --filter name=psychologist-app_web
```

Confirme imagem **1.2.2**, tarefa **Running** e **1/1** réplica.

No **banco-de-dados-manager02**:

```sh
APP_CONTAINER=$(docker ps --filter label=com.docker.swarm.service.name=psychologist-app_web --filter status=running --format '{{.ID}}')
docker exec "$APP_CONTAINER" /rails/bin/docker-entrypoint bin/rails db:abort_if_pending_migrations
curl -I https://rosemarydias.com
```

O comando de migrações deve terminar sem erro. Confira o site em uma janela sem login e no celular.

## 5. Onde encontrar as alterações

### Imagens e posições

Na pré-visualização, clique no controle de posição da imagem. Acima, abaixo, esquerda e direita agora ocupam os lugares correspondentes, com pequenas ilustrações. As opções entre título/parágrafo, antes dos botões e imagem de fundo aparecem na linha inferior. Os ajustes continuam separados por dispositivo.

### Carrossel

No desktop e tablet, o carrossel mantém cards compactos (até 360 px de largura), distribuídos automaticamente conforme o espaço da seção, como no layout anterior. Não amplia um card para preencher toda a linha. Quando todos cabem, não aparecem setas, barra nem avanço automático. Com excedentes, as setas avançam um card por vez e uma barra discreta abaixo permite escolher a posição. O conjunto respeita o alinhamento configurado quando não há excedentes. Todos os cards têm **440 px de altura e até 360 px de largura**, com ou sem imagem ou texto. A largura diminui quando há menos espaço. Imagens acima/abaixo do texto usam uma área de **190 px**; formatos diferentes não ampliam o card. O texto aparece como resumo dentro do espaço disponível, com reticências e acesso ao conteúdo completo por “Ler mais” ou pelo destino de “Saiba mais”. Não há rolagem dentro do card. Na grade, o mesmo limite vale entre todas as linhas.

Com “Quebrar em novas linhas” ativo, a quantidade de colunas escolhida para cada dispositivo organiza a grade e não há carrossel. No modo carrossel, a quantidade visível é automática; configurações antigas de uma coluna não ampliam os cards.

Até 600 px de largura, aparecem os pontos de paginação. Não há botão de pausa. Selecionar um ponto ou a barra mantém o conteúdo escolhido; o avanço automático também respeita foco pelo teclado e preferência por movimento reduzido. Se todos os cards couberem, os controles ficam ocultos. As setas e o avanço automático funcionam na página pública.

### Prévia do card durante a edição

Em **Editar card → Imagem opcional**, a prévia mostra o card inteiro antes de salvar. O texto, a foto selecionada, os ajustes de recorte e a composição mudam imediatamente. Arraste a imagem na própria moldura do card para enquadrá-la. A prévia usa o mesmo componente da página pública.

- **Desktop / Tablet / Mobile:** confira a composição e as fontes de cada dispositivo. Ao alterar uma opção de composição, a prévia muda para aquele dispositivo.
- **Largura da prévia:** simule entre 240 e 360 px para conferir a quebra do texto e o recorte em cards mais estreitos. A largura pública depende do espaço disponível na seção; a altura permanece em 440 px.
- As mesmas ferramentas aparecem no editor **Card em Conteúdos** dos artigos. Salve o card e publique a página para aplicar as alterações no site.

Esses limites são definidos no layout da aplicação e não exigem recriar os cards existentes, novas credenciais ou uma migração adicional.

### Botões para qualquer página ou seção

- **Páginas → conteúdo da página → Adicionar botões:** cria um bloco somente com botões, que pode ser reordenado entre os outros blocos.
- **Editar bloco → Botões:** adiciona, remove e reordena botões junto ao conteúdo. Os controles de posição/alinhamento ficam na mesma aba.
- **Estilo → Personalizado:** escolhe cor do botão e cor do texto. Tamanho e formato também podem ser alterados, com amostra visual.
- **Ação → Seção de uma página:** escolhe a página e a seção pelo nome. Também continuam disponíveis página, contato, trecho por âncora, link externo, WhatsApp, e-mail e telefone.

**Para usar os novos destinos de seção, publique a página de destino uma vez depois da atualização**, revisando os rascunhos antes. Isso sincroniza os identificadores estáveis com a versão pública. O seletor avisa “publique para ativar” quando necessário. Salve e publique também a página que contém o novo botão. Destinos ainda não publicados não aparecem como links no site público; as prévias permanecem no ambiente administrativo.

Republicar ou reordenar uma seção mantém o destino. Se a seção for excluída e a exclusão publicada, o link deixa de aparecer, sem impedir que outras páginas sejam publicadas. No editor, escolha outro destino ou exclua o botão antigo.

### E-mail de contato

As próximas notificações usam o novo layout com identidade do site, data, campos organizados e botão para responder. A versão em texto continua disponível para leitores de e-mail. O destinatário e as configurações SMTP permanecem os mesmos; mensagens antigas na caixa de entrada não são alteradas.

O template foi conferido localmente com dados fictícios, sem envio real. A apresentação pode variar entre aplicativos de e-mail.

## Para testar no localhost

```sh
bin/rails db:migrate
```

Reinicie o servidor Rails. A migração desta versão já foi aplicada no banco local desta sessão; o comando acima é seguro caso existam outras migrações pendentes.

## Se precisar voltar

Use a imagem anterior registrada em `image.txt` no backup como `APP_IMAGE` na stack web, com Re-pull desativado. Mantenha a imagem anterior até validar a atualização. As migrações são aditivas: não execute `db:rollback`, seeds ou restauração apenas para trocar a imagem.

O código anterior não reconhece o novo destino “Seção de uma página” nem o estilo “Personalizado”. Se voltar depois de usá-los, revise esses botões no editor. Banco, contas, páginas e imagens não precisam ser recriados.

Nenhuma alteração de produção foi executada nesta sessão.

## Validação local

- Verificação dos cards nesta revisão: **28 testes de navegador e 30 testes de controllers, sem falhas**. Cobrem limites de 360 × 440 px, resumo com acesso ao conteúdo completo, recorte equivalente entre editor e publicação, prévia antes de salvar, texto completo acessível e navegação responsiva. Também conferem rotação/espelhamento ao passar o mouse e arraste de imagens usadas como fundo. Os cards reais do localhost também foram medidos: cerca de 352 × 440 px, com área de imagem de 190 px, na tela de 1.280 px.
- Controllers, modelos e e-mail: 112 testes, 1.024 verificações, sem falhas.
- E-mail conferido em HTML e texto, incluindo escape do conteúdo enviado pelo formulário.
- Análise estática Brakeman: zero alertas e zero erros. YAML das stacks, sintaxe da migração e diff conferidos.
