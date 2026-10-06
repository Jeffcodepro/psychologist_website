# SEO e indexação de rosemarydias.com

## O que já foi conferido

Leitura pública, sem login, em 01/10/2026:

- Home, `robots.txt` e `sitemap.xml`: HTTP 200.
- Título da home: `Rosemary Dias | Psicologia e Desenvolvimento Humano`.
- Descrição presente, canonical `https://rosemarydias.com/` e meta robots permitindo indexação.
- Sitemap com Home, Psicoterapia, Desenvolvimento Humano, Sobre, Conteúdos e Contato. O admin está bloqueado no robots e usa cabeçalho `noindex`.

Isso confirma a configuração técnica observada, não a inclusão no índice nem uma posição nas buscas. O Google não garante primeira posição ou indexação. [Como a busca funciona](https://developers.google.com/search/docs/fundamentals/how-search-works).

## 1. Nome e conteúdo no CMS

Use o mesmo nome profissional no título, na apresentação, na página Sobre e nos perfis oficiais. Se a profissional utiliza um nome completo diferente de “Rosemary Dias”, preencha o nome real consistentemente; não invente localidade, especialização ou credencial.

Exemplos para revisar e adaptar:

| Página | Título SEO | Descrição SEO |
| --- | --- | --- |
| Home | Rosemary Dias — Psicologia e psicoterapia | Conheça o trabalho de Rosemary Dias em psicologia, psicoterapia e desenvolvimento humano. Saiba mais sobre a abordagem e entre em contato. |
| Psicoterapia | Psicoterapia — Rosemary Dias | Entenda como funciona a psicoterapia com Rosemary Dias, conheça a abordagem e consulte as modalidades e a disponibilidade de atendimento. |
| Sobre | Sobre Rosemary Dias — Trajetória e formação | Conheça a trajetória, a formação e os valores que orientam o trabalho de Rosemary Dias em psicologia e desenvolvimento humano. |
| Artigo | Tema específico do artigo — Rosemary Dias | Resuma em uma ou duas frases a questão que o artigo aborda e o que a pessoa encontrará ao ler. |

As sugestões do CMS são pontos de partida. Use títulos e descrições próprios para cada página; não repita listas de palavras. O campo de palavras-chave não determina posição no Google. [Orientações sobre títulos](https://developers.google.com/search/docs/appearance/title-link), [meta tags aceitas](https://developers.google.com/search/docs/crawling-indexing/special-tags).

O SEO da página tem prioridade sobre o SEO geral quando preenchido. Para mudar a home já configurada, edite **Páginas → Home → Configurar página → SEO** também. O exemplo mostrado no editor é ilustrativo: o Google pode apresentar outro título ou trecho.

## 2. Search Console e Cloudflare

1. Acesse [Google Search Console](https://search.google.com/search-console) com a conta que administrará o site.
2. Adicione a propriedade do tipo **Domínio**: `rosemarydias.com` (sem `https://`).
3. Copie o registro TXT de verificação fornecido pelo Google. No Cloudflare, selecione a zona `rosemarydias.com` → DNS → Add record → TXT. Use o nome `@` e o conteúdo exato fornecido.
4. Salve e volte ao Search Console para verificar. Mantenha o TXT; não altere os registros A/CNAME que já fazem o site funcionar.
5. Em **Sitemaps**, envie `https://rosemarydias.com/sitemap.xml`.
6. Em **Inspeção de URL**, informe `https://rosemarydias.com/`, execute **Testar URL publicada** e, quando disponível, **Solicitar indexação**. Repita para Sobre e as páginas principais.
7. Acompanhe **Indexação → Páginas** e **Desempenho**. Se houver falha, use o motivo específico exibido nesses relatórios. Repetir pedidos não acelera o processo.

O rastreamento pode levar dias ou semanas; o sitemap facilita a descoberta, mas não garante posição. [Solicitar nova leitura de URLs](https://developers.google.com/search/docs/crawling-indexing/ask-google-to-recrawl).

## 3. Depois da indexação

Mantenha textos autorais úteis, dados profissionais completos e links de perfis oficiais apontando ao domínio. Atualize o site quando houver conteúdo relevante. Não compre backlinks ou repita artificialmente o nome da profissional. Acompanhe as consultas pelo nome no Search Console; uma pesquisa isolada no próprio navegador não representa todas as pessoas.

Português e inglês continuam no mesmo endereço, conforme a escolha feita para o projeto. A preferência fica no navegador; visitantes e robôs sem preferência recebem português. Não há URL inglesa separada para indexação nesta configuração.
