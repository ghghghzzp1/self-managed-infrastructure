# ==========================================
# Service A Backend: Spring Boot
# ==========================================

# Stage 1: Build
FROM gradle:8.5-jdk17-alpine AS build
WORKDIR /app

COPY build.gradle settings.gradle ./
RUN gradle dependencies --no-daemon || true

COPY src/ ./src/
RUN gradle bootJar --no-daemon

# Stage 2: Production
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

COPY --from=build --chown=appuser:appgroup /app/build/libs/*.jar app.jar

USER appuser

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD wget -q --spider http://localhost:8080/actuator/health || exit 1

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
