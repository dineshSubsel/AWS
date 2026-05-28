public with sharing class BatchFileTransfer implements Database.Batchable<SObject>, Database.Stateful {
    private String awsKey;
    private String awsSecret;
    private String bucketName;
    private String hostName;
    private String methodName;
    private Integer batchSize; // Number of records to process in each batch

    public BatchFileTransfer(String awsKey, String awsSecret, String bucketName, String hostName, String methodName, Integer batchSize) {
        this.awsKey = awsKey;
        this.awsSecret = awsSecret;
        this.bucketName = bucketName;
        this.hostName = hostName;
        this.methodName = methodName;
        this.batchSize = batchSize;
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        // Query the records (e.g., Salesforce objects) that you want to process.
        String query = 'SELECT Id, Title, ContentDocumentId, FileExtension, ContentSize FROM ContentVersion'; // Add your conditions
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext context, List<SObject> scope) {
        for (SObject record : scope) {
            List<ContentDocumentLink> links = [SELECT ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId = :record.Id];

            for (ContentDocumentLink link : links) {
                ContentVersion version = [SELECT VersionData, Title, FileExtension FROM ContentVersion WHERE ContentDocumentId = :link.ContentDocumentId AND IsLatest = true LIMIT 1];

                if (version != null) {
                    try {
                       
                        // Construct S3 URL
                        String filename = version.Title;
                        String fileExtension = version.FileExtension.toLowerCase();
                        String fileUrl = 'https://' + bucketName + '.' + hostName + '/' + filename.toLowerCase() + '.' + fileExtension;
                        
                        // Prepare HTTP request
                        HttpRequest req = new HttpRequest();
                        req.setMethod(methodName);
                        req.setEndpoint(fileUrl);
                        req.setHeader('Host', bucketName + '.' + hostName);
                        req.setHeader('Content-Type', 'application/octet-stream');
                        req.setHeader('x-amz-date', Datetime.now().formatGMT('yyyyMMdd\'T\'HHmmss\'Z\''));
                        req.setHeader('x-amz-content-sha256', 'UNSIGNED-PAYLOAD');
                       
                        // Set the request body
                        req.setBodyAsBlob(version.VersionData); 

                        // Send the HTTP request
                        Http http = new Http();
                        HttpResponse res = http.send(req);

                        // Check the response and handle accordingly
                        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                            // Successfully uploaded
                            // You can insert records or perform other actions here if needed
                        } else {
                            // Handle error cases
                            System.debug('S3 Upload Error: ' + res.getBody());
                        }

                    } catch (Exception ex) {
                        // Handle exceptions
                        System.debug('Exception during S3 upload: ' + ex.getMessage());
                    }
                }
            }
        }
    }

    public void finish(Database.BatchableContext context) {
        // Perform any cleanup or finalization tasks if necessary.
    }
}