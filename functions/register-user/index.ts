// File: supabase/functions/register-user/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

console.log('Funzione "register-user" avviata.');

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { email, password } = await req.json()

    if (!email || !password) {
      return new Response(JSON.stringify({ error: 'Email e password sono obbligatorie' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      })
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    )

    const { data, error } = await supabaseAdmin.auth.signUp({
      email: email,
      password: password,
    })

    if (error) {
      // Logga l'intero oggetto errore per maggiori dettagli sul server
      console.error('Errore dettagliato da Supabase durante la registrazione:', JSON.stringify(error, null, 2));

      // Gestione specifica per "User already registered"
      if (error.message.includes('User already registered') || error.message.includes('A user with this email address already exists')) {
        return new Response(JSON.stringify({ error: 'Un utente con questa email è già registrato nel sistema di autenticazione.' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 409, // Conflict
        })
      }

      // Gestione specifica per errori di politica della password
      if (error.message.includes('Password should be at least')) {
        return new Response(JSON.stringify({ error: 'La password non rispetta i requisiti di sicurezza. Deve essere di almeno 6 caratteri.' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400, // Bad Request
        })
      }

      // Per altri errori di AuthApiError, restituisci il messaggio di errore specifico al client
      return new Response(JSON.stringify({ error: error.message || 'Errore generico durante la registrazione dell\'utente.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: error.status || 500, // Usa lo status dell'errore se disponibile, altrimenti 500
      })
    }

    return new Response(JSON.stringify({
      message: 'Registrazione avviata. Controlla la tua email per il link di conferma.',
      user: data.user
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (e) {
    console.error('Errore generico nella funzione:', e instanceof Error ? e.message : e); // Logga il messaggio se è un Error
    return new Response(JSON.stringify({ error: 'Errore interno del server' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})