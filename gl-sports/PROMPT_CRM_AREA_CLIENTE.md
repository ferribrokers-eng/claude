Adicione ao site GL Sports a **área do cliente** e o **CRM da equipe**, no mesmo site e no mesmo domínio, usando **Supabase**. O Supabase ainda NÃO está configurado: deixe tudo pronto e funcionando em "modo de preparação" (explicado no item 1). Não mude o visual nem as funções que já existem na loja.

O banco de dados já está pronto e testado. **Não crie outras tabelas.** Use exatamente as tabelas, status e funções deste arquivo:
`https://cdn.jsdelivr.net/gh/ferribrokers-eng/claude@claude/extract-website-images-ehffq2/gl-sports/supabase/migrations/0001_crm.sql`

## 1. Conexão com o Supabase (preparada, sem configurar)

- Use `@supabase/supabase-js` v2, com as variáveis `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY` (deixe um `.env.example`).
- Se as variáveis estiverem vazias, o site entra em **modo de preparação**:
  - a loja funciona normalmente, e o carrinho finaliza pelo WhatsApp como hoje;
  - "Entrar", "Criar conta" e `/crm` mostram o aviso "Em breve: área do cliente em configuração", sem erros na tela;
  - nenhum dado inventado é salvo.
- Nunca coloque a chave `service_role` no site.

## 2. Três áreas no mesmo site

| Área | Endereço | Quem acessa |
|---|---|---|
| **Loja** | `/`, `/categoria/...`, `/produto/...` | Todo mundo |
| **Área do cliente** | `/entrar`, `/criar-conta`, `/minha-conta/...` | Clientes cadastrados |
| **CRM** | `/crm/entrar`, `/crm/...` | Só a equipe (master, admin, vendedor) |

- O CRM **não aparece em nenhum menu** da loja, tem `noindex` e fica fora do sitemap. A equipe entra digitando `/crm/entrar`.
- **Proteção de rotas:**
  - `/crm/*` só abre se o usuário logado tiver registro **ativo** em `perfis`. Se um cliente tentar entrar, faça logout e mostre "Acesso restrito à equipe GL Sports".
  - `/minha-conta/*` só abre para usuários com registro em `clientes` (`clientes.user_id = auth.uid()`).
- Login da equipe e login de cliente usam o Supabase Auth, mas em telas separadas:
  - `/crm/entrar`: e-mail e senha, sem "criar conta";
  - `/entrar`: login do cliente, com link para criar conta.

## 3. Cadastro do cliente (automático)

- Para enviar um pedido, o cliente precisa ter conta. Se ele clicar em "Enviar pedido" sem estar logado, mostre login/cadastro e, depois, volte ao carrinho.
- Tela `/criar-conta` (passo único e simples): nome, e-mail, senha, WhatsApp, tipo (pessoa, time, escola, empresa, igreja), CPF/CNPJ (opcional), CEP (preencha cidade, UF e endereço pela API ViaCEP), "como nos conheceu" e a caixa "Aceito receber novidades pelo WhatsApp" (LGPD, desmarcada por padrão).
- Chame:
  ```js
  supabase.auth.signUp({ email, password, options: { data: {
    tipo_conta: 'cliente', nome, whatsapp, documento, cep, endereco, cidade, uf,
    tipo, origem, aceita_marketing } } })
  ```
  O banco cria o cliente sozinho (trigger `trg_novo_usuario`). Não insira em `clientes` pelo site.

## 4. Pedido pelo site

- No carrinho, além dos itens: quantidade de peças, tipo de peça (camiseta, regata, manga longa, abadá), "com nome e número?", data em que precisa receber e observações.
- O botão **"Enviar pedido"** chama `supabase.rpc('criar_pedido', { itens, data_entrega, funil, observacoes })`:
  - `funil` é `escolas` para Interclasse, Jogos Internos, Nono Ano e Terceirão; `times_empresas` para Futebol, Ciclismo, Pesca, Motocross, Artes Marciais e Torcida; `varejo` para o resto;
  - cada item tem `produto_id`, `produto_nome`, `imagem_url` (do catálogo), `tipo_peca`, `quantidade` e `adicionais`.
- Depois, mostre "Pedido #NUMERO recebido!" e leve o cliente para a página do pedido.

## 5. Área do cliente (`/minha-conta`)

- **Meus pedidos:** lista com número, data, foto da estampa, status e valor.
- **Página do pedido:** uma linha do tempo com as etapas (Recebido → Orçamento → Arte → Lista → Pagamento → Produção → Pronto → Enviado → Entregue), com a etapa atual destacada em verde (vem de `pedidos.status`). As ações aparecem conforme o status:
  - `orcamento_enviado`: mostra o orçamento (produtos, frete, desconto, total, validade) e o botão **"Aceitar orçamento"** → `rpc('aceitar_orcamento')`;
  - `arte_em_aprovacao`: mostra a arte grande (URL assinada do bucket `artes`) com os botões **"Aprovar arte"** (pede o nome de quem aprova → `rpc('aprovar_arte')`) e **"Pedir ajuste"** (comentário → `rpc('pedir_ajuste_arte')`);
  - `aguardando_lista`: abre a **planilha de nomes, números e tamanhos**:
    - adicionar linhas e colar direto do Excel/WhatsApp (uma pessoa por linha: nome; número; tamanho);
    - aviso em vermelho para números repetidos;
    - total por tamanho;
    - botões **"Salvar rascunho"** e **"Confirmar lista"** → `rpc('salvar_lista', { confirmar })`;
  - `aguardando_sinal`: valor do sinal (`valor_total × sinal_percentual / 100`), a chave Pix da loja e o envio do comprovante (bucket `comprovantes`, pasta `<pedido_id>/`);
  - `enviado`: código de rastreio e o botão **"Recebi meu pedido"** → `rpc('confirmar_entrega')`.
- **Meus dados:** editar o cadastro e a autorização de WhatsApp.
- Atualize a página em tempo real (Supabase Realtime em `pedidos`) quando o status mudar.

## 6. CRM (`/crm`), feito para computador

Visual escuro da marca, menu lateral fixo: Painel, Pedidos, Clientes, Tarefas, Mensagens, Relatórios e, só para master/admin, Equipe e Configurações.

**REGRA PRINCIPAL:** o CRM **nunca** altera `pedidos.status` diretamente e **não tem arrastar card**. O vendedor só registra fatos (orçamento, arte, pagamento, produção, envio), e o banco move o pedido sozinho. Use Supabase Realtime para os cards mudarem de coluna na tela, com uma animação suave e um aviso "Pedido #1023 foi para Em produção".

1. **Painel:**
   - números do mês (pedidos, faturamento, ticket médio, taxa orçamento → pedido);
   - tarefas de hoje e atrasadas;
   - pedidos com prazo de produção (`prazo_producao`) em até 3 dias ou vencido, em vermelho.
2. **Pedidos:**
   - colunas por status, só de visualização, com filtro por funil (Times e empresas, Escolas, Varejo) e por vendedor, e busca por número ou cliente;
   - cada card mostra o número, o cliente, a foto da estampa, o valor, a data de entrega e um selo de atraso.
3. **Página do pedido (equipe)**, com as ações:
   - **Orçamento:** formulário (valor dos produtos, frete, desconto, validade) com o botão "Enviar orçamento" (insere em `orcamentos` com `enviado_em = now()`, versão +1);
   - **Arte:** envio do arquivo para o bucket `artes` (pasta `<pedido_id>/`), que insere em `artes` (versão +1). Mostra o histórico de versões, quem aprovou e quando, e os comentários de ajuste;
   - **Lista:** a mesma planilha do cliente, com exportação para CSV e totais por tamanho para a produção;
   - **Pagamentos:** registrar valor, método e comprovante, com o botão "Confirmar pagamento" (`confirmado_em = now()`). Mostra quanto falta do sinal e do total;
   - **Produção:** botões em sequência: Impressão → Prensa → Costura → Conferência, e "Finalizar conferência" (`producao.finalizada_em = now()`);
   - **Envio:** retirada, Correios, transportadora ou motoboy, e o código de rastreio;
   - **Cancelar pedido** (só admin/master, com motivo);
   - **Histórico:** `pedido_eventos` em linha do tempo;
   - **WhatsApp:** as mensagens do pedido. As que estão com status `manual` têm o botão **"Abrir no WhatsApp"** (`https://wa.me/55<numero>?text=<mensagem>`) e o botão "Marcar como enviada".
4. **Clientes:**
   - lista com busca, filtros (tipo, cidade, UF, tag, origem) e cadastro manual;
   - a ficha do cliente mostra os dados, as tags, o histórico de pedidos, o total já comprado e o botão "Novo pedido" (canal `whatsapp` ou `loja`).
5. **Tarefas:** lista das minhas tarefas e de todas (admin), com "Concluir" e filtro por atrasadas. As tarefas são criadas sozinhas pelo banco.
6. **Mensagens:**
   - fila de WhatsApp (pendentes, manuais, enviadas, falhas);
   - edição dos textos automáticos (`mensagem_modelos`, com as variáveis {nome}, {numero} e {link});
   - **Conexões** (admin): cadastrar a conexão `manual`, `cloud_api` (WhatsApp verificado pela Meta) ou `nao_oficial` (gateway) e escolher qual é a padrão. Ao escolher `nao_oficial`, mostre o aviso: "Pode causar bloqueio do número. Use um número separado." Tokens e senhas NÃO são digitados no site: ficam nos secrets do Supabase.
7. **Relatórios:**
   - vendas por mês, por funil, por categoria de estampa, por vendedor e por UF;
   - taxa de conversão;
   - prazo médio de produção;
   - pedidos atrasados.
8. **Equipe** (master e admin):
   - lista de membros (nome, e-mail, papel, ativo);
   - **"Novo membro"** (nome, e-mail, senha e papel), que chama a Edge Function `equipe` com `{ acao: 'criar', ... }`;
   - botões "Redefinir senha", "Desativar" e "Ativar", com `{ acao: 'redefinir_senha' | 'desativar' | 'ativar', id }`;
   - o admin só vê a opção de papel "vendedor"; o master pode criar admin e master.
9. **Configurações** (admin): editar `configuracoes` (`site_url`, `avaliacao_google_url` e `whatsapp_loja`) e a chave Pix da loja.

## 7. Permissões na tela (o banco já protege; a tela só esconde)

| Papel | O que vê |
|---|---|
| **master** | Tudo, incluindo criar admin/master. |
| **admin** | Tudo, menos criar master. |
| **vendedor** | Os próprios pedidos e os sem vendedor, clientes e tarefas. Sem Equipe e Configurações. |

## 8. Conferência

Me diga:

- se em modo de preparação (sem variáveis) a loja funciona e as áreas mostram "Em breve";
- se `/crm` não aparece em nenhum menu da loja;
- quais telas foram criadas;
- se nenhum lugar do código altera `pedidos.status` diretamente.
