# CollectiveCRM Demo — Build Tasks

Progress tracker for building the CollectiveCRM demo app on Open Demo Starter v2.0.  
Detailed specs for each phase: `docs/open-collectivecrm/build-plan.md`

**Legend:** `[ ]` not started · `[x]` complete · `[~]` in progress

---

## Phase 1 — App Setup & Branding

- [x] `.env.example` — add `APP_NAME`, `APP_TAGLINE`, `APP_DESCRIPTION`, `SERPER_API_KEY`; set `AI_CALLS_PER_USER_PER_DAY=20`
- [x] `application.css` — set `--accent: #d97706`, `--accent-hover: #b45309`, `--secondary: #57534e`
- [x] `application.css` — add `.research-summary`, `.kanban-column`, `.lead-card` rules
- [x] `home/index.html.erb` — replace with amber-accented CRM landing page (headline, tagline, sign-up CTA, right-column placeholder)
- [x] `layouts/application.html.erb` — add "Pipeline" and "My Profile" navbar links (signed-in only)
- [x] `config/routes.rb` — added domain routes (seller_profile, leads, outreach_emails) so path helpers work from Phase 1
- [x] `config/database.yml` — renamed all database entries from open_base_* to open_collectivecrm_*

**Manual tests:**
- [ ] Landing page renders with amber accent and tagline from env var
- [ ] Navbar links absent when signed out; present when signed in
- [ ] All existing pages still render correctly (no regressions)

---

## Phase 2 — Data Models

**Migrations:**
- [x] `db/migrate/20260504000001_create_seller_profiles.rb`
- [x] `db/migrate/20260504000002_create_leads.rb`
- [x] `db/migrate/20260504000003_create_outreach_emails.rb`

**Models:**
- [x] `app/models/seller_profile.rb` — belongs_to :user, validations (presence, 500 char limit on description, unique user_id)
- [x] `app/models/lead.rb` — belongs_to :user, has_many :outreach_emails, STAGES + COMPANY_SIZES constants, all validations, grouped_by_stage scope
- [x] `app/models/outreach_email.rb` — belongs_to :lead, ANGLES constant, validations
- [x] `app/models/user.rb` — added `has_one :seller_profile` and `has_many :leads`

**Factories:**
- [x] `spec/factories/seller_profiles.rb`
- [x] `spec/factories/leads.rb` (with :smb, :enterprise, :contacted, :qualified, :proposal, :closed traits)
- [x] `spec/factories/outreach_emails.rb` (with :problem, :referral traits)

**Model specs:**
- [x] `spec/models/seller_profile_spec.rb` (5 examples)
- [x] `spec/models/lead_spec.rb` (10 examples — validations + cascade destroy)
- [x] `spec/models/outreach_email_spec.rb` (4 examples)

**Manual tests:**
- [ ] `rails db:migrate` — no errors
- [ ] Rails console — create SellerProfile, Lead, OutreachEmail — no errors
- [ ] Uniqueness constraint on seller_profiles.user_id works
- [ ] Destroying a lead cascades to outreach_emails
- [ ] Run model specs: `bundle exec rspec spec/models/seller_profile_spec.rb spec/models/lead_spec.rb spec/models/outreach_email_spec.rb`

---

## Phase 3 — Core CRUD (Controllers, Views, Routes)

**Routes:**
- [x] `config/routes.rb` — `resource :seller_profile`, `resources :leads` (with `generate_outreach`), `resources :outreach_emails` (added in Phase 1)
- [x] `GET /leads` redirects to `dashboard_path`

**SellerProfilesController:**
- [x] `app/controllers/seller_profiles_controller.rb`
- [x] `app/views/seller_profiles/edit.html.erb`

**LeadsController:**
- [x] `app/controllers/leads_controller.rb` — index (redirect), new, create, show, edit, update, destroy, generate_outreach stub
- [x] `app/views/leads/_form.html.erb`
- [x] `app/views/leads/new.html.erb`
- [x] `app/views/leads/edit.html.erb`
- [x] `app/views/leads/show.html.erb` — two-panel layout; left: details + stage dropdown; right: Phase 5 placeholder
- [x] `app/views/leads/_stage_badge.html.erb` — Turbo Stream target partial
- [x] `app/helpers/application_helper.rb` — added `angle_badge_class` helper
- [x] `app/views/shared/_flash.html.erb` — flash partial for Turbo Stream updates
- [x] `app/controllers/application_controller.rb` — `record_not_found` now renders 404.html (required for cross-user access specs)

**Stimulus stage controller:**
- [x] Stage updates handled via `button_to` with `method: :patch` — no custom Stimulus controller needed; Turbo handles it natively

**OutreachEmailsController:**
- [x] `app/controllers/outreach_emails_controller.rb`
- [x] `app/views/outreach_emails/show.html.erb` — full-page view with breadcrumb, research summary, email, raw toggle

**Request specs:**
- [x] `spec/requests/leads_spec.rb`
- [x] `spec/requests/seller_profiles_spec.rb`
- [x] `spec/requests/outreach_emails_spec.rb`

**Manual tests:**
- [ ] `/seller_profile/edit` — fill in, save → flash notice, redirected to dashboard
- [ ] `/leads/new` — fill form → create → redirected to lead show
- [ ] Lead show page — all fields visible in left panel
- [ ] Edit lead → save → back on show page
- [ ] Move Stage dropdown changes stage (Turbo Stream, no full page reload)
- [ ] Delete lead → dashboard, lead gone
- [ ] Access another user's lead → 404
- [ ] Form validation errors display inline
- [ ] Run request specs: `bundle exec rspec spec/requests/leads_spec.rb spec/requests/seller_profiles_spec.rb spec/requests/outreach_emails_spec.rb`

---

## Phase 4 — Kanban Dashboard

- [x] `app/controllers/dashboard_controller.rb` — show: load leads grouped by stage, load seller_profile
- [x] `app/views/dashboard/show.html.erb` — 5-column Bootstrap Kanban board
- [x] Dashboard: first-run alert when no seller_profile (amber dismissible Bootstrap alert)
- [x] Dashboard: each column has "+" button linking to `new_lead_path(stage:)`
- [x] Dashboard: lead cards link to lead show page

**Manual tests:**
- [ ] Dashboard shows five columns with correct stage names
- [ ] New user — columns empty, first-run alert visible; dismiss works
- [ ] Click "+" in a column → new lead form with stage pre-filled
- [ ] Create a lead → appears in correct column
- [ ] Lead cards are clickable (link to show page)
- [ ] Board scrolls horizontally on narrow viewport
- [ ] No first-run alert after seller profile is created

---

## Phase 5 — Gemini Agent Integration

**Services:**
- [x] `app/services/serper_service.rb` — Serper.dev web search, 5 results, 1500 char truncation, graceful fallback if no API key
- [x] `app/services/fetch_url_service.rb` — HTTP GET, extract title + meta description + paragraph text, 2000 char cap

**GeminiService extension:**
- [x] `app/services/gemini_service.rb` — add `generate_with_tools` class method (same gatekeeper/budget/log flow; multi-turn function calling loop; max 5 rounds; yields status messages for progress streaming; returns `{ raw: String, trace: Array }`)

**AiTemplate seeds:**
- [x] `db/seeds.rb` — `collectivecrm_outreach_startup_v1` (full system prompt + user prompt from PRD §7, model: `gemini-2.5-flash`, max_output_tokens: 3000, temperature: 0.6)
- [x] `db/seeds.rb` — `collectivecrm_outreach_enterprise_v1` (full prompts from PRD §7, model: `gemini-2.5-flash`, max_output_tokens: 3000, temperature: 0.55)

**LeadsController#generate_outreach:**
- [x] `app/controllers/leads_controller.rb` — add `generate_outreach` action (load lead + seller_profile, select template by company_size, call generate_with_tools, parse JSON, create OutreachEmail, return Turbo Stream)
- [x] `generate_outreach` — full error handling for all GeminiService error types + JSON::ParseError
- [x] `generate_outreach` — rate limiting (5 requests per minute)
- [x] `private outreach_variables` helper method

**Lead show page updates:**
- [x] `leads/show.html.erb` — replace right-panel placeholder with: AI disclaimer, angle selector (Bootstrap btn-group radio), generate button, `outreach_progress` div, `outreach_results` div
- [x] `leads/show.html.erb` — wire Stimulus `outreach` controller to generate button

**Stimulus outreach controller:**
- [x] `app/javascript/controllers/outreach_controller.js` — handles generate click, disables button during request, renders returned Turbo Stream

**Request specs:**
- [x] `spec/requests/leads_generate_outreach_spec.rb` (10 examples: startup template, enterprise template, creates OutreachEmail, Turbo Stream response, GeminiError inline error, budget exceeded error, agent_trace stored, sources stored, auth required, 404 for other user's lead)

**Manual tests:**
- [x] Lead show — see AI disclaimer, angle selector, generate button
- [ ] No seller profile → generate shows warning
- [x] With seller profile (no PERPLEXITY_API_KEY) → outreach generates using fetch_url only
- [x] With PERPLEXITY_API_KEY → result card appears after generation
- [ ] `AI_CALLS_PER_USER_PER_DAY=0` → budget exceeded error shows inline
- [ ] `/admin/llm_requests` → generation logged with status, tokens, duration
- [x] Run request specs: `bundle exec rspec spec/requests/leads_generate_outreach_spec.rb`

---

## Phase 6 — Outreach Email Display

**Partial:**
- [x] `app/views/outreach_emails/_outreach_email.html.erb` — header row (angle badge + timestamp + delete button)
- [x] Partial — "What the agent found" Bootstrap collapse with research summary, source URL list
- [x] Partial — email card (subject h6, body pre, copy button wired to clipboard controller)
- [x] Partial — "Show raw response" Bootstrap collapse with gemini_raw in pre

**Stimulus clipboard controller:**
- [x] `app/javascript/controllers/clipboard_controller.js` — copies source target text, briefly shows "Copied!"

**Outreach email show page:**
- [x] `app/views/outreach_emails/show.html.erb` — full-page view, breadcrumb, back link, renders _outreach_email partial or equivalent content

**Manual tests:**
- [x] Generated outreach card appears with correct angle badge color
- [ ] "What the agent found" collapse opens/closes; source URLs are clickable links
- [ ] "Copy" button copies email body; button briefly says "Copied!"
- [ ] "Show raw response" collapse reveals JSON
- [ ] Delete button → confirm → card removed → stay on lead page
- [ ] `/outreach_emails/:id` — full-page view with breadcrumb
- [ ] Other user's outreach email URL → 404
- [x] Run specs: `bundle exec rspec spec/requests/outreach_emails_spec.rb`

---

## Phase 7 — Seeds, README & Final Polish

- [x] `db/seeds.rb` — complete seed file: demo user, health_ping template, both CollectiveCRM templates, SellerProfile, 5 sample leads, 1 sample OutreachEmail for Priya Nair
- [x] Run `rails db:seed` — no errors; all records created
- [x] `README.md` — add app name, tagline, description, "Why I Built This", screenshot placeholder, Serper.dev setup instructions, privacy note, seed credentials
- [x] Verify AI disclaimer present on lead show page above generate button
- [x] Verify footer AI disclaimer inherited from layout on all pages
- [x] Verify `AI_CALLS_PER_USER_PER_DAY=20` in `.env.example` with comment
- [x] Verify SERPER_API_KEY fallback works gracefully when absent
- [x] Audit all views: no string paths (use named route helpers only)
- [x] Audit all views: no hardcoded app name (use `ENV.fetch`)

**Manual tests:**
- [x] Fresh `rails db:seed` → visit `/dashboard` as demo@example.com → 5 leads in correct columns
- [ ] Priya Nair (Figma) has pre-seeded outreach email visible on her show page
- [ ] `/admin/ai_templates` → both CollectiveCRM templates visible
- [x] Full end-to-end: sign up as new user → set up seller profile → create lead → generate outreach → verify card + research summary

---

## Phase 8 — Full Test Suite

- [x] Run `bundle exec rspec spec/models/` — all green
- [x] Run `bundle exec rspec spec/services/` — all green
- [x] Run `bundle exec rspec spec/requests/` — all green
- [x] Run `bundle exec rspec` — full suite green, zero failures
- [x] Verify zero real API calls during test run (no requests to googleapis.com or serper.dev)
- [x] `bundle exec rspec --format documentation` — review output for any unexpected behavior

**Spec files to verify exist and pass:**
- [x] `spec/models/seller_profile_spec.rb`
- [x] `spec/models/lead_spec.rb`
- [x] `spec/models/outreach_email_spec.rb`
- [x] `spec/models/user_spec.rb` (boilerplate — unchanged)
- [x] `spec/models/ai_template_spec.rb` (boilerplate — unchanged)
- [x] `spec/requests/leads_spec.rb`
- [x] `spec/requests/seller_profiles_spec.rb`
- [x] `spec/requests/outreach_emails_spec.rb`
- [x] `spec/requests/leads_generate_outreach_spec.rb`
- [x] `spec/services/ai_gatekeeper_spec.rb` (boilerplate — unchanged)
- [x] `spec/services/ai_budget_checker_spec.rb` (boilerplate — unchanged)
- [x] `spec/services/gemini_service_spec.rb` (boilerplate + generate_with_tools additions)

---

## Notes

- **Gemini model:** Use `gemini-2.5-flash` in all seeds. The PRD specifies `gemini-2.0-flash` but that model is deprecated for new API keys per `docs/ai-templates.md`.
- **No streaming responses:** Progress updates are Turbo Stream appends, not HTTP streaming. The generate action completes synchronously and returns all streams at once.
- **SERPER_API_KEY optional:** The app must function (generate outreach via fetch_url fallback) when the key is absent.
- **Turbo Streams:** Always use `turbo_stream.update()` — never `replace()`. See `docs/turbo-stimulus-patterns.md`.
- **Test stubs:** Stub `GeminiService.generate_with_tools` in all request specs. Never hit real APIs in tests.
