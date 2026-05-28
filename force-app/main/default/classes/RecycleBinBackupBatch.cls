public with sharing class RecycleBinBackupBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {

// private static final String  S3_BUCKET_URL = 'https://sfdcfiles2023.s3-us-west-2.amazonaws.com/';
private static final Integer RECORD_LIMIT  = 1000;

private String       objectType;
    private String       objectLabel;  // ← ADD THIS
private List<String> recordIds;

private List<String> allCsvRows    = new List<String>();
private Integer      successCount  = 0;
private Integer      failureCount  = 0;
private List<String> errorMessages = new List<String>();

public RecycleBinBackupBatch(String objectType) {
    this.objectType = objectType;
            this.objectLabel = objectType;
    this.recordIds  = null;
}

public RecycleBinBackupBatch(String objectType, List<String> recordIds) {
    this.objectType = objectType;
            this.objectLabel = objectType;
    this.recordIds  = (recordIds != null && !recordIds.isEmpty()) ? recordIds : null;
}

public RecycleBinBackupBatch(String objectType, String objectLabel) {
        this.objectType  = objectType;
        this.objectLabel = objectLabel;
        this.recordIds   = null;
    }

    public RecycleBinBackupBatch(String objectType, List<String> recordIds, String objectLabel) {
        this.objectType  = objectType;
        this.objectLabel = objectLabel;
        this.recordIds   = (recordIds != null && !recordIds.isEmpty()) ? recordIds : null;
    }

public Iterable<SObject> start(Database.BatchableContext bc) {
    String nameField    = getNameField(objectType);
    String selectFields = 'Id, LastModifiedById, LastModifiedDate';

    if (!nameField.equalsIgnoreCase('id')) {
        selectFields += ', ' + nameField;
    }

    String query = 'SELECT ' + selectFields
                    + ' FROM '  + objectType
                    + ' WHERE IsDeleted = true';

    if (recordIds != null && !recordIds.isEmpty()) {
        query += ' AND Id IN (\'' + String.join(recordIds, '\',\'') + '\')';
    }

    query += ' LIMIT ' + RECORD_LIMIT + ' ALL ROWS';

    return AWSVaultSectionQueryHelper.getDeletedRecordsForBackup(
objectType,
selectFields,
recordIds,
RECORD_LIMIT
);
}

public void execute(Database.BatchableContext bc, List<SObject> scope) {
    if (scope == null || scope.isEmpty()) return;

    Set<Id> userIds = new Set<Id>();
    for (SObject rec : scope) {
        Id uid = (Id) rec.get('LastModifiedById');
        if (uid != null) userIds.add(uid);
    }

    Map<Id, String> userNameMap = new Map<Id, String>();

if (!userIds.isEmpty()) {
for (User u : AWSVaultSectionQueryHelper.getUsersByIds(userIds)) {
    userNameMap.put(u.Id, u.Name);
}
}

    String nameField = getNameField(objectType);

    for (SObject rec : scope) {
        try {
            String   recId       = (String)   rec.get('Id');
            String   recName     = nameField.equalsIgnoreCase('id')
                                        ? recId
                                        : (String) rec.get(nameField);
            DateTime deletedDate = (DateTime) rec.get('LastModifiedDate');
            Id       uid         = (Id)       rec.get('LastModifiedById');
            String   deletedBy   = userNameMap.containsKey(uid)
                                        ? userNameMap.get(uid)
                                        : (uid != null ? String.valueOf(uid) : '');

            allCsvRows.add(
                escapeCsvValue(recId)      + ',' +
                escapeCsvValue(recName)    + ',' +
                escapeCsvValue(objectType) + ',' +
                escapeCsvValue(deletedBy)  + ',' +
                escapeCsvValue(deletedDate != null
                    ? deletedDate.format('yyyy-MM-dd HH:mm:ss') : '')
            );

            successCount++;

        } catch (Exception e) {
            failureCount++;
            errorMessages.add('Row error: ' + e.getMessage());
        }
    }
}
public void finish(Database.BatchableContext bc) {
    try {
        AsyncApexJob job = AWSVaultSectionQueryHelper.getJobById(bc.getJobId());
        if (job != null && job.Status == 'Aborted') return;
    } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, 'Could not fetch job status: ' + e.getMessage());
    }

    String status;
    String message;
    String s3Key = null;

    String timestamp    = DateTime.now().format('yyyyMMdd-HHmmss');
    String randomSuffix = String.valueOf((Integer)(Math.random() * 9000) + 1000);
    String recordName   = 'RB-BKP-' + timestamp + '-' + randomSuffix;
    
    // File_Name__c = Backup-<ObjectLabel>-<datetime>
    String fileName = 'Backup-' + objectLabel + '-' + DateTime.now().format('yyyy-MM-dd_HH-mm-ss');

    if (allCsvRows.isEmpty()) {
        status  = 'Failed';
        message = 'No deleted records found for the selected object types.';
    } else {
        List<String> csvLines = new List<String>{ 'Id,Name,ObjectType,DeletedBy,DeletedDate' };
        csvLines.addAll(allCsvRows);
        String csvContent = String.join(csvLines, '\n');
        s3Key = 'recycle-bin-backup/multi/' + recordName + '.csv';

        try {
            uploadToS3(s3Key, csvContent);
            status  = (failureCount == 0) ? 'Success' : 'Partial';
            message = successCount + ' record(s) uploaded successfully'
                + (failureCount > 0
                    ? '. Failures: ' + String.join(errorMessages, ' | ')
                    : '');
        } catch (Exception e) {
            status  = 'Failed';
            message = 'S3 upload failed: ' + e.getMessage();
            s3Key   = null;
        }
    }

    try {
        AWSVaultSectionQueryHelper.insertRecycleBinLog(
            new File_Recovery_Log__c(
                Name             = recordName,
                File_Name__c     = fileName,
                Object_Name__c   = objectLabel,
                S3_Key__c        = s3Key,
                Action_Type__c   = 'Backup',
                Backup_Time__c   = DateTime.now(),
                Backup_Status__c = 'Failed',
                Recycle_Bin__c   = true,
                Parent_Job_Id__c = String.valueOf(bc.getJobId()),
                Error_Message__c = truncate(message, 255)
            )
        );
    } catch (Exception logEx) {
        System.debug(LoggingLevel.ERROR,
            'RecycleBinBackupBatch log insert failed: ' + logEx.getMessage());
    }
}
@TestVisible
private static void uploadToS3(String s3Key, String csvContent) {
AWS_Settings__c setting = AWS_Settings__c.getInstance();
String bucketUrl = setting != null ? setting.S3_Bucket_URL__c : null;

if(String.isBlank(bucketUrl)){
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

private static String getNameField(String apiName) {
    Map<String, Schema.SObjectField> fields =
        Schema.getGlobalDescribe()
                .get(apiName.toLowerCase())
                .getDescribe().fields.getMap();

    for (String f : new List<String>{ 'name', 'subject', 'title', 'casenumber', 'contractnumber' }) {
        if (fields.containsKey(f)) return f;
    }
    return 'id';
}

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