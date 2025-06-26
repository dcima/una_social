// ~/supabase/docker/volumes/functions/create-invite/index.ts

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

console.log("Funzione 'create-invite' caricata.");

const corsHeaders = { 
  'Access-Control-Allow-Origin': '*', 
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' 
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') { 
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 1. Ottieni l'utente che sta facendo la richiesta dal token di autenticazione
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) throw new Error('Manca il token di autorizzazione.');
    
    // Crea un client Supabase per validare il token JWT e ottenere l'utente
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '', 
      Deno.env.get('SUPABASE_ANON_KEY') ?? '', {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user: inviterUser }, error: userError } = await supabaseClient.auth.getUser();
    if (userError) throw userError;

    // 2. Estrai l'email dell'invitato dal corpo della richiesta
    const { invited_email } = await req.json();
    if (!invited_email) throw new Error('Email dell\'invitato non fornita.');

    // 3. Crea un client Admin per eseguire operazioni privilegiate
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // 4. Genera il link di invito usando il ruolo di servizio
    const { data, error: linkError } = await supabaseAdmin.auth.admin.generateLink({
      type: 'invite',
      email: invited_email,
    });
    if (linkError) throw linkError;

    // 5. Estrai il token dal link
    const url = new URL(data.properties.action_link);
    const token = url.searchParams.get('token');
    if (!token) throw new Error('Impossibile estrarre il token dal link di invito.');

    // 6. Salva l'invito nella tabella `invites`
    const { error: dbError } = await supabaseAdmin.from('invites').insert({
      inviter_id: inviterUser.id,
      invited_email: invited_email,
      token: token,
      status: 'pending'
    });
    if (dbError) throw dbError;
    
    console.log(`[create-invite] Invito creato da ${inviterUser.email} per ${invited_email}`);

    // 7. Restituisci il token al client
    return new Response(
      JSON.stringify({ invite_token: token }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error("[create-invite] ERRORE:", error.message);
    return new Response(
      JSON.stringify({ error: error.message }), 
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    );
  }
});