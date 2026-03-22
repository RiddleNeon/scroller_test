import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        const formData = await req.formData();
        const file     = formData.get('file') as File | null;
        const language = (formData.get('language') as string | null) ?? 'de';

        if (!file) {
            return new Response(
                JSON.stringify({ success: false, error: 'No file provided' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
            );
        }

        const whisperForm = new FormData();
        whisperForm.append('file', file, file.name);
        whisperForm.append('model', 'whisper-1');
        whisperForm.append('language', language);
        whisperForm.append('response_format', 'verbose_json');
        whisperForm.append('timestamp_granularities[]', 'segment');

        const openAiRes = await fetch('https://api.openai.com/v1/audio/transcriptions', {
            method:  'POST',
            headers: { Authorization: `Bearer ${Deno.env.get('OPENAI_API_KEY')}` },
            body:    whisperForm,
        });

        console.log('OpenAI Status:', openAiRes.status);
        const responseText = await openAiRes.text();
        console.log('OpenAI Response:', responseText);

        if (!openAiRes.ok) {
            return new Response(
                JSON.stringify({ success: false, error: responseText }),
                { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
            );
        }

        const data = JSON.parse(responseText);

        const chunks = (data.segments ?? []).map((s: any) => ({
            text:      s.text.trim(),
            timestamp: [s.start, s.end],
        }));

        return new Response(
            JSON.stringify({ success: true, text: data.text, chunks }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        );
    } catch (e) {
        return new Response(
            JSON.stringify({ success: false, error: (e as Error).message }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        );
    }
});