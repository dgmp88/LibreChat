# Renew certbot 

1. Docker compose down 
2. sudo certbot renew
3. stop nginx - pain in the arse:
- sudo systemctl stop nginx
- sudo nginx -s quit
- sudo nginx -s stop
- sudo /etc/init.d/nginx stop
- sudo lsof -i :80


# Create a user 
docker exec -it LibreChat-API /bin/sh -c "cd .. && npm run create-user"
