# Limpeza verificada

A revisão considerou `app`, `config`, `db`, `lib`, `test`, `bin`, `public`, assets, dependências e arquivos de implantação. Arquivos de infraestrutura não foram considerados inúteis apenas por não terem chamadas explícitas: Rails carrega vários deles por convenção.

Removidos nesta revisão:

- `app/views/contacts/show.html.erb` e `app/views/shared/_contact_section.html.erb`: o contato agora usa a página e os blocos do CMS, renderizados por `pages/home`.
- `app/views/devise/shared/_links.html.erb`: nenhuma view o chamava; continha links genéricos de cadastro e login incompatíveis com a entrada privada.
- Dez arquivos de testes gerados contendo somente testes comentados. Os testes efetivos de comportamento e segurança foram preservados/ampliados.
- A dependência `jbuilder`: nenhuma resposta/template JSON usa esse construtor; os controllers usam `render json:`.
- Métodos de carregamento duplicados em `PagesController`: agora centralizados em `PublicController` com escopo por cliente.

Preservados: migrações/histórico do banco, seeds, uploads existentes, ícones públicos convencionais, arquivos de configuração do Rails, geradores e CSS compartilhado cujo uso dinâmico impede afirmar remoção segura. Nenhum conteúdo de produção ou arquivo de mídia foi removido por esta limpeza.
