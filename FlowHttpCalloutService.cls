/**
 * Copyright (c) 2026 Oleg Konanykhin and Oksana Sokolova
 * Licensed under the MIT License.
 */
public with sharing class FlowHttpCalloutService {
    private static final Set<String> SUPPORTED_METHODS = new Set<String>{
        'GET', 'POST', 'PUT', 'PATCH', 'DELETE'
    };
    private static final Set<String> METHODS_REQUIRING_BODY = new Set<String>{
        'POST', 'PUT', 'PATCH'
    };
    private static final Integer MAX_RESULT_LENGTH = 100000;

    public class CallSpec {
        public String configurationKey;
        public String relativePath;
        public String method;
        public String headersJson;
        public String body;
        public String correlationId;
    }

    public class CallResult {
        public Boolean success = false;
        public Integer statusCode;
        public String responseBody;
        public String errorMessage;
        public String endpoint;
        public String method;
    }

    public static CallResult execute(CallSpec spec) {
        CallResult result = new CallResult();

        try {
            validateSpec(spec);
            FlowHttpEndpointRepository.EndpointConfig config =
                FlowHttpEndpointRepository.getActive(spec.configurationKey);

            String method = spec.method.trim().toUpperCase();
            validateMethod(config, method, spec.body);

            result.method = method;
            result.endpoint = buildEndpoint(config, spec.relativePath);

            HttpRequest request = new HttpRequest();
            request.setEndpoint(result.endpoint);
            request.setMethod(method);
            request.setTimeout(config.timeoutMs);
            applyHeaders(request, spec.headersJson);

            if (String.isNotBlank(spec.body)) {
                request.setBody(spec.body);
            }

            HttpResponse response = new Http().send(request);
            result.statusCode = response.getStatusCode();
            result.responseBody = truncate(response.getBody());
            result.success = response.getStatusCode() >= 200 && response.getStatusCode() < 300;

            if (!result.success) {
                result.errorMessage = 'Remote service returned HTTP ' + response.getStatusCode();
            }
        } catch (Exception error) {
            result.success = false;
            result.errorMessage = truncate(error.getTypeName() + ': ' + error.getMessage());
        }

        return result;
    }

    private static void validateSpec(CallSpec spec) {
        if (spec == null) {
            throw new CalloutException('Request is required.');
        }
        if (String.isBlank(spec.configurationKey)) {
            throw new CalloutException('Endpoint configuration key is required.');
        }
        if (String.isBlank(spec.method)) {
            throw new CalloutException('HTTP method is required.');
        }
        if (String.isNotBlank(spec.relativePath)) {
            String path = spec.relativePath.trim();
            if (path.contains('://') || path.startsWith('//') || path.contains('\r') || path.contains('\n')) {
                throw new CalloutException('Relative path must not contain a scheme, host, or line break.');
            }
        }
    }

    private static void validateMethod(
        FlowHttpEndpointRepository.EndpointConfig config,
        String method,
        String body
    ) {
        if (!SUPPORTED_METHODS.contains(method)) {
            throw new CalloutException('Unsupported HTTP method: ' + method);
        }
        if (!config.allowedMethods.contains(method)) {
            throw new CalloutException(
                'HTTP method ' + method + ' is not allowed by configuration ' + config.key
            );
        }
        if (METHODS_REQUIRING_BODY.contains(method) && String.isBlank(body)) {
            throw new CalloutException('Request body is required for ' + method + '.');
        }
    }

    private static String buildEndpoint(
        FlowHttpEndpointRepository.EndpointConfig config,
        String relativePath
    ) {
        return 'callout:' + config.namedCredential + joinPaths(
            normalizePath(config.basePath),
            normalizePath(relativePath)
        );
    }

    private static String normalizePath(String value) {
        if (String.isBlank(value)) {
            return '';
        }
        String path = value.trim();
        return path.startsWith('/') ? path : '/' + path;
    }

    private static String joinPaths(String left, String right) {
        if (String.isBlank(left)) {
            return String.isBlank(right) ? '' : right;
        }
        if (String.isBlank(right)) {
            return left;
        }
        return left.endsWith('/') ? left.left(left.length() - 1) + right : left + right;
    }

    private static void applyHeaders(HttpRequest request, String headersJson) {
        if (String.isBlank(headersJson)) {
            return;
        }

        Object parsed = JSON.deserializeUntyped(headersJson);
        if (!(parsed instanceof Map<String, Object>)) {
            throw new CalloutException('Headers JSON must be an object with a headers array.');
        }

        Map<String, Object> root = (Map<String, Object>) parsed;
        Object rawHeaders = root.get('headers');
        if (rawHeaders == null) {
            return;
        }
        if (!(rawHeaders instanceof List<Object>)) {
            throw new CalloutException('The headers property must be an array.');
        }

        for (Object rawHeader : (List<Object>) rawHeaders) {
            if (!(rawHeader instanceof Map<String, Object>)) {
                throw new CalloutException('Each header must be an object.');
            }

            Map<String, Object> header = (Map<String, Object>) rawHeader;
            String key = header.get('key') == null ? null : String.valueOf(header.get('key')).trim();
            String value = header.get('value') == null ? '' : String.valueOf(header.get('value'));

            if (String.isBlank(key)) {
                throw new CalloutException('Header name is required.');
            }
            if (key.contains('\r') || key.contains('\n') || value.contains('\r') || value.contains('\n')) {
                throw new CalloutException('Header names and values must not contain line breaks.');
            }

            request.setHeader(key, value);
        }
    }

    private static String truncate(String value) {
        if (value == null || value.length() <= MAX_RESULT_LENGTH) {
            return value;
        }
        return value.left(MAX_RESULT_LENGTH);
    }
}

// Authors: Oleg Konanykhin, Oksana Sokolova
