@IsTest
public class SlackWebhookMock implements HttpCalloutMock {
  public Integer statusCode;
  public Integer calls = 0;
  public String lastBody;
  public String lastEndpoint;

  public SlackWebhookMock(Integer statusCode) {
    this.statusCode = statusCode;
  }

  public HttpResponse respond(HttpRequest request) {
    calls++;
    lastBody = request.getBody();
    lastEndpoint = request.getEndpoint();
    HttpResponse response = new HttpResponse();
    response.setStatusCode(statusCode);
    response.setBody(statusCode == 200 ? 'ok' : 'invalid_payload');
    return response;
  }
}
