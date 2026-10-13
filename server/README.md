# لوحة الأهل (سيرفر دراستي)

لوحة على الويب تشوف فيها شو درس كل ولد (لميس، مفيد، لجين، ندى)، وكم نجمة أخذ في كل درس،
وأكثر الأسئلة اللي بغلط فيها، وتقدر تضيف له **اختبار على دروس معيّنة مع جائزة**.
اللعبة بتشتغل بدون إنترنت، ولما يكون في نت بترفع التقدّم للسيرفر وبتنزّل الاختبارات الجديدة.

## 1. التشغيل على VPS (Docker، معزول عن باقي الخدمات)

اللوحة بتشتغل بكونتينر لحالها، بشبكة و volume خاصين فيها، وما بتلمس أي إشي ثاني على السيرفر:
- بتسمع بس على `127.0.0.1:8090`، يعني ما حدا بيوصلها من برا إلا عن طريق الـ HTTPS proxy.
- محدودة بـ 256MB رام ونص معالج.
- نظام الملفات read-only، وبتشتغل كمستخدم عادي (مش root).
- اللوغز محدودة بـ 30MB.

**أ. نزّل الكود** (بس مجلدي `server` و `data`، بدون كتب الـ PDF الكبيرة). المستودع خاص، فبدك
[توكن GitHub](https://github.com/settings/tokens) بصلاحية قراءة للمستودع:

```bash
cd ~
git clone --filter=blob:none --sparse -b feat/game-foundation https://<TOKEN>@github.com/karmontal/StudyGame.git studygame
cd studygame && git sparse-checkout set server data
cd server
```

(بعد ما ندمج الـ PR استخدم `-b main`.)

**ب. الإعدادات:**

```bash
cp .env.example .env
openssl rand -hex 16    # انسخ الناتج كمفتاح الجهاز
nano .env               # حط المفتاح وكلمة سر طويلة
```

**ج. شغّل:**

```bash
docker compose up -d --build
docker ps                 # لازم يطلع studygame-dashboard ... (healthy) بعد دقيقة
curl -H "X-Device-Key: <المفتاح>" http://127.0.0.1:8090/api/ping    # {"ok":true}
```

| المتغير في `.env` | معناه |
|---|---|
| `STUDYGAME_DEVICE_KEY` | مفتاح الجهاز: نفس المفتاح بتكتبه في اللعبة. 8 أحرف على الأقل، والأفضل طويل وعشوائي. |
| `STUDYGAME_ADMIN_PASSWORD` | كلمة سر دخول لوحة الأهل. 8 أحرف على الأقل. |
| `STUDYGAME_SECURE_COOKIE` | خلّيها `1` لما يكون الموقع على HTTPS. |
| `TZ` | المنطقة الزمنية (مثلاً `Asia/Gaza`) عشان "اليوم" و"هالأسبوع" يكونوا صح. |
| `STUDYGAME_PORT` | البورت المحلي (افتراضي 8090). غيّره إذا في خدمة ثانية عليه: `sudo ss -tlnp \| grep 8090` |
| `STUDYGAME_DOMAIN` | الدومين، بس إذا استخدمت Caddy اللي معنا (الخيار الثاني تحت). |

السيرفر ما بيشتغل إذا المفتاح أو كلمة السر ناقصين أو أقصر من 8 أحرف (هذا مقصود).
البيانات محفوظة في volume اسمه `studygame_studygame-db` وما بتضيع لما تحدّث أو تعيد التشغيل.

للتحديث: `git pull && docker compose up -d --build`

حدّث السيرفر كل ما تنزّل نسخة جديدة من اللعبة. إذا اللعبة أحدث من السيرفر، المزامنة بتعطي خطأ 422 (مثلاً آية بالصف 0 أو مسابقة العيلة ما كانوا موجودين بالنسخة القديمة).

نسخة احتياطية من البيانات:
`docker exec studygame-dashboard python -c "import sqlite3; s=sqlite3.connect('/app/data/studygame.db'); s.backup(sqlite3.connect('/app/data/backup.db'))" && docker cp studygame-dashboard:/app/data/backup.db ~/studygame-backup-$(date +%F).db`

## 2. HTTPS (ضروري للعبة)

أولاً، اعمل subdomain (مثلاً `study.yourdomain.com`) بيأشّر بسجل A على IP السيرفر. بعدين شوف إذا
في إشي شغّال على البورتات 80 و 443:

```bash
sudo ss -tlnp | grep -E ':80 |:443 '
```

**الخيار الأول: في nginx أو Caddy أو Traefik شغّال أصلاً** (الأغلب إذا عندك مواقع ثانية).
لا تشغّل Caddy تبعنا، بس زيد موقع جديد عالـ proxy الموجود:

nginx (`/etc/nginx/sites-available/study`):

```nginx
server {
    server_name study.yourdomain.com;
    location / {
        proxy_pass http://127.0.0.1:8090;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/study /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d study.yourdomain.com
```

Caddy موجود: زيد بالـ `Caddyfile`:

```caddy
study.yourdomain.com {
    reverse_proxy 127.0.0.1:8090
}
```

**الخيار الثاني: البورتات 80 و 443 فاضية.** حط الدومين بـ `STUDYGAME_DOMAIN` بالـ `.env` وشغّل:

```bash
docker compose --profile https up -d --build
```

Caddy بكونتينر بيطلع شهادة HTTPS لحاله. تأكد إن البورتين 80 و 443 مفتوحين بالـ firewall
(عند Hostinger: hPanel > VPS > Security > Firewall، وإذا في `ufw`: `sudo ufw allow 80,443/tcp`).

افتح `https://study.yourdomain.com` من الموبايل وادخل بكلمة السر.

## 3. ربط اللعبة

1. في اللعبة، بشاشة اختيار الولد، اضغط مطوّلاً على زر **للأهل**.
2. اكتب عنوان السيرفر: `https://study.yourdomain.com`
3. اكتب **مفتاح الجهاز** (نفس `STUDYGAME_DEVICE_KEY`).
4. اضغط زر فحص الاتصال. إذا نجح، اللعبة بتزامن لحالها كل ما يخلص الولد جولة ويكون في إنترنت.

## شو في اللوحة

- **الأولاد**: بطاقة لكل ولد: المستوى، العملات، الأيام المتتالية، آخر نشاط، دروس هالأسبوع، الدقة، الاختبارات المفتوحة.
- **صفحة الولد**: كل مادة بوحداتها ودروسها والنجوم وآخر مرة لعبها، آخر النشاطات، الأوسمة والملصقات،
  وأكثر الأسئلة اللي غلط فيها مع الإجابة الصحيحة.
- **تقرير الأسبوع**: آخر 7 أيام (جولات، أسئلة، دقة، نجوم، دروس جديدة) بصفحة وحدة سهلة تاخدلها screenshot.
- **الاختبارات**: اختار الولد، المادة، علّم على الدروس، واكتب اسم الاختبار ورسالة للولد والجائزة وأقل عدد نجوم.
  لما يجيب النجوم المطلوبة بيصير الاختبار "أنجزه"، وبعد ما تعطيه الجائزة اضغط **سلّمت الجائزة**.

---

## Developers

FastAPI + SQLite (stdlib `sqlite3`) + Jinja2, no JS build. Contract: [`../docs/sync_api.md`](../docs/sync_api.md).

```bash
cd server
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements-dev.txt
pytest -q
STUDYGAME_DEVICE_KEY=devkey123 STUDYGAME_ADMIN_PASSWORD=devpass123 \
  uvicorn app.main:create_app --factory --reload   # http://127.0.0.1:8000 (cookie not https-only by default)
```

Env: `STUDYGAME_DEVICE_KEY`, `STUDYGAME_ADMIN_PASSWORD` (both required, >= 8 chars),
`STUDYGAME_DB` (default `./data/studygame.db`), `STUDYGAME_CONTENT` (repo `data/` folder, default `../data`),
`STUDYGAME_SECURE_COOKIE` (`1` = https-only cookie).

Layout:
- `app/api.py`: `/api/ping`, `/api/sync` (key check with `hmac.compare_digest`, 1 MB body cap, max 500 events, pydantic validation).
- `app/db.py`: schema, `apply_sync()` (`INSERT OR IGNORE` on event id; assignment rules only run for newly stored events; summary upsert).
- `app/stats.py`: read queries for the pages. `app/content.py`: curriculum lookup (`book/unit/lesson[/index]`), badge names copied from `scripts/game/rewards.gd`.
- `app/web.py` + `app/templates/`: dashboard; signed session cookie (Starlette `SessionMiddleware`, key derived from the admin password), CSRF token on every POST form.

Notes: assignment ids on the wire are `"a<rowid>"`. `done_at` is the `at` of the first qualifying event (phone time).
A sync with more than 500 events is rejected with 422, so the game must send at most 500 per request.
