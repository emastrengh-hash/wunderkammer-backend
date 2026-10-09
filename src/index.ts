import express from 'express';
import cors from 'cors';
import { supabase } from './supabase.js';
import { generaFilo, generaTitolo, generaRabbitHole, generaMistero, valutaIntuizione, generaDeepDive } from './curator.js';
import { getEmbedding } from './embeddings.js';

const app = express();
app.use(cors());
app.use(express.json());

app.post('/api/rifletti', async (req, res) => {
    try {
        const nuovaEsperienza = req.body.testo;
        if (!nuovaEsperienza) return res.status(400).json({ error: "Nessun testo fornito" });
        const [vectorEmbedding, titoloGenerato] = await Promise.all([ getEmbedding(nuovaEsperienza), generaTitolo(nuovaEsperienza) ]);
        const { data: frammentoSalvato, error } = await supabase.from('frammenti').insert([{
            tipo: 'riflessione', titolo: titoloGenerato, contenuto_testuale: nuovaEsperienza, embedding: vectorEmbedding, stato_s: 2
        }]).select();
        if (error || !frammentoSalvato) throw error;
        const nuovoNodoId = frammentoSalvato[0].id;

        const { data: ricordiSimili, error: fetchError } = await supabase.rpc('match_frammenti', { query_embedding: vectorEmbedding, match_count: 3 });
        if (fetchError) throw fetchError;
        const ricordiPassati = ricordiSimili.filter((r: any) => r.id !== nuovoNodoId);
        const memoriaReale = { frammenti: ricordiPassati.map((r: any) => ({ id: r.id, tipo: r.tipo, titolo: r.titolo, nota: r.contenuto_testuale })) };
        const filo = await generaFilo(nuovaEsperienza, memoriaReale);

        if (filo.percorso) {
            for (const tappa of filo.percorso) {
                if (tappa.id_riferimento) await supabase.from('connessioni').insert([{ nodo_origine_id: nuovoNodoId, nodo_destinazione_id: tappa.id_riferimento, spiegazione_curatore: tappa.pillola }]);
            }
        }
        res.json({ success: true, messaggio: filo.apertura_maieutica });
    } catch (err: any) { res.status(500).json({ error: err.message }); }
});

app.post('/api/rabbithole/sfida', async (req, res) => {
    try {
        const { testo_origine } = req.body;
        const { data: scopertePrecedenti } = await supabase.from('frammenti').select('titolo').eq('tipo', 'scoperta');
        const titoliDaEvitare = scopertePrecedenti ? scopertePrecedenti.map((s: any) => s.titolo) : [];
        const rabbitHoleData = await generaRabbitHole(testo_origine, titoliDaEvitare);
        res.json({ success: true, dati: rabbitHoleData });
    } catch (err: any) { res.status(500).json({ error: err.message }); }
});

app.post('/api/rabbithole/sblocca', async (req, res) => {
    try {
        const { id_nodo_origine, dati_polimata, risposta_utente } = req.body;
        const valutazione = await valutaIntuizione(dati_polimata.sfida_cognitiva, dati_polimata.spiegazione_filo, risposta_utente);

        if (!valutazione.superato) {
            return res.json({ success: true, risolto: false, nuovo_indizio: valutazione.risposta_maieutica });
        }

        const vectorEmbedding = await getEmbedding(dati_polimata.contenuto_nozione);
        const { data: scopertaSalvata, error: insertError } = await supabase.from('frammenti').insert([{
            tipo: 'scoperta', titolo: dati_polimata.titolo_nozione, contenuto_testuale: dati_polimata.contenuto_nozione, embedding: vectorEmbedding, stato_s: 2
        }]).select();
        if (insertError || !scopertaSalvata) throw insertError;

        const spiegazioneGenerativa = `La tua intuizione: "${risposta_utente}"\n\nRivelazione: ${valutazione.risposta_maieutica}`;
        await supabase.from('connessioni').insert([{ nodo_origine_id: id_nodo_origine, nodo_destinazione_id: scopertaSalvata[0].id, spiegazione_curatore: spiegazioneGenerativa }]);
        
        res.json({ success: true, risolto: true, id_nuovo_nodo: scopertaSalvata[0].id });
    } catch (err: any) { res.status(500).json({ error: err.message }); }
});

// ROTTA DEEP DIVE
app.post('/api/rabbithole/deepdive', async (req, res) => {
    try {
        const { id_nodo, titolo, contenuto_base } = req.body;
        if (!id_nodo || !titolo) return res.status(400).json({ error: "Dati insufficienti" });

        console.log(`\n📚 Generazione Deep Dive per: "${titolo}"...`);
        const deepDiveData = await generaDeepDive(titolo, contenuto_base);

        const testoCompleto = `${contenuto_base}\n\n--- DEEP DIVE: ${deepDiveData.titolo_saggio} ---\n\n${deepDiveData.testo_saggio}`;
        
        await supabase
            .from('frammenti')
            .update({ contenuto_testuale: testoCompleto })
            .eq('id', id_nodo);

        console.log(`✅ Deep Dive generato e salvato con successo!`);
        res.json({ success: true, saggio: deepDiveData });
    } catch (err: any) {
        console.error("❌ Errore Deep Dive:", err.message);
        res.status(500).json({ error: err.message });
    }
});

app.get('/api/mistero/genera', async (req, res) => {
    try {
        const { data: scopertePrecedenti } = await supabase.from('frammenti').select('titolo').eq('tipo', 'scoperta');
        const titoliDaEvitare = scopertePrecedenti ? scopertePrecedenti.map((s: any) => s.titolo) : [];
        const mistero = await generaMistero(titoliDaEvitare);
        res.json({ success: true, dati: mistero });
    } catch (err: any) { res.status(500).json({ error: err.message }); }
});

app.post('/api/mistero/risolvi', async (req, res) => {
    try {
        const { titolo, premessa, verita_nascosta, risposta_utente, pos_x, pos_y } = req.body;
        const valutazione = await valutaIntuizione(premessa, verita_nascosta, risposta_utente);

        if (!valutazione.superato) {
            return res.json({ success: true, risolto: false, nuovo_indizio: valutazione.risposta_maieutica });
        }

        const testo_completo = `La tua intuizione: "${risposta_utente}"\n\nRivelazione: ${valutazione.risposta_maieutica}`;
        const vectorEmbedding = await getEmbedding(testo_completo);

        const { data: salvato, error } = await supabase.from('frammenti').insert([{
            tipo: 'scoperta', titolo: titolo, contenuto_testuale: testo_completo, embedding: vectorEmbedding, stato_s: 2, pos_x: pos_x, pos_y: pos_y
        }]).select();

        if (error || !salvato) throw error;
        res.json({ success: true, risolto: true, id: salvato[0].id });
    } catch (err: any) { res.status(500).json({ error: err.message }); }
});

// Il cloud userà la sua porta (process.env.PORT), altrimenti sul tuo PC userà la 3000
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => { console.log(`\n🚀 Motore del Curatore in ascolto sulla porta ${PORT}`); });