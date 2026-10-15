# WSO2 API Platform demos

Hands-on, scripted demos for the WSO2 API Platform: the Platform API, the API Gateway and the API Portal.
Each scenario lives in its own folder with a README, the JSON/YAML artifacts it uses, and the scripts that run it.

## Scenarios

| Scenario | What it shows |
|---|---|
| [Scenario-01-Basic-Flow](Scenario-01-Basic-Flow) | The complete flow on one machine with Docker Compose. Set up the API Portal (with the Platform API) and the API Gateway, register and start the gateway, create and deploy an API protected by the `api-key-auth` and `subscription-validation` policies, publish it in the API Portal with the gateway URL as its server URL, subscribe, create an API key, and invoke the API. A call succeeds only when both the API key and the subscription token are valid. |

More scenarios will be added over time, each as its own `Scenario-NN-...` folder.
