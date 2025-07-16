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

    // Usa il metodo standard `signUp`.
    // Questo creerà l'utente ma NON lo confermerà, inviando l'email di conferma
    // che verrà gestita dal tuo hook "custom-email-sender".
    const { data, error } = await supabaseAdmin.auth.signUp({
      email: email,
      password: password,
    })

    if (error) {
      console.error('Errore da Supabase durante la registrazione:', error.message);
      
      if (error.message.includes('User already registered')) {
        return new Response(JSON.stringify({ error: 'Un utente con questa email è già registrato.' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 409, // Conflict
        })
      }
      
      return new Response(JSON.stringify({ error: error.message }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: error.status || 400,
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
    console.error('Errore generico nella funzione:', e.message);
    return new Response(JSON.stringify({ error: 'Errore interno del server' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})