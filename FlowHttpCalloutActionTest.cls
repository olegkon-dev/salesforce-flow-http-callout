/**
 * Copyright (c) 2026 Oleg Konanykhin and Oksana Sokolova
 * Licensed under the MIT License.
 */
@IsTest
private class FlowHttpCalloutActionTest {
    private class RecordingMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;

        RecordingMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest request) {
            System.assertEquals(
                'callout:Example_External_Service/api/items/42',
                request.getEndpoint()
            );
            System.assertEquals('POST', request.getMethod());
            System.assertEquals('application/json', request.getHeader('Content-Type'));
            System.assertEquals('Bearer configurable-token', request.getHeader('Authorization'));
            System.assertEquals('{"name":"Test","value":123}', request.getBody());

            HttpResponse response = new HttpResponse();
            response.setStatusCode(statusCode);
            response.setBody(responseBody);
            return response;
        }
    }

    @TestSetup
    static void setupConfiguration() {
        insert new Integration_Endpoint__c(
            Name = 'Example External Service',
            Unique_Key__c = 'Example_External_Service',
            Active__c = true,
            Named_Credential__c = 'Example_External_Service',
            Base_Path__c = '/api',
            Allowed_Methods__c = 'GET,POST,PUT,PATCH,DELETE',
            Timeout_Ms__c = 120000
        );
    }

    private static FlowHttpCalloutAction.Request request(Boolean synchronous) {
        FlowHttpCalloutAction.Request request = new FlowHttpCalloutAction.Request();
        request.configurationKey = 'Example_External_Service';
        request.relativePath = '/items/42';
        request.method = 'POST';
        request.headersJson =
            '{"headers":[' +
            '{"key":"Content-Type","value":"application/json"},' +
            '{"key":"Authorization","value":"Bearer configurable-token"}' +
            ']}';
        request.body = '{"name":"Test","value":123}';
        request.isSyncRun = synchronous;
        request.correlationId = 'test-correlation-id';
        return request;
    }

    @IsTest
    static void synchronousSuccessReturnsResponse() {
        Test.setMock(HttpCalloutMock.class, new RecordingMock(200, '{"status":"ok"}'));

        Test.startTest();
        List<FlowHttpCalloutAction.Result> results = FlowHttpCalloutAction.execute(
            new List<FlowHttpCalloutAction.Request>{ request(true) }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].success);
        System.assertEquals(false, results[0].queued);
        System.assertEquals(200, results[0].statusCode);
        System.assertEquals('{"status":"ok"}', results[0].responseBody);
        System.assertEquals(0, [SELECT COUNT() FROM Callout_Log__c]);
    }

    @IsTest
    static void asynchronousRequestRunsInFutureContext() {
        Test.setMock(HttpCalloutMock.class, new RecordingMock(200, '{"status":"ok"}'));

        Test.startTest();
        List<FlowHttpCalloutAction.Result> results = FlowHttpCalloutAction.execute(
            new List<FlowHttpCalloutAction.Request>{ request(false) }
        );
        System.assertEquals(true, results[0].success);
        System.assertEquals(true, results[0].queued);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Callout_Log__c]);
    }

    @IsTest
    static void failedResponseIsLoggedWithoutHeaders() {
        Test.setMock(HttpCalloutMock.class, new RecordingMock(503, 'Unavailable'));

        Test.startTest();
        List<FlowHttpCalloutAction.Result> results = FlowHttpCalloutAction.execute(
            new List<FlowHttpCalloutAction.Request>{ request(true) }
        );
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assertEquals(503, results[0].statusCode);

        Callout_Log__c logEntry = [
            SELECT Configuration_Key__c, Endpoint__c, Http_Method__c,
                   Request_Body__c, Response_Status_Code__c, Response_Body__c,
                   Error_Message__c, Correlation_Id__c, Retry_Status__c
            FROM Callout_Log__c
            LIMIT 1
        ];
        System.assertEquals('Example_External_Service', logEntry.Configuration_Key__c);
        System.assertEquals('POST', logEntry.Http_Method__c);
        System.assertEquals(503, logEntry.Response_Status_Code__c);
        System.assertEquals('test-correlation-id', logEntry.Correlation_Id__c);
        System.assertEquals('Pending', logEntry.Retry_Status__c);
    }

    @IsTest
    static void invalidMethodDoesNotCallOut() {
        FlowHttpCalloutAction.Request invalidRequest = request(true);
        invalidRequest.method = 'HEAD';

        Test.startTest();
        List<FlowHttpCalloutAction.Result> results = FlowHttpCalloutAction.execute(
            new List<FlowHttpCalloutAction.Request>{ invalidRequest }
        );
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].errorMessage.contains('Unsupported HTTP method'));
        System.assertEquals(1, [SELECT COUNT() FROM Callout_Log__c]);
    }

    @IsTest
    static void missingBodyIsRejected() {
        FlowHttpCalloutAction.Request invalidRequest = request(true);
        invalidRequest.body = null;

        Test.startTest();
        List<FlowHttpCalloutAction.Result> results = FlowHttpCalloutAction.execute(
            new List<FlowHttpCalloutAction.Request>{ invalidRequest }
        );
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].errorMessage.contains('Request body is required'));
    }
}

// Authors: Oleg Konanykhin, Oksana Sokolova
