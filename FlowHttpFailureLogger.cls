/**
 * Copyright (c) 2026 Oleg Konanykhin and Oksana Sokolova
 * Licensed under the MIT License.
 */
public with sharing class FlowHttpFailureLogger {
    private static final Integer MAX_LONG_TEXT_LENGTH = 100000;

    public static Callout_Log__c build(
        FlowHttpCalloutAction.Request request,
        FlowHttpCalloutService.CallResult result
    ) {
        if (result == null || result.success == true) {
            return null;
        }

        Callout_Log__c logEntry = new Callout_Log__c();
        logEntry.Configuration_Key__c = truncate(
            request == null ? null : request.configurationKey,
            255
        );
        logEntry.Endpoint__c = truncate(result.endpoint, MAX_LONG_TEXT_LENGTH);
        logEntry.Http_Method__c = truncate(result.method, 10);
        logEntry.Request_Body__c = truncate(
            request == null ? null : request.body,
            MAX_LONG_TEXT_LENGTH
        );
        logEntry.Response_Status_Code__c = result.statusCode;
        logEntry.Response_Body__c = truncate(result.responseBody, MAX_LONG_TEXT_LENGTH);
        logEntry.Error_Message__c = truncate(result.errorMessage, MAX_LONG_TEXT_LENGTH);
        logEntry.Correlation_Id__c = truncate(
            request == null ? null : request.correlationId,
            255
        );
        logEntry.Occurred_At__c = System.now();
        logEntry.Retry_Status__c = 'Pending';
        return logEntry;
    }

    public static void save(List<Callout_Log__c> logs) {
        if (logs != null && !logs.isEmpty()) {
            Database.insert(logs, false);
        }
    }

    private static String truncate(String value, Integer maxLength) {
        if (value == null || value.length() <= maxLength) {
            return value;
        }
        return value.left(maxLength);
    }
}

// Authors: Oleg Konanykhin, Oksana Sokolova
