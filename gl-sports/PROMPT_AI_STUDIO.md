# Prompt para o Google AI Studio — Site GL Sports

> Como usar: abra https://aistudio.google.com, entre em **Build**, cole TODO o texto abaixo da linha e envie.
> Depois de gerado, peça ajustes em mensagens curtas (ex.: "deixe o banner da home mais escuro").

---

Crie um site de e-commerce completo, moderno e muito intuitivo chamado **GL Sports**, em **português do Brasil**, usando React + TypeScript + Tailwind CSS. O site vende **artes digitais de estampas para camisetas** (arquivos para sublimação/estamparia), organizadas por categoria. Ele substitui uma loja antiga e defasada; o objetivo é parecer uma marca esportiva premium (referências de estilo: Nike.com, Adidas.com, Netshoes), com navegação rápida, visual limpo e foco total nas estampas.

## 1. Fonte de dados (obrigatório usar)

Todo o catálogo já existe em um JSON público. Carregue-o com `fetch` ao abrir o site (e guarde em cache em memória):

```
https://cdn.jsdelivr.net/gh/ferribrokers-eng/claude@24377ec/gl-sports/catalogo.json
```

Estrutura do JSON:

```json
{
  "loja": "GL Sports",
  "total_produtos": 2262,
  "grupos": [
    { "nome": "Esportes", "categorias": [ { "nome": "Futebol", "slug": "futebol", "total": 475 } ] }
  ],
  "produtos": [
    {
      "id": 123,
      "nome": "Camisa Bayern de Munique",
      "slug": "camisa-bayern-de-munique-2",
      "categoria": "Futebol",
      "grupo": "Esportes",
      "preco": 2.88,
      "tags": [],
      "tipo": "estampa",          // "estampa" = arte de camiseta | "recurso" = mockup/template/molde
      "imagens": ["https://cdn.jsdelivr.net/gh/ferribrokers-eng/claude@.../estampashirt_imagens/Futebol/arte.jpg"],
      "visual3d": { "layout": "molde", "imagem": "...", "pecas": { } }   // ver seção 3
    }
  ]
}
```

Regras sobre os dados:
- `imagens[0]` é a imagem principal; as demais vão para a galeria do produto.
- Vários produtos têm o mesmo nome (ex.: 4× "Camisa Bayern de Munique"). Na listagem, diferencie automaticamente com "Modelo 1", "Modelo 2"… (ordem do `id`).
- Preço em reais: exibir sempre como `R$ 2,88` (formato `pt-BR`, `Intl.NumberFormat`).
- Nunca invente produtos; tudo vem do JSON.

## 2. Nova organização de categorias (mega menu)

As categorias antigas eram uma lista solta. Agora ficam em **8 grupos** (já vêm no JSON em `grupos`), cada um com ícone e cor de destaque:

| Grupo | Categorias |
|---|---|
| ⚽ Esportes | Futebol (475), Ciclismo (128), Pesca (112), Motocross (25), Artes Marciais (16), Torcida (9) |
| 🎓 Escolar & Formatura | Interclasse (270), Jogos Internos (35), Nono Ano (100), Terceirão (100) |
| 🎉 Festas & Datas | Abadás (190), Dia dos Pais (42), Dia das Mães (33), Natal (16), Páscoa (6), Festa Junina (5) |
| 🦸 Cultura Pop | Super Heróis (85), Animes (75), Game (52), Funko Pop (26), Desenho Animado (18), Filmes e Séries (15), Música (7) |
| 🔥 Estilo & Lifestyle | Quebrada (124), Original Style (26), Divertidas (17), Agro (11) |
| ✝️ Fé | Religião (73), Católica (5) |
| 🧸 Infantil | Infantil (25) |
| 🛠️ Para Estampadores | Mockups (108), Templates (25), Moldes (8) |

- **Desktop:** mega menu ao passar o mouse em "Categorias", mostrando os 8 grupos em colunas, cada categoria com a contagem de produtos e uma miniatura.
- **Celular:** menu em gaveta (drawer) com grupos em acordeão.
- Cada grupo tem sua página (`/grupo/esportes`) com um banner e chips para filtrar pelas categorias do grupo.
- Cada categoria tem sua página (`/categoria/futebol`).

## 3. Provador 3D — recurso principal

Na página de cada estampa o cliente vê **um manequim 3D vestindo a camisa** e gira com o dedo/mouse para ver **frente, costas e mangas**. **Não use IA de imagem**: o 3D é montado no navegador, em tempo real, a partir da própria arte (custo zero por produto e por visitante).

Use **three.js** com **@react-three/fiber** e **@react-three/drei** (`OrbitControls`). Um protótipo funcional, que deve ser reproduzido fielmente como componente React `Provador3D`, está em:
`https://cdn.jsdelivr.net/gh/ferribrokers-eng/claude@24377ec/gl-sports/prototipo-3d/provador.html`

### Dados do 3D (já vêm no catálogo)

Cada produto tem `visual3d`:

```json
"visual3d": {
  "layout": "molde",                 // molde | so_frente | kit | foto | recurso
  "imagem": "https://cdn.jsdelivr.net/gh/.../Futebol/arte.jpg",   // arte usada no 3D
  "pecas": {                          // [x, y, largura, altura] em fração (0–1) da imagem
    "frente":   [0.031, 0.063, 0.457, 0.633],
    "costas":   [0.516, 0.055, 0.453, 0.648],
    "manga_esq":[0.051, 0.727, 0.418, 0.223],
    "manga_dir":[0.535, 0.727, 0.414, 0.223]
  },
  "aprox": true                       // opcional: posição estimada (camisa clara)
}
```

| layout | Quantidade | O que mostrar |
|---|---|---|
| `molde` | 1.488 | 3D completo: frente, costas e 2 mangas (a arte é o molde plano da camisa) |
| `so_frente` | 271 | 3D com a frente estampada; costas lisas na cor da camisa |
| `kit` | 17 | Dois manequins lado a lado (ex.: "Tal Mãe / Tal Filha"); o segundo menor (escala 0,8); peças `frente` e `frente_2` |
| `foto` | 345 | Sem 3D: a arte já é uma foto pronta. Mostrar a imagem 2D com zoom |
| `recurso` | 141 | Mockups/Templates/Moldes: sem 3D, só a imagem |

### Como montar (mesmo método do protótipo)

1. **Recorte das peças:** carregue `visual3d.imagem` (com `crossOrigin = "anonymous"`) num `<canvas>`, recorte cada caixa de `pecas` com 1,2% de margem e **remova o fundo** por *flood fill* a partir das bordas do recorte. É fundo o pixel com brilho máximo entre 140 e 247 e saturação (máx − mín) < 34 (papel texturizado e sombra), ou laranja (`r>195, 100<g<200, b<160, r−b>60`; faixa decorativa das artes `so_frente`/`kit`). Esses pixels ficam com alfa 0. Cada recorte vira uma `CanvasTexture` (sRGB) em `MeshStandardMaterial` com `alphaTest: 0.5`, `side: DoubleSide`, `roughness: 0.82`.
2. **Tronco:** frente e costas são duas superfícies curvas (meia elipse cada, 48×40 segmentos) com raios `rx = 0.34`, `rz = 0.21`. A largura da frente vira meia volta do tronco: `escala = meioPerimetro / larguraDaFrente` e `alturaDoTronco = alturaDaFrente × escala`. Perto do topo (v > 0,8) os raios fecham (rx −36%, rz −72%) para formar os ombros. As costas usam ângulos de π/2 a 3π/2, para a arte das costas ficar no sentido certo quando vista por trás.
3. **Mangas:** cada manga é um tubo (circunferência = largura da peça × escala, comprimento = altura × escala) preso no ombro e inclinado para fora (0,32 rad; 0,12 rad para manga longa, comprimento > 0,6). O centro da arte da manga fica para fora.
4. **`so_frente` e `kit`:** as costas usam a silhueta da frente espelhada, pintada com a cor média da barra da camisa.
5. **Manequim de loja** cinza-claro fosco por baixo: tronco, pescoço, cabeça oval, braços (cápsulas), quadril e haste com base metálica.
6. **Câmera e controles:** perspectiva 32°, `OrbitControls` com amortecimento, sem *pan*, zoom limitado, ângulo vertical limitado (sem ver por baixo). Gira sozinho devagar (desliga ao tocar e respeita `prefers-reduced-motion`). Botões **Frente**, **Costas** e **Girar**.
7. **Desempenho:** só monte o 3D na página do produto (nunca nos cards da vitrine). Carregue o componente com *lazy loading*, descarte geometrias e texturas ao trocar de produto e mostre "Montando a camisa…" enquanto carrega. Se o WebGL falhar, mostre a arte 2D.
8. Ao lado do 3D, mostre a **arte original** (o arquivo que o cliente compra) e um selo: "3D completo", "3D · frente", "Kit 3D" ou "Foto 2D".

Na vitrine (cards), use a arte 2D normal. Opcional: ao passar o mouse, um ícone "Ver em 3D".

## 4. Páginas

1. **Home**
   - Hero em tela cheia com carrossel de 3 banners (Esportes, Escolar & Formatura, Festas & Datas), título forte, subtítulo e CTA "Ver estampas".
   - Barra de benefícios: "Download imediato", "Arte em alta resolução", "+2.200 estampas", "Atendimento no WhatsApp".
   - Grade com os 8 grupos (cards grandes com imagem, nome e total de estampas).
   - Carrosséis: "Mais procuradas" (Futebol), "Para a sua turma" (Interclasse/Terceirão), "Carnaval" (Abadás), "Cultura Pop".
   - Seção "Como funciona" em 3 passos: Escolha → Pague → Baixe e estampe.
   - Depoimentos (placeholders editáveis), FAQ curto e newsletter.
2. **Grupo / Categoria** — banner, contagem, chips de subcategoria, filtros (grupo, categoria, faixa de preço), ordenação (relevância, A–Z, mais novos = maior `id`), grade responsiva com **scroll infinito** (carregar 24 por vez) e skeletons.
3. **Produto** — **Provador 3D** (seção 3) em destaque, com a arte original e a galeria de imagens ao lado; nome, categoria (breadcrumb), preço, botão "Adicionar ao carrinho" e botão "Comprar pelo WhatsApp"; descrição padrão (arquivo digital em alta resolução, pronto para sublimação, entrega por download/WhatsApp); "Você também pode gostar" (mesma categoria).
4. **Busca** — campo sempre visível no topo; resultados instantâneos enquanto digita (sem acento e sem diferenciar maiúsculas: "terceirao" encontra "Terceirão"), com miniaturas no dropdown e página de resultados completa.
5. **Favoritos** — coração em cada card, salvo em `localStorage`.
6. **Carrinho** — gaveta lateral com itens, quantidade, total e botão **"Finalizar pelo WhatsApp"**, que abre `https://wa.me/{NUMERO}` com mensagem pronta listando nome + id de cada estampa e o total. Deixe `{NUMERO}` numa constante de configuração fácil de trocar. (Estruturar o código para depois plugar Pix/Mercado Pago.)
7. **Sobre a GL Sports**, **Como comprar**, **Contato** e **Política de uso das artes**.
8. **404** amigável com busca e atalhos para os grupos.

## 5. Identidade visual

Siga a identidade oficial da GL Sports descrita em `gl-sports/PROMPT_IDENTIDADE_VISUAL.md`: site sempre escuro (`#0A0B0D`), verde-neon `#58E707` como cor principal, azul `#026FF6`, laranja `#FC6602`, faixa tricolor, pinceladas de tinta, títulos em "Barlow Condensed" itálico caixa alta e o logo oficial:
`https://cdn.jsdelivr.net/gh/ferribrokers-eng/claude@371be0c/gl-sports/marca/logo-gl-sports.png`

## 6. Experiência e qualidade

- **Mobile first**: barra de navegação inferior no celular (Início, Categorias, Busca, Favoritos, Carrinho).
- Header fixo que encolhe ao rolar.
- Imagens com `loading="lazy"`, `decoding="async"`, proporção fixa para não "pular" a página e placeholder enquanto carrega.
- Grade virtualizada/paginada para lidar com 2.262 produtos sem travar.
- Acessibilidade: contraste AA, `alt` com o nome do produto, navegação por teclado, foco visível.
- SEO: `<title>` e meta description por página, URLs amigáveis (`/produto/{slug}`), Open Graph com a imagem do produto.
- Rodapé com grupos, links institucionais, redes sociais (placeholders), formas de pagamento e "© GL Sports".
- Código organizado em componentes (`Header`, `MegaMenu`, `ProductCard`, `ProductGrid`, `ModelViewer`, `CartDrawer`, `SearchBar`…), com um arquivo `config.ts` para nome da loja, WhatsApp, cores e URL do catálogo.

## 7. Entrega

Gere o projeto completo e funcional. Ao final, liste: o que foi implementado, onde trocar o número do WhatsApp e como o Provador 3D monta cada tipo de layout.
