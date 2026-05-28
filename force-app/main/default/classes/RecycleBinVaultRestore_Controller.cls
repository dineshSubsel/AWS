public with sharing class RecycleBinVaultRestore_Controller {

    private static final Set<String> ACTIVE_STATUSES = new Set<String>{
        'Queued', 'On Holding', 'Preparing', 'Processing'
    };

    private static Map<String, Schema.SObjectType> gdCache;
    private static Map<String, Schema.DescribeSObjectResult> describeCache;

    private static Map<String, Schema.SObjectType> getGD() {
        if (gdCache == null) {
            gdCache = Schema.getGlobalDescribe();
        }
        return gdCache;
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

private static Map<String, Schema.DescribeSObjectResult> getDescribeCache() {
    if (describeCache == null) {
        describeCache = new Map<String, Schema.DescribeSObjectResult>();

        Map<String, Schema.SObjectType> gd = getGD();

        for (String api : gd.keySet()) {
            describeCache.put(api, gd.get(api).getDescribe());
        }
    }

    return describeCache;
}

    public class RecycleBinRecord {
        @AuraEnabled public String   id;
        @AuraEnabled public String   name;
        @AuraEnabled public String   objectType;
        @AuraEnabled public String   deletedBy;
        @AuraEnabled public Datetime deletedDate;
    }

   @AuraEnabled(cacheable=false)
public static List<Map<String, Object>> getDeletedRecordCounts() {
    Set<String> labelsWithDeletes = new Set<String>();
    Map<String, Integer> deCountByLabel = new Map<String, Integer>();
    for (DeleteEvent de : AWSVaultSectionQueryHelper.getDeleteEvents()) {
        String lbl = de.SobjectName;
        labelsWithDeletes.add(lbl);
        deCountByLabel.put(
            lbl,
            deCountByLabel.containsKey(lbl)
                ? deCountByLabel.get(lbl) + 1
                : 1
        );
    }
    if (labelsWithDeletes.isEmpty()) {
        return new List<Map<String, Object>>();
    }

    Map<String, String> labelToApi = getLabelToApiMap();
    Set<String> apiNames = new Set<String>();
    for (String lbl : labelsWithDeletes) {
        String apiName = labelToApi.get(lbl.toLowerCase());
        if (!String.isBlank(apiName)) {
            apiNames.add(apiName);
        }
    }

    Map<String, Integer> deletedCounts =
        AWSVaultSectionQueryHelper.countDeletedRecordsBulk(apiNames);
    List<Map<String, Object>> result = new List<Map<String, Object>>();
    for (String lbl : labelsWithDeletes) {
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
            records = AWSVaultSectionQueryHelper.getDeletedRecords(objectType, fields);
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

    // ─── Instant Restore ─────────────────────────────────────────────────────

@AuraEnabled
public static String restoreDeletedRecords(
    String       selectedObjects,
    List<String> selectedRecordIds
) {
    if (String.isBlank(selectedObjects)) {
        throw new AuraHandledException('No object selected.');
    }

    List<String> objectList = parseCommaList(selectedObjects);

   List<String> objectLabels = new List<String>();

Map<String, Schema.SObjectType> gd = getGD();

for (String obj : objectList) {
    Schema.SObjectType sot = gd.get(obj);
    objectLabels.add(sot != null ? sot.getDescribe().getLabel() : obj);
}
    String objectNamesForLog = objectLabels.size() > 1
        ? JSON.serialize(objectLabels)
        : objectLabels[0];

    List<File_Recovery_Log__c> backupLogs =
        AWSVaultSectionQueryHelper.queryEligibleBackupLogsForRecycleBin(objectLabels);

    String timestamp    = DateTime.now().format('yyyyMMdd-HHmmss');
    String randomSuffix = String.valueOf((Integer)(Math.random() * 9000) + 1000);
    String restoreName  = 'RB-RST-' + timestamp + '-' + randomSuffix;

   String fallbackFileName = objectLabels.size() > 1
    ? 'Restore-Multiple Objects-' + DateTime.now().format('yyyy-MM-dd_HH-mm-ss')
    : 'Restore-' + objectLabels[0] + '-' + DateTime.now().format('yyyy-MM-dd_HH-mm-ss');

String backupFileName = (!backupLogs.isEmpty() && String.isNotBlank(backupLogs[0].File_Name__c))
    ? backupLogs[0].File_Name__c
    : fallbackFileName;

    // Insert intent log and capture its Id
    Id intentLogId = AWSVaultSectionQueryHelper.insertFileRecoveryLog(
        new File_Recovery_Log__c(
            Name              = restoreName,
            File_Name__c      = backupFileName,
            Object_Name__c    = objectNamesForLog,
            Action_Type__c    = 'Restore',
            Restore_Status__c = backupLogs.isEmpty() ? 'Failed' : 'In Progress',
            Restore_Time__c   = DateTime.now(),
            Recycle_Bin__c    = true,
            Error_Message__c  = backupLogs.isEmpty()
                                    ? 'No backup files found. Please run backup first.'
                                    : backupLogs.size() + ' file(s) queued for restore.'
         
        )
    );

    List<File_Recovery_Log__c> restoreLogs = backupLogs.isEmpty()
        ? new List<File_Recovery_Log__c>()
        : createRestoreLogs(backupLogs);

    List<Id> backupLogIds  = new List<Id>();
    List<Id> restoreLogIds = new List<Id>();
    for (File_Recovery_Log__c bl : backupLogs)  backupLogIds.add(bl.Id);
    for (File_Recovery_Log__c rl : restoreLogs) restoreLogIds.add(rl.Id);

    String batchJobId = AWSVaultSectionQueryHelper.executeBatchRestore(
        backupLogIds, restoreLogIds, selectedRecordIds
    );

    // // Store batch job ID in intent log
    // if (intentLogId != null && String.isNotBlank(batchJobId)) {
    //     AWSVaultSectionQueryHelper.updateRecycleBinRestoreLogs(
    //         new List<File_Recovery_Log__c>{
    //             new File_Recovery_Log__c(
    //                 Id               = intentLogId,
    //                 Parent_Job_Id__c = batchJobId
    //             )
    //         }
    //     );
    // }

    return batchJobId;
}
    // ─── Scheduled Restore ───────────────────────────────────────────────────

    @AuraEnabled
public static String startScheduledRecycleBinRestore(
    String       selectedObjects,
    List<String> selectedRecordIds,
    String       frequency,
    String       restoreTime
) {
    if (String.isBlank(selectedObjects)) throw new AuraHandledException('Object required.');
    if (String.isBlank(frequency))       throw new AuraHandledException('Frequency required.');
    if (String.isBlank(restoreTime))     throw new AuraHandledException('Time required.');

    List<String> objectList = parseCommaList(selectedObjects);

    // Resolve labels
   List<String> objectLabels = new List<String>();

Map<String, Schema.SObjectType> gd = getGD();

for (String obj : objectList) {
    Schema.SObjectType sot = gd.get(obj);
    objectLabels.add(sot != null ? sot.getDescribe().getLabel() : obj);
}
    String objectNamesForLog = String.join(objectLabels, ', ');

    List<CronTrigger> existing =
        AWSVaultSectionQueryHelper.getActiveRecycleBinRestoreJobs();
    AWSVaultSectionQueryHelper.abortCronJobs(existing);

    String cronExp = buildCronExpression(frequency, restoreTime);
    String jobName = 'RecycleBinRestore-'
        + objectNamesForLog.replaceAll(', ', '_').left(50)
        + '-' + frequency.toUpperCase()
        + '-' + System.now().format('yyyyMMdd_HHmmss');

    AWSVaultSectionQueryHelper.scheduleRecycleBinRestore(
        jobName,
        cronExp,
        new RecycleBinRestoreScheduler(objectList, selectedRecordIds, objectNamesForLog)
    );

    return jobName;
}

    // ─── Job Status ───────────────────────────────────────────────────────────

    @AuraEnabled
    public static Boolean areAllJobsDone(String jobIdsJson) {
        Set<Id> ids = toIdSet(parseJsonList(jobIdsJson));
        if (ids.isEmpty()) return true;
        return AWSVaultSectionQueryHelper.countActiveJobsByIds(ids, ACTIVE_STATUSES) == 0;
    }

    @AuraEnabled
    public static List<Map<String, Object>> getJobDetails(String jobIdsJson) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();

        List<String> rawIds      = parseJsonList(jobIdsJson);
        Boolean      useSentinel = rawIds.size() == 1 && rawIds[0] == 'LATEST_RESTORE';

        List<AsyncApexJob> jobs;
        if (useSentinel) {
            jobs = AWSVaultSectionQueryHelper.getLatestRecycleBinRestoreJobs();
        } else {
            Set<Id> ids = toIdSet(rawIds);
            if (ids.isEmpty()) return result;
            jobs = AWSVaultSectionQueryHelper.getRecycleBinRestoreJobsByIds(ids);
        }

        Set<Id> creatorIds = new Set<Id>();
        for (AsyncApexJob j : jobs) creatorIds.add(j.CreatedById);

        Map<Id, String> userMap = new Map<Id, String>();
        for (User u : AWSVaultSectionQueryHelper.getUsersByIds(creatorIds)) {
            userMap.put(u.Id, u.Name);
        }

        for (AsyncApexJob job : jobs) {
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
            AWSVaultSectionQueryHelper.abortJob(jobId);
        } catch (Exception e) {
            throw new AuraHandledException('Could not cancel job: ' + e.getMessage());
        }
    }

    // ─── Public Helpers (used by batch/scheduler) ─────────────────────────────

   public static void insertFailedLogViaSavepoint(
    String       objectNames,
    List<String> recordIds,
    String       errorMsg
) {
    String timestamp    = DateTime.now().format('yyyyMMdd-HHmmss');
    String randomSuffix = String.valueOf((Integer)(Math.random() * 9000) + 1000);
    String restoreName  = 'RB-RST-' + timestamp + '-' + randomSuffix;

    AWSVaultSectionQueryHelper.insertFailedRecycleBinLog(new File_Recovery_Log__c(
        Name              = restoreName,
        File_Name__c      = restoreName,
        Object_Name__c    = objectNames,
        Action_Type__c    = 'Restore',
        Recycle_Bin__c    = true,
        Restore_Status__c = 'Failed',
        Restore_Time__c   = DateTime.now(),
        Error_Message__c  = (errorMsg != null ? errorMsg : '').left(255)
       
    ));
}
 public static List<File_Recovery_Log__c> createRestoreLogs(
    List<File_Recovery_Log__c> backupLogs
) {
    List<File_Recovery_Log__c> logs = new List<File_Recovery_Log__c>();

    for (File_Recovery_Log__c bl : backupLogs) {
        String objName = String.isNotBlank(bl.Object_Name__c)
            ? bl.Object_Name__c
            : 'Unknown';

        String timestamp    = DateTime.now().format('yyyyMMdd-HHmmss');
        String randomSuffix = String.valueOf((Integer)(Math.random() * 9000) + 1000);
        String restoreName  = 'RB-RST-' + timestamp + '-' + randomSuffix;

        logs.add(new File_Recovery_Log__c(
            Name              = restoreName,
            File_Name__c      = restoreName,
            S3_Key__c         = bl.S3_Key__c,
            Object_Name__c    = objName,
            Action_Type__c    = 'Restore',
            Recycle_Bin__c    = true,
            Restore_Status__c = 'In Progress',
            Restore_Time__c   = DateTime.now()
        ));
    }

    return AWSVaultSectionQueryHelper.insertAndReturnRestoreLogs(logs);
}
    // ─── Private Helpers ──────────────────────────────────────────────────────
 private static Set<String> allowedObjectTypes;

 private static Set<String> getAllowedApiNames() {
    if (allowedObjectTypes == null) {
        allowedObjectTypes = new Set<String>();

        if (gdCache == null) {
            gdCache = Schema.getGlobalDescribe();
        }

        for (Schema.SObjectType objType : gdCache.values()) {
            Schema.DescribeSObjectResult d = objType.getDescribe();

            if (!d.isQueryable() || !d.isDeletable()) {
                continue;
            }

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
    private static String getNameField(String apiName) {
        if (String.isBlank(apiName)) return 'Id';
        Schema.SObjectType objType = getGD().get(apiName);
        if (objType == null) return 'Id';
        Map<String, Schema.SObjectField> fields = objType.getDescribe().fields.getMap();
        if (fields.containsKey('Name'))           return 'Name';
        if (fields.containsKey('Subject'))        return 'Subject';
        if (fields.containsKey('Title'))          return 'Title';
        if (fields.containsKey('CaseNumber'))     return 'CaseNumber';
        if (fields.containsKey('ContractNumber')) return 'ContractNumber';
        return 'Id';
    }

    private static void validateObjectType(String objectType) {
        if (String.isBlank(objectType))
            throw new AuraHandledException('Object type cannot be blank.');
        Boolean isValid = false;
        for (String api : getAllowedApiNames()) {
            if (api.equalsIgnoreCase(objectType)) { isValid = true; break; }
        }
        if (!isValid) throw new AuraHandledException('Invalid object type: ' + objectType);
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

    private static List<String> parseJsonList(String jsonStr) {
        List<String> result = new List<String>();
        if (String.isBlank(jsonStr)) return result;
        try {
            for (Object o : (List<Object>) System.JSON.deserializeUntyped(jsonStr)) {
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

    private static String buildCronExpression(String frequency, String timeStr) {
        List<String> parts  = timeStr.split(':');
        Integer      hour   = Integer.valueOf(parts[0]);
        Integer      minute = parts.size() > 1 ? Integer.valueOf(parts[1]) : 0;
        switch on frequency.toLowerCase() {
            when 'daily'   { return '0 ' + minute + ' ' + hour + ' * * ?';   }
            when 'weekly'  { return '0 ' + minute + ' ' + hour + ' ? * MON'; }
            when 'monthly' { return '0 ' + minute + ' ' + hour + ' 1 * ?';   }
            when else      { throw new AuraHandledException('Invalid frequency: ' + frequency); }
        }
    }
}