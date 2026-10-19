# README Redesign Plan — openp41ge/browser

Status: agreed work, not yet done
This is a working plan for contributors/agents. It is **not** the README.

## Goal

Rewrite this repo's `README.md` so it reads as a **project-overview** document
rather than developer onboarding. It should:

1. say **what this repo is** (the openp41ge companion web browser);
2. place it **within the openp41ge project** and name its **relationship to the sibling repos**;
3. **point elsewhere** for any developer onboarding — it must not contain build/setup/test/code-layout details.

## README rules

- Lead with the project and this repo's role in it.
- Include a **Relationship to other repos** section.
- **No developer onboarding**: no build commands, no setup steps, no repo layout, no test instructions, no internal architecture. At most, link to a doc (`PLAN.md`, `docs/`, the project site) or the sibling test repo.
- Keep it short and durable; avoid details that go stale.

## Shared README skeleton (used across all openp41ge repos)

1. **Project intro** — what openp41ge is (one or two paragraphs).
2. **This repo** — what it is and does, in project terms.
3. **Relationship to other repos** — the project map and how siblings interact.
4. **Repo-specific notes** — still project-level, not onboarding.
5. **Developing / docs** — a single line pointing to the doc(s) with build/setup/test details.

## Relationship to other repos (shared content)

- `openp41ge/code` — the openp41ge **code editor** desktop app (Electron). The browser and the app are
  **separate programs** that talk over a defined, versioned link; the app can pin webpage
  elements into its panes. (Do **not** refer to it as `openp41ge/app`.)
- `openp41ge/browser-tests` — **private** tests repo for this browser. CI here dispatches to
  browser-tests, which posts a `browser-tests` commit status back to this repo.
- `openp41ge/web` — the openp41ge backend services (authentication, portal/relay, content, mongo).

## Naming corrections

- **Standardise** on `openp41ge/code` for the Electron app; remove any `openp41ge/app` references.
- The Electron app is a **code editor**; if any text calls it a "desktop pane manager", correct it.

## This repo's specific plan (browser)

**State as of 2026-10-16 pull:** the README has already been slimmed upstream — the
Building / Releases / Tests onboarding sections are gone, and it now reads as a consumer
"Download / License" page. So the remaining work here is **project framing**, not de-onboarding.

- Keep the "what it is" framing: **openp41ge explorer**, a free, open-source web browser for the
  Mac, built on Chromium/CEF, with the **element pop-out** headline capability.
- Add a **project intro** line (what openp41ge is) and the **Relationship to other repos** section —
  the current README says nothing about the sibling repos or the openp41ge project.
- Mention the companion **`openp41ge/code`** code editor and the **`openp41ge/web`** backend briefly.
- `PLAN.md` holds the design/roadmap — point to it rather than summarising the whole design in the README.
- Do **not** re-introduce build/setup/test details; keep it as a project+download overview.

## Steps / checklist

- [ ] Rewrite `README.md` to the shared skeleton.
- [ ] (Already done upstream) build/setup/layout/test details removed — do **not** re-add.
- [ ] Add the project intro and **Relationship to other repos** section using shared content above.
- [ ] Correct naming to `openp41ge/code`; drop `openp41ge/app`.
- [ ] Keep it a project+download overview; link to `PLAN.md` for design.

## What NOT to do

- Do not embed build commands, CMake/Ninja steps, test setup, or repo layout in the README.
- Do not inline the design road-map; link to `PLAN.md`.
- Do not rename repos or change paths — only the README content and references.
