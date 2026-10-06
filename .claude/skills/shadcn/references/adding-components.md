# Adding a component

Only eight components are installed (see `components-installed.md`). Anything else — checkbox,
switch, tabs, tooltip, popover, badge, avatar, separator, skeleton, textarea, radio-group,
calendar, sidebar, form, sheet, accordion, alert, command, pagination — **is not here**, and you
do not know its API in this style. Install it, read the generated file, then write code.

## Install

```bash
npx shadcn@latest add <name>
```

The `shadcn` CLI (v4.16.1) is already a devDependency. Several at once:

```bash
npx shadcn@latest add checkbox switch tabs
```

The command writes files and may add packages. **Do not run it speculatively** — install only
what the current task needs, and tell the user when a dependency was added.

## Where files land

From `components.json`:

| Setting                 | Value             | Effect                                             |
| ----------------------- | ----------------- | -------------------------------------------------- |
| `style`                 | `base-nova`       | generates **Base UI** components, not Radix        |
| `rsc`                   | `true`            | omits `"use client"` unless the component needs it |
| `tsx`                   | `true`            | `.tsx` output                                      |
| `iconLibrary`           | `lucide`          | icons come from `lucide-react`                     |
| `tailwind.baseColor`    | `neutral`         | matches the greyscale palette in `globals.css`     |
| `tailwind.cssVariables` | `true`            | token classes, not hardcoded colors                |
| `tailwind.config`       | `""`              | no config file — Tailwind v4                       |
| `aliases.ui`            | `@/components/ui` | where components are written                       |
| `aliases.utils`         | `@/lib/utils`     | where `cn()` is imported from                      |

So `add checkbox` writes `components/ui/checkbox.tsx`. Some components also add a hook under
`hooks/` or a helper under `lib/`.

Never hand-write a file into `components/ui/` to fake a component that the CLI should generate.

## After installing — check these

1. **Read the generated file before using it.** Note its exported parts, its cva `variants` and
   `size` keys, its `data-slot` values, and whether it has `"use client"`. The Base UI part
   names will not match Radix: expect `Popup`, `Backdrop`, `Positioner`, `Portal`, and a
   `render` prop for composition.
2. **Check `package.json`** for anything new the CLI installed, and mention it.
3. **Check `app/globals.css`** — a component may append tokens. If so, confirm the new
   variables exist in **both** `:root` and `.dark`.
4. **Formatting.** Generated files come out **without semicolons** and in the CLI's own style,
   which conflicts with this repo's `.prettierrc` (`"semi": true`). Lefthook runs Prettier on
   staged files at pre-commit, so the file will be reformatted then; `npm run format:check` may
   report it before that happens. This is expected for CLI output — do not treat it as your bug,
   and do not "fix" it by rewriting the component by hand.
5. **`npm run typecheck`** after wiring it up.

## Updating an existing component

Re-running `add` for an installed component **overwrites** it. Any local edit is lost — which is
why per-instance changes belong in a `className` at the call site, never in the file itself.
If a genuine shared change is needed, edit `components/ui/*` deliberately and note that a future
`add` will revert it.
