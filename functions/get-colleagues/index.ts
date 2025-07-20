import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // 1. Ottieni l'utente dalla richiesta (protetta da JWT)
    const userRes = await supabaseAdmin.auth.getUser();
    if (userRes.error) throw userRes.error;
    const user = userRes.data.user;

    // 2. Trova la struttura dell'utente in public.personale
    const { data: userData, error: userError } = await supabaseAdmin
      .from('personale')
      .select('struttura')
      .eq('email_principale', user.email)
      .single();

    if (userError || !userData || !userData.struttura) {
      return new Response(JSON.stringify({ error: 'Utente non trovato nel personale o senza struttura.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 404,
      });
    }

    // 3. Trova tutti i colleghi nella stessa struttura, escludendo l'utente stesso
    const { data: colleagues, error: colleaguesError } = await supabaseAdmin
      .from('personale')
      .select('cognome, nome, email_principale')
      .eq('struttura', userData.struttura)
      .neq('email_principale', user.email);

    if (colleaguesError) throw colleaguesError;

    return new Response(JSON.stringify(colleagues), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});