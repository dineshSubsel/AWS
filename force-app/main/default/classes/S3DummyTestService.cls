public with sharing class S3DummyTestService {

    public static void uploadDummy(Id contentVersionId) {

        ContentVersion cv = [
            SELECT VersionData, Title, FileExtension
            FROM ContentVersion
            WHERE Id = :contentVersionId
            LIMIT 1
        ];

        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://httpbin.org/put');
        req.setMethod('PUT');

        req.setHeader('Content-Type', 'application/octet-stream');
        req.setBodyAsBlob(cv.VersionData);

        Http http = new Http();

        HttpResponse res = http.send(req);

        System.debug('Status Code: ' + res.getStatusCode());
        System.debug('Response: ' + res.getBody());
    }
}