Aplique a identidade visual oficial da GL Sports em todo o site. Ela substitui qualquer cor, fonte ou estilo anterior. Não mude nada que já funciona (catálogo, categorias, WhatsApp). O site não tem provador 3D: não adicione nenhum; mude só o visual e os textos de marca indicados abaixo.

## 1. Logo

- Logo oficial (PNG com fundo transparente, feito para fundo escuro):
  `https://cdn.jsdelivr.net/gh/ferribrokers-eng/claude@371be0c/gl-sports/marca/logo-gl-sports.png`
- Use no cabeçalho (altura de 44 a 56 px), no hero da home (grande, com um brilho suave verde e azul atrás), no rodapé e como favicon.
- Nunca coloque o logo sobre fundo claro.

## 2. Cores (tokens em `config.ts` e no Tailwind)

O site é **sempre escuro**, como o portfólio da marca. Remova o modo claro.

| Token | Cor | Uso |
|---|---|---|
| `preto` | `#0A0B0D` | Fundo do site |
| `grafite` | `#14161A` | Cards, cabeçalho, gavetas e menus |
| `grafite-2` | `#1D2026` | Bordas, hover dos cards, campos |
| `verde` | `#58E707` | **Cor principal**: botões de comprar, preços, destaques, palavra final dos títulos |
| `azul` | `#026FF6` | Cor secundária: links e botões secundários |
| `laranja` | `#FC6602` | Cor de destaque: selos "Novo" e "Mais vendido", detalhes |
| `ciano` | `#10C6EE` | Só brilhos e realces (glow), nunca em texto |
| `branco` | `#FFFFFF` | Títulos |
| `texto-2` | `#A7ADB5` | Textos secundários |

- Botão principal: fundo verde `#58E707`, texto preto `#0A0B0D` em negrito e caixa alta. No hover, aparece um brilho verde (`box-shadow: 0 0 24px #58E70766`).
- Botão secundário: contorno azul `#026FF6` e texto branco.
- Botão do WhatsApp: verde, com o ícone do WhatsApp.

## 3. Assinatura visual da marca

- **Faixa tricolor:** uma linha fina com gradiente verde → azul → laranja (`linear-gradient(90deg, #58E707, #026FF6, #FC6602)`), 3 a 4 px de altura e cerca de 120 px de largura, embaixo dos títulos de seção, no topo do rodapé e na borda inferior do cabeçalho.
- **Pinceladas de tinta:** no hero e nos banners, faixas diagonais com textura de pincel/respingo nas cores verde, azul e laranja, como na camisa do portfólio. Faça com SVG ou CSS, sem imagens externas.
- **Arcos do logo:** um arco duplo verde e azul, com brilho, como elemento decorativo atrás do logo no hero e atrás da imagem principal na página do produto.
- Fundo com textura sutil de grafite (ruído leve) e vinheta escura nas bordas.

## 4. Tipografia (Google Fonts)

- **Títulos:** "Barlow Condensed" 800, *itálico*, CAIXA ALTA, espaçamento justo. A última palavra ou frase dos títulos principais em verde. Exemplo: "TUDO PARA QUEM VIVE **O ESPORTE.**"
- **Rótulos e menus:** "Barlow" 500, caixa alta, com espaçamento largo entre letras (`letter-spacing: 0.25em`), como "PRODUTOS · SERVIÇOS · SOLUÇÕES".
- **Texto:** "Barlow" 400.
- **Frases de efeito:** "Kaushan Script" em verde, só nos slogans manuscritos (ex.: "Esportes movem pessoas.").

## 5. Home: novo hero e seções de marca

1. **Hero** (fundo preto com pinceladas coloridas e o logo grande):
   - rótulo pequeno: `DISCIPLINA · RESPEITO · EVOLUÇÃO`
   - título: **TUDO PARA QUEM VIVE O ESPORTE.** ("O ESPORTE." em verde)
   - subtítulo: "Camisetas e uniformes personalizados para times, escolas, eventos e empresas. Sede em Peruíbe/SP. Atendemos todo o Brasil."
   - botões: **"Ver estampas"** (verde) e **"Falar no WhatsApp"** (contorno azul)
   - ao lado, no desktop, uma montagem com 3 estampas em destaque do catálogo, levemente inclinadas, com as pinceladas coloridas atrás
2. **Nossas soluções**, em cards escuros com ícone e faixa tricolor no topo de cada card:
   Uniformes personalizados · Materiais esportivos · Manutenção de quadras · Assessoria esportiva · Eventos
3. **Por que a GL Sports**, com 4 ícones em linha (em verde):
   Qualidade em cada detalhe · Parceria de verdade · Atendimento personalizado · Soluções completas
4. **Faixa de slogan** em largura total: "Esportes movem pessoas." em Kaushan Script verde e, ao lado, "TRANSFORMANDO IDEIAS EM CONQUISTAS" em Barlow Condensed itálico branco.
5. Depois, as seções que já existem (grupos de categorias, carrosséis, como funciona etc.), aplicando as novas cores.

## 6. Cards, categorias e páginas

- Cards de produto: fundo `grafite`, borda `grafite-2`, cantos de 14 px. No hover, a borda fica verde com um leve brilho e a imagem dá um zoom suave. O preço fica em verde.
- Cada um dos 8 grupos de categorias recebe uma das cores da marca, alternando verde, azul e laranja, no ícone e na faixa do banner.
- Página do produto: imagem grande com zoom sobre fundo escuro, com um brilho radial azul e verde atrás, e as miniaturas da galeria em pílulas escuras (a selecionada com borda verde).
- Cabeçalho fixo em `grafite` translúcido com desfoque (`backdrop-blur`), logo à esquerda, menu em caixa alta espaçada e busca em destaque.

## 7. Rodapé

- Logo e o slogan "Mais que um esporte, um estilo de vida".
- Instagram: **@glsportscamisetas** (`https://instagram.com/glsportscamisetas`).
- "Peruíbe/SP · Atendemos todo o Brasil", com o endereço, o WhatsApp (13) 99701-1514 e "5,0 no Google".
- Na última linha: `GL SPORTS · DESDE 2015`.

## 8. Qualidade

- Contraste: texto branco ou cinza-claro sobre o fundo escuro. Verde e laranja não são usados em textos longos.
- Respeite `prefers-reduced-motion` (sem animação das pinceladas e do brilho).
- Confira no celular: hero legível, botões grandes e o logo sem cortes.
