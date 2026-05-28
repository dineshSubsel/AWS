public with sharing class S3Uploader {

    public class S3UploadJob implements Queueable, Database.AllowsCallouts {
        private Map<String, Object[]> uploadMap;
        public S3UploadJob(Map<String, Object[]> uploadMap) {
            this.uploadMap = uploadMap;
        }
        public void execute(QueueableContext context) {
            if (uploadMap.isEmpty()) return;

            String s3Key      = new List<String>(uploadMap.keySet())[0];
            Object[] fileData = uploadMap.remove(s3Key);

            Blob   fileBlob      = (Blob)   fileData[0];
            String fileExtension = (String) fileData[1];

            fileuploadToS3(s3Key, fileBlob, fileExtension);

            if (!uploadMap.isEmpty()) {
                System.enqueueJob(new S3UploadJob(uploadMap));
            }
        }
    }

    private static AWS_Settings__c getAWSSettings() {
        AWS_Settings__c settings = AWS_Settings__c.getOrgDefaults();
        if (settings == null
            || String.isBlank(settings.S3_Bucket_Name__c)
            || String.isBlank(settings.S3_Region_Name__c)) {
            throw new AuraHandledException(
                'AWS Settings are not configured. Please set up AWS_Settings__c custom setting.'
            );
        }
        return settings;
    }

    @AuraEnabled
    public static String migrateFilesToS3(String objectType, String recordId) {
        if (objectType == null || recordId == null) return null;

        List<ContentDocumentLink> links =
            AWSVaultSectionQueryHelper.getContentDocumentLinks(recordId);

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink link : links) {
            docIds.add(link.ContentDocumentId);
        }

        List<ContentVersion> versions =
            AWSVaultSectionQueryHelper.getLatestContentVersionRecords(docIds);

        Map<String, Object[]> uploadMap = new Map<String, Object[]>();
        for (ContentVersion ver : versions) {
            String s3Key = objectType + '/' + recordId + '/' + ver.Title + '.' + ver.FileExtension;
            uploadMap.put(s3Key, new Object[]{ ver.VersionData, ver.FileExtension });
        }

        if (!uploadMap.isEmpty()) {
            System.enqueueJob(new S3UploadJob(uploadMap));
        }

        return 'Files migration queued successfully';
    }

    @AuraEnabled
    public static String migrateAttachmentsToS3(String objectType, String recordId) {
        if (objectType == null || recordId == null) return null;

        List<Attachment> attachments =
            AWSVaultSectionQueryHelper.getAttachments(recordId);

        Map<String, Object[]> uploadMap = new Map<String, Object[]>();
        for (Attachment att : attachments) {
            String s3Key = objectType + '/' + recordId + '/' + att.Name;
            uploadMap.put(s3Key, new Object[]{
                att.Body,
                (String.isNotBlank(att.Name) && att.Name.contains('.'))
                    ? att.Name.substringAfterLast('.')
                    : 'bin'
            });
        }

        if (!uploadMap.isEmpty()) {
            System.enqueueJob(new S3UploadJob(uploadMap));
        }

        return 'Attachments migration queued successfully';
    }

    private static void fileuploadToS3(String s3Key, Blob fileBlob, String fileExtension) {
        AWS_Settings__c awsSettings = getAWSSettings();
        String bucketName = awsSettings.S3_Bucket_Name__c;
        String region     = awsSettings.S3_Region_Name__c;

        String endpoint = 'https://' + bucketName + '.s3.' + region + '.amazonaws.com/'
                        + EncodingUtil.urlEncode(s3Key, 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setMethod('PUT');
        req.setEndpoint(endpoint);
        req.setHeader('Content-Type', getContentTypeFromExtension(fileExtension));
        req.setBodyAsBlob(fileBlob);

        HttpResponse res = new Http().send(req);

         if (res.getStatusCode() != 200 && res.getStatusCode() != 201) {
        throw new AuraHandledException(
            'S3 upload failed for ' + s3Key +
            ' | Status: ' + res.getStatus() +
            ' | Body: ' + res.getBody()
        );
    }
    }

    private static String getContentTypeFromExtension(String extension) {
        Map<String, String> contentTypes = new Map<String, String>{
            'jpg'  => 'image/jpeg',
            'jpeg' => 'image/jpeg',
            'png'  => 'image/png',
            'pdf'  => 'application/pdf',
            'txt'  => 'text/plain',
            'doc'  => 'application/msword',
            'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'xls'  => 'application/vnd.ms-excel',
            'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'bin'  => 'application/octet-stream'
        };
        extension = extension != null ? extension.toLowerCase() : 'bin';
        return contentTypes.containsKey(extension) ? contentTypes.get(extension) : 'application/octet-stream';
    }
}