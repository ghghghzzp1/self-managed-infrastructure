# ==========================================
# Service A Backend: Spring Boot
# ==========================================

# Stage 1: Build
FROM eclipse-temurin:17-jdk-alpine AS build
WORKDIR /app

COPY gradlew settings.gradle build.gradle ./
COPY gradle/ ./gradle/
RUN chmod +x gradlew && ./gradlew dependencies --no-daemon

COPY src/ ./src/
RUN ./gradlew bootJar --no-daemon

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
