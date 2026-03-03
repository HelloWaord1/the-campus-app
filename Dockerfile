# Stage 1: Build Flutter web
FROM ghcr.io/cirruslabs/flutter:3.32.0 AS build

WORKDIR /app
COPY . .

RUN flutter pub get
RUN flutter build web --release

# Stage 2: Serve with nginx
FROM nginx:alpine

COPY --from=build /app/build/web /usr/share/nginx/html

# nginx config for SPA routing
RUN echo 'server { \
    listen 80; \
    server_name _; \
    root /usr/share/nginx/html; \
    index index.html; \
    location / { \
        try_files $uri $uri/ /index.html; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
