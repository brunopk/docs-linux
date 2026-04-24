# NGINX configuration

To configure NGINX :

1. Go to **Configurations** of [NGINX Home Assistant SSL proxy](https://github.com/home-assistant/addons/tree/master/nginx_proxy) and under **Customize** put the following:
     ```yaml
     active: true
     default: nginx/default/*.conf
     servers: nginx/*.conf
     ```

     This will change NGINX to load configurations from `nginx/default/*.conf` instead of from `nginx_proxy_default*.conf` as default.
2. Create a file named `mis_gastos_backend.conf` into `/share/nginx/default/` with this content:
     ```
     location /server/mis-gastos/api/ {
       proxy_pass http://local-misgastos:8080/;
       proxy_set_header Host $host;
       proxy_redirect http:// https://;
       proxy_http_version 1.1;
       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
       proxy_set_header Upgrade $http_upgrade;
       proxy_set_header Connection $connection_upgrade;
       auth_basic "Administrator’s Area";
       auth_basic_user_file /share/nginx/.htpasswd;
     }
     ```
   
     For more information open `etc/nginx.conf` file within the [NGINX Home Assistant SSL proxy](https://github.com/home-assistant/addons/tree/master/nginx_proxy) Docker container to understand how this NGINX location is inserted into the proxy configuration
3. Create the `.htpasswd` into `/share/nginx/` :
     ```bash
     sudo htpasswd -c /etc/apache2/.htpasswd user1
     ```
     as described in [Restricting Access with HTTP Basic Authentication](https://docs.nginx.com/nginx/admin-guide/security-controls/configuring-http-basic-authentication/)

## Links 

- [Restricting Access with HTTP Basic Authentication](https://docs.nginx.com/nginx/admin-guide/security-controls/configuring-http-basic-authentication/)
