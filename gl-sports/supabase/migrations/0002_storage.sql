-- Pastas de arquivos do Supabase Storage (rodar depois do 0001).
-- Caminho dos arquivos: <pedido_id>/<nome-do-arquivo>

insert into storage.buckets (id, name, public) values
  ('artes', 'artes', false),
  ('comprovantes', 'comprovantes', false)
on conflict (id) do nothing;

-- Equipe: envia e vê tudo.
create policy "equipe gerencia artes" on storage.objects for all
  using (bucket_id = 'artes' and public.e_equipe())
  with check (bucket_id = 'artes' and public.e_equipe());
create policy "equipe gerencia comprovantes" on storage.objects for all
  using (bucket_id = 'comprovantes' and public.e_equipe())
  with check (bucket_id = 'comprovantes' and public.e_equipe());

-- Cliente: vê a arte e o comprovante só dos próprios pedidos e pode enviar comprovante.
create policy "cliente ve artes do pedido" on storage.objects for select
  using (bucket_id = 'artes' and public.pode_ver_pedido(((storage.foldername(name))[1])::uuid));
create policy "cliente ve comprovantes do pedido" on storage.objects for select
  using (bucket_id = 'comprovantes' and public.pode_ver_pedido(((storage.foldername(name))[1])::uuid));
create policy "cliente envia comprovante" on storage.objects for insert
  with check (bucket_id = 'comprovantes' and public.pode_ver_pedido(((storage.foldername(name))[1])::uuid));
