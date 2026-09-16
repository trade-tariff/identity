# Agent Instructions

## Start Here

Read `README.md` first.

This Ruby app provides an interface to AWS Cognito so users can authenticate. Consumer applications receive user details and access tokens for a limited time after authentication.

## Working Rules

- Keep scope tight and prefer simple changes.
- Verify generated or AI-suggested claims against source code and tests.
- Use `rg` for code search.
- Follow existing patterns in the repository.

## Pull request writing

Write all pull request titles and descriptions in ASD-STE100 Simplified Technical English.

- Write short sentences. Put one fact or one instruction in each sentence.
- Use the same word for the same thing. Do not use synonyms.
- Use active voice.
- Use simple present tense for facts. Use simple past tense for completed work.
- Use words that a general technical reader can understand. Keep product names and legal terms when they are necessary.
- Do not write long noun clusters.
- Do not write filler, marketing language, or vague claims.
- Follow the repository pull request template. Fill each required section with concrete facts.
- Write for the reviewer. Do not write a work diary.

## Pull requests and commits

- Follow `.github/pull_request_template.md`.
- Use conventional commits.
- Apply exactly one risk label: `low-risk`, `medium-risk`, or `high-risk`.
