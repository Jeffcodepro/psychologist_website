# CMS de sites profissionais

Ruby 3.3.5, Rails 8.1, PostgreSQL, Devise e Stimulus. Cada profissional pode ter um site público e um painel próprios, no seu domínio. Páginas, configurações, mensagens e contas são separados por site (`tenant_id` é o identificador interno). Sites sem domínio próprio podem usar `/s/identificador` em um host de plataforma neutro; um domínio cadastrado para um cliente exibe somente o site desse cliente.

## Desenvolvimento

```sh
bundle install
bin/rails db:prepare
bin/rails server
```

Copie `.env.example` para `.env` ao configurar um ambiente novo. Preserve o `.env` existente. Não versione senhas, chaves nem links privados. Os seeds só podem ser executados em banco sem páginas; nunca recriam conteúdo sobre o banco atual.

## Contas e acesso privado

Não existe cadastro público. Crie cada cliente pelo terminal:

```sh
bin/provision_tenant
```

O comando pede os dados e lê a senha sem exibi-la. A senha é transformada em hash pelo Devise/bcrypt; não insira uma senha em texto no campo `encrypted_password`. O cliente recebe seu próprio link privado, ainda protegido por e-mail e senha, e uma página de Contato editável. O link não aparece no site público. `/admin/login`, `/users/sign_in` e `/users/sign_up` não são entradas de acesso.

Para gerar outro link de um cliente existente, no console Rails:

```ruby
tenant = Tenant.find_by!(slug: "identificador-do-cliente")
puts tenant.rotate_admin_link!
```

A rotação invalida o link anterior. Ela não encerra sessões já autenticadas. Para suspender um cliente, use `tenant.update!(active: false)`; o painel e o site deixam de estar acessíveis. A conta original e o conteúdo existente foram associados ao cliente principal. O link inicial local está em `tmp/admin-access.txt`, ignorado pelo Git.

## Contato, prévia e fontes

Em **Páginas → Contato → Editar conteúdo → Editar bloco → Formulário**, adicione, exclua e reordene campos pela alça ou pelas setas. Configure nome PT/EN, tipo, obrigatoriedade e largura. Salve o rascunho e use **Aprovar e publicar** para mudar o formulário público. Mensagens antigas preservam os rótulos e respostas da época do envio.

O idioma escolhido na prévia acompanha a navegação do painel. Os links de Contato e a logo da prévia permanecem no CMS. Para ver o site público como visitante, use uma janela sem sessão administrativa.

Em **Aparência**, títulos e textos têm 27 famílias com busca e amostra visual, peso, estilo, tamanho, entrelinhas e espaçamento. Tablet e mobile podem herdar ou substituir os ajustes do desktop. Textos longos nos cards abrem em **Ler mais**, sem capturar a rolagem da página. Setas do carrossel ficam nas extremidades no mobile e fora dos cards em telas maiores.

## Envio de e-mails

Configure `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `MAILER_FROM` e `APP_HOST`. No Gmail, utilize senha de aplicativo. `CONTACT_RECIPIENT` é somente o destinatário de fallback do cliente principal. Clientes novos usam `Tenant.contact_recipient`; eles nunca herdam o destinatário de outro cliente.

As mensagens são salvas antes da tentativa de envio. Falhas aparecem em **Mensagens**, com opção de reenviar. O e-mail inclui os campos personalizados e usa o endereço informado pelo visitante como `Reply-To`, quando o formulário tem um campo de e-mail. Os testes usam o adaptador `:test` e não enviam e-mails externos.

## Publicação e domínios

Para atualizar a aplicação que já está no ar, siga [o roteiro 1.1.1 com Cloudinary](docs/update-cloudinary-seo.md). Para a primeira instalação no Portainer/Swarm, use [o guia de deploy e importação dos dados locais](docs/deploy-swarm.md) e os arquivos de `deploy/swarm/`. O domínio inicial é `rosemarydias.com`. A stack usa master key e senhas via Docker Secrets; `secret_key_base` é lido das credentials criptografadas. O Dockerfile compila os assets e as migrações rodam separadamente. Use HTTPS; cookies de produção são Secure, HttpOnly e SameSite=Lax. Mantenha banco, volumes de uploads e backups privados.

Para domínio próprio, cadastre `tenant.update!(domain: "www.cliente.com.br")`, configure o DNS e o certificado TLS no provedor. O domínio deve chegar a esta aplicação. Hosts não cadastrados são recusados em produção. Sites sem domínio próprio usam `/s/identificador` em um host de plataforma neutro, conforme o guia de novos sites.

Em produção com vários processos ou servidores, configure `RATE_LIMIT_REDIS_URL` para compartilhar limites de acesso. Sem Redis, usa-se arquivo local, adequado a um único servidor. Configure o proxy para limitar uploads a 30 MB por requisição e sobrescrever cabeçalhos encaminhados pelo cliente. O aplicativo aceita apenas imagens JPG/PNG/WebP com até 10 MB cada. Não publique o servidor de desenvolvimento na internet.

Veja [como disponibilizar novos sites e domínios](docs/sites-and-domains.md), o [relatório de carga e segurança de 01/10/2026](docs/performance-security-2026-10-01.md), [a revisão de segurança anterior](docs/security-review.md) e [a limpeza de arquivos](docs/cleanup.md).

## Verificações

```sh
bin/rails test
bin/rails zeitwerk:check
bundle exec brakeman --no-pager
bundle exec bundle-audit check --update
```

A atualização para Rails 8.1 mantém inicialmente `config.load_defaults 7.1` para preservar comportamentos existentes; as proteções descritas são configuradas explicitamente. Reexecute os testes e a auditoria a cada atualização.

## Botões e ações

Em **Conteúdo → Botões deste bloco**, adicione ou exclua botões de qualquer seção; arraste os itens ou use as setas para ordenar. Escolha o rótulo PT/EN, estilo e destino: Contato, página do próprio cliente, âncora, URL externa, WhatsApp, e-mail ou telefone. O conjunto pode ficar antes dos textos, entre título/parágrafo ou depois, alinhado à esquerda, centro ou direita. Na prévia, a alça **Botões** permite arrastar o conjunto ou transferi-lo para outro trecho. Tablet e mobile têm posição própria em Aparência.

Em **Configurações gerais**, os botões do cabeçalho e rodapé podem ser alterados ou removidos separadamente. Blocos novos começam sem botões; apagar todos não recria um botão automático. Links para páginas internas permanecem dentro do CMS na prévia.

## Blog, artigos e reflexões

Em **Blog e textos → Novo texto**, escolha Artigo ou Reflexão e a seção de apresentação na página Conteúdos. O artigo e seu card são criados juntos, já vinculados. A opção Automático usa Artigos ou Reflexões conforme o tipo do texto; também é possível escolher Destaques. Se o cliente ainda não tiver a página ou seção necessária, ela é criada em rascunho.

Use **Card em Conteúdos** para editar a imagem, o título, o resumo, a ordem e a seção do card. A tela mostra uma prévia após salvar. O card apresenta até 240 caracteres e o botão **Saiba mais**; clicar no botão ou em qualquer área do card abre o texto completo. Um resumo vazio usa automaticamente um trecho do artigo, respeitando a versão publicada no site e o rascunho no CMS. A apresentação pode ser personalizada sem alterar o texto completo.

O texto completo usa o mesmo editor das páginas: blocos, imagens, fontes, botões, versões PT/EN e prévia responsiva. Use **Pré-visualizar e publicar → Aprovar e publicar** para disponibilizá-lo aos visitantes e publique também Conteúdos após editar seus cards. Os textos têm endereço próprio e ficam fora do menu principal por padrão.

Artigos e reflexões mostram a data da primeira publicação no texto, no card e no CMS. Atualizar e publicar novamente preserva essa data. Para textos já publicados antes desse recurso, usa-se a data de publicação que já estava registrada. Datas seguem o fuso `America/Sao_Paulo` e o idioma da página.

Nos cards de qualquer seção (inclusive Destaques, Artigos e Reflexões), abra **Editar card e destino → Ao clicar no card**. Escolha um texto ou página do próprio site e salve. Também é possível usar **Salvar e criar texto completo**, que cria um artigo em rascunho aproveitando título, texto, traduções e imagem do card. A opção **Sem redirecionamento** remove o vínculo e mantém a leitura do card.

Publique o texto de destino e também a página que contém o card após configurar o vínculo. Um mesmo texto pode aparecer em vários cards. Cards vinculados são clicáveis em toda a área e mantêm o idioma; na prévia, abrem outra prévia dentro do CMS. Destinos em rascunho não geram links públicos. Excluir um texto preserva os cards, retirando somente o vínculo com ele.
