Ajuste as imagens dos produtos do site GL Sports: cada estampa deve aparecer **montada** (camisa pronta) e, ao passar o mouse, mostrar o **molde** (peças separadas). Não use IA para gerar imagens. Não mude nada além do que está descrito abaixo.

## 1. Novo catálogo (troque o link atual por este)

`https://cdn.jsdelivr.net/gh/ferribrokers-eng/claude@2bb6da8/gl-sports/catalogo.json`

Cada produto agora tem estes campos novos:

- `capa`: imagem principal do card (a camisa montada, quando existe).
- `capa_hover`: imagem que aparece ao passar o mouse (o molde). Pode ser `null`.
- `imagem_montada`: camisa montada, de frente. Pode ser `null`.
- `imagem_costas`: camisa montada, de costas. Pode ser `null`.
- `imagem_molde`: molde com as peças separadas. Pode ser `null`.
- `visual3d.pecas`: posição de cada peça dentro do molde, no formato `[x, y, largura, altura]`, com valores de 0 a 1.

## 2. Card do produto (vitrine, categorias, busca)

- Mostre `capa`.
- Se `capa_hover` existir: ao passar o mouse (no celular, ao tocar e segurar), troque suavemente para `capa_hover` com um fade de 250 ms, e volte para `capa` ao tirar o mouse.
- Mostre um selinho no canto do card: "Montada" quando a imagem visível é a camisa pronta, e "Molde" quando é o molde.

## 3. Montagem automática para produtos sem foto montada (sem IA)

Cerca de 1.350 produtos (Futebol, Ciclismo, Quebrada, Pesca, Animes etc.) só têm o molde. Para eles, **monte a camisa no navegador** com `<canvas>` 2D, sem IA e sem 3D. Isso vale para produtos com `imagem_montada == null` e `visual3d.layout` igual a `molde`, `so_frente` ou `kit`.

1. Carregue `visual3d.imagem` com `crossOrigin = "anonymous"`.
2. Recorte as peças de `visual3d.pecas` (frente, costas, mangas) com 1,2% de margem.
3. Remova o fundo de cada recorte com *flood fill* a partir das bordas, deixando transparentes:
   - os pixels com brilho máximo entre 140 e 247 e (máx − mín) < 34;
   - os pixels laranja: `r > 195`, `100 < g < 200`, `b < 160` e `r − b > 60`.
4. Monte uma imagem quadrada de 800×800 px, em fundo cinza-claro `#ECEEF0` com uma sombra suave embaixo:
   - **molde:** a costas atrás, à direita e um pouco menor, e a frente na frente, à esquerda. Encaixe cada manga no ombro da sua peça, girada uns 25° para fora, para formar o desenho de uma camiseta com mangas. Gire as duas camisas cerca de 4° em sentidos opostos.
   - **so_frente:** só a frente, centralizada.
   - **kit:** as duas peças (`frente` e `frente_2`) lado a lado, a segunda 15% menor.
5. Use a imagem montada como `capa` do card e o molde original como `capa_hover`.
6. **Desempenho:** monte só quando o card aparecer na tela (`IntersectionObserver`), no máximo 3 ao mesmo tempo. Guarde o resultado em cache (`Map` em memória + IndexedDB, com a chave `id` do produto) para não montar de novo. Enquanto monta, mostre o molde com um skeleton suave por cima. Se der erro, mostre só o molde.
7. Tamanho da peça no card: a camisa montada ocupa uns 80% da altura do quadro, centralizada.

## 4. Página do produto

- Galeria nesta ordem: montada (`imagem_montada` ou a montagem automática), `imagem_costas` (se houver) e `imagem_molde`.
- Embaixo da imagem grande, dois botões em pílula: **"Camisa montada"** e **"Molde (peças)"**, para alternar.
- Mantenha o zoom.

## 5. Conferência

Depois de aplicar, confira e me diga:

- um produto de Interclasse mostra a foto montada e troca para o molde no mouse;
- um produto de Futebol mostra a camisa montada automaticamente e troca para o molde no mouse;
- os Abadás (só têm foto) aparecem normalmente, sem troca;
- o total continua 2.262 produtos.
