# Deploy Qo'llanma

Bu fayl `deploy_u9` loyihasini `Docker + PostgreSQL + Nginx + SSL` bilan serverga joylash uchun boshidan oxirigacha qadamma-qadam yozilgan qo'llanma.

Loyiha domeni:
- `new-project.uz`
- `www.new-project.uz`

Repo:
- `git@github.com:temuralidavron/deploy_u9.git`

Asosiy servislar:
- `web` - Django + Gunicorn
- `db` - PostgreSQL
- `nginx` - reverse proxy

## 1. Docker Nima?

Docker dasturni alohida konteyner ichida ishga tushiradi.

Oddiy qilib:
- serverda Python o'rnatilganmi yoki yo'qmi, farqi kamayadi
- kutubxonalar chalkashib ketmaydi
- loyiha bir xil muhitda ishlaydi

Asosiy tushunchalar:
- `Dockerfile` - image yig'ish retsepti
- `image` - tayyor shablon
- `container` - image'dan ishga tushgan jarayon
- `docker compose` - bir nechta container'ni birga boshqarish usuli
- `volume` - ma'lumotni saqlab qoladigan joy

Bu loyihada oqim:
1. `db` ishga tushadi.
2. `web` PostgreSQL tayyor bo'lishini kutadi.
3. Django migratsiya qiladi.
4. Static fayllar yig'iladi.
5. Gunicorn ilovani `8000` portda ishga tushiradi.
6. Nginx tashqi so'rovlarni `web` container'ga yuboradi.

## 2. Lokal Tayyorlov

Lokalda loyiha ichida quyidagilar tayyor bo'lishi kerak:
- `Dockerfile`
- `docker-compose.yml`
- `.env.example`
- `entrypoint.sh`
- `store/migrations/0001_initial.py`

Lokal test:

```bash
cp .env.example .env
docker compose up --build -d
docker compose ps
docker compose logs -f web
```

Admin user yaratish:

```bash
docker compose exec web python manage.py createsuperuser
```

## 3. Gitga Yuborish

Repo hali bo'lmasa:

```bash
git init
git add .
git commit -m "first commit"
git branch -M main
git remote add origin git@github.com:temuralidavron/deploy_u9.git
git push -u origin main
```

Muhim:
- `.env` gitga yuborilmaydi
- `.gitignore` bunga javob beradi

## 4. Serverga Kirish

Serverga SSH bilan kirasiz:

```bash
ssh user@server_ip
```

Agar server `Ubuntu` bo'lsa, quyidagi buyruqlar ishlatiladi.

## 5. Docker va Kerakli Paketlarni O'rnatish

```bash
sudo apt update
sudo apt install -y ca-certificates curl nginx snapd
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo ${UBUNTU_CODENAME:-$VERSION_CODENAME}) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
docker --version
docker compose version
```

## 6. Repo'ni Serverga Clone Qilish

```bash
git clone git@github.com:temuralidavron/deploy_u9.git
cd deploy_u9
```

## 7. `.env` Faylni Yaratish

```bash
cp .env.example .env
nano .env
```

Biz ishlatgan tayyor `.env` namunasi:

```env
DEBUG=0
SECRET_KEY=django-insecure-new-project-uz-2026-secret-key-938472
DJANGO_ALLOWED_HOSTS=new-project.uz www.new-project.uz
CSRF_TRUSTED_ORIGINS=https://new-project.uz https://www.new-project.uz
TIME_ZONE=Asia/Tashkent

POSTGRES_DB=new_project_db
POSTGRES_USER=new_project_user
POSTGRES_PASSWORD=new_project_password_2026
DATABASE_HOST=db
DATABASE_PORT=5432

SECURE_SSL_REDIRECT=0
SESSION_COOKIE_SECURE=0
CSRF_COOKIE_SECURE=0
```

Izoh:
- `DEBUG=0` production uchun
- `DATABASE_HOST=db` chunki Compose ichida PostgreSQL servisi `db` nomi bilan yuradi
- SSL olinmaguncha secure flag'lar `0` bo'ladi

## 8. Containerlarni Ishga Tushirish

```bash
docker compose up -d --build
docker compose ps
docker compose logs -f web
```

Kutiladigan holat:
- `db` healthy bo'ladi
- `web` start bo'ladi
- migratsiyalar ishlaydi
- static fayllar yig'iladi
- `gunicorn` `0.0.0.0:8000` da turadi

Admin user yaratish:

```bash
docker compose exec web python manage.py createsuperuser
```

Parol yozganda ekranda hech narsa ko'rinmaydi. Bu normal holat.

## 9. Ilova Ichkarida Ishlayaptimi Tekshirish

```bash
curl http://127.0.0.1:8000
```

`Not Found` chiqsa ham yomon emas. Bu Django javob qaytarayotganini bildiradi. Root `/` route yo'qligi uchun `404` bo'lishi mumkin.

Haqiqiy endpointlar:
- `http://127.0.0.1:8000/api/`
- `http://127.0.0.1:8000/admin/`

## 10. Nginx Konfiguratsiyasi

Avval `nginx.conf` ni to'liq yozib oldik:

```bash
sudo tee /etc/nginx/nginx.conf > /dev/null <<'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
error_log /var/log/nginx/error.log;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
}

http {
    server_names_hash_bucket_size 64;
    server_names_hash_max_size 512;

    sendfile on;
    tcp_nopush on;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    access_log /var/log/nginx/access.log;

    gzip on;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF
```

Keyin domen config yozildi:

```bash
sudo tee /etc/nginx/sites-available/new-project.uz > /dev/null <<'EOF'
server {
    listen 80;
    server_name new-project.uz www.new-project.uz;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
```

Keyin yoqildi:

```bash
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/new-project.uz /etc/nginx/sites-enabled/new-project.uz
sudo nginx -t
sudo systemctl restart nginx
```

Muhim:
- `nginx -t` `syntax is ok` chiqishi kerak
- `server_names_hash_bucket_size` xatosi bo'lsa, `nginx.conf` ichidagi yuqoridagi 2 qator yordam beradi

## 11. Domen Ishlayaptimi Tekshirish

```bash
curl http://new-project.uz
curl http://www.new-project.uz
```

`Not Found` chiqsa ham yomon emas. Bu request domen orqali Django'ga yetib borganini bildiradi.

## 12. SSL Sertifikat Olish

```bash
sudo snap install core
sudo snap refresh core
sudo snap install --classic certbot
sudo ln -sf /snap/bin/certbot /usr/local/bin/certbot
sudo certbot --nginx -d new-project.uz -d www.new-project.uz
```

Certbot nimalarni qiladi:
- Let's Encrypt'dan sertifikat oladi
- Nginx config'ga SSL ulaydi
- auto renew vazifasini yaratadi

Natijada:
- `https://new-project.uz`
- `https://www.new-project.uz`

ishlay boshlaydi.

## 13. SSLdan Keyin `.env`ni Yangilash

SSL tayyor bo'lgach `.env` ichida quyidagilarni `1` qilamiz:

```env
SECURE_SSL_REDIRECT=1
SESSION_COOKIE_SECURE=1
CSRF_COOKIE_SECURE=1
```

Keyin:

```bash
docker compose up -d
sudo systemctl reload nginx
```

Tekshiruv:

```bash
curl -I https://new-project.uz
curl -I https://www.new-project.uz
```

## 14. Brauzerda Tekshirish

Asosiy foydali yo'llar:
- `https://new-project.uz/api/`
- `https://new-project.uz/admin/`

Eslatma:
- `https://new-project.uz/` root route hozir `404` bo'lishi mumkin
- bu deploy buzilganini anglatmaydi
- bu faqat `/` uchun URL yozilmaganini anglatadi

## 15. Yangilanish Chiqqanda Qanday Deploy Qilinadi

Kodga o'zgartirish kiritilgach serverda:

```bash
cd ~/deploy_u9
git pull origin main
docker compose up -d --build
docker compose logs -f web
```

Agar model o'zgargan bo'lsa, container start vaqtida migratsiya avtomatik ishlaydi.

## 16. Foydali Tekshiruv Buyruqlari

Containerlar holati:

```bash
docker compose ps
```

Web log:

```bash
docker compose logs -f web
```

DB log:

```bash
docker compose logs -f db
```

Nginx config test:

```bash
sudo nginx -t
```

Nginx qayta yuklash:

```bash
sudo systemctl reload nginx
sudo systemctl restart nginx
```

SSL renew test:

```bash
sudo certbot renew --dry-run
```

## 17. Tez-tez Uchraydigan Muammolar

### `docker compose build` ishlamasa
- Docker daemon ishlayotganini tekshiring:

```bash
sudo systemctl status docker
```

### `web` container start bo'lmay qolsa
- logni ko'ring:

```bash
docker compose logs -f web
```

### Domen ochilib `404 Not Found` chiqsa
- bu ko'pincha yaxshi belgi
- demak domen `Nginx -> Django` zanjiri ishlagan
- `/api/` yoki `/admin/` ni tekshiring

### Nginx `server_names_hash_bucket_size` xatosi chiqsa
- `nginx.conf` ichida mana bular bo'lsin:

```nginx
server_names_hash_bucket_size 64;
server_names_hash_max_size 512;
```

### SSL olinmasa
- DNS `A record` to'g'ri ko'rsatilganmi tekshiring
- `new-project.uz` va `www.new-project.uz` server IP'ga qarashi kerak
- `80` va `443` portlar ochiq bo'lishi kerak

## 18. Shu Deployda Ishlatilgan Asosiy Fayllar

- `Dockerfile`
- `docker-compose.yml`
- `.env.example`
- `entrypoint.sh`
- `config/settings.py`
- `config/urls.py`
- `store/migrations/0001_initial.py`

## 19. Qisqa Xulosa

Deploy zanjiri quyidagicha:
1. Kod gitga push qilinadi.
2. Serverga clone qilinadi.
3. `.env` yoziladi.
4. Docker orqali `web` va `db` ko'tariladi.
5. Admin user yaratiladi.
6. Nginx domenni `8000` portdagi Django'ga uzatadi.
7. Certbot SSL sertifikat qo'yadi.
8. `.env` secure flag'lari yoqiladi.
9. Sayt `https://new-project.uz` da ishlaydi.
