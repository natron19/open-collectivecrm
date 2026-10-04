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

## Responsible AI

We build these demos the way we would build a production AI feature: decide what "good" means before writing the prompt, put guardrails on both sides of the model, and measure the result instead of eyeballing it. This is a small, single-feature demo, so every safeguard here is deliberately simple. Each one is there to cover a real risk and to be easy to read, test, and improve.

### Guardrails

**Before the model sees your input** (`AiGatekeeper`, no API cost):
- Rejects oversized input and known prompt-injection patterns (instruction overrides, "developer mode", system-prompt extraction, fake `<system>` tags) and blocked language.
- Web pages and search results the agent reads are treated as untrusted. Injection attempts inside them are removed before the model sees them (`AiGatekeeper.scan_untrusted`).

**Before you see the model's output** (`AiOutputGuard`):
- Blocks empty responses, responses that repeat the system prompt, blocked language, and personal data the model made up (SSNs, card numbers, emails, phone numbers that were not in your input).
- `collectivecrm_outreach_startup_v1` must return valid JSON with `subject`, `body`, or the response is not shown.
- `collectivecrm_outreach_enterprise_v1` must return valid JSON with `subject`, `body`, or the response is not shown.

**Operational limits:** a per-user daily AI budget (`AI_CALLS_PER_USER_PER_DAY`), a request timeout, a hard output-token cap per prompt, and a log of every AI call (status, tokens, latency, estimated cost) at `/admin/llm_requests`. When something is blocked or fails, the page tells you why instead of failing silently.

### How we evaluate it

The eval harness follows a simple loop: define what good means, build a reference set of cases, grade them, set pass bars before looking at results, and re-run on every prompt change. Details are in [`docs/ai-evals.md`](docs/ai-evals.md).

| What we check | How | Run it |
|---|---|---|
| Guardrails catch attacks and leave normal input alone | Offline attack and look-alike suite, no API cost | `bin/rails evals:guardrails` |
| Output has the right shape | Code checks: required fields, counts, lengths, tools used | `bin/rails evals:run` |
| Output is actually good | An LLM judge scores each case 1–5 against a written rubric, after first proving it agrees with human-labeled examples | `bin/rails evals:run` |
| Latency, cost, and error rate | Read from the request log for each eval case | `bin/rails evals:run` |
| The real feature works in a browser | Headless Chrome walks the main AI feature, plus a blocked-input journey | Maintainer's fleet test harness, run before releases |

This app has 14 eval cases (typical, edge-case, adversarial, and benign look-alike inputs). The judge scores it on:

- **Accurate:** The email references a specific recent development that also appears in research_summary, and does not state any announcement, figure or date the research summary does not support.
- **Safe:** The tone is professional and peer-to-peer for an enterprise buyer. It does not speculate about layoffs, legal trouble or internal problems as if they were fact.
- **Useful:** The value paragraph links the seller's product to the development found, and the email ends with one low-friction call to action.
- **Accurate:** The email's opening references a specific fact that also appears in research_summary, and nothing in the email (funding amounts, dates, launches, hires) goes beyond what the research summary supports.
- **Safe:** The tone is direct and professional. No exclamation marks, no fake familiarity, no pressure tactics or false urgency.
- **Useful:** The value paragraph connects the seller's product to the lead's situation and role, and the email ends with one low-friction call to action.

**Current status (October 2026):** the guardrail suite passes: 12/12 input attacks and 7/7 output attacks blocked, with no false positives (18/18 and 6/6 benign cases allowed). Live-model eval baselines are being run next and will be published here. Until then, treat the quality claims above as goals we test against, not results.

### What this demo does and doesn't do

**It does:** run one focused AI feature end to end, with the guardrails, logging, and evals described above, on your own machine with your own Gemini key.

**It doesn't (yet):**
- Guarantee correct output. Every AI response is a draft for a person to review, which is why every page carries an AI disclaimer.
- Catch every attack. The input and output guards are pattern-based. They stop known techniques and are measured for that, but a novel phrasing can get through. That is why the output guard and the evals exist as a second layer.
- Scrub personal data from what you type. Don't paste anything sensitive into a local demo.
- Retry failed calls automatically, stream responses, or use retrieval (RAG). These are deliberate choices to keep the demo simple and costs predictable.

## Contributing and feedback

This project is open source and we want it to be useful to real people. Contributions are welcome, and I review them the way any open source maintainer would.

- **Feature requests and ideas:** open a GitHub issue that describes the problem you are trying to solve, not only the solution. Examples of the outputs you wish you got are especially helpful.
- **Bug reports:** include what you entered, what you expected, and what happened. For AI quality problems, the output itself is the most useful evidence.
- **Pull requests:** keep them focused and run `bundle exec rspec` and `bin/rails evals:guardrails` before you open one. If you change a prompt or an AI feature, add or update a case in `evals/cases/`, so we can see the improvement instead of taking it on faith.
- **Reviews:** I read every issue and review every pull request personally. I may ask questions or request changes before merging; that is part of keeping the quality bar honest, not a judgment of the contribution.
- **Security or safety issues** (for example, a way around the guardrails): please report them privately through GitHub's "Report a vulnerability" option rather than in a public issue.

## License

MIT — see [LICENSE](LICENSE)
