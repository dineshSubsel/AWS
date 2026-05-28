/*public class FileUploadBatchAWS implements Database.Batchable<sObject>, Database.AllowsCallouts {

    List<ContentDocumentLink> links=[SELECT ContentDocumentId,LinkedEntityId FROM ContentDocumentLink where LinkedEntityId=:recordId];
        Set<Id> ids=new Set<Id>();
        for(ContentDocumentLink link:links)
        {
            ids.add(link.ContentDocumentId);
        }
        List<ContentVersion> versions=[SELECT VersionData,Title,ContentDocumentId,FileExtension FROM ContentVersion WHERE ContentDocumentId = :ids AND IsLatest = true];
        Set<Id> versionIds = new Set<Id>;
        for(ContentVersion attach:versions)
        {
         versionIds.add(attach.ContentDocumentId);
        }
}*/

public with sharing class FileUploadBatchAWS implements Database.Batchable<sObject>, Database.AllowsCallouts {
    private static final Id recordId = '0012t00000RC05qAAD'; // Replace with your Account Id

    public Database.QueryLocator start(Database.BatchableContext context) {
        // Query for the ContentDocumentLinks and ContentVersions as before
        List<ContentDocumentLink> links = [SELECT ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId = :recordId];
        Set<Id> ids = new Set<Id>();
        for (ContentDocumentLink link : links) {
            ids.add(link.ContentDocumentId);
        }

        return Database.getQueryLocator([SELECT VersionData, Title, ContentDocumentId, FileExtension FROM ContentVersion WHERE ContentDocumentId IN :ids AND IsLatest = true]);
    }

    public void execute(Database.BatchableContext context, List<ContentVersion> scope) {
        for (ContentVersion attach : scope) {
            // Determine the content type based on the file extension
            String contentType = ContentType(attach.FileExtension);
            
            // Perform the file transfer to AWS using HTTP callouts
            transferFileToAWS(attach, contentType);
        }
    }

    private void transferFileToAWS(ContentVersion contentVersion, String contentType) {
        String awsEndpoint = 's3-us-west-1.amazonaws.com';//https://your-aws-endpoint-url.com/upload'; // Replace with your AWS endpoint URL
        String awsBucketName = 'sfdcfiles2023';
        String awsObjectKey = 'folder/' + contentVersion.Title + '.' + contentVersion.FileExtension;
        Blob fileData = contentVersion.VersionData;

        HttpRequest req = new HttpRequest();
        req.setEndpoint(awsEndpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', contentType); // Set the content type based on the file extension
        
        String boundary = 'boundary';
        String header = '--' + boundary + '\nContent-Disposition: form-data; name="file"; filename="' + awsObjectKey + '"\nContent-Type: ' + contentType + '\n\n';
        String footer = '\n--' + boundary + '--';
        
        String body = header + EncodingUtil.base64Encode(fileData) + footer;
        req.setBody(body);

        // Perform the HTTP callout to transfer the file to AWS
        Http http = new Http();
        HttpResponse res = http.send(req);

        // Handle the response as needed
        if (res.getStatusCode() == 200) {
            // The file was successfully transferred
        } else {
            // Handle the error case
        }
    }

    public void finish(Database.BatchableContext context) {
        // Perform any cleanup or finalization logic here
    }

    public String ContentType(String fileType) {
        switch on fileType.toLowerCase() {
            when 'docx' {
                return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
            }
            when 'csv' {
                return 'application/vnd.ms-excel';
            }
            when 'wav' {
                return 'audio/wav';
            }
            when 'wmv' {
                return 'video/x-ms-wmv';
            }
            when 'mp3' {
                return 'audio/mpeg';
            }
            when 'mp4' {
                return 'video/mp4';
            }
            when 'png' {
                return 'image/png';
            }
            when 'pdf' {
                return 'application/pdf';
            }
            when else {
                return 'image/jpeg';
            }
        }
    }
}





















/*public class FileUploadBatch implements Database.Batchable<SObject> {
    private String awsKey;
    private String awsSecret;
    private String bucketName;
    private String hostName;
    private String methodName;
    private String parentId; 

    public FileUploadBatch(String awsKey, String awsSecret, String bucketName, String hostName, String methodName, String parentId) {
        this.awsKey = awsKey;
        this.awsSecret = awsSecret;
        this.bucketName = bucketName;
        this.hostName = hostName;
        this.methodName = methodName;
        this.parentId = parentId;

    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        // Query the records (e.g., Salesforce objects) that you want to process.
        String query = 'ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId = :parentId'; // Add your conditions
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext context, List<SObject> scope) {
        Set<Id>
        // Gather ContentDocumentIds needed for the query
        Set<Id> contentDocumentIds = new Set<Id>();
        for (SObject record : scope) {
            ContentVersion contentVersion = (ContentVersion)record;
            contentDocumentIds.add(contentVersion.ContentDocumentId);
        }

        // Query ContentDocumentLinks for the gathered ContentDocumentIds
        List<ContentDocumentLink> links = [SELECT ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE ContentDocumentId IN :contentDocumentIds];

        // Create a map to store ContentVersions by ContentDocumentId
        Map<Id, ContentVersion> contentVersionMap = new Map<Id, ContentVersion>();

        // Query the latest ContentVersion for each ContentDocumentId
        for (ContentDocumentLink link : links) {
            if (!contentVersionMap.containsKey(link.ContentDocumentId)) {
                ContentVersion version = [SELECT VersionData, Title, FileExtension FROM ContentVersion WHERE ContentDocumentId = :link.ContentDocumentId AND IsLatest = true LIMIT 1];
                
                if (version != null) {
                    contentVersionMap.put(link.ContentDocumentId, version);
                }
            }
        }

        // Process the records
        for (SObject record : scope) {
            ContentVersion contentVersion = (ContentVersion)record;
            ContentVersion version = contentVersionMap.get(contentVersion.ContentDocumentId);
            
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

    public void finish(Database.BatchableContext context) {
        // Perform any cleanup or finalization tasks if necessary.
    }
}*/

/*

public class FileUploadBatch implements Database.Batchable<SObject> {
    private String awsKey;
    private String awsSecret;
    private String bucketName;
    private String hostName;
    private String methodName;

    public FileUploadBatch(String awsKey, String awsSecret, String bucketName, String hostName, String methodName) {
        this.awsKey = awsKey;
        this.awsSecret = awsSecret;
        this.bucketName = bucketName;
        this.hostName = hostName;
        this.methodName = methodName;
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        // Query the records (e.g., Salesforce ContentVersions) that you want to process.
        String query = 'SELECT Id, Title, ContentDocumentId, FileExtension, VersionData FROM ContentVersion WHERE  ContentDocumentId IN (SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = \'0015j000019PWMOAA4\')';
        system.debug('QUERY FORMAT' + query);
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext context, List<ContentVersion> scope) {
        List<ContentVersion> versionsToProcess = new List<ContentVersion>();

        for (ContentVersion version : scope) {
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
                    versionsToProcess.add(version);
                } else {
                    // Handle error cases
                    System.debug('S3 Upload Error: ' + res.getBody());
                }
            } catch (Exception ex) {
                // Handle exceptions
                System.debug('Exception during S3 upload: ' + ex.getMessage());
            }
        }

        // Perform any necessary post-processing for successfully uploaded records
        if (!versionsToProcess.isEmpty()) {
            // You can insert records or perform other actions here if needed
        }
    }

    public void finish(Database.BatchableContext context) {
        // Perform any cleanup or finalization tasks if necessary.
    }
}*/