# ElderGuard AI – Project Rules

## Project
Web-based smartwatch simulator for elderly safety: fall detection, abnormal heart rate detection, SOS alerts with mock GPS. University project; it must be fully demoable in a browser without a physical smartwatch.

## Environment
- Windows + VS Code + PowerShell. All commands and npm scripts must work on Windows (no bash-only syntax, no `rm -rf`, no `&&`-dependent scripts that fail in PowerShell; use cross-platform tools if needed).

## Fixed Stack (do not change without asking)
- Vite + vanilla JavaScript (ES modules). No backend, no frameworks, no external APIs.
- Plain CSS with custom properties (design tokens).
- Vitest for tests, ESLint (flat config) + Prettier for static checks.

## Folder Structure
- /src/core – telemetry store, detectors, alert logic (pure JS, testable)
- /src/ui – watch UI components
- /src/simulator – external sensor simulator panel
- /src/styles – tokens and global styles
- /src/config – thresholds and app config
- /tests – unit tests
- /public – static assets

## Commit Rules
- Conventional Commits with scope: feat, fix, style, refactor, test, docs, chore. Example: `feat(telemetry): add heart rate generator`.
- One commit per meaningful subtask. Each commit must leave the project working.
- Before every commit run: `npm run lint`, `npm test`, `npm run build`. Do not commit if any fails; fix first.
- Never create empty or cosmetic-only commits to inflate the count.
- Commit locally only. NEVER push unless explicitly asked.
- Follow the commit list given in each phase prompt. If a listed commit doesn't make sense, explain why and propose an alternative before doing it.

## Working Style
- Execute only the phase requested in the current prompt. Do not start the next phase.
- At the end of each phase: stop, list the commits created (`git log --oneline` for that phase), summarize what was built, and report any problems.

## UI Principles
- Users are elderly people: high contrast (WCAG AAA, 7:1 text), very large touch targets, minimal text, readable at a glance.
- Watch UI lives inside a circular frame (390–454px). The simulator panel lives outside the frame.
- Light theme is the default. Dark theme is optional, chosen by the user, and saved across reloads. Do NOT follow the system preference.
- The UI is bilingual: Spanish (es) is the default, English (en) is optional, chosen by the user, and saved across reloads.
- Never hardcode user-facing text. All visible strings (including aria-labels, titles and alerts) must come from the i18n dictionaries, with both Spanish and English entries added in the same commit.
- Code, comments and commit messages stay in English.
