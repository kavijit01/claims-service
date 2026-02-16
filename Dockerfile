FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY target/*.jar claims-service.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","claims-service.jar"]