import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { Resend } from 'https://esm.sh/resend@3.2.0'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { invited_email } = await req.json();
    if (!invited_email) throw new Error("Email dell'invitato è richiesta.");

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );
    
    const resend = new Resend(Deno.env.get('RESEND_API_KEY'));
    const userRes = await supabaseAdmin.auth.getUser();
    if (userRes.error) throw userRes.error;
    const inviter = userRes.data.user;

    // 1. Controlla se l'utente è già registrato
    const { data: existingUser } = await supabaseAdmin.from('users').select('id').eq('email', invited_email).single();
    if (existingUser) {
        return new Response(JSON.stringify({ message: 'Questo utente è già registrato.' }), { status: 409 });
    }

    // 2. Crea un token di invito univoco
    const token = crypto.randomUUID();

    // 3. Salva l'invito nel database
    const { error: inviteError } = await supabaseAdmin.from('invites').insert({
      inviter_id: inviter.id,
      invited_email: invited_email,
      token: token,
      status: 'pending'
    });

    if (inviteError) throw inviteError;

    // 4. Invia l'email con Resend
    // Assicurati di aver verificato il dominio su Resend per inviare da un'email personalizzata!
    await resend.emails.send({
        from: 'Una Social <onboarding@uno-alla-luna.it>', // Usa il tuo dominio verificato
        to: invited_email,
        subject: `${inviter.email} ti ha invitato su Una Social!`,
        html: `<h1>Sei stato invitato!</h1><p>Ciao! ${inviter.email} ti sta invitando a unirti a Una Social, la nuova app per la community universitaria. Clicca qui per unirti!</p><p><a href="https://una-social.uno-alla-luna.it/invite?token=${token}">Accetta l'invito</a></p>`
    });

    return new Response(JSON.stringify({ message: 'Invito inviato con successo!' }), {
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