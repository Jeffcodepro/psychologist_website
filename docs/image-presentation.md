# Logo, zoom e fotos em relevo

## Área clicável da logo

O link do cabeçalho acompanha o retângulo ocupado pela imagem, respeitando o zoom, a posição e os limites da moldura. O espaço vazio ao lado deixa de levar à página inicial. O ajuste é recalculado no desktop, tablet e celular. Margens transparentes que façam parte do próprio arquivo da logo ainda pertencem à imagem; prefira um arquivo sem margens internas excessivas.

## Diminuir ou exibir a foto inteira

1. Edite a seção e abra **Mídia** (ou abra a imagem do card).
2. Em **Tamanho / zoom**, use de **25% a 300%**. Por exemplo, 70% reduz a imagem.
3. Em **Como encaixar a foto**, escolha **Mostrar a imagem inteira** para preservar as bordas. **Preencher a área** mantém o recorte tradicional.
4. Arraste a imagem ou use as posições horizontal e vertical. Diminuir o zoom não aumenta o card.
5. Confira a prévia, salve o rascunho e publique as páginas desejadas.

O zoom também aceita valores abaixo de 100% na logo, foto profissional, banners, imagens adicionais e ajustes de tablet/celular. O encaixe, os filtros e a sombra são compartilhados entre dispositivos; zoom e posição podem variar por dispositivo.

## Composição semelhante à referência

1. Coloque a imagem do ambiente em **Banner ou imagem de fundo**, com **Onde exibir o banner → Imagem de fundo**. Ajuste sua tonalidade nos controles de overlay.
2. Coloque a foto da pessoa em **Fotografia do conteúdo**. Use **Texto à esquerda**, para a pessoa ficar à direita.
3. Clique em **Aplicar efeito foto recortada**. O editor remove a moldura, mostra a imagem inteira e aplica uma sombra suave.
4. Ajuste **Intensidade do relevo**, tamanho e posição. Zero desliga a sombra.
5. Para eliminar o fundo da própria foto, envie um PNG/WebP com transparência ou use **Remover fundo com IA**.

**Sem moldura** não apaga o fundo de um JPG. O recorte precisa existir no arquivo ou ser processado pela IA. Nesse modo o overlay retangular da fotografia é ocultado, para deixar o fundo da seção aparecer ao redor da pessoa; brilho, contraste e saturação continuam disponíveis. A sombra segue a transparência da imagem. Os cards continuam limitados às suas dimensões.

## Recorte por IA e original

A opção usa a [remoção de fundo do Cloudinary](https://cloudinary.com/documentation/background_removal). A imagem deve estar salva no Cloudinary; depois de um novo upload, salve o rascunho e abra novamente o editor para habilitar o botão. Imagens armazenadas apenas no disco local podem usar arquivos já transparentes.

O processamento gera uma versão derivada, preservando o upload original. Usa créditos de transformação do Cloudinary e depende da disponibilidade na conta. O botão só aplica o recorte ao formulário após carregar a prévia. **Restaurar fundo original** desfaz a seleção; salve para persistir. Se o processamento não ficar disponível, o editor informa o problema e mantém o original. A página pública tenta carregar a derivada e usa o original como alternativa em caso de erro.

Os testes automatizados validam as URLs assinadas, a preservação do original e o fluxo de prévia usando uma imagem local simulada. Eles não acionam IA nem consomem créditos da conta.

## Disponibilizar as mudanças

Estas alterações de código não atualizam a VPS automaticamente. No localhost, reinicie o Rails se necessário e recarregue a página. Em produção, reconstrua a imagem Docker a partir deste commit, usando uma **nova tag**, e atualize as stacks seguindo o procedimento de backup, migração e verificação já documentado em [atualização 1.2.7](update-1.2.7.md). O pacote antigo 1.2.7 não inclui estes ajustes posteriores. Não há migração nova, gem nova ou secret novo neste complemento.
