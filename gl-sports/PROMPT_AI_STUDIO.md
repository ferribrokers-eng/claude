# Prompt para o Google AI Studio — Site GL Sports

> Como usar: abra https://aistudio.google.com, entre em **Build**, cole TODO o texto abaixo da linha e envie.
> Depois de gerado, peça ajustes em mensagens curtas (ex.: "deixe o banner da home mais escuro").

---

Crie um site de e-commerce completo, moderno e muito intuitivo chamado **GL Sports**, em **português do Brasil**, usando React + TypeScript + Tailwind CSS. O site vende **artes digitais de estampas para camisetas** (arquivos para sublimação/estamparia), organizadas por categoria. Ele substitui uma loja antiga e defasada; o objetivo é parecer uma marca esportiva premium (referências de estilo: Nike.com, Adidas.com, Netshoes), com navegação rápida, visual limpo e foco total nas estampas.

## 1. Fonte de dados (obrigatório usar)

Todo o catálogo já existe em um JSON público. Carregue-o com `fetch` ao abrir o site (e guarde em cache em memória):

```
https://cdn.jsdelivr.net/gh/ferribrokers-eng/claude@claude/extract-website-images-ehffq2/gl-sports/catalogo.json
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
      "imagens": ["https://cdn.jsdelivr.net/gh/ferribrokers-eng/claude@.../estampashirt_imagens/Futebol/arte.jpg"]
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

## 3. Pessoa vestindo cada estampa (mockup com IA) — recurso principal

Cada estampa (`tipo === "estampa"`) deve poder ser vista **em uma pessoa real vestindo a camiseta**.

**Regra de custo (obrigatória):** os visitantes **nunca** disparam geração de imagem. As fotos são geradas **uma única vez por produto**, só na área do administrador (abaixo), aprovadas e publicadas como arquivos estáticos. A loja pública apenas exibe essas imagens prontas, e a chave da API do Gemini **não** pode aparecer no código da loja pública.

Na loja pública:
1. A foto do modelo de cada produto fica em `https://cdn.jsdelivr.net/gh/ferribrokers-eng/claude@claude/extract-website-images-ehffq2/gl-sports/modelos/{id}.jpg` (constante `MODELOS_BASE_URL` no `config.ts`).
2. Na página do produto, mostre as abas **"Ver no modelo"** e **"Arte original"**. Se a foto do modelo não existir (erro ao carregar a imagem), esconda a aba e mostre só a arte original, sem mensagem de erro.
3. **Não** existe foto de modelo para `tipo === "recurso"` (Mockups, Templates, Moldes).

Na geração (somente no admin), use o modelo de geração/edição de imagens do Gemini disponível no AI Studio (o mais recente com suporte a imagem de entrada, ex.: "Nano Banana" / Gemini Image) via `@google/genai`, enviando a imagem da estampa (`imagens[0]`, convertida para base64) junto com o prompt abaixo.

Prompt de imagem (montar dinamicamente com a categoria):

```
Fotografia de produto realista, estilo catálogo de e-commerce esportivo premium.
Uma pessoa vestindo uma camiseta com EXATAMENTE a estampa da imagem enviada,
aplicada na frente da camiseta, preservando cores, textos, números e posições da arte,
com caimento natural do tecido, dobras e iluminação realistas.
Contexto da cena: {CENA_DA_CATEGORIA}.
Enquadramento da cintura para cima, pessoa de frente, fundo limpo e levemente desfocado,
luz de estúdio suave, alta nitidez, proporção 4:5.
Pessoa fictícia (não é celebridade), diversidade de gênero, idade e tom de pele adequada ao público.
Sem textos extras, sem marcas d'água, sem logotipos adicionais além dos que já estão na arte.
```

Mapa `{CENA_DA_CATEGORIA}`:
- Futebol / Torcida → torcedor(a) ou atleta em estádio ou campo de futebol
- Ciclismo → ciclista com camisa de ciclismo, estrada ou trilha ao fundo
- Pesca → pescador(a) às margens de um rio ou em um barco, luz natural
- Motocross → piloto em pista de terra, capacete na mão
- Artes Marciais → atleta em academia/tatame
- Interclasse / Jogos Internos / Nono Ano / Terceirão → grupo de estudantes adolescentes sorrindo em quadra ou pátio escolar
- Abadás → folião em bloco de carnaval/micareta, confetes, luz de festa
- Dia dos Pais → pai sorrindo com filho(a) | Dia das Mães → mãe sorrindo com filho(a)
- Natal / Páscoa / Festa Junina → ambiente decorado da data
- Super Heróis / Animes / Game / Funko Pop / Desenho Animado / Filmes e Séries / Música → jovem em ambiente urbano ou quarto gamer, luz neon suave
- Quebrada / Original Style → estilo streetwear, rua urbana, grafite ao fundo
- Divertidas → pessoa rindo, ambiente descontraído | Agro → pessoa em fazenda, chapéu, campo ao pôr do sol
- Religião / Católica → pessoa serena, igreja ou paisagem com luz suave
- Infantil → criança brincando em parque, ambiente alegre e seguro

**Geração em lote (área do administrador):** crie a rota `/admin/modelos` (protegida por uma senha simples em variável de ambiente) com:
- seletor de categoria e botão "Gerar modelos desta categoria";
- fila com no máximo 2 gerações ao mesmo tempo, barra de progresso, pausar/retomar e repetir em caso de erro;
- grade com as imagens geradas, para aprovar, descartar ou "gerar outra" (nova pessoa/pose) em cada uma;
- produtos que já têm foto em `MODELOS_BASE_URL` são pulados, para nunca pagar duas vezes pela mesma estampa;
- botão "Baixar ZIP" com as imagens aprovadas nomeadas como `{id}.jpg` (o dono envia esse ZIP para a pasta `gl-sports/modelos/` do repositório).
Na vitrine, se o produto tiver foto de modelo, o card mostra a **pessoa vestindo** e, ao passar o mouse, troca para a arte original.

## 4. Páginas

1. **Home**
   - Hero em tela cheia com carrossel de 3 banners (Esportes, Escolar & Formatura, Festas & Datas), título forte, subtítulo e CTA "Ver estampas".
   - Barra de benefícios: "Download imediato", "Arte em alta resolução", "+2.200 estampas", "Atendimento no WhatsApp".
   - Grade com os 8 grupos (cards grandes com imagem, nome e total de estampas).
   - Carrosséis: "Mais procuradas" (Futebol), "Para a sua turma" (Interclasse/Terceirão), "Carnaval" (Abadás), "Cultura Pop".
   - Seção "Como funciona" em 3 passos: Escolha → Pague → Baixe e estampe.
   - Depoimentos (placeholders editáveis), FAQ curto e newsletter.
2. **Grupo / Categoria** — banner, contagem, chips de subcategoria, filtros (grupo, categoria, faixa de preço), ordenação (relevância, A–Z, mais novos = maior `id`), grade responsiva com **scroll infinito** (carregar 24 por vez) e skeletons.
3. **Produto** — galeria grande com zoom e abas "Ver no modelo" / "Arte original"; nome, categoria (breadcrumb), preço, botão "Adicionar ao carrinho" e botão "Comprar pelo WhatsApp"; descrição padrão (arquivo digital em alta resolução, pronto para sublimação, entrega por download/WhatsApp); "Você também pode gostar" (mesma categoria).
4. **Busca** — campo sempre visível no topo; resultados instantâneos enquanto digita (sem acento e sem diferenciar maiúsculas: "terceirao" encontra "Terceirão"), com miniaturas no dropdown e página de resultados completa.
5. **Favoritos** — coração em cada card, salvo em `localStorage`.
6. **Carrinho** — gaveta lateral com itens, quantidade, total e botão **"Finalizar pelo WhatsApp"**, que abre `https://wa.me/{NUMERO}` com mensagem pronta listando nome + id de cada estampa e o total. Deixe `{NUMERO}` numa constante de configuração fácil de trocar. (Estruturar o código para depois plugar Pix/Mercado Pago.)
7. **Sobre a GL Sports**, **Como comprar**, **Contato** e **Política de uso das artes**.
8. **404** amigável com busca e atalhos para os grupos.

## 5. Identidade visual

- Nome/logo: **GL Sports** em tipografia esportiva, bold, levemente itálica (ex.: "Barlow Condensed" ou "Oswald" nos títulos, "Inter" no texto).
- Paleta: fundo escuro grafite `#0E0F12`, superfícies `#17191F`, texto claro, **cor de destaque verde-neon `#22E06B`** e secundária azul elétrico `#2F6BFF`. Ter também **modo claro** (alternador no topo) com fundo branco.
- Cards com cantos arredondados (16px), sombra suave, hover com leve zoom na imagem e borda na cor de destaque.
- Microanimações discretas (Framer Motion): entrada dos cards, abertura do carrinho, troca de abas.
- Ícones: lucide-react.

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

Gere o projeto completo e funcional. Ao final, liste: o que foi implementado, onde trocar o número do WhatsApp e a senha do admin, e como gerar os modelos em lote.
