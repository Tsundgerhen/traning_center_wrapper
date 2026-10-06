# Patterns

Cross-cutting conventions, taken from working code in this repo:
`components/auth/employee-login-form.tsx`, `components/onboarding/tenant-registration-form.tsx`,
`components/language-switcher.tsx`, `app/[lang]/layout.tsx`, `app/[lang]/(tenant)/layout.tsx`.

## Server vs. Client Components

Pages and layouts are Server Components by default. Add `"use client"` only for state, effects,
or event handlers — and push it to the **leaf**: keep the page a Server Component and import a
small client component for the interactive part. `app/[lang]/(auth)/login/page.tsx` stays on the
server and renders `<EmployeeLoginForm />`, which carries the directive.

Four `components/ui/*` files already declare `"use client"`: `dialog.tsx`, `dropdown-menu.tsx`,
`select.tsx`, `label.tsx`, plus `table.tsx`. Importing one does **not** make your file a Client
Component — the boundary is per-module. But anything you pass them that is a function (an
`onValueChange`, an `onClick`) must come from a file that is itself `"use client"`.

`button.tsx`, `card.tsx` and `input.tsx` have no directive, so they render on the server as long
as you attach no handler.

In Next 16, `params` is a **Promise**:

```tsx
type PageProps = { params: Promise<{ lang: string }> };

export default async function Page({ params }: PageProps) {
  const { lang } = await params;
  // ...
}
```

## Internationalization

**No user-facing string is ever hardcoded.** Text lives in `i18n/dictionary/en/*.json` and
`i18n/dictionary/mn/*.json`. Locales are `["mn", "en"]`; the default is **`mn`**.

Client components:

```tsx
"use client";
import { useTranslations } from "next-intl";

export function StudentTable() {
  const t = useTranslations("students");
  return <TableHead>{t("columns.name")}</TableHead>;
}
```

Server components use `getTranslations` from `next-intl/server`.

Two gotchas:

1. **A new dictionary file must be registered by hand** in `i18n/request.ts`. Namespaces are
   imported one at a time and assembled into `messages` — adding
   `i18n/dictionary/{en,mn}/students.json` does nothing until you add the matching `import` and
   `messages` key there. Always add the file to **both** `en/` and `mn/`.
2. **Navigate with the locale-aware helpers.** `Link`, `useRouter`, `redirect`, `usePathname`
   and `getPathname` come from `@/i18n/navigation` — never from `next/link` or
   `next/navigation`. They keep the `[lang]` segment. `href` is written without the locale:
   `<Link href="/login">`, `router.replace("/dashboard")`.

Placeholders and `aria-label`s are user-facing too — translate them. Only `next/navigation`'s
`redirect` in a server layout that already builds the path itself (`redirect(`/${lang}/login`)`)
is exempt.

## Forms

Two patterns coexist.

**The branches/subjects dialogs use react-hook-form + zod** (`@hookform/resolvers/zod`).
`FormDialog` in `components/shared/dialogs.tsx` owns the `useForm` instance; the RHF-bound
`TextField` / `SelectField` in `components/shared/form-fields.tsx` each own their `<Label>`,
control and error line, reading the form through `useFormContext`. Note there is **no
`components/ui/form.tsx`** — the `base-nova` registry has no `form` component.

Validation messages come from the `errors.validation` dictionary, never a literal: schemas
are factories over the translator, built with `lib/forms.ts`. NestJS stays the validator of
record; its messages arrive on `ApiError.messages`.

**The two auth forms** (`components/auth/employee-login-form.tsx`,
`components/onboarding/tenant-registration-form.tsx`) are still uncontrolled `<form>`s read
through `FormData`:

```tsx
const formData = new FormData(event.currentTarget);
const email = String(formData.get("email") ?? "").trim();
```

Conventions shared by both:

- Wrap fields in `<fieldset disabled={isPending}>` so the whole group disables at once.
- Helper text: `<p className="text-muted-foreground text-xs">`.
- Errors render in one block with `role="alert"`.
- The form lives inside `<Card>`, with `CardContent` holding fields and `CardFooter` the actions.

The two pre-existing auth forms (`components/auth/employee-login-form.tsx`,
`components/onboarding/tenant-registration-form.tsx`) are still uncontrolled `FormData`
holdouts. They are not the pattern to copy.

## Calling the backend

This is a **frontend-only** repo. `lib/api/backend.ts` is `import "server-only"` and reads
`process.env.BACKEND_API_URL` — it can only be called from Server Components and from the
`app/api/auth/*` route handlers. Client components `fetch` a **same-origin relative path**
(`/api/auth/login`); never call the external backend directly from the browser, and never import
`lib/api/backend.ts` into a `"use client"` file.

Auth uses httpOnly cookies set server-side (`lib/auth/cookies.ts`). There is no token in JS —
do not try to read one.

## Toasts

`app/[lang]/layout.tsx` already renders `<Toaster richColors position="bottom-right" />` inside
`NextIntlClientProvider`. Do not add a second one.

```tsx
import { toast } from "sonner";

toast.success(t("success"));
toast.error(t("errors.network"));
```

Use a toast for a transient outcome. Use the inline `role="alert"` block for validation errors
the user must act on.

## Icons

`lucide-react` only. Decorative icons get `aria-hidden="true"`; icons that are the sole content
of a control need an `aria-label` on the control (translated).

```tsx
import { AlertCircle } from "lucide-react";

<AlertCircle aria-hidden="true" className="mt-0.5 size-4 shrink-0" />;
```

Buttons size child `<svg>` to `size-4` automatically (`size-3` at `xs`, `size-3.5` at `sm`), so
the class is only needed outside a Button.

## Composing with `cn()`

`cn()` from `@/lib/utils` is `twMerge(clsx(...))` — later conflicting Tailwind classes win.
Every `components/ui/*` runs `className` through it, so overriding from the outside is safe and
is the **only** correct way to adjust one instance:

```tsx
<Input className="h-10 pr-10" />
<Button variant="ghost" size="icon-sm" className="absolute top-2 right-2" />
```

Use `cn()` yourself when building conditional classes. Never edit a file in `components/ui/` to
change one usage — `npx shadcn@latest add` will overwrite it.

## Layout

`app/[lang]/(tenant)/layout.tsx` guards the tenant area: it awaits `hasAuthSession()` and
redirects to `/${lang}/login` when there is no session, then renders a sidebar + header + main
shell. Route groups — `(auth)`, `(onboarding)`, `(tenant)`, and inside it `(organization)`,
`(operation)`, `(finance)`, `(general)` — organize files and add layouts, but **do not appear in
the URL**: `app/[lang]/(tenant)/(organization)/students/page.tsx` serves `/mn/students`.
