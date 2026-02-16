package com.introspect.claims.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.bedrockruntime.BedrockRuntimeClient;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.s3.S3Client;

@Configuration
public class ClaimsConfig {

    // Define the region where your Bedrock and data services are hosted
    private final Region region = Region.US_EAST_1; 

    @Bean
    public DynamoDbClient dynamoDbClient() {
        return DynamoDbClient.builder()
                .region(region)
                .build();
    }

    @Bean
    public S3Client s3Client() {
        return S3Client.builder()
                .region(region)
                .build();
    }

    @Bean
    public BedrockRuntimeClient bedrockRuntimeClient() {
        return BedrockRuntimeClient.builder()
                .region(region)
                .build();
    }
}