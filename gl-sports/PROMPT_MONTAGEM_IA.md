Quero que TODOS os produtos do site GL Sports tenham uma foto da camisa montada no mesmo estilo das fotos que já existem na Interclasse (frente e costas, realista, com dobras, sombras e fundo). As fotos serão geradas UMA ÚNICA VEZ por mim, numa área de administrador. Os clientes nunca geram imagem.

## 1. Quais produtos precisam de foto montada

No catálogo (`https://cdn.jsdelivr.net/gh/ferribrokers-eng/claude@2bb6da8/gl-sports/catalogo.json`), são os produtos com `imagem_montada == null` e `visual3d.layout` igual a `molde`, `so_frente` ou `kit`. São 1.326 produtos: Futebol 409, Ciclismo 124, Quebrada 122, Pesca 94, Super Heróis 82, Animes 73 e outros.

## 2. Área do administrador: `/admin/montagem`

- Proteja com senha (variável de ambiente `ADMIN_SENHA`).
- Deixe fora do menu e do mapa do site.
- A chave do Gemini é usada SÓ nesta página. Nunca use em páginas públicas.

Nesta página:

1. Filtro por categoria, com a contagem de produtos "sem foto montada" e "já geradas".
2. Botão **"Gerar fotos desta categoria"**: uma fila com no máximo 2 gerações ao mesmo tempo, barra de progresso, pausar/retomar e uma nova tentativa automática em caso de erro.
3. Para cada produto, chame o modelo de imagem do Gemini (o mais recente com imagem de entrada, ex.: Nano Banana / Gemini Image) via `@google/genai`, enviando **duas imagens** e o texto abaixo:
   - Imagem 1 (o molde do produto): `produto.imagem_molde`
   - Imagem 2 (referência de estilo, sempre a mesma): `https://cdn.jsdelivr.net/gh/ferribrokers-eng/claude@cc30edc16a57509c153da55217133e2e879f1d89/estampashirt_imagens/Interclasse/arte-para-camisa-interclasse-pokemon-gengar-modelo-26A002.jpg`
   - Texto:

```
A primeira imagem é o MOLDE de sublimação de uma camiseta: as peças separadas (frente, costas e mangas).
A segunda imagem é só a REFERÊNCIA DE ESTILO de foto.
Crie uma foto realista de produto, no mesmo estilo da referência: DUAS camisetas montadas lado a lado,
a da esquerda mostrando a FRENTE e a da direita mostrando as COSTAS, levemente giradas, com caimento natural,
dobras e sombras realistas, gola e mangas costuradas.
Use EXATAMENTE a arte do molde em cada parte (frente na frente, costas nas costas, mangas nas mangas):
mesmas cores, desenhos, textos, nomes, números e posições. Não invente, não remova e não altere nenhum elemento da arte.
Fundo: ambiente urbano claro e desfocado, iluminação de estúdio suave.
Sem pessoas, sem marca d'água e sem texto extra. Formato quadrado 1:1.
```

   - Para `layout == "so_frente"`, troque a frase das duas camisetas por: "UMA camiseta montada vista de frente, levemente girada, com costas lisas na cor da camisa".
   - Para `layout == "kit"`, troque por: "DUAS camisetas lado a lado (adulto e infantil), cada uma com uma das artes do molde, vistas de frente".
4. Mostre o resultado numa grade ao lado do molde, com os botões **Aprovar**, **Gerar outra** e **Descartar**. Mostre também o molde ampliado para eu conferir se a arte ficou fiel.
5. Produtos que já têm foto aprovada não são gerados de novo, para eu nunca pagar duas vezes pela mesma estampa.
6. Botão **"Baixar ZIP das aprovadas"**: arquivos JPG de 1024×1024, com o nome `{id}.jpg`. Eu vou enviar esse ZIP para a pasta `gl-sports/montadas/` do repositório.

## 3. Site público

- Crie a constante `MONTADAS_BASE_URL = "https://cdn.jsdelivr.net/gh/ferribrokers-eng/claude@claude/extract-website-images-ehffq2/gl-sports/montadas/"` em `config.ts`.
- Card e página do produto:
  - se o produto tem `imagem_montada`, use essa imagem;
  - se não tem, tente `MONTADAS_BASE_URL + id + ".jpg"`;
  - se essa imagem não existir (erro ao carregar), use a montagem automática em canvas que já está no site; se ela também não existir, use o molde.
- Ao passar o mouse, troque para o molde (`imagem_molde`), como já acontece hoje.
- Na página do produto, mantenha os botões "Camisa montada" e "Molde (peças)".

## 4. Conferência

Me diga:

- se `/admin/montagem` abre com a senha;
- quantos produtos aparecem sem foto em cada categoria;
- se gerou corretamente uma foto de teste da categoria Infantil (só 20 produtos, bom para testar antes das grandes).
