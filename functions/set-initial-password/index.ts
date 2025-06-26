// ~/supabase/docker/volumes/functions/set-initial-password/index.ts

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { SignJWT } from 'https://esm.sh/jose@4.14.4'

console.log("Funzione 'set-initial-password' (v3 - Solo Impostazione) caricata.");

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
    const { email, password } = await req.json();
    
    if (!email || !password || password.length < 6) {
      throw new Error('Email e una password di almeno 6 caratteri sono obbligatori.');
    }

    const serviceToken = await createServiceRoleToken();
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');
    if (!supabaseAnonKey) throw new Error('SUPABASE_ANON_KEY non trovata.');
    
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      supabaseAnonKey,
      { global: { headers: { Authorization: `Bearer ${serviceToken}` } } }
    );

    // 1. Trova l'utente esistente
    const { data: { users } } = await supabaseAdmin.auth.admin.listUsers({ email: email });
    const authUser = users.length > 0 ? users[0] : null;

    if (!authUser) {
      throw new Error('Utente non trovato. Effettua prima la verifica dell\'email Unibo.');
    }

    // 2. Imposta la password per l'utente e aggiorna i metadati
    console.log(`[set-initial-password] Impostando password per utente: ${email}`);
    const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
      authUser.id,
      {
        password: password,
        app_metadata: {
          ...authUser.app_metadata,
          has_set_password: true,
        }
      }
    );

    if (updateError) {
      console.error(`[set-initial-password] Errore aggiornamento utente: ${updateError.message}`);
      throw updateError;
    }

    console.log(`[set-initial-password] Password impostata con successo per: ${email}`);

    // 3. Restituisci un messaggio di successo. Il client si occuperà del login.
    return new Response(
      JSON.stringify({
        success: true,
        message: 'Password impostata con successo. Ora puoi effettuare il login.',
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error("[set-initial-password] ERRORE:", error.message);
    return new Response(
      JSON.stringify({ error: error.message }), 
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
        status: 400 
      }
    );
  }
});