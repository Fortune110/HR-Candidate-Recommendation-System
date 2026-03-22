# ── Stage 1: build ───────────────────────────────────────────
FROM eclipse-temurin:21-jdk-jammy AS build
WORKDIR /app

# Copy Maven wrapper and pom first for layer-cache of dependencies
COPY mvnw mvnw
COPY .mvn .mvn
COPY pom.xml pom.xml
RUN chmod +x mvnw && ./mvnw dependency:go-offline -q

# Copy source and package (skip tests — integration tests need a live DB)
COPY src src
RUN ./mvnw package -DskipTests -q

# ── Stage 2: runtime ─────────────────────────────────────────
FROM eclipse-temurin:21-jre-jammy
WORKDIR /app

COPY --from=build /app/target/resume-blueprint-api-*.jar app.jar

EXPOSE 18080

HEALTHCHECK --interval=15s --timeout=5s --start-period=60s --retries=5 \
  CMD curl -sf http://localhost:18080/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
