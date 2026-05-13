## What:
<!-- A brief description of what this PR does -->

## Why:
<!-- The reasoning or context behind this change -->

## Ticket:
<!-- Link to the relevant Jira/ticket, or 'N/A' if not applicable -->

## Risk:

**Risk level:** 🟢 / 🟠 / 🔴 <!-- delete as appropriate -->

**Reason for rating:**
<!-- One or two sentences explaining your assessment, especially for Amber or Red -->

───────────────────────────────────────────────────

Rate the overall risk of deploying this change:

🟢 Green  – Low risk. Good to go, standard review applies.

🟠 Amber  – Medium risk. Socialise with the team before merging.

🔴 Red    – High risk. Requires explicit approval from Thor or Neil before merging.

───────────────────────────────────────────────────

🟢 GREEN – things that are typically low risk:
───────────────────────────────────────────────────

- New tests or improved test coverage with no production code changes
- Dependency bumps with no API changes (minor/patch gems)
- Copy changes to sign-in UI (labels, hint text, error messages) with no logic change
- Config/env var additions that are purely additive and have safe defaults
- Refactors with full test coverage and no behaviour change
- Adding or updating CloudWatch alarms or dashboards (read-only observability)
- Terraform formatting or variable renaming with no resource recreation
- Logging improvements or additional audit trail entries (additive only)

🟠 AMBER – things that need a team conversation first:
───────────────────────────────────────────────────

- Changes to session handling, cookie attributes, or token lifetimes
- Modifications to the sign-in or sign-out flow (redirects, callbacks, error paths)
- Changes to how user attributes or claims are mapped, stored, or forwarded to downstream services
- New or modified OAuth 2.0 / OIDC scopes, grant types, or client configurations
- Adding or changing feature flags that affect live authentication journeys
- Infrastructure changes that alter networking, security groups, or IAM permissions in non-production first
- Terraform changes that will cause a resource replacement (check plan output carefully)
- Changes to CI/CD pipeline steps or deployment order dependencies
- Removing or deprecating an endpoint or claim that may still be consumed by another service

🔴 RED – requires explicit approval from Thor or Neil:
───────────────────────────────────────────────────

- Any change to password hashing, token signing, or cryptographic primitives
- Modifications to MFA logic, step-up authentication, or account recovery flows
- Changes to how user accounts are created, merged, suspended, or deleted
- Changes to authorisation rules, role definitions, or permission scoping
- Secrets rotation or changes to how credentials, signing keys, or client secrets are stored or accessed
- Changes to production AWS infrastructure that cannot be easily rolled back (e.g. Cognito user pool settings, KMS key policy, removal of resources)
- Significant architectural shifts (e.g. new identity provider integrations, changes to the token issuance pipeline)
- Any change that could result in users being locked out of the service or losing access to their accounts
