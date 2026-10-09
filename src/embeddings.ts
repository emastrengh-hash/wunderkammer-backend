import 'dotenv/config';

export async function getEmbedding(text: string): Promise<number[]> {
    const response = await fetch("https://openrouter.ai/api/v1/embeddings", {
        method: "POST",
        headers: {
            "Authorization": `Bearer ${process.env.OPENROUTER_API_KEY}`,
            "Content-Type": "application/json"
        },
        body: JSON.stringify({
            model: "openai/text-embedding-3-small",
            input: text
        })
    });

    const data = await response.json();
    
    if (!response.ok) {
        throw new Error(`❌ Errore generazione embedding: ${JSON.stringify(data)}`);
    }

    return data.data[0].embedding;
}