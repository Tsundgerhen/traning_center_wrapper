# ==============================================================================
#  training_center - dev orchestration
#
#  Targets are named after the app they run:
#
#    make backend   lms-erp          API :3003 + db :5433 + studio :5555
#    make tenant    lms-erp-tenant   center staff web        :3000
#    make admin     lms-erp-admin    Bilig staff web         :3002
#    make user      bilig_user_web   student & parent web    :3001
#
#    make dev       backend + tenant          (the usual day)
#    make dev-all   backend + all three webs
#    make stop      free every dev port (postgres is left running)
#
#  Requires GNU make, Node, yarn, npm and Git Bash on PATH.
#  Run `make` or `make help` for the full list.
# ==============================================================================

SHELL         := bash
.SHELLFLAGS   := -eu -o pipefail -c
.DEFAULT_GOAL := help
MAKEFLAGS     += --no-print-directory

BACKEND_DIR := lms-erp
TENANT_DIR  := lms-erp-tenant
ADMIN_DIR   := lms-erp-admin
USER_DIR    := bilig_user_web

DEV_PG_PORT ?= 5433
DEV_PG_DB   ?= school_mgmt

# Ports the dev processes listen on -- what the `stop-*` targets clear before
# a restart. Sources of truth: $(BACKEND_DIR)/.env PORT,
# $(TENANT_DIR)/.env.local BACKEND_API_URL, and prisma studio's default.
# Postgres is deliberately not in this list: `db` reuses a live one on
# purpose, and `db-stop` is how you end that.
TENANT_PORT ?= 3000
USER_PORT   ?= 3001
ADMIN_PORT  ?= 3002
API_PORT    ?= 3003
STUDIO_PORT ?= 5555

# Script `make api` runs. `make dev API_START=start:dev` for nest watch mode.
API_START   ?= start

# `prisma migrate deploy` does NOT regenerate the client (only `migrate dev`
# does), so a schema edit since the last `yarn install` leaves the seed calling
# models the generated client has never heard of -- it fails with a bare
# "Cannot read properties of undefined". Generating between the two closes it.
MIGRATE_AND_SEED := yarn db:reset && yarn db:deploy && npx prisma generate && yarn db:seed

# runs several long-lived processes in one terminal, Ctrl+C kills them all
CONC := npx -y concurrently@9

# shipped with the embedded-postgres package; used for a clean shutdown
PG_CTL_BIN := $(firstword $(wildcard $(BACKEND_DIR)/node_modules/@embedded-postgres/*/native/bin/pg_ctl*))
PGDATA_DIR := $(CURDIR)/$(BACKEND_DIR)/.pgdata

# exit 0 when anything holds the postgres port. Distinguishes a free port
# from one still held by a postmaster that is shutting down and can no
# longer be talked to -- PG_PING alone reads those two as the same thing.
PORT_BUSY = netstat -ano | tr -d '\r' | awk '$$4=="LISTENING" && $$2 ~ /:$(DEV_PG_PORT)$$/ {found=1} END{exit !found}'

# exit 0 only when postgres actually accepts a connection (run from $(BACKEND_DIR))
PG_PING = node -e "const{Client}=require('pg');const c=new Client({host:'127.0.0.1',port:$(DEV_PG_PORT),user:'postgres',password:'postgres',database:'postgres'});c.connect().then(()=>c.end()).then(()=>process.exit(0)).catch(()=>process.exit(1))"

## start several apps - one terminal, Ctrl+C stops them all
dev: stop-tenant stop-api stop-studio ## backend + tenant web (the usual day)
	$(CONC) -n db,studio,api,tenant -c blue,magenta,green,cyan --kill-others \
	  "$(MAKE) db" \
	  "$(MAKE) wait-db && $(MAKE) studio" \
	  "$(MAKE) wait-db && $(MAKE) api" \
	  "$(MAKE) tenant"

dev-all: stop ## backend + tenant + admin + user webs
	$(CONC) -n db,studio,api,tenant,admin,user -c blue,magenta,green,cyan,yellow,red --kill-others \
	  "$(MAKE) db" \
	  "$(MAKE) wait-db && $(MAKE) studio" \
	  "$(MAKE) wait-db && $(MAKE) api" \
	  "$(MAKE) tenant" \
	  "$(MAKE) admin" \
	  "$(MAKE) user"

backend: stop-api stop-studio ## backend only: db + prisma studio + API
	$(CONC) -n db,studio,api -c blue,magenta,green --kill-others \
	  "$(MAKE) db" \
	  "$(MAKE) wait-db && $(MAKE) studio" \
	  "$(MAKE) wait-db && $(MAKE) api"

## start one app
tenant: stop-tenant ## tenant web, center staff       http://localhost:3000
	cd $(TENANT_DIR) && npm run dev

admin: stop-admin ## admin web, Bilig staff         http://localhost:3002
	cd $(ADMIN_DIR) && npm run dev -- -p $(ADMIN_PORT)

user: stop-user ## user web, students/parents     http://localhost:3001
	cd $(USER_DIR) && npm run dev -- -p $(USER_PORT)

api: stop-api ## backend API, db must be up     http://localhost:3003
	cd $(BACKEND_DIR) && yarn $(API_START)

db: ## embedded postgres (foreground) localhost:5433
	@cd $(BACKEND_DIR); \
	for i in $$(seq 1 20); do \
	  if $(PG_PING) >/dev/null 2>&1 || ! $(PORT_BUSY); then break; fi; \
	  if [ $$i -eq 1 ]; then \
	    echo "[db] :$(DEV_PG_PORT) is held but not answering - waiting for the previous postgres to exit"; \
	  fi; \
	  sleep 1; \
	done; \
	if $(PG_PING) >/dev/null 2>&1; then \
	  echo "[db] postgres already listening on :$(DEV_PG_PORT) - reusing it"; \
	  while $(PG_PING) >/dev/null 2>&1; do sleep 5; done; \
	  echo "[db] the postgres on :$(DEV_PG_PORT) went away"; \
	else \
	  yarn db:dev; \
	fi

studio: stop-studio ## prisma studio, db must be up   http://localhost:5555
	cd $(BACKEND_DIR) && yarn db:studio

# blocks until postgres accepts connections; `dev`/`backend` use it
wait-db:
	@cd $(BACKEND_DIR); \
	for i in $$(seq 1 90); do \
	  if $(PG_PING) >/dev/null 2>&1; then echo "[wait-db] postgres ready on :$(DEV_PG_PORT)"; exit 0; fi; \
	  sleep 1; \
	done; \
	echo "[wait-db] timed out after 90s on :$(DEV_PG_PORT)"; exit 1

## stop - frees a port held by a leftover dev process
stop: stop-tenant stop-admin stop-user stop-api stop-studio ## stop every app (postgres keeps running, see db-stop)

stop-tenant: ## stop the tenant web   :3000
	$(call kill_port,$(TENANT_PORT),tenant)

stop-admin: ## stop the admin web    :3002
	$(call kill_port,$(ADMIN_PORT),admin)

stop-user: ## stop the user web     :3001
	$(call kill_port,$(USER_PORT),user)

stop-api: ## stop the backend API  :3003
	$(call kill_port,$(API_PORT),api)

stop-studio: ## stop prisma studio    :5555
	$(call kill_port,$(STUDIO_PORT),studio)

## database - starts postgres for the command if it is not already up
db-reset: ## FULL RESET: drop + recreate (UTF8/C), migrate deploy, generate, seed
	@$(MAKE) with-db CMD="$(MIGRATE_AND_SEED)"

db-nuke: ## NUCLEAR: delete .pgdata, re-init cluster, recreate, migrate, seed
	@$(MAKE) db-stop
	rm -rf "$(PGDATA_DIR)"
	@$(MAKE) with-db CMD="$(MIGRATE_AND_SEED)"

db-migrate: ## prisma migrate dev  (make db-migrate NAME=add_foo)
	@$(MAKE) with-db CMD="yarn db:migrate $(if $(NAME),--name $(NAME),)"

db-deploy: ## prisma migrate deploy (apply pending migrations) + generate
	@$(MAKE) with-db CMD="yarn db:deploy && npx prisma generate"

db-seed: ## prisma db seed
	@$(MAKE) with-db CMD="yarn db:seed"

db-generate: ## regenerate the prisma client
	cd $(BACKEND_DIR) && npx prisma generate

db-stop: ## stop the embedded postgres, if one is running
	@if [ -n "$(PG_CTL_BIN)" ] && [ -d "$(PGDATA_DIR)" ]; then \
	  "$(CURDIR)/$(PG_CTL_BIN)" -D "$(PGDATA_DIR)" -m fast stop >/dev/null 2>&1 || true; \
	  echo "==> postgres stopped"; \
	else \
	  echo "==> nothing to stop"; \
	fi

## all four apps
install: ## install dependencies
	cd $(BACKEND_DIR) && yarn install
	cd $(TENANT_DIR) && npm install
	cd $(ADMIN_DIR) && npm install
	cd $(USER_DIR) && npm install

build: ## production build
	cd $(BACKEND_DIR) && yarn build
	cd $(TENANT_DIR) && npm run build
	cd $(ADMIN_DIR) && npm run build
	cd $(USER_DIR) && npm run build

lint: ## lint
	cd $(BACKEND_DIR) && yarn lint
	cd $(TENANT_DIR) && npm run lint
	cd $(ADMIN_DIR) && npm run lint
	cd $(USER_DIR) && npm run lint

clean: ## remove build output (keeps node_modules and .pgdata)
	rm -rf "$(BACKEND_DIR)/dist" "$(TENANT_DIR)/.next" "$(ADMIN_DIR)/.next" "$(USER_DIR)/.next"

help: ## show this help
	@printf '\nUsage: \033[36mmake <target>\033[0m   e.g. make dev, make tenant, make db-migrate NAME=add_foo\n'
	@awk 'BEGIN{FS=":.*##"} \
	  /^## /{printf "\n\033[1m%s\033[0m\n", substr($$0,4)} \
	  /^[a-zA-Z0-9_-]+:.*##/{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2} \
	  END{print ""}' $(MAKEFILE_LIST)

# --- old names -----------------------------------------------------------
# Kept so muscle memory and old notes still work; hidden from `make help`.
front: tenant
back: backend
stop-web: stop-tenant
stop-all: stop

# --- internal ------------------------------------------------------------
# Ends whatever node process is listening on $(1), labelled $(2).
#
# Windows shape: Git Bash has no lsof/fuser, so the pid comes out of netstat
# and taskkill ends it -- //T because concurrently and next both spawn
# children that outlive the parent otherwise. A listener that is NOT node is
# named and left alone: :3000 is a popular address, and a dev helper must not
# shoot down something it never started.
define kill_port
@pids=$$(netstat -ano | tr -d '\r' | awk '$$4=="LISTENING" && $$2 ~ /:$(1)$$/ {print $$5}' | sort -u); \
if [ -z "$${pids:-}" ]; then echo "[stop] $(2) :$(1) free"; else \
  for pid in $$pids; do \
    name=$$(tasklist //FI "PID eq $$pid" //NH //FO CSV 2>/dev/null | head -1 | cut -d, -f1 | tr -d '"'); \
    case "$$name" in \
      node.exe|node) \
        taskkill //PID $$pid //T //F >/dev/null 2>&1 || true; \
        echo "[stop] $(2) :$(1) killed $$name ($$pid)";; \
      *) \
        echo "[stop] $(2) :$(1) held by $${name:-unknown} ($$pid) - not ours, left alone";; \
    esac; \
  done; \
fi
endef

# Runs CMD with a guaranteed-live database: reuses one that is already
# listening, otherwise starts embedded postgres, runs CMD, and shuts it
# back down. CMD's exit code is the target's exit code.
with-db:
	@cd $(BACKEND_DIR); \
	own=0; dbpid=""; \
	if $(PG_PING) >/dev/null 2>&1; then \
	  echo "==> reusing postgres already listening on :$(DEV_PG_PORT)"; \
	else \
	  echo "==> starting embedded postgres on :$(DEV_PG_PORT)"; \
	  node scripts/dev-db.mjs & \
	  dbpid=$$!; own=1; ok=0; \
	  for i in $$(seq 1 90); do \
	    if $(PG_PING) >/dev/null 2>&1; then ok=1; break; fi; \
	    sleep 1; \
	  done; \
	  if [ $$ok -ne 1 ]; then echo "!! postgres did not come up on :$(DEV_PG_PORT)"; exit 1; fi; \
	fi; \
	echo "==> $(CMD)"; \
	set +e; bash -c '$(CMD)'; rc=$$?; set -e; \
	if [ $$own -eq 1 ]; then \
	  echo "==> stopping embedded postgres"; \
	  if [ -n "$(PG_CTL_BIN)" ]; then "$(CURDIR)/$(PG_CTL_BIN)" -D "$(PGDATA_DIR)" -m fast stop >/dev/null 2>&1 || true; fi; \
	  if [ -n "$$dbpid" ]; then kill $$dbpid >/dev/null 2>&1 || true; fi; \
	fi; \
	exit $$rc

.PHONY: dev dev-all backend tenant admin user api db studio wait-db \
        stop stop-tenant stop-admin stop-user stop-api stop-studio \
        front back stop-web stop-all \
        db-reset db-nuke db-migrate db-deploy db-seed db-generate db-stop \
        install build lint clean help with-db
