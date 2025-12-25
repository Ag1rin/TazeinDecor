# Deployment Guide

This guide explains how to deploy the TazeinDecor API to production servers.

## 🚀 Quick Start

### For Heroku Deployment

1. **Install Heroku CLI** (if not already installed)
   ```bash
   # Windows (using Chocolatey)
   choco install heroku-cli
   
   # Or download from: https://devcenter.heroku.com/articles/heroku-cli
   ```

2. **Login to Heroku**
   ```bash
   heroku login
   ```

3. **Create a new Heroku app**
   ```bash
   cd backend
   heroku create your-app-name
   ```

4. **Set environment variables**
   ```bash
   heroku config:set ENVIRONMENT=production
   heroku config:set SECRET_KEY=your-super-secret-key-here
   heroku config:set DATABASE_URL=your-database-url
   heroku config:set WOOCOMMERCE_URL=https://tazeindecor.com
   heroku config:set WOOCOMMERCE_CONSUMER_KEY=your-key
   heroku config:set WOOCOMMERCE_CONSUMER_SECRET=your-secret
   ```

5. **Add PostgreSQL addon (if using PostgreSQL)**
   ```bash
   heroku addons:create heroku-postgresql:mini
   # This automatically sets DATABASE_URL
   ```

6. **Deploy**
   ```bash
   git push heroku main
   # Or if your branch is master:
   git push heroku master
   ```

7. **Check logs**
   ```bash
   heroku logs --tail
   ```

### For VPS/Cloud Server Deployment (Ubuntu/Debian)

1. **Update system and install dependencies**
   ```bash
   sudo apt update
   sudo apt install python3.12 python3.12-venv python3-pip nginx supervisor -y
   ```

2. **Clone your repository**
   ```bash
   cd /var/www
   sudo git clone <your-repo-url> tazeindecor-api
   cd tazeindecor-api/backend
   ```

3. **Create virtual environment**
   ```bash
   python3.12 -m venv venv
   source venv/bin/activate
   pip install --upgrade pip
   pip install -r requirements.txt
   ```

4. **Create environment file**
   ```bash
   sudo nano .env
   ```
   
   Add your configuration:
   ```
   ENVIRONMENT=production
   PORT=8000
   SECRET_KEY=your-super-secret-key-here
   DATABASE_URL=postgresql://user:password@localhost/dbname
   WOOCOMMERCE_URL=https://tazeindecor.com
   WOOCOMMERCE_CONSUMER_KEY=your-key
   WOOCOMMERCE_CONSUMER_SECRET=your-secret
   ```

5. **Create systemd service**
   ```bash
   sudo nano /etc/systemd/system/tazeindecor-api.service
   ```
   
   Add this content:
   ```ini
   [Unit]
   Description=TazeinDecor API
   After=network.target

   [Service]
   User=www-data
   Group=www-data
   WorkingDirectory=/var/www/tazeindecor-api/backend
   Environment="PATH=/var/www/tazeindecor-api/backend/venv/bin"
   Environment="ENVIRONMENT=production"
   ExecStart=/var/www/tazeindecor-api/backend/venv/bin/python main.py
   Restart=always

   [Install]
   WantedBy=multi-user.target
   ```

6. **Start and enable service**
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl start tazeindecor-api
   sudo systemctl enable tazeindecor-api
   sudo systemctl status tazeindecor-api
   ```

7. **Configure Nginx as reverse proxy**
   ```bash
   sudo nano /etc/nginx/sites-available/tazeindecor-api
   ```
   
   Add this configuration:
   ```nginx
   server {
       listen 80;
       server_name your-domain.com;

       location / {
           proxy_pass http://127.0.0.1:8000;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
       }
   }
   ```

8. **Enable site and restart Nginx**
   ```bash
   sudo ln -s /etc/nginx/sites-available/tazeindecor-api /etc/nginx/sites-enabled/
   sudo nginx -t
   sudo systemctl restart nginx
   ```

9. **Setup SSL with Let's Encrypt (recommended)**
   ```bash
   sudo apt install certbot python3-certbot-nginx -y
   sudo certbot --nginx -d your-domain.com
   ```

## 🔧 Configuration

### Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `ENVIRONMENT` | Set to `production` for production | No | `development` |
| `PORT` | Port to run the server on | No | `8000` |
| `DATABASE_URL` | Database connection string | Yes | `sqlite:///./tazeindecor.db` |
| `SECRET_KEY` | Secret key for JWT tokens | Yes | - |
| `WOOCOMMERCE_URL` | WooCommerce store URL | Yes | - |
| `WOOCOMMERCE_CONSUMER_KEY` | WooCommerce API key | Yes | - |
| `WOOCOMMERCE_CONSUMER_SECRET` | WooCommerce API secret | Yes | - |

### Production Checklist

- [ ] Set `ENVIRONMENT=production`
- [ ] Change `SECRET_KEY` to a strong random value
- [ ] Use PostgreSQL or MySQL instead of SQLite
- [ ] Configure proper CORS origins (not `*`)
- [ ] Setup SSL/HTTPS
- [ ] Configure database backups
- [ ] Setup monitoring and logging
- [ ] Configure firewall rules

## 🐳 Docker Deployment (Optional)

Create a `Dockerfile`:

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["python", "main.py"]
```

Build and run:
```bash
docker build -t tazeindecor-api .
docker run -d -p 8000:8000 --env-file .env tazeindecor-api
```

## 📝 Notes

- The server automatically detects production vs development based on `ENVIRONMENT` variable
- In production, auto-reload is disabled and multiple workers are used
- Port 8000 is the default, but Heroku will use the `PORT` environment variable
- Make sure to keep your `.env` file secure and never commit it to version control

