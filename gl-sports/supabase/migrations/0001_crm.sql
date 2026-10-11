-- GL Sports: banco de dados do site + CRM (Supabase / PostgreSQL)
--
-- O status do pedido NUNCA é alterado à mão: ele é recalculado a partir dos
-- fatos do pedido (orçamento aceito, arte aprovada, sinal pago, lista
-- confirmada, produção, envio, entrega) sempre que um desses fatos muda.
-- Cada mudança fica registrada em pedido_eventos e pode gerar tarefas e
-- mensagens de WhatsApp automáticas.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Tipos
-- ---------------------------------------------------------------------------

create type papel_usuario as enum ('master', 'admin', 'vendedor');
create type tipo_cliente as enum ('pessoa', 'time', 'escola', 'empresa', 'igreja', 'outro');
create type funil_venda as enum ('times_empresas', 'escolas', 'varejo');
create type canal_pedido as enum ('site', 'whatsapp', 'loja');
create type pedido_status as enum (
  'novo',                -- pedido feito no site, aguardando orçamento
  'orcamento_enviado',   -- vendedor enviou o orçamento
  'criando_arte',        -- cliente aceitou o orçamento
  'arte_em_aprovacao',   -- arte enviada, aguardando o cliente
  'aguardando_lista',    -- arte aprovada, falta confirmar nomes/números/tamanhos
  'aguardando_sinal',    -- arte aprovada e lista ok, falta o sinal
  'em_producao',
  'pronto',
  'enviado',
  'entregue',
  'cancelado'
);
create type etapa_producao as enum ('impressao', 'prensa', 'costura', 'conferencia');
create type metodo_pagamento as enum ('pix', 'cartao_credito', 'cartao_debito', 'dinheiro', 'boleto', 'outro');
create type modalidade_envio as enum ('retirada', 'correios', 'transportadora', 'motoboy');
create type tipo_conexao_whatsapp as enum (
  'cloud_api',      -- WhatsApp Business verificado pela Meta (API oficial)
  'nao_oficial',    -- gateway pelo WhatsApp Web (ex.: Evolution API). Risco de bloqueio.
  'manual'          -- só abre wa.me com a mensagem pronta; o vendedor clica em enviar
);
create type status_mensagem as enum ('pendente', 'enviada', 'entregue', 'lida', 'falhou', 'manual');

-- ---------------------------------------------------------------------------
-- Equipe e clientes
-- ---------------------------------------------------------------------------

create table perfis (
  id uuid primary key references auth.users (id) on delete cascade,
  nome text not null,
  papel papel_usuario not null default 'vendedor',
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

create table clientes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users (id) on delete set null,
  tipo tipo_cliente not null default 'pessoa',
  nome text not null,
  email text,
  whatsapp text,
  documento text,                         -- CPF ou CNPJ
  cep text,
  endereco text,
  cidade text,
  uf char(2),
  origem text,                            -- google, instagram, site, indicacao...
  tags text[] not null default '{}',
  aceita_marketing boolean not null default false,
  aceita_marketing_em timestamptz,
  vendedor_id uuid references perfis (id) on delete set null,
  observacoes text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create unique index clientes_email_unico on clientes (lower(email)) where email is not null;
create index clientes_whatsapp on clientes (whatsapp);

-- ---------------------------------------------------------------------------
-- Pedidos
-- ---------------------------------------------------------------------------

create table pedidos (
  id uuid primary key default gen_random_uuid(),
  numero bigint generated always as identity (start with 1001) unique,
  cliente_id uuid not null references clientes (id) on delete restrict,
  vendedor_id uuid references perfis (id) on delete set null,
  canal canal_pedido not null default 'site',
  funil funil_venda not null default 'varejo',
  status pedido_status not null default 'novo',
  data_entrega date,                                -- data combinada com o cliente
  prazo_producao date generated always as (data_entrega - 5) stored,  -- folga de 5 dias
  sinal_percentual numeric(5,2) not null default 50 check (sinal_percentual between 0 and 100),
  valor_total numeric(12,2) not null default 0,     -- do orçamento aceito
  lista_confirmada_em timestamptz,
  entregue_em timestamptz,
  cancelado_em timestamptz,
  cancelado_motivo text,
  observacoes text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index pedidos_status on pedidos (status);
create index pedidos_cliente on pedidos (cliente_id);
create index pedidos_vendedor on pedidos (vendedor_id);

create table pedido_itens (
  id uuid primary key default gen_random_uuid(),
  pedido_id uuid not null references pedidos (id) on delete cascade,
  produto_id integer,                 -- id do produto no catalogo.json
  produto_nome text not null,
  imagem_url text,
  tipo_peca text not null default 'camiseta',   -- camiseta, regata, manga longa, short, abadá...
  quantidade integer not null check (quantidade > 0),
  preco_unitario numeric(12,2) not null default 0,
  adicionais jsonb not null default '{}'::jsonb  -- ex.: {"nome_numero": true, "gola": "V"}
);
create index pedido_itens_pedido on pedido_itens (pedido_id);

-- Nomes, números e tamanhos de cada peça (a "grade" do uniforme)
create table pedido_lista (
  id uuid primary key default gen_random_uuid(),
  pedido_id uuid not null references pedidos (id) on delete cascade,
  item_id uuid references pedido_itens (id) on delete cascade,
  nome text,
  numero text,
  tamanho text not null,              -- PP, P, M, G, GG, XG, infantil 2..16
  observacao text
);
create index pedido_lista_pedido on pedido_lista (pedido_id);

create table orcamentos (
  id uuid primary key default gen_random_uuid(),
  pedido_id uuid not null references pedidos (id) on delete cascade,
  versao integer not null default 1,
  valor_produtos numeric(12,2) not null default 0,
  frete numeric(12,2) not null default 0,
  desconto numeric(12,2) not null default 0,
  valor_total numeric(12,2) generated always as (valor_produtos + frete - desconto) stored,
  validade date,
  enviado_em timestamptz,
  aceito_em timestamptz,
  recusado_em timestamptz,
  criado_em timestamptz not null default now(),
  unique (pedido_id, versao)
);

create table artes (
  id uuid primary key default gen_random_uuid(),
  pedido_id uuid not null references pedidos (id) on delete cascade,
  versao integer not null,
  arquivo_url text not null,
  enviada_em timestamptz not null default now(),
  aprovada_em timestamptz,
  aprovada_por text,                  -- nome de quem aprovou
  reprovada_em timestamptz,
  comentario_cliente text,
  unique (pedido_id, versao)
);

create table pagamentos (
  id uuid primary key default gen_random_uuid(),
  pedido_id uuid not null references pedidos (id) on delete cascade,
  valor numeric(12,2) not null check (valor > 0),
  metodo metodo_pagamento not null default 'pix',
  comprovante_url text,
  confirmado_em timestamptz,          -- só conta quando confirmado
  registrado_por uuid references perfis (id),
  criado_em timestamptz not null default now()
);
create index pagamentos_pedido on pagamentos (pedido_id);

create table producao (
  pedido_id uuid primary key references pedidos (id) on delete cascade,
  etapa etapa_producao not null default 'impressao',
  iniciada_em timestamptz not null default now(),
  finalizada_em timestamptz           -- conferência concluída = pedido pronto
);

create table envios (
  id uuid primary key default gen_random_uuid(),
  pedido_id uuid not null references pedidos (id) on delete cascade,
  modalidade modalidade_envio not null,
  codigo_rastreio text,
  enviado_em timestamptz not null default now(),
  entregue_em timestamptz
);

create table pedido_eventos (
  id bigint generated always as identity primary key,
  pedido_id uuid not null references pedidos (id) on delete cascade,
  status_anterior pedido_status,
  status_novo pedido_status not null,
  autor uuid,
  criado_em timestamptz not null default now()
);
create index pedido_eventos_pedido on pedido_eventos (pedido_id, criado_em);

create table tarefas (
  id uuid primary key default gen_random_uuid(),
  pedido_id uuid references pedidos (id) on delete cascade,
  cliente_id uuid references clientes (id) on delete cascade,
  responsavel_id uuid references perfis (id) on delete set null,
  tipo text not null,                 -- retorno_orcamento, cobrar_sinal, pedir_avaliacao...
  descricao text not null,
  vence_em timestamptz not null,
  concluida_em timestamptz,
  criado_em timestamptz not null default now()
);
create index tarefas_abertas on tarefas (responsavel_id, vence_em) where concluida_em is null;

-- ---------------------------------------------------------------------------
-- WhatsApp (oficial, não oficial ou manual)
-- ---------------------------------------------------------------------------

-- Tokens e senhas NÃO ficam aqui: ficam nos "secrets" das Edge Functions.
create table whatsapp_conexoes (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  tipo tipo_conexao_whatsapp not null,
  numero text not null,
  ativa boolean not null default false,
  padrao boolean not null default false,
  config jsonb not null default '{}'::jsonb,   -- ex.: phone_number_id, url do gateway (sem segredos)
  criado_em timestamptz not null default now()
);
create unique index whatsapp_uma_padrao on whatsapp_conexoes (padrao) where padrao;

create table mensagem_modelos (
  id uuid primary key default gen_random_uuid(),
  chave text not null unique,
  status_gatilho pedido_status,       -- envia automaticamente ao entrar neste status
  texto text not null,                -- variáveis: {nome} {numero} {link}
  template_meta text,                 -- nome do template aprovado na Meta (API oficial)
  ativo boolean not null default true
);

-- Configurações gerais (editáveis no CRM pelo admin)
create table configuracoes (
  chave text primary key,
  valor text not null
);
insert into configuracoes (chave, valor) values
  ('site_url', 'https://glsports.com.br'),            -- trocar pelo domínio real
  ('avaliacao_google_url', 'https://g.page/r/COLE-AQUI/review'),
  ('whatsapp_loja', '5513997011514');

create table whatsapp_mensagens (
  id uuid primary key default gen_random_uuid(),
  conexao_id uuid references whatsapp_conexoes (id) on delete set null,
  cliente_id uuid references clientes (id) on delete cascade,
  pedido_id uuid references pedidos (id) on delete cascade,
  direcao text not null check (direcao in ('saida', 'entrada')),
  modelo_chave text,
  conteudo text not null,
  status status_mensagem not null default 'pendente',
  erro text,
  externo_id text,                    -- id da mensagem no WhatsApp/gateway
  criado_em timestamptz not null default now(),
  enviado_em timestamptz
);
create index whatsapp_fila on whatsapp_mensagens (status, criado_em) where status = 'pendente';

-- ---------------------------------------------------------------------------
-- Funções auxiliares de permissão
-- ---------------------------------------------------------------------------

create or replace function papel_atual() returns papel_usuario
language sql stable security definer set search_path = public as $$
  select papel from perfis where id = auth.uid() and ativo
$$;

create or replace function e_equipe() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from perfis where id = auth.uid() and ativo)
$$;

create or replace function e_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(papel_atual() in ('master', 'admin'), false)
$$;

create or replace function meu_cliente_id() returns uuid
language sql stable security definer set search_path = public as $$
  select id from clientes where user_id = auth.uid()
$$;

-- ---------------------------------------------------------------------------
-- Status automático
-- ---------------------------------------------------------------------------

create or replace function calcular_status(p_pedido uuid) returns pedido_status
language plpgsql stable set search_path = public as $$
declare
  p pedidos;
  v_pago numeric;
  v_arte_aprovada boolean;
  v_arte_pendente boolean;
begin
  select * into p from pedidos where id = p_pedido;
  if p.cancelado_em is not null then return 'cancelado'; end if;
  if p.entregue_em is not null
     or exists (select 1 from envios where pedido_id = p_pedido and entregue_em is not null) then
    return 'entregue';
  end if;
  if exists (select 1 from envios where pedido_id = p_pedido) then return 'enviado'; end if;
  if exists (select 1 from producao where pedido_id = p_pedido and finalizada_em is not null) then
    return 'pronto';
  end if;

  select coalesce(sum(valor), 0) into v_pago
    from pagamentos where pedido_id = p_pedido and confirmado_em is not null;
  select exists (select 1 from artes where pedido_id = p_pedido and aprovada_em is not null)
    into v_arte_aprovada;

  if v_arte_aprovada then
    if p.lista_confirmada_em is null then return 'aguardando_lista'; end if;
    if v_pago < round(p.valor_total * p.sinal_percentual / 100, 2) then return 'aguardando_sinal'; end if;
    return 'em_producao';
  end if;

  select exists (
    select 1 from artes a
    where a.pedido_id = p_pedido and a.aprovada_em is null and a.reprovada_em is null
  ) into v_arte_pendente;
  if v_arte_pendente then return 'arte_em_aprovacao'; end if;

  if exists (select 1 from orcamentos where pedido_id = p_pedido and aceito_em is not null) then
    return 'criando_arte';
  end if;
  if exists (select 1 from orcamentos
             where pedido_id = p_pedido and enviado_em is not null and recusado_em is null) then
    return 'orcamento_enviado';
  end if;
  return 'novo';
end $$;

-- Coloca na fila a mensagem automática do status (a Edge Function envia).
create or replace function enfileirar_mensagem(p_pedido uuid, p_status pedido_status) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_pedido pedidos;
  v_cliente clientes;
  v_modelo mensagem_modelos;
  v_conexao uuid;
  v_link text;
begin
  select * into v_modelo from mensagem_modelos where status_gatilho = p_status and ativo limit 1;
  if not found then return; end if;
  select * into v_pedido from pedidos where id = p_pedido;
  select * into v_cliente from clientes where id = v_pedido.cliente_id;
  if v_cliente.whatsapp is null or v_cliente.whatsapp = '' then return; end if;
  select id into v_conexao from whatsapp_conexoes where padrao and ativa limit 1;
  v_link := case when p_status = 'entregue'
                 then (select valor from configuracoes where chave = 'avaliacao_google_url')
                 else (select valor from configuracoes where chave = 'site_url')
                      || '/minha-conta/pedidos/' || v_pedido.numero end;
  insert into whatsapp_mensagens (conexao_id, cliente_id, pedido_id, direcao, modelo_chave, conteudo, status)
  values (
    v_conexao, v_cliente.id, p_pedido, 'saida', v_modelo.chave,
    replace(replace(replace(v_modelo.texto,
      '{nome}', split_part(v_cliente.nome, ' ', 1)),
      '{numero}', v_pedido.numero::text),
      '{link}', coalesce(v_link, '')),
    case when v_conexao is null then 'manual'::status_mensagem else 'pendente'::status_mensagem end
  );
end $$;

-- Aplica o status calculado, registra o evento e dispara as automações.
create or replace function atualizar_status(p_pedido uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_antigo pedido_status;
  v_novo pedido_status;
  v_pedido pedidos;
begin
  select status into v_antigo from pedidos where id = p_pedido for update;
  if not found then return; end if;
  v_novo := calcular_status(p_pedido);
  if v_novo = v_antigo then return; end if;

  perform set_config('glsports.status_interno', 'on', true);
  update pedidos set status = v_novo, atualizado_em = now() where id = p_pedido
    returning * into v_pedido;
  perform set_config('glsports.status_interno', 'off', true);
  insert into pedido_eventos (pedido_id, status_anterior, status_novo, autor)
    values (p_pedido, v_antigo, v_novo, auth.uid());

  -- Ao entrar em produção, abre a ficha de produção.
  if v_novo = 'em_producao' then
    insert into producao (pedido_id) values (p_pedido) on conflict do nothing;
  end if;

  -- Tarefas automáticas para o vendedor do pedido.
  insert into tarefas (pedido_id, cliente_id, responsavel_id, tipo, descricao, vence_em)
  select p_pedido, v_pedido.cliente_id, v_pedido.vendedor_id, t.tipo, t.descricao, now() + t.prazo
  from (values
    ('novo'::pedido_status, 'enviar_orcamento', 'Enviar orçamento do pedido #' || v_pedido.numero, interval '4 hours'),
    ('orcamento_enviado', 'retorno_orcamento', 'Retornar orçamento sem resposta do pedido #' || v_pedido.numero, interval '2 days'),
    ('criando_arte', 'enviar_arte', 'Criar e enviar a arte do pedido #' || v_pedido.numero, interval '2 days'),
    ('aguardando_lista', 'cobrar_lista', 'Cobrar a lista de nomes/números/tamanhos do pedido #' || v_pedido.numero, interval '1 day'),
    ('aguardando_sinal', 'cobrar_sinal', 'Cobrar o sinal do pedido #' || v_pedido.numero, interval '1 day'),
    ('pronto', 'combinar_entrega', 'Combinar envio ou retirada do pedido #' || v_pedido.numero, interval '4 hours'),
    ('entregue', 'pedir_avaliacao', 'Pedir avaliação no Google do pedido #' || v_pedido.numero, interval '2 days')
  ) as t(status, tipo, descricao, prazo)
  where t.status = v_novo;

  perform enfileirar_mensagem(p_pedido, v_novo);
end $$;

create or replace function trg_recalcular_status() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform atualizar_status(coalesce(new.pedido_id, old.pedido_id));
  return null;
end $$;

create trigger orcamentos_status after insert or update or delete on orcamentos
  for each row execute function trg_recalcular_status();
create trigger artes_status after insert or update or delete on artes
  for each row execute function trg_recalcular_status();
create trigger pagamentos_status after insert or update or delete on pagamentos
  for each row execute function trg_recalcular_status();
create trigger producao_status after insert or update on producao
  for each row execute function trg_recalcular_status();
create trigger envios_status after insert or update or delete on envios
  for each row execute function trg_recalcular_status();

-- Ninguém muda o status à mão (nem pela API): só atualizar_status().
-- Cancelar ou reabrir um pedido é só para admin/master.
create or replace function trg_proteger_pedido() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status is distinct from old.status
     and coalesce(current_setting('glsports.status_interno', true), 'off') <> 'on' then
    new.status := old.status;
  end if;
  if new.cancelado_em is distinct from old.cancelado_em and auth.uid() is not null and not e_admin() then
    raise exception 'Só admin pode cancelar ou reabrir um pedido';
  end if;
  return new;
end $$;
create trigger pedidos_proteger before update on pedidos
  for each row execute function trg_proteger_pedido();

create or replace function trg_pedido_campos() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.lista_confirmada_em is distinct from old.lista_confirmada_em
     or new.entregue_em is distinct from old.entregue_em
     or new.cancelado_em is distinct from old.cancelado_em
     or new.valor_total is distinct from old.valor_total
     or new.sinal_percentual is distinct from old.sinal_percentual then
    perform atualizar_status(new.id);
  end if;
  return null;
end $$;
create trigger pedidos_status after update on pedidos
  for each row execute function trg_pedido_campos();

-- O orçamento aceito define o valor total do pedido.
create or replace function trg_orcamento_aceito() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.aceito_em is not null and old.aceito_em is null then
    update pedidos set valor_total = new.valor_total where id = new.pedido_id;
  end if;
  return new;
end $$;
create trigger orcamentos_aceito after update on orcamentos
  for each row execute function trg_orcamento_aceito();

-- Pedido novo: distribui para o vendedor com menos pedidos abertos e cria a tarefa inicial.
create or replace function trg_pedido_novo() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.vendedor_id is null then
    select coalesce(
      (select vendedor_id from clientes where id = new.cliente_id),
      (select p.id from perfis p
        where p.ativo and p.papel = 'vendedor'
        order by (select count(*) from pedidos x
                  where x.vendedor_id = p.id and x.status not in ('entregue', 'cancelado')), p.criado_em
        limit 1)
    ) into new.vendedor_id;
  end if;
  return new;
end $$;
create trigger pedidos_distribuir before insert on pedidos
  for each row execute function trg_pedido_novo();

create or replace function trg_pedido_criado() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into pedido_eventos (pedido_id, status_anterior, status_novo, autor)
    values (new.id, null, new.status, auth.uid());
  insert into tarefas (pedido_id, cliente_id, responsavel_id, tipo, descricao, vence_em)
    values (new.id, new.cliente_id, new.vendedor_id, 'enviar_orcamento',
            'Enviar orçamento do pedido #' || new.numero, now() + interval '4 hours');
  perform enfileirar_mensagem(new.id, new.status);
  return null;
end $$;
create trigger pedidos_criado after insert on pedidos
  for each row execute function trg_pedido_criado();

-- ---------------------------------------------------------------------------
-- Cadastro automático do cliente (cadastro feito no site)
-- ---------------------------------------------------------------------------

-- O site chama supabase.auth.signUp({ email, password, options: { data: {
--   tipo_conta: 'cliente', nome, whatsapp, documento, cep, endereco, cidade, uf,
--   tipo, origem, aceita_marketing } } })
create or replace function trg_novo_usuario() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  m jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  if coalesce(m->>'tipo_conta', 'cliente') <> 'cliente' then return new; end if;
  insert into clientes (user_id, nome, email, whatsapp, documento, cep, endereco, cidade, uf,
                        tipo, origem, aceita_marketing, aceita_marketing_em)
  values (
    new.id,
    coalesce(nullif(m->>'nome', ''), split_part(new.email, '@', 1)),
    new.email, m->>'whatsapp', m->>'documento', m->>'cep', m->>'endereco', m->>'cidade',
    upper(left(m->>'uf', 2)),
    coalesce(nullif(m->>'tipo', ''), 'pessoa')::tipo_cliente,
    coalesce(nullif(m->>'origem', ''), 'site'),
    coalesce((m->>'aceita_marketing')::boolean, false),
    case when coalesce((m->>'aceita_marketing')::boolean, false) then now() end
  )
  -- cliente que já existia (ex.: cadastrado pelo vendedor) ganha o login
  on conflict (lower(email)) where email is not null
  do update set user_id = excluded.user_id, atualizado_em = now();
  return new;
end $$;
create trigger auth_novo_usuario after insert on auth.users
  for each row execute function trg_novo_usuario();

-- ---------------------------------------------------------------------------
-- Ações do cliente pelo site (RPCs)
-- ---------------------------------------------------------------------------

-- Cria o pedido a partir do carrinho:
-- itens = [{ "produto_id": 123, "produto_nome": "...", "imagem_url": "...",
--            "tipo_peca": "camiseta", "quantidade": 15, "adicionais": {...} }]
create or replace function criar_pedido(itens jsonb, data_entrega date default null,
                                        funil funil_venda default 'varejo', observacoes text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_cliente uuid := meu_cliente_id();
  v_pedido uuid;
begin
  if v_cliente is null then raise exception 'Faça login para enviar o pedido'; end if;
  if jsonb_array_length(coalesce(itens, '[]'::jsonb)) = 0 then raise exception 'Carrinho vazio'; end if;
  insert into pedidos (cliente_id, canal, funil, data_entrega, observacoes)
    values (v_cliente, 'site', funil, data_entrega, observacoes)
    returning id into v_pedido;
  insert into pedido_itens (pedido_id, produto_id, produto_nome, imagem_url, tipo_peca, quantidade, adicionais)
  select v_pedido, (i->>'produto_id')::int, i->>'produto_nome', i->>'imagem_url',
         coalesce(i->>'tipo_peca', 'camiseta'), greatest(1, coalesce((i->>'quantidade')::int, 1)),
         coalesce(i->'adicionais', '{}'::jsonb)
  from jsonb_array_elements(itens) i;
  return v_pedido;
end $$;

create or replace function verificar_dono(p_pedido uuid) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if not exists (select 1 from pedidos where id = p_pedido and cliente_id = meu_cliente_id()) then
    raise exception 'Pedido não encontrado';
  end if;
end $$;

create or replace function aceitar_orcamento(p_orcamento uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_pedido uuid;
begin
  select pedido_id into v_pedido from orcamentos where id = p_orcamento and enviado_em is not null;
  perform verificar_dono(v_pedido);
  update orcamentos set aceito_em = now() where id = p_orcamento and aceito_em is null;
end $$;

create or replace function aprovar_arte(p_arte uuid, p_nome text) returns void
language plpgsql security definer set search_path = public as $$
declare v_pedido uuid;
begin
  select pedido_id into v_pedido from artes where id = p_arte;
  perform verificar_dono(v_pedido);
  update artes set aprovada_em = now(), aprovada_por = p_nome
    where id = p_arte and aprovada_em is null and reprovada_em is null;
end $$;

create or replace function pedir_ajuste_arte(p_arte uuid, p_comentario text) returns void
language plpgsql security definer set search_path = public as $$
declare v_pedido uuid;
begin
  select pedido_id into v_pedido from artes where id = p_arte;
  perform verificar_dono(v_pedido);
  update artes set reprovada_em = now(), comentario_cliente = p_comentario
    where id = p_arte and aprovada_em is null;
end $$;

-- linhas = [{ "nome": "João", "numero": "10", "tamanho": "G" }, ...]
create or replace function salvar_lista(p_pedido uuid, linhas jsonb, confirmar boolean default false)
returns void
language plpgsql security definer set search_path = public as $$
begin
  perform verificar_dono(p_pedido);
  if exists (select 1 from pedidos where id = p_pedido
             and status in ('em_producao', 'pronto', 'enviado', 'entregue', 'cancelado')) then
    raise exception 'A lista não pode mais ser alterada: o pedido já está em produção';
  end if;
  delete from pedido_lista where pedido_id = p_pedido;
  insert into pedido_lista (pedido_id, nome, numero, tamanho, observacao)
  select p_pedido, l->>'nome', l->>'numero', l->>'tamanho', l->>'observacao'
  from jsonb_array_elements(linhas) l;
  if confirmar then
    update pedidos set lista_confirmada_em = now() where id = p_pedido;
  end if;
end $$;

create or replace function confirmar_entrega(p_pedido uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform verificar_dono(p_pedido);
  update pedidos set entregue_em = now() where id = p_pedido and status = 'enviado';
end $$;

-- ---------------------------------------------------------------------------
-- Painel: totais por etapa e números repetidos na lista
-- ---------------------------------------------------------------------------

create view painel_funil with (security_invoker = true) as
select funil, status, count(*) as pedidos, sum(valor_total) as valor
from pedidos group by funil, status;

create view lista_numeros_repetidos with (security_invoker = true) as
select pedido_id, numero, count(*) as vezes
from pedido_lista where numero is not null and numero <> ''
group by pedido_id, numero having count(*) > 1;

create view lista_totais_tamanho with (security_invoker = true) as
select pedido_id, tamanho, count(*) as quantidade
from pedido_lista group by pedido_id, tamanho;

-- ---------------------------------------------------------------------------
-- Segurança (RLS)
-- ---------------------------------------------------------------------------

alter table perfis enable row level security;
alter table clientes enable row level security;
alter table pedidos enable row level security;
alter table pedido_itens enable row level security;
alter table pedido_lista enable row level security;
alter table orcamentos enable row level security;
alter table artes enable row level security;
alter table pagamentos enable row level security;
alter table producao enable row level security;
alter table envios enable row level security;
alter table pedido_eventos enable row level security;
alter table tarefas enable row level security;
alter table whatsapp_conexoes enable row level security;
alter table mensagem_modelos enable row level security;
alter table whatsapp_mensagens enable row level security;
alter table configuracoes enable row level security;

-- Equipe
create policy perfis_ver on perfis for select using (e_equipe());
create policy perfis_admin on perfis for all using (e_admin()) with check (
  e_admin() and (papel <> 'master' or papel_atual() = 'master')   -- só o master cria outro master
);

-- Clientes: equipe vê todos; o cliente vê e edita só o próprio cadastro.
create policy clientes_equipe on clientes for all using (e_equipe()) with check (e_equipe());
create policy clientes_proprio_ver on clientes for select using (user_id = auth.uid());
create policy clientes_proprio_editar on clientes for update using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Pedidos: admin/master veem tudo; vendedor vê os seus e os sem vendedor; cliente vê os próprios.
create policy pedidos_admin on pedidos for all using (e_admin()) with check (e_admin());
create policy pedidos_vendedor on pedidos for all
  using (papel_atual() = 'vendedor' and (vendedor_id = auth.uid() or vendedor_id is null))
  with check (papel_atual() = 'vendedor' and (vendedor_id = auth.uid() or vendedor_id is null));
create policy pedidos_cliente on pedidos for select using (cliente_id = meu_cliente_id());

-- Tabelas filhas do pedido: mesma regra do pedido.
create or replace function pode_ver_pedido(p_pedido uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from pedidos p where p.id = p_pedido and (
      e_admin()
      or (papel_atual() = 'vendedor' and (p.vendedor_id = auth.uid() or p.vendedor_id is null))
      or p.cliente_id = meu_cliente_id()
    )
  )
$$;
create or replace function pode_editar_pedido(p_pedido uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select e_equipe() and pode_ver_pedido(p_pedido)
$$;

create policy itens_ver on pedido_itens for select using (pode_ver_pedido(pedido_id));
create policy itens_editar on pedido_itens for all using (pode_editar_pedido(pedido_id)) with check (pode_editar_pedido(pedido_id));
create policy lista_ver on pedido_lista for select using (pode_ver_pedido(pedido_id));
create policy lista_editar on pedido_lista for all using (pode_editar_pedido(pedido_id)) with check (pode_editar_pedido(pedido_id));
create policy orcamentos_ver on orcamentos for select using (pode_ver_pedido(pedido_id) and (e_equipe() or enviado_em is not null));
create policy orcamentos_editar on orcamentos for all using (pode_editar_pedido(pedido_id)) with check (pode_editar_pedido(pedido_id));
create policy artes_ver on artes for select using (pode_ver_pedido(pedido_id));
create policy artes_editar on artes for all using (pode_editar_pedido(pedido_id)) with check (pode_editar_pedido(pedido_id));
create policy pagamentos_ver on pagamentos for select using (pode_ver_pedido(pedido_id));
create policy pagamentos_editar on pagamentos for all using (pode_editar_pedido(pedido_id)) with check (pode_editar_pedido(pedido_id));
create policy producao_ver on producao for select using (pode_ver_pedido(pedido_id));
create policy producao_editar on producao for all using (pode_editar_pedido(pedido_id)) with check (pode_editar_pedido(pedido_id));
create policy envios_ver on envios for select using (pode_ver_pedido(pedido_id));
create policy envios_editar on envios for all using (pode_editar_pedido(pedido_id)) with check (pode_editar_pedido(pedido_id));
create policy eventos_ver on pedido_eventos for select using (pode_ver_pedido(pedido_id));

-- Tarefas e WhatsApp: só a equipe.
create policy tarefas_equipe on tarefas for all using (e_equipe()) with check (e_equipe());
create policy conexoes_ver on whatsapp_conexoes for select using (e_equipe());
create policy conexoes_admin on whatsapp_conexoes for all using (e_admin()) with check (e_admin());
create policy modelos_ver on mensagem_modelos for select using (e_equipe());
create policy modelos_admin on mensagem_modelos for all using (e_admin()) with check (e_admin());
create policy config_ver on configuracoes for select using (e_equipe());
create policy config_admin on configuracoes for all using (e_admin()) with check (e_admin());
create policy mensagens_equipe on whatsapp_mensagens for all using (e_equipe()) with check (e_equipe());

-- Funções que o site pode chamar
revoke execute on all functions in schema public from public, anon;
grant execute on function criar_pedido(jsonb, date, funil_venda, text),
  aceitar_orcamento(uuid), aprovar_arte(uuid, text), pedir_ajuste_arte(uuid, text),
  salvar_lista(uuid, jsonb, boolean), confirmar_entrega(uuid)
  to authenticated;
grant execute on function papel_atual(), e_equipe(), e_admin(), meu_cliente_id(),
  pode_ver_pedido(uuid), pode_editar_pedido(uuid)
  to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Mensagens automáticas (textos iniciais, editáveis no CRM)
-- ---------------------------------------------------------------------------

insert into mensagem_modelos (chave, status_gatilho, texto) values
  ('pedido_recebido', 'novo', 'Oi, {nome}! Recebemos o seu pedido #{numero} na GL Sports ⚽ Em breve enviamos o orçamento por aqui.'),
  ('orcamento_enviado', 'orcamento_enviado', 'Oi, {nome}! O orçamento do pedido #{numero} está pronto. Confira e aprove no site: {link}'),
  ('arte_enviada', 'arte_em_aprovacao', 'Oi, {nome}! A arte do pedido #{numero} está pronta para você aprovar: {link}'),
  ('lista_pendente', 'aguardando_lista', 'Oi, {nome}! Arte aprovada ✅ Agora falta preencher os nomes, números e tamanhos do pedido #{numero}: {link}'),
  ('sinal_pendente', 'aguardando_sinal', 'Oi, {nome}! Tudo certo com o pedido #{numero}. Para começar a produção, falta o sinal. Pix e detalhes: {link}'),
  ('em_producao', 'em_producao', 'Oi, {nome}! O pedido #{numero} entrou em produção 🔥'),
  ('pronto', 'pronto', 'Oi, {nome}! O pedido #{numero} está pronto! Vamos combinar o envio ou a retirada?'),
  ('enviado', 'enviado', 'Oi, {nome}! O pedido #{numero} foi enviado 🚚 Acompanhe: {link}'),
  ('entregue', 'entregue', 'Oi, {nome}! Esperamos que tenha gostado das camisas do pedido #{numero}! Se puder, deixe sua avaliação no Google: {link}');
