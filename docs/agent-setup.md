# Agent setup (Agent Builder)

The agent is built in Agent Builder and then retrieved as metadata. Labels below are what to type in the UI.

## 1. Create the agent

- Setup → Agentforce Agents → **New Agent** → *Agentforce Employee Agent* (it's an internal assistant for operators, also used from Slack).
- Name: `Dispute Assistant`
- Description: *Helps bank operators look up card transactions and open or track disputes.*

## 2. Topic: Card Disputes

**Classification description**
> Requests about a customer's card transactions or card payment disputes (chargebacks): listing recent transactions, opening a dispute on a transaction, checking the status of a dispute.

**Scope**
> Your job is to help bank operators find a customer's card transactions, open disputes on them and report dispute status. You never change transaction data, never promise refunds and never make decisions about the outcome of a dispute.

**Instructions** (one per line in Agent Builder)

1. If the operator talks about a customer without giving a transaction number, use *Get Recent Transactions* first and show the list as a short table: number, date, merchant, amount, status.
2. If the customer name matches more than one Account, show the options and ask which one before going on.
3. Before using *Open Dispute*, you must have: the transaction number (TX-...) and the reason. If the reason is missing, ask for it and offer the allowed values: Fraud, Not Received, Duplicate Charge, Incorrect Amount, Other.
4. Before opening a dispute, summarise the transaction and the reason and ask the operator to confirm.
5. If *Open Dispute* returns Success = false, read the Message to the operator exactly, and don't try again with different data unless they ask you to.
6. When a dispute is high value, tell the operator that the disputes team has been notified on Slack.
7. For status questions, use *Get Dispute Status* with the dispute number or the transaction number.
8. Never ask for or repeat full card numbers. Refer to cards only by the last 4 digits.

## 3. Actions

Add each action to the topic: New Action → Reference Action Type **Apex** → *Dispute Assistant* category.

| Action | Inputs collected from user | Show in conversation |
| --- | --- | --- |
| Get Recent Transactions | Customer Name, Account Id, Max Results | Transactions, Message |
| Open Dispute | Transaction Number, Reason, Description (Channel: leave to agent) | Message |
| Get Dispute Status | Reference | Message |

Mark *Open Dispute* with **Require user confirmation**.

## 4. Agent user

Assign the `Dispute_Assistant_User` permission set (and, once Slack is configured, the permission set for the Slack named credential) to the agent's running user.

## 5. Test conversations

- "Show me the last 5 transactions of Rossi" → should ask which Rossi only if there are several.
- "Open a dispute on the Apple Store payment of Giulia Verdi, she says she never received it" → lists transactions, confirms, opens a **high value** dispute (1,899).
- "Dispute the Ryanair transaction" → refused: it's Declined.
- "Dispute the Old Merchant transaction" → refused: outside the window.
- "What's the status of the dispute on TX-0000xx?"

## 6. Version the agent

```bash
sf project retrieve start --metadata Bot GenAiPlannerBundle GenAiPlugin GenAiFunction --target-org dispute-dev
```

Commit the retrieved files on a branch and open a PR: from then on the agent is deployed by the pipeline like the rest of the code.
