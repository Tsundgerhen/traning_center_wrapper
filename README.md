# training_center — Bilig LMS ERP workspace

One folder, four apps, each in **its own git repo**. This root folder is a small
wrapper repo that only holds the shared setup — the `Makefile` that runs
everything, the agent docs (`AGENTS.md`, `CLAUDE.md`) and `.claude/`.

| Folder            | App                                   | Dev URL                   |
| ----------------- | ------------------------------------- | ------------------------- |
| `lms-erp/`        | Backend API (NestJS + Prisma)         | http://localhost:3003     |
| `lms-erp-tenant/` | Tenant web — training-center staff    | http://localhost:3000     |
| `bilig_user_web/` | User web — students & parents         | http://localhost:3001     |
| `lms-erp-admin/`  | Admin web — Bilig platform staff      | http://localhost:3002     |

Also running in dev: PostgreSQL on **5433** (embedded, no install needed) and
Prisma Studio on http://localhost:5555.

---

## Quick start

Already set up? This is all you need:

```bash
make dev        # backend + tenant web  →  open http://localhost:3000
```

`Ctrl+C` stops everything. `make help` lists every command.

---

## First-time setup

### 1. Install the tools

| Tool      | Why                                   | Check            |
| --------- | ------------------------------------- | ---------------- |
| Node 24   | all four apps                         | `node -v`        |
| Corepack  | gives the backend its yarn 4          | `corepack enable` (once) |
| Git Bash  | the Makefile runs in bash             | comes with Git for Windows |
| GNU make  | runs the `make …` commands            | `make -v`        |

On Windows, install make with `winget install ezwinports.make`, then open a new
terminal. You do **not** need to install PostgreSQL.

### 2. Get the code

Clone this wrapper, then the four apps **inside** it, with exactly these folder
names (you need SSH access to each GitHub repo):

```bash
git clone git@github.com:Tsundgerhen/traning_center_wrapper.git training_center
cd training_center
git clone git@github.com:Erdene-Vvl/lms-erp.git
git clone git@github.com:Artistry449/lms-erp-tenant.git
git clone git@github.com:Erdene-Vvl/lms-erp-admin.git
git clone git@github.com:Erdene-Vvl/bilig_user_web.git
```

### 3. Install dependencies

```bash
make install    # yarn for the backend, npm for the three webs
```

### 4. Create the env files

Every app has an `.env.example`. Copy it and fill in **every** value — each app
checks its env at startup and refuses to boot if something is missing.

```bash
cp lms-erp/.env.example         lms-erp/.env
cp lms-erp-tenant/.env.example  lms-erp-tenant/.env.local   # note: .env.local
cp lms-erp-admin/.env.example   lms-erp-admin/.env
cp bilig_user_web/.env.example  bilig_user_web/.env
```

Ask a teammate for secrets (JWT secrets, QPay, eBarimt, storage keys). These
values must line up between the apps for local dev:

| File                     | Variable              | Local value                                                 |
| ------------------------ | --------------------- | ----------------------------------------------------------- |
| `lms-erp/.env`           | `PORT`                | `3003`                                                      |
| `lms-erp/.env`           | `DATABASE_URL`        | `postgresql://postgres:postgres@127.0.0.1:5433/school_mgmt` |
| `lms-erp/.env`           | `CORS_ORIGINS`        | must include `http://localhost:3000` and `http://localhost:3001` (chat) |
| `lms-erp/.env`           | `SEED_ADMIN_USERNAME` / `SEED_ADMIN_PASSWORD` | your admin-web login, created by the seed |
| `lms-erp-tenant/.env.local` | `BACKEND_API_URL`  | `http://localhost:3003` (no `/v1`)                          |
| `lms-erp-admin/.env`     | `BACKEND_API_URL`     | `http://localhost:3003` (no `/v1`)                          |
| `bilig_user_web/.env`    | `API_BASE_URL`        | `http://localhost:3003/v1` (**with** `/v1`, no trailing `/`) |

Never commit an `.env` file.

### 5. Create the database

```bash
make db-reset   # starts postgres, applies migrations, generates the client, seeds
```

The seed creates the module catalog, the platform super admin and a demo
training center. **At the end it prints the accounts and their password** —
keep that output.

Optional — the public read-only demo tenant (`director@demo.mn` / `DemoPass!2026`):

```bash
cd lms-erp && yarn db:seed-demo
```

### 6. Run it

```bash
make dev        # backend + tenant web
make dev-all    # backend + all three webs
```

| Open                          | Log in with                                   |
| ----------------------------- | --------------------------------------------- |
| http://localhost:3000 tenant  | a staff account printed by the seed            |
| http://localhost:3002 admin   | `SEED_ADMIN_USERNAME` / `SEED_ADMIN_PASSWORD` |
| http://localhost:3001 user    | a student or parent account printed by the seed |
| http://localhost:3003/docs/company · `/docs/admin` · `/docs/user` | Swagger, per surface |

---

## Everyday commands

| Command                       | What it does                                             |
| ----------------------------- | -------------------------------------------------------- |
| `make dev`                    | backend + tenant web (the usual day)                     |
| `make dev-all`                | backend + tenant + admin + user webs                     |
| `make backend`                | db + Prisma Studio + API only                            |
| `make tenant` / `admin` / `user` | one web app on its own (needs the backend running)    |
| `make stop`                   | free every dev port (postgres keeps running)             |
| `make db-stop`                | stop postgres                                            |
| `make db-deploy`              | apply new migrations after a `git pull` + regenerate     |
| `make db-migrate NAME=add_x`  | create a migration after editing the schema              |
| `make db-reset`               | wipe the database and re-seed                            |
| `make install` / `lint` / `build` | across all four apps                                 |

`make dev API_START=start:dev` runs the API in watch mode (restarts on save).

---

## When something goes wrong

| Symptom                                           | Fix                                                        |
| ------------------------------------------------- | ---------------------------------------------------------- |
| `port 3000 is already in use` (or 3001–3003, 5555)| `make stop`, then start again                              |
| postgres hangs or won't start                     | `make db-stop`, then retry; last resort `make db-nuke`     |
| API won't boot, complains about an env variable   | a value is missing in `lms-erp/.env` — compare with `.env.example` |
| errors about missing tables/columns after a pull  | `make db-deploy`                                           |
| seed fails with `Cannot read properties of undefined` | `make db-generate`, then `make db-seed`                |
| web shows "fetch failed" / 502                    | the API isn't running, or `BACKEND_API_URL` / `API_BASE_URL` is wrong |
| `yarn` says it is version 1.x in `lms-erp/`       | run `corepack enable` and open a new terminal              |

`make db-nuke` deletes the local database files entirely — only use it when
`db-reset` itself can't get postgres up.

---

## Working with git here

- **Each app commits to its own repo.** `cd lms-erp` (or the web you changed)
  before `git add` / `git commit`.
- **This root repo** tracks only the workspace setup: `Makefile`, `AGENTS.md`,
  `CLAUDE.md`, `README.md`, `.claude/`. Its `.gitignore` ignores every app folder,
  so committing here can never pick up app code. A new root-level setup file has
  to be added to `.gitignore` with a `!/name` line.

## More docs

- `AGENTS.md` — architecture and rules for all four apps (start here before coding).
- `lms-erp/README.md` — backend: surfaces, auth, billing, chat, storage.
- `lms-erp-tenant/AGENTS.md`, `lms-erp-admin/AGENTS.md`, `bilig_user_web/README.md` — per-app rules.
- Email templates: `lms-erp/src/core/notifications/templates/README.md`.
