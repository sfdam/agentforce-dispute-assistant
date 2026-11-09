/**
 * Reads the business rules from Dispute_Setting__mdt (record "Default").
 * Tests can inject their own values through the @TestVisible override.
 */
public with sharing class DisputeSettings {
  public static final String DEFAULT_RECORD = 'Default';

  @TestVisible
  private static Dispute_Setting__mdt testOverride;

  public static Dispute_Setting__mdt get() {
    if (testOverride != null) {
      return testOverride;
    }
    Dispute_Setting__mdt setting = Dispute_Setting__mdt.getInstance(DEFAULT_RECORD);
    if (setting == null) {
      setting = new Dispute_Setting__mdt(
        High_Value_Threshold__c = 1000,
        Dispute_Window_Days__c = 120,
        Slack_Notifications_Enabled__c = false
      );
    }
    return setting;
  }

  public static Decimal highValueThreshold() {
    Decimal value = get().High_Value_Threshold__c;
    return value == null ? 1000 : value;
  }

  public static Integer disputeWindowDays() {
    Decimal value = get().Dispute_Window_Days__c;
    return value == null ? 120 : value.intValue();
  }

  public static Boolean slackEnabled() {
    return get().Slack_Notifications_Enabled__c == true;
  }
}
