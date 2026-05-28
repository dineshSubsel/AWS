public with sharing class OrgBackupBatch
    implements Database.Batchable<String>, Database.AllowsCallouts, Database.Stateful {

   @TestVisible private String backupType;
@TestVisible private List<String> objectList;
    private String       metadataPayload;
    private String       configPayload;
@TestVisible private List<String> recordIds;

    private Integer      successCount  = 0;
    private Integer      failureCount  = 0;
    private Integer      skippedCount  = 0;
    private List<String> errorMessages = new List<String>();

    private static String getS3BucketUrl() {
        AWS_Settings__c setting = AWS_Settings__c.getInstance();
        return setting != null ? setting.S3_Bucket_URL__c : null;
    }

    private static final Integer RECORD_BATCH_SIZE = 2000;

    // ── Constructor (original — no recordIds) ────────────────────────────────
    public OrgBackupBatch(
        String       backupType,
        List<String> objectList,
        String       metadataPayload,
        String       configPayload
    ) {
        this.backupType      = backupType;
        this.objectList      = objectList != null ? objectList : new List<String>();
        this.metadataPayload = metadataPayload;
        this.configPayload   = configPayload;
        this.recordIds       = new List<String>();
    }

    // ── Constructor (new — with recordIds) ───────────────────────────────────
    public OrgBackupBatch(
        String       backupType,
        List<String> objectList,
        String       metadataPayload,
        String       configPayload,
        List<String> recordIds
    ) {
        this.backupType      = backupType;
        this.objectList      = objectList != null ? objectList : new List<String>();
        this.metadataPayload = metadataPayload;
        this.configPayload   = configPayload;
        this.recordIds       = recordIds != null ? recordIds : new List<String>();
    }

    // ── Batchable interface ──────────────────────────────────────────────────
    public Iterable<String> start(Database.BatchableContext bc) {
        return objectList;
    }

   public void execute(Database.BatchableContext bc, List<String> scope) {
    String objectName = scope[0];
    switch on backupType {
        when 'data' { 
            executeDataBackup(objectName); 
        }
        when 'metadata' { 
            executeMetadataBackup(); 
        }
        when 'config' { 
            executeConfigBackup(); 
        }
        when 'full' { 
            executeFullBackup(objectName); 
        }
        when else {
            skippedCount++;
            errorMessages.add('Unknown backupType: ' + backupType);
        }
    }
}
private void executeMetadataBackup() {
    try {
        if (String.isBlank(metadataPayload)) {
            failureCount++;
            errorMessages.add('Metadata backup failed: No metadata payload provided.');
            return;
        }

        Map<String, Object> parsed =
            (Map<String, Object>) JSON.deserializeUntyped(metadataPayload);

        if (parsed.isEmpty()) {
            failureCount++;
            errorMessages.add('Metadata backup failed: Metadata selection is empty.');
            return;
        }

        String csvContent = buildGroupCsv(parsed);

        if (String.isBlank(csvContent)) {
            failureCount++;
            errorMessages.add('Metadata backup failed: CSV content could not be generated.');
            return;
        }

        String s3Key = 'metadata-backup/metadata_backup_'
            + DateTime.now().format('yyyy-MM-dd_HH-mm-ss') + '.csv';

        uploadToS3(s3Key, csvContent);
        successCount++;

    } catch (Exception e) {
        failureCount++;
        String msg = e.getMessage();
        if (msg != null && msg.contains('|')) {
            msg = msg.substringBefore('|').trim()
                + ' | ' + extractS3ErrorCode(msg);
        }
        errorMessages.add('Metadata backup failed: ' + (msg != null ? msg.left(180) : 'Unknown error'));
    }
}
private void executeConfigBackup() {
    try {
        if (String.isBlank(configPayload)) {
            failureCount++;
            errorMessages.add('Config backup failed: No config payload provided.');
            return;
        }

        Map<String, Object> parsed =
            (Map<String, Object>) JSON.deserializeUntyped(configPayload);

        if (parsed.isEmpty()) {
            failureCount++;
            errorMessages.add('Config backup failed: Config selection is empty.');
            return;
        }

        String csvContent = buildGroupCsv(parsed);

        if (String.isBlank(csvContent)) {
            failureCount++;
            errorMessages.add('Config backup failed: CSV content could not be generated.');
            return;
        }

        String s3Key = 'config-backup/config_backup_'
            + DateTime.now().format('yyyy-MM-dd_HH-mm-ss') + '.csv';

        uploadToS3(s3Key, csvContent);
        successCount++;

    } catch (Exception e) {
        failureCount++;
        String msg = e.getMessage();
        if (msg != null && msg.contains('|')) {
            msg = msg.substringBefore('|').trim()
                + ' | ' + extractS3ErrorCode(msg);
        }
        errorMessages.add('Config backup failed: ' + (msg != null ? msg.left(180) : 'Unknown error'));
    }
}

private void executeFullBackup(String objectName) {
    try {
        // Step 1: backup data records for this object
        if (!objectName.equals('orgfull')) {
            executeDataBackup(objectName);
        }

        // Step 2: backup metadata (only on first scope item)
        if (!String.isBlank(metadataPayload)) {
            Map<String, Object> metaParsed = 
                (Map<String, Object>) JSON.deserializeUntyped(metadataPayload);

            if (!metaParsed.isEmpty()) {
                String metaCsv = buildGroupCsv(metaParsed);
                if (!String.isBlank(metaCsv)) {
                    String metaKey = 'orgfull-backup/metadata_'
                        + DateTime.now().format('yyyy-MM-dd_HH-mm-ss') + '.csv';
                    uploadToS3(metaKey, metaCsv);
                }
            }
        }

        // Step 3: backup config
        if (!String.isBlank(configPayload)) {
            Map<String, Object> cfgParsed = 
                (Map<String, Object>) JSON.deserializeUntyped(configPayload);

            if (!cfgParsed.isEmpty()) {
                String cfgCsv = buildGroupCsv(cfgParsed);
                if (!String.isBlank(cfgCsv)) {
                    String cfgKey = 'orgfull-backup/config_'
                        + DateTime.now().format('yyyy-MM-dd_HH-mm-ss') + '.csv';
                    uploadToS3(cfgKey, cfgCsv);
                }
            }
        }

        successCount++;

    } catch (Exception e) {
        failureCount++;
        errorMessages.add('Org Full backup failed for ' + objectName + ': ' + e.getMessage());
    }
}

// ── Helper to build CSV from group payload ───────────────────────────────────
private static String buildGroupCsv(Map<String, Object> parsed) {
    List<String> lines = new List<String>{ 'GroupKey,ItemName' };
    for (String groupKey : parsed.keySet()) {
        List<Object> items = (List<Object>) parsed.get(groupKey);
        for (Object item : items) {
            lines.add(escapeCsvValue(groupKey) + ',' + escapeCsvValue(String.valueOf(item)));
        }
    }
    return String.join(lines, '\n');
}
public void finish(Database.BatchableContext bc) {
    String status = (failureCount > 0 || !errorMessages.isEmpty()) ? 'Failed' : 'Success';

    String errorSummary = null;
    if (!errorMessages.isEmpty()) {
        List<String> truncated = new List<String>();
        for (String msg : errorMessages) {
            truncated.add(msg.left(200));
        }
        errorSummary = String.join(truncated, ' | ').left(255);
    }

    String objectNameValue;
    if (objectList != null && objectList.size() > 1) {
        objectNameValue = JSON.serialize(objectList);
    } else if (objectList != null && objectList.size() == 1) {
        objectNameValue = objectList[0];
    } else {
        objectNameValue = backupType + '_backup';
    }

    String parentJobId = bc != null ? String.valueOf(bc.getJobId()) : null;

    try {
        File_Recovery_Log__c logRecord = new File_Recovery_Log__c(
            File_Name__c      = '',
            Object_Name__c    = objectNameValue.left(255),
            Action_Type__c    = 'Backup',
            Backup_Time__c    = DateTime.now(),
            Backup_Status__c  = 'Failed',
            Error_Message__c  = errorSummary,
            Parent_Job_Id__c  = parentJobId  
        );
        AWSVaultSectionQueryHelper.sanitizeLogName(logRecord, 'DAT', 'BKP');
        AWSVaultSectionQueryHelper.insertLog(logRecord);
    } catch (Exception logEx) {}
}
    @TestVisible
private void executeDataBackup(String objectName) {
    try {
        List<String> fieldNames = getQueryableFields(objectName);

        if (fieldNames.isEmpty()) {
            skippedCount++;
            return;
        }

        List<SObject> records;
        if (recordIds != null && !recordIds.isEmpty()) {
            records = AWSVaultSectionQueryHelper.getRecordsByQuery(
                objectName, fieldNames, recordIds
            );
        } else {
            records = AWSVaultSectionQueryHelper.getObjectRecords(
                objectName, fieldNames, RECORD_BATCH_SIZE
            );
        }

        if (records.isEmpty()) {
            skippedCount++;
            return;
        }

        String csvContent = buildCsv(fieldNames, records);

        if (String.isBlank(csvContent)) {
            failureCount++;
            errorMessages.add('CSV content is empty for: ' + objectName);
            return;
        }

        String s3Key = 'data-backup/' + objectName + '/'
            + DateTime.now().format('yyyy-MM-dd_HH-mm-ss') + '.csv';

        uploadToS3(s3Key, csvContent);
        successCount++;

    } catch (Exception e) {
        failureCount++;
        String msg = e.getMessage();
        if (msg != null && msg.contains('|')) {
            msg = msg.substringBefore('|').trim()
                + ' | ' + extractS3ErrorCode(msg);
        }
        errorMessages.add(objectName + ': ' + (msg != null ? msg.left(200) : 'Unknown error'));
    }
}
    // ── S3 upload ────────────────────────────────────────────────────────────
    @TestVisible
    private static void uploadToS3(String s3Key, String csvContent) {
        String bucketUrl = getS3BucketUrl();
        if (String.isBlank(bucketUrl)) {
            throw new CalloutException('S3 Bucket URL not configured in AWS_Settings__c');
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

    // ── Field / CSV utilities ────────────────────────────────────────────────
    private static List<String> getQueryableFields(String objectName) {
        List<String> fields = new List<String>();
        try {
            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
            if (objType == null) return fields;
            Map<String, Schema.SObjectField> fieldMap =
                objType.getDescribe().fields.getMap();
            for (String fname : fieldMap.keySet()) {
                Schema.DescribeFieldResult dfr = fieldMap.get(fname).getDescribe();
                if (dfr.getType() == Schema.DisplayType.BASE64) continue;
                if (!dfr.isAccessible()) continue;
                fields.add(dfr.getName());
            }
            fields.sort();
            if (fields.contains('Id')) {
                fields.remove(fields.indexOf('Id'));
                fields.add(0, 'Id');
            }
        } catch (Exception e) {}
        return fields;
    }

    @TestVisible
    private static String buildCsv(List<String> headers, List<SObject> records) {
        List<String> lines = new List<String>{ String.join(headers, ',') };
        lines.addAll(AWSVaultSectionQueryHelper.buildCsvLines(headers, records));
        return String.join(lines, '\n');
    }

    @TestVisible
    private static String escapeCsvValue(Object val) {
        if (val == null) return '';
        String s = String.valueOf(val);
        if (s.contains(',') || s.contains('\n') || s.contains('\r') || s.contains('"')) {
            s = '"' + s.replace('"', '""') + '"';
        }
        return s;
    }
    private static String extractS3ErrorCode(String raw) {
    try {
        String code = '';
        String message = '';
        if (raw.contains('<Code>')) {
            code = raw.substringBetween('<Code>', '</Code>');
        }
        if (raw.contains('<Message>')) {
            message = raw.substringBetween('<Message>', '</Message>');
        }
        if (String.isNotBlank(code) || String.isNotBlank(message)) {
            return code + ': ' + message;
        }
    } catch (Exception e) {}
    return raw.left(100);
}
}