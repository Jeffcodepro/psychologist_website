# Revisão de segurança — 28/09/2026

Revisão histórica. Consulte também a [verificação de desempenho, domínios e segurança de 01/10/2026](performance-security-2026-10-01.md).

## Controles implementados e verificados

| Ponto | Controle |
| --- | --- |
| Separação entre clientes / IDOR | Consultas administrativas partem de `current_user.tenant`; páginas, blocos, cards e mensagens de outro cliente retornam 404. O `tenant_id` enviado pelo navegador não é aceito como autorização. Publicação e troca de blocos seguem o mesmo escopo. |
| Acesso / cadastro | Cadastro público removido. Link privado aleatório de 256 bits, com apenas SHA-256 salvo no banco, e autenticação por e-mail, senha e cliente. Usuários sem `admin` e clientes inativos são recusados. |
| Senhas | Hash bcrypt pelo Devise; novas senhas com 12–128 caracteres. Nenhuma senha em texto deve ser gravada diretamente no banco. |
| Força bruta | Bloqueio após seis senhas erradas por 30 minutos; limite de requisições por IP para autenticação, formulário e tradução. Redis permite compartilhar contadores entre servidores. |
| Sessões / cookies | Expiração por inatividade em 30 minutos, cookie HttpOnly/SameSite=Lax, Secure e HTTPS em produção. Respostas administrativas e autenticação sem cache. |
| Tokens | Recuperação de senha com token temporário armazenado por hash e invalidado após uso. Rotação do link privado. Não reutilizar `SECRET_KEY_BASE` entre ambientes. |
| CSRF / envio duplicado | Proteção Rails nas mutações; botões Turbo ficam bloqueados durante envio. Formulário com honeypot e limites por sessão/IP, além do middleware. |
| Validação | HTML required/tipo/comprimento e validação independente no servidor. O servidor usa o esquema publicado do cliente, sem aceitar campos, opções ou esquema enviados como configuração pelo visitante. |
| SQL injection / XSS | Active Record parametrizado; campos e operações permitidos explicitamente; conteúdo escapado/sanitizado; enumerações e cores/fontes validadas antes de gerar CSS. |
| Uploads | Somente multipart autenticado. Identificação por conteúdo (Marcel), JPG/PNG/WebP e máximo 10 MB por arquivo. IDs assinados de blobs e URLs remotas recusados na entrada. Endpoints de upload direto não utilizados foram bloqueados. |
| SSRF | Não há busca de URLs arbitrárias para uploads; tradução usa URL HTTPS fixa e timeouts. SMTP é configurado pelo operador no ambiente. Links sociais não são buscados pelo servidor. |
| Segredos / arquivos | `.env`, chaves, armazenamento, logs e tmp fora do Git/Docker; rotas de arquivos sensíveis bloqueadas. Nunca coloque esses arquivos em `public/`. Parâmetros de contato, senha e chaves filtrados dos logs. |
| CORS / cabeçalhos | Sem CORS aberto. CSP, frame-ancestors self, nosniff e política de referência. Login usa no-referrer; host autorizado por domínio cadastrado em produção. |
| Erros | Produção não mostra stack traces. Falhas de e-mail/tradução retornam mensagens controladas. |
| Dependências | Rails atualizado de 7.1 fora de suporte para 8.1.4, Devise 5.0.4 e dependências resolvidas. Auditoria por Brakeman e ruby-advisory-db. |

## Limites da verificação

Verificação local concluída: 54 testes, 499 assertions, sem falhas; carregamento Zeitwerk sem erros; Brakeman sem avisos e ruby-advisory-db sem vulnerabilidades conhecidas nas versões instaladas (base atualizada em 28/09/2026). Fluxos de formulário, prévia em inglês, fontes, botões, cards automáticos de Conteúdos, resumos que respeitam a publicação e layouts responsivos também foram conferidos no navegador. Clientes e contas temporárias usados nessa conferência foram removidos, preservando o conteúdo e as mensagens do cliente principal.

A revisão local e as ferramentas automáticas não garantem ausência total de vulnerabilidades. DNS, TLS, proxy, permissões do banco, Redis, backups e acesso ao servidor dependem da implantação. Configure o proxy para não registrar o segmento secreto `/admin/access/...` nos logs de acesso; guarde o link como uma credencial. Evite logs de debug em produção.

Imagens publicadas são arquivos públicos por natureza. URLs assinadas de Active Storage funcionam como permissão de leitura para quem as recebe; não use a biblioteca de mídia para documentos confidenciais. Arquivos enviados não são antivírus-scaneados; há restrição de formato e tamanho. O isolamento é por aplicação e chaves estrangeiras em um banco compartilhado, sem PostgreSQL RLS.

Não há autenticação de dois fatores neste escopo. Redis compartilhado é necessário para limites consistentes em mais de um servidor. Proteção contra ataques volumétricos deve ser feita também no provedor/proxy.

## Fontes e reprodução

- [Fim do suporte ao Rails 7.1](https://rubyonrails.org/2025/10/29/new-rails-releases-and-end-of-support-announcement)
- [Rack::Attack: limites e cache compartilhado](https://github.com/rack/rack-attack)
- [Devise](https://github.com/heartcombo/devise)

Execute os comandos de verificação do README. Os testes incluem login real, conta bloqueada, token de recuperação, CSRF, troca de IDs entre clientes, uploads inválidos, formulário publicado, fontes e permanência da prévia no CMS. Nenhum teste envia e-mail real.
