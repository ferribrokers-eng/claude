Corrija o site GL Sports com as alterações abaixo. Faça todas, sem pular nenhuma.

## 1. Carregar o catálogo inteiro (hoje aparecem poucas imagens)

- Apague todos os produtos de exemplo, mocks ou listas fixas no código. Os produtos vêm **somente** deste JSON:
  `https://cdn.jsdelivr.net/gh/ferribrokers-eng/claude@24377ec/gl-sports/catalogo.json`
- Se esse link falhar, tente este, com a mesma estrutura:
  `https://raw.githubusercontent.com/ferribrokers-eng/claude/aa5ff1e/gl-sports/catalogo.json`
- O JSON tem **2.262 produtos** em `produtos` e **3.043 imagens** no total (`imagens` de cada produto). Use todos, sem limitar, cortar ou filtrar.
- Enquanto carrega, mostre skeletons. Se os dois links falharem, mostre o aviso "Não foi possível carregar o catálogo" com o botão "Tentar de novo". Nunca troque por dados inventados.
- No rodapé, mostre o total carregado ("2.262 estampas"). Assim dá para ver na hora se veio tudo.

## 2. Tudo dividido por categoria

- Use os grupos e categorias que vêm em `grupos` no JSON: 8 grupos e 33 categorias, cada um com o total de produtos.
- Cada categoria tem a sua página (`/categoria/{slug}`), com **todos** os produtos daquela categoria. O número de produtos na página tem que bater com o `total` do JSON (ex.: Futebol 475, Interclasse 270, Abadás 190).
- Cada grupo tem a sua página (`/grupo/{nome}`), com chips para filtrar as categorias do grupo.
- Na home, mostre os 8 grupos e, para cada categoria, um carrossel com as primeiras estampas e o botão "Ver todas (N)".
- Grade com **scroll infinito**: carregue 24 por vez até mostrar todos. Imagens com `loading="lazy"` e proporção 1:1 fixa.
- A busca procura nos 2.262 produtos, sem diferenciar acento nem maiúsculas.
- Produto com mais de uma imagem: na página do produto, mostre todas na galeria.

## 3. Nenhuma imagem é gerada

- Remova todo o código de geração de imagem com IA: Gemini, `@google/genai`, chave de API, rota `/admin/modelos`, botões "Gerar modelo" e cache de imagens geradas.
- O site só exibe as imagens que já estão no JSON. O visitante nunca gera nada.

## 4. Provador 3D em todas as estampas

Na página de **cada** produto, use `produto.visual3d`, que já vem no JSON:

- `layout: "molde"` (1.488 produtos): manequim 3D com frente, costas e as duas mangas.
- `layout: "so_frente"` (271): manequim 3D com a frente estampada e as costas lisas na cor da camisa.
- `layout: "kit"` (17): dois manequins lado a lado (o segundo menor).
- `layout: "foto"` (345) e `"recurso"` (141): sem 3D; mostre a imagem com zoom e o selo "Foto do produto".

Reproduza **exatamente** o método do protótipo funcional, em um componente React `Provador3D` com three.js:
`https://cdn.jsdelivr.net/gh/ferribrokers-eng/claude@24377ec/gl-sports/prototipo-3d/provador.html`

1. Carregue `visual3d.imagem` com `crossOrigin = "anonymous"` e recorte cada caixa de `visual3d.pecas`. Cada caixa é `[x, y, largura, altura]` em fração de 0 a 1 da imagem; use 1,2% de margem.
2. Remova o fundo de cada recorte com *flood fill* a partir das bordas, deixando transparente (alfa 0):
   - papel e sombra: brilho máximo entre 140 e 247 e (máx − mín) < 34;
   - laranja: `r > 195`, `100 < g < 200`, `b < 160` e `r − b > 60`.
3. Monte o tronco com duas superfícies curvas (meia elipse cada: `rx = 0.34`, `rz = 0.21`, 48×40 segmentos) e os ombros fechando no topo. Cada manga é um tubo inclinado para fora. Por baixo, um manequim de loja cinza com haste e base.
4. Use `OrbitControls` sem *pan* e com zoom limitado. Gire sozinho devagar e pare quando o cliente tocar na tela. Mostre os botões **Frente**, **Costas** e **Girar**.
5. Monte o 3D só na página do produto (nunca nos cards), com *lazy loading*. Ao trocar de produto, descarte a geometria e as texturas. Se o WebGL falhar, mostre a imagem 2D.
6. Ao lado do 3D, mostre a "Arte original" (`imagens[0]`) e o selo: "3D completo", "3D · frente", "Kit 3D" ou "Foto do produto".
7. Nos cards da vitrine, mostre o selo "3D" nos produtos com `layout` `molde`, `so_frente` ou `kit`. Inclua também um filtro "Só com provador 3D".

## 5. Conferência final

Antes de terminar, confira e me diga o resultado de cada item:
- total de produtos carregados: 2.262;
- quantidade por categoria igual ao `total` do JSON;
- nenhum produto de exemplo e nenhuma chamada a IA no código;
- o provador 3D abre em um produto de Futebol (`molde`), em um de Animes (`so_frente`) e no kit "Ctrl C Ctrl V Mãe e Filha" (`kit`).
