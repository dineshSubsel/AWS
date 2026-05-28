global with sharing class S3BackupBatch implements Database.Batchable<SObject>,
                                       Database.AllowsCallouts,
                                       Database.Stateful {

    private static final Map<String, String> CONTENT_TYPES =
        new Map<String, String>{
            'jpg'  => 'image/jpeg',
            'jpeg' => 'image/jpeg',
            'png'  => 'image/png',
            'pdf'  => 'application/pdf',
            'txt'  => 'text/plain',
            'doc'  => 'application/msword',
            'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        };

    global final String       objectType;
    global final List<String> recordIds;
    global final String       mode;
    global final Boolean      deleteAfterMigration;
    global final DateTime     backupTime;

    // ── shared across all chained batches ────────────────────────────────────
    global final String       sharedJobName;
    global final List<String> allObjectNames;
    global final Integer      currentObjectIndex;
    global final List<String> allRecordIds;

    global static Boolean isAborted     = false;
    global static Set<Id> abortedJobIds = new Set<Id>();

    global Integer      successCount   = 0;
    global Integer      failureCount   = 0;
    global List<String> errorMessages  = new List<String>();
    global List<String> allCsvRows     = new List<String>();
    global Set<Id>      resolvedDocIds = new Set<Id>();

    // ── constructor for multi-object chaining ─────────────────────────────────
    public S3BackupBatch(
        String       objectType,
        List<String> recordIds,
        String       mode,
        Boolean      deleteAfterMigration,
        DateTime     backupTime,
        String       sharedJobName,
        List<String> allObjectNames,
        Integer      currentObjectIndex
    ) {
        this.objectType           = objectType;
        this.recordIds            = recordIds;
        this.mode                 = mode;
        this.deleteAfterMigration = deleteAfterMigration;
        this.backupTime           = backupTime;
        this.sharedJobName        = sharedJobName;
        this.allObjectNames       = allObjectNames;
        this.currentObjectIndex   = currentObjectIndex;
        this.allRecordIds         = null;
    }

    // ── original constructor (single object, no chaining) ─────────────────────
    public S3BackupBatch(
        String       objectType,
        List<String> recordIds,
        String       mode,
        Boolean      deleteAfterMigration,
        DateTime     backupTime
    ) {
        this(objectType, recordIds, mode, deleteAfterMigration, backupTime, null, null, 0);
    }

    // ─── START ───────────────────────────────────────────────────────────────

    global Database.QueryLocator start(Database.BatchableContext bc) {

        if (isJobAborted(bc.getJobId())) {
            return AWSVaultSectionQueryHelper.getLatestContentVersions(new Set<Id>());
        }

        if (mode == 'File') {

            // ── FIX 1: if no recordIds passed, fetch ALL records for the object ──
            Set<Id> recordIdSet = new Set<Id>();

            if (recordIds != null && !recordIds.isEmpty()) {
                // specific records selected by user
                for (String rid : recordIds) {
                    try { recordIdSet.add(Id.valueOf(rid)); } catch (Exception e) { }
                }
            } else {
                // NO records selected → backup ALL records for this object
                List<String> allIds =
                    AWSQuerySharingHelper.getAllRecordIdsByObjectName(objectType);
                if (allIds != null) {
                    for (String rid : allIds) {
                        try { recordIdSet.add(Id.valueOf(rid)); } catch (Exception e) { }
                    }
                }
            }

            if (recordIdSet.isEmpty()) {
                // Truly no records exist for this object
                return AWSVaultSectionQueryHelper.getLatestContentVersions(new Set<Id>());
            }

            resolvedDocIds =
                AWSVaultSectionQueryHelper.getContentDocumentIdsByRecordIds(recordIdSet);

            if (resolvedDocIds.isEmpty()) {
                return AWSVaultSectionQueryHelper.getLatestContentVersions(new Set<Id>());
            }

            return AWSVaultSectionQueryHelper.getLatestContentVersions(resolvedDocIds);
        }

        return AWSVaultSectionQueryHelper.getLatestContentVersions(new Set<Id>());
    }

    // ─── EXECUTE ─────────────────────────────────────────────────────────────

    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        if (isJobAborted(bc.getJobId())) return;

        for (SObject sObj : scope) {
            try {
                ContentVersion cv             = (ContentVersion) sObj;
                String         parentRecordId = cv.FirstPublishLocationId;
                String         s3Key          = objectType + '/' + parentRecordId + '/'
                                              + cv.Title + '.' + cv.FileExtension;

                Boolean success = uploadToS3(cv, s3Key);

                allCsvRows.add(
                    escapeCsvValue(cv.Title)                             + ',' +
                    escapeCsvValue(s3Key)                                + ',' +
                    escapeCsvValue(success ? 'Success' : 'Failed')      + ',' +
                    escapeCsvValue(String.valueOf(bc.getJobId()))        + ',' +
                    escapeCsvValue(parentRecordId)                       + ',' +
                    escapeCsvValue('false')                              + ',' +
                    escapeCsvValue(objectType)                           + ',' +
                    escapeCsvValue(String.valueOf(cv.ContentDocumentId)) + ',' +
                    escapeCsvValue(success ? '' : 'Upload failed')      + ',' +
                    escapeCsvValue('Backup')                             + ',' +
                    escapeCsvValue('')                                   + ',' +
                    escapeCsvValue('')                                   + ',' +
                    escapeCsvValue(DateTime.now().format('yyyy-MM-dd HH:mm:ss'))
                );

                if (success) successCount++;
                else {
                    failureCount++;
                    errorMessages.add('Failed: ' + cv.Title);
                }

            } catch (Exception e) {
                failureCount++;
                errorMessages.add('Row error: ' + e.getMessage());
            }
        }
    }

    // ─── FINISH ──────────────────────────────────────────────────────────────

 global void finish(Database.BatchableContext bc) {
    String s3CsvKey = null;

    if (!allCsvRows.isEmpty()) {
        List<String> csvLines = new List<String>{
            'File_Name__c,S3_Key__c,Backup_Status__c,Parent_Job_Id__c,' +
            'Record_Id__c,Recycle_Bin__c,Object_Name__c,Content_Document_Id__c,' +
            'Error_Message__c,Action_Type__c,Restore_Status__c,Restore_Time__c,Backup_Time__c'
        };
        csvLines.addAll(allCsvRows);

        s3CsvKey = 'backup-reports/' + sharedJobName + '/'
                 + objectType + '_'
                 + DateTime.now().format('yyyy-MM-dd_HH-mm-ss') + '.csv';

        try {
            uploadCsvToS3(s3CsvKey, String.join(csvLines, '\n'));
        } catch (Exception e) {
            s3CsvKey = null;
            errorMessages.add('CSV upload failed: ' + e.getMessage());
        }
    }
    Integer objectNamesSize = 0;
    if (allObjectNames != null) {
        for (String name : allObjectNames) {
            objectNamesSize++;
        }
    }

    Boolean isLastObject;
    if (objectNamesSize == 0) {
        isLastObject = true;
    } else {
        isLastObject = (currentObjectIndex >= objectNamesSize - 1);
    }

    if (isLastObject) {

        String objectLabel;
        if (objectNamesSize <= 1) {
            objectLabel = objectType;
        } else {
            objectLabel = JSON.serialize(allObjectNames);
        }

        String fileNameValue;
        if (objectNamesSize <= 1) {
            fileNameValue = 'Backup-' + objectType + '-'
                          + DateTime.now().format('yyyy-MM-dd_HH-mm-ss');
        } else {
            fileNameValue = 'Backup-Multiple Objects-'
                          + DateTime.now().format('yyyy-MM-dd_HH-mm-ss');
        }

        List<String> safeErrors = (errorMessages != null)
            ? errorMessages
            : new List<String>();

        String status;
        String message;

        if (successCount == 0 && failureCount == 0) {
            status  = 'Failed';
            message = 'No files found for the selected records. Nothing was backed up.';
        } else {
            status  = failureCount == 0 ? 'Success'
                    : (successCount == 0 ? 'Failed' : 'Partial');
            message = successCount + ' file(s) backed up successfully'
                    + (failureCount > 0
                        ? '. Failures: ' + String.join(safeErrors, ' | ')
                        : '');
        }

        File_Recovery_Log__c log = new File_Recovery_Log__c(
            Name             = AWSVaultSectionQueryHelper.generateLogFileName('FIL', 'BKP'),
            File_Name__c     = fileNameValue,
            Object_Name__c   = objectLabel,
            S3_Key__c        = s3CsvKey,
            Action_Type__c   = 'Backup',
            Backup_Time__c   = DateTime.now(),
            Backup_Status__c = 'Failed',
            Recycle_Bin__c   = false,
            Error_Message__c = truncate(message, 255),
            Parent_Job_Id__c = String.valueOf(bc.getJobId())
        );

        AWSVaultSectionQueryHelper.insertBackupLog(log);

    } else {

        Integer nextIndex = currentObjectIndex + 1;

        if (nextIndex >= objectNamesSize) {
            return;
        }

        String       nextObject = allObjectNames[nextIndex];
        List<String> nextIds    = AWSQuerySharingHelper.getAllRecordIdsByObjectName(nextObject);

        S3BackupBatch nextBatch = new S3BackupBatch(
            nextObject, nextIds, 'File', false, DateTime.now(),
            sharedJobName, allObjectNames, nextIndex
        );
        Database.executeBatch(nextBatch, 10);
    }
}
    // ─── S3 File Upload (per ContentVersion) ──────────────────────────────────

    @TestVisible
    private Boolean uploadToS3(ContentVersion cv, String s3Key) {
        try {
            AWS_Settings__c setting   = AWS_Settings__c.getInstance();
            String          bucketUrl = setting != null ? setting.S3_Bucket_URL__c : null;

            if (String.isBlank(bucketUrl)) {
                throw new CalloutException('S3 Bucket URL not configured');
            }

            HttpRequest req = new HttpRequest();
            req.setMethod('PUT');
            req.setEndpoint(bucketUrl + EncodingUtil.urlEncode(s3Key, 'UTF-8'));
            req.setHeader('Content-Type', resolveContentType(cv.FileExtension));
            req.setBodyAsBlob(cv.VersionData);

            HttpResponse res = new Http().send(req);
            return res.getStatusCode() == 200 || res.getStatusCode() == 201;

        } catch (Exception e) {
            return false;
        }
    }

    // ─── S3 CSV Report Upload ─────────────────────────────────────────────────

    @TestVisible
    private static void uploadCsvToS3(String s3Key, String csvContent) {
        AWS_Settings__c setting   = AWS_Settings__c.getInstance();
        String          bucketUrl = setting != null ? setting.S3_Bucket_URL__c : null;

        if (String.isBlank(bucketUrl)) {
            throw new CalloutException('S3 Bucket URL not configured');
        }

        Blob body = Blob.valueOf(csvContent);

        HttpRequest req = new HttpRequest();
        req.setMethod('PUT');
        req.setEndpoint(bucketUrl + EncodingUtil.urlEncode(s3Key, 'UTF-8'));
        req.setHeader('Content-Type',   'text/csv');
        req.setHeader('Content-Length', String.valueOf(body.size()));
        req.setBodyAsBlob(body);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200 && res.getStatusCode() != 201) {
            throw new CalloutException(
                'S3 upload failed. HTTP ' + res.getStatusCode() + ' | ' + res.getBody()
            );
        }
    }

    // ─── Abort Check ──────────────────────────────────────────────────────────

    private Boolean isJobAborted(Id jobId) {
        return isAborted || abortedJobIds.contains(jobId);
    }

    // ─── Content Type ─────────────────────────────────────────────────────────

    @TestVisible
    private static String resolveContentType(String extension) {
        String ext = extension?.toLowerCase();
        return CONTENT_TYPES.containsKey(ext)
            ? CONTENT_TYPES.get(ext)
            : 'application/octet-stream';
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private static String truncate(String val, Integer maxLen) {
        if (val == null) return null;
        return val.length() > maxLen ? val.substring(0, maxLen) : val;
    }

    @TestVisible
    private static String escapeCsvValue(Object val) {
        if (val == null) return '';
        String s = String.valueOf(val);
        if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
            s = '"' + s.replace('"', '""') + '"';
        }
        return s;
    }
}