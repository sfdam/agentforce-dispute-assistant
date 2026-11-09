/**
 * Agentforce action: "Get Dispute Status".
 * Accepts a dispute number (DSP-...) or a transaction number (TX-...).
 */
public with sharing class GetDisputeStatusAction {
  public class Input {
    @InvocableVariable(
      label='Reference'
      description='Dispute number (DSP-000123) or transaction number (TX-000123).'
      required=true
    )
    public String reference;
  }

  public class Output {
    @InvocableVariable(label='Found' description='True when at least one dispute matches the reference.')
    public Boolean found;

    @InvocableVariable(label='Message' description='Readable summary of the dispute status.')
    public String message;

    @InvocableVariable(label='Disputes' description='Matching disputes, most recent first.')
    public List<Dispute__c> disputes;
  }

  @InvocableMethod(
    label='Get Dispute Status'
    description='Returns status, reason and amount of a dispute, searched by dispute number or transaction number.'
    category='Dispute Assistant'
  )
  public static List<Output> getDisputeStatus(List<Input> inputs) {
    // Agentforce calls this with one input per turn. Queries per input are capped by the
    // 200-element invocable batch; if Flow bulk usage grows, move to a set-based query.
    DisputeSelector selector = new DisputeSelector();
    List<Output> outputs = new List<Output>();
    for (Input input : inputs) {
      Output out = new Output();
      out.disputes = String.isBlank(input.reference)
        ? new List<Dispute__c>()
        : selector.selectByDisputeOrTransactionNumber(input.reference);
      out.found = !out.disputes.isEmpty();
      out.message = out.found ? describe(out.disputes[0]) : 'No dispute found for "' + input.reference + '".';
      outputs.add(out);
    }
    return outputs;
  }

  private static String describe(Dispute__c dispute) {
    return 'Dispute ' +
      dispute.Name +
      ' on transaction ' +
      dispute.Payment_Transaction__r.Name +
      ' (' +
      dispute.Payment_Transaction__r.Merchant_Name__c +
      ') is "' +
      dispute.Status__c +
      '". Reason: ' +
      dispute.Reason__c +
      '. Opened on ' +
      dispute.CreatedDate.date().format() +
      '.';
  }
}
