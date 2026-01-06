# Simple Dockerfile to serve static site with nginx
FROM nginx:stable-alpine

# Remove default nginx config and html
RUN rm -rf /usr/share/nginx/html/* /etc/nginx/nginx.conf

# Copy custom nginx config
COPY nginx.conf /etc/nginx/nginx.conf

# Copy site files
COPY . /usr/share/nginx/html/

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
