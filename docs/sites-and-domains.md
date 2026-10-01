# Um site público e um painel para cada domínio

Rosemary e Thiago podem ter domínios, identidade visual, páginas, blog, formulário, mensagens e administradores próprios. O nome `Tenant` no código identifica esse conjunto; o visitante não vê esse termo nem precisa navegar por um portal compartilhado.

## Escolha de implantação

| Opção | O que é separado | Consequência |
| --- | --- | --- |
| Uma aplicação atendendo vários domínios | Contas, conteúdo, configurações e mensagens por site | Já suportado pelo modelo atual. CPU, memória e banco são compartilhados. |
| Uma instalação por cliente | Stack, banco, credenciais, armazenamento e ciclo de atualização | Pode reutilizar o mesmo código. Requer provisionar recursos exclusivos e manter cada instalação. |

O exemplo de Rosemary e Thiago funciona nas duas opções. As alterações desta revisão preservam a instalação existente; nenhuma cópia de produção ou novo domínio foi criado. Veja os [testes e limites de capacidade](performance-security-2026-10-01.md).

## Novo domínio na aplicação atual

Use somente domínios que você controla. `thiagoribeiro.com` abaixo é um exemplo do fluxo solicitado, não um domínio provisionado por esta revisão.

1. No node que executa a aplicação, localize o container e abra o provisionador interativo:

```sh
APP_CONTAINER=$(docker ps --filter label=com.docker.swarm.service.name=psychologist-app_web --filter status=running --format '{{.ID}}')
docker exec -it "$APP_CONTAINER" /rails/bin/docker-entrypoint bin/provision_tenant
```

Informe nome do profissional, identificador, e-mail de acesso, domínio sem `https://`, destinatário dos contatos e senha. O script não exibe a senha; o banco guarda seu hash. Guarde o link privado que será mostrado no terminal. Ele permite entrar no painel do novo site, sem conteúdo da Rosemary. A página de Contato inicial é criada; as demais páginas são montadas no painel. Para um cliente já cadastrado, não execute o provisionador novamente: atualize o domínio do registro existente no Rails console.

2. Aponte o DNS do domínio novo para o servidor que recebe o Traefik. Configure `@` e `www`; confirme que o desafio de certificado funciona. Se houver proxy Cloudflare, mantenha HTTPS com validação do certificado da origem.

3. Na stack da aplicação, acrescente novos routers em `deploy.labels`, mantendo os atuais. Exemplo para o segundo site, usando os nomes de rede/middlewares/service já presentes nesta stack:

```yaml
- traefik.http.routers.thiago.rule=Host(`thiagoribeiro.com`) || Host(`www.thiagoribeiro.com`)
- traefik.http.routers.thiago.entrypoints=websecure
- traefik.http.routers.thiago.tls=true
- traefik.http.routers.thiago.tls.certresolver=letsencryptresolver
- traefik.http.routers.thiago.service=psychologist
- traefik.http.routers.thiago.middlewares=psychologist-upload
- traefik.http.routers.thiago-http.rule=Host(`thiagoribeiro.com`) || Host(`www.thiagoribeiro.com`)
- traefik.http.routers.thiago-http.entrypoints=web
- traefik.http.routers.thiago-http.middlewares=psychologist-https
- traefik.http.routers.thiago-http.service=psychologist
```

Substitua o domínio e o nome `thiago` para cada site. As labels ficam no serviço `web`, dentro de `deploy.labels`, não nas labels do container. `APP_HOST` continua sendo o domínio principal da plataforma; ele não deve ser trocado a cada cliente. O domínio cadastrado no banco seleciona o site e define seus links canônicos e de recuperação de senha. Os routers adicionais apontam para o mesmo serviço Rails, conforme o [roteamento Swarm do Traefik](https://doc.traefik.io/traefik/v3.6/reference/routing-configuration/other-providers/swarm/).

4. Após atualizar a stack, teste o novo domínio em uma janela sem login. Entre também pelo link privado desse mesmo domínio. Publique as páginas configuradas e confira sitemap, contato e recuperação de senha. Não adicione links administrativos no site público.

## Sites sem domínio próprio

Para usar `/s/identificador`, configure `APP_HOST` com um domínio de plataforma que você controla e que não esteja cadastrado como domínio exclusivo de um cliente. Aponte DNS e Traefik para ele. O site sem domínio usa esse endereço e o painel usa o link privado nesse host. Mantenha `Tenant.domain` dos clientes com domínio próprio. Como `rosemarydias.com` pertence ao site Rosemary, ele não serve como endereço compartilhado para exibir outro cliente.

## Se preferir uma instalação por cliente

Use a mesma imagem Docker, mas dê a cada instalação seu domínio, banco/usuário, rede interna, volumes, secrets e nomes de routers/service próprios. Cada instalação também deve ter seu próprio conjunto de credentials/segredos de sessão. Não basta duplicar o YAML atual: ele declara recursos externos com nomes fixos, como `psychologist_postgres_data`, `psychologist_storage` e `psychologist_backend`, e isso pode conectar a cópia aos recursos do site existente.

Crie a nova base sem importar contas ou conteúdo de outro cliente. Provisione o cliente dessa instalação e configure `APP_HOST` para o domínio dela. Com Cloudinary, ambientes ou contas separados permitem credenciais de armazenamento próprias; a integração atual usa uma conexão global por instalação. Pastas por site em um mesmo ambiente não são isolamento de infraestrutura.

Mesmo stacks separadas podem disputar CPU/memória se executarem na mesma VPS. Defina limites por serviço e capacidade disponível; para tolerar perda de uma VPS, é necessário planejar também banco, armazenamento e nodes de aplicação.
