# Atualização 1.2.6 — tradução de botões e overlays

## O que muda

- Em cada botão, abra **Texto em inglês → Traduzir com IA**. O texto atual em português é enviado ao serviço de tradução já configurado. Revise e salve. Vale para botões de bloco, cabeçalho e rodapé, incluindo o editor da prévia. Um botão novo não recebe mais a tradução fixa “Learn more”. Se houver falha, a tradução anterior é mantida; respostas atrasadas não sobrescrevem texto alterado durante a requisição.
- O controle **Usar a foto profissional nesta seção** volta a aparecer como uma caixa compacta com rótulo na prévia e na tela completa. Continua acessível pelo teclado.
- Em **Mídia → Overlay do banner / da fotografia**, escolha a cor e a intensidade independentemente. **0%** deixa a imagem sem camada; **100%** mostra a cor sólida. A prévia pequena acompanha os ajustes. Há controles para desktop, tablet e mobile; campos vazios herdam o padrão. O efeito vale para todas as imagens da sequência do respectivo tipo, para banners acima/abaixo e de fundo, e para fotografias normais ou de fundo. O texto não recebe a opacidade da imagem.
- As configurações antigas de cor/escurecimento permanecem como padrão para fundos. Faixas e fotografias que não eram fundos continuam sem camada até receberem um ajuste explícito.

Os novos valores usam o JSON de layout que já existe. **Não há migração nova, dependência nova nem secret novo nesta versão.** A tradução usa a mesma chave `OPENAI_API_KEY` / `OPENAI_API_KEY_FILE` que já traduzia os textos do bloco. Não cole a chave no formulário nem no Git.

## Localhost

Pare o Rails com `Ctrl+C`, na pasta do projeto execute `bundle install` caso ainda não tenha instalado as dependências da 1.2.5 e reinicie com `bin/rails server`. Recarregue o navegador. Quem já está na 1.2.5 não precisa de alteração no banco para esta revisão.

Teste a tradução com uma frase curta; esse botão usa a API real configurada no `.env`. Os testes automatizados simulam o serviço, sem consumir créditos. No editor, salve o rascunho e confira a prévia. **Aprovar e publicar** aplica ao site as alterações de conteúdo e de overlay.

## Produção — Termius e Portainer

A imagem é construída no **banco-de-dados-manager02** e precisa continuar fixada nesse node. Preserve as stacks atualmente configuradas, principalmente SMTP, Cloudinary, redes, volumes e secrets. Altere somente a versão da imagem; não substitua a stack inteira pelos exemplos de instalação.

1. Envie `tmp/rosemarydias-source-1.2.6.tar.gz` e seu arquivo `.sha256` pelo SFTP para `/opt/rosemarydias/` no **banco-de-dados-manager02**.
2. Nesse servidor, confira e extraia o pacote em uma pasta nova:

```bash
cd /opt/rosemarydias
sha256sum -c rosemarydias-source-1.2.6.tar.gz.sha256
mkdir -p releases
mkdir releases/1.2.6
tar -xzf rosemarydias-source-1.2.6.tar.gz -C releases/1.2.6
cd releases/1.2.6
bash deploy/swarm/backup-production.sh
```

Só avance se o checksum estiver OK e o backup concluir. Se a pasta já existir, confira o conteúdo antes de reutilizá-la. Guarde a pasta de backup no Mac pelo SFTP.

3. Construa a imagem no mesmo node:

```bash
docker build -t psychologist-website:1.2.6 .
docker image inspect psychologist-website:1.2.6 --format 'Imagem disponível: {{.Id}}'
```

4. No Portainer, stack **psychologist-release**, defina `APP_IMAGE=psychologist-website:1.2.6`. Se `image:` estiver fixo no YAML, altere esse campo. Atualize com **Re-pull image desativado**. Verifique no worker:

```bash
docker ps -a --filter label=com.docker.swarm.service.name=psychologist-release_migrate --format 'ID={{.ID}} | IMAGEM={{.Image}} | STATUS={{.Status}}'
```

A tarefa 1.2.6 deve terminar como `Exited (0)`. Se houver falha, confira `docker logs ID_DO_CONTAINER` antes de continuar. Esta etapa não deve encontrar novas migrações em um banco já atualizado para a 1.2.5.

5. No Portainer, stack **psychologist-app**, defina a mesma imagem e atualize com **Re-pull desativado**. Preserve a configuração atual. Pode haver uma breve interrupção durante a substituição do container.
6. Aguarde a estabilização da atualização e confira no worker:

```bash
docker ps --filter label=com.docker.swarm.service.name=psychologist-app_web --format 'IMAGEM={{.Image}} | STATUS={{.Status}}'
```

Deve aparecer `psychologist-website:1.2.6` e `healthy`. Abra a página e o editor para testar os novos controles. O acesso SSH ao manager não é obrigatório para consultar esses containers, mas o manager precisa estar funcionando para o Portainer conseguir atualizar o Swarm. Se o Portainer não conseguir gerenciar a stack, recupere o manager antes de continuar; não crie outro Swarm.

Não execute seeds, restauração dos dados locais ou recriação de volumes. A atualização mantém os dados de produção.

## Retorno à versão anterior

Se necessário, altere a imagem da stack web para a registrada no backup (esperada: 1.2.5). Os campos novos podem permanecer no banco, mas a versão anterior não exibirá os novos overlays nem o botão de tradução. Não há migração desta revisão para desfazer.

## Validação

Os testes cobrem tradução autenticada com resposta simulada, falhas, respostas atrasadas, persistência, publicação e exibição em inglês. Também verificam o controle de mídia na prévia, validação dos valores de overlay, isolamento entre sites, herança por dispositivo e aparência pública/administrativa. Não são enviados e-mails nem chamadas à API externa pelos testes.

Resultado final: **50 testes, 507 verificações, zero falhas e zero erros**. Brakeman: zero alertas e zero erros. Carregamento Rails, sintaxe JavaScript, YAML das stacks e verificação de whitespace passaram. A página pública local também foi conferida com Playwright: nenhum erro de console e nenhuma largura excedente no viewport verificado.
