// Edge Function "equipe": cria e gerencia os logins da equipe do CRM.
// Só master e admin podem chamar. O admin só gerencia vendedores; o master gerencia todos.
//
// POST /functions/v1/equipe   (com o token de quem está logado no CRM)
//   { "acao": "criar", "email": "...", "senha": "...", "nome": "...", "papel": "vendedor" }
//   { "acao": "redefinir_senha", "id": "<uuid>", "senha": "..." }
//   { "acao": "ativar" | "desativar", "id": "<uuid>" }
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const resposta = (status: number, corpo: unknown) =>
  new Response(JSON.stringify(corpo), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return resposta(405, { erro: "Use POST" });

  const url = Deno.env.get("SUPABASE_URL")!;
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  // Quem está chamando?
  const token = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
  const { data: quem } = await admin.auth.getUser(token);
  if (!quem?.user) return resposta(401, { erro: "Faça login no CRM" });
  const { data: perfil } = await admin.from("perfis").select("papel, ativo").eq("id", quem.user.id).single();
  if (!perfil?.ativo || !["master", "admin"].includes(perfil.papel)) {
    return resposta(403, { erro: "Só o master ou um admin pode gerenciar a equipe" });
  }

  const corpo = await req.json().catch(() => ({}));
  const podeGerenciar = (papel: string) => perfil.papel === "master" || papel === "vendedor";

  if (corpo.acao === "criar") {
    const { email, senha, nome } = corpo;
    const papel = corpo.papel ?? "vendedor";
    if (!email || !senha || !nome) return resposta(400, { erro: "Informe nome, e-mail e senha" });
    if (String(senha).length < 10) return resposta(400, { erro: "A senha precisa ter pelo menos 10 caracteres" });
    if (!["master", "admin", "vendedor"].includes(papel)) return resposta(400, { erro: "Papel inválido" });
    if (!podeGerenciar(papel)) return resposta(403, { erro: "Admin só pode criar vendedores" });

    const { data: novo, error } = await admin.auth.admin.createUser({
      email,
      password: senha,
      email_confirm: true,
      user_metadata: { tipo_conta: "equipe", nome }, // "equipe" impede que vire cliente
    });
    if (error) return resposta(400, { erro: error.message });
    const { error: erroPerfil } = await admin.from("perfis").insert({ id: novo.user.id, nome, papel });
    if (erroPerfil) {
      await admin.auth.admin.deleteUser(novo.user.id);
      return resposta(400, { erro: erroPerfil.message });
    }
    return resposta(200, { id: novo.user.id });
  }

  // As outras ações agem sobre um membro existente.
  const { data: alvo } = await admin.from("perfis").select("papel").eq("id", corpo.id ?? "").single();
  if (!alvo) return resposta(404, { erro: "Membro não encontrado" });
  if (!podeGerenciar(alvo.papel)) return resposta(403, { erro: "Admin só pode gerenciar vendedores" });
  if (corpo.id === quem.user.id && corpo.acao === "desativar") {
    return resposta(400, { erro: "Você não pode desativar o próprio acesso" });
  }

  if (corpo.acao === "redefinir_senha") {
    if (String(corpo.senha ?? "").length < 10) return resposta(400, { erro: "A senha precisa ter pelo menos 10 caracteres" });
    const { error } = await admin.auth.admin.updateUserById(corpo.id, { password: corpo.senha });
    return error ? resposta(400, { erro: error.message }) : resposta(200, { ok: true });
  }

  if (corpo.acao === "ativar" || corpo.acao === "desativar") {
    const ativo = corpo.acao === "ativar";
    await admin.from("perfis").update({ ativo }).eq("id", corpo.id);
    // Desativado: bloqueia o login também.
    await admin.auth.admin.updateUserById(corpo.id, { ban_duration: ativo ? "none" : "876000h" });
    return resposta(200, { ok: true });
  }

  return resposta(400, { erro: "Ação desconhecida" });
});
