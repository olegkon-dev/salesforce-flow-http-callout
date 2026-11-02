/**
 * Copyright (c) 2026 Oleg Konanykhin and Oksana Sokolova
 * Licensed under the MIT License.
 */
public with sharing class FlowHttpCalloutFuture {
    @future(callout=true)
    public static void submit(String serializedRequests) {
        List<FlowHttpCalloutAction.Request> requests =
            (List<FlowHttpCalloutAction.Request>) JSON.deserialize(
                serializedRequests,
                List<FlowHttpCalloutAction.Request>.class
            );

        List<Callout_Log__c> failureLogs = new List<Callout_Log__c>();
        for (FlowHttpCalloutAction.Request request : requests) {
            FlowHttpCalloutService.CallResult result = FlowHttpCalloutService.execute(
                FlowHttpCalloutAction.toCallSpec(request)
            );
            Callout_Log__c failureLog = FlowHttpFailureLogger.build(request, result);
            if (failureLog != null) {
                failureLogs.add(failureLog);
            }
        }

        FlowHttpFailureLogger.save(failureLogs);
    }
}

// Authors: Oleg Konanykhin, Oksana Sokolova
