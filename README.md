# GAS Git Workflow Template

This repository is a **starter template** for managing a Google Apps Script project with Git. It sets up a clean development workflow with separate **DEV** and **PROD** environments, version-controlled Git hooks, and helper scripts to make pushing and promoting code safe and predictable.

---

## ✨ Features

- **Two environments (DEV/PROD)**  
  – `.clasp.dev.json` and `.clasp.prod.json` are included with placeholders for your own Script IDs.  
  – Easy one-time initialization (`scripts/init-ids.sh`) to insert your real IDs.  

- **Git hook automation**  
  – A `pre-push` hook runs `clasp push` to keep your DEV environment always in sync when you push to Git.  
  – Hooks are version-controlled under `.githooks/` so they work consistently across clones.  

- **Promotion flow**  
  – `scripts/promote-to-prod.sh` safely promotes the current code to PROD.  
  – Checks that you are on a clean `main` branch, with optional tagging for release notes.  

- **Diff tooling**  
  – `scripts/gas-diff.sh` lets you compare two GAS projects (by Script ID or local folders).  
  – Supports unified diff or just a summary list of added/modified/deleted files.  

- **Safe configuration management**  
  – `.clasp.json` is ignored in Git (it’s always a generated/temporary file).  
  – Scripts automatically copy the correct config (`.clasp.dev.json` or `.clasp.prod.json`) before pushing.  

- **Minimal starter code**  
  – Includes a simple `Code.gs` with a `myFunction()` that logs a message so you can verify the pipeline works immediately.  
  – `appsscript.json` is pre-configured with V8 runtime and safe defaults.  

---

## 🚀 Getting started

1. Clone this template:
   ```bash
   git clone <url> my-gas-project
   cd my-gas-project
   ```

2. Install clasp and log in:
   ```bash
   npx @google/clasp login --no-localhost
   ```

3. Initialize your Script IDs:
   ```bash
   ./scripts/init-ids.sh  # enters DEV and PROD IDs once and saves them into the JSON configs
   ```

4. Enable versioned hooks:
   ```bash
   ./scripts/install-hooks.sh
   ```

5. Push to DEV (automatically via pre-push) or manually:
   ```bash
   ./scripts/push-dev.sh
   ```

6. Release to PROD when ready:
   ```bash
   ./scripts/release.sh
   ```


## 🧩 Project structure

```text
.githooks/          # version-controlled Git hooks
  pre-push          # runs clasp push to DEV
scripts/            # helper scripts
  init-ids.sh       # set your real DEV/PROD Script IDs
  push-dev.sh       # push code to DEV
  promote-to-prod.sh# promote code to PROD safely
  gas-diff.sh       # compare two GAS projects
src/                # your Apps Script source files
  Code.gs           # starter code (hello world)
.clasp.dev.json     # DEV config (with placeholder Script ID)
.clasp.prod.json    # PROD config (with placeholder Script ID)
.gitignore          # ignores .clasp.json and build artifacts
```

## 📦 Why use this template?

- Keeps your Apps Script projects under **version control**.  
- Makes it easy to **separate DEV and PROD** safely.  
- Automates away the noisy `.clasp.json` switching.  
- Provides tooling to **diff and review** before promoting.  
- Works out of the box for **bound scripts** (Sheets, Docs, etc.) and standalone Apps Script projects.  
