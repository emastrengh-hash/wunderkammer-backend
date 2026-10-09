import { chat } from "./openrouter.js";
import { CURATORE_SYSTEM_PROMPT } from "./prompt.js";

export type Frammento = { id?: string; tipo: string; titolo: string; nota?: string };
export type Memoria = { frammenti: Frammento[] };

export async function generaFilo(esperienza: string, memoria: Memoria) {
  const memoriaTesto = memoria.frammenti
    .map((f) => `- [ID: ${f.id}] [${f.tipo}] ${f.titolo}${f.nota ? `: ${f.nota}` : ""}`)
    .join("\n");

  const messaggioUtente = [
    `Nuova esperienza dell'utente: "${esperienza}"`,
    ``,
    `Memoria rilevante dell'utente:`,
    memoriaTesto,
    ``,
    `Genera il filo del Curatore. Ricorda: se nel tuo "percorso" crei un ancoraggio usando una di queste memorie, devi obbligatoriamente inserire il suo ID esatto nel campo "id_riferimento".`,
  ].join("\n");

  try {
        const risposta = await chat([{ role: "system", content: CURATORE_SYSTEM_PROMPT }, { role: "user", content: messaggioUtente }], { responseFormatJson: true, temperature: 0.8 });
        return JSON.parse(risposta);
    } catch (error: any) {
        return {
            apertura_maieutica: "Il filo dei miei pensieri si è aggrovigliato. Concedimi un momento.",
            percorso: [{ ordine: 1, direzione: "attesa", titolo: "Pausa", pillola: "La memoria ha bisogno di riposare." }],
            produzione_attiva: { attiva: false, motivo: "Errore di connessione." }
        };
    }
}

export async function generaTitolo(testo: string): Promise<string> {
    try {
        const promptSystema = `Sei un curatore minimale e poetico. Restituisci SOLO un JSON: { "titolo": "Il tuo titolo di max 3 parole" }`;
        const risposta = await chat([{ role: "system", content: promptSystema }, { role: "user", content: `Pensiero: "${testo}"` }], { responseFormatJson: true, temperature: 0.7 });
        return (JSON.parse(risposta).titolo || "Riflessione").replace(/^["']|["']$/g, '').trim(); 
    } catch (error: any) { return "Nuovo Pensiero"; }
}

export async function generaRabbitHole(testoOrigine: string, scopertePassate: string[] = []) {
    try {
        const regolaEsclusione = scopertePassate.length > 0 ? `REGOLA: NON usare mai questi argomenti già noti: ${scopertePassate.join(", ")}.` : "";
        const promptSystema = `
            Sei un Esploratore della Conoscenza Totale. Trova un "Isomorfismo Culturale" con il pensiero dell'utente. Nessun limite di dominio.
            ${regolaEsclusione}
            Restituisci SOLO JSON:
            {
                "titolo_nozione": "Titolo (max 4 parole)",
                "contenuto_nozione": "Spiegazione affascinante (max 3 frasi)",
                "spiegazione_filo": "Collegamento al pensiero dell'utente (max 2 frasi)",
                "sfida_cognitiva": "Una domanda aperta o una riflessione intrigante per spingere l'utente a intuire il collegamento (max 2 frasi, NO indovinelli banali)"
            }
        `;
        const risposta = await chat([{ role: "system", content: promptSystema }, { role: "user", content: `Pensiero: "${testoOrigine}"` }], { responseFormatJson: true, temperature: 0.95 });
        return JSON.parse(risposta);
    } catch (error: any) { throw new Error("Il Polimata è confuso."); }
}

export async function generaMistero(scopertePassate: string[] = []) {
    try {
        const regolaEsclusione = scopertePassate.length > 0 ? `Evita questi argomenti: ${scopertePassate.join(", ")}.` : "";
        const promptSystema = `
            Sei il Custode della Wunderkammer. Il tuo raggio d'azione è l'intero scibile umano.
            Devi creare un "Frammento Sospeso". Inizia a raccontare una storia vera, un fatto affascinante o un paradosso, ma INTERROMPI la narrazione sul più bello. 
            ${regolaEsclusione}
            Restituisci SOLO JSON:
            {
                "titolo": "Titolo suggestivo (max 3 parole)",
                "premessa": "L'inizio dell'aneddoto o del paradosso, che si interrompe ponendo una domanda stimolante all'utente su come prosegue o qual è il senso (max 4 frasi).",
                "verita_nascosta": "La spiegazione reale e la conclusione sorprendente del fenomeno (max 4 frasi)."
            }
        `;
        const risposta = await chat([{ role: "system", content: promptSystema }], { responseFormatJson: true, temperature: 0.95 });
        return JSON.parse(risposta);
    } catch (error: any) { throw new Error("I misteri sono temporaneamente svaniti."); }
}

export async function valutaIntuizione(contesto: string, soluzioneReale: string, rispostaUtente: string) {
    try {
        const promptSystema = `
            Sei un maestro di Maieutica Socratica. L'utente sta cercando di dedurre un concetto.
            Premessa/Sfida: "${contesto}"
            La Verità Reale: "${soluzioneReale}"
            Valuta la risposta dell'utente. Premia il ragionamento laterale o lo sforzo logico.
            Se l'utente si avvicina o ha una bella intuizione (anche parziale): superato = true.
            Se l'utente è completamente fuori strada o dice "non lo so": superato = false.
            Restituisci SOLO JSON:
            {
                "superato": true/false,
                "risposta_maieutica": "Se superato: Elogia l'intuizione e svela la verità completa. Se NON superato: Incoraggialo, NON dare la soluzione, ma offri un NUOVO indizio molto più esplicito."
            }
        `;
        const risposta = await chat([{ role: "system", content: promptSystema }, { role: "user", content: `Risposta dell'utente: "${rispostaUtente}"` }], { responseFormatJson: true, temperature: 0.7 });
        return JSON.parse(risposta);
    } catch (error) {
        return { superato: true, risposta_maieutica: "L'intuizione è preziosa. La verità era: " + soluzioneReale };
    }
}

// --------------------------------------------------------
// FUNZIONE DEEP DIVE (Saggista Enciclopedico)
// --------------------------------------------------------
export async function generaDeepDive(titolo: string, contenutoBase: string) {
    try {
        const promptSystema = `
            Sei un saggista enciclopedico di immenso spessore. L'utente vuole compiere un "Deep Dive" (un'immersione verticale approfondita) su un concetto scoperto nella sua Wunderkammer.
            Concetto: "${titolo}"
            Pillola di partenza: "${contenutoBase}"
            
            Scrivi un saggio approfondito, strutturato e denso, diviso in paragrafi con chiari capoversi, che esplori le origini storiche, i meccanismi profondi, le implicazioni filosofiche/scientifiche e un esempio illuminante di questo concetto. 
            Sii rigoroso, affascinante, colto e dettagliato (lunghezza ideale: 4-5 paragrafi ricchi e stimolanti).
            
            Restituisci SOLO un JSON valido strutturato così:
            {
                "titolo_saggio": "Titolo esteso e solenne del saggio",
                "testo_saggio": "Il saggio completo suddiviso in paragrafi (usa \n\n per separare i paragrafi)."
            }
        `;
        const risposta = await chat(
            [
                { role: "system", content: promptSystema },
                { role: "user", content: `Approfondisci il concetto: ${titolo}` },
            ],
            { responseFormatJson: true, temperature: 0.8 }
        );
        return JSON.parse(risposta);
    } catch (error: any) {
        console.error("⚠️ [Errore Deep Dive]:", error.message || error);
        throw new Error("Il saggista è momentaneamente irraggiungibile.");
    }
}