# ==========================================
# Service A: Spring Boot + Dashboard UI
# Multi-stage build for integrated deployment
# ==========================================

# Stage 1: Build Frontend
FROM node:20-alpine AS frontend-build
WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm ci --only=production
COPY frontend/ ./
RUN npm run build

# Stage 2: Build Backend
FROM eclipse-temurin:17-jdk-alpine AS backend-build
WORKDIR /app
COPY backend/ ./
RUN chmod +x gradlew && ./gradlew bootJar --no-daemon

# Stage 3: Production Image
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Copy backend JAR
COPY --from=backend-build /app/build/libs/*.jar app.jar

# Copy frontend static files to Spring Boot static directory
COPY --from=frontend-build /app/frontend/dist /app/static

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD wget -q --spider http://localhost:8080/health || exit 1

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
