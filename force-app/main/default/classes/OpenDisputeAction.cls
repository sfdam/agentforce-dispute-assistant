/**
 * Agentforce action: "Open Dispute".
 * Thin adapter between the agent and DisputeService: all the rules live in the service.
 */
public with sharing class OpenDisputeAction {
  public class Input {
    @InvocableVariable(
      label='Transaction Number'
      description='Number of the transaction to dispute, format TX-000123.'
      required=true
    )
    public String transactionNumber;

    @InvocableVariable(
      label='Reason'
      description='One of: Fraud, Not Received, Duplicate Charge, Incorrect Amount, Other.'
      required=true
    )
    public String reason;

    @InvocableVariable(label='Description' description='Short description of the problem in the customer words.')
    public String description;

    @InvocableVariable(label='Channel' description='Where the request comes from: Agentforce (default) or Slack.')
    public String channel;
  }

  public class Output {
    @InvocableVariable(label='Success' description='True when the dispute was created.')
    public Boolean success;

    @InvocableVariable(
      label='Message'
      description='Confirmation with the dispute number, or the reason why the dispute could not be opened.'
    )
    public String message;

    @InvocableVariable(label='Dispute Number' description='Number of the new dispute, format DSP-000123.')
    public String disputeNumber;

    @InvocableVariable(label='Dispute Id' description='Salesforce Id of the new dispute.')
    public Id disputeId;

    @InvocableVariable(
      label='High Value'
      description='True when the amount is above the high value threshold and the team was notified.'
    )
    public Boolean isHighValue;
  }

  @InvocableMethod(
    label='Open Dispute'
    description='Opens a dispute (chargeback request) on a card transaction after checking status, time window and duplicates.'
    category='Dispute Assistant'
  )
  public static List<Output> openDispute(List<Input> inputs) {
    List<DisputeService.Request> requests = new List<DisputeService.Request>();
    for (Input input : inputs) {
      DisputeService.Request req = new DisputeService.Request();
      req.transactionNumber = input.transactionNumber;
      req.reason = input.reason;
      req.description = input.description;
      req.channel = input.channel;
      requests.add(req);
    }

    List<Output> outputs = new List<Output>();
    for (DisputeService.Result res : new DisputeService().openDisputes(requests)) {
      Output out = new Output();
      out.success = res.success;
      out.message = res.message;
      out.disputeNumber = res.disputeNumber;
      out.disputeId = res.disputeId;
      out.isHighValue = res.isHighValue;
      outputs.add(out);
    }
    return outputs;
  }
}
