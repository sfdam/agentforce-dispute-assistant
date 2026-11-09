/**
 * Domain logic to open disputes. Bulkified: one query per object whatever the
 * number of requests, partial success (one bad request does not block the others).
 */
public with sharing class DisputeService {
  public static final String CHANNEL_AGENTFORCE = 'Agentforce';
  private static final Set<String> DISPUTABLE_STATUSES = new Set<String>{ 'Settled', 'Authorized' };

  @TestVisible
  private TransactionSelector transactions = new TransactionSelector();
  @TestVisible
  private DisputeSelector disputes = new DisputeSelector();

  public class Request {
    public String transactionNumber;
    public String reason;
    public String description;
    public String channel;
  }

  public class Result {
    public Boolean success = false;
    public String message;
    public Id disputeId;
    public String disputeNumber;
    public Boolean isHighValue = false;
  }

  public List<Result> openDisputes(List<Request> requests) {
    List<Result> results = new List<Result>();
    Set<String> numbers = new Set<String>();
    for (Request req : requests) {
      results.add(new Result());
      if (String.isNotBlank(req.transactionNumber)) {
        numbers.add(req.transactionNumber.trim().toUpperCase());
      }
    }

    Map<String, Payment_Transaction__c> txByNumber = transactions.selectByNames(numbers);
    Set<Id> txIds = new Set<Id>();
    for (Payment_Transaction__c tx : txByNumber.values()) {
      txIds.add(tx.Id);
    }
    Set<Id> alreadyDisputed = disputes.selectTransactionsWithOpenDispute(txIds);
    Map<String, String> reasonByKey = picklistValuesByKey(Dispute__c.Reason__c.getDescribe());
    Map<String, String> channelByKey = picklistValuesByKey(Dispute__c.Channel__c.getDescribe());
    Decimal threshold = DisputeSettings.highValueThreshold();
    Datetime oldestAllowed = Datetime.now().addDays(-DisputeSettings.disputeWindowDays());

    List<Dispute__c> toInsert = new List<Dispute__c>();
    List<Integer> resultIndexes = new List<Integer>();
    Set<Id> claimedInThisBatch = new Set<Id>();

    for (Integer i = 0; i < requests.size(); i++) {
      Request req = requests[i];
      Result res = results[i];
      try {
        Payment_Transaction__c tx = String.isBlank(req.transactionNumber)
          ? null
          : txByNumber.get(req.transactionNumber.trim().toUpperCase());
        if (tx == null) {
          throw new DisputeException(
            'Transaction ' + req.transactionNumber + ' not found. Check the transaction number (e.g. TX-000123).'
          );
        }
        if (!DISPUTABLE_STATUSES.contains(tx.Status__c)) {
          throw new DisputeException('Transaction ' + tx.Name + ' is ' + tx.Status__c + ' and cannot be disputed.');
        }
        if (tx.Transaction_Date__c != null && tx.Transaction_Date__c < oldestAllowed) {
          throw new DisputeException(
            'Transaction ' +
              tx.Name +
              ' is older than ' +
              DisputeSettings.disputeWindowDays() +
              ' days: the dispute window is closed.'
          );
        }
        if (alreadyDisputed.contains(tx.Id) || claimedInThisBatch.contains(tx.Id)) {
          throw new DisputeException('Transaction ' + tx.Name + ' already has an open dispute.');
        }
        String reason = reasonByKey.get(normalize(req.reason));
        if (reason == null) {
          throw new DisputeException(
            'Reason "' +
              req.reason +
              '" is not valid. Allowed values: ' +
              String.join(new List<String>(new Set<String>(reasonByKey.values())), ', ') +
              '.'
          );
        }
        String channel = channelByKey.get(normalize(String.isBlank(req.channel) ? CHANNEL_AGENTFORCE : req.channel));

        Boolean highValue = tx.Amount__c != null && tx.Amount__c >= threshold;
        toInsert.add(
          new Dispute__c(
            Payment_Transaction__c = tx.Id,
            Account__c = tx.Account__c,
            Amount__c = tx.Amount__c,
            Reason__c = reason,
            Description__c = req.description == null ? null : req.description.left(2000),
            Channel__c = channel == null ? CHANNEL_AGENTFORCE : channel,
            Status__c = 'New',
            Is_High_Value__c = highValue
          )
        );
        resultIndexes.add(i);
        claimedInThisBatch.add(tx.Id);
        res.isHighValue = highValue;
      } catch (DisputeException e) {
        res.message = e.getMessage();
      }
    }

    if (!toInsert.isEmpty()) {
      insertAndCollect(toInsert, resultIndexes, results);
    }
    return results;
  }

  private void insertAndCollect(List<Dispute__c> toInsert, List<Integer> resultIndexes, List<Result> results) {
    Database.SaveResult[] saves = Database.insert(toInsert, false, AccessLevel.USER_MODE);
    Set<Id> created = new Set<Id>();
    Set<Id> highValueIds = new Set<Id>();
    for (Integer j = 0; j < saves.size(); j++) {
      Result res = results[resultIndexes[j]];
      if (saves[j].isSuccess()) {
        res.success = true;
        res.disputeId = saves[j].getId();
        created.add(res.disputeId);
        if (res.isHighValue) {
          highValueIds.add(res.disputeId);
        }
      } else {
        res.isHighValue = false;
        res.message = 'The dispute could not be saved: ' + saves[j].getErrors()[0].getMessage();
      }
    }

    Map<Id, Dispute__c> createdById = new Map<Id, Dispute__c>(disputes.selectByIds(created));
    for (Integer j = 0; j < saves.size(); j++) {
      Result res = results[resultIndexes[j]];
      if (res.success) {
        res.disputeNumber = createdById.get(res.disputeId).Name;
        res.message =
          'Dispute ' +
          res.disputeNumber +
          ' opened on transaction ' +
          createdById.get(res.disputeId).Payment_Transaction__r.Name +
          (res.isHighValue ? '. It is high value: the disputes team has been notified on Slack.' : '.');
      }
    }

    if (!highValueIds.isEmpty() && DisputeSettings.slackEnabled()) {
      System.enqueueJob(new SlackDisputeNotifier(highValueIds));
    }
  }

  /** Maps lower-cased value and label to the API value, so "duplicate charge" works. */
  private static Map<String, String> picklistValuesByKey(Schema.DescribeFieldResult field) {
    Map<String, String> byKey = new Map<String, String>();
    for (Schema.PicklistEntry entry : field.getPicklistValues()) {
      if (entry.isActive()) {
        byKey.put(normalize(entry.getValue()), entry.getValue());
        byKey.put(normalize(entry.getLabel()), entry.getValue());
      }
    }
    return byKey;
  }

  private static String normalize(String value) {
    return value == null ? null : value.trim().toLowerCase();
  }
}
