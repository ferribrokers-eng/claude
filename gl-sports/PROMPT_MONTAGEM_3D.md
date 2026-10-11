Algumas estampas do site GL Sports só têm o MOLDE (peças separadas). Quero que o site monte essas camisas em 3D automaticamente, igual ao protótipo abaixo, SEM IA de imagem. As estampas que já têm foto montada continuam como estão.

Protótipo de referência (reproduza o mesmo método):
`https://cdn.jsdelivr.net/gh/ferribrokers-eng/claude@24377ec/gl-sports/prototipo-3d/provador.html`

Catálogo atualizado (use este link):
`https://cdn.jsdelivr.net/gh/ferribrokers-eng/claude@2bb6da8/gl-sports/catalogo.json`

## 1. Quais produtos recebem a montagem 3D

Só os que têm `imagem_montada == null` e `visual3d.layout` igual a `molde`, `so_frente` ou `kit`. São 1.326 produtos (Futebol, Ciclismo, Quebrada, Pesca, Super Heróis, Animes etc.).

Os outros produtos ficam como estão:

- com foto montada (Interclasse, Nono Ano, Terceirão…): mostram a foto e, no mouse, o molde;
- só com foto (Abadás, Mockups): sem troca.

## 2. Componente `Camisa3D` (three.js, sem IA)

1. Carregue `visual3d.imagem` com `crossOrigin = "anonymous"`.
2. Recorte cada peça de `visual3d.pecas` (`[x, y, largura, altura]` em fração de 0 a 1, com 1,2% de margem).
3. Remova o fundo de cada recorte com flood fill a partir das bordas, deixando transparentes:
   - papel e sombra: brilho máximo entre 140 e 247 e (máx − mín) < 34;
   - laranja: r > 195, 100 < g < 200, b < 160 e r − b > 60.
4. Monte a camisa como no protótipo:
   - frente e costas viram duas superfícies curvas (meia elipse, rx = 0.34 e rz = 0.21), com os ombros fechando no topo;
   - as mangas são tubos inclinados para fora;
   - `so_frente`: as costas ficam lisas, na cor da camisa;
   - `kit`: duas camisas, sendo a segunda menor.
5. **Sem manequim:** mostre só a camisa, como uma camiseta pronta flutuando.
6. Material `MeshStandardMaterial` com `alphaTest: 0.5`, luz suave de estúdio e uma sombra leve no chão.

## 3. No card (vitrine, categorias, busca): as duas versões no mesmo card

- **A foto que já está no card continua sendo a principal.** Não troque nem remova: o molde (peças separadas) aparece primeiro, como hoje.
- No canto do card, coloque um botão em pílula **"Ver em 3D"**, com ícone de cubo, em verde.
  - Ao clicar (ou ao passar o mouse, no computador), o próprio card troca para a **camisa montada em 3D**, com fade de 250 ms.
  - O botão vira **"Ver molde"** para voltar à foto original.
- **Dentro do card, o 3D é interativo:**
  - a camisa gira sozinha devagar;
  - o cliente arrasta com o dedo ou o mouse para ver frente e costas;
  - não precisa abrir a página do produto.
- Embaixo da imagem do card, coloque dois pontinhos indicadores: **Molde** e **3D**.
- Desempenho (importante, pois são muitos cards):
  - use **um único renderizador WebGL compartilhado**: só **um card por vez** fica com o 3D interativo ativo;
  - quando o cliente abre o 3D em outro card, o anterior vira uma imagem parada (*snapshot* da última posição);
  - só monte o 3D quando o cliente pedir (clique ou mouse), nunca de forma automática na lista;
  - guarde as peças recortadas em cache (`Map` com a chave `id`) para reabrir rápido;
  - se o WebGL falhar, o botão "Ver em 3D" some e o card fica só com a foto original.

## 4. Na página do produto: 3D interativo

- Só para esses produtos: a galeria mostra a foto original (molde) primeiro e, ao lado, o `Camisa3D` interativo.
  - O cliente gira com o dedo ou o mouse (OrbitControls sem pan, zoom limitado).
  - A camisa gira sozinha devagar e para quando o cliente toca.
  - Botões **Frente**, **Costas** e **Girar**.
- Embaixo, mostre os botões **"Camisa montada 3D"** e **"Molde (peças)"** para alternar.
- Fundo do palco escuro, com brilho radial verde e azul (cores da marca).
- Nesta página, monte o 3D com lazy loading. Ao sair da página, descarte a geometria e as texturas.

## 5. Conferência

Me diga:

- se os cards de Futebol continuam com a foto original e o botão "Ver em 3D" mostra a camisa montada girando dentro do próprio card;
- se, ao abrir um produto de Futebol, a camisa gira em 3D;
- se a Interclasse continua com as fotos montadas originais;
- se a página da categoria continua rápida no celular;
- se o total continua 2.262 produtos.
