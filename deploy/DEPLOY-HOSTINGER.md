# Deploy to Hostinger — sms.digitalsafar.tech / smsback.digitalsafar.tech

| What | Domain | Server path |
|---|---|---|
| React (Vite) SPA | `sms.digitalsafar.tech` | `/home/u652379655/domains/digitalsafar.tech/public_html/sms` |
| Laravel API | `smsback.digitalsafar.tech` | `/home/u652379655/domains/digitalsafar.tech/public_html/smsback` |
| Python face service | not on shared hosting | needs a VPS (see step 8) |

Prepared upload packages:

- `deploy/upload/sms/` → React build + `.htaccess` (SPA fallback)
- `deploy/upload/smsback-public/` → Laravel `public/` + production `.htaccess`

## Server facts (confirmed)

| | |
|---|---|
| Type | **Hostinger shared hosting** — no Python runtime, no persistent processes |
| IP | `145.79.28.23` |
| SSH port | `65002` (not 22 — that is why this is shared, not VPS) |
| SSH user | `u652379655` |
| SSH command | `ssh -p 65002 u652379655@145.79.28.23` |
| Account email | `malik.bilal.mubarak@gmail.com` |
| PHP CLI | discover with `ls -d /opt/alt/php*`, then use that version's binary |

Subdomains already exist (their document roots are `public_html/sms` and
`public_html/smsback`). Manage them under
**Websites → digitalsafar.tech → Domains → Subdomains**.

---

## Step 1 — hPanel: websites and PHP

1. hPanel → **Websites**. Confirm you have two separate entries:
   `digitalsafar.tech`, `sms.digitalsafar.tech`, `smsback.digitalsafar.tech`.
   If a subdomain is missing, add it there first.
2. hPanel → **Advanced → PHP Configuration** for `smsback.digitalsafar.tech`.
   Set **PHP 8.2 or newer** (Laravel 12 will not run on 8.1 or lower).
   Write down the exact version — you need it for the CLI paths below.
3. hPanel → **Websites → Manage → Domains** for `smsback.digitalsafar.tech`.
   Change the document root to:

   ```
   /home/u652379655/domains/digitalsafar.tech/public_html/smsback/public
   ```

   This is the single most important setting. Without it the server shows a
   directory listing instead of running Laravel, and `.env` sits in the web root.
4. hPanel → **Security → SSL** → install a Let's Encrypt certificate for both
   subdomains, then turn on **Force HTTPS**.

## Step 2 — hPanel: create the database

hPanel → **Databases → Management**:

1. New database → name it `sms_college`.
   Hostinger prefixes it, so the real name is `u652379655_sms_college`.
2. New database user → name it `smscollege`, set a strong password.
   The real username is `u652379655_smscollege`.
3. Add the user to the database with **All Privileges**.
4. Copy down the password — you need it for `.env`.

## Step 3 — Upload Laravel

Upload the **contents** of `E:\Mernprojects\SMS\backend\` into
`public_html/smsback/`, so it ends up like this:

```
public_html/smsback/
├── app/  bootstrap/  config/  database/  lang/  public/
├── routes/  storage/  vendor/
├── artisan  composer.json  composer.lock
└── .env
```

Skip `node_modules`, `.git`, and `tests`.

Then upload `deploy/upload/smsback-public/` **into** `public_html/smsback/public/`
and choose *overwrite*. This replaces `.htaccess` with the production one that
serves `/storage/`, passes the `Authorization` header to Sanctum, blocks `.env`,
and raises the upload limit to 12 MB.

Then copy `deploy/env.production.txt` to `public_html/smsback/.env` and edit:

```
APP_ENV=production
APP_DEBUG=false                 <- must be false
APP_URL=https://smsback.digitalsafar.tech

DB_DATABASE=u652379655_sms_college
DB_USERNAME=u652379655_smscollege
DB_PASSWORD=<the password from step 2>

SESSION_DOMAIN=smsback.digitalsafar.tech
```

`APP_KEY` is already filled in. Keep it — changing it later invalidates every
issued login token.

Finally upload `backend/storage/app/public/` (the `photos/`, `faces/`,
`branding/` folders) into `public_html/smsback/storage/app/public/`.

> Do **not** run `php artisan storage:link`. On Hostinger shared hosting the
> symlink fails, and the `.htaccess` rewrite already maps
> `/storage/...` to `storage/app/public/...`.

## Step 4 — Set permissions

hPanel → **Files → Permissions**:

| Folder | Permission |
|---|---|
| `public_html/smsback/public` | `755` |
| `public_html/smsback/storage` | `775` |
| `public_html/smsback/bootstrap/cache` | `775` |
| `public_html/sms` | `755` |

## Step 5 — Composer, migrations, seed

This needs **SSH or the hPanel Terminal**. If you have neither, upload your
local `backend/vendor/` folder and skip the `composer install` line.

```bash
cd /home/u652379655/domains/digitalsafar.tech/public_html/smsback

/opt/alt/php82/usr/bin/php /opt/alt/php82/usr/bin/composer install --no-dev --optimize-autoloader
/opt/alt/php82/usr/bin/php artisan migrate --force
/opt/alt/php82/usr/bin/php artisan db:seed --force
/opt/alt/php82/usr/bin/php artisan optimize:clear
```

> Replace `php82` with `php83` / `php84` to match the version you set in step 1.
> Hostinger's default SSH PHP is often 7.4, which Laravel 12 will refuse to run
> on — always call the versioned binary explicitly.

## Step 6 — Scheduler (fee reminders, late fees at 07:00)

hPanel → **Advanced → Cron Jobs**, one job:

```
* * * * * cd /home/u652379655/domains/digitalsafar.tech/public_html/smsback && /opt/alt/php82/usr/bin/php artisan schedule:run >> /dev/null 2>&1
```

Set frequency to **Every minute**.

## Step 7 — Upload React

Upload everything in `deploy/upload/sms/` into `public_html/sms/`.

```
public_html/sms/
├── .htaccess
├── index.html
├── favicon.svg
├── icons.svg
├── logo.png
└── assets/
```

The build is already compiled against `https://smsback.digitalsafar.tech`
(that URL is baked into `assets/index-*.js`), so nothing needs rebuilding.

The `.htaccess` is required. Without it, refreshing `https://sms.digitalsafar.tech/students`
returns a 404 even though clicking links inside the app works fine.

## Step 8 — Verify

Run these in order:

| Check | Expected |
|---|---|
| `https://smsback.digitalsafar.tech/api/branding` | JSON, no error page |
| `https://sms.digitalsafar.tech` | login screen |
| Log in at `sms.digitalsafar.tech` | dashboard loads |
| Refresh `https://sms.digitalsafar.tech/students` | still the app, not a 404 |
| Open any student with a photo | image loads from `smsback.digitalsafar.tech/storage/...` |
| hPanel → Advanced → PHP Error Log | empty |

## Step 9 — Python face service (separate, optional)

Hostinger shared hosting has no Python runtime and blocks `exec`/`shell_exec`,
so `uvicorn` cannot run there. Everything else works without it — the React app
scans faces offline in the browser and syncs the results to
`/api/face/sync` later.

When you want it live, get a Hostinger VPS (or Railway/Render/Fly):

```bash
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
uvicorn app:app --host 127.0.0.1 --port 8001
```

Run it as a systemd service, copy `face-service/models/*.onnx` across (38 MB,
and the app will try to download them on first start, which fails on a locked
down server), then set in `public_html/smsback/.env`:

```
FACE_SERVICE_URL=https://face.digitalsafar.tech
```

## Redeploying later

Only `frontend/dist` changes normally:

```powershell
cd E:\Mernprojects\SMS\frontend
npm run build
```

Then re-upload `dist/*` into `public_html/sms/`. Remember to overwrite
`.htaccess` too, or it will not be replaced.

---

## Gotchas that will bite you

- **`APP_DEBUG=true` leaks everything.** With debug on, any Laravel error page
  prints your database password and `APP_KEY` to the visitor.
- **Cross-origin.** The app is on `sms.` and the API on `smsback.`. That works
  because `backend/config/cors.php` has `allowed_origins => ['*']`. Before
  launch, change that to `['https://sms.digitalsafar.tech']`.
- **Sanctum needs the Authorization header.** The `.htaccess` line
  `RewriteCond %{HTTP:Authorization} .` is what makes Bearer tokens reach PHP.
  Without it every request comes back as "Unauthenticated."
- **Never upload `.env` inside `public/`.** It must sit one level up, at
  `public_html/smsback/.env`.
- **`.htaccess` must be named exactly that.** A file named `htaccess.txt` or
  `.htaccess.txt` is silently ignored — no error, just broken routing.
