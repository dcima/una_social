// ~/supabase/docker/volumes/functions/set-initial-password/index.ts
// VERSIONE FINALE: "Admin Direct-Set & Login"

import { createClient, Session } from 'https://esm.sh/@supabase/supabase-js@2'
import { SignJWT } from 'https://esm.sh/jose@4.14.4'

console.log("Funzione 'set-initial-password' (v3 - con Login) caricata.");

const corsHeaders = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' };
async function createServiceRoleToken() { const jwtSecret = Deno.env.get('JWT_SECRET'); if (!jwtSecret) throw new Error('JWT_SECRET non trovato.'); const secret = new TextEncoder().encode(jwtSecret); return await new SignJWT({ role: 'service_role' }).setProtectedHeader({ alg: 'HS256' }).setIssuedAt().setExpirationTime('1h').sign(secret); }

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') { return new Response('ok', { headers: corsHeaders }) }

  try {
    const { email, password } = await req.json();
    if (!email || !password) throw new Error('Email e password sono richieste.');

    const serviceToken = await createServiceRoleToken();
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');
    if (!supabaseAnonKey) throw new Error('SUPABASE_ANON_KEY non trovata.');
    
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      supabaseAnonKey,
      { global: { headers: { Authorization: `Bearer ${serviceToken}` } } }
    );

    const { data: { users }, error: listError } = await supabaseAdmin.auth.admin.listUsers({ email: email });
    if (listError) throw listError;
    if (users.length === 0) throw new Error('Utente non trovato.');
    
    const userToUpdate = users[0];

    // 1. Imposta la password e conferma l'email
    const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
      userToUpdate.id,
      { password: password, email_confirm: true, app_metadata: { ...userToUpdate.app_metadata, has_set_password: true } }
    );
    if (updateError) throw updateError;
    console.log(`[Admin-Login] Password per ${email} impostata e email confermata.`);

    // 2. GENERA UNA SESSIONE VALIDA PER L'UTENTE
    // Questo è il modo più pulito per ottenere una sessione valida lato server
    const { data: sessionData, error: sessionError } = await supabaseAdmin.auth.signInWithPassword({
        email: email,
        password: password,
    });
    if (sessionError) throw sessionError;
    if (!sessionData.session) throw new Error("Login fallito dopo l'impostazione della password.");

    console.log(`[Admin-Login] Sessione generata con successo per ${email}.`);

    // 3. Restituisci la sessione al client
    return new Response(JSON.stringify({ success: true, session: sessionData.session }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });

  } catch (error) {
    console.error("[Admin-Login] ERRORE CRITICO:", error.message);
    return new Response(JSON.stringify({ error: error.message }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 });
  }
});
