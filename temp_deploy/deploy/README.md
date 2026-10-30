# WordRise WebSocket Deployment Guide

This directory contains the necessary configuration files to deploy the Ratchet PHP WebSocket server for WordRise.

## Requirements
- PHP 8.1+
- Composer
- Systemd (for running the background process)
- Nginx (for SSL termination and proxying WSS traffic)

## 1. Install Dependencies
Run composer install in the `backend_php` folder:
```bash
cd /var/www/wordrise/backend_php
composer install
```

## 2. Setup Systemd Service
Copy the service file to systemd and enable it:
```bash
sudo cp deploy/wordrise-websocket.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable wordrise-websocket
sudo systemctl start wordrise-websocket
```
You can check the logs using:
```bash
sudo journalctl -u wordrise-websocket -f
```

## 3. Configure Nginx
Add the `location /ws` block from `nginx-websocket.conf` to your existing domain's Nginx server block.
```nginx
server {
    server_name api.wordrise.uz;
    
    # ... existing configuration ...

    location /ws {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        # Optional timeouts for long-lived connections
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
}
```
Reload Nginx to apply changes:
```bash
sudo nginx -t
sudo systemctl reload nginx
```

## 4. How it works
1. **Flutter app** connects to `wss://api.wordrise.uz/ws` (which hits Nginx).
2. Nginx proxies to the **Ratchet Server** running on `127.0.0.1:8080`.
3. The Ratchet server also listens internally on `127.0.0.1:8081` for broadcast signals.
4. Your normal **PHP REST API endpoints** (e.g., `Message::send`) will use `ws_broadcast()` which opens a quick local connection to `8081` to pass data.
5. The Ratchet server receives this data and broadcasts it securely to connected authenticated clients.
