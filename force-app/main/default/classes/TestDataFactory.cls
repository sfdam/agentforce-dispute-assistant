@IsTest
public class TestDataFactory {
  public static final String PERMISSION_SET = 'Dispute_Assistant_User';

  /** Standard user with the project permission set: tests run as this user because queries use USER_MODE. */
  public static User createDisputeUser() {
    Profile profile = [
      SELECT Id
      FROM Profile
      WHERE Name IN ('Standard User', 'Utente standard')
      ORDER BY Name
      LIMIT 1
    ];
    String unique = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
    User user = new User(
      ProfileId = profile.Id,
      LastName = 'Dispute Tester',
      Email = 'dispute.tester@example.com',
      Username = 'dispute.tester.' + unique + '@example.com',
      Alias = 'dtest',
      TimeZoneSidKey = 'Europe/Rome',
      LocaleSidKey = 'it_IT',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US'
    );
    insert user;
    PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = :PERMISSION_SET LIMIT 1];
    insert new PermissionSetAssignment(AssigneeId = user.Id, PermissionSetId = ps.Id);
    return user;
  }

  public static Account createAccount(String name) {
    Account acc = new Account(Name = name);
    insert acc;
    return acc;
  }

  public static Payment_Transaction__c buildTransaction(Id accountId, Decimal amount, Integer daysAgo, String status) {
    return new Payment_Transaction__c(
      Account__c = accountId,
      Amount__c = amount,
      Transaction_Date__c = Datetime.now().addDays(-daysAgo),
      Merchant_Name__c = 'Test Merchant',
      Status__c = status,
      Card_Last4__c = '4242',
      Channel__c = 'E-commerce'
    );
  }

  public static Payment_Transaction__c createTransaction(Id accountId, Decimal amount, Integer daysAgo, String status) {
    Payment_Transaction__c tx = buildTransaction(accountId, amount, daysAgo, status);
    insert tx;
    return [SELECT Id, Name, Amount__c, Status__c FROM Payment_Transaction__c WHERE Id = :tx.Id];
  }

  /** Fixed settings so tests do not depend on the deployed Custom Metadata record. */
  public static void useSettings(Decimal threshold, Integer windowDays, Boolean slackEnabled) {
    DisputeSettings.testOverride = new Dispute_Setting__mdt(
      High_Value_Threshold__c = threshold,
      Dispute_Window_Days__c = windowDays,
      Slack_Notifications_Enabled__c = slackEnabled
    );
  }
}
