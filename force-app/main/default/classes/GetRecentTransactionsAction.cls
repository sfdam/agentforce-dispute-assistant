/**
 * Agentforce action: "Get Recent Transactions".
 * Finds the customer by Account Id or name and returns the latest card transactions.
 */
public with sharing class GetRecentTransactionsAction {
  private static final Integer DEFAULT_ROWS = 10;
  private static final Integer MAX_ROWS = 50;

  public class Input {
    @InvocableVariable(
      label='Account Id'
      description='Salesforce Id of the customer Account. Use it when known, otherwise pass the customer name.'
    )
    public Id accountId;

    @InvocableVariable(
      label='Customer Name'
      description='Name (or part of the name) of the customer Account. Ignored when Account Id is provided.'
    )
    public String accountName;

    @InvocableVariable(
      label='Max Results'
      description='How many transactions to return, most recent first. Default 10, maximum 50.'
    )
    public Integer maxResults;
  }

  public class Output {
    @InvocableVariable(label='Success' description='False when the customer could not be identified.')
    public Boolean success;

    @InvocableVariable(
      label='Message'
      description='Explanation for the user: number of transactions found, or what is missing.'
    )
    public String message;

    @InvocableVariable(
      label='Transactions'
      description='Recent transactions with number (TX-...), date, merchant, amount, status and channel.'
    )
    public List<Payment_Transaction__c> transactions;
  }

  @InvocableMethod(
    label='Get Recent Transactions'
    description='Returns the most recent card transactions of a customer, identified by Account Id or by name.'
    category='Dispute Assistant'
  )
  public static List<Output> getRecentTransactions(List<Input> inputs) {
    // Agentforce calls this with one input per turn. Queries per input are capped by the
    // 200-element invocable batch; if Flow bulk usage grows, move to a set-based query.
    TransactionSelector selector = new TransactionSelector();
    List<Output> outputs = new List<Output>();
    for (Input input : inputs) {
      outputs.add(handle(input, selector));
    }
    return outputs;
  }

  private static Output handle(Input input, TransactionSelector selector) {
    Output out = new Output();
    out.success = false;
    out.transactions = new List<Payment_Transaction__c>();

    Id accountId = input.accountId;
    String accountLabel;
    if (accountId == null) {
      if (String.isBlank(input.accountName)) {
        out.message = 'Please provide the customer name or Account Id.';
        return out;
      }
      List<Account> matches = selector.selectAccountsByName(input.accountName);
      if (matches.isEmpty()) {
        out.message = 'No customer found matching "' + input.accountName + '".';
        return out;
      }
      if (matches.size() > 1) {
        List<String> names = new List<String>();
        for (Account acc : matches) {
          names.add(acc.Name);
        }
        out.message =
          'More than one customer matches "' +
          input.accountName +
          '": ' +
          String.join(names, ', ') +
          '. Ask which one.';
        return out;
      }
      accountId = matches[0].Id;
      accountLabel = matches[0].Name;
    }

    Integer rows = input.maxResults == null ||
      input.maxResults <= 0
      ? DEFAULT_ROWS
      : Math.min(input.maxResults, MAX_ROWS);
    out.transactions = selector.selectRecentByAccount(accountId, rows);
    out.success = true;
    out.message =
      out.transactions.size() +
      ' transaction(s) found' +
      (accountLabel == null ? '' : ' for ' + accountLabel) +
      '.';
    return out;
  }
}
