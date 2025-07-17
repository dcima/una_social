import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

// Definisci l'email di test dove ricevere tutto.
const TEST_RECIPIENT_EMAIL = "diego.cimarosa@gmail.com"; 
// Leggi una variabile d'ambiente per capire se sei in sviluppo o produzione.
// Aggiungi ENV_MODE="development" al tuo file .env.dev
const ENV_MODE = Deno.env.get("ENV_MODE") ?? "production";

// --- FINE MODIFICHE ---

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "re_k8x6KEAD_7YaSAzUMygXqv3cy63XCKC8b";
const SENDER_EMAIL = Deno.env.get("SENDER_EMAIL") ?? "Una Social <onboarding@resend.dev>";

serve(async (req) => {
  try {
    const payload = await req.clone().json();
    const originalUserEmail = payload.user.email; 
    //const email = payload.user.email;
    const otp = payload.email_data.token; // Il token ora è il codice OTP
    const type = payload.email_data.email_action_type;

  // --- INIZIO MODIFICHE ---

    // Se siamo in modalità sviluppo, tutte le email vengono inviate all'indirizzo di test.
    // Altrimenti, vengono inviate all'utente reale (questo funzionerà solo in produzione).
    const recipientEmail = ENV_MODE === "development" ? TEST_RECIPIENT_EMAIL : originalUserEmail;

    let subject = "";
    let htmlBody = "";

    switch (type) {
      case 'signup':
        // Personalizza l'oggetto per capire subito chi si sta registrando
        subject = `[TEST] Codice di verifica per ${originalUserEmail}`;
        // Personalizza il corpo dell'email come richiesto
        htmlBody = `
          <h1>Benvenuto/a ${originalUserEmail} in Una Social!</h1>
          <p>Grazie per esserti registrato/a. Inserisci questo codice nella app per confermare il tuo account:</p>
          <p style="font-size: 24px; font-weight: bold; letter-spacing: 5px; text-align: center;">${otp}</p>
          <hr>
          <p style="font-size: 12px; color: #888;">Questa è un'email di test. In produzione, sarebbe stata inviata a ${originalUserEmail}.<br>Destinatario effettivo per il test: ${recipientEmail}.</p>
        `;
        break;
      // ... altri casi se necessario ...
      default:
        throw new Error(`Tipo di email non gestito: ${type}`);
    }

    const resendPayload = {
        from: SENDER_EMAIL,
        to: recipientEmail, // Usa il destinatario che abbiamo deciso (quello di test)
        subject,
        html: htmlBody,
    };

    // --- INIZIO CORREZIONE 2 ---
    // Il body della richiesta fetch deve usare il `resendPayload` che abbiamo appena costruito.
    const resendResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${RESEND_API_KEY}` },
      body: JSON.stringify(resendPayload), // <-- USARE resendPayload QUI
    });
    // --- FINE CORREZIONE 2 ---

    if (!resendResponse.ok) {
      const errorBody = await resendResponse.text();
      // Log più dettagliato
      console.error(`Errore invio email con Resend a ${recipientEmail}. Payload:`, JSON.stringify(resendPayload));
      throw new Error(`Errore invio email con Resend: ${errorBody}`);
    }
    
    console.log(`Email di tipo '${type}' per ${originalUserEmail} inviata con successo a ${recipientEmail}.`);
    return new Response("{}", { status: 200, headers: { "Content-Type": "application/json" } });

  } catch (e) {
    console.error('Errore generico nella funzione:', e.message);
    return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});