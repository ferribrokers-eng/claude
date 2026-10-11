# Supabase da GL Sports (site + área do cliente + CRM)

Tudo já está pronto aqui; é só aplicar quando for configurar o Supabase.

| Arquivo | O que é |
|---|---|
| `migrations/0001_crm.sql` | Tabelas, status automático dos pedidos, tarefas, fila de WhatsApp, cadastro automático de clientes e segurança (RLS). **Testado** num PostgreSQL 16 com o fluxo completo de um pedido. |
| `migrations/0002_storage.sql` | Pastas de arquivos (artes e comprovantes) e quem pode ver cada uma. Não testado aqui (precisa do Storage do Supabase). |
| `functions/equipe/` | Função que cria logins da equipe, redefine senhas e desativa acessos, de dentro do CRM. Não testada aqui (precisa do Supabase). |

## Como ligar (uma vez só)

1. Crie o projeto em https://supabase.com (região São Paulo).
2. **SQL Editor:** cole e rode `0001_crm.sql`, depois `0002_storage.sql` e `0003_permissoes_visitante.sql`.
3. **Authentication → Providers → Email:** deixe ativado. Em **URL Configuration**, coloque o domínio do site.
4. **Crie a conta master** (a sua):
   - Em **Authentication → Users → Add user**, informe o seu e-mail e uma senha forte.
   - No **SQL Editor**, rode (troque o e-mail):
     ```sql
     insert into perfis (id, nome, papel)
     select id, 'Seu Nome', 'master' from auth.users where email = 'seu@email.com';
     delete from clientes where email = 'seu@email.com';  -- a conta master não é cliente
     ```
5. **Publique a função da equipe** (pelo terminal, com o Supabase CLI):
   ```bash
   supabase functions deploy equipe
   ```
6. **No site**, configure as variáveis:
   ```
   VITE_SUPABASE_URL=https://SEU-PROJETO.supabase.co
   VITE_SUPABASE_ANON_KEY=sua-chave-anon-publica
   ```
   A chave `service_role` **nunca** vai para o site; ela só existe dentro das funções.
7. Entre em `/crm/entrar` com a conta master. Em **Equipe**, crie os logins dos vendedores.
8. Em **Configurações**, troque `site_url` pelo domínio real e `avaliacao_google_url` pelo link de avaliação do Google Meu Negócio.

## Como o status anda sozinho

Ninguém arrasta card. O status é recalculado sempre que um fato do pedido muda:

| Fato | Status |
|---|---|
| Cliente envia o pedido pelo site | `novo` |
| Vendedor envia o orçamento | `orcamento_enviado` |
| Cliente aceita o orçamento no site | `criando_arte` |
| Vendedor envia a arte | `arte_em_aprovacao` |
| Cliente aprova a arte | `aguardando_lista` |
| Cliente confirma nomes, números e tamanhos | `aguardando_sinal` |
| Vendedor confirma pagamentos que somam o sinal (50% padrão) | `em_producao` (abre a ficha de produção) |
| Produção finaliza a conferência | `pronto` |
| Vendedor registra o envio ou a retirada | `enviado` |
| Cliente (ou vendedor) confirma o recebimento | `entregue` |
| Admin cancela | `cancelado` |

Cada mudança gera um registro no histórico, uma tarefa para o vendedor e uma mensagem de WhatsApp na fila.

## WhatsApp: três modos

| Modo | Como funciona | Custo / risco |
|---|---|---|
| `manual` (padrão) | O CRM mostra a mensagem pronta e o botão "Abrir no WhatsApp" (wa.me). O vendedor só clica em enviar. | Grátis e sem risco. Funciona com o WhatsApp Business que você já usa. |
| `cloud_api` (verificado pela Meta) | Envio automático pela API oficial. Mensagens fora da janela de 24 h precisam de **templates aprovados** pela Meta. | Cobrança por conversa da Meta. Sem risco de bloqueio, se seguir as regras. |
| `nao_oficial` | Envio automático por um gateway do WhatsApp Web (ex.: Evolution API em um servidor seu). | Viola os termos do WhatsApp: **o número pode ser banido**. Use um número separado do principal, se usar. |

As funções `whatsapp-enviar` (lê a fila `whatsapp_mensagens` com status `pendente` e envia pela conexão padrão) e `whatsapp-webhook` (recebe respostas) ficam para a próxima etapa.
