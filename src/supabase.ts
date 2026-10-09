import { createClient } from '@supabase/supabase-js';
import 'dotenv/config'; // Assicuriamoci che legga il file .env

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_ANON_KEY;

// Controllo di sicurezza se mancano i dati nel .env
if (!supabaseUrl || !supabaseKey) {
    throw new Error("⚠️ Mancano le credenziali SUPABASE_URL o SUPABASE_ANON_KEY nel file .env");
}

// Creiamo e esportiamo il client che useremo nel resto dell'app
export const supabase = createClient(supabaseUrl, supabaseKey);