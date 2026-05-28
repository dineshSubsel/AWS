public with sharing class RecycleBinVaultController {

    private static final Set<String> ACTIVE_STATUSES = new Set<String>{
        'Queued', 'Holding', 'Preparing', 'Processing'
    };

    private static Map<String, Schema.SObjectType> gdCache;
    private static Map<String, Schema.DescribeSObjectResult> describeCache;

private static Map<String, Schema.SObjectType> getGD() {
    if (gdCache == null) {
        gdCache = Schema.getGlobalDescribe();
    } 
    
    return gdCache;
}

private static Map<String, Schema.DescribeSObjectResult> getDescribeCache() {
    if (describeCache == null) {
        describeCache = new Map<String, Schema.DescribeSObjectResult>();

        Map<String, Schema.SObjectType> gd = new Map<String, Schema.SObjectType>();

        if (gdCache == null) {
           gd =  getGD(); 
        } else {
            gd = gdCache;
        }

        for (String api : gd.keySet()) {
            describeCache.put(api, gd.get(api).getDescribe()); 
        }
    }
    return describeCache;
}
private static Set<String> allowedObjectTypes;
private static Set<String> getAllowedApiNames() {
    if (allowedObjectTypes == null) {
        allowedObjectTypes = new Set<String>();

        Map<String, Schema.SObjectType> gd = new Map<String, Schema.SObjectType>();

        if (gdCache == null) {
           gd =  getGD(); 
        } else {
            gd = gdCache;
        } 

        for (Schema.SObjectType objType : gd.values()) {
            Schema.DescribeSObjectResult d = objType.getDescribe();

            if (!d.isQueryable() || !d.isDeletable()) continue;

            String name = d.getName().toLowerCase();

            if (name.endsWith('__mdt') ||
                name.endsWith('__e') ||
                name.endsWith('__b') ||
                name.endsWith('__x') ||
                name.endsWith('history') ||
                name.endsWith('share') ||
                name.endsWith('feed') ||
                name.endsWith('changeevent')) {
                continue;
            }

            allowedObjectTypes.add(d.getName());
        }
    }

    return allowedObjectTypes;
}

    public class RecycleBinRecord {
        @AuraEnabled public String   id;
        @AuraEnabled public String   name;
        @AuraEnabled public String   objectType;
        @AuraEnabled public String   deletedBy;
        @AuraEnabled public DateTime deletedDate;
    }

    public class BackupJobStatus {
        @AuraEnabled public String  jobId;
        @AuraEnabled public String  status;
        @AuraEnabled public String  startTime;
        @AuraEnabled public String  progress;
        @AuraEnabled public Boolean isDone;
    }

    private static String getNameField(String apiName) {
    if (String.isBlank(apiName)) return 'Id';

    Schema.SObjectType objType = getGD().get(apiName);
    if (objType == null) return 'Id';

    Map<String, Schema.SObjectField> fields =
        objType.getDescribe().fields.getMap();

    if (fields.containsKey('Name'))           return 'Name';
    if (fields.containsKey('Subject'))        return 'Subject';
    if (fields.containsKey('Title'))          return 'Title';
    if (fields.containsKey('CaseNumber'))     return 'CaseNumber';
    if (fields.containsKey('ContractNumber')) return 'ContractNumber';

    return 'Id';
}

private static Map<String, String> getLabelToApiMap() {

    Map<String, String> mapResult = new Map<String, String>();
    Map<String, Schema.DescribeSObjectResult> cache = getDescribeCache();

    for (String api : cache.keySet()) {
        Schema.DescribeSObjectResult d = cache.get(api);
        if (d != null) {
            mapResult.put(d.getLabel().toLowerCase(), d.getName());
        }
    }

    return mapResult;
}
   private static void validateObjectType(String objectType) {
    
    if (allowedObjectTypes == null || allowedObjectTypes.isEmpty()) {
        getAllowedApiNames();
    }
    if (String.isBlank(objectType)) {
        throw new AuraHandledException('Object type cannot be blank.');
    }

    if (!allowedObjectTypes.contains(objectType)) {
        throw new AuraHandledException('Invalid object type: ' + objectType);
    }
}

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getSupportedObjectTypes() {

        List<String> sorted = new List<String>(getAllowedApiNames());
        sorted.sort();

        List<Map<String, String>> result = new List<Map<String, String>>();

        for (String api : sorted) {

            Schema.DescribeSObjectResult d = getDescribeCache().get(api);

            String label = (d != null) ? d.getLabel() : api;

            result.add(new Map<String, String>{
                'label' => label + ' (' + api + ')',
                'value' => api
            });
        }

        return result;
    }
@AuraEnabled
public static List<Map<String, Object>> getDeletedRecordCounts() {
    Map<String, Integer> deCountByLabel = new Map<String, Integer>();
    for (DeleteEvent de : AWSVaultSectionQueryHelper.getDeleteEvents()) {
        String lbl = de.SobjectName;
        deCountByLabel.put(
            lbl,
            deCountByLabel.containsKey(lbl)
                ? deCountByLabel.get(lbl) + 1
                : 1
        );
    }
    if (deCountByLabel.isEmpty()) {
        return new List<Map<String, Object>>();
    }

    Map<String, String> labelToApi = getLabelToApiMap();
    Set<String> apiNames = new Set<String>();
    for (String lbl : deCountByLabel.keySet()) {
        String apiName = labelToApi.get(lbl.toLowerCase());
        if (String.isNotBlank(apiName)) {
            apiNames.add(apiName);
        }
    }

    Map<String, Integer> deletedCounts =
        AWSVaultSectionQueryHelper.countDeletedRecordsBulk(apiNames);
    List<Map<String, Object>> result = new List<Map<String, Object>>();
    for (String lbl : deCountByLabel.keySet()) {
        String apiName = labelToApi.get(lbl.toLowerCase());
        if (String.isBlank(apiName)) {
            continue;
        }
        Integer cnt = deletedCounts.containsKey(apiName)
            ? deletedCounts.get(apiName)
            : deCountByLabel.get(lbl);
        if (cnt != null && cnt > 0) {
            result.add(new Map<String, Object>{
                'label' => lbl + ' (' + cnt + ')',
                'value' => apiName,
                'count' => cnt
            });
        }
    }
    return result;
}
@AuraEnabled(cacheable=false)
public static List<RecycleBinRecord> getDeletedRecordsByType(String objectType) {
    validateObjectType(objectType);
    String nameField = getNameField(objectType);
    String fields    = 'Id, LastModifiedById, LastModifiedDate';
    if (!nameField.equalsIgnoreCase('Id')) fields += ', ' + nameField;

    List<SObject> records = new List<SObject>();
    try {
        records = AWSVaultSectionQueryHelper.getDeletedRecordsByType(objectType, fields);
    } catch (Exception e) {
        return new List<RecycleBinRecord>();
    }
    Set<Id> userIds = new Set<Id>();
    for (SObject rec : records) {
        Id uid = (Id) rec.get('LastModifiedById');
        if (uid != null) userIds.add(uid);
    }

    Map<Id, String> userMap = new Map<Id, String>();
    if (!userIds.isEmpty()) {
        for (User u : AWSVaultSectionQueryHelper.getUsersByIds(userIds)) {
            userMap.put(u.Id, u.Name);
        }
    }
    List<RecycleBinRecord> result = new List<RecycleBinRecord>();
    for (SObject rec : records) {
        RecycleBinRecord r = new RecycleBinRecord();
        r.id = (String) rec.get('Id');

        String nameVal = nameField.equalsIgnoreCase('Id')
            ? null
            : (String) rec.get(nameField);

        r.name        = String.isNotBlank(nameVal) ? nameVal : r.id;
        r.objectType  = objectType;
        r.deletedDate = (DateTime) rec.get('LastModifiedDate');
        Id uid        = (Id) rec.get('LastModifiedById');
        r.deletedBy   = userMap.containsKey(uid)
            ? userMap.get(uid)
            : (uid != null ? String.valueOf(uid) : '');
        result.add(r);
    }
    return result;
}
@AuraEnabled
public static String startInstantBackup(String objectType, String recordIdsJson) {
    validateObjectType(objectType);

    // Get human-readable label
    String objectLabel = objectType;
    Schema.SObjectType sot = getGD().get(objectType);
    if (sot != null) {
        objectLabel = sot.getDescribe().getLabel();
    }

    List<String> ids = parseJsonList(recordIdsJson);

    RecycleBinBackupBatch batch = ids.isEmpty()
        ? new RecycleBinBackupBatch(objectType, objectLabel)
        : new RecycleBinBackupBatch(objectType, ids, objectLabel);

    if (Test.isRunningTest()) return '';
    return String.valueOf(Database.executeBatch(batch, 200));
}

 @AuraEnabled
public static String startMultiObjectBackup(String objectTypesJson) {
    List<String> objectTypes = parseJsonList(objectTypesJson);

    if (objectTypes.isEmpty()) {
        throw new AuraHandledException('At least one object type is required.');
    }

    for (String obj : objectTypes) {
        validateObjectType(obj);
    }

    // JSON format for Object_Name__c storage
    String objectNamesForLog = objectTypes.size() > 1
        ? JSON.serialize(objectTypes)
        : objectTypes[0];

    if (Test.isRunningTest()) return '{}';

    Id jobId = Database.executeBatch(
        new RecycleBinMultiObjectBackupBatch(objectTypes, objectNamesForLog), 200
    );

    Map<String, String> result = new Map<String, String>();
    result.put('multi', String.valueOf(jobId));
    return JSON.serialize(result);
}

   @AuraEnabled
public static String scheduleBackup(
    String objectTypesJson,
    String recordIdsJson,
    String frequency,
    String backupTime
) {
    try {
        List<String> objectTypes = parseJsonList(objectTypesJson);
        List<String> recordIds   = parseJsonList(recordIdsJson);

        if (objectTypes.isEmpty()) {
            throw new AuraHandledException('At least one object type is required.');
        }
        for (String obj : objectTypes) {
            validateObjectType(obj);
        }

        // JSON format for Object_Name__c — same as instant multi backup
        String objectNamesForLog = objectTypes.size() > 1
            ? JSON.serialize(objectTypes)
            : objectTypes[0];

        String[] timeParts = backupTime.split(':');
        String hh = timeParts[0];
        String mm = timeParts[1];

        String cronExp;
        if (frequency == 'daily') {
            cronExp = '0 ' + mm + ' ' + hh + ' * * ?';
        } else if (frequency == 'weekly') {
            cronExp = '0 ' + mm + ' ' + hh + ' ? * MON';
        } else if (frequency == 'monthly') {
            cronExp = '0 ' + mm + ' ' + hh + ' 1 * ?';
        } else {
            throw new AuraHandledException('Invalid frequency: ' + frequency);
        }

        String jobName = 'RecycleBinBackup_'
                       + frequency + '_'
                       + DateTime.now().format('yyyyMMdd_HHmmss');

        if (Test.isRunningTest()) return 'TEST_SCHEDULE_JOB';

        String jobId = System.schedule(
            jobName,
            cronExp,
            new RecycleBinScheduledBackup(objectTypes, recordIds, objectNamesForLog)
        );

        return jobId;

    } catch (AuraHandledException ahe) {
        throw ahe;
    } catch (Exception e) {
        throw new AuraHandledException('Schedule failed: ' + e.getMessage());
    }
}
    @AuraEnabled
    public static List<BackupJobStatus> getBackupJobStatus(String jobIdsJson) {
        List<BackupJobStatus> result = new List<BackupJobStatus>();
        Set<Id> ids = toIdSet(parseJsonList(jobIdsJson));

        if (ids.isEmpty()) return result;

        for (AsyncApexJob job : AWSVaultSectionQueryHelper.getJobsByIds(ids)) {
            BackupJobStatus s = new BackupJobStatus();
            s.jobId     = job.Id;
            s.status    = job.Status;
            s.startTime = job.CreatedDate.format('yyyy-MM-dd HH:mm:ss');
            s.progress  = job.TotalJobItems > 0
                ? job.JobItemsProcessed + '/' + job.TotalJobItems
                : '-';
            s.isDone    = !ACTIVE_STATUSES.contains(job.Status);
            result.add(s);
        }

        return result;
    }

    @AuraEnabled
    public static Boolean areAllJobsDone(String jobIdsJson) {
        Set<Id> ids = toIdSet(parseJsonList(jobIdsJson));
        if (ids.isEmpty()) return true;

        return AWSVaultSectionQueryHelper.countActiveJobsByIdSet(ids, ACTIVE_STATUSES) == 0;
    }

    @AuraEnabled
    public static List<Map<String, Object>> getJobDetails(String jobIdsJson) {
        Set<Id> ids = toIdSet(parseJsonList(jobIdsJson));
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        if (ids.isEmpty()) return result;

        Map<Id, String> userMap = new Map<Id, String>();
        for (AsyncApexJob job : 
            AWSVaultSectionQueryHelper.getJobsWithCreator(ids)
        ) {
            userMap.put(job.CreatedById, null);
        }

        userMap = AWSVaultSectionQueryHelper.getUserNameMapByIds(userMap.keySet());

        for (AsyncApexJob job : 
            AWSVaultSectionQueryHelper.getJobDetailsByIds(ids)
        ) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('jobId',        String.valueOf(job.Id));
            row.put('className',    job.ApexClass.Name);
            row.put('status',       job.Status);
            row.put('userName',     userMap.get(job.CreatedById));
            row.put('startTime',    job.CreatedDate.format('yyyy-MM-dd HH:mm:ss'));
            row.put('isNotRunning', !ACTIVE_STATUSES.contains(job.Status));
            result.add(row);
        }

        return result;
    }

    @AuraEnabled
    public static void cancelJob(String jobId) {
        try {
            System.abortJob((Id) jobId);
        } catch (Exception e) {
            throw new AuraHandledException('Could not cancel job: ' + e.getMessage());
        }
    }

    private static List<String> parseJsonList(String json) {
        List<String> result = new List<String>();
        if (String.isBlank(json)) return result;

        try {
            for (Object o : (List<Object>) System.JSON.deserializeUntyped(json)) {
                String val = String.valueOf(o).trim();
                if (!String.isBlank(val)) result.add(val);
            }
        } catch (Exception e) {
        }

        return result;
    }

    private static Set<Id> toIdSet(List<String> ids) {
        Set<Id> result = new Set<Id>();
        for (String s : ids) {
            try { result.add((Id) s); } catch (Exception e) {}
        }
        return result;
    }
}