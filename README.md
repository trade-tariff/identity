# Trade Tariff Identity

Identity provides passwordless sign-in for Trade Tariff applications through
AWS Cognito. It supplies user details and tokens to configured consumers,
including Admin, Dev Hub and MyOTT. It also exposes APIs for user management
and client credentials.

This is a Ruby on Rails application. It does not use an Active Record database;
Cognito holds the user identities. Consumer routes and callback URLs are defined
in [config/consumers.yml](config/consumers.yml).

## Run locally

Use Ruby at the version in [.ruby-version](.ruby-version) and Bundler:

```sh
bundle install
bin/dev
```

Development defaults are in [.env.development](.env.development). Put overrides
in `.env.development.local`, and keep secrets outside Git. Open
<http://localhost:3005/myott> for the MyOTT consumer. The consuming application
must also be running at its configured callback URL to complete the journey.

Rails development uses the local Cognito bypass by default in
[lib/trade_tariff_identity.rb](lib/trade_tariff_identity.rb). Set
`BYPASS_COGNITO=false` to verify Cognito tokens in development. For a local AWS
emulator, configure `AWS_ENDPOINT_URL_COGNITO_IDENTITY_PROVIDER` and
`COGNITO_JWKS_BASE_URL` (for example, `http://ministack:4566`). The signing-key
endpoint does not change the expected AWS token issuer or disable signature
verification. Development cookies remain unencrypted, as the consuming apps
expect. Never enable a development bypass to circumvent access controls in a
shared environment.

For an authorised Cognito integration environment, configure `AWS_REGION`,
`COGNITO_USER_POOL_ID`, `COGNITO_CLIENT_ID` and the required AWS credentials.
Temporary AWS credentials also need `AWS_SESSION_TOKEN`. Check consumer URLs,
cookie domains and encryption settings before testing a complete sign-in flow.
Outside development, consumers that decrypt Identity cookies must use the same
`ENCRYPTION_SECRET` as Identity. Share it through the approved secret mechanism.
Use disposable test identities, not production accounts.

## Check changes

```sh
bundle exec rspec
bundle exec rubocop
bundle exec brakeman
npm ci --ignore-scripts
RAILS_ENV=test bin/rails assets:precompile
npm test
```

See [CI configuration](.github/workflows/ci.yml) for the current checks.
Authentication and credential-management changes need security-focused review.
The JavaScript checks use Node.js 24 and jsdom. These are test dependencies only.

### Update GOV.UK Frontend

Use `bin/importmap pin govuk-frontend@VERSION`. The automated updater uses the
same command. The binstub selects the complete, versioned GOV.UK distribution.
Do not vendor `dist/govuk/all.mjs` alone: its relative imports need additional
files and prevent the application from loading when those files are absent.
The asset checks load the precompiled bundle and check its module dependencies.

The code-entry form starts as a standard text input so sign-in does not require
JavaScript. JavaScript enhances it into six boxes with paste and autofill support.
The no-JavaScript feature specs submit the real form with Cognito mocked. The
JavaScript tests cover the enhanced boxes and the precompiled module dependencies.

## Find your way around

- [Routes](config/routes.rb): consumer entry points and APIs.
- [Controllers](app/controllers/): sign-in, callback and API behaviour.
- [Services](app/services/): Cognito and token operations.
- [Passwordless flow diagram](docs/passwordless_login_flow.png): sign-in overview.
- [Deployment workflows](.github/workflows/): maintainer deployment configuration.

## Contribute

Read [CONTRIBUTING.md](CONTRIBUTING.md) for the fork workflow, checks and private
security reporting.

## Licence

The code and associated documentation use the [MIT licence](LICENCE.md), with
Crown copyright (HM Revenue & Customs). Dependencies retain their own licences.
