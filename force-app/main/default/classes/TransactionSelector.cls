/**
 * All SOQL on Payment_Transaction__c and Account used by the assistant.
 * Queries run in USER_MODE so the agent never sees more than the running user can.
 */
public inherited sharing class TransactionSelector {
  public List<Payment_Transaction__c> selectRecentByAccount(Id accountId, Integer maxRows) {
    return [
      SELECT
        Id,
        Name,
        Account__c,
        Amount__c,
        Transaction_Date__c,
        Merchant_Name__c,
        Status__c,
        Card_Last4__c,
        Channel__c
      FROM Payment_Transaction__c
      WHERE Account__c = :accountId
      WITH USER_MODE
      ORDER BY Transaction_Date__c DESC
      LIMIT :maxRows
    ];
  }

  public Map<String, Payment_Transaction__c> selectByNames(Set<String> transactionNumbers) {
    Map<String, Payment_Transaction__c> byName = new Map<String, Payment_Transaction__c>();
    for (Payment_Transaction__c tx : [
      SELECT Id, Name, Account__c, Amount__c, Transaction_Date__c, Merchant_Name__c, Status__c
      FROM Payment_Transaction__c
      WHERE Name IN :transactionNumbers
      WITH USER_MODE
    ]) {
      byName.put(tx.Name.toUpperCase(), tx);
    }
    return byName;
  }

  public List<Account> selectAccountsByName(String accountName) {
    String pattern = '%' + accountName.trim() + '%';
    return [SELECT Id, Name FROM Account WHERE Name LIKE :pattern WITH USER_MODE ORDER BY Name LIMIT 5];
  }
}
