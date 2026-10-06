# Proteção do formulário de contato

## Comportamento da aplicação

- Após salvar uma mensagem, a confirmação permanece por **10 minutos** ao recarregar ou abrir outra aba no mesmo navegador. Depois desse intervalo, recarregue para mostrar novamente o formulário.
- O servidor recusa novos envios por **10 minutos** quando coincidir o navegador, o IP ou o e-mail normalizado (sem espaços nas extremidades e em minúsculas). Cada site possui seu próprio histórico.
- O mesmo IP pode salvar no máximo **5 contatos em uma janela móvel de uma hora por site**. Outra sessão ou limpeza dos cookies não apagam esse histórico do banco.
- A verificação e o salvamento usam um lock curto no registro do site. Dois processos ou réplicas não conseguem salvar simultaneamente o mesmo contato contornando a consulta anterior.
- O IP é armazenado como HMAC, não como endereço aberto. Não há fingerprint invasivo de dispositivo.
- A sessão recebe somente site e horário do envio, protegidos pelo cookie criptografado do Rails. Dados pessoais não aparecem no comprovante mostrado ao visitante.
- SMTP roda depois de salvar e liberar o lock. Uma falha de e-mail não libera reenvios duplicados: a mensagem fica no painel para o administrador reenviar.
- Mensagens inválidas continuam editáveis. Honeypot, validação no servidor, CSRF e desativação do botão durante o envio continuam ativos.

No middleware, cada IP tem até **5 tentativas por janela de 10 segundos** e **10 por janela de 10 minutos**, incluindo dados inválidos. Os caminhos `/contato`, `/contato/`, `/contato.json` e `/s/identificador/contato` compartilham o contador do IP. O excesso retorna **HTTP 429**, `Retry-After` com o tempo restante e uma mensagem compatível com Turbo, evitando “Content missing”. Essas janelas são fixas, diferentemente do limite de contatos salvos no banco.

O intervalo está em `ContactSubmissionGuard::COOLDOWN`; os limites de mensagens estão na mesma classe. Os limites de tentativas ficam em `config/initializers/rack_attack.rb`.

## Limites práticos

IP e e-mail são sinais de controle, não prova de identidade. Pessoas no mesmo Wi-Fi podem compartilhar o limite de IP. Alguém que troque simultaneamente rede, navegador e e-mail pode escapar desses sinais; os controles da aplicação não garantem proteção contra um ataque distribuído/volumétrico.

Os limites de mensagens salvas usam PostgreSQL e continuam entre reinícios e réplicas. O histórico usado nesses limites é o de contatos existentes: excluir mensagens recentes no admin remove essas mensagens da contagem do banco. A confirmação da sessão continua até expirar.

Para contadores de tentativas consistentes entre processos/nodes, configure `RATE_LIMIT_REDIS_URL` com Redis compartilhado. A stack atual usa um processo e o volume `psychologist_rate_limits` no mesmo node. Não apague o volume durante atualizações. A limitação de mensagens no banco não depende desse cache.

O IP considerado é `request.remote_ip`, após o tratamento de proxies do Rails. Traefik/Cloudflare precisam encaminhar o IP real e aceitar cabeçalhos encaminhados apenas dos proxies confiáveis. Não confie diretamente em `CF-Connecting-IP` ou `X-Forwarded-For` enviado pela internet. Um proxy mal configurado pode fazer vários visitantes parecerem o mesmo IP ou aceitar endereços falsificados.

## Cloudflare: proteção antes de chegar à aplicação

1. Em DNS, mantenha `rosemarydias.com` e `www` com o proxy da Cloudflare habilitado (nuvem laranja), com HTTPS funcionando no servidor de origem.
2. Em **Security → Security rules → Rate limiting rules** (o nome pode aparecer como WAF), crie uma regra para os caminhos do formulário. Se seu plano permitir filtrar método, aplique a `POST`. Inclua `/contato`, `/contato/`, sufixos como `/contato.json` e caminhos `/s/.../contato` caso os utilize.
3. Como ponto inicial, limite **5 requisições em 10 segundos por IP** e use bloqueio temporário com a duração disponível no seu plano. Os campos, períodos e ações variam por plano. Se só houver filtro por caminho, a regra também contará visitas GET a esse caminho: considere isso ao ajustar o limite.
4. Observe os eventos da regra e valide um envio normal pelo navegador. Evite desafios interativos diretamente na resposta do POST Turbo; podem impedir a exibição da confirmação. Para desafio no próprio formulário, uma próxima integração possível é Turnstile com validação obrigatória no servidor e as chaves do seu domínio.
5. Confira com cuidado a proteção da origem: permitir contornar a Cloudflare acessando o IP da VPS reduz essa proteção. Restrições de firewall devem considerar os outros serviços do manager (Portainer, SSH, Swarm e outros domínios); não bloqueie portas globais sem revisar esses serviços e o acesso de manutenção.
6. Não habilite cache público do HTML do formulário/CMS: o idioma e a confirmação dependem da sessão. A aplicação mantém respostas privadas e os POSTs/429 sem cache.

Essas configurações externas não foram aplicadas automaticamente. Não foram feitos testes de ataque contra produção.

Fontes: [Cloudflare DDoS Protection](https://developers.cloudflare.com/ddos-protection/), [Rate limiting rules](https://developers.cloudflare.com/waf/rate-limiting-rules/), [Parâmetros por plano](https://developers.cloudflare.com/waf/rate-limiting-rules/parameters/), [Proteção da origem](https://developers.cloudflare.com/fundamentals/security/protect-your-origin-server/), [Rack::Attack](https://github.com/rack/rack-attack).
