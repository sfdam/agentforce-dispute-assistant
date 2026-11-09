@IsTest
private class DisputeServiceTest {
  private static DisputeService.Request request(String txNumber, String reason) {
    DisputeService.Request req = new DisputeService.Request();
    req.transactionNumber = txNumber;
    req.reason = reason;
    req.description = 'Customer does not recognise the charge';
    return req;
  }

  @IsTest
  static void opensDisputeOnSettledTransaction() {
    User user = TestDataFactory.createDisputeUser();
    System.runAs(user) {
      TestDataFactory.useSettings(1000, 120, false);
      Account acc = TestDataFactory.createAccount('Rossi SpA');
      Payment_Transaction__c tx = TestDataFactory.createTransaction(acc.Id, 49.90, 3, 'Settled');

      Test.startTest();
      List<DisputeService.Result> results = new DisputeService()
        .openDisputes(new List<DisputeService.Request>{ request(tx.Name, 'Fraud') });
      Test.stopTest();

      Assert.isTrue(results[0].success, results[0].message);
      Assert.isFalse(results[0].isHighValue);
      Assert.isTrue(results[0].disputeNumber.startsWith('DSP-'));
      Dispute__c dispute = [
        SELECT Status__c, Reason__c, Amount__c, Account__c, Channel__c
        FROM Dispute__c
        WHERE Id = :results[0].disputeId
      ];
      Assert.areEqual('New', dispute.Status__c);
      Assert.areEqual('Fraud', dispute.Reason__c);
      Assert.isTrue(dispute.Amount__c == 49.90, String.valueOf(dispute.Amount__c));
      Assert.areEqual(acc.Id, dispute.Account__c);
      Assert.areEqual(DisputeService.CHANNEL_AGENTFORCE, dispute.Channel__c);
    }
  }

  @IsTest
  static void acceptsReasonWithDifferentCase() {
    User user = TestDataFactory.createDisputeUser();
    System.runAs(user) {
      TestDataFactory.useSettings(1000, 120, false);
      Account acc = TestDataFactory.createAccount('Bianchi Srl');
      Payment_Transaction__c tx = TestDataFactory.createTransaction(acc.Id, 20, 1, 'Authorized');

      DisputeService.Request req = request(tx.Name.toLowerCase(), '  duplicate charge ');
      req.channel = 'slack';
      List<DisputeService.Result> results = new DisputeService().openDisputes(new List<DisputeService.Request>{ req });

      Assert.isTrue(results[0].success, results[0].message);
      Dispute__c dispute = [SELECT Reason__c, Channel__c FROM Dispute__c WHERE Id = :results[0].disputeId];
      Assert.areEqual('Duplicate Charge', dispute.Reason__c);
      Assert.areEqual('Slack', dispute.Channel__c);
    }
  }

  @IsTest
  static void highValueDisputeIsNotifiedOnSlack() {
    User user = TestDataFactory.createDisputeUser();
    System.runAs(user) {
      TestDataFactory.useSettings(1000, 120, true);
      Account acc = TestDataFactory.createAccount('Verdi SpA');
      Payment_Transaction__c tx = TestDataFactory.createTransaction(acc.Id, 2500, 2, 'Settled');
      SlackWebhookMock mock = new SlackWebhookMock(200);
      Test.setMock(HttpCalloutMock.class, mock);

      Test.startTest();
      List<DisputeService.Result> results = new DisputeService()
        .openDisputes(new List<DisputeService.Request>{ request(tx.Name, 'Not Received') });
      Test.stopTest();

      Assert.isTrue(results[0].success, results[0].message);
      Assert.isTrue(results[0].isHighValue);
      Assert.areEqual(1, mock.calls, 'One Slack message expected');
      Dispute__c dispute = [
        SELECT Is_High_Value__c, Slack_Notified__c
        FROM Dispute__c
        WHERE Id = :results[0].disputeId
      ];
      Assert.isTrue(dispute.Is_High_Value__c);
      Assert.isTrue(dispute.Slack_Notified__c);
    }
  }

  @IsTest
  static void highValueWithSlackDisabledDoesNotCallOut() {
    User user = TestDataFactory.createDisputeUser();
    System.runAs(user) {
      TestDataFactory.useSettings(1000, 120, false);
      Account acc = TestDataFactory.createAccount('Neri SpA');
      Payment_Transaction__c tx = TestDataFactory.createTransaction(acc.Id, 5000, 2, 'Settled');
      SlackWebhookMock mock = new SlackWebhookMock(200);
      Test.setMock(HttpCalloutMock.class, mock);

      Test.startTest();
      List<DisputeService.Result> results = new DisputeService()
        .openDisputes(new List<DisputeService.Request>{ request(tx.Name, 'Fraud') });
      Test.stopTest();

      Assert.isTrue(results[0].isHighValue);
      Assert.areEqual(0, mock.calls);
    }
  }

  @IsTest
  static void rejectsInvalidRequests() {
    User user = TestDataFactory.createDisputeUser();
    System.runAs(user) {
      TestDataFactory.useSettings(1000, 120, false);
      Account acc = TestDataFactory.createAccount('Gialli Srl');
      Payment_Transaction__c declined = TestDataFactory.createTransaction(acc.Id, 10, 1, 'Declined');
      Payment_Transaction__c old = TestDataFactory.createTransaction(acc.Id, 10, 200, 'Settled');
      Payment_Transaction__c ok = TestDataFactory.createTransaction(acc.Id, 10, 1, 'Settled');

      List<DisputeService.Result> results = new DisputeService()
        .openDisputes(
          new List<DisputeService.Request>{
            request('TX-999999', 'Fraud'),
            request(declined.Name, 'Fraud'),
            request(old.Name, 'Fraud'),
            request(ok.Name, 'I just changed my mind'),
            request(null, 'Fraud')
          }
        );

      for (DisputeService.Result res : results) {
        Assert.isFalse(res.success);
        Assert.isNotNull(res.message);
      }
      Assert.isTrue(results[0].message.contains('not found'));
      Assert.isTrue(results[1].message.contains('cannot be disputed'));
      Assert.isTrue(results[2].message.contains('window is closed'));
      Assert.isTrue(results[3].message.contains('Allowed values'));
      Assert.areEqual(0, [SELECT COUNT() FROM Dispute__c]);
    }
  }

  @IsTest
  static void rejectsDuplicateOpenDispute() {
    User user = TestDataFactory.createDisputeUser();
    System.runAs(user) {
      TestDataFactory.useSettings(1000, 120, false);
      Account acc = TestDataFactory.createAccount('Blu SpA');
      Payment_Transaction__c tx = TestDataFactory.createTransaction(acc.Id, 30, 1, 'Settled');
      DisputeService service = new DisputeService();

      // Same transaction twice in the same batch: only the first one wins.
      List<DisputeService.Result> sameBatch = service.openDisputes(
        new List<DisputeService.Request>{ request(tx.Name, 'Fraud'), request(tx.Name, 'Other') }
      );
      Assert.isTrue(sameBatch[0].success);
      Assert.isFalse(sameBatch[1].success);

      // And again in a later call.
      List<DisputeService.Result> later = service.openDisputes(
        new List<DisputeService.Request>{ request(tx.Name, 'Fraud') }
      );
      Assert.isFalse(later[0].success);
      Assert.isTrue(later[0].message.contains('already has an open dispute'));
      Assert.areEqual(1, [SELECT COUNT() FROM Dispute__c]);
    }
  }

  @IsTest
  static void bulkRequestsUseConstantQueries() {
    User user = TestDataFactory.createDisputeUser();
    System.runAs(user) {
      TestDataFactory.useSettings(1000, 120, false);
      Account acc = TestDataFactory.createAccount('Bulk SpA');
      List<Payment_Transaction__c> txs = new List<Payment_Transaction__c>();
      for (Integer i = 0; i < 200; i++) {
        txs.add(TestDataFactory.buildTransaction(acc.Id, 10 + i, 1, 'Settled'));
      }
      insert txs;
      List<DisputeService.Request> requests = new List<DisputeService.Request>();
      for (Payment_Transaction__c tx : [SELECT Name FROM Payment_Transaction__c]) {
        requests.add(request(tx.Name, 'Fraud'));
      }

      Test.startTest();
      List<DisputeService.Result> results = new DisputeService().openDisputes(requests);
      Integer queries = Limits.getQueries();
      Test.stopTest();

      Assert.areEqual(200, [SELECT COUNT() FROM Dispute__c]);
      Assert.isTrue(queries <= 5, 'Expected constant number of queries, got ' + queries);
      Assert.isTrue(results[199].success);
    }
  }
}
