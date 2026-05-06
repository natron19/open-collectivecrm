# CollectiveCRM Demo

> Add a lead. The agent researches their company. AI writes outreach that references something real.

CollectiveCRM Demo is a locally-runnable Rails 8 app showing the core capability of CollectiveCRM: AI-researched outreach emails for every lead in a 5-stage sales pipeline.

When you trigger outreach generation for a lead, a Gemini agent first researches the company using web search and URL fetching, then writes a personalized email that references something specific and current — a recent funding round, a product launch, an executive hire. The research findings are displayed above the email so you can verify the facts before sending.

## Why I Built This

Generic outreach is ignored. Outreach that says "I saw you just closed your Series A" or "I noticed you launched a new product line last month" gets replies. The bottleneck is the research — it takes 20+ minutes per lead manually, so SDRs skip it.

This demo isolates that single capability as a standalone tool: add a lead, the agent researches them, you get a draft that's actually worth sending. The full production version of CollectiveCRM is multi-tenant with team collaboration and shared pipelines. This demo is open source under MIT, single-user, and runs entirely on localhost.

## Quick Start

```bash
git clone <this-repo>
cd open-collectivecrm
bin/setup
```

Copy the example env file and fill in your keys:

```bash
cp .env.example .env
```

Edit `.env` and set at minimum:

```
GEMINI_API_KEY=your_key_here
```

Then:

```bash
bin/rails db:seed
bin/rails server
```

Visit http://localhost:3000 and sign in with `demo@example.com` / `password123`.

## Gemini API Key

Get a free key at https://aistudio.google.com/app/apikey. The default model is `gemini-2.5-flash`, which has a generous free tier. Under typical demo use you will not incur charges.

## Perplexity API Key (optional)

The AI agent uses [Perplexity](https://www.perplexity.ai) to search the web for recent information about leads. Perplexity returns synthesized answers with citations, which gives the agent better research context than raw search snippets. Without a key the agent falls back to fetching the company website directly — outreach still generates, but without news-based hooks.

To enable web search:

1. Get an API key at https://www.perplexity.ai/settings/api
2. Add your key to `.env`:

```
PERPLEXITY_API_KEY=your_key_here
```

**Privacy note:** When generating outreach, the agent sends the lead's company name and job title to Perplexity as search queries. It does not send email addresses or personal notes. Do not enter home addresses or sensitive personal data in lead records if you are concerned about third-party API exposure.

## Seed Credentials

| Email | Password | Role |
|---|---|---|
| `demo@example.com` | `password123` | Admin |

The seed also creates a SellerProfile, 5 sample leads across all pipeline stages, and one pre-generated outreach email for Priya Nair at Figma so you can see the full UI without running the agent first.

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `APP_NAME` | `"CollectiveCRM Demo"` | Navbar and page title |
| `APP_TAGLINE` | — | Shown on the landing page |
| `APP_DESCRIPTION` | — | Shown on the landing page |
| `GEMINI_API_KEY` | (required) | Google Gemini API key |
| `PERPLEXITY_API_KEY` | — | Perplexity key for web search (optional) |
| `AI_CALLS_PER_USER_PER_DAY` | `20` | Daily AI budget per user (lower than boilerplate default because each outreach generation may use multiple Gemini calls across the agent loop) |
| `AI_GLOBAL_TIMEOUT_SECONDS` | `15` | Timeout for single Gemini calls (health check, etc.) |
| `AI_AGENT_TIMEOUT_SECONDS` | `60` | Timeout for the multi-turn agent loop (research + write) |

## Stack

| Layer | Choice |
|---|---|
| Framework | Rails 8.1 |
| Database | PostgreSQL with UUID primary keys |
| Auth | Rails native (`has_secure_password`, sessions) |
| CSS | Bootstrap 5 dark mode (CDN) |
| JavaScript | Stimulus + Turbo via importmap |
| AI | Google Gemini via Faraday (function calling) |
| Queue / Cache / Cable | Solid Stack (no Redis) |
| Testing | RSpec |

## AI Safety

- Per-user daily call cap (default: 20/day — lower than the boilerplate because each outreach generation may consume multiple Gemini calls across the agent loop)
- Pre-flight gatekeeper: input length limit, prompt injection patterns, profanity filter
- Hard output token cap per template (3,000 tokens)
- Configurable request timeout (default: 15s), agent loop capped at 5 rounds
- Full request log with status, tokens, duration, and cost estimate in `/admin/llm_requests`
- Research summary displayed above every email so you can verify facts before sending
- Source URLs shown as clickable links for one-click verification
- AI disclaimer on the lead page and in the footer on every page
- No automatic email sending — you copy the draft; nothing goes out without your review

## License

MIT — see [LICENSE](LICENSE)
