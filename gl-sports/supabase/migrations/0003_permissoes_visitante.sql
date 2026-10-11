-- Visitantes sem login (anon) também passam pelas regras de segurança (RLS),
-- que chamam estas funções. Sem esta permissão, a API responde "permission
-- denied" em vez de simplesmente não mostrar nada.
grant execute on function papel_atual(), e_equipe(), e_admin(), meu_cliente_id(),
  pode_ver_pedido(uuid), pode_editar_pedido(uuid)
  to anon;
