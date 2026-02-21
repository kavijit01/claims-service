package com.introspect.claims.service;

import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.core.SdkBytes;
import software.amazon.awssdk.services.bedrockruntime.BedrockRuntimeClient;
import software.amazon.awssdk.services.bedrockruntime.model.InvokeModelRequest;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.GetItemRequest;
import software.amazon.awssdk.services.s3.S3Client;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class ClaimsService implements IClaimsService{

    private final DynamoDbClient dynamoDb;
    private final S3Client s3Client;
    private final BedrockRuntimeClient bedrockClient;

    @Value("${aws.dynamodb.tableName}")
    private String tableName;

    @Value("${aws.s3.bucketName}")
    private String bucketName;

    public ClaimsService(DynamoDbClient dynamoDb, S3Client s3Client, BedrockRuntimeClient bedrockClient) {
        this.dynamoDb = dynamoDb;
        this.s3Client = s3Client;
        this.bedrockClient = bedrockClient;
    }

    @Override
    public String check() {
        return "Hello from Claims Service";
    }

    @Override
    public Map<String, Object> getClaimFromDb(String claimId) {
        GetItemRequest request = GetItemRequest.builder()
                .tableName(tableName)
                .key(Map.of("claimId", AttributeValue.builder().s(claimId).build()))
                .build();

        Map<String, AttributeValue> item = dynamoDb.getItem(request).item();

        if (item == null || item.isEmpty()) {
            return Collections.emptyMap();
        }

        return item.entrySet().stream()
                .collect(HashMap::new, (m, v) -> {
                    // Safely handle values: if s() is null, use a placeholder or skip
                    AttributeValue val = v.getValue();
                    //String val = v.getValue().s();
                    m.put(v.getKey(), val.s() != null ? val.s() : val.n() != null ? val.n() : "");
                }, Map::putAll);
    }

    @Override
    public String processGenAISummary(String claimId) {
        // 1. Fetch Notes from S3
        String notes = s3Client.getObjectAsBytes(r -> r.bucket(bucketName).key(claimId + ".txt"))
                .asUtf8String();

        // 2. Construct Prompt for Claude 3 (Bedrock)
        String prompt = String.format("""
            Human: Analyze these insurance claim notes: %s
            Generate a JSON response with:
            - overall_summary
            - customer_facing_summary (empathetic tone)
            - adjuster_focused_summary (technical)
            - recommended_next_step
            Assistant:""", notes);

        // 3. Invoke Bedrock
        JSONObject payload = new JSONObject()
                .put("anthropic_version", "bedrock-2023-05-31")
                .put("max_tokens", 1024)
                .put("temperature",0.5)
                .put("messages", new JSONArray().put(new JSONObject().put("role", "user").put("content", prompt)));

        InvokeModelRequest request = InvokeModelRequest.builder()
                .modelId("us.anthropic.claude-sonnet-4-20250514-v1:0")
                //.contentType("application/json")
                .body(SdkBytes.fromUtf8String(payload.toString()))
                .build();

        return bedrockClient.invokeModel(request).body().asUtf8String();
    }
}
