# Atualização 1.2.7 — artigos, editor e publicação

## Correções confirmadas

- **Erro 500 ao criar blocos:** o log de produção identificou `ActiveRecord::RecordNotUnique` no índice `index_sections_on_page_state_anchor`. O formulário enviava `anchor: ""`, e o banco tratava dois endereços vazios como duplicados. Agora, endereços em branco são normalizados para `NULL` antes da validação e gravação. A unicidade de endereços preenchidos continua protegida. Não é necessário excluir o artigo nem restaurar dados.
- **Fechar editor:** removido o controlador duplicado que interceptava o “×”. O fechamento esconde o painel e o fundo, restaura o foco e permite reabrir outro bloco. Escape também funciona.
- **Mover seções e conteúdo:** as requisições JSON recebem confirmação direta, sem seguir um redirecionamento para uma página HTML. A troca de posições só altera os rascunhos da mesma página, normaliza posições antigas repetidas e mantém a publicação atual até nova aprovação.

## Blog e textos

Entre em **Blog e textos → Novo texto** ou **Editar conteúdo**. A tela agora contém:

1. Tipo de texto, título e **Texto completo**.
2. Botões de **negrito**, *itálico*, subtítulo, listas, citação e link. Selecione o trecho e use o botão. `⌘B` / `Ctrl+B` e `⌘I` / `Ctrl+I` também funcionam.
3. **Ver formatação** para conferir o resultado antes de salvar.
4. **Versão em inglês → Traduzir com IA** para traduzir título e conteúdo usando a configuração atual. Revise antes de salvar. O limite atual da tradução é 12.000 caracteres por solicitação.
5. Card de apresentação, endereço e SEO. As configurações de menu e posição geral da página saíram desse fluxo de escrita.

O formato do exemplo enviado passa a funcionar:

```markdown
É nesse contexto que a **Comunicação Assertiva** e a **Comunicação Não Violenta (CNV)** se tornam importantes.

## Comunicação assertiva: clareza sem agressividade

- Escutar com atenção
- Expressar limites com respeito
```

O parser é [Redcarpet](https://github.com/vmg/redcarpet); o HTML final também passa pela sanitização do Rails. Scripts, imagens embutidas nesse texto e atributos perigosos não são aceitos. Fotos continuam nos controles de mídia. Os botões de formatação também aparecem nos parágrafos do editor de blocos.

**Salvar rascunho** conserva o conteúdo no editor; **Pré-visualizar e publicar** permite conferir o artigo no site. Textos anteriores continuam usando seus mesmos blocos. Se um artigo antigo tem um bloco vazio inicial e outro com o texto, a edição abre o bloco preenchido. Blocos adicionais e cards personalizados são preservados; podem ser ajustados em **Ajustar blocos e imagens** e **Editar card em Conteúdos**.

## Publicar uma página ou o site

A publicação anterior era por página. Por isso, aprovar a página principal não atualizava automaticamente o contato.

- **Aprovar e publicar**, na prévia: continua publicando somente a página aberta.
- **Publicar site…**, na prévia ou no painel: abre uma revisão com todas as páginas marcadas. Confira a lista, desmarque os artigos que ainda não estão prontos e clique em **Publicar páginas selecionadas**. Pode incluir principal, contato, Conteúdos e artigos na mesma operação.

**Salve os rascunhos primeiro.** Campos ainda não salvos em outra aba não são incluídos. Se uma das páginas falhar na validação, nenhuma das selecionadas recebe uma publicação parcial. Cada artigo mantém a data da primeira publicação.

## Espaçamento antes de salvar

Em **Aparência → Espaçamentos**, os controles agora ficam junto de uma prévia do próprio bloco. Ao alterar um valor, a prévia atualiza sem gravar no banco. Desktop, tablet e mobile têm prévias com suas respectivas larguras, reduzidas para caber no painel. A mesma regra de espaçamento usada no site gera essa visualização.

A prévia usa o texto atual e as imagens já salvas. Um arquivo de imagem recém-selecionado ainda deve ser salvo para aparecer nessa prévia; o editor de recorte continua mostrando o novo arquivo. Salvar o rascunho e publicar continuam sendo ações separadas.

## Atualizar o localhost

No terminal da pasta do projeto:

```bash
bundle install
```

Há uma nova dependência de Markdown. Pare o Rails local com `Ctrl+C` e reinicie:

```bash
bin/rails server
```

Recarregue o navegador. Esta revisão não adiciona migrações nem secrets. Se sua base ainda for anterior à 1.2.5, rode `bin/rails db:migrate` antes de iniciar.

## Atualizar a VPS com Termius e Portainer

O pacote contém o código atual, incluindo arquivos novos ainda não commitados. Não use `git archive HEAD` para substituir esse pacote enquanto as alterações não estiverem commitadas.

1. No SFTP do Termius, envie estes arquivos do Mac para `/opt/rosemarydias/` no **banco-de-dados-manager02**:

   - `tmp/rosemarydias-source-1.2.7.tar.gz`
   - `tmp/rosemarydias-source-1.2.7.tar.gz.sha256`

2. No terminal desse mesmo servidor, confira o pacote, extraia e faça o backup:

```bash
cd /opt/rosemarydias
sha256sum -c rosemarydias-source-1.2.7.tar.gz.sha256
mkdir -p releases
mkdir releases/1.2.7
tar -xzf rosemarydias-source-1.2.7.tar.gz -C releases/1.2.7
cd releases/1.2.7
bash deploy/swarm/backup-production.sh
```

Só avance com checksum OK e backup concluído. Baixe o backup por SFTP e guarde-o em local privado. Se `releases/1.2.7` já existir, confira seu conteúdo antes de reutilizá-lo.

3. Construa a nova imagem **no banco-de-dados-manager02**, onde a aplicação executa:

```bash
docker build -t psychologist-website:1.2.7 .
docker image inspect psychologist-website:1.2.7 --format 'Imagem disponível: {{.Id}}'
```

4. No Portainer, abra a stack **psychologist-release**. Mude `APP_IMAGE` para `psychologist-website:1.2.7`; se `image:` estiver fixo no YAML, altere essa linha. Atualize com **Re-pull image desativado**, pois a imagem foi construída localmente. Confirme no worker:

```bash
docker ps -a --filter label=com.docker.swarm.service.name=psychologist-release_migrate --format 'ID={{.ID}} | IMAGEM={{.Image}} | STATUS={{.Status}}'
```

A tarefa **1.2.7** precisa terminar como `Exited (0)`. Se falhar, pare e confira os logs desse container antes de atualizar o web.

5. Na stack **psychologist-app**, use a mesma imagem `psychologist-website:1.2.7` e atualize também com **Re-pull desativado**. Preserve os valores atuais de SMTP, Cloudinary, redes, secrets, volumes e a restrição para `banco-de-dados-manager02`. **Não substitua a stack já configurada pelos exemplos do repositório.** Nesta atualização, só a imagem precisa mudar.

6. Aguarde a atualização estabilizar e confira:

```bash
docker ps --filter label=com.docker.swarm.service.name=psychologist-app_web --format 'IMAGEM={{.Image}} | STATUS={{.Status}}'
```

Deve aparecer **1.2.7** e **healthy**. Abra novamente o painel e teste criar/editar um artigo, fechar o editor, mover seções, ver a formatação e alterar um espaçamento antes de salvar. Depois, salve os rascunhos desejados e use **Publicar site…** para aplicá-los juntos.

Não rode seeds, restauração da base local nem recriação de volumes. A atualização conserva os dados da VPS. A troca do container pode causar uma breve interrupção. O manager precisa estar funcionando para o Portainer atualizar o Swarm, mesmo quando os comandos de consulta são executados no worker.

## Voltar à imagem anterior

Anote a imagem atual antes da atualização ou consulte a registrada no backup. Se necessário, volte a stack web para essa imagem, mantendo os mesmos volumes e secrets. Como esta revisão não adiciona migrações, não há alteração de esquema a desfazer. A versão anterior não interpreta a nova formatação Markdown.

## Verificação local

Testes cobrem criação e edição sem endereço de bloco, edição dos textos antigos, rascunhos e publicações, isolamento entre sites, sanitização da formatação, fechamento e arraste no navegador, prévia de espaçamento sem persistência e publicação conjunta com rollback. A IA é simulada nos testes; nenhum e-mail ou publicação na VPS é executado por eles.

Resultado: **161 testes Rails (1.423 verificações)** e **29 testes de navegador (441 verificações)** passaram sem falhas ou erros. Também passaram os testes de exclusão de blocos e de espaçamentos existentes. Brakeman: **zero alertas e zero erros**. Carregamento Rails, sintaxe dos novos módulos JavaScript, YAML das stacks e whitespace foram verificados.
