# CollectiveCRM Demo — Phased Build Plan

**Based on:** `prd_collectivecrm_demo_app.md` v1.0  
**Boilerplate:** Open Demo Starter v2.0  
**Stack:** Rails 8.1, PostgreSQL, Stimulus + Turbo, Bootstrap 5 dark, Gemini AI

> Always consult the reference guides before implementing each phase:
> - `docs/turbo-stimulus-patterns.md` — Turbo Streams, Stimulus, Bootstrap
> - `docs/ai-templates.md` — GeminiService, templates, error handling
> - `docs/ai-guardrails.md` — AiGatekeeper, AiBudgetChecker, LlmRequest
> - `docs/testing.md` — RSpec factories, stubs, request specs

---

## Model Note on Gemini Model Name

The PRD specifies `gemini-2.0-flash` in the AI template seeds. **Override this.**  
`docs/ai-templates.md` explicitly states `gemini-2.0-flash` is deprecated for new API keys.  
Use `gemini-2.5-flash` in all seeds and template records.

---

## Phase 1 — App Setup & Branding

**Goal:** Replace boilerplate identity with CollectiveCRM branding. No new models or routes.

### Files to Create / Modify

| File | Action | Notes |
|---|---|---|
| `.env.example` | Modify | Add `APP_NAME`, `APP_TAGLINE`, `APP_DESCRIPTION`, `SERPER_API_KEY`, set `AI_CALLS_PER_USER_PER_DAY=20` |
| `app/assets/stylesheets/application.css` | Modify | Set `--accent: #d97706`, `--accent-hover: #b45309`, add `--secondary: #57534e`; add `.research-summary`, `.kanban-column`, `.lead-card` rules |
| `app/views/home/index.html.erb` | Replace | Amber landing page per PRD §6. Left: headline + desc + sign-up button. Right: pipeline screenshot placeholder. Use `ENV.fetch` for all copy. |
| `app/views/layouts/application.html.erb` | Modify | Add "Pipeline" link (`leads_path`) and "My Profile" link (`edit_seller_profile_path`) to navbar; only render when signed in |

### Implementation Notes

**CSS additions** (`application.css`):
```css
:root {
  --accent: #d97706;
  --accent-hover: #b45309;
  --secondary: #57534e;
}
.research-summary { border-left: 3px solid var(--accent); }
.kanban-column    { height: calc(100vh - 180px); overflow-y: auto; }
.lead-card:hover  { border-color: var(--accent) !important; cursor: pointer; }
```

**Navbar links** — wrap in `<% if current_user %>` guard. Use named route helpers only.

**Home page** — The right-column placeholder can be a Bootstrap card with muted text "Pipeline screenshot" until a real screenshot is added. Never hardcode the app name — always `ENV.fetch("APP_NAME", "CollectiveCRM Demo")`.

### Manual Test Checklist

- [ ] Visit `/` — see amber-accented landing page with tagline from env var
- [ ] Navbar shows no "Pipeline" or "My Profile" links when signed out
- [ ] Sign in as `demo@example.com` / `password123` — navbar shows "Pipeline" and "My Profile"
- [ ] Accent color visible on primary buttons
- [ ] Dark mode consistent across all existing pages

### RSpec Tests

None in this phase. Branding is covered by visual inspection.

---

## Phase 2 — Data Models

**Goal:** Create the three domain models with migrations, validations, associations, and factories.

### Migrations

**`SellerProfile`**
```ruby
create_table :seller_profiles, id: :uuid do |t|
  t.references :user, null: false, foreign_key: true, type: :uuid
  t.string  :product_name,        null: false
  t.text    :product_description, null: false
  t.timestamps null: false
end
add_index :seller_profiles, :user_id, unique: true
```

**`Lead`**
```ruby
create_table :leads, id: :uuid do |t|
  t.references :user, null: false, foreign_key: true, type: :uuid
  t.string  :first_name,   null: false
  t.string  :last_name,    null: false
  t.string  :company,      null: false
  t.string  :company_size, null: false
  t.string  :role
  t.string  :email
  t.string  :website
  t.string  :stage,        null: false, default: "prospect"
  t.text    :notes
  t.timestamps null: false
end
add_index :leads, [:user_id, :stage]
add_index :leads, :created_at
```

**`OutreachEmail`**
```ruby
create_table :outreach_emails, id: :uuid do |t|
  t.references :lead, null: false, foreign_key: true, type: :uuid
  t.string :angle,            null: false
  t.string :subject
  t.text   :body
  t.text   :research_summary
  t.text   :sources
  t.text   :agent_trace
  t.text   :gemini_raw
  t.timestamps null: false
end
add_index :outreach_emails, [:lead_id, :created_at]
```

### Models

**`app/models/seller_profile.rb`**
- `belongs_to :user`
- `validates :product_name, presence: true`
- `validates :product_description, presence: true, length: { maximum: 500 }`
- `validates :user_id, uniqueness: true`

**`app/models/lead.rb`**
- `belongs_to :user`
- `has_many :outreach_emails, dependent: :destroy`
- `STAGES = %w[prospect contacted qualified proposal closed].freeze`
- `COMPANY_SIZES = %w[startup smb enterprise].freeze`
- `validates :first_name, :last_name, :company, :company_size, :stage, presence: true`
- `validates :stage, inclusion: { in: STAGES }`
- `validates :company_size, inclusion: { in: COMPANY_SIZES }`
- `validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true`
- Scope: `def self.grouped_by_stage` → returns hash keyed by stage name

**`app/models/outreach_email.rb`**
- `belongs_to :lead`
- `ANGLES = %w[value problem referral].freeze`
- `validates :angle, presence: true, inclusion: { in: ANGLES }`

**`app/models/user.rb`** — add `has_one :seller_profile, dependent: :destroy`

### Factories

**`spec/factories/seller_profiles.rb`**
```ruby
FactoryBot.define do
  factory :seller_profile do
    user
    product_name        { "TestProduct" }
    product_description { "A product that helps with testing." }
  end
end
```

**`spec/factories/leads.rb`**
```ruby
FactoryBot.define do
  factory :lead do
    user
    first_name   { "Jordan" }
    last_name    { "Ellis" }
    company      { "Acme Corp" }
    company_size { "startup" }
    role         { "Head of Growth" }
    stage        { "prospect" }

    trait :enterprise do
      company_size { "enterprise" }
      company      { "BigCo Inc" }
    end

    trait :contacted  { stage { "contacted" } }
    trait :qualified  { stage { "qualified" } }
    trait :proposal   { stage { "proposal" } }
    trait :closed     { stage { "closed" } }
  end
end
```

**`spec/factories/outreach_emails.rb`**
```ruby
FactoryBot.define do
  factory :outreach_email do
    lead
    angle   { "value" }
    subject { "Great opportunity for your company" }
    body    { "Hi there, I wanted to reach out..." }
    research_summary { "The agent found recent funding news." }
    sources { "https://example.com" }
    gemini_raw { '{"research_summary":"...","subject":"...","body":"...","sources":[]}' }

    trait :problem  { angle { "problem" } }
    trait :referral { angle { "referral" } }
  end
end
```

### RSpec Tests

**`spec/models/seller_profile_spec.rb`**
1. Valid with all required fields
2. Invalid without `product_name`
3. Invalid without `product_description`
4. Invalid if `product_description` exceeds 500 chars
5. Enforces one profile per user (unique `user_id`)

**`spec/models/lead_spec.rb`**
1. Valid with all required fields
2. Invalid without `first_name`, `last_name`, `company`, `company_size`, `stage`
3. Invalid with unrecognized `company_size` value
4. Invalid with unrecognized `stage` value
5. Destroys associated `outreach_emails` when deleted (dependent: :destroy)

**`spec/models/outreach_email_spec.rb`**
1. Valid with required fields
2. Invalid without `angle`
3. Invalid with unrecognized `angle` value
4. `belongs_to :lead`

### Manual Test Checklist

- [ ] Run `rails db:migrate` — no errors
- [ ] Open `rails console`, create a `SellerProfile`, `Lead`, and `OutreachEmail` — no errors
- [ ] Verify uniqueness constraint on `seller_profiles.user_id` raises on second create
- [ ] Verify `lead.destroy` cascades to `outreach_emails`

---

## Phase 3 — Core CRUD (Controllers, Views, Routes)

**Goal:** Full CRUD for Leads and SellerProfile. OutreachEmail show + destroy. No AI integration yet.

### Routes (`config/routes.rb`)

```ruby
resource  :seller_profile, only: [:edit, :update]
resources :leads do
  member do
    post :generate_outreach  # wired up in Phase 5
  end
end
resources :outreach_emails, only: [:show, :destroy]
```

GET `/leads` redirects to `/dashboard` (the pipeline is the index).

### Controllers

**`app/controllers/seller_profiles_controller.rb`**
- `edit`: `@seller_profile = current_user.seller_profile || SellerProfile.new`
- `update`: `find_or_initialize_by(user: current_user)`, update attributes. On success: redirect to `dashboard_path` with flash notice. On failure: re-render edit.
- Strong params: permit `product_name`, `product_description`

**`app/controllers/leads_controller.rb`**
- All actions scope to `current_user.leads`
- `index`: redirect to `dashboard_path`
- `new`: `@lead = Lead.new(stage: params[:stage] || "prospect")`
- `create`: on success redirect to `lead_path(@lead)`; on failure re-render new
- `show`: eager load `outreach_emails` ordered by `created_at desc`; also load `@seller_profile = current_user.seller_profile`
- `edit` / `update`: standard; on update success redirect to `lead_path`
- `destroy`: destroys lead, redirects to `dashboard_path` with notice
- Strong params: permit `first_name`, `last_name`, `company`, `company_size`, `role`, `email`, `website`, `stage`, `notes`

**`app/controllers/outreach_emails_controller.rb`**
- `show`: scope through current user's leads — `OutreachEmail.joins(:lead).where(leads: { user_id: current_user.id }).find(params[:id])`; 404 if not found
- `destroy`: same scoping; on destroy redirect to `lead_path(outreach_email.lead)` with notice

### Views

**`app/views/seller_profiles/edit.html.erb`**
- Single card form
- Fields: `product_name` (text input), `product_description` (textarea, 4 rows)
- Note: "This context appears in every outreach email the agent writes for you."
- Save button using accent color

**`app/views/leads/_form.html.erb`** (shared partial)
- Fields: first_name, last_name, company, role, email, website, notes
- `company_size` — Bootstrap select with options: "Startup" (startup), "Small/Mid-size Business" (smb), "Enterprise" (enterprise)
- Informational note below company_size select: "This determines how the agent researches your lead's company."
- `stage` — Bootstrap select with the five stage options
- Standard error display using `@lead.errors`

**`app/views/leads/new.html.erb`** — wraps `_form` partial with "New Lead" heading

**`app/views/leads/edit.html.erb`** — wraps `_form` partial with "Edit Lead" heading

**`app/views/leads/show.html.erb`** (without AI section — added in Phase 5/6)
- Two-panel `col-md-4` / `col-md-8` layout
- Left: lead details card (all fields), "Edit Lead" button, "Move Stage" dropdown
- "Move Stage" dropdown: Bootstrap dropdown; each option submits a PATCH to `lead_path` with `lead[stage]=value`; returns Turbo Stream; uses `data-action` on the dropdown items to submit a hidden form — implement via Stimulus `stage` controller
- Right: placeholder card "Outreach generation coming in Phase 5"
- Right panel wrapped in `turbo_frame_tag "outreach_panel"` (will be activated in Phase 5)

**`app/views/outreach_emails/show.html.erb`**
- Breadcrumb: Dashboard > [Lead Name] > Outreach [timestamp]
- Full outreach email display (more vertical space than the partial)
- Back link to parent lead
- Research summary, sources, email subject/body, raw response toggle
- (Partial will be built in Phase 6; this page can initially render the record fields directly)

### CSS

**`app/assets/stylesheets/application.css`** — add in Phase 1, referenced here:
- `.research-summary { border-left: 3px solid var(--accent); }`
- `.kanban-column { height: calc(100vh - 180px); overflow-y: auto; }`
- `.lead-card:hover { border-color: var(--accent) !important; cursor: pointer; }`

### Stimulus: `stage_controller.js`

Handles the Move Stage dropdown. Each dropdown item has a `data-action="click->stage#update"` and `data-stage-value` attribute. The controller submits a PATCH to the lead's URL with `lead[stage]`.

```javascript
// app/javascript/controllers/stage_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  update(event) {
    event.preventDefault()
    const stage = event.currentTarget.dataset.stageValue
    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        "Accept": "text/vnd.turbo-stream.html"
      },
      body: JSON.stringify({ lead: { stage } })
    })
  }
}
```

**Note:** The controller action for stage updates should handle `turbo_stream` format and return a stream that updates the flash and potentially redirects or updates the stage badge on the page.

### RSpec Tests

**`spec/requests/leads_spec.rb`**
1. `GET /leads/new` — redirects to sign in when unauthenticated
2. `POST /leads` — creates a lead scoped to `current_user`; redirects to lead show
3. `GET /leads/:id` — returns 404 for a lead belonging to a different user
4. `PATCH /leads/:id` — updates stage and returns Turbo Stream response (accept header)
5. `DELETE /leads/:id` — destroys the lead and redirects to dashboard
6. `GET /leads/:id/edit` — returns 200 for owner, 404 for other user

**`spec/requests/seller_profiles_spec.rb`**
1. `GET /seller_profile/edit` — redirects to sign in when unauthenticated
2. `PATCH /seller_profile` — creates or updates the `SellerProfile` for `current_user`
3. `PATCH /seller_profile` — does not update another user's profile (scoped by `current_user`)
4. `PATCH /seller_profile` with invalid data — re-renders edit with errors

**`spec/requests/outreach_emails_spec.rb`**
1. `GET /outreach_emails/:id` — returns 404 for an email belonging to a different user's lead
2. `DELETE /outreach_emails/:id` — destroys the record and redirects to parent lead

### Manual Test Checklist

- [ ] Sign in → visit `/seller_profile/edit` → fill in product name/description → save → flash notice → redirected to dashboard
- [ ] Visit `/leads/new` → fill form → create → redirected to lead show page
- [ ] Lead show page shows all fields in left panel
- [ ] "Edit Lead" button → edit form → save → back to show page
- [ ] "Move Stage" dropdown on show page changes stage (Turbo Stream response)
- [ ] Delete lead from show page → redirected to dashboard, lead gone
- [ ] Attempt to visit another user's lead → 404
- [ ] Form validation errors display inline on submit with missing required fields

---

## Phase 4 — Kanban Dashboard

**Goal:** Replace the dashboard with a five-column Kanban pipeline view. First-run SellerProfile prompt.

### DashboardController

**`app/controllers/dashboard_controller.rb`**
```ruby
def show
  @leads_by_stage = Lead::STAGES.index_with { |stage|
    current_user.leads.where(stage: stage).order(created_at: :desc)
  }
  @seller_profile = current_user.seller_profile
end
```

### Views

**`app/views/dashboard/show.html.erb`**

Structure:
```
[First-run alert if no seller_profile]
<div class="row g-3 flex-nowrap overflow-auto">
  [5x kanban column cards]
</div>
```

Each Kanban column:
```erb
<div class="col" style="min-width: 220px;">
  <div class="card bg-dark border-secondary h-100">
    <div class="card-header d-flex justify-content-between align-items-center">
      <span>[Stage Name]</span>
      <%= link_to "+", new_lead_path(stage: stage), class: "btn btn-sm btn-outline-warning" %>
    </div>
    <div class="card-body kanban-column p-2">
      [lead cards]
    </div>
  </div>
</div>
```

Each lead card (links to `lead_path(lead)`):
```erb
<%= link_to lead_path(lead), class: "text-decoration-none" do %>
  <div class="card mb-2 bg-dark border-secondary lead-card p-2">
    <div class="fw-semibold"><%= lead.first_name %> <%= lead.last_name %></div>
    <div class="small text-muted"><%= lead.company %></div>
    <div class="small text-muted"><%= lead.role %></div>
    <span class="badge mt-1" style="background-color: var(--secondary);">
      <%= lead.company_size %>
    </span>
  </div>
<% end %>
```

First-run prompt (amber dismissible alert):
```erb
<% unless @seller_profile %>
  <div class="alert alert-warning alert-dismissible fade show mb-4" role="alert">
    <strong>Set up your product context</strong> before generating outreach.
    <%= link_to "Set it up now →", edit_seller_profile_path, class: "alert-link" %>
    <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
  </div>
<% end %>
```

### Manual Test Checklist

- [ ] Visit `/dashboard` — see five columns (Prospect, Contacted, Qualified, Proposal, Closed)
- [ ] New user with no leads — columns are empty, first-run alert is visible
- [ ] Dismiss first-run alert — it closes (Bootstrap dismiss)
- [ ] Click "+" in any column — new lead form pre-populated with that stage
- [ ] Create a lead → it appears in the correct column after redirect
- [ ] Lead cards link to the lead show page
- [ ] Dashboard scrolls horizontally on narrow viewports
- [ ] After creating a SellerProfile, first-run alert no longer appears

### RSpec Tests

None specific to this phase (dashboard is covered by manual testing; request spec is basic auth check already in boilerplate).

---

## Phase 5 — Gemini Agent Integration

**Goal:** Wire up the AI outreach generation with function calling, web search, URL fetch, Turbo Stream progress, and full error handling.

### Overview

This phase adds:
1. `GeminiService.generate_with_tools` — extends GeminiService for multi-turn function calling
2. `SerperService` — Serper.dev web search
3. `FetchUrlService` — URL content extraction
4. `LeadsController#generate_outreach` — the generation action
5. AiTemplate seeds for startup and enterprise templates
6. Rate limiting on the generate endpoint
7. Turbo Stream progress feed on the lead show page
8. `outreach` Stimulus controller

### `app/services/serper_service.rb`

```ruby
class SerperService
  BASE_URL = "https://google.serper.dev/search"
  MAX_CHARS = 1500

  def self.search(query)
    new.search(query)
  end

  def search(query)
    return placeholder_response(query) if api_key.blank?

    response = Faraday.post(BASE_URL,
      { q: query, num: 5 }.to_json,
      "Content-Type" => "application/json",
      "X-API-KEY" => api_key
    )
    parse_response(JSON.parse(response.body))
  rescue => e
    "Search failed: #{e.message}"
  end

  private

  def api_key = ENV.fetch("SERPER_API_KEY", "")

  def parse_response(data)
    results = (data["organic"] || []).first(5).map do |r|
      "#{r['title']} — #{r['snippet']} (#{r['link']})"
    end.join("\n")
    results.truncate(MAX_CHARS)
  end

  def placeholder_response(query)
    "No SERPER_API_KEY configured. Cannot search for: #{query}"
  end
end
```

### `app/services/fetch_url_service.rb`

```ruby
class FetchUrlService
  MAX_CHARS = 2000
  USER_AGENT = "Mozilla/5.0 (compatible; CollectiveCRM-Agent/1.0)"

  def self.fetch(url)
    new.fetch(url)
  end

  def fetch(url)
    response = Faraday.get(url, nil, "User-Agent" => USER_AGENT)
    extract_content(response.body, url)
  rescue => e
    "Could not fetch #{url}: #{e.message}"
  end

  private

  def extract_content(html, url)
    title   = html.match(/<title[^>]*>(.*?)<\/title>/mi)&.captures&.first&.strip || ""
    meta    = html.match(/<meta\s+name="description"\s+content="([^"]+)"/i)&.captures&.first&.strip || ""
    paras   = html.scan(/<p[^>]*>(.*?)<\/p>/mi).flatten.map { |p| p.gsub(/<[^>]+>/, "").strip }.reject(&:blank?).first(5).join(" ")

    result = [title.presence && "Title: #{title}", meta.presence && "Description: #{meta}", paras.presence].compact.join("\n")
    result.truncate(MAX_CHARS)
  end
end
```

### `GeminiService.generate_with_tools`

Extend `app/services/gemini_service.rb` to add a class method `generate_with_tools`. This method:

1. Runs the same gatekeeper + budget + logging flow as `generate`
2. Builds the tool definitions for `search_web` and `fetch_url`
3. Sends the initial request to Gemini with `tools` array in the API payload
4. Enters the agent loop (max 5 rounds):
   - If response contains `functionCall`: execute the tool, append result, call Gemini again
   - If response contains text: exit loop, return structured result
5. Returns a hash: `{ raw: String, trace: Array }` where `trace` is the array of all tool calls

**API format for function calling** (v1beta):
```json
{
  "contents": [...],
  "tools": [{
    "functionDeclarations": [
      { "name": "search_web", "description": "...", "parameters": { "type": "OBJECT", "properties": { "query": { "type": "STRING" } }, "required": ["query"] } },
      { "name": "fetch_url",  "description": "...", "parameters": { "type": "OBJECT", "properties": { "url":   { "type": "STRING" } }, "required": ["url"] } }
    ]
  }]
}
```

**Multi-turn conversation** — maintain a `contents` array. Each round adds a `model` role entry (the function call) and a `user` role entry (the function result as `functionResponse`).

**Endpoint:** Same v1beta `generateContent` endpoint; tools are a separate top-level field.

**Progress streaming:** Before each tool execution, the method yields a status string if a block is given. The controller uses this to push Turbo Stream updates.

```ruby
def self.generate_with_tools(template:, variables:, tools: [], user:, &progress_block)
  # ... gatekeeper, budget, log setup (same as generate) ...
  # agent loop with yield for progress
end
```

### `LeadsController#generate_outreach`

```ruby
def generate_outreach
  @lead           = current_user.leads.find(params[:id])
  @seller_profile = current_user.seller_profile

  unless @seller_profile
    render turbo_stream: turbo_stream.update("outreach_progress",
      "<div class='alert alert-warning'>Please set up your seller profile first.</div>")
    return
  end

  angle         = params[:angle].presence || "value"
  template_name = @lead.company_size == "enterprise" ?
    "collectivecrm_outreach_enterprise_v1" :
    "collectivecrm_outreach_startup_v1"

  result = GeminiService.generate_with_tools(
    template:  template_name,
    variables: outreach_variables(@lead, @seller_profile, angle),
    user:      current_user
  ) do |status_message|
    response.stream.write(
      turbo_stream.update("outreach_progress", "<p class='text-muted small'>#{status_message}</p>")
    )
  end

  parsed   = JSON.parse(result[:raw])
  @outreach = OutreachEmail.create!(
    lead:             @lead,
    angle:            angle,
    subject:          parsed["subject"],
    body:             parsed["body"],
    research_summary: parsed["research_summary"],
    sources:          Array(parsed["sources"]).join("\n"),
    agent_trace:      result[:trace].to_json,
    gemini_raw:       result[:raw]
  )

  render turbo_stream: [
    turbo_stream.update("outreach_progress", ""),
    turbo_stream.prepend("outreach_results", partial: "outreach_emails/outreach_email", locals: { outreach_email: @outreach })
  ]

rescue JSON::ParseError
  render turbo_stream: turbo_stream.update("outreach_progress",
    render_to_string(partial: "shared/ai_error", locals: { error_type: :error }))
rescue GeminiService::BudgetExceededError
  render turbo_stream: turbo_stream.update("outreach_progress",
    render_to_string(partial: "shared/ai_error", locals: { error_type: :budget_exceeded }))
rescue GeminiService::GatekeeperError
  render turbo_stream: turbo_stream.update("outreach_progress",
    render_to_string(partial: "shared/ai_error", locals: { error_type: :gatekeeper_blocked }))
rescue GeminiService::TimeoutError
  render turbo_stream: turbo_stream.update("outreach_progress",
    render_to_string(partial: "shared/ai_error", locals: { error_type: :timeout }))
rescue GeminiService::GeminiError
  render turbo_stream: turbo_stream.update("outreach_progress",
    render_to_string(partial: "shared/ai_error", locals: { error_type: :error }))
end

private

def outreach_variables(lead, profile, angle)
  {
    first_name:          lead.first_name,
    last_name:           lead.last_name,
    role:                lead.role.to_s,
    company:             lead.company,
    company_size:        lead.company_size,
    website:             lead.website.to_s,
    notes:               lead.notes.to_s,
    product_name:        profile.product_name,
    product_description: profile.product_description,
    angle:               angle
  }
end
```

### Lead Show Page Updates

Add to the right panel of `leads/show.html.erb`:

```erb
<%# AI disclaimer %>
<div class="alert alert-secondary small mb-3">
  The agent searches the web and may find outdated or incorrect information.
  Review the research summary and verify the sources before sending any email.
</div>

<%# Generate Outreach form %>
<div data-controller="outreach" data-outreach-url-value="<%= generate_outreach_lead_path(@lead) %>">
  <div class="btn-group w-100 mb-3" role="group">
    <input type="radio" class="btn-check" name="angle" id="angle_value"   value="value"   data-outreach-target="angle" checked>
    <label class="btn btn-outline-warning" for="angle_value">Value-focused</label>
    <input type="radio" class="btn-check" name="angle" id="angle_problem" value="problem" data-outreach-target="angle">
    <label class="btn btn-outline-warning" for="angle_problem">Problem-focused</label>
    <input type="radio" class="btn-check" name="angle" id="angle_referral" value="referral" data-outreach-target="angle">
    <label class="btn btn-outline-warning" for="angle_referral">Referral-focused</label>
  </div>
  <button class="btn btn-warning w-100 mb-3"
          data-action="click->outreach#generate"
          data-outreach-target="button">
    Research and Write Outreach
  </button>
</div>

<div id="outreach_progress" class="mb-3"></div>

<div id="outreach_results">
  <%= render @outreach_emails %>
</div>
```

### Rate Limiting

Add to `LeadsController`:
```ruby
rate_limit to: 5, within: 1.minute, only: [:generate_outreach],
           with: -> { render turbo_stream: turbo_stream.update("outreach_progress",
             "<div class='alert alert-warning'>Please wait before generating again.</div>") }
```

### `outreach_controller.js` (Stimulus)

Handles the generate button: disables it during request, shows loading text.

```javascript
// app/javascript/controllers/outreach_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "angle"]
  static values  = { url: String }

  generate(event) {
    event.preventDefault()
    const angle = this.angleTargets.find(r => r.checked)?.value || "value"

    this.buttonTarget.disabled    = true
    this.buttonTarget.textContent = "Researching..."

    fetch(this.urlValue, {
      method:  "POST",
      headers: {
        "Content-Type":  "application/json",
        "X-CSRF-Token":  document.querySelector('meta[name="csrf-token"]').content,
        "Accept":        "text/vnd.turbo-stream.html"
      },
      body: JSON.stringify({ angle })
    })
    .then(r => r.text())
    .then(html => Turbo.renderStreamMessage(html))
    .finally(() => {
      this.buttonTarget.disabled    = false
      this.buttonTarget.textContent = "Research and Write Outreach"
    })
  }
}
```

### AiTemplate Seeds

Add to `db/seeds.rb` (model names noted: `gemini-2.5-flash` overrides PRD's `gemini-2.0-flash`):

```ruby
AiTemplate.find_or_create_by!(name: "collectivecrm_outreach_startup_v1") do |t|
  t.description       = "Researches startup leads via funding search, role context, and homepage; writes personalized outreach."
  t.system_prompt     = <<~PROMPT.strip
    [full system prompt from PRD §7]
  PROMPT
  t.user_prompt_template = <<~PROMPT.strip
    [full user prompt template from PRD §7]
  PROMPT
  t.model             = "gemini-2.5-flash"  # NOT gemini-2.0-flash
  t.max_output_tokens = 3000
  t.temperature       = 0.6
  t.notes             = "Startup/SMB research path..."
end

AiTemplate.find_or_create_by!(name: "collectivecrm_outreach_enterprise_v1") do |t|
  # ... enterprise template from PRD §7 ...
  t.model             = "gemini-2.5-flash"  # NOT gemini-2.0-flash
  t.max_output_tokens = 3000
  t.temperature       = 0.55
end
```

### RSpec Tests

**`spec/requests/leads_generate_outreach_spec.rb`**
1. Uses startup template when `company_size` is "startup"
2. Uses enterprise template when `company_size` is "enterprise"
3. Creates an `OutreachEmail` record on success
4. Returns Turbo Stream response on success
5. Returns inline error Turbo Stream when `GeminiService` raises `GeminiError`
6. Returns inline error Turbo Stream when budget exceeded
7. Stores `agent_trace` JSON on the created `OutreachEmail`
8. Stores `sources` on the created `OutreachEmail`
9. Requires authentication (redirects to sign in when not signed in)
10. Returns 404 for a lead belonging to a different user

**Stubbing strategy:** Stub `GeminiService.generate_with_tools` to return `{ raw: valid_json_string, trace: [{...}] }` for success cases. Use `allow(GeminiService).to receive(:generate_with_tools).and_raise(...)` for error cases.

### Manual Test Checklist

- [ ] Visit lead show page — see AI disclaimer, angle selector, generate button
- [ ] Without seller profile — generate button shows warning (no seller profile)
- [ ] With seller profile, no SERPER_API_KEY — generates outreach using fetch_url only
- [ ] With seller profile and SERPER_API_KEY — progress feed shows "Researching [Company]..." messages during generation
- [ ] After generation — new outreach email card appears in results panel
- [ ] Error case — trigger budget exceeded (set `AI_CALLS_PER_USER_PER_DAY=0`) → error partial displayed inline
- [ ] Admin panel `/admin/llm_requests` — shows the call with status, duration, tokens

---

## Phase 6 — Outreach Email Display

**Goal:** Build the outreach email partial and show page. Add copy-to-clipboard Stimulus controller.

### `app/views/outreach_emails/_outreach_email.html.erb`

Structure per PRD §6:
1. **Header row:** angle badge (amber for value, blue for problem, green for referral) + timestamp + delete button
2. **Research summary** — Bootstrap collapse toggle labeled "What the agent found"; inside: `alert alert-info research-summary` with the summary text and bulleted source URLs
3. **Email card** — subject as `<h6>`, body as `<pre class="text-wrap">`, copy-to-clipboard button (Stimulus `clipboard` controller)
4. **Raw response toggle** — Bootstrap collapse revealing `gemini_raw` content in a `<pre>`

**Angle badge colors:**
- `value` → `badge bg-warning text-dark`
- `problem` → `badge bg-primary`
- `referral` → `badge bg-success`

**Delete button:**
```erb
<%= link_to "Delete", outreach_email_path(outreach_email),
    data: { turbo_method: :delete, turbo_confirm: "Delete this outreach email?" },
    class: "btn btn-sm btn-outline-danger" %>
```

**Source URLs** — render as `<ul>` with each URL as a `<li><a href="...">` link. Split on newlines from `sources` field.

### `clipboard_controller.js` (Stimulus)

```javascript
// app/javascript/controllers/clipboard_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button"]

  copy() {
    navigator.clipboard.writeText(this.sourceTarget.textContent)
    this.buttonTarget.textContent = "Copied!"
    setTimeout(() => { this.buttonTarget.textContent = "Copy" }, 2000)
  }
}
```

Usage in partial:
```erb
<div data-controller="clipboard">
  <pre class="text-wrap" data-clipboard-target="source"><%= outreach_email.body %></pre>
  <button class="btn btn-sm btn-outline-secondary" data-action="click->clipboard#copy" data-clipboard-target="button">Copy</button>
</div>
```

### `app/views/outreach_emails/show.html.erb`

- Container with breadcrumb: Dashboard › [Lead name] › Outreach (formatted timestamp)
- Back link: `link_to "← Back to Lead", lead_path(@outreach_email.lead)`
- Renders the same content as the partial but with more padding
- Can DRY this by rendering the `_outreach_email` partial with `show: true` local if desired

### Manual Test Checklist

- [ ] Generate an outreach email → card appears in results with angle badge and timestamp
- [ ] Click "What the agent found" → research summary collapses open; source URLs are clickable
- [ ] Click "Copy" on email body → button briefly says "Copied!"
- [ ] Click "Show raw response" → raw JSON displayed in `<pre>` block
- [ ] Click "Delete" on an outreach email → confirm dialog → card removed → redirected to lead page
- [ ] Visit `/outreach_emails/:id` directly → full-page view with breadcrumb
- [ ] Visit another user's outreach email URL → 404

### RSpec Tests

Run existing `spec/requests/outreach_emails_spec.rb` (already written in Phase 3).

---

## Phase 7 — Seeds, README & Final Polish

**Goal:** Complete `db/seeds.rb`, update README, add final safety notes.

### `db/seeds.rb`

Full seed file contents per PRD §10:

```ruby
# Demo user (already created by boilerplate seed)
demo_user = User.find_or_create_by!(email: "demo@example.com") do |u|
  u.name     = "Demo User"
  u.password = "password123"
  u.admin    = true
end

# AiTemplates (health_ping from boilerplate, plus the two CollectiveCRM templates)
AiTemplate.find_or_create_by!(name: "health_ping") { ... }  # keep existing boilerplate seed

AiTemplate.find_or_create_by!(name: "collectivecrm_outreach_startup_v1") { ... }
AiTemplate.find_or_create_by!(name: "collectivecrm_outreach_enterprise_v1") { ... }

# SellerProfile for demo user
SellerProfile.find_or_create_by!(user: demo_user) do |sp|
  sp.product_name        = "CollectiveCRM"
  sp.product_description = "A multi-tenant CRM for sales teams that uses AI to research leads and write personalized outreach. Helps SDRs spend more time selling and less time doing research."
end

# 5 sample leads across all stages and company sizes
leads_data = [
  { first_name: "Jordan", last_name: "Ellis",      company: "Lattice",   company_size: "startup",    role: "Head of Growth",              email: nil,                     website: "https://lattice.com",  stage: "prospect",  notes: "Saw their Series C announcement last week." },
  { first_name: "Priya",  last_name: "Nair",       company: "Figma",     company_size: "enterprise", role: "VP Sales",                    email: "priya@figma.com",       website: "https://figma.com",    stage: "contacted", notes: nil },
  { first_name: "Marcus", last_name: "Webb",        company: "Tally",     company_size: "startup",    role: "Founder",                     email: nil,                     website: "https://tally.so",     stage: "qualified", notes: "No-code form builder. Recently launched a new paid plan." },
  { first_name: "Sarah",  last_name: "Kim",         company: "HubSpot",   company_size: "enterprise", role: "Director of Revenue Operations", email: "sarah@hubspot.com", website: "https://hubspot.com",  stage: "proposal",  notes: nil },
  { first_name: "Tomasz", last_name: "Wierzbicki",  company: "Typeform",  company_size: "smb",        role: "CEO",                         email: nil,                     website: "https://typeform.com", stage: "closed",    notes: nil }
]

leads_data.each do |attrs|
  Lead.find_or_create_by!(user: demo_user, first_name: attrs[:first_name], company: attrs[:company]) do |l|
    l.assign_attributes(attrs.except(:first_name, :company))
    l.user = demo_user
  end
end

# Sample OutreachEmail for Priya Nair / Figma
priya_lead = Lead.find_by(user: demo_user, first_name: "Priya", company: "Figma")
if priya_lead && priya_lead.outreach_emails.empty?
  gemini_json = {
    research_summary: "Figma recently unveiled Config 2024 with major updates to their Dev Mode and new AI-powered design tools. The announcements were widely covered and positioned Figma as doubling down on the developer-designer collaboration space.",
    sources: ["https://figma.com/blog/config-2024", "https://techcrunch.com/2024/06/figma-config"],
    subject: "Saw the Figma Config announcements",
    body: "Hi Priya,\n\nCongratulations on the Config 2024 announcements — the Dev Mode improvements in particular seemed to land well with the engineering community.\n\nAt CollectiveCRM, we work with VP Sales and revenue ops leaders at product-led companies who are scaling outbound. The challenge we hear most often is that the research step before outreach takes 20+ minutes per lead — and SDRs skip it.\n\nOur AI agent does the research automatically: it searches for recent news, reads the company website, and writes an opening line that references something real. The result is higher reply rates without adding headcount.\n\nWould a 20-minute call make sense? Happy to show you the pipeline view.\n\nBest,\nDemo"
  }.to_json

  OutreachEmail.create!(
    lead:             priya_lead,
    angle:            "value",
    subject:          "Saw the Figma Config announcements",
    body:             JSON.parse(gemini_json)["body"],
    research_summary: JSON.parse(gemini_json)["research_summary"],
    sources:          JSON.parse(gemini_json)["sources"].join("\n"),
    agent_trace:      [{ tool: "search_web", args: { query: "Figma news 2024" }, result: "Config 2024 announced..." }].to_json,
    gemini_raw:       gemini_json
  )
end
```

### README Updates

Add to the project README (per PRD §11):
1. App name and tagline
2. Description paragraph
3. "Why I Built This" section
4. Screenshot placeholder
5. Additional setup section for Serper.dev API key
6. Note about Serper.dev privacy (company name + role sent to third-party API)
7. Seed credentials: `demo@example.com` / `password123`

### Final Polish

- Verify AI disclaimer is present on lead show page above the generate button
- Verify footer AI disclaimer is inherited from layout
- Verify `AI_CALLS_PER_USER_PER_DAY=20` default in `.env.example`
- Verify `SERPER_API_KEY` fallback (graceful if missing)
- Check all route helpers are named (no string paths in views)
- Run `bundle exec rspec` — full green suite

### Manual Test Checklist

- [ ] `rails db:seed` — no errors
- [ ] Visit `/dashboard` as `demo@example.com` — see all 5 sample leads in correct columns
- [ ] Priya Nair (Figma) already has a sample outreach email in her show page
- [ ] Visit `/admin/ai_templates` — see both CollectiveCRM templates
- [ ] All five stages populated, board scrolls correctly
- [ ] README instructions are accurate (test `bin/setup` from scratch if possible)

---

## Phase 8 — Full Test Suite

**Goal:** All RSpec specs passing. No real API calls.

### Full Spec File List

```
spec/
  models/
    seller_profile_spec.rb    # Phase 2
    lead_spec.rb              # Phase 2
    outreach_email_spec.rb    # Phase 2
    user_spec.rb              # boilerplate (verify unchanged)
    ai_template_spec.rb       # boilerplate (verify unchanged)
  requests/
    leads_spec.rb                      # Phase 3
    seller_profiles_spec.rb            # Phase 3
    outreach_emails_spec.rb            # Phase 3 / Phase 6
    leads_generate_outreach_spec.rb    # Phase 5
  services/
    ai_gatekeeper_spec.rb     # boilerplate (verify unchanged)
    ai_budget_checker_spec.rb # boilerplate (verify unchanged)
    gemini_service_spec.rb    # boilerplate + generate_with_tools additions
```

### `generate_with_tools` additions to `gemini_service_spec.rb`

Add these contexts to the existing service spec:
1. Raises `ActiveRecord::RecordNotFound` for missing template name
2. Returns a hash with `:raw` and `:trace` keys on success
3. Logs an `LlmRequest` row with status `success`
4. Calls `AiGatekeeper.check!` before making the API call
5. Calls `AiBudgetChecker.check!` before making the API call

### Running the Suite

```bash
bundle exec rspec                          # full suite
bundle exec rspec spec/models/             # model specs only
bundle exec rspec spec/requests/           # request specs only
bundle exec rspec --format documentation   # verbose
```

**Verify:** Zero real API calls (check that no network requests are made to `generativelanguage.googleapis.com` or `google.serper.dev` during the test run).

---

## Appendix: File Creation Order

Suggested order to minimize blocked steps:

1. `.env.example`, `application.css` (Phase 1)
2. Home page, navbar (Phase 1)
3. Migrations + models (Phase 2)
4. Factories + model specs (Phase 2)
5. Routes (Phase 3)
6. SellerProfilesController + views (Phase 3)
7. LeadsController CRUD + views (Phase 3)
8. OutreachEmailsController (Phase 3)
9. Request specs for Phase 3 (Phase 3)
10. DashboardController + Kanban view (Phase 4)
11. SerperService + FetchUrlService (Phase 5)
12. `GeminiService.generate_with_tools` (Phase 5)
13. AiTemplate seeds (Phase 5)
14. `LeadsController#generate_outreach` + Stimulus outreach controller (Phase 5)
15. Outreach generate request specs (Phase 5)
16. Outreach email partial + clipboard controller (Phase 6)
17. Outreach email show page (Phase 6)
18. Complete seeds (Phase 7)
19. README updates (Phase 7)
20. Full spec run + fixes (Phase 8)
