---
name: shadcn
description: Use this skill when building or changing any UI in the frontend app `lms-erp-tenant/` — pages, layouts, forms, dialogs, tables, buttons, cards, selects, dropdown menus, sidebars, dashboards — or when theming, picking colors, or styling with Tailwind here. Triggers: shadcn, Base UI, "add a component", building a form, modal, dialog, table, button, card, select, menu, layout, dark mode, theme tokens, CSS variables, styling a component. Also triggers when deciding between a Server and a Client Component, or when a component needs user-facing text.
---

# shadcn (Base UI) — Skill Index

UI layer for the **frontend app only**. Every path in this file and in its reference files
is relative to `lms-erp-tenant/` — prefix it when you are working from the workspace root
(`components/ui/button.tsx` → `lms-erp-tenant/components/ui/button.tsx`). The backend
(`lms-erp/`) has no UI; nothing here applies to it.

This file is an index: it holds the rules that apply everywhere, and points at reference
files. **Load reference files on demand — read only the one you need, never all at once.**

## ⚠️ This is not the shadcn/ui in your training data

`components.json` sets `"style": "base-nova"`. Every component in `components/ui/` wraps
**`@base-ui/react`** (v1.7.0), not Radix. Writing Radix APIs from memory produces code
that does not compile. Verified differences:

| Concern            | This repo (Base UI)                        | Do not write                       |
| ------------------ | ------------------------------------------ | ---------------------------------- |
| Dialog backdrop    | `DialogPrimitive.Backdrop`                 | Radix's `Overlay` part             |
| Dialog panel       | `DialogPrimitive.Popup`                    | Radix's `Content` part             |
| Open/close styling | `data-open:` / `data-closed:` variants     | Radix `state`-attribute variants   |
| Composition        | the `render` prop, given an element        | Radix's child-merging boolean prop |
| Popup placement    | explicit `Portal` → `Positioner` → `Popup` | a single content element           |

`DialogOverlay` and `DialogContent` **are** valid names here — they are this repo's
wrapper exports around `Backdrop` and `Popup`. The primitive parts are what differ.

**If a component is not in `components/ui/`, you do not know its API.** Run
`npx shadcn@latest add <name>`, read the generated file, then write code. Never
substitute a remembered Radix API.

## Non-negotiable rules

1. **Semantic tokens only.** `bg-primary`, `text-muted-foreground`, `border-border`,
   `bg-destructive/10`. Never raw palette colors (`bg-gray-800`, `text-slate-500`) — they
   ignore `.dark` and break dark mode.
2. **Tailwind v4. There is no `tailwind.config.js` — never create one.** Theme changes go
   in `app/globals.css`.
3. **Icons: `lucide-react` only.** Decorative icons get `aria-hidden="true"`.
4. **Toasts: `sonner`.** `import { toast } from "sonner"`. The single `<Toaster />` already
   lives in `app/[lang]/layout.tsx` — do not add another.
5. **Server Components by default.** Add `"use client"` only when the file needs state,
   effects, or event handlers.
6. **All user-facing text goes through `i18n/dictionary/{en,mn}/`** via `useTranslations`.
   Never hardcode a visible string. Code, comments, and identifiers stay English.
7. **Compose `components/ui/*`; don't write new primitives** when one already exists.
8. **Never edit `components/ui/*` for a one-off.** Pass `className` — every component merges
   it through `cn()`.

## Color tokens

Defined in `app/globals.css` for both `:root` and `.dark`. Each has a paired
`-foreground` unless noted.

| Token                                | Use for                                              |
| ------------------------------------ | ---------------------------------------------------- |
| `background` / `foreground`          | page surface and default text                        |
| `card` / `card-foreground`           | raised panels                                        |
| `popover` / `popover-foreground`     | dialogs, menus, select popups                        |
| `primary` / `primary-foreground`     | main action, emphasis                                |
| `secondary` / `secondary-foreground` | lower-emphasis action                                |
| `muted` / `muted-foreground`         | subdued surfaces, helper and caption text            |
| `accent` / `accent-foreground`       | hover and focus states in menus                      |
| `destructive`                        | errors, delete actions (no paired foreground token)  |
| `border`, `input`, `ring`            | borders, field borders, focus rings                  |
| `chart-1` … `chart-5`                | data series                                          |
| `sidebar`, `sidebar-*`               | sidebar surface, text, primary, accent, border, ring |

## Reference files — load only what you need

| Load this                            | When you need                                                                                                                                    |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `references/components-installed.md` | The exact API of an installed component: exports, variants, sizes, `data-slot`, a working example. Read this before using any `components/ui/*`. |
| `references/theming.md`              | Token values, light/dark palettes, the `--radius-*` scale, how `.dark` works, changing the theme.                                                |
| `references/patterns.md`             | Server vs. Client decisions, forms, dialogs, tables, toasts, icons, i18n wiring, `cn()`.                                                         |
| `references/adding-components.md`    | Installing a component that isn't here yet, and what to check afterward.                                                                         |

## How to use this skill

1. Identify which components the task needs.
2. If any is missing from `components/ui/`, follow `references/adding-components.md` first.
3. Read `references/components-installed.md` for the ones you will use — that file, not memory,
   is the source of truth for props and variants.
4. Add `references/theming.md` or `references/patterns.md` only if the task actually touches
   theming or a cross-cutting pattern.

Example: _"build a student list with a filter dropdown"_ → read `components-installed.md`
(Table, Select, Button, Input) and `patterns.md` (Server vs Client, i18n). Skip `theming.md`.
