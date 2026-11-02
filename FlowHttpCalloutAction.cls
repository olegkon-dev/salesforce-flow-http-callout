/**
 * Copyright (c) 2026 Oleg Konanykhin and Oksana Sokolova
 * Licensed under the MIT License.
 */
public with sharing class FlowHttpCalloutAction {
    public class Request {
        public Request() {
        }

        @InvocableVariable(required=true label='Endpoint configuration key')
        public String configurationKey;

        @InvocableVariable(label='Relative path')
        public String relativePath;

        @InvocableVariable(required=true label='HTTP method')
        public String method;

        @InvocableVariable(label='Headers JSON')
        public String headersJson;

        @InvocableVariable(label='Request body')
        public String body;

        @InvocableVariable(label='Run synchronously')
        public Boolean isSyncRun;

        @InvocableVariable(label='Correlation ID')
        public String correlationId;
    }

    public class Result {
        public Result() {
        }

        @InvocableVariable(label='Successful')
        public Boolean success;

        @InvocableVariable(label='Queued')
        public Boolean queued;

        @InvocableVariable(label='HTTP status code')
        public Integer statusCode;

        @InvocableVariable(label='Response body')
        public String responseBody;

        @InvocableVariable(label='Error message')
        public String errorMessage;

        @InvocableVariable(label='Correlation ID')
        public String correlationId;
    }

    @InvocableMethod(
        label='HTTP Callout'
        description='Calls a configured HTTP endpoint. A synchronous call returns the response; an asynchronous call is submitted for future execution.'
        category='Integrations'
    )
    public static List<Result> execute(List<Request> requests) {
        if (requests == null || requests.isEmpty()) {
            return new List<Result>();
        }

        List<Result> results = new List<Result>();
        List<Request> futureRequests = new List<Request>();
        List<Callout_Log__c> failureLogs = new List<Callout_Log__c>();

        for (Request request : requests) {
            if (request != null && request.isSyncRun == true) {
                FlowHttpCalloutService.CallResult callResult =
                    FlowHttpCalloutService.execute(toCallSpec(request));
                results.add(toFlowResult(request, callResult));

                Callout_Log__c failureLog = FlowHttpFailureLogger.build(request, callResult);
                if (failureLog != null) {
                    failureLogs.add(failureLog);
                }
            } else {
                futureRequests.add(request);
                results.add(queuedResult(request));
            }
        }

        if (!futureRequests.isEmpty()) {
            FlowHttpCalloutFuture.submit(JSON.serialize(futureRequests));
        }

        FlowHttpFailureLogger.save(failureLogs);
        return results;
    }

    public static FlowHttpCalloutService.CallSpec toCallSpec(Request request) {
        FlowHttpCalloutService.CallSpec spec = new FlowHttpCalloutService.CallSpec();
        if (request != null) {
            spec.configurationKey = request.configurationKey;
            spec.relativePath = request.relativePath;
            spec.method = request.method;
            spec.headersJson = request.headersJson;
            spec.body = request.body;
            spec.correlationId = request.correlationId;
        }
        return spec;
    }

    private static Result toFlowResult(
        Request request,
        FlowHttpCalloutService.CallResult callResult
    ) {
        Result result = new Result();
        result.success = callResult.success;
        result.queued = false;
        result.statusCode = callResult.statusCode;
        result.responseBody = callResult.responseBody;
        result.errorMessage = callResult.errorMessage;
        result.correlationId = request == null ? null : request.correlationId;
        return result;
    }

    private static Result queuedResult(Request request) {
        Result result = new Result();
        result.success = true;
        result.queued = true;
        result.correlationId = request == null ? null : request.correlationId;
        return result;
    }
}

// Authors: Oleg Konanykhin, Oksana Sokolova
