public with sharing class ProxyController {

    @AuraEnabled
    public static String callAPI(String recordId, String action) {

        Http http = new Http();
        HttpRequest req = new HttpRequest();

        req.setEndpoint('https://orgfarm-4e9caeff63-dev-ed.develop.my.salesforce-sites.com/services/apexrest/fundingAction?id=' 
            + recordId + '&action=' + action);

        req.setMethod('GET');

        HttpResponse res = http.send(req);

        System.debug('Response: ' + res.getBody());

        return res.getBody();
    }
}