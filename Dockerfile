FROM eclipse-temurin:17-jre-alpine

# 1. Add a non-root user for security
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring

WORKDIR /app

# 2. Copy the jar with correct ownership
COPY --chown=spring:spring target/claims-service.jar app.jar

EXPOSE 8080

# 3. Use an array for ENTRYPOINT (standard practice)
ENTRYPOINT ["java", "-jar", "app.jar"]