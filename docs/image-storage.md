# Imagens e armazenamento no Cloudinary

## Quando ocorre um upload

| Ação | Comportamento |
| --- | --- |
| Salvar título, texto, zoom, posição, overlay ou sombra | Mantém o original; nenhum upload de imagem. |
| Aprovar/publicar uma ou várias páginas, inclusive várias vezes | Reaproveita o mesmo blob e a mesma chave do original; cria apenas vínculos no banco. |
| Selecionar novamente um arquivo idêntico já vinculado ao mesmo site | Confere conteúdo, tamanho, tipo e serviço e reaproveita o original. O nome do arquivo pode ser diferente. |
| Enviar a mesma imagem para várias posições no mesmo formulário | Compartilha um único original; os recortes continuam independentes. |
| Enviar um arquivo com conteúdo diferente | Cria um novo original. O anterior permanece enquanto uma página publicada ou outro campo ainda o utiliza. |
| Remover uma imagem do rascunho | Solicita descarte em segundo plano. Só há exclusão do original quando nenhum vínculo permanece, inclusive na publicação. |

O reaproveitamento não cruza sites nem serviços de armazenamento. Requisições simultâneas de upload são coordenadas por site até terminar o envio, evitando duas cópias do mesmo arquivo inédito. Arquivos inválidos não são enviados. Antes de reutilizar um arquivo já salvo, há uma consulta de existência no armazenamento; isso permite recuperar uma tentativa anterior de upload interrompida. A consulta não reenvia a imagem.

O descarte usa os jobs do Active Storage. Falhas ou reinícios do processo podem deixar pendências de limpeza, por isso existe a auditoria abaixo. Trocas de posição entre seções apenas transferem os vínculos.

## Versões otimizadas e recortes

O original pode ter versões derivadas em tamanhos/formatos diferentes e uma versão sem fundo. Elas são geradas para exibição e ocupam armazenamento, mas não correspondem a um novo upload do original a cada salvamento. As mesmas URLs reutilizam versões já geradas e cacheadas. Consulte a [documentação de transformações e cache do Cloudinary](https://cloudinary.com/documentation/eager_and_incoming_transformations).

Zoom, posição, sombra e overlay são aplicados por CSS. Não geram um arquivo para cada mudança desses controles.

## Auditar os dados existentes, sem apagar arquivos

Após atualizar a aplicação com esta correção, no worker que executa `psychologist-app_web`:

```bash
APP_CONTAINER=$(docker ps -q \
  --filter label=com.docker.swarm.service.name=psychologist-app_web \
  --filter status=running)

docker exec "$APP_CONTAINER" \
  /rails/bin/docker-entrypoint bin/rails media:audit
```

Para consultar apenas um site, acrescente `-e TENANT_SLUG=rosemary` antes de `"$APP_CONTAINER"` (use o slug real do site).

O relatório informa originais vinculados por site, grupos com conteúdo repetido e arquivos sem vínculos no banco criados há mais de 48 horas. Esta última contagem é global. Não acessa a API, não envia, não modifica e não exclui arquivos.

O relatório usa o banco da aplicação. Não inclui o inventário de derivados do Cloudinary nem arquivos enviados manualmente ou por outras aplicações. Cópias históricas permanecem para revisão; esta correção evita novas duplicações e corrige o descarte das próximas remoções, sem realizar uma limpeza retroativa em produção.

Não há migração, gem ou secret novo. É necessário reconstruir a imagem Docker com uma nova tag e atualizar a aplicação para que o código passe a valer em produção.
