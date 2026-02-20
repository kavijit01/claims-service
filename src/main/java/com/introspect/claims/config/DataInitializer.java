package com.introspect.claims.config;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.*;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Component
public class DataInitializer implements CommandLineRunner {

    private final DynamoDbClient dynamoDb;
    private final ObjectMapper objectMapper;

    @Value("${aws.dynamodb.tableName}")
    private String tableName;

    public DataInitializer(DynamoDbClient dynamoDb, ObjectMapper objectMapper) {
        this.dynamoDb = dynamoDb;
        this.objectMapper = objectMapper;
    }

    @Override
    public void run(String... args) throws Exception {
        System.out.println("🔄 Starting DynamoDB Data Reset...");

        // 1. Clear existing data (Scan then Batch Delete)
        ScanResponse scanResponse = dynamoDb.scan(ScanRequest.builder().tableName(tableName).build());
        if (!scanResponse.items().isEmpty()) {
            List<WriteRequest> deleteRequests = scanResponse.items().stream()
                    .map(item -> WriteRequest.builder()
                            .deleteRequest(DeleteRequest.builder()
                                    .key(Map.of("claimId", item.get("claimId"))) // Use your Partition Key name
                                    .build())
                            .build())
                    .collect(Collectors.toList());

            dynamoDb.batchWriteItem(BatchWriteItemRequest.builder()
                    .requestItems(Map.of(tableName, deleteRequests))
                    .build());
            System.out.println("🗑️ Existing data cleared.");
        }

        // 2. Load data from JSON file
        List<Map<String, Object>> claims = objectMapper.readValue(
                new ClassPathResource("mock/claims.json").getInputStream(),
                new TypeReference<>() {}
        );

        List<WriteRequest> putRequests = claims.stream()
                .map(claim -> WriteRequest.builder()
                        .putRequest(PutRequest.builder()
                                .item(convertToAttributeValueMap(claim))
                                .build())
                        .build())
                .collect(Collectors.toList());

        dynamoDb.batchWriteItem(BatchWriteItemRequest.builder()
                .requestItems(Map.of(tableName, putRequests))
                .build());

        System.out.println("✅ " + claims.size() + " claims successfully loaded from mock/claims.json");
    }

    private Map<String, AttributeValue> convertToAttributeValueMap(Map<String, Object> map) {
        return map.entrySet().stream().collect(Collectors.toMap(
                Map.Entry::getKey,
                e -> {
                    if (e.getValue() instanceof Number) return AttributeValue.builder().n(e.getValue().toString()).build();
                    return AttributeValue.builder().s(e.getValue().toString()).build();
                }
        ));
    }
}