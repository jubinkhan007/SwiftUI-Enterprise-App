## Deployment notes (VPS + Docker + Nginx)

### Symptom: iOS app can’t sign up / log in

If the app shows **“Authentication failed — Something went wrong”** and Nginx returns **`502 Bad Gateway`** for `POST /api/auth/login` or `POST /api/auth/register`, your reverse proxy is not forwarding `/api/*` to the Vapor container.

Quick checks (run on the VPS):

```bash
curl -i http://127.0.0.1:8080/health
curl -i http://127.0.0.1:8080/api/auth/login
curl -i https://enterpriseapp.chickenkiller.com/health
curl -i https://enterpriseapp.chickenkiller.com/api/auth/login
```

- If `:8080/health` works but `https://.../api/*` is `502`, fix Nginx.

### Nginx config

Use `Backend/deploy/nginx-enterpriseapp.conf` as a starting point.

Apply (example):

```bash
sudo cp Backend/deploy/nginx-enterpriseapp.conf /etc/nginx/sites-available/enterpriseapp.conf
sudo ln -sf /etc/nginx/sites-available/enterpriseapp.conf /etc/nginx/sites-enabled/enterpriseapp.conf
sudo nginx -t
sudo systemctl reload nginx
```

