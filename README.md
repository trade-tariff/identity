# trade-tariff-identity

Ruby app providing interface to Cognito allowing users to be authenticated

## Getting started

### AWS Locally

Add the following env variables to an `.env.development.local` file:

```
AWS_PROFILE
COGNITO_USER_POOL_ID
COGNITO_CLIENT_ID
```

login to the aws profile with

``` sh
aws sso login --profile [profile name]
```


