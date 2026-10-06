# Installed components

The eight components that exist in `components/ui/`. Everything below is transcribed from
those files. **Anything not listed here is not installed** — see `adding-components.md`.

All import from `@/components/ui/<file>`. All merge `className` through `cn()`.

| File                | Wraps                   | `"use client"` |
| ------------------- | ----------------------- | -------------- |
| `button.tsx`        | `@base-ui/react/button` | no             |
| `card.tsx`          | plain `div` elements    | no             |
| `dialog.tsx`        | `@base-ui/react/dialog` | yes            |
| `dropdown-menu.tsx` | `@base-ui/react/menu`   | yes            |
| `input.tsx`         | `@base-ui/react/input`  | no             |
| `label.tsx`         | native `<label>`        | yes            |
| `select.tsx`        | `@base-ui/react/select` | yes            |
| `table.tsx`         | native table elements   | yes            |

---

## Button

`import { Button, buttonVariants } from "@/components/ui/button"`

Wraps `Button as ButtonPrimitive` from `@base-ui/react/button`. Props are
`ButtonPrimitive.Props & VariantProps<typeof buttonVariants>`. `data-slot="button"`.

**Variants** (`variant`, default `"default"`): `default`, `outline`, `secondary`, `ghost`,
`destructive`, `link`.

Note `destructive` is a **tinted** style here, not solid: `bg-destructive/10 text-destructive`.

**Sizes** (`size`, default `"default"`) — this scale is dense:

| Size      | Geometry                                           |
| --------- | -------------------------------------------------- |
| `default` | `h-8 gap-1.5 px-2.5`                               |
| `xs`      | `h-6 gap-1 px-2 text-xs`, icons `size-3`           |
| `sm`      | `h-7 gap-1 px-2.5 text-[0.8rem]`, icons `size-3.5` |
| `lg`      | `h-9 gap-1.5 px-2.5`                               |
| `icon`    | `size-8`                                           |
| `icon-xs` | `size-6`                                           |
| `icon-sm` | `size-7`                                           |
| `icon-lg` | `size-9`                                           |

A bare `<Button>` is `h-8`. Existing forms opt into `size="lg"` for primary submits, and pass
`className="h-10"` on `Input` to match a taller field. Child `<svg>` defaults to `size-4`.

```tsx
import { LoaderCircle } from "lucide-react";
import { Button } from "@/components/ui/button";

<Button type="submit" size="lg" disabled={isPending} className="w-full">
  {isPending ? (
    <LoaderCircle aria-hidden="true" className="size-4 animate-spin" />
  ) : null}
  {isPending ? t("submitting") : t("submit")}
</Button>;
```

---

## Card

`import { Card, CardHeader, CardTitle, CardDescription, CardAction, CardContent, CardFooter } from "@/components/ui/card"`

Plain `div`s — no primitive, no `"use client"`. All accept `React.ComponentProps<"div">`.

- `Card` takes `size?: "default" | "sm"`, which sets the `--card-spacing` variable
  (`--spacing(4)` / `--spacing(3)`) that every part pads from.
- `CardHeader` switches to a two-column grid when a `CardAction` is present.
- `CardAction` places itself top-right of the header.
- `CardFooter` renders a top border on `bg-muted/50`; `Card` drops its own bottom padding
  when a footer exists.

`data-slot`: `card`, `card-header`, `card-title`, `card-description`, `card-action`,
`card-content`, `card-footer`.

```tsx
<Card>
  <form onSubmit={handleSubmit}>
    <CardHeader className="border-b">
      <CardTitle>{t("cardTitle")}</CardTitle>
      <CardDescription>{t("cardDescription")}</CardDescription>
    </CardHeader>
    <CardContent className="space-y-5 py-6">{/* fields */}</CardContent>
    <CardFooter className="justify-center">{/* actions */}</CardFooter>
  </form>
</Card>
```

---

## Dialog

`import { Dialog, DialogTrigger, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter, DialogClose, DialogOverlay, DialogPortal } from "@/components/ui/dialog"`

File is `"use client"`. Mapping to Base UI parts — **this is where Radix habits break**:

| Export                          | Base UI part                  |
| ------------------------------- | ----------------------------- |
| `Dialog`                        | `DialogPrimitive.Root`        |
| `DialogTrigger`                 | `DialogPrimitive.Trigger`     |
| `DialogPortal`                  | `DialogPrimitive.Portal`      |
| `DialogClose`                   | `DialogPrimitive.Close`       |
| `DialogOverlay`                 | `DialogPrimitive.Backdrop`    |
| `DialogContent`                 | `DialogPrimitive.Popup`       |
| `DialogTitle`                   | `DialogPrimitive.Title`       |
| `DialogDescription`             | `DialogPrimitive.Description` |
| `DialogHeader` / `DialogFooter` | plain `div`                   |

`DialogContent` already renders its own `DialogPortal` and `DialogOverlay` — do not add them.

Both `DialogContent` and `DialogFooter` accept `showCloseButton?: boolean`:
`DialogContent` defaults to `true` (an `icon-sm` ghost button, top-right);
`DialogFooter` defaults to `false` (an `outline` "Close" button in the footer row).

Animation uses `data-open:` / `data-closed:` variants. Composition uses Base UI's `render`
prop, which takes an **element**:

```tsx
<DialogPrimitive.Close render={<Button variant="outline" />}>
  Close
</DialogPrimitive.Close>
```

```tsx
<Dialog>
  <DialogTrigger render={<Button variant="outline" />}>
    {t("edit")}
  </DialogTrigger>
  <DialogContent>
    <DialogHeader>
      <DialogTitle>{t("dialog.title")}</DialogTitle>
      <DialogDescription>{t("dialog.description")}</DialogDescription>
    </DialogHeader>
    {/* body */}
    <DialogFooter showCloseButton>
      <Button type="submit">{t("save")}</Button>
    </DialogFooter>
  </DialogContent>
</Dialog>
```

`DialogFooter` is styled to sit flush at the bottom of the popup (`-mx-4 -mb-4`, top border,
`bg-muted/50`), so keep it as the last child of `DialogContent`.

---

## DropdownMenu

`import { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuGroup, DropdownMenuLabel, DropdownMenuItem, DropdownMenuCheckboxItem, DropdownMenuRadioGroup, DropdownMenuRadioItem, DropdownMenuSeparator, DropdownMenuShortcut, DropdownMenuSub, DropdownMenuSubTrigger, DropdownMenuSubContent, DropdownMenuPortal } from "@/components/ui/dropdown-menu"`

File is `"use client"`. Wraps `Menu as MenuPrimitive` from `@base-ui/react/menu`.

`DropdownMenuContent` renders `Portal → Positioner → Popup` internally and accepts the
positioning props directly: `align` (default `"start"`), `alignOffset` (`0`),
`side` (`"bottom"`), `sideOffset` (`4`).

- `DropdownMenuItem` takes `inset?: boolean` and `variant?: "default" | "destructive"`.
- Submenus are `DropdownMenuSub` (`MenuPrimitive.SubmenuRoot`) + `DropdownMenuSubTrigger`
  (`MenuPrimitive.SubmenuTrigger`) + `DropdownMenuSubContent`.
- `DropdownMenuLabel` maps to `MenuPrimitive.GroupLabel` and also takes `inset`.
- `DropdownMenuShortcut` is a plain `<span>` for key hints.

```tsx
<DropdownMenu>
  <DropdownMenuTrigger render={<Button variant="ghost" size="icon-sm" />}>
    <MoreHorizontal aria-hidden="true" />
  </DropdownMenuTrigger>
  <DropdownMenuContent align="end">
    <DropdownMenuLabel>{t("actions")}</DropdownMenuLabel>
    <DropdownMenuItem>{t("edit")}</DropdownMenuItem>
    <DropdownMenuSeparator />
    <DropdownMenuItem variant="destructive">{t("delete")}</DropdownMenuItem>
  </DropdownMenuContent>
</DropdownMenu>
```

---

## Input

`import { Input } from "@/components/ui/input"`

Wraps `Input as InputPrimitive` from `@base-ui/react/input`, but typed as
`React.ComponentProps<"input">` — treat it as a normal input. No `"use client"`, so it works
inside a Server Component as long as no handler is attached. `data-slot="input"`.

Base height is `h-8`. Existing forms pass `className="h-10"`. Invalid state is driven by
`aria-invalid`, not a prop.

```tsx
<Input
  id="email"
  name="email"
  type="email"
  autoComplete="email"
  placeholder={t("emailPlaceholder")}
  required
  className="h-10"
/>
```

---

## Label

`import { Label } from "@/components/ui/label"`

A native `<label>` with styling — **no Base UI primitive**. File is `"use client"`.
`React.ComponentProps<"label">`, `data-slot="label"`. Link it with `htmlFor`; it is a flex row
with `gap-2`, so a required marker can be a direct child.

```tsx
<Label htmlFor="tenantName">
  {t("organization.name")}
  <span className="text-destructive" aria-hidden="true">
    *
  </span>
</Label>
```

---

## Select

`import { Select, SelectTrigger, SelectValue, SelectContent, SelectGroup, SelectLabel, SelectItem, SelectSeparator, SelectScrollUpButton, SelectScrollDownButton } from "@/components/ui/select"`

File is `"use client"`. Wraps `Select as SelectPrimitive` from `@base-ui/react/select`.
`Select` is `SelectPrimitive.Root` re-exported directly.

| Export                                            | Base UI part                                                |
| ------------------------------------------------- | ----------------------------------------------------------- |
| `SelectTrigger`                                   | `Trigger` (renders its own chevron `Icon`)                  |
| `SelectValue`                                     | `Value`                                                     |
| `SelectContent`                                   | `Portal` → `Positioner` → `Popup` → `List`                  |
| `SelectGroup`                                     | `Group`                                                     |
| `SelectLabel`                                     | `GroupLabel`                                                |
| `SelectItem`                                      | `Item` (wraps children in `ItemText`, adds `ItemIndicator`) |
| `SelectSeparator`                                 | `Separator`                                                 |
| `SelectScrollUpButton` / `SelectScrollDownButton` | `ScrollUpArrow` / `ScrollDownArrow`                         |

- `SelectTrigger` takes `size?: "sm" | "default"` → `h-7` / `h-8`, exposed as `data-size`.
- `SelectContent` accepts `side` (`"bottom"`), `sideOffset` (`4`), `align` (`"center"`),
  `alignOffset` (`0`), `alignItemWithTrigger` (`true`) and forwards them to the `Positioner`.
- The scroll buttons are rendered by `SelectContent` automatically.

Put the placeholder on `SelectValue`, not on a disabled item.

> ⚠️ **Verify the Root props before using.** `Select` is `SelectPrimitive.Root` re-exported
> unchanged (`select.tsx:9`), and **no file in this repo uses `Select` yet** — so its
> value/change props are not evidenced anywhere in this codebase. The example below shows
> `value` / `onValueChange`; confirm against
> `node_modules/@base-ui/react/select` (or the Base UI docs) before relying on it, and update
> this file once the first real usage lands. The same caution applies to the accepted values of
> `side` / `align` on `SelectContent` and `DropdownMenuContent`: the props exist and are
> forwarded to the `Positioner`, but only the defaults (`side="bottom"`, `align="center"` for
> Select, `align="start"` for the menu) are proven by the wrapper source.

```tsx
<Select value={branchId} onValueChange={setBranchId}>
  <SelectTrigger className="w-56">
    <SelectValue placeholder={t("branch.placeholder")} />
  </SelectTrigger>
  <SelectContent>
    <SelectGroup>
      <SelectLabel>{t("branch.label")}</SelectLabel>
      {branches.map((branch) => (
        <SelectItem key={branch.id} value={branch.id}>
          {branch.name}
        </SelectItem>
      ))}
    </SelectGroup>
  </SelectContent>
</Select>
```

---

## Table

`import { Table, TableHeader, TableBody, TableFooter, TableRow, TableHead, TableCell, TableCaption } from "@/components/ui/table"`

File is `"use client"`. Native elements only — no primitive, no sorting, no pagination.

**`Table` wraps itself in a `<div data-slot="table-container">` with `overflow-x-auto`.**
Do not add your own scroll wrapper.

`TableRow` styles a selected row from `data-[state=selected]` — set that attribute yourself if
you implement selection. Cells use `whitespace-nowrap`, so wrap long text explicitly.

```tsx
<Table>
  <TableHeader>
    <TableRow>
      <TableHead>{t("columns.name")}</TableHead>
      <TableHead>{t("columns.branch")}</TableHead>
    </TableRow>
  </TableHeader>
  <TableBody>
    {students.map((student) => (
      <TableRow key={student.id}>
        <TableCell>{student.name}</TableCell>
        <TableCell>{student.branchName}</TableCell>
      </TableRow>
    ))}
  </TableBody>
</Table>
```
