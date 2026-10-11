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

## 3. No card (vitrine, categorias, busca): imagem "montada" gerada pelo 3D

- Use **um único renderizador WebGL escondido**, compartilhado por todo o site. Não crie um canvas 3D por card.
- Para cada card desses produtos, renderize uma imagem quadrada de 600×600 com DUAS camisas lado a lado (frente à esquerda e costas à direita, levemente giradas), no mesmo estilo das fotos montadas da Interclasse, em fundo cinza-claro `#ECEEF0`.
- Transforme o resultado em imagem (`canvas.toBlob` → URL) e use como `capa` do card. Ao passar o mouse, mostre o molde original (`imagem_molde`).
- Desempenho:
  - só renderize quando o card aparecer na tela (`IntersectionObserver`);
  - uma fila de 1 render por vez;
  - guarde o resultado em cache (`Map` em memória + IndexedDB, com a chave `id`) para não montar de novo;
  - enquanto monta, mostre o molde com um skeleton suave por cima;
  - se der erro ou o WebGL não funcionar, mostre o molde.

## 4. Na página do produto: 3D interativo

- Só para esses produtos: a imagem principal vira o `Camisa3D` interativo.
  - O cliente gira com o dedo ou o mouse (OrbitControls sem pan, zoom limitado).
  - A camisa gira sozinha devagar e para quando o cliente toca.
  - Botões **Frente**, **Costas** e **Girar**.
- Embaixo, mostre os botões **"Camisa montada 3D"** e **"Molde (peças)"** para alternar.
- Fundo do palco escuro, com brilho radial verde e azul (cores da marca).
- Monte o 3D só nessa página, com lazy loading. Ao sair da página, descarte a geometria e as texturas.

## 5. Conferência

Me diga:

- se a categoria Futebol mostra as camisas montadas (frente e costas) nos cards e troca para o molde no mouse;
- se, ao abrir um produto de Futebol, a camisa gira em 3D;
- se a Interclasse continua com as fotos montadas originais;
- se a página da categoria continua rápida no celular;
- se o total continua 2.262 produtos.
