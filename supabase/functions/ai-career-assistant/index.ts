import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const jsonHeaders = { ...corsHeaders, "Content-Type": "application/json" };

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authHeader = request.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) return json({ error: "Authentication required" }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const openAiKey = Deno.env.get("OPENAI_API_KEY");
  if (!supabaseUrl || !anonKey || !openAiKey) return json({ error: "AI service is not configured" }, 503);

  const supabase = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (userError || !user) return json({ error: "Authentication required" }, 401);

  try {
    const body = await request.json();
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      return json({ error: "Malformed request" }, 400);
    }
    const action = typeof body.action === "string" ? body.action.trim() : "";
    const input = body.input && typeof body.input === "object" && !Array.isArray(body.input)
      ? body.input as Record<string, unknown>
      : null;
    if (!input) return json({ error: "Malformed request input" }, 400);
    const prompt = buildPrompt(action, input);
    if (!prompt) return json({ error: "Unsupported AI action" }, 400);

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 30000);
    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      signal: controller.signal,
      method: "POST",
      headers: {
        "Authorization": `Bearer ${openAiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini",
        temperature: action === "cover_letter" ? 0.4 : 0.1,
        response_format: { type: "json_object" },
        messages: [
          {
            role: "system",
            content: "You are a careful job-search assistant. Use only supplied facts. Never invent experience, qualifications, companies, certifications, scores, or skills. Return only valid JSON matching the requested schema.",
          },
          { role: "user", content: prompt },
        ],
      }),
    }).finally(() => clearTimeout(timeout));
    if (!response.ok) return json({ error: "Upstream AI request failed" }, 502);

    const completion = await response.json();
    const content = completion?.choices?.[0]?.message?.content;
    if (typeof content !== "string") return json({ error: "Invalid AI response" }, 502);
    const result = JSON.parse(content);
    return json({ result });
  } catch (error) {
    console.error("ai-career-assistant error", error);
    return json({ error: "Unable to complete AI analysis" }, 500);
  }
});

function buildPrompt(action: string, input: Record<string, unknown>): string | null {
  const data = JSON.stringify(input);
  switch (action) {
    case "job_match":
      return `Evaluate this candidate against this job using only the supplied data. The deterministic_score is context, not permission to invent a result. Return {"match_score": number 0-100, "match_summary": string, "matching_skills": string[], "missing_skills": string[], "matching_qualifications": string[], "missing_qualifications": string[], "experience_match": boolean|null, "recommendations": string[]}. Candidate and job JSON: ${data}`;
    case "skills_gap":
      return `Compare the candidate's skills and resume against the selected job. Return {"existing_skills": string[], "missing_skills": string[], "priority_skills": string[], "recommendations":[{"skill":string,"reason":string,"priority":"high"|"medium"|"low"}]}. Do not recommend skills absent from the job requirements or evidence. JSON: ${data}`;
    case "resume_analysis":
      return `Analyze only the supplied resume text. Return {"technical_skills":string[],"soft_skills":string[],"education":string[],"experience":string[],"certifications":string[],"projects":string[],"strengths":string[],"missing_information":string[],"weaknesses":string[]}. Use empty arrays when absent; do not guess. JSON: ${data}`;
    case "career_assistant":
      return `Answer the user's question using the supplied candidate, resume, job, ATS, and skills-gap data. Return {"answer":string,"actions":string[]}. Do not invent facts. Question and context JSON: ${data}`;
    case "cover_letter":
      return `Write a concise professional cover letter using only supplied candidate and job facts. Return {"cover_letter":string}. Do not invent achievements, employers, certifications, or qualifications. JSON: ${data}`;
    case "search_filters":
    case "job_search_parser":
      return `Extract filters from the query. Return {"keyword":string|null,"work_model":"all"|"remote"|"hybrid"|"on-site","employment_type":"all"|"full-time"|"contract","experience_level":"entry"|"mid"|"senior"|"lead"|"executive"|null,"min_salary":number|null,"max_salary":number|null,"location":string|null,"industry":string|null,"tech_stack":string|null}. Salaries are GHS. Query JSON: ${data}`;
    case "rank_jobs":
    case "job_ranking":
      return `Rank the supplied approved active jobs for the candidate using only supplied evidence. Return {"job_ids":string[]}, containing only supplied IDs, best first. JSON: ${data}`;
    case "match_insight":
    case "match_explanation":
      return `Explain the supplied deterministic job match using only supplied facts. Return {"summary":string}. JSON: ${data}`;
    default:
      return null;
  }
}

function json(value: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(value), { status, headers: jsonHeaders });
}
