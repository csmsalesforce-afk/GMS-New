@IsTest
public class GMSMockHttpResponseGenerator implements HttpCalloutMock {
    public static Id campaignIdOverride;
    public static Id donorIdOverride;

    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setStatusCode(200);

        String endpoint = req != null && req.getEndpoint() != null ? req.getEndpoint() : '';
        if (endpoint.contains('/account_links')) {
            res.setBody('{"object": "account_link", "url": "https://connect.stripe.com/setup/s/test_link"}');
        } else if (endpoint.contains('/accounts')) {
            res.setBody('{"id": "acct_test123", "details_submitted": true, "charges_enabled": true, "payouts_enabled": true, "requirements": {"currently_due": [], "eventually_due": [], "past_due": []}}');
        } else if (endpoint.contains('/transfers')) {
            res.setBody('{"id": "tr_test123", "amount": 10000, "currency": "usd", "destination": "acct_test123"}');
        } else if (endpoint.contains('/payouts')) {
            res.setBody('{"id": "po_test123", "amount": 10000, "currency": "usd", "status": "paid"}');
        } else if (endpoint.contains('/checkout/sessions')) {
            String cId = campaignIdOverride != null ? String.valueOf(campaignIdOverride) : '';
            String dId = donorIdOverride != null ? String.valueOf(donorIdOverride) : '';
            res.setBody('{"id": "cs_test_123", "url": "https://checkout.stripe.com/test", "payment_status": "paid", "amount_total": 5000, "payment_intent": "pi_test123", "customer_details": {"email": "test@example.com", "name": "Test Supporter", "phone": "555-0100"}, "metadata": {"campaignId": "' + cId + '", "donorId": "' + dId + '", "donorName": "Test Supporter", "donorEmail": "test@example.com", "donorPhone": "555-0100", "frequency": "Monthly", "duration": "12 Months", "designation": "General"}}');
        } else {
            res.setBody('{"id": "mock_id_123", "status": "success", "url": "https://example.com/mock", "payment_status": "paid", "amount_total": 5000, "details_submitted": true, "charges_enabled": true, "payouts_enabled": true}');
        }
        return res;
    }
}

