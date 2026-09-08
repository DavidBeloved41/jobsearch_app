# AI Career Assistant

Deploy this function from the repository root with the Supabase CLI:

```sh
supabase functions deploy ai-career-assistant
supabase secrets set OPENAI_API_KEY=your-key OPENAI_MODEL=gpt-4o-mini
```

The Flutter client invokes `ai-career-assistant` through the authenticated Supabase client. The OpenAI key must exist only as an Edge Function secret. Do not add it to `.env`, Flutter assets, or source control.

The function requires an authenticated Supabase access token and supports these actions:

- `job_match`
- `skills_gap`
- `resume_analysis`
- `career_assistant`
- `cover_letter`
- `search_filters`
- `rank_jobs`
- `match_insight`
