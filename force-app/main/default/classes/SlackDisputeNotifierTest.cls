@IsTest
private class SlackDisputeNotifierTest {
  private static Dispute__c createDispute(Decimal amount) {
    Account acc = TestDataFactory.createAccount('Slack Test SpA');
    Payment_Transaction__c tx = TestDataFactory.createTransaction(acc.Id, amount, 1, 'Settled');
    Dispute__c dispute = new Dispute__c(
      Payment_Transaction__c = tx.Id,
      Account__c = acc.Id,
      Amount__c = amount,
      Reason__c = 'Fraud',
      Status__c = 'New',
      Channel__c = 'Agentforce',
      Is_High_Value__c = true
    );
    insert dispute;
    return dispute;
  }

  @IsTest
  static void postsBlockKitMessageAndFlagsDispute() {
    User user = TestDataFactory.createDisputeUser();
    System.runAs(user) {
      Dispute__c dispute = createDispute(1500);
      SlackWebhookMock mock = new SlackWebhookMock(200);
      Test.setMock(HttpCalloutMock.class, mock);

      Test.startTest();
      System.enqueueJob(new SlackDisputeNotifier(new Set<Id>{ dispute.Id }));
      Test.stopTest();

      Assert.areEqual(1, mock.calls);
      Assert.areEqual(SlackDisputeNotifier.NAMED_CREDENTIAL, mock.lastEndpoint);
      Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(mock.lastBody);
      Assert.isTrue(((String) payload.get('text')).contains('High value dispute'));
      Assert.areEqual(3, ((List<Object>) payload.get('blocks')).size());
      Assert.isTrue([SELECT Slack_Notified__c FROM Dispute__c WHERE Id = :dispute.Id].Slack_Notified__c);
    }
  }

  @IsTest
  static void slackErrorLeavesDisputeNotFlagged() {
    User user = TestDataFactory.createDisputeUser();
    System.runAs(user) {
      Dispute__c dispute = createDispute(1500);
      Test.setMock(HttpCalloutMock.class, new SlackWebhookMock(500));

      Test.startTest();
      System.enqueueJob(new SlackDisputeNotifier(new Set<Id>{ dispute.Id }));
      Test.stopTest();

      Assert.isFalse([SELECT Slack_Notified__c FROM Dispute__c WHERE Id = :dispute.Id].Slack_Notified__c);
    }
  }
}
