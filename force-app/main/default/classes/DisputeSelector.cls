/**
 * All SOQL on Dispute__c used by the assistant (USER_MODE).
 */
public inherited sharing class DisputeSelector {
  public static final Set<String> OPEN_STATUSES = new Set<String>{ 'New', 'Under Review' };

  /** Transaction Ids that already have an open dispute. */
  public Set<Id> selectTransactionsWithOpenDispute(Set<Id> transactionIds) {
    Set<Id> result = new Set<Id>();
    for (Dispute__c dispute : [
      SELECT Payment_Transaction__c
      FROM Dispute__c
      WHERE Payment_Transaction__c IN :transactionIds AND Status__c IN :OPEN_STATUSES
      WITH USER_MODE
    ]) {
      result.add(dispute.Payment_Transaction__c);
    }
    return result;
  }

  public List<Dispute__c> selectByIds(Set<Id> disputeIds) {
    return [
      SELECT
        Id,
        Name,
        Status__c,
        Reason__c,
        Amount__c,
        Channel__c,
        Is_High_Value__c,
        Description__c,
        CreatedDate,
        Account__r.Name,
        Payment_Transaction__r.Name,
        Payment_Transaction__r.Merchant_Name__c,
        Payment_Transaction__r.Transaction_Date__c
      FROM Dispute__c
      WHERE Id IN :disputeIds
      WITH USER_MODE
    ];
  }

  /** Looks a dispute up by its number (DSP-...) or by the number of its transaction (TX-...). */
  public List<Dispute__c> selectByDisputeOrTransactionNumber(String reference) {
    String ref = reference.trim().toUpperCase();
    return [
      SELECT
        Id,
        Name,
        Status__c,
        Reason__c,
        Amount__c,
        Is_High_Value__c,
        CreatedDate,
        LastModifiedDate,
        Payment_Transaction__r.Name,
        Payment_Transaction__r.Merchant_Name__c
      FROM Dispute__c
      WHERE Name = :ref OR Payment_Transaction__r.Name = :ref
      WITH USER_MODE
      ORDER BY CreatedDate DESC
      LIMIT 5
    ];
  }
}
