// File: supabase/functions/register-user/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Header per gestire il CORS (Cross-Origin Resource Sharing)
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

console.log('Funzione "register-user" avviata.');

serve(async (req) => {
  // Gestisce la richiesta pre-flight CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. Estrai email e password dal corpo della richiesta
    const { email, password } = await req.json()

    if (!email || !password) {
      return new Response(JSON.stringify({ error: 'Email e password sono obbligatorie' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      })
    }

    // 2. Crea un client Supabase con privilegi di amministratore
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    )

    // 3. MODIFICA CHIAVE: Usa `auth.admin.createUser` per creare l'utente
    // Questo metodo è disponibile solo per il client admin (service_role).
    const { data, error } = await supabaseAdmin.auth.admin.createUser({
      email: email,
      password: password,
      // Questa proprietà bypassa la conferma via email.
      email_confirm: true,
      // --- MODIFICA CHIAVE ---
      // Imposta i metadati dell'utente direttamente alla creazione.
      user_metadata: {
        has_set_password: true
      }
    })

    // 4. Gestisci gli errori di Supabase (es. utente già esistente)
    if (error) {
      console.error('Errore da Supabase:', error.message);
      
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

    // 5. Restituisci i dati dell'utente creato
    // L'utente è ora attivo, con la password e i metadati corretti.
    return new Response(JSON.stringify({ 
      message: 'Utente registrato con successo!',
      user: data.user 
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200, // OK
    })

  } catch (e) {
    console.error('Errore generico:', e.message);
    return new Response(JSON.stringify({ error: 'Errore interno del server' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})