# لوحة الأهل (سيرفر دراستي)

لوحة على الويب تشوف فيها شو درس كل ولد (لميس، مفيد، لجين، ندى)، وكم نجمة أخذ في كل درس،
وأكثر الأسئلة اللي بغلط فيها، وتقدر تضيف له **اختبار على دروس معيّنة مع جائزة**.
اللعبة بتشتغل بدون إنترنت، ولما يكون في نت بترفع التقدّم للسيرفر وبتنزّل الاختبارات الجديدة.

## 1. التشغيل (Docker)

على السيرفر (لازم يكون عليه Docker و Docker Compose):

```bash
git clone <رابط مستودع اللعبة> studygame
cd studygame/server
cp .env.example .env
nano .env        # غيّر المفتاح وكلمة السر
docker compose up -d --build
```

في ملف `.env`:

| المتغير | معناه |
|---|---|
| `STUDYGAME_DEVICE_KEY` | مفتاح الجهاز: نفس المفتاح بتكتبه في اللعبة. 8 أحرف على الأقل، والأفضل طويل وعشوائي. |
| `STUDYGAME_ADMIN_PASSWORD` | كلمة سر دخول لوحة الأهل. 8 أحرف على الأقل. |
| `STUDYGAME_SECURE_COOKIE` | خلّيها `1` لما يكون الموقع على HTTPS. |
| `TZ` | المنطقة الزمنية (مثلاً `Asia/Gaza`) عشان "اليوم" و"هالأسبوع" يكونوا صح. |

لعمل مفتاح عشوائي: `openssl rand -hex 16`

السيرفر ما بيشتغل إذا المفتاح أو كلمة السر ناقصين أو أقصر من 8 أحرف (هذا مقصود).
البيانات محفوظة في volume اسمه `studygame-db` وما بتضيع لما تحدّث أو تعيد التشغيل.

للتحديث بعد ما تنزل نسخة جديدة من اللعبة: `git pull && docker compose up -d --build`

## 2. HTTPS (ضروري)

السيرفر بيسمع فقط على `127.0.0.1:8000`، وبتحط قدامه Caddy عشان يعطيك HTTPS تلقائي.
محتاج دومين (أو subdomain) بيأشّر على عنوان السيرفر. مثال `Caddyfile`:

```caddy
study.example.com {
    encode gzip
    reverse_proxy 127.0.0.1:8000
}
```

بعدها `sudo systemctl reload caddy`، وافتح `https://study.example.com` من الموبايل وادخل بكلمة السر.

## 3. ربط اللعبة

1. في اللعبة افتح **إعدادات الأهل**.
2. اكتب عنوان السيرفر: `https://study.example.com`
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
