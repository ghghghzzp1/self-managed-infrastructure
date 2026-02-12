# ==========================================
# Service B Frontend: React + Vite → Nginx
# ==========================================

# ---------- build stage ----------
FROM node:20-alpine AS build

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

# ---------- runtime stage ----------
FROM nginx:alpine

RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

COPY nginx.conf /etc/nginx/nginx.conf
COPY --from=build /app/dist /usr/share/nginx/html

RUN chown -R appuser:appgroup /var/cache/nginx /var/log/nginx /usr/share/nginx/html && \
    touch /var/run/nginx.pid && chown appuser:appgroup /var/run/nginx.pid

USER appuser

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD wget -q --spider http://127.0.0.1:8080/health || exit 1

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
