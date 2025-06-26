// ~/supabase/docker/volumes/functions/authenticate-unibo-user/index.ts

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { SignJWT } from 'https://esm.sh/jose@4.14.4'

console.log("Funzione 'authenticate-unibo-user' (v3 - Invite Token) caricata.");

const corsHeaders = { 
  'Access-Control-Allow-Origin': '*', 
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' 
};

async function createServiceRoleToken() {
  const jwtSecret = Deno.env.get('JWT_SECRET');
  if (!jwtSecret) throw new Error('JWT_SECRET non trovato.');
  const secret = new TextEncoder().encode(jwtSecret);
  return await new SignJWT({ role: 'service_role' })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime('1h')
    .sign(secret);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') { 
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { email } = await req.json();
    if (!email) throw new Error('Email non fornita.');

    const uniboDomains = ['@unibo.it', '@studio.unibo.it'];
    if (!uniboDomains.some(domain => email.endsWith(domain))) {
      throw new Error('Email non appartiene ai domini autorizzati Unibo.');
    }

    const serviceToken = await createServiceRoleToken();
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');
    if (!supabaseAnonKey) throw new Error('SUPABASE_ANON_KEY non trovata.');
    
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      supabaseAnonKey,
      { global: { headers: { Authorization: `Bearer ${serviceToken}` } } }
    );

    // 1. Controlla se l'utente esiste già
    let { data: { users } } = await supabaseAdmin.auth.admin.listUsers({ email: email });
    let authUser = users.length > 0 ? users[0] : null;
    let userExists = !!authUser;

    const passwordIsSet = authUser?.app_metadata?.has_set_password === true;

    // Se l'utente esiste e ha già una password, deve fare il login standard
    if (userExists && passwordIsSet) {
      console.log(`[authenticate-unibo-user] Utente esistente con password: ${email}`);
      return new Response(
        JSON.stringify({ user_exists: true, password_set: true }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Se l'utente non esiste, crealo
    if (!authUser) {
      console.log(`[authenticate-unibo-user] Creando nuovo utente Unibo: ${email}`);
      const { data: { user: newUser }, error: createError } = await supabaseAdmin.auth.admin.createUser({ 
        email: email, 
        email_confirm: true,
        app_metadata: { domain: email.split('@')[1], user_type: 'unibo' }
      });
      
      if (createError) throw createError;
      authUser = newUser;
    }

    // 2. Genera un link di invito per l'utente (nuovo o esistente senza password)
    console.log(`[authenticate-unibo-user] Generando link di invito per: ${email}`);
    const { data, error: linkError } = await supabaseAdmin.auth.admin.generateLink({
      type: 'invite',
      email: email,
    });
    if (linkError) throw linkError;

    // 3. Estrai il token dal link generato
    const url = new URL(data.properties.action_link);
    const hashParams = new URLSearchParams(url.hash.substring(1)); // Rimuovi il '#'
    const token = hashParams.get('access_token');

    if (!token) {
      throw new Error('Impossibile estrarre il token dal link di invito.');
    }

    console.log(`[authenticate-unibo-user] Token di invito generato per: ${email}`);

    // 4. Restituisci il token al client
    return new Response(
      JSON.stringify({
        user_exists: userExists,
        password_set: false,
        invite_token: token,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error("[authenticate-unibo-user] ERRORE:", error.message);
    return new Response(
      JSON.stringify({ error: error.message }), 
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    );
  }
});