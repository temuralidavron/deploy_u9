# Django REST Framework + PostgreSQL + Docker

Bu loyiha `Django REST Framework` ilovasi bo'lib, `PostgreSQL` bilan ishlaydi va Docker orqali serverga qulay deploy qilinadigan holatga keltirilgan.

Asosiy endpoint:
- `/api/` - `Category` va `Product` uchun DRF router

**Docker Nima?**
Docker dasturni "o'z qutisi" ichida ishga tushirish usuli.

Oddiy qilib:
- Sizning laptopingizda Python bir xil, serverda boshqa versiya bo'lishi mumkin.
- Bir joyda paket ishlaydi, boshqa joyda buziladi.
- Docker ilovani kerakli muhiti bilan birga o'rab beradi.

Bu loyihada:
- `web` konteyneri: Django + Gunicorn
- `db` konteyneri: PostgreSQL

Docker ichidagi asosiy tushunchalar:
- `Dockerfile`: image qanday yig'ilishini yozadigan retsept
- `image`: tayyor shablon, ya'ni yig'ilgan muhit
- `container`: image'dan ishga tushgan real nusxa
- `docker compose`: bir nechta konteynerni birga boshqarish usuli
- `volume`: ma'lumotni konteyner o'chsa ham saqlab qoladi

Bu loyihadagi oqim:
1. `db` konteyneri PostgreSQL'ni ishga tushiradi.
2. `web` konteyneri kutadi, baza tayyor bo'lsa ulanadi.
3. Django migratsiya qiladi.
4. Statik fayllar yig'iladi.
5. Gunicorn ilovani servis sifatida ko'taradi.

**Lokal Ishga Tushirish**
1. `.env.example` dan `.env` yarating:

```bash
cp .env.example .env
```

2. `.env` ichidagi qiymatlarni o'zingizga moslang.

3. Konteynerlarni ishga tushiring:

```bash
docker compose up --build -d
```

4. Admin user yarating:

```bash
docker compose exec web python manage.py createsuperuser
```

5. Tekshirish:

```bash
docker compose ps
docker compose logs -f web
```

Admin panel:
- `http://127.0.0.1:8000/admin/`

API:
- `http://127.0.0.1:8000/api/`

**Serverga Deploy**
Quyidagi yo'l eng sodda va amaliy variant:

1. Serverga `Docker Engine` va `Docker Compose plugin` o'rnating.
2. Loyihani serverga ko'chiring.
3. `.env` fayl yarating:

```bash
cp .env.example .env
```

4. `.env` ni production qiymatlar bilan to'ldiring:
- `DEBUG=0`
- `SECRET_KEY` uzun va tasodifiy bo'lsin
- `DJANGO_ALLOWED_HOSTS` ichiga domen va server IP kiriting
- `CSRF_TRUSTED_ORIGINS` ichiga `https://` bilan domenlarni yozing
- `POSTGRES_PASSWORD` kuchli bo'lsin

5. Konteynerlarni ko'taring:

```bash
docker compose up -d --build
```

6. Holatini tekshiring:

```bash
docker compose ps
docker compose logs -f
```

7. Admin user yarating:

```bash
docker compose exec web python manage.py createsuperuser
```

**Reverse Proxy Tavsiya**
Productionda odatda foydalanuvchi `8000` portga emas, `Nginx` orqali kiradi.

Tavsiya qilinadigan sxema:
- Internet -> `Nginx`
- `Nginx` -> `web:8000`
- Django -> `db:5432`

Nega kerak:
- Domen ulash osonlashadi
- HTTPS/SSL sertifikat ulash osonlashadi
- Port 8000 ni tashqariga ochib qo'ymaslik mumkin

Agar Nginx orqali HTTPS ishlatsangiz, `.env` ichida quyidagilarni yoqishingiz mumkin:

```env
SECURE_SSL_REDIRECT=1
SESSION_COOKIE_SECURE=1
CSRF_COOKIE_SECURE=1
```

**Muhim Fayllar**
- [docker-compose.yml](docker-compose.yml) - `web` va `db` servislar
- [Dockerfile](Dockerfile) - Django image yig'ilishi
- [entrypoint.sh](entrypoint.sh) - DB kutish, migrate, collectstatic
- [config/settings.py](config/settings.py) - Django production sozlamalari
- [store/migrations/0001_initial.py](store/migrations/0001_initial.py) - birinchi migratsiya

**Foydali Buyruqlar**
Konteynerlarni to'xtatish:

```bash
docker compose down
```

Loglarni ko'rish:

```bash
docker compose logs -f web
docker compose logs -f db
```

Faqat qayta build:

```bash
docker compose up -d --build
```

PostgreSQL ma'lumoti qayerda saqlanadi:
- `postgres_data` volume ichida
- Shu sabab konteyner qayta yaratilsa ham baza saqlanib qoladi
