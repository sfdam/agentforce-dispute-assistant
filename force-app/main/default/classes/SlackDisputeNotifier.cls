/**
 * Posts high-value disputes to a Slack channel through an Incoming Webhook.
 * The webhook URL is a secret: it lives in the Named Credential
 * "Slack_Dispute_Webhook" in the org, never in the repository.
 */
public with sharing class SlackDisputeNotifier implements Queueable, Database.AllowsCallouts {
  public static final String NAMED_CREDENTIAL = 'callout:Slack_Dispute_Webhook';
  @TestVisible
  private static final Integer MAX_CALLOUTS = 50;

  private final Set<Id> disputeIds;

  public SlackDisputeNotifier(Set<Id> disputeIds) {
    this.disputeIds = disputeIds;
  }

  public void execute(QueueableContext context) {
    List<Dispute__c> notified = new List<Dispute__c>();
    Integer callouts = 0;
    for (Dispute__c dispute : new DisputeSelector().selectByIds(disputeIds)) {
      if (callouts >= MAX_CALLOUTS) {
        break;
      }
      callouts++;
      if (post(buildMessage(dispute))) {
        notified.add(new Dispute__c(Id = dispute.Id, Slack_Notified__c = true));
      }
    }
    if (!notified.isEmpty()) {
      // Technical flag, not editable by users: system mode on purpose.
      Database.update(notified, false, AccessLevel.SYSTEM_MODE);
    }
  }

  private Boolean post(String body) {
    HttpRequest request = new HttpRequest();
    request.setEndpoint(NAMED_CREDENTIAL);
    request.setMethod('POST');
    request.setHeader('Content-Type', 'application/json');
    request.setTimeout(10000);
    request.setBody(body);
    try {
      HttpResponse response = new Http().send(request);
      if (response.getStatusCode() == 200) {
        return true;
      }
      System.debug(LoggingLevel.ERROR, 'Slack webhook error ' + response.getStatusCode() + ': ' + response.getBody());
    } catch (CalloutException e) {
      System.debug(LoggingLevel.ERROR, 'Slack callout failed: ' + e.getMessage());
    }
    return false;
  }

  /** Slack Block Kit payload. "text" is the fallback used in notifications. */
  @TestVisible
  private static String buildMessage(Dispute__c dispute) {
    String recordUrl = Url.getOrgDomainUrl().toExternalForm() + '/' + dispute.Id;
    String amount = dispute.Amount__c == null ? '-' : dispute.Amount__c.setScale(2).format();
    String summary = ':rotating_light: High value dispute ' + dispute.Name + ' (' + amount + ')';

    String details =
      '*Customer:* ' +
      valueOrDash(dispute.Account__r?.Name) +
      '\n*Transaction:* ' +
      valueOrDash(dispute.Payment_Transaction__r?.Name) +
      ' - ' +
      valueOrDash(dispute.Payment_Transaction__r?.Merchant_Name__c) +
      '\n*Reason:* ' +
      valueOrDash(dispute.Reason__c) +
      '\n*Opened via:* ' +
      valueOrDash(dispute.Channel__c);

    Map<String, Object> header = new Map<String, Object>{
      'type' => 'header',
      'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => summary }
    };
    Map<String, Object> section = new Map<String, Object>{
      'type' => 'section',
      'text' => new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => details }
    };
    Map<String, Object> actions = new Map<String, Object>{
      'type' => 'actions',
      'elements' => new List<Object>{
        new Map<String, Object>{
          'type' => 'button',
          'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => 'Open in Salesforce' },
          'url' => recordUrl
        }
      }
    };
    return JSON.serialize(
      new Map<String, Object>{ 'text' => summary, 'blocks' => new List<Object>{ header, section, actions } }
    );
  }

  private static String valueOrDash(String value) {
    return String.isBlank(value) ? '-' : value;
  }
}
