// VERSIONE DEBUG - USA SOLO PER TESTARE

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { SignJWT } from 'https://esm.sh/jose@4.14.4'

console.log("Funzione 'ensure-personale' (DEBUG) caricata.");

const corsHeaders = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' };

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
  if (req.method === 'OPTIONS') { return new Response('ok', { headers: corsHeaders }) }

  try {
    const { email } = await req.json();
    if (!email) {
      throw new Error('Email non fornita.');
    }

    const serviceToken = await createServiceRoleToken();
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');
    if (!supabaseAnonKey) throw new Error('SUPABASE_ANON_KEY non trovata.');
    
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      supabaseAnonKey,
      { global: { headers: { Authorization: `Bearer ${serviceToken}` } } }
    );

    // 1. Controlla se l'utente è nel personale
    const { data: personaleData } = await supabaseAdmin.from('personale').select('email_principale').eq('email_principale', email).single();
    if (!personaleData) {
      return new Response(JSON.stringify({ exists_in_personale: false }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }
    
    // 2. Controlla se l'utente esiste in auth.users
    let { data: { users } } = await supabaseAdmin.auth.admin.listUsers({ email: email });
    let authUser = users.length > 0 ? users[0] : null;
    
    let userWasCreated = false;
    if (!authUser) {
      console.log(`[DEBUG] Utente non trovato, lo creo...`);
      const { data: { user: newUser }, error: createError } = await supabaseAdmin.auth.admin.createUser({ 
        email: email, 
        email_confirm: true 
      });
      if (createError) throw createError;
      authUser = newUser;
      userWasCreated = true;
    }

    // 3. DEBUG: Stampa TUTTO quello che sappiamo sull'utente
    console.log(`[DEBUG] === INFORMAZIONI UTENTE ${email} ===`);
    console.log(`[DEBUG] ID: ${authUser!.id}`);
    console.log(`[DEBUG] created_at: ${authUser!.created_at}`);
    console.log(`[DEBUG] last_sign_in_at: ${authUser!.last_sign_in_at}`);
    console.log(`[DEBUG] email_confirmed_at: ${authUser!.email_confirmed_at}`);
    console.log(`[DEBUG] app_metadata: ${JSON.stringify(authUser!.app_metadata)}`);
    console.log(`[DEBUG] user_metadata: ${JSON.stringify(authUser!.user_metadata)}`);
    console.log(`[DEBUG] userWasCreated: ${userWasCreated}`);
    
    // 4. Logica per determinare se ha password
    let passwordIsSet = false;
    let reasoning = "";
    
    if (userWasCreated) {
      passwordIsSet = false;
      reasoning = "Utente appena creato - nessuna password";
    } else if (authUser!.last_sign_in_at !== null) {
      passwordIsSet = true;
      reasoning = "Ha fatto login almeno una volta";
    } else if (authUser!.app_metadata?.has_set_password === true) {
      passwordIsSet = true;
      reasoning = "Metadati indicano password impostata";
    } else {
      passwordIsSet = false;
      reasoning = "Nessuna evidenza di password impostata";
    }
    
    console.log(`[DEBUG] passwordIsSet: ${passwordIsSet} (${reasoning})`);

    return new Response(
      JSON.stringify({
          exists_in_personale: true,
          password_set: passwordIsSet,
          debug: {
            user_id: authUser!.id,
            last_sign_in_at: authUser!.last_sign_in_at,
            app_metadata: authUser!.app_metadata,
            user_was_created: userWasCreated,
            reasoning: reasoning
          }
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error("[DEBUG] ERRORE:", error.message);
    return new Response(JSON.stringify({ error: error.message }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 });
  }
});
