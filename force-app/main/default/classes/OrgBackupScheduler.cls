public with sharing class OrgBackupScheduler implements Schedulable {

    private String backupType;       
    private String selectedObjects; 
    private String metadataPayload; 
    private String configPayload;   


    // ── Constructor ──────────────────────────────────────────────────────────
    public OrgBackupScheduler(
        String backupType,
        String selectedObjects,
        String metadataPayload,
        String configPayload
    ) {
        this.backupType      = backupType;
        this.selectedObjects = selectedObjects;
        this.metadataPayload = metadataPayload;
        this.configPayload   = configPayload;
    }

    // ── Schedulable entry point ──────────────────────────────────────────────
    public void execute(SchedulableContext sc) {
        try {
            switch on backupType {
                when 'data'     { executeData();     }
                when 'metadata' { executeMetadata(); }
                when 'config'   { executeConfig();   }
                when 'full'     { executeFull();     }
                when else {
                }
            }
        } catch (Exception e) {
        }
    }

    // ── Data backup ──────────────────────────────────────────────────────────
   private void executeData() {
    List<String> objectList = parseCommaList(selectedObjects);
    if (objectList.isEmpty()) return;
    Database.executeBatch(new OrgBackupBatch('data', objectList, '', ''), 1);
}
private void executeMetadata() {
    if (String.isBlank(metadataPayload)) return;
    Map<String, Object> parsed = parseJsonMap(metadataPayload);
    if (parsed.isEmpty()) return;

    String csvContent = buildGroupCsv(parsed);
    // ✅ Updated file name format
    String fileName = 'Backup-metadata-'
        + DateTime.now().format('yyyy-MM-dd_HH-mm-ss') + '.csv';
    
    uploadGroupToS3('metadata_backup', 'metadata-backup', fileName, csvContent);
}

private void executeConfig() {
    if (String.isBlank(configPayload)) return;
    Map<String, Object> parsed = parseJsonMap(configPayload);
    if (parsed.isEmpty()) return;

    String csvContent = buildGroupCsv(parsed);
    // ✅ Updated file name format
    String fileName = 'Backup-config-'
        + DateTime.now().format('yyyy-MM-dd_HH-mm-ss') + '.csv';
    
    uploadGroupToS3('config_backup', 'config-backup', fileName, csvContent);
}

private void executeFull() {
    List<String> objectList = parseCommaList(selectedObjects);
    Map<String, Object> meta = parseJsonMap(metadataPayload);
    Map<String, Object> config = parseJsonMap(configPayload);
    if (objectList.isEmpty() && meta.isEmpty() && config.isEmpty()) return;

    String csvContent = buildOrgFullCsv(objectList, meta, config);
    // ✅ Updated file name format
    String fileName = 'Backup-orgfull-'
        + DateTime.now().format('yyyy-MM-dd_HH-mm-ss') + '.csv';
    
    uploadGroupToS3('orgfull_backup', 'orgfull-backup', fileName, csvContent);

    if (!objectList.isEmpty()) {
        Database.executeBatch(new OrgBackupBatch('data', objectList, '', ''), 1);
    }
}

 private void uploadGroupToS3(
    String objectType,
    String s3Folder,
    String fileName,       
    String csvContent
) {
    File_Recovery_Log__c log = new File_Recovery_Log__c(
        File_Name__c     = '',          
        Object_Name__c   = objectType,
        S3_Key__c        = null,
        Action_Type__c   = 'Backup',
        Backup_Time__c   = DateTime.now(),
        Backup_Status__c = 'Failed',
        Error_Message__c = null
    );
    AWSVaultSectionQueryHelper.sanitizeLogName(log, 'FIL', 'BKP');

    Id logId = AWSVaultSectionQueryHelper.insertFileRecoveryLog(log);

    if (logId != null) {
        uploadToS3(logId, s3Folder + '/' + fileName, csvContent);
    }
}
    // ── @future callout ──────────────────────────────────────────────────────
@future(callout=true)
private static void uploadToS3(String logId, String s3Key, String csvContent) {

    String errMsg    = null;
    String uploadKey = s3Key;

    try {
        AWS_Settings__c setting = AWS_Settings__c.getInstance();
        String bucketUrl = setting != null ? setting.S3_Bucket_URL__c : null;

        if (String.isBlank(bucketUrl)) {
            throw new CalloutException('S3 Bucket URL not configured in AWS_Settings__c');
        }

        Blob body = Blob.valueOf(csvContent);

        HttpRequest req = new HttpRequest();
        req.setMethod('PUT');
        req.setEndpoint(bucketUrl + EncodingUtil.urlEncode(s3Key, 'UTF-8'));
        req.setHeader('Content-Type', 'text/csv');
        req.setHeader('Content-Length', String.valueOf(body.size()));
        req.setBodyAsBlob(body);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200 && res.getStatusCode() != 201) {
            throw new CalloutException(
                'S3 upload failed. HTTP ' + res.getStatusCode() + ' | ' + res.getBody()
            );
        }

    } catch (Exception e) {
        errMsg    = e.getMessage();
        uploadKey = null;
    }

    // ✅ Always store 'Failed' — UI toast handles success message
    AWSVaultSectionQueryHelper.updateFileRecoveryLog(
        logId,
        uploadKey,
        'Failed',
        errMsg
    );
}
    // ── Utility helpers ──────────────────────────────────────────────────────

    private static String buildGroupCsv(Map<String, Object> parsed) {
    List<String> lines = new List<String>{ 'GroupKey,ItemName' };

    //  call helper method instead of loop
    lines.addAll(
        AWSVaultSectionQueryHelper.buildGroupCsvLines(parsed)
    );

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

    private static List<String> parseCommaList(String input) {
        List<String> result = new List<String>();
        if (String.isBlank(input)) return result;
        for (String s : input.split(',')) {
            String t = s.trim();
            if (!String.isBlank(t)) result.add(t);
        }
        return result;
    }

    private static String buildOrgFullCsv(
    List<String> objectList,
    Map<String, Object> meta,
    Map<String, Object> config
) {
    List<String> lines = new List<String>{ 'Category,GroupKey,ItemName' };

    // call helper instead of loops
    lines.addAll(
        AWSVaultSectionQueryHelper.buildOrgFullCsvLines(objectList, meta, config)
    );

    return String.join(lines, '\n');
}

    private static Map<String, Object> parseJsonMap(String jsonStr) {
        if (String.isBlank(jsonStr)) return new Map<String, Object>();
        return (Map<String, Object>) JSON.deserializeUntyped(jsonStr);
    }
}