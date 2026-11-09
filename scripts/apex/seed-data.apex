// Demo data. Run with: sf apex run --file scripts/apex/seed-data.apex --target-org <alias>
// Dates are relative to today, so the dispute window rules always make sense in the demo.
List<Account> accounts = new List<Account>{
    new Account(Name = 'Rossi Alimentari SpA'),
    new Account(Name = 'Bianchi Viaggi Srl'),
    new Account(Name = 'Giulia Verdi')
};
insert accounts;

String[] merchants = new String[]{ 'Amazon EU', 'Trenitalia', 'Esselunga', 'Booking.com', 'Apple Store', 'Ryanair' };
String[] channels = new String[]{ 'E-commerce', 'POS', 'E-commerce', 'E-commerce', 'POS', 'E-commerce' };
List<Payment_Transaction__c> txs = new List<Payment_Transaction__c>();
for (Account acc : accounts) {
    for (Integer i = 0; i < 6; i++) {
        txs.add(new Payment_Transaction__c(
            Account__c = acc.Id,
            Merchant_Name__c = merchants[i],
            Channel__c = channels[i],
            Amount__c = (i == 4) ? 1899.00 : 12.50 + i * 37,
            Transaction_Date__c = Datetime.now().addDays(-(i * 9 + 1)),
            Status__c = (i == 5) ? 'Declined' : 'Settled',
            Card_Last4__c = '4242'
        ));
    }
    // One transaction outside the 120-day window, to show the rule in the demo.
    txs.add(new Payment_Transaction__c(
        Account__c = acc.Id, Merchant_Name__c = 'Old Merchant', Channel__c = 'POS',
        Amount__c = 80, Transaction_Date__c = Datetime.now().addDays(-150),
        Status__c = 'Settled', Card_Last4__c = '4242'
    ));
}
insert txs;
System.debug('Created ' + accounts.size() + ' accounts and ' + txs.size() + ' transactions');
