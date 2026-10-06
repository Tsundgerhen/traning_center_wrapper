# Theming

Everything here is transcribed from `app/globals.css` — the single source of theme truth.
There is **no `tailwind.config.js` and never should be** (Tailwind v4).

## File shape

```css
@import "tailwindcss";
@import "tw-animate-css";
@import "shadcn/tailwind.css";

@custom-variant dark (&:is(.dark *));

@theme inline {
  /* maps CSS variables to Tailwind utilities */
}

:root {
  /* light palette */
}
.dark {
  /* dark palette */
}

@layer base {
  /* global element defaults */
}
```

## Dark mode is a class, not a media query

```css
@custom-variant dark (&:is(.dark *));
```

Dark styles apply to descendants of an element carrying `.dark`. Nothing in the repo currently
toggles that class — a theme switcher must add or remove `dark` on `<html>`.
`prefers-color-scheme` is not consulted, so respecting the OS setting requires explicit code.

Use the `dark:` variant only for genuine per-element corrections. Normal color work needs no
`dark:` at all, because the tokens already swap.

## `@theme inline`

Maps each raw variable to a Tailwind utility namespace: `--color-primary: var(--primary)`
gives you `bg-primary`, `text-primary`, `border-primary`, `ring-primary`. Because the mapping
is `inline`, utilities resolve `var(--primary)` at use site, so `.dark` overrides apply
without regenerating utilities.

`--font-sans` and `--font-mono` map to the Geist variables set in `app/[lang]/layout.tsx`;
`--font-heading` aliases `--font-sans` and is what `CardTitle` and `DialogTitle` use.

## Color tokens

Every token is `oklch()`. The palette is **neutral/greyscale** — `--primary` is near-black in
light and near-white in dark, not a brand hue.

| Token                    | `:root` (light)             | `.dark`                     |
| ------------------------ | --------------------------- | --------------------------- |
| `--background`           | `oklch(1 0 0)`              | `oklch(0.145 0 0)`          |
| `--foreground`           | `oklch(0.145 0 0)`          | `oklch(0.985 0 0)`          |
| `--card`                 | `oklch(1 0 0)`              | `oklch(0.205 0 0)`          |
| `--card-foreground`      | `oklch(0.145 0 0)`          | `oklch(0.985 0 0)`          |
| `--popover`              | `oklch(1 0 0)`              | `oklch(0.205 0 0)`          |
| `--popover-foreground`   | `oklch(0.145 0 0)`          | `oklch(0.985 0 0)`          |
| `--primary`              | `oklch(0.205 0 0)`          | `oklch(0.922 0 0)`          |
| `--primary-foreground`   | `oklch(0.985 0 0)`          | `oklch(0.205 0 0)`          |
| `--secondary`            | `oklch(0.97 0 0)`           | `oklch(0.269 0 0)`          |
| `--secondary-foreground` | `oklch(0.205 0 0)`          | `oklch(0.985 0 0)`          |
| `--muted`                | `oklch(0.97 0 0)`           | `oklch(0.269 0 0)`          |
| `--muted-foreground`     | `oklch(0.556 0 0)`          | `oklch(0.708 0 0)`          |
| `--accent`               | `oklch(0.97 0 0)`           | `oklch(0.269 0 0)`          |
| `--accent-foreground`    | `oklch(0.205 0 0)`          | `oklch(0.985 0 0)`          |
| `--destructive`          | `oklch(0.577 0.245 27.325)` | `oklch(0.704 0.191 22.216)` |
| `--border`               | `oklch(0.922 0 0)`          | `oklch(1 0 0 / 10%)`        |
| `--input`                | `oklch(0.922 0 0)`          | `oklch(1 0 0 / 15%)`        |
| `--ring`                 | `oklch(0.708 0 0)`          | `oklch(0.556 0 0)`          |

`--destructive` has **no** `--destructive-foreground`. Components pair it with opacity instead:
`bg-destructive/10 text-destructive`, `border-destructive/30`.

`--border` and `--input` are **translucent white** in dark mode, so they blend with whatever is
behind them. Do not replace them with solid greys.

### Charts

`--chart-1` … `--chart-5`: `oklch(0.87 0 0)`, `oklch(0.556 0 0)`, `oklch(0.439 0 0)`,
`oklch(0.371 0 0)`, `oklch(0.269 0 0)` — identical in light and dark, and all greyscale.
They read as a single-hue ramp, not five distinct categories; a categorical chart needs real
hues added to both palettes first.

### Sidebar

`--sidebar`, `--sidebar-foreground`, `--sidebar-primary`, `--sidebar-primary-foreground`,
`--sidebar-accent`, `--sidebar-accent-foreground`, `--sidebar-border`, `--sidebar-ring`.

`--sidebar-primary` is the one non-grey token in the file: `oklch(0.488 0.243 264.376)` (blue)
in `.dark` only; in light it is `oklch(0.205 0 0)`.

## Radius

One input, `--radius: 0.625rem` (10px), and a derived scale in `@theme inline`:

| Utility       | Formula                     | Value |
| ------------- | --------------------------- | ----- |
| `rounded-sm`  | `calc(var(--radius) * 0.6)` | 6px   |
| `rounded-md`  | `calc(var(--radius) * 0.8)` | 8px   |
| `rounded-lg`  | `var(--radius)`             | 10px  |
| `rounded-xl`  | `calc(var(--radius) * 1.4)` | 14px  |
| `rounded-2xl` | `calc(var(--radius) * 1.8)` | 18px  |
| `rounded-3xl` | `calc(var(--radius) * 2.2)` | 22px  |
| `rounded-4xl` | `calc(var(--radius) * 2.6)` | 26px  |

Change `--radius` once to rescale the whole UI. Controls use `rounded-lg`; cards, dialogs and
popups use `rounded-xl`.

## Base layer

```css
@layer base {
  * {
    @apply border-border outline-ring/50;
  }
  body {
    @apply bg-background text-foreground;
  }
  html {
    @apply font-sans;
  }
}
```

Default border color is already `border-border` — `<div className="border">` is correctly
themed with no color class. Body background and text are set globally; do not repeat them.

## Changing the theme

1. Edit `:root` **and** `.dark` in `app/globals.css`. Every token needs both.
2. Add a new token by defining it in both blocks and mapping it in `@theme inline`
   (`--color-x: var(--x)`), which is what creates `bg-x` / `text-x`.
3. Do not create a config file, and do not hardcode a hex or a palette color in a component.
