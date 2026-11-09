@IsTest
private class AgentActionsTest {
  @IsTest
  static void getRecentTransactionsByName() {
    User user = TestDataFactory.createDisputeUser();
    System.runAs(user) {
      Account acc = TestDataFactory.createAccount('Ferrari Logistica');
      TestDataFactory.createTransaction(acc.Id, 10, 5, 'Settled');
      TestDataFactory.createTransaction(acc.Id, 20, 1, 'Settled');

      GetRecentTransactionsAction.Input input = new GetRecentTransactionsAction.Input();
      input.accountName = 'ferrari';
      GetRecentTransactionsAction.Output out = GetRecentTransactionsAction.getRecentTransactions(
        new List<GetRecentTransactionsAction.Input>{ input }
      )[0];

      Assert.isTrue(out.success, out.message);
      Assert.areEqual(2, out.transactions.size());
      Assert.isTrue(out.transactions[0].Amount__c == 20, 'Most recent first');
    }
  }

  @IsTest
  static void getRecentTransactionsHandlesMissingAndAmbiguousCustomer() {
    User user = TestDataFactory.createDisputeUser();
    System.runAs(user) {
      TestDataFactory.createAccount('Rossi Alfa');
      TestDataFactory.createAccount('Rossi Beta');

      GetRecentTransactionsAction.Input empty = new GetRecentTransactionsAction.Input();
      GetRecentTransactionsAction.Input ambiguous = new GetRecentTransactionsAction.Input();
      ambiguous.accountName = 'Rossi';
      GetRecentTransactionsAction.Input unknown = new GetRecentTransactionsAction.Input();
      unknown.accountName = 'Nobody';

      List<GetRecentTransactionsAction.Output> outs = GetRecentTransactionsAction.getRecentTransactions(
        new List<GetRecentTransactionsAction.Input>{ empty, ambiguous, unknown }
      );

      Assert.isFalse(outs[0].success);
      Assert.isFalse(outs[1].success);
      Assert.isTrue(outs[1].message.contains('More than one'));
      Assert.isFalse(outs[2].success);
    }
  }

  @IsTest
  static void getRecentTransactionsByAccountIdWithLimit() {
    User user = TestDataFactory.createDisputeUser();
    System.runAs(user) {
      Account acc = TestDataFactory.createAccount('Limit SpA');
      List<Payment_Transaction__c> txs = new List<Payment_Transaction__c>();
      for (Integer i = 0; i < 5; i++) {
        txs.add(TestDataFactory.buildTransaction(acc.Id, 10, i, 'Settled'));
      }
      insert txs;

      GetRecentTransactionsAction.Input input = new GetRecentTransactionsAction.Input();
      input.accountId = acc.Id;
      input.maxResults = 3;
      GetRecentTransactionsAction.Output out = GetRecentTransactionsAction.getRecentTransactions(
        new List<GetRecentTransactionsAction.Input>{ input }
      )[0];

      Assert.areEqual(3, out.transactions.size());
    }
  }

  @IsTest
  static void openDisputeThenReadStatus() {
    User user = TestDataFactory.createDisputeUser();
    System.runAs(user) {
      TestDataFactory.useSettings(1000, 120, false);
      Account acc = TestDataFactory.createAccount('Status SpA');
      Payment_Transaction__c tx = TestDataFactory.createTransaction(acc.Id, 75, 2, 'Settled');

      OpenDisputeAction.Input input = new OpenDisputeAction.Input();
      input.transactionNumber = tx.Name;
      input.reason = 'Incorrect Amount';
      input.description = 'Charged 75 instead of 57';
      OpenDisputeAction.Output opened = OpenDisputeAction.openDispute(new List<OpenDisputeAction.Input>{ input })[0];
      Assert.isTrue(opened.success, opened.message);

      GetDisputeStatusAction.Input byDispute = new GetDisputeStatusAction.Input();
      byDispute.reference = opened.disputeNumber;
      GetDisputeStatusAction.Input byTransaction = new GetDisputeStatusAction.Input();
      byTransaction.reference = tx.Name.toLowerCase();
      GetDisputeStatusAction.Input missing = new GetDisputeStatusAction.Input();
      missing.reference = 'DSP-999999';

      List<GetDisputeStatusAction.Output> outs = GetDisputeStatusAction.getDisputeStatus(
        new List<GetDisputeStatusAction.Input>{ byDispute, byTransaction, missing }
      );

      Assert.isTrue(outs[0].found);
      Assert.isTrue(outs[0].message.contains('"New"'));
      Assert.isTrue(outs[1].found);
      Assert.isFalse(outs[2].found);
    }
  }
}
