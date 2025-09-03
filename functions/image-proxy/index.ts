// supabase/functions/image-proxy/index.ts

// Importa il modulo 'serve' da Deno per creare un server HTTP
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

// Funzione principale che verrà eseguita quando la Edge Function riceve una richiesta
serve(async (req) => {
  // Parsa l'URL della richiesta in arrivo per estrarre i parametri
  const url = new URL(req.url)
  // Recupera il valore del parametro 'url' dalla query string (es: ?url=https://...)
  const imageUrl = url.searchParams.get('url')

  // Se l'URL dell'immagine non è stato fornito, restituisci un errore 400
  if (!imageUrl) {
    return new Response(JSON.stringify({ error: 'Missing image URL' }), {
      headers: { 'Content-Type': 'application/json' },
      status: 400,
    })
  }

  try {
    // Effettua la richiesta HTTP all'URL dell'immagine originale
    const response = await fetch(imageUrl)

    // Controlla se la risposta è OK e se ha un Content-Type valido
    if (!response.ok || !response.headers.get('Content-Type')) {
      return new Response(JSON.stringify({ error: 'Failed to fetch image or invalid content type from origin' }), {
        headers: { 'Content-Type': 'application/json' },
        status: response.status,
      })
    }

    // Crea nuovi header per la risposta, copiando il Content-Type originale
    const headers = new Headers();
    headers.set('Content-Type', response.headers.get('Content-Type')!);
    // Imposta l'header 'Access-Control-Allow-Origin' a '*' per consentire tutte le origini.
    // In un ambiente di produzione, potresti volerlo restringere all'origine della tua app Flutter Web.
    headers.set('Access-Control-Allow-Origin', '*');
    // Specifica i metodi HTTP consentiti
    headers.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
    // Specifica gli header consentiti
    headers.set('Access-Control-Allow-Headers', 'Content-Type');

    // Restituisci il corpo della risposta dell'immagine con i nuovi header
    return new Response(response.body, {
      status: response.status,
      headers: headers,
    })
  } catch (error: any) { // Specifica 'any' per accedere a 'error.message'
    console.error('Error fetching image:', error)
    // In caso di errore durante il fetching, restituisci un errore 500
    return new Response(JSON.stringify({ error: `Internal server error: ${error.message}` }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})