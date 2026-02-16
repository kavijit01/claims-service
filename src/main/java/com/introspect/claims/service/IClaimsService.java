package com.introspect.claims.service;

import java.util.Map;

public interface IClaimsService {

    public String check();

    public Map<String, Object> getClaimFromDb(String claimId);

    public String processGenAISummary(String claimId);
}
