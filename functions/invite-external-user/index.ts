// ~/supabase/docker/volumes/functions/invite-external-user/index.ts

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

console.log("Funzione 'invite-external-user' caricata.");

const corsHeaders = { 
  'Access-Control-Allow-Origin': '*', 
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' 
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') { 
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 1. Crea un client Supabase che agisce per conto dell'utente che ha chiamato la funzione.
    // Questo è FONDAMENTALE per la sicurezza: verifica che la chiamata provenga da un utente loggato.
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    );

    // 2. Ottieni i dati dell'utente che sta effettuando l'invito.
    // Se il token JWT non è valido, questo comando fallirà, proteggendo la funzione.
    const { data: { user: inviterUser }, error: inviterError } = await supabaseClient.auth.getUser();
    if (inviterError) throw inviterError;

    // 3. Estrai l'email dell'utente da invitare dal corpo della richiesta.
    const { invited_email } = await req.json();
    if (!invited_email) {
      throw new Error('Email dell\'utente da invitare non fornita.');
    }

    // 4. Utilizza il client con privilegi di amministratore per inviare l'invito.
    // È necessario perché solo un admin può invitare nuovi utenti.
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '' // Usa la SERVICE_ROLE_KEY per i privilegi di admin
    );

    console.log(`[invite-external-user] L'utente ${inviterUser.email} sta invitando ${invited_email}`);

    // 5. Invia l'invito via email. Passiamo l'email di chi invita nei metadati.
    // Questi dati saranno disponibili nel template dell'email.
    const { error: inviteError } = await supabaseAdmin.auth.admin.inviteUserByEmail(
      invited_email,
      {
        data: { 
          user_type: 'invited_external',
          inviter_email: inviterUser.email, // Dato personalizzato per l'email
        }
      }
    );

    if (inviteError) {
      // Gestisce il caso in cui l'utente esista già
      if (inviteError.message.includes('User already registered')) {
        return new Response(
          JSON.stringify({ message: 'Questo utente è già registrato.' }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 409 } // 409 Conflict
        );
      }
      throw inviteError;
    }

    return new Response(
      JSON.stringify({ success: true, message: `Invito inviato con successo a ${invited_email}` }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error("[invite-external-user] ERRORE:", error.message);
    return new Response(
      JSON.stringify({ error: error.message }), 
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
        status: 400 
      }
    );
  }
});