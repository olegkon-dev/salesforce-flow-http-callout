/**
 * Copyright (c) 2026 Oleg Konanykhin and Oksana Sokolova
 * Licensed under the MIT License.
 */
public with sharing class FlowHttpEndpointRepository {
    private static final Set<String> SUPPORTED_METHODS = new Set<String>{
        'GET', 'POST', 'PUT', 'PATCH', 'DELETE'
    };

    public class EndpointConfig {
        public String key;
        public String namedCredential;
        public String basePath;
        public Set<String> allowedMethods;
        public Integer timeoutMs;
    }

    public static EndpointConfig getActive(String configurationKey) {
        String normalizedKey = configurationKey == null ? null : configurationKey.trim();
        List<Integration_Endpoint__c> records = [
            SELECT Unique_Key__c, Named_Credential__c, Base_Path__c,
                   Allowed_Methods__c, Timeout_Ms__c
            FROM Integration_Endpoint__c
            WHERE Unique_Key__c = :normalizedKey
              AND Active__c = true
            LIMIT 1
        ];

        if (records.isEmpty()) {
            throw new CalloutException(
                'Endpoint configuration is missing or inactive: ' + normalizedKey
            );
        }

        Integration_Endpoint__c record = records[0];
        if (String.isBlank(record.Named_Credential__c)) {
            throw new CalloutException(
                'Named Credential is not configured for: ' + normalizedKey
            );
        }
        if (!Pattern.matches('^[A-Za-z][A-Za-z0-9_]*$', record.Named_Credential__c)) {
            throw new CalloutException(
                'Named Credential API name is invalid for: ' + normalizedKey
            );
        }

        EndpointConfig config = new EndpointConfig();
        config.key = record.Unique_Key__c;
        config.namedCredential = record.Named_Credential__c.trim();
        config.basePath = record.Base_Path__c;
        config.allowedMethods = parseAllowedMethods(record.Allowed_Methods__c);
        config.timeoutMs = record.Timeout_Ms__c == null
            ? 120000
            : record.Timeout_Ms__c.intValue();

        if (config.timeoutMs < 1 || config.timeoutMs > 120000) {
            throw new CalloutException(
                'Timeout must be between 1 and 120000 ms for: ' + normalizedKey
            );
        }

        return config;
    }

    private static Set<String> parseAllowedMethods(String value) {
        if (String.isBlank(value)) {
            return SUPPORTED_METHODS.clone();
        }

        Set<String> methods = new Set<String>();
        for (String token : value.split('[,;\\s]+')) {
            if (String.isNotBlank(token)) {
                String method = token.trim().toUpperCase();
                if (!SUPPORTED_METHODS.contains(method)) {
                    throw new CalloutException(
                        'Unsupported method in endpoint configuration: ' + method
                    );
                }
                methods.add(method);
            }
        }
        return methods;
    }
}

// Authors: Oleg Konanykhin, Oksana Sokolova
