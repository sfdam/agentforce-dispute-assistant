# Agentforce Dispute Assistant

An Agentforce agent that helps bank operators handle **card payment disputes** (chargeback requests), from Salesforce or directly from **Slack**, delivered through a **GitHub Actions CI/CD pipeline**.

> Portfolio project: Apex + Agentforce + Slack + CI/CD on a realistic payments use case.

## What it does

An operator asks the agent things like:

- *"Show me the last transactions of Rossi Alimentari"*
- *"Open a dispute on TX-000012, the customer says it's a duplicate charge"*
- *"What's the status of DSP-000003?"*

The agent calls three Apex actions, which apply the business rules:

| Action | Apex class | What it does |
| --- | --- | --- |
| Get Recent Transactions | `GetRecentTransactionsAction` | Finds the customer by Id or name (handles ambiguous names) and returns the latest transactions |
| Open Dispute | `OpenDisputeAction` → `DisputeService` | Validates and opens the dispute |
| Get Dispute Status | `GetDisputeStatusAction` | Looks a dispute up by dispute number or transaction number |

Business rules enforced in `DisputeService` (not in the prompt, so the LLM can't skip them):

- only **Settled** or **Authorized** transactions can be disputed
- the transaction must be inside the **dispute window** (default 120 days)
- **one open dispute** per transaction
- the reason must be a valid picklist value (matched case-insensitively on value or label)
- disputes above the **high value threshold** (default 1,000) are flagged and **posted to a Slack channel**

Thresholds and switches live in Custom Metadata (`Dispute_Setting__mdt.Default`), so they change through a pull request, not a code change.

## Architecture

```
Slack / Lightning ──> Agentforce agent (topic: Card Disputes)
                         │
                         ├─ GetRecentTransactionsAction ─┐
                         ├─ OpenDisputeAction ───────────┼─> DisputeService ─> Selectors (USER_MODE SOQL)
                         └─ GetDisputeStatusAction ──────┘        │
                                                                  └─ high value ─> SlackDisputeNotifier (Queueable)
                                                                                     └─> Named Credential ─> Slack Incoming Webhook
```

Design choices worth noting:

- **Invocable actions are thin adapters**: all the rules sit in `DisputeService`, which can be reused by Flow, LWC or an API.
- **Bulkified service**: constant number of queries whatever the number of requests, partial success with a readable message per request (tested with 200 records).
- **Security**: SOQL and DML run in `USER_MODE`, so the agent can never see or change more than its running user. The Slack webhook URL is a secret and stays in a Named Credential in the org, never in Git.
- **Async callout**: Slack is called from a Queueable, so a Slack outage never blocks dispute creation; `Slack_Notified__c` records the outcome.
- **Messages written for the agent**: every action returns a `message` the agent can read back to the user, including why a request was refused.

## Data model

- `Payment_Transaction__c` (TX-000000): Account, amount, date, merchant, status, channel, last 4 digits of the card, external id from the processor.
- `Dispute__c` (DSP-000000): transaction, account, amount, reason, status, channel, high value flag, Slack notified flag.
- `Dispute_Setting__mdt`: threshold, window days, Slack switch.
- Permission set `Dispute_Assistant_User`: for operators and for the agent user.

## CI/CD

| When | Workflow | Steps |
| --- | --- | --- |
| Pull request to `main` | `pr-validation.yml` | Prettier check → Salesforce Code Analyzer (fails on high severity, HTML report as artifact) → check-only deploy with `RunLocalTests` → coverage gate at 85% |
| Merge to `main` | `deploy-main.yml` | Deploy with `RunLocalTests` |

Branch protection on `main` requires the PR validation to be green.

## Setup

### 1. Org

Use a Developer Edition org with Agentforce enabled (for example a free *Agentforce Developer Edition* org).

```bash
npm install
sf org login web --alias dispute-dev
sf project deploy start --source-dir force-app --target-org dispute-dev --test-level RunLocalTests
sf org assign permset --name Dispute_Assistant_User --target-org dispute-dev
sf apex run --file scripts/apex/seed-data.apex --target-org dispute-dev
```

### 2. Agent

Create the agent in Agent Builder following [docs/agent-setup.md](docs/agent-setup.md), then retrieve its metadata into the repo so it is versioned and deployed by the pipeline too.

### 3. Slack notifications

1. In Slack, create an app with an **Incoming Webhook** on the disputes channel and copy the webhook URL.
2. In Setup create an **External Credential** `Slack_Webhook` with protocol *No Authentication* and a principal.
3. Create a **Named Credential** `Slack_Dispute_Webhook` with the full webhook URL, linked to that external credential, with *Generate Authorization Header* turned off.
4. Create a permission set (for example `Slack_Webhook_Callout`) that grants the external credential principal, and assign it to operators and to the agent user. It's kept outside the repo on purpose, because it depends on the secret configured in each org.
5. Set `Slack_Notifications_Enabled__c = true` in `Dispute_Setting.Default.md-meta.xml` and ship it through a PR.

### 4. Agent in Slack

In Setup, connect the org to the Slack workspace (Agentforce in Slack) and make the agent available there, so operators can talk to it from Slack.

### 5. GitHub Actions

```bash
sf org display --target-org dispute-dev --verbose --json   # copy "sfdxAuthUrl"
```

- Add it as the repository secret `SFDX_AUTH_URL`.
- Protect `main`: require a pull request and the *PR validation* checks.

## Roadmap

- [ ] Delta deploys with `sfdx-git-delta` (deploy only what changed in the PR)
- [ ] Scratch org per PR, with a Dev Hub
- [ ] Knowledge articles on dispute policy, used by the agent for answers (RAG)
- [ ] Agent tests (`sf agent test`) in the pipeline
- [ ] LWC timeline of a dispute on the Account page
- [ ] Inbound integration: transactions upserted by `External_Id__c` from a processor API
