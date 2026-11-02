# Flow HTTP Callout Apex

This revision is intentionally small and Flow-oriented:

- no Queueable Apex;
- synchronous callout by default when `isSyncRun = true`;
- optional asynchronous execution through `@future(callout=true)`, matching the original code reference;
- runtime configuration in `Integration_Endpoint__c`, not Custom Metadata;
- request headers are accepted dynamically and never written to `Callout_Log__c`;
- no duplicate governor-limit checks;
- code is split into action, service, repository, future runner, and logger classes;
- no SFDX project structure.

## Classes

- `FlowHttpCalloutAction` — the single Apex Action visible in Flow.
- `FlowHttpCalloutService` — validation, request construction, and HTTP execution.
- `FlowHttpEndpointRepository` — reads active configuration records.
- `FlowHttpCalloutFuture` — minimal async adapter without Queueable.
- `FlowHttpFailureLogger` — stores failed calls, excluding headers.
- `FlowHttpCalloutActionTest` — tests the end-to-end behavior.

## Setup

1. Create the two objects described in `schema.md` through the team's normal CLI/deployment process.
2. Create an enhanced Named Credential for the external service, for example `Example_External_Service`.
3. Create an `Integration_Endpoint__c` record using the example in `schema.md`.
4. Deploy the six `.cls` files through the team's normal CLI process.
5. Grant Flow users access to the action class, configuration object, log object, and the External Credential principal.

## Flow contract

Inputs:

- `configurationKey` — `Integration_Endpoint__c.Unique_Key__c`.
- `relativePath` — appended to the configured base path.
- `method` — GET, POST, PUT, PATCH, or DELETE.
- `headersJson` — dynamic headers in the original reference format.
- `body` — raw request body; required for POST, PUT, and PATCH.
- `isSyncRun` — `true` returns the remote response; `false` submits a future call.
- `correlationId` — optional tracing key.

Example headers:

```json
{
  "headers": [
    { "key": "Content-Type", "value": "application/json" },
    { "key": "Authorization", "value": "Bearer token123" }
  ]
}
```

Headers can be changed without an Apex deployment. They are intentionally excluded from failure logs.

## Important Flow constraint

For a synchronous call, place the Apex Action before any Flow element that performs DML. Otherwise Salesforce can raise `You have uncommitted work pending`.

The component is not intended for use inside Flow loops. Prefer one request containing a collection when the external API supports bulk operations.

## Authors and license

Copyright (c) 2026 Oleg Konanykhin and Oksana Sokolova.

Licensed under the MIT License. See [LICENSE](LICENSE).
