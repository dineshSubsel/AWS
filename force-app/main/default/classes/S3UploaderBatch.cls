global with sharing class S3UploaderBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {

    global String  recordId;
    global String  objectType;
    global String  mode;
    global Boolean deleteAfterMigration;
    global Id      initiatedByUserId;
    global static Boolean isAborted     = false;
    global static Set<Id> abortedJobIds = new Set<Id>();
    global Integer successCount = 0;
    global Integer failureCount = 0;
    global Set<Id> contentDocIdsToDelete = new Set<Id>();
    global Set<Id> attachmentIdsToDelete = new Set<Id>();
    global List<File_Recovery_Log__c> logs = new List<File_Recovery_Log__c>();

    public S3UploaderBatch(String objectType, String recordId, String mode, Boolean deleteAfterMigration) {
        this.objectType           = objectType;
        this.recordId             = recordId;
        this.mode                 = mode;
        this.deleteAfterMigration = deleteAfterMigration;
        this.initiatedByUserId    = UserInfo.getUserId();
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {
        if (isAbortedJob(bc)) {
            return AWSVaultSectionQueryHelper.getEmptyLocator();
        }
      if(recordId == null){
           return null;
      }
        if (mode == 'File') {
            Set<Id> docIds = AWSVaultSectionQueryHelper.getContentDocumentIds(recordId);
            return AWSVaultSectionQueryHelper.getContentVersionLocator(docIds);
        }

        if (mode == 'Attachment') {
            return AWSVaultSectionQueryHelper.getAttachmentLocator(recordId);
        }

        throw new AuraHandledException('Invalid mode: must be "File" or "Attachment".');
    }

    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        if (isAbortedJob(bc)) return;

        List<Id> uploadedContentVersionIds = new List<Id>();
        List<Id> uploadedAttachmentIds     = new List<Id>();

        for (SObject sObj : scope) {
            if (isAbortedJob(bc)) break;

            try {
                Boolean uploaded = false;

                if (mode == 'File') {
                    ContentVersion cv = (ContentVersion) sObj;
                    uploaded = uploadFileToS3(cv);
                    if (uploaded) uploadedContentVersionIds.add(cv.Id);
                } else {
                    Attachment att = (Attachment) sObj;
                    uploaded = uploadAttachmentToS3(att);
                    if (uploaded) uploadedAttachmentIds.add(att.Id);
                }

                if (uploaded) successCount++;
                else          failureCount++;

            } catch (Exception e) {
                failureCount++;
            }
        }

        if (deleteAfterMigration && !isAbortedJob(bc)) {
            if (!uploadedContentVersionIds.isEmpty()) {
                Map<Id, Id> versionToDocMap =
                    AWSVaultSectionQueryHelper.getContentDocumentIdsByVersionIds(uploadedContentVersionIds);
                contentDocIdsToDelete.addAll(versionToDocMap.values());
            }
            attachmentIdsToDelete.addAll(uploadedAttachmentIds);
        }
    }

    global void finish(Database.BatchableContext bc) {
        if (isAbortedJob(bc)) {
            return;
        }
        AWSVaultSectionQueryHelper.insertLogs(logs);
        if (deleteAfterMigration) {
            deleteFiles();
        }
    }
@TestVisible
   private Boolean uploadFileToS3(ContentVersion cv) {
    String s3Key = objectType + '/' + recordId + '/' + cv.Title + '.' + cv.FileExtension;

    try {
        HttpResponse res = makeS3Request(s3Key, cv.VersionData, cv.FileExtension);
        Boolean success  = res.getStatusCode() == 200 || res.getStatusCode() == 201;

        logs.add(new File_Recovery_Log__c(
            Name                   = AWSVaultSectionQueryHelper.generateLogFileName('FIL', 'BKP'),
            File_Name__c           = cv.Title,
            Content_Document_Id__c = cv.ContentDocumentId,
            S3_Key__c              = s3Key,
            Record_Id__c           = recordId,
            Object_Name__c         = objectType,
            Action_Type__c         = 'Backup',
            Backup_Time__c         = DateTime.now(),
            Backup_Status__c       = success ? 'Success' : 'Failed',
            Error_Message__c       = success ? null : ('HTTP ' + res.getStatusCode() + ' | ' + res.getBody())
        ));

        return success;

    } catch (Exception e) {
        logs.add(new File_Recovery_Log__c(
            Name                   = AWSVaultSectionQueryHelper.generateLogFileName('FIL', 'BKP'),
            File_Name__c           = cv.Title,
            Content_Document_Id__c = cv.ContentDocumentId,
            S3_Key__c              = s3Key,
            Record_Id__c           = recordId,
            Object_Name__c         = objectType,
            Action_Type__c         = 'Backup',
            Backup_Time__c         = DateTime.now(),
            Backup_Status__c       = 'Failed',
            Error_Message__c       = e.getMessage()
        ));
        return false;
    }
}
@TestVisible
   private Boolean uploadAttachmentToS3(Attachment att) {
    String ext   = getExtensionFromFilename(att.Name);
    String s3Key = objectType + '/' + recordId + '/' + att.Name;

    try {
        HttpResponse res = makeS3Request(s3Key, att.Body, ext != null ? ext : 'bin');
        Boolean success  = res.getStatusCode() == 200 || res.getStatusCode() == 201;

        logs.add(new File_Recovery_Log__c(
            Name             = AWSVaultSectionQueryHelper.generateLogFileName('FIL', 'BKP'),
            File_Name__c     = att.Name,
            S3_Key__c        = s3Key,
            Record_Id__c     = recordId,
            Object_Name__c   = objectType,
            Action_Type__c   = 'Backup',
            Backup_Time__c   = DateTime.now(),
            Backup_Status__c = success ? 'Success' : 'Failed',
            Error_Message__c = success ? null : ('HTTP ' + res.getStatusCode() + ' | ' + res.getBody())
        ));

        return success;

    } catch (Exception e) {
        logs.add(new File_Recovery_Log__c(
            Name             = AWSVaultSectionQueryHelper.generateLogFileName('FIL', 'BKP'),
            File_Name__c     = att.Name,
            S3_Key__c        = s3Key,
            Record_Id__c     = recordId,
            Object_Name__c   = objectType,
            Action_Type__c   = 'Backup',
            Backup_Time__c   = DateTime.now(),
            Backup_Status__c = 'Failed',
            Error_Message__c = e.getMessage()
        ));
        return false;
    }
}
@TestVisible
  private HttpResponse makeS3Request(String s3Key, Blob fileBlob, String fileExtension) {
    AWS_Settings__c setting = AWS_Settings__c.getInstance();
    String bucketUrl = setting != null ? setting.S3_Bucket_URL__c : null;

    if(String.isBlank(bucketUrl)){
        throw new CalloutException('S3 Bucket URL not configured in AWS_Settings__c');
    }

    HttpRequest req = new HttpRequest();
    req.setMethod('PUT');
  req.setEndpoint(
    (bucketUrl.endsWith('/') ? bucketUrl : bucketUrl + '/') +
    EncodingUtil.urlEncode(s3Key, 'UTF-8')
);

    req.setHeader('Content-Type', getContentTypeFromExtension(fileExtension));
    req.setBodyAsBlob(fileBlob);

    return new Http().send(req);
}

    private void deleteFiles() {
        AWSVaultSectionQueryHelper.deleteContentDocuments(contentDocIdsToDelete);
        AWSVaultSectionQueryHelper.deleteAttachments(attachmentIdsToDelete);
    }

    private Boolean isAbortedJob(Database.BatchableContext bc) {
        return isAborted || abortedJobIds.contains(bc.getJobId());
    }

    global static void abortAllJobs() {
        isAborted = true;
        for (AsyncApexJob job : AWSVaultSectionQueryHelper.getRunningBatchJobs()) {
            abortedJobIds.add(job.Id);
            try {
                System.abortJob(job.Id);
            } catch (Exception e) {
            }
        }
    }
@TestVisible
    private static String getContentTypeFromExtension(String extension) {
        Map<String, String> contentTypes = new Map<String, String>{
            'jpg'  => 'image/jpeg',
            'jpeg' => 'image/jpeg',
            'png'  => 'image/png',
            'gif'  => 'image/gif',
            'pdf'  => 'application/pdf',
            'txt'  => 'text/plain',
            'csv'  => 'text/csv',
            'doc'  => 'application/msword',
            'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'xls'  => 'application/vnd.ms-excel',
            'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'bin'  => 'application/octet-stream'
        };
        String key = extension != null ? extension.toLowerCase() : 'bin';
        return contentTypes.containsKey(key) ? contentTypes.get(key) : 'application/octet-stream';
    }

    private static String getExtensionFromFilename(String filename) {
        return String.isNotBlank(filename) && filename.contains('.')
            ? filename.substringAfterLast('.')
            : null;
    }
}