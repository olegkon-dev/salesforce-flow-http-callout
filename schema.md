# Required Salesforce objects

Create these two custom objects before deploying the Apex classes. API names and field types must match exactly.

## `Integration_Endpoint__c`

Runtime configuration object. Records can be edited directly in Salesforce without deploying Apex.

| Field | Type | Properties |
|---|---|---|
| `Name` | Text | Standard name field |
| `Unique_Key__c` | Text(255) | Required, Unique, External ID |
| `Active__c` | Checkbox | Default `false` |
| `Named_Credential__c` | Text(80) | Required |
| `Base_Path__c` | Text(255) | Optional |
| `Allowed_Methods__c` | Text(255) | Example: `GET,POST`; blank means all supported methods |
| `Timeout_Ms__c` | Number(6,0) | From 1 to 120000; blank means 120000 |

Example record:

| Field | Value |
|---|---|
| `Name` | Example External Service |
| `Unique_Key__c` | `Example_External_Service` |
| `Active__c` | `true` |
| `Named_Credential__c` | `Example_External_Service` |
| `Base_Path__c` | blank or the shared service prefix |
| `Allowed_Methods__c` | `GET,POST,PUT,PATCH,DELETE` |
| `Timeout_Ms__c` | `120000` |

## `Callout_Log__c`

Only failed calls are written. Request headers are deliberately not stored.

| Field | Type |
|---|---|
| `Name` | Auto Number, for example `CALL-{00000000}` |
| `Configuration_Key__c` | Text(255) |
| `Endpoint__c` | Long Text Area(131072) |
| `Http_Method__c` | Text(10) |
| `Request_Body__c` | Long Text Area(131072) |
| `Response_Status_Code__c` | Number(3,0) |
| `Response_Body__c` | Long Text Area(131072) |
| `Error_Message__c` | Long Text Area(131072) |
| `Correlation_Id__c` | Text(255) |
| `Occurred_At__c` | Date/Time |
| `Retry_Status__c` | Picklist: `Pending`, `Processing`, `Succeeded`, `Failed`, `Ignored` |

## Authors and license

Copyright (c) 2026 Oleg Konanykhin and Oksana Sokolova.

Licensed under the MIT License. See [LICENSE](LICENSE).
