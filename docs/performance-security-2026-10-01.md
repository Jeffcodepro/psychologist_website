# Desempenho, segurança e sites por domínio — 01/10/2026

## O modelo de produto

A plataforma permite que cada profissional tenha seu site público, domínio, conteúdo e painel próprios. `Tenant` é apenas o nome interno do registro que reúne esses dados. Não obriga o cliente a usar um subdiretório nem a acessar o painel de outra pessoa.

Na instalação compartilhada, os dados são separados pela aplicação, mas CPU, memória e banco são compartilhados. Se a intenção for vender uma instalação com recursos, atualizações e banco independentes, use uma stack separada por cliente. Não é necessário reescrever o editor para nenhuma dessas opções. A criação de outro site dentro da instalação atual é simples; isolamento de infraestrutura exige provisionamento e operação adicionais.

Veja o [guia de novos sites e domínios](sites-and-domains.md). Nenhum novo domínio real foi configurado nesta revisão.

## Teste de carga executado

- Alvo: somente `127.0.0.1:3101`, banco exclusivo `psychologist_website_performance`, com dados artificiais. Os bancos de desenvolvimento e produção não foram usados pela carga.
- Ambiente: macOS ARM64, 11 núcleos físicos, 18 GiB de RAM; Ruby 3.3.5, Rails 8.1.4, Puma 8.0.2, um processo com cinco threads e pool de sete conexões.
- Dois sites fictícios, cada página inicial com 12 seções, 36 cards, seis perguntas e 41 referências a imagens. O HTML tinha aproximadamente 197 KB antes da compressão.
- O carregamento do código é antecipado e sem recarga automática, como em produção. Assets podem ser compilados localmente; não entram na medição de carga.
- Modelo de carga fechado: cada cliente de teste envia a próxima requisição assim que a anterior termina. Concorrência aqui significa requisições HTTP simultâneas, não visitantes com uma página aberta.
- Os estágios duraram dez segundos de envio, mais o tempo de conclusão das requisições em andamento. O teste após a mudança aqueceu os dois domínios antes da medição. O primeiro estágio da linha de base incluiu o primeiro acesso do processo HTTP; compare principalmente os estágios de 10 a 50.
- Todos os estágios validaram status 200 e o conteúdo do domínio correto. O teste com publicação também validou exatamente 12 seções e 36 cards em cada resposta.

| Requisições simultâneas | Antes: respostas/s | Depois: respostas/s | Antes: p95 | Depois: p95 | Erros depois |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 11,96 | 27,10 | 96 ms | 39 ms | 0 |
| 10 | 15,15 | 26,52 | 764 ms | 415 ms | 0 |
| 25 | 16,74 | 26,48 | 1.510 ms | 980 ms | 0 |
| 50 | 16,96 | 26,12 | 2.985 ms | 1.944 ms | 0 |
| 100 | Não medido | 25,77 | Não medido | 4.046 ms | 0 |

p95 é o tempo abaixo do qual ficaram 95% das respostas. O custo de SQL por página caiu de 99 para 17 consultas (82,8%). Na concorrência 50, a vazão subiu aproximadamente 54% e o p95 caiu aproximadamente 35%.

Foi executado ainda um estágio de 60 segundos, com 25 requisições simultâneas e dez republicações do site Rosemary fictício durante a carga. Resultado: 1.570 respostas corretas, zero erros, 25,83 respostas/s, p95 de 1.060 ms e p99 de 1.158 ms. Nenhuma resposta misturou os domínios ou perdeu seções/cards.

Total dos cenários: 3.748 requisições, zero erros. [Resultados numéricos](benchmarks/2026-10-01.json).

### Limites e conclusão

O teste mostra estabilidade nos cenários executados, mas também saturação de um processo: aumentar a concorrência acima de 25 não elevou a vazão de forma significativa e aumentou a espera. Não é correto prometer rapidez ilimitada ou ausência de quedas.

Os números não representam a capacidade da VPS. Gerador, Rails e PostgreSQL estavam na mesma máquina, sem o limite de 1 CPU/1 GiB da stack, sem Traefik, TLS, internet ou competição com os demais serviços do servidor. Não foram medidos download real das imagens, cache frio do Cloudinary, LCP/INP do navegador, uploads em massa nem ataques DDoS. O teste sustentado durou apenas um minuto; não substitui um teste de longa duração em homologação.

## Mudanças aplicadas

1. `PublicContentLoader` carrega seções publicadas, cards, slides, imagens e textos associados em lotes. As consultas deixam de crescer a cada card. A seleção mantém itens visíveis, ordem e separação entre rascunho/publicado.
2. Domínios cadastrados não podem selecionar outro site pelo parâmetro de rota `/s/...`. Domínio desconhecido também não pode usar esse caminho para escolher um site.
3. Login privado e operações administrativas recusam um domínio cadastrado pertencente a outro site, mesmo com a chave privada ou uma sessão autenticada.
4. Solicitação e uso de token de recuperação de senha respeitam o site. O e-mail usa nome e domínio do dono da conta, em vez de apontar todos os clientes para Rosemary.
5. Testes de regressão limitam o crescimento das consultas e conferem que os resumos dos cards não expõem rascunhos.

A publicação continua usando uma transação; a leitura pública mantém uma visão consistente dos dados durante a renderização. Não foram acrescentadas migrações de banco de produção.

## Segurança verificada

A suíte de controllers/modelos passou com 93 testes e 879 assertions. Ela cobre isolamento por domínio e IDs, ausência de cadastro público, bloqueio por senhas erradas, limite por IP, tokens de recuperação, CSRF, uploads inválidos/IDs de outra conta, validação de formulários, XSS e tentativas de SQL injection, além dos fluxos de edição/publicação.

Os testes no navegador passaram com dez testes e 71 assertions, cobrindo carrossel, exclusão de blocos na prévia e troca de idioma. Somando as duas suítes: 103 testes, 950 assertions e nenhuma falha.

Brakeman 8.0.6: zero avisos de segurança e zero erros no relatório. Bundler Audit: nenhuma vulnerabilidade conhecida encontrada; ruby-advisory-db com 1.251 avisos, commit `cb6460a5876f3bf6ef908718457bfa9dd4ca9c06`, atualizado em 29/09/2026. O carregamento Zeitwerk em configuração de produção também passou.

Essa verificação é local e não é um pentest completo da infraestrutura. Persistem os limites descritos na [revisão de segurança](security-review.md): imagens do site são públicas, não há MFA, não há PostgreSQL RLS e o isolamento no banco é feito pela aplicação. Um problema no processo/banco compartilhado pode afetar vários sites.

## Antes de prometer capacidade em produção

1. Medir uma homologação com os mesmos limites de CPU/RAM, PostgreSQL, proxy e arquivos do servidor. Definir um objetivo de tráfego e latência; como referência de avaliação, p95 abaixo de um segundo e taxa de erro próxima de zero.
2. Ativar a entrega das imagens pelo Cloudinary e testar também o primeiro carregamento no navegador. Cache de imagens não remove o custo de renderizar HTML no Rails.
3. Dimensionar processos e réplicas segundo CPU, memória e conexões disponíveis. A stack atual continua com um processo, uma réplica, limite de 1 CPU/1 GiB para web, atualização `stop-first` e volume local no node indicado. Não foi alterada automaticamente.
4. Antes de distribuir réplicas entre nodes, compartilhar os contadores de rate limit por Redis e concluir a migração do armazenamento local. Todos os nodes precisam da mesma imagem e dos secrets corretos. Duas réplicas no mesmo node não protegem contra a queda desse node.
5. Medir lentidão, respostas 5xx, CPU, memória, conexões PostgreSQL e disponibilidade; testar restauração de backup. Proteção contra tráfego abusivo deve existir também no proxy/provedor. Não ativar cache indiscriminado de páginas do CMS ou de HTML que depende do idioma/cookie.

Aumentar apenas `RAILS_MAX_THREADS` não resolve renderização limitada por CPU no Ruby MRI. Consulte o [guia oficial de desempenho Rails](https://guides.rubyonrails.org/tuning_performance_for_deployment.html) e as [orientações de cache compartilhado do Rack::Attack](https://github.com/rack/rack-attack).

## Como reproduzir localmente

Na pasta do projeto, sem `DATABASE_URL` definido, prepare apenas o banco de carga. O comando de schema abaixo é somente para o banco dedicado vazio; não deve ser executado com `RAILS_ENV=production` ou `development`.

```sh
RAILS_ENV=performance bin/rails db:create db:schema:load
bin/rails runner -e performance script/performance/seed.rb
bin/rails runner -e performance script/performance/profile.rb
bin/rails server -e performance -b 127.0.0.1 -p 3101 --pid tmp/pids/performance.pid
```

Se o banco fictício já estiver preparado, reutilize-o e inicie apenas o servidor. Em outro terminal:

```sh
DURATION=10 CONCURRENCY=1,10,25,50,100 ruby script/performance/load.rb tmp/performance/after.json
```

Para repetir o cenário de publicação, inicie a carga abaixo e execute o segundo comando em outro terminal enquanto ela estiver em andamento:

```sh
DURATION=60 CONCURRENCY=25 ruby script/performance/load.rb tmp/performance/publication.json
bin/rails runner -e performance script/performance/publish.rb
```

O gerador só conecta a loopback, aceita no máximo 100 conexões simultâneas e 60 segundos por estágio. Encerre o servidor temporário com Ctrl+C ao terminar. O banco e o storage fictícios ficam separados para reutilização. A configuração de produção não foi flexibilizada para permitir esses testes.
