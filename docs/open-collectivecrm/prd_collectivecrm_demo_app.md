# CollectiveCRM Demo - App Spec

**Document Version:** 1.0
**Built On:** Open Demo Starter v2.0
**License:** MIT
**Accent Color:** `#d97706` (amber) / secondary: `#57534e` (warm gray)

---

## 1. App Overview

CollectiveCRM Demo is a single-user, locally-runnable Rails 8 application that shows the core capability of CollectiveCRM: AI-researched outreach emails for every lead in a 5-stage sales pipeline.

The user manages leads through a Kanban board with five stages (Prospect, Contacted, Qualified, Proposal, Closed). When they trigger outreach generation for any lead, a Gemini agent first researches the lead's company using web search and URL fetching before writing the email. The resulting outreach references something specific and current about the company rather than generic value propositions.

The agent adapts its research strategy based on a company_size field on the lead record. For startups, it searches for funding announcements and role context. For enterprise leads, it searches for recent news and industry challenges. In both cases, the agent's research findings are stored and displayed above the generated email so the user can verify the facts before sending. The user selects an outreach angle (value-focused, problem-focused, referral-focused) before triggering, which shapes how Gemini frames the email independent of the research findings.

**Why it matters:** Generic outreach is ignored. Outreach that references "I saw you just closed your Series A" or "I noticed you launched a new product line last month" gets replies. The agent does the research in seconds. This demo isolates that capability as a standalone tool.

This is one feature from a larger multi-tenant SaaS product the author is building (CollectiveCRM), where teams share a pipeline, collaborate on leads, and manage outreach at scale. The demo isolates the single most valuable action a user can take: add a lead, research them, write outreach that references something real. The full production version is multi-tenant with team collaboration, shared pipelines, and per-member AI credit budgets. This demo is open source under MIT license, scoped to a single signed-in user, and runs locally.

---

## 2. Customizations Applied to the Boilerplate

- **App name:** `CollectiveCRM Demo` (set via `APP_NAME` in `.env.example`)
- **Tagline:** `Add a lead. The agent researches their company. AI writes outreach that references something real.` (set via `APP_TAGLINE`)
- **Description:** One-paragraph product description set via `APP_DESCRIPTION`
- **Accent color:** `#d97706` (amber) set in `app/assets/stylesheets/_accent.scss`; hover: `#b45309`
- **Secondary color:** `#57534e` (warm gray) added as `--secondary` in the same file
- **Navbar links:** Added links for "Pipeline" (leads index) and "My Profile" (seller profile edit) after sign-in
- **Home page:** `home/index.html.erb` replaced with a CRM-specific landing pitch featuring a pipeline screenshot placeholder, the tagline, and a sign-up call to action
- **Dashboard page:** `dashboard/show.html.erb` replaced with the Kanban pipeline view (see Section 6)
- **UX pattern:** Kanban board (5 columns) for the pipeline; lead show page as the primary action surface for outreach generation
- **AI templates seeded:** `collectivecrm_outreach_startup_v1`, `collectivecrm_outreach_enterprise_v1`
- **Additional env var:** `SERPER_API_KEY` for the web search tool used by the agent (Serper.dev free tier)

---

## 3. Data Model

### SellerProfile

One record per user. Captures the product the user is selling, used as context in every outreach email.

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | Primary key |
| `user_id` | uuid | Foreign key; belongs_to :user |
| `product_name` | string | **(template variable)** |
| `product_description` | text | **(template variable)** |
| `created_at` | datetime | |
| `updated_at` | datetime | |

**Associations:** `belongs_to :user`

**Validations:** `user_id` unique (one profile per user); `product_name` presence; `product_description` presence, max 500 chars

**Notes:** Created via a first-run prompt when the user logs in for the first time and has no profile. Shown in a persistent settings card on the pipeline page.

---

### Lead

The core domain record. Represents one person in the sales pipeline.

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | Primary key |
| `user_id` | uuid | Foreign key; belongs_to :user |
| `first_name` | string | **(template variable)** |
| `last_name` | string | **(template variable)** |
| `company` | string | **(template variable)** |
| `company_size` | string | `startup`, `smb`, `enterprise`; controls which template is used; **(template variable)** |
| `role` | string | **(template variable)** |
| `email` | string | |
| `website` | string | Used as the fetch_url target if populated; **(template variable)** |
| `stage` | string | `prospect`, `contacted`, `qualified`, `proposal`, `closed` |
| `notes` | text | **(template variable)** |
| `created_at` | datetime | |
| `updated_at` | datetime | |

**Associations:** `belongs_to :user`; `has_many :outreach_emails, dependent: :destroy`

**Validations:** `first_name`, `last_name`, `company`, `company_size`, `stage` presence; `stage` inclusion in allowed values; `company_size` inclusion in `[startup, smb, enterprise]`; `email` format if present

---

### OutreachEmail

One record per generated outreach attempt for a lead. Multiple records per lead are allowed (different angles, regenerated after new research).

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | Primary key |
| `lead_id` | uuid | Foreign key; belongs_to :lead |
| `angle` | string | `value`, `problem`, `referral`; **(template variable)** |
| `subject` | string | Parsed from Gemini output |
| `body` | text | Parsed from Gemini output |
| `research_summary` | text | What the agent found about the company; displayed above the email |
| `sources` | text | Newline-separated source URLs from agent tool calls |
| `agent_trace` | text | JSON log of every tool call and result in the agent loop |
| `gemini_raw` | text | **(Gemini output, used for Show raw response toggle)** |
| `created_at` | datetime | |
| `updated_at` | datetime | |

**Associations:** `belongs_to :lead`

**Validations:** `lead_id`, `angle` presence; `angle` inclusion in `[value, problem, referral]`

---

## 4. Routes

| HTTP Verb | Path | Controller#Action | Purpose |
|---|---|---|---|
| GET | `/dashboard` | `dashboard#show` | Kanban pipeline view (all leads by stage) |
| GET | `/seller_profile/edit` | `seller_profiles#edit` | Edit product name and description |
| PATCH | `/seller_profile` | `seller_profiles#update` | Save seller profile |
| GET | `/leads` | `leads#index` | Redirect to dashboard (pipeline is the index) |
| GET | `/leads/new` | `leads#new` | New lead form |
| POST | `/leads` | `leads#create` | Create lead |
| GET | `/leads/:id` | `leads#show` | Lead detail page with outreach history |
| GET | `/leads/:id/edit` | `leads#edit` | Edit lead fields |
| PATCH | `/leads/:id` | `leads#update` | Save lead changes; also handles stage drag-drop via Turbo |
| DELETE | `/leads/:id` | `leads#destroy` | Delete lead and all outreach emails |
| POST | `/leads/:id/generate_outreach` | `leads#generate_outreach` | Trigger the agent; returns Turbo Stream |
| GET | `/outreach_emails/:id` | `outreach_emails#show` | Full outreach email with research summary |
| DELETE | `/outreach_emails/:id` | `outreach_emails#destroy` | Delete a single outreach email |

---

## 5. Controllers and Actions

### `DashboardController`

**`show`:** Loads all leads for `current_user` grouped by stage into five collections (prospect, contacted, qualified, proposal, closed). Renders the Kanban board. If the user has no `SellerProfile`, renders a first-run prompt card above the pipeline asking them to set up their product context before generating outreach.

---

### `SellerProfilesController`

**`edit`:** Finds or initializes the `SellerProfile` for `current_user`.

**`update`:** Saves the seller profile. On success, redirects to the dashboard with a flash notice. On failure, re-renders the edit form.

---

### `LeadsController`

**`new`:** Initializes a new `Lead` belonging to `current_user`.

**`create`:** Creates the lead scoped to `current_user`. On success, redirects to the lead show page. On failure, re-renders the new form.

**`show`:** Loads the lead by `current_user.leads.find(params[:id])`. Loads all `outreach_emails` for the lead ordered by `created_at desc`. Renders the lead detail page.

**`edit`:** Loads the lead for `current_user`.

**`update`:** Updates lead fields or stage. Stage updates may come from drag-drop (Turbo Stream) or from the edit form (redirect). Responds with Turbo Stream for stage changes, redirect for full edits.

**`destroy`:** Deletes the lead and all associated outreach emails. Redirects to the dashboard.

**`generate_outreach`:** This action triggers the Gemini agent. It:
1. Loads the lead and the `SellerProfile` for `current_user`.
2. Reads `angle` from params (value/problem/referral).
3. Selects the template name based on `lead.company_size` (`collectivecrm_outreach_startup_v1` for startup/smb; `collectivecrm_outreach_enterprise_v1` for enterprise).
4. Calls `GeminiService.generate_with_tools(template: template_name, variables: {...}, tools: [search_web_tool, fetch_url_tool])`.
5. Parses the returned JSON into `subject`, `body`, `research_summary`, `sources`, `agent_trace`, and `gemini_raw`.
6. Creates an `OutreachEmail` record.
7. Returns a Turbo Stream that appends the new outreach email card to the results container and clears the progress feed.
8. Catches `GeminiService::GeminiError` and returns a Turbo Stream that renders the error partial with a retry button inline on the page.

---

### `OutreachEmailsController`

**`show`:** Loads the outreach email via `OutreachEmail.joins(:lead).where(leads: { user_id: current_user.id }).find(params[:id])`. Renders the full email with research summary, sources, and the raw response toggle.

**`destroy`:** Deletes the outreach email. Redirects to the parent lead show page.

---

## 6. Views

### `home/index.html.erb`

Amber-accented landing page. Left column: headline ("Your AI researches every lead before writing outreach"), two-line description, sign-up button. Right column: static pipeline screenshot placeholder. Footer AI disclaimer is inherited from the layout.

---

### `dashboard/show.html.erb`

Five-column Kanban board. Each column is a Bootstrap card with the stage name as the header and a scrollable list of lead cards inside. Each lead card shows name, company, role, and a colored stage badge. A button at the top of each column links to `new_lead_path(stage: column_stage)`. An "Add Lead" button in the navbar header opens the new lead form.

First-run prompt: if `current_user.seller_profile` is nil, a dismissible amber Bootstrap alert banner at the top prompts the user to set up their product context before generating outreach. Links to `edit_seller_profile_path`.

---

### `leads/new.html.erb` and `leads/edit.html.erb`

Standard Rails form pages. Include fields for first_name, last_name, company, company_size (Bootstrap select: Startup, Small/Mid-size Business, Enterprise), role, email, website, stage (select), and notes textarea.

---

### `leads/_form.html.erb`

Shared form partial used by both new and edit. No JavaScript; standard `form_with` helper. Company size select drives which template is used during outreach generation (displayed as an informational note below the select: "This determines how the agent researches your lead's company.").

---

### `leads/show.html.erb`

Two-panel layout. Left panel (one-third width): lead details card showing all fields, an "Edit Lead" button, and a "Move Stage" dropdown (Bootstrap dropdown listing the five stages; each option submits a PATCH via a small form). Right panel (two-thirds width):

**Generate Outreach section:**
- Angle selector: three Bootstrap radio buttons (Value-focused, Problem-focused, Referral-focused). Default: value-focused.
- "Research and Write Outreach" amber button that submits `POST /leads/:id/generate_outreach` via `data-action="click->outreach#generate"` on a Stimulus controller named `outreach`.
- A Turbo Frame with id `outreach_progress` that shows a live status feed during generation (see Turbo Stream spec below).
- A Turbo Frame with id `outreach_results` that renders all existing outreach emails for the lead.

**Status feed (inside `outreach_progress`):**
Stimulus controller `outreach` listens for the Turbo Stream response and updates the progress container with status messages: "Researching [Company]...", "Reading their website...", "Writing your email...". Implemented as sequential Turbo Stream `update` calls streaming back from the controller action. Progress container is cleared after the result card is appended.

---

### `outreach_emails/_outreach_email.html.erb`

Partial rendered inside the `outreach_results` frame for each outreach email. Structure:

- Header row: angle badge (Bootstrap badge, amber for value, blue for problem, green for referral), timestamp, delete button.
- Research summary card: Bootstrap `alert alert-info` (muted, inside a Bootstrap collapse toggle labeled "What the agent found"). Shows `research_summary` text and a bulleted list of source URLs from `sources`.
- Email card: subject line as `<h6>`, body as `<pre class="text-wrap">`, copy-to-clipboard button (Stimulus; no custom JS needed beyond a single `navigator.clipboard.writeText` call in a minimal controller).
- "Show raw response" Bootstrap collapse toggle revealing `gemini_raw` field content (inherited UX requirement).

---

### `seller_profiles/edit.html.erb`

Single-card form. Fields: `product_name` (text input), `product_description` (textarea, 4 rows). Save button. Brief instructional note: "This context appears in every outreach email the agent writes for you."

---

### `outreach_emails/show.html.erb`

Full-page view of a single outreach email. Same content as the partial above but with more vertical space. Breadcrumb: Dashboard > Lead Name > Outreach (timestamp). Back link to the parent lead show page.

---

## 7. AI Templates and Gemini Integration

This demo uses Gemini's function calling API via `GeminiService.generate_with_tools(template: "...", variables: {...}, tools: [...])`. Two tool definitions are registered:

**Tool: `search_web`**
- Description: Search the web for recent information about a company or person.
- Parameter: `query` (string, required)
- Implementation: Calls the Serper.dev `/search` endpoint with the query. Returns the top 5 organic results as title plus snippet plus URL. Truncated to 1500 chars total.

**Tool: `fetch_url`**
- Description: Fetch and read the content of a URL.
- Parameter: `url` (string, required)
- Implementation: Sends an HTTP GET request with a browser User-Agent. Extracts the `<title>` tag, `<meta name="description">` content, and first 1500 chars of visible `<p>` text. Returns title plus meta description first as a lightweight fallback; appends paragraph content if available within the 2000 char total cap.

**Agent loop cap:** Maximum 5 rounds. After round 5, Gemini must produce a final response with no further tool calls.

**Intermediate state:** The `generate_outreach` controller action streams Turbo Stream `update` events to the `outreach_progress` frame before the agent loop completes. Status messages are sent as the agent invokes each tool: one update per tool call. The progress frame is cleared and replaced with the result card when the final response arrives.

**Stored on OutreachEmail:** `agent_trace` (JSON array of all tool calls with their arguments and truncated results), `sources` (newline-separated URLs actually used), `research_summary` (a prose digest of what was found, extracted from the agent's final structured output), `gemini_raw` (the full raw response object from the last Gemini call).

---

### Template: `collectivecrm_outreach_startup_v1`

**Description:** Researches startup leads via funding search, role context, and homepage; writes personalized outreach.

**System Prompt:**
```
You are a sales research agent helping a salesperson write highly personalized outreach emails.

Your job has two phases:
PHASE 1 - RESEARCH: Use the tools available to you to research the lead's company. Follow the startup research path below in order. Stop searching once you have enough specific, current information to write a credible, personalized email.

Startup research path:
1. search_web("[company] funding announcement OR seed round OR Series A OR raised")
2. search_web("[company] [role] LinkedIn OR about OR team")
3. fetch_url([company website]) - read their homepage and product description

PHASE 2 - WRITE: After completing your research, produce a JSON object (no markdown, no code fences) with these exact fields:
- research_summary: A 2-3 sentence digest of the most relevant things you found about the company. Be specific; include the specific fact you will reference in the email. If you found funding news, include the round size and date.
- sources: An array of URLs you actually used to gather information.
- subject: The email subject line (under 60 characters).
- body: The full email body (under 200 words). Format: opening paragraph (references the specific thing you found), value proposition paragraph (tied to the seller's product), closing line with a low-friction call to action.

Rules:
- The opening line must reference one specific thing you found: a recent funding round, a product launch, a team expansion, or something from their website. Never open with "I noticed you are in [industry]."
- Match the outreach angle described in the user prompt.
- Do not fabricate funding amounts or dates. If you could not find funding news, reference something else specific: a product feature, a job posting, a team member.
- Write in a direct, professional tone. No filler phrases. No exclamation marks.
- Cap your agent loop at 5 rounds total.
```

**User Prompt Template:**
```
Write a personalized outreach email for this lead. Use your research tools first, then write.

LEAD INFORMATION
Name: {{first_name}} {{last_name}}
Title: {{role}}
Company: {{company}}
Company Website: {{website}}
Notes: {{notes}}

SELLER CONTEXT
Product: {{product_name}}
Description: {{product_description}}

OUTREACH ANGLE
{{angle}}

Value-focused: Frame the email around how the seller's product helps the company achieve their growth goals or scale what they just built.
Problem-focused: Frame the email around a challenge companies at their stage commonly face that the seller's product solves.
Referral-focused: Frame the email as if the sender was referred by someone in the industry; keep it conversational and brief.

Return only the JSON object. No markdown. No explanation outside the JSON.
```

**Variables:**
- `{{first_name}}`, `{{last_name}}` - Lead.first_name, Lead.last_name
- `{{role}}` - Lead.role
- `{{company}}` - Lead.company
- `{{website}}` - Lead.website (may be blank; agent falls back to searching if no URL provided)
- `{{notes}}` - Lead.notes (optional; may be empty)
- `{{product_name}}` - SellerProfile.product_name
- `{{product_description}}` - SellerProfile.product_description
- `{{angle}}` - The selected angle (value/problem/referral)

**Model:** `gemini-2.0-flash`

**max_output_tokens:** 3000 (higher than the default 2000 because the agent trace plus the structured output can be verbose)

**Temperature:** 0.6 (lower than default for more factual, structured output; the research component needs reliability over creativity)

**Notes:** This template encodes the startup research path (funding news, role context, website). The most common failure mode is a hallucinated funding round when no real funding news exists. The system prompt instructs the agent to fall back to other specific facts rather than fabricate. Watch for the agent calling `fetch_url` on a LinkedIn URL and receiving a login wall; the truncation fallback to title plus meta description handles this gracefully. Test with leads where the company has a clear website vs. leads where only a company name is known.

**Where called:** `LeadsController#generate_outreach`, when `lead.company_size` is `startup` or `smb`.

**Expected output format:** JSON with fields `research_summary`, `sources` (array), `subject`, `body`.

**How parsed:** `JSON.parse(gemini_raw)` extracts each field. `subject` and `body` are stored directly on `OutreachEmail`. `sources` array is joined with newlines and stored in `OutreachEmail.sources`. `research_summary` is stored in `OutreachEmail.research_summary`. If parsing fails, the raw string is stored in `gemini_raw` and a parsing error is shown inline with the raw response toggle.

**Raw response field:** `OutreachEmail.gemini_raw`

---

### Template: `collectivecrm_outreach_enterprise_v1`

**Description:** Researches enterprise leads via recent news and industry challenges; writes personalized outreach referencing a specific recent development.

**System Prompt:**
```
You are a sales research agent helping a salesperson write highly personalized outreach emails for enterprise accounts.

Your job has two phases:
PHASE 1 - RESEARCH: Use the tools available to you to research the lead's company. Follow the enterprise research path below in order. Stop searching once you have a specific, current development to reference in the email.

Enterprise research path:
1. search_web("[company] news [current year]")
2. search_web("[company] [industry] challenges OR layoffs OR expansion OR product launch OR acquisition")
3. fetch_url([company website]/about OR [company website]/news OR [company website]) - read their current positioning

PHASE 2 - WRITE: After completing your research, produce a JSON object (no markdown, no code fences) with these exact fields:
- research_summary: A 2-3 sentence digest of the most relevant recent development you found. Name the specific event, date, or announcement. This is what the email will reference.
- sources: An array of URLs you actually used to gather information.
- subject: The email subject line (under 60 characters).
- body: The full email body (under 200 words). Format: opening paragraph (references the specific recent development), value proposition paragraph (tied to the seller's product and relevant to the development you found), closing line with a low-friction call to action.

Rules:
- The opening line must reference one specific recent development: an acquisition, expansion, product launch, industry challenge, or executive change. Never open with generic industry observations.
- Match the outreach angle described in the user prompt.
- Do not fabricate announcements. If you cannot find a specific recent development, reference something from their About or News page instead.
- Write in a professional, peer-to-peer tone appropriate for enterprise buyers. Concise, direct, no filler phrases.
- Cap your agent loop at 5 rounds total.
```

**User Prompt Template:**
```
Write a personalized outreach email for this enterprise lead. Use your research tools first, then write.

LEAD INFORMATION
Name: {{first_name}} {{last_name}}
Title: {{role}}
Company: {{company}}
Company Website: {{website}}
Notes: {{notes}}

SELLER CONTEXT
Product: {{product_name}}
Description: {{product_description}}

OUTREACH ANGLE
{{angle}}

Value-focused: Frame the email around how the seller's product supports the company's recent initiative or growth direction.
Problem-focused: Frame the email around an operational or strategic challenge that companies undergoing this type of development commonly face.
Referral-focused: Keep it brief and conversational; mention the specific development as the reason for reaching out now.

Return only the JSON object. No markdown. No explanation outside the JSON.
```

**Variables:** Same as `collectivecrm_outreach_startup_v1`.

**Model:** `gemini-2.0-flash`

**max_output_tokens:** 3000

**Temperature:** 0.55 (slightly lower; enterprise outreach errors are higher-stakes and the research needs to be accurate)

**Notes:** The enterprise path prioritizes recent news over company fundamentals. The most common failure mode is finding old news (1-2 years ago) and treating it as current. The system prompt includes `[current year]` in the search query to bias toward recent results. The second search covers the common enterprise events (layoffs, expansion, acquisition, launch) that make for compelling outreach hooks. Test with a large well-known company (where news is plentiful) and with a mid-market company (where less is published). The fetch_url step on the `/about` or `/news` page is the fallback when search results are thin.

**Where called:** `LeadsController#generate_outreach`, when `lead.company_size` is `enterprise`.

**Expected output format:** Same JSON schema as the startup template.

**How parsed:** Same parsing logic as the startup template.

**Raw response field:** `OutreachEmail.gemini_raw`

---

## 8. AI Safety Considerations (Specific to This App)

**Content sensitivity:** Low. Sales outreach emails are not a high-stakes domain. No mental health, legal, medical, or regulated content.

**Consequential outputs:** Moderate. The user is directly sending or copying these emails to real people. A poorly researched or factually incorrect email (e.g., referencing a funding round that did not happen, congratulating a company on an acquisition that was actually a layoff) could damage the user's professional credibility. The research summary display pattern (showing what the agent found before showing the email) is the primary mitigation. The user sees the evidence before they see the conclusion.

**Domain accuracy requirements:** The research summary must be treated as unverified until the user checks the sources. Source URLs are displayed as clickable links so verification requires one click. The "what the agent found" panel must be labeled clearly as agent research, not as verified facts.

**App-specific disclaimers:** Add a note on the lead show page, above the Generate Outreach section: "The agent searches the web and may find outdated or incorrect information. Review the research summary and verify the sources before sending any email." This is in addition to the boilerplate footer disclaimer.

**Tightened settings:** The per-user daily cap should default to 20 for this demo (rather than the boilerplate's 50), because each outreach generation may consume multiple Gemini calls across the agent loop. Set `AI_CALLS_PER_USER_PER_DAY=20` in `.env.example` with a note explaining the lower default.

**Web search privacy:** The Serper.dev API receives the company name and role from the lead record. Users should not enter personal data (home addresses, personal email addresses) in the lead notes field if they are concerned about sending it to a third-party search API. The README includes a note about this.

**What this demo deliberately does NOT do:**
- Does not send emails automatically. The user copies or downloads the email body; there is no SMTP integration. This is an intentional boundary: outreach goes out only when the user explicitly reviews and sends it.
- Does not store or cache Serper.dev search results beyond the single agent run. Each generation starts fresh.
- Does not use the lead's personal email address as a search query (only company name and role are used in search).
- Does not provide confidence scores or fact-checking on the research findings. That belongs in a production app with a dedicated verification layer.

---

## 9. RSpec Outline

### `spec/models/seller_profile_spec.rb`

1. Valid with all required fields
2. Invalid without product_name
3. Invalid without product_description
4. Invalid if product_description exceeds 500 chars
5. Enforces one profile per user (unique validation on user_id)

### `spec/models/lead_spec.rb`

1. Valid with all required fields
2. Invalid without first_name, last_name, company, company_size, stage
3. Invalid with unrecognized company_size value
4. Invalid with unrecognized stage value
5. Destroys associated outreach_emails when deleted

### `spec/models/outreach_email_spec.rb`

1. Valid with all required fields
2. Invalid without angle
3. Invalid with unrecognized angle value
4. belongs_to :lead association

### `spec/requests/leads_spec.rb`

1. GET /leads/new requires authentication; redirects if not signed in
2. POST /leads creates a lead scoped to the current user
3. GET /leads/:id returns 404 for a lead belonging to a different user
4. PATCH /leads/:id updates stage and returns Turbo Stream response
5. DELETE /leads/:id destroys the lead and redirects to dashboard

### `spec/requests/leads_generate_outreach_spec.rb`

1. POST /leads/:id/generate_outreach calls `GeminiService.generate_with_tools` with the startup template when company_size is "startup"
2. POST /leads/:id/generate_outreach calls `GeminiService.generate_with_tools` with the enterprise template when company_size is "enterprise"
3. POST /leads/:id/generate_outreach creates an OutreachEmail record on success
4. POST /leads/:id/generate_outreach creates an LlmRequest record on each call (verified via the test double)
5. POST /leads/:id/generate_outreach returns an inline error Turbo Stream when GeminiService raises GeminiError
6. Agent loop terminates within 5 rounds (verified via tool call count in stubbed agent trace)
7. Tool calls are recorded in the agent_trace field of the created OutreachEmail
8. Source URLs are stored in the sources field of the created OutreachEmail

### `spec/requests/seller_profiles_spec.rb`

1. GET /seller_profile/edit requires authentication
2. PATCH /seller_profile creates or updates the SellerProfile for current_user
3. PATCH /seller_profile does not update another user's profile

### `spec/requests/outreach_emails_spec.rb`

1. GET /outreach_emails/:id returns 404 for an email belonging to a different user's lead
2. DELETE /outreach_emails/:id destroys the record and redirects to the parent lead

---

## 10. Seed Data

### AiTemplate Seeds

`db/seeds.rb` creates two `AiTemplate` records with the full field values specified in Section 7:

- `collectivecrm_outreach_startup_v1`: name, description, system_prompt, user_prompt_template, model `gemini-2.0-flash`, max_output_tokens 3000, temperature 0.6, notes
- `collectivecrm_outreach_enterprise_v1`: name, description, system_prompt, user_prompt_template, model `gemini-2.0-flash`, max_output_tokens 3000, temperature 0.55, notes

Both templates are created with `find_or_create_by(name: ...)` to be safe on re-seed.

### Domain Seeds

One `SellerProfile` for the demo user:
- product_name: "CollectiveCRM"
- product_description: "A multi-tenant CRM for sales teams that uses AI to research leads and write personalized outreach. Helps SDRs spend more time selling and less time doing research."

Five sample `Lead` records covering all pipeline stages and all three company size categories:

1. **Jordan Ellis** - Head of Growth at Lattice (startup, stage: prospect, website: lattice.com) - startup company with notes about seeing their Series C announcement
2. **Priya Nair** - VP Sales at Figma (enterprise, stage: contacted) - enterprise lead at a well-known company
3. **Marcus Webb** - Founder at Tally (startup, stage: qualified, website: tally.so) - small startup, notes about their no-code forms product
4. **Sarah Kim** - Director of Revenue Operations at HubSpot (enterprise, stage: proposal) - enterprise lead in a relevant industry
5. **Tomasz Wierzbicki** - CEO at Typeform (smb, stage: closed) - closed deal (shows the full pipeline)

One `OutreachEmail` record for lead 2 (Priya Nair) with a pre-written realistic sample:
- angle: "value"
- subject: "Saw the Figma Config announcements"
- body: Sample 150-word outreach email referencing a fictional recent product launch
- research_summary: Sample 2-sentence research finding
- sources: One sample URL
- gemini_raw: The full JSON string that would have been returned by Gemini

This gives a visitor a realistic view of the output without requiring them to run a real Gemini call on first seed.

---

## 11. README Additions

### App Name and Tagline

**CollectiveCRM Demo**
*Add a lead. The agent researches their company. AI writes outreach that references something real.*

### Description

CollectiveCRM Demo is an open source Rails 8 app that shows one thing: how an AI agent can research a sales lead's company and write personalized outreach that references something specific and current. You add a lead, choose an angle (value, problem, or referral), and click Generate Outreach. A Gemini agent searches the web, reads the company's website, and writes an email that opens with a real fact it found - a funding round, a product launch, a recent news item. The research findings are shown above the email so you can verify before you send.

### Screenshot

[Screenshot placeholder - add a screenshot of the Kanban board and a lead page with a generated outreach email]

### Why I Built This

Generic outreach does not work. I know because I have sent thousands of generic emails and watched them get ignored. The hard part of good outreach is not the writing - it is the 20 minutes of research before you write. This demo shows that an agent can do that research in seconds.

This is a standalone demo of one capability from CollectiveCRM, the AI-powered CRM I am building at [your-production-url]. The full version is multi-tenant: your whole team shares a pipeline, AI credits are pooled per member, and outreach history is visible across the org. This demo is the single-user, locally-runnable version - clone it, try it, and tune the prompts yourself.

The AI prompt for this demo is editable at `/admin/ai_templates`. Sign in as `demo@example.com` with password `password123` and you can adjust the research strategy, the email format, or the tone without touching any code. The updated prompt takes effect on the next outreach generation.

MIT licensed. Fork it, extend it, use it as a starting point.

### Additional Setup (Beyond `bin/setup`)

This demo uses [Serper.dev](https://serper.dev) for the agent's web search capability.

1. Create a free account at serper.dev (free tier: 2500 queries/month)
2. Copy your API key from the Serper dashboard
3. Add it to your `.env` file: `SERPER_API_KEY=your_key_here`

Without a Serper API key, the `search_web` tool will return a placeholder response and the agent will fall back to `fetch_url` only. The outreach will still generate but will not include web-sourced research findings.

---

## 12. Bootstrap Dark Mode and Accent Color Notes

**UX pattern:** Kanban board for the pipeline; card-based detail pages for leads; form-then-result on the lead show page for outreach generation.

**Accent color application:**
- `--accent: #d97706` (amber) applied to: primary buttons (Generate Outreach, Save, Create Lead), active nav state, angle radio button borders when selected, the "What the agent found" research card left border
- `--accent-hover: #b45309` (darker amber) for button hover states
- `--secondary: #57534e` (warm gray) applied to: stage badges, secondary action buttons (Edit, Move Stage), muted card borders

**Kanban board implementation:**
- Five equal Bootstrap columns (`col`) inside a `row g-3 flex-nowrap overflow-auto` container so the board scrolls horizontally on small screens
- Each column uses a `card bg-dark border-secondary` with a fixed height and `overflow-y: auto` for the lead card list
- Lead cards inside each column use `card mb-2 bg-dark border-secondary` with minimal padding
- Stage column headers use accent color for the active stage badge

**Lead show page:**
- Two-column layout using Bootstrap `col-md-4` (lead details) and `col-md-8` (outreach panel)
- Research summary panel uses Bootstrap `alert alert-info` with the amber left border override (1 line of CSS)
- Angle selector uses Bootstrap `btn-group` with `input type="radio"` for the three angle options; selected state uses `btn-outline-warning` (maps to amber)

**Custom CSS additions (minimal):**
- Left border accent on the research summary card: `.research-summary { border-left: 3px solid var(--accent); }`
- Kanban column fixed height: `.kanban-column { height: calc(100vh - 180px); overflow-y: auto; }`
- Lead card hover state: `.lead-card:hover { border-color: var(--accent) !important; cursor: pointer; }`

All other styling uses Bootstrap utilities only.

---

*v1.0 - CollectiveCRM Demo spec. Built on Open Demo Starter v2.0. Open source under MIT license.*
