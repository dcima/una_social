import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "re_k8x6KEAD_7YaSAzUMygXqv3cy63XCKC8b";
const SENDER_EMAIL = Deno.env.get("SENDER_EMAIL") ?? "Una Social <onboarding@resend.dev>";

serve(async (req) => {
  try {
    const payload = await req.clone().json();
    const email = payload.user.email;
    const otp = payload.email_data.token; // Il token ora è il codice OTP
    const type = payload.email_data.email_action_type;

    let subject = "";
    let htmlBody = "";

    switch (type) {
      case 'signup':
        subject = "Il tuo codice di verifica per Una Social";
        htmlBody = `
          <h1>Benvenuto in Una Social!</h1>
          <p>Grazie per esserti registrato. Inserisci questo codice nella app per confermare il tuo account:</p>
          <p style="font-size: 24px; font-weight: bold; letter-spacing: 5px; text-align: center;">${otp}</p>
        `;
        break;
      // ... altri casi se necessario ...
      default:
        throw new Error(`Tipo di email non gestito: ${type}`);
    }

    const resendResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${RESEND_API_KEY}` },
      body: JSON.stringify({ from: SENDER_EMAIL, to: email, subject, html: htmlBody }),
    });

    if (!resendResponse.ok) {
      const errorBody = await resendResponse.text();
      throw new Error(`Errore invio email con Resend: ${errorBody}`);
    }
    
    return new Response("{}", { status: 200, headers: { "Content-Type": "application/json" } });

  } catch (e) {
    console.error('Errore generico nella funzione:', e.message);
    return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});