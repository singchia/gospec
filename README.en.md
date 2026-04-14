# gospec — Go SDLC spec skill for AI coding agents

[中文](README.md) | **English**

> **A spec skill that teaches AI coding agents how to do Go SDLC the right way — from requirements to incident response.**

---

## What is this

`gospec` is an [Open Agent Skill](https://skills.sh) for Go backend projects, written in Chinese with full English install support. It tells the agent:

- Which requirement artifact to use (Issue / RFC / PRD / Epic) for any given change
- What design work is required before coding (layering / monorepo / ADR / HLD)
- The red lines when writing APIs / data models / code / tests
- The PR self-check list before merging
- What observability / security / ops preparation is needed before shipping
- How to run postmortems and incident response after shipping

It is not a static document. It is a **progressive-disclosure knowledge base**: the agent reads a routing table first, then loads only the 1–3 files relevant to the current task. No context-window flooding.

> The spec body is in **Chinese**. This matches the primary audience and works seamlessly with any modern LLM. If you need an English adaptation, open an issue — a translation pass is on the roadmap.

## Tech stack baseline

| Layer | Choice |
|-------|--------|
| Language | Go 1.21+ |
| Web framework | go-kratos/kratos v2 |
| API protocol | Protocol Buffers v3 + gRPC + HTTP/REST |
| ORM | gorm.io/gorm |
| Storage | MySQL / Redis / ClickHouse / InfluxDB |
| Logging | `log/slog` (preferred) or zap |
| Metrics | Prometheus client_golang |
| Tracing | OpenTelemetry |
| Auth | Casdoor + JWT |
| Testing | testing + testify + testcontainers-go |
| CI/CD | GitHub Actions + golangci-lint + govulncheck + trivy + cosign |

Full rationale in `spec/05-coding/README.md`.

---

## Repository layout

```
gospec/
├── spec/                  # Specification body (organized by SDLC stage)
│   ├── spec.md            # Entry point: task routing table + core constraints
│   ├── 01-requirement/    # Requirements (issue/rfc/prd/epic/lifecycle)
│   ├── 02-architecture/   # Architecture (layering/monorepo/ADR/HLD)
│   ├── 03-api/            # API (proto/http/middleware/versioning)
│   ├── 04-data-model/     # Data models (mysql/redis/clickhouse/influxdb)
│   ├── 05-coding/         # Coding (naming/errors/concurrency/patterns/style)
│   ├── 06-testing/        # Testing (unit/integration/fuzz-bench)
│   ├── 07-code-review.md  # PR self-check list
│   ├── 08-delivery/       # Delivery (git/cicd/release)
│   ├── 09-documentation.md
│   ├── 10-observability/  # Logs / metrics / traces / SLO
│   ├── 11-security/       # AuthN/Z / input / secrets / privacy / threat modeling
│   ├── 12-operations/     # Deploy / incident / capacity / backup
│   └── 13-database-migration/  # Migration / online DDL / data governance
│
├── docs/
│   └── templates/         # Copy-paste document templates (single source of truth)
│       ├── product-requirement-template.md       (PRD)
│       ├── technical-rfc-template.md             (RFC)
│       ├── architecture-decision-record-template.md  (ADR)
│       ├── high-level-design-template.md         (HLD)
│       ├── pull-request-template.md              (PR)
│       └── project-agents-template.md            (project-root AGENTS.md)
│
├── scripts/
│   ├── install.sh         # User install script (one-liner: install skill + create AGENTS.md)
│   ├── build-skill.py     # Maintainer script: build the .skill artifact (cross-platform, used by CI)
│   ├── build-skill.sh     # Maintainer script: bash equivalent of build-skill.py
│   └── validate-skill.py  # Self-contained frontmatter + required-file validator
│
├── .github/
│   └── workflows/
│       ├── validate.yml   # Runs on push/PR: validate + smoke-test build
│       └── release.yml    # Runs on tag push: build and publish .skill to GitHub Releases
│
├── SKILL.md               # Skill manifest (Claude Code entry point)
├── AGENTS.md              # Agent behavior entry point
├── CHANGELOG.md
├── LICENSE                # MIT
├── README.md              # Chinese README (default)
└── README.en.md           # This file
```

---

## Key features

### 1. Progressive disclosure

The agent never reads the whole spec at once. `spec/spec.md` contains a task-to-file routing table:

```
Writing a new HTTP handler
→ 03-api/proto.md + 03-api/http.md + 05-coding/errors.md
→ Optionally 11-security/auth.md, 10-observability/logging.md

Writing a MySQL migration
→ 13-database-migration/migration.md
→ For large tables, also online-ddl.md

Deploying / rolling back
→ 12-operations/deployment.md
```

A typical task loads 2–5 sub-files, each 80–300 lines. No context bloat.

### 2. Multi-store coverage

The data layer is not just MySQL. `04-data-model/` ships design constraints for four major stores:

- **MySQL** (GORM / DAO / transactions / indexes / cursor pagination)
- **Redis** (key naming / TTL / big keys / distributed locks / cache stampede/penetration/avalanche)
- **ClickHouse** (MergeTree family / LowCardinality / batch writes / materialized views)
- **InfluxDB** (tag vs field / cardinality control / retention / downsampling)

### 3. Single-service + monorepo

`02-architecture/` covers both the **intra-service layering** (`cmd → web → controlplane → repo → model`) and the **monorepo repo structure** (`cmd/ internal/ pkg/ api/`), module strategy (single `go.mod` vs `go.work`), domain boundaries, `CODEOWNERS`, and CI affected detection.

### 4. Design patterns library

`05-coding/patterns.md` covers 10 Go patterns that actually earn their keep:

Functional Options / Constructor Injection / Strategy / Decorator / Adapter / Worker Pool / Pipeline / Errgroup / Retry + Backoff / Outbox

Each pattern is paired with "when NOT to use" and common anti-patterns, so the agent doesn't over-apply them.

### 5. Full SDLC right-shift

The spec goes well beyond "how to write code":

- `10-observability/` — logs / metrics / traces / SLO / alerting
- `11-security/` — threat modeling / auth / input hardening / secrets management / supply chain / container security / privacy
- `12-operations/` — deploy strategies / rollback / feature flags / on-call / incident response / postmortems / capacity / chaos / backup & DR
- `13-database-migration/` — migration tooling / online DDL / backfill / data retention

### 6. Requirement artifact tiers

`01-requirement/` explicitly separates four requirement artifact types, each with its own workflow:

- **Issue** — bugs / small changes / config tweaks, stored in issue tracker
- **RFC** — pure technical changes (refactors, dep upgrades, performance work)
- **PRD** — user-facing feature changes
- **Epic** — multi-PRD strategic initiatives

Shared lifecycle rules cover promotion (how a long issue discussion graduates into an ADR / RFC / postmortem), state gates, amendment tracking, and outcome reviews.

---

## How to use

gospec is compatible with the [skills.sh](https://skills.sh) Open Agent Skills protocol, which means any [skills.sh-compatible agent](https://skills.sh) (45+ agents including Claude Code, Cursor, Cline, Codex, Gemini CLI, GitHub Copilot) can install it with `npx skills add`.

### Method 1: `npx skills add` (recommended, standard entry point)

Run this in the root of your Go project:

```bash
cd your-go-project
npx skills add singchia/gospec        # project-level install to .claude/skills/gospec/
# Or globally:
npx skills add singchia/gospec -g     # installs to ~/.claude/skills/gospec/
```

From then on, any SKILL.md-aware agent (e.g. Claude Code) auto-activates gospec when you write or review Go code, and on first activation prompts you to drop an `AGENTS.md` at your project root.

### Method 2: `install.sh` (one-liner with automatic AGENTS.md drop)

If you want `AGENTS.md` at your project root immediately (without waiting for agent prompting), or your agent doesn't read `SKILL.md` and relies on `AGENTS.md` for discovery:

```bash
cd your-go-project
bash <(curl -sSL https://raw.githubusercontent.com/singchia/gospec/main/scripts/install.sh)
```

This one-liner does two things:

1. **Installs the gospec skill** to `~/.claude/skills/gospec/` (if not already there)
2. **Creates `AGENTS.md` in the current directory** so any AI agent entering this project immediately sees it

From then on, any agent (Claude Code, Cursor, Cline, Codex, Gemini CLI, GitHub Copilot) opening your project finds `AGENTS.md` at root and is directed to the gospec routing table + core constraints.

> **AGENTS.md vs SKILL.md**:
> - `SKILL.md` is the [skills.sh](https://skills.sh) manifest that Claude Code auto-loads — its scope is the skill itself.
> - `AGENTS.md` is the [agentsmd.net](https://agentsmd.net) open convention placed at the project root, telling **every** agent "this project uses gospec".
> - The two are complementary: `SKILL.md` solves "how does an agent load skill content", `AGENTS.md` solves "how does an agent know which skills this project uses".

### Method 3: Project-scoped `install.sh` (no impact on other projects)

```bash
cd your-go-project
SKILL_DIR=.claude/skills/gospec bash <(curl -sSL https://raw.githubusercontent.com/singchia/gospec/main/scripts/install.sh)
```

### Method 4: Manual install

```bash
# 1. Clone the skill
git clone https://github.com/singchia/gospec ~/.claude/skills/gospec

# 2. Copy AGENTS.md into your project root
cd your-go-project
cp ~/.claude/skills/gospec/docs/templates/project-agents-template.md ./AGENTS.md

# 3. Commit
git add AGENTS.md && git commit -m "chore: add gospec AGENTS.md"
```

### Method 5: Offline / air-gapped (.skill package)

GitHub Releases ships a pre-packaged `gospec.skill` (zip, ~140 KB):

```bash
curl -L -o gospec.skill https://github.com/singchia/gospec/releases/latest/download/gospec.skill
unzip gospec.skill -d ~/.claude/skills/
cp ~/.claude/skills/gospec/docs/templates/project-agents-template.md ./AGENTS.md
```

Or build it yourself:

```bash
git clone https://github.com/singchia/gospec && cd gospec

# Cross-platform (recommended — Windows / macOS / Linux, only python3 + pyyaml required)
python3 scripts/build-skill.py         # outputs ./dist/gospec.skill

# Or bash version (macOS / Linux only, needs bash + zip)
scripts/build-skill.sh
```

### Reading as a human

Even without an AI agent, this spec works as a team SDLC handbook. Every sub-directory has a `README.md` acting as a secondary routing table, and every sub-file has an "applicable scenarios" header plus a trailing self-check list.

### Verifying the installation

After install, ask your agent:

> I have a new task: migrate the project from klog to log/slog. Please drive this following the gospec workflow.

The agent should:

1. Read `AGENTS.md` or auto-activate the gospec skill
2. Read the task routing table in `spec/spec.md`
3. Determine this is a technical change, so it goes through an RFC (not a PRD / issue)
4. Read `spec/01-requirement/technical-rfc.md` and `docs/templates/technical-rfc-template.md`
5. Propose creating `docs/rfc/RFC-001-migrate-to-slog.md`

If the agent doesn't follow this path, check:

- Does `AGENTS.md` exist in the project root?
- Does `~/.claude/skills/gospec/SKILL.md` exist?

---

## Spec principles

1. **Progressive disclosure**: SKILL.md → spec.md (routing table) → sub-files (on-demand loading)
2. **Single source of truth**: rules in `spec/`, templates in `docs/templates/`, no duplication
3. **Cross-reference, don't copy**: cross-cutting topics (e.g. `trace_id` context propagation) are defined in one place, everything else links to it
4. **Hard constraints as guardrails**: `spec/spec.md` has a "core constraints" section the agent remembers at all times, even without loading sub-files
5. **Every sub-file has a self-check list**: the agent runs the check at task completion
6. **Templates are decoupled from rules**: `docs/templates/` are copy-paste starting points; `spec/` describes the rules and required fields

---

## Contributing

PRs and issues welcome. This project follows its own spec — please check `spec/08-delivery/git.md` for commit conventions.

## License

[MIT](LICENSE)
