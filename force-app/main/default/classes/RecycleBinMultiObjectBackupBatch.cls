public with sharing class RecycleBinMultiObjectBackupBatch
implements Database.Batchable<SObject>,
           Database.AllowsCallouts,
           Database.Stateful {

 //   private static final String  S3_BUCKET_URL = 'https://sfdcfiles2023.s3-us-west-2.amazonaws.com/';
    private static final Integer RECORD_LIMIT  = 1000;

    private List<String> objectTypes;
    private List<String> recordIds;

    private List<String> allCsvRows    = new List<String>();
    private Integer      successCount  = 0;
    private Integer      failureCount  = 0;
    private List<String> errorMessages = new List<String>();
        private String       objectNamesLabel;  


    public RecycleBinMultiObjectBackupBatch(List<String> objectTypes) {
        this.objectTypes = objectTypes;
                this.objectNamesLabel = String.join(objectTypes, ', ');

    }
    public RecycleBinMultiObjectBackupBatch(List<String> objectTypes, List<String> recordIds) {
        this.objectTypes = objectTypes;
        this.recordIds   = recordIds;
                this.objectNamesLabel = String.join(objectTypes, ', ');
    }

    public RecycleBinMultiObjectBackupBatch(List<String> objectTypes, String objectNamesLabel) {
        this.objectTypes      = objectTypes;
        this.objectNamesLabel = objectNamesLabel;
    }

    public RecycleBinMultiObjectBackupBatch(List<String> objectTypes, List<String> recordIds, String objectNamesLabel) {
        this.objectTypes      = objectTypes;
        this.recordIds        = recordIds;
        this.objectNamesLabel = objectNamesLabel;
    }
    public Iterable<SObject> start(Database.BatchableContext bc) {

        return AwsVaultSectionQueryHelper.fetchDeletedRecords(
            objectTypes,
            recordIds,
            RECORD_LIMIT
        );
    }

   public void execute(Database.BatchableContext bc, List<SObject> scope) {

    if (scope == null || scope.isEmpty()) return;

    Set<Id> userIds = new Set<Id>();
    Set<String> objectTypesInScope = new Set<String>();

    for (SObject rec : scope) {
        if (rec.get('LastModifiedById') != null) {
            userIds.add((Id) rec.get('LastModifiedById'));
        }
        objectTypesInScope.add(rec.getSObjectType().getDescribe().getName());
    }

    Map<Id, String> userMap = AwsVaultSectionQueryHelper.fetchUsers(userIds);
    Map<String, String> objectNameFieldMap =
        AwsVaultSectionQueryHelper.getNameFields(objectTypesInScope);
    for (SObject rec : scope) {
        try {
            String objectType = rec.getSObjectType().getDescribe().getName();
            String nameField = objectNameFieldMap.get(objectType);

            String recId = (String) rec.get('Id');

            String recName = (nameField != null && nameField.equalsIgnoreCase('Id'))
                ? recId
                : String.valueOf(rec.get(nameField));

            DateTime deletedDate = (DateTime) rec.get('LastModifiedDate');
            Id uid = (Id) rec.get('LastModifiedById');

            String deletedBy = userMap.containsKey(uid) ? userMap.get(uid) : '';

            allCsvRows.add(
                escapeCsvValue(recId) + ',' +
                escapeCsvValue(recName) + ',' +
                escapeCsvValue(objectType) + ',' +
                escapeCsvValue(deletedBy) + ',' +
                escapeCsvValue(
                    deletedDate != null
                    ? deletedDate.format('yyyy-MM-dd HH:mm:ss')
                    : ''
                )
            );

            successCount++;
        } catch (Exception e) {
            failureCount++;
            errorMessages.add(e.getMessage());
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
    // Single object via multi batch (shouldn't happen but safety net)
String fileName = objectTypes.size() > 1
    ? 'Backup-Multiple Objects-' + DateTime.now().format('yyyy-MM-dd_HH-mm-ss')
    : 'Backup-' + objectNamesLabel + '-' + DateTime.now().format('yyyy-MM-dd_HH-mm-ss');

    if (allCsvRows.isEmpty()) {
        status  = 'Failed';
        message = 'No deleted records found';
    } else {
        List<String> csvLines = new List<String>{ 'Id,Name,ObjectType,DeletedBy,DeletedDate' };
        csvLines.addAll(allCsvRows);
        String csvContent = String.join(csvLines, '\n');
        s3Key = 'recycle-bin-backup/multi/' + recordName + '.csv';

        try {
            uploadToS3(s3Key, csvContent);
            status  = (failureCount == 0) ? 'Success' : 'Partial';
            message = successCount + ' records uploaded';
        } catch (Exception e) {
            status  = 'Failed';
            message = e.getMessage();
            s3Key   = null;
        }
    }

    try {
        AWSVaultSectionQueryHelper.insertRecycleBinLog(
            new File_Recovery_Log__c(
                Name             = recordName,
                File_Name__c     = fileName,
                Object_Name__c   = objectNamesLabel,
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
            'RecycleBinMultiObjectBackupBatch log insert failed: ' + logEx.getMessage());
    }
}
@TestVisible
    private static void uploadToS3(
    String s3Key,
    String csvContent
){

    AWS_Settings__c setting = AWS_Settings__c.getInstance();
    String bucketUrl = setting != null ? setting.S3_Bucket_URL__c : null;

    if(String.isBlank(bucketUrl)){
        throw new CalloutException('S3 Bucket URL not configured in AWS_Settings__c');
    }

    Blob body = Blob.valueOf(csvContent);

    HttpRequest req = new HttpRequest();
    req.setMethod('PUT');
    req.setEndpoint(
        bucketUrl +
        EncodingUtil.urlEncode(s3Key,'UTF-8')
    );

    req.setHeader('Content-Type','text/csv');
    req.setHeader('Content-Length',
        String.valueOf(body.size())
    );

    req.setBodyAsBlob(body);
    HttpResponse res = new Http().send(req);

    if(res.getStatusCode() != 200 &&
       res.getStatusCode() != 201){

        throw new CalloutException(
            'S3 upload failed : ' +
            res.getBody()
        );
    }
}


    private static String truncate(
        String val,
        Integer maxLen
    ){
        if(val == null) return null;
        return val.length() > maxLen
            ? val.substring(0,maxLen)
            : val;
    }


    @TestVisible
    private static String escapeCsvValue(Object val){
        if(val == null) return '';
        String s = String.valueOf(val);
        if(s.contains(',') ||
           s.contains('"') ||
           s.contains('\n') ||
           s.contains('\r')){

            s = '"' +
                s.replace('"','""') +
                '"';
        }
        return s;
    }
}