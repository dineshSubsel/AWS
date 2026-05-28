public without sharing class AWSVaultSectionQueryHelper {

    // ─── DML ──────────────────────────────────────────────────────────────────

 public static void insertLog(File_Recovery_Log__c log) {
    if (String.isBlank(log.Name)) {
        sanitizeLogName(log);
    }
    /* sfge-disable-next-line ApexFlsViolationRule */
    Database.insert(log, AccessLevel.SYSTEM_MODE);
}

public static void insertLogs(List<File_Recovery_Log__c> logs) {
    if (logs == null || logs.isEmpty()) return;

    for (File_Recovery_Log__c log : logs) {
        // only sanitize if Name not already set
        if (String.isBlank(log.Name)) {
            sanitizeLogName(log);
        }
    }
    /* sfge-disable-next-line ApexFlsViolationRule */
    Database.insert(logs, AccessLevel.SYSTEM_MODE);
}

    public static void updateLogs(List<File_Recovery_Log__c> logs) {
        if (logs != null && !logs.isEmpty()) 
           /* sfge-disable-next-line ApexFlsViolationRule*/
         Database.update(logs, AccessLevel.SYSTEM_MODE);
    }

    public static void upsertLogs(List<File_Recovery_Log__c> logs) {
        if (logs != null && !logs.isEmpty()) 
           /* sfge-disable-next-line ApexFlsViolationRule*/
         Database.upsert(logs, AccessLevel.SYSTEM_MODE);
    }

    public static void deleteLogs(List<File_Recovery_Log__c> logs) {
        if (logs != null && !logs.isEmpty()) 
           /* sfge-disable-next-line ApexFlsViolationRule*/
        Database.delete(logs, AccessLevel.SYSTEM_MODE);
    }

    public static List<Database.UpsertResult> upsertRecords(List<SObject> records) {
        if (records == null || records.isEmpty()) return new List<Database.UpsertResult>();
           /* sfge-disable-next-line ApexFlsViolationRule*/
        return Database.upsert(records, AccessLevel.SYSTEM_MODE);
    }

    // ─── Scheduling / Queueing ────────────────────────────────────────────────

    public static void scheduleJob(String jobName, String cron, Schedulable job) {
        System.schedule(jobName, cron, job);
    }

    public static void enqueueRestore(
        List<File_Recovery_Log__c> backupLogs,
        List<File_Recovery_Log__c> restoreLogs
    ) {
        System.enqueueJob(new DataRestoreQueueable(backupLogs, restoreLogs));
    }

    public static void enqueueFileRestore(List<File_Recovery_Log__c> logs) {
        System.enqueueJob(new FileRestoreQueueable(logs));
    }

    public static void abortJob(String jobId) {
        System.abortJob(jobId);
    }

    // ─── Object / Record Queries ──────────────────────────────────────────────

    public static List<String> getAllObjects() {
        List<String> objectNames = new List<String>(Schema.getGlobalDescribe().keySet());
        objectNames.sort();
        return objectNames;
    }

    public static List<SObject> getRecords(String objectName) {

    if (objectName == null || String.isBlank(objectName)) {
        return new List<SObject>();
    }
 return AWSQuerySharingHelper.getRecordsByObjectName(objectName);
}

    public static List<ContentDocument> getFilesForRecords(List<Id> recordIds) {
    if (recordIds == null || recordIds.isEmpty()) 
        return new List<ContentDocument>();

    List<ContentDocumentLink> links =
        AWSQuerySharingHelper.getContentDocumentLinksByIds(recordIds);
    Set<Id> docIds = new Set<Id>();
    for (ContentDocumentLink link : links) {
        docIds.add(link.ContentDocumentId);
    }

    if (docIds.isEmpty()) return new List<ContentDocument>();
    return AWSQuerySharingHelper.getContentDocumentsByIds(docIds);
}
public static List<FileRecoveryVaultController.FileRow> getFilesForLogRecords(
    List<Id> selectedRecordIds,
    String objectName
) {

    if (selectedRecordIds == null || selectedRecordIds.isEmpty()) {
        return new List<FileRecoveryVaultController.FileRow>();
    }

    if (String.isBlank(objectName)) {
        return new List<FileRecoveryVaultController.FileRow>();
    }

    Set<Id> safeRecordIds = new Set<Id>();

    for (Id recordId : selectedRecordIds) {
        if (recordId != null) {
            safeRecordIds.add(recordId);
        }
    }

    if (safeRecordIds.isEmpty()) {
        return new List<FileRecoveryVaultController.FileRow>();
    }

    List<ContentDocumentLink> links = [
        SELECT ContentDocumentId
        FROM ContentDocumentLink
        WHERE LinkedEntityId IN :safeRecordIds
        WITH SECURITY_ENFORCED
    ];

    if (links.isEmpty()) {
        return new List<FileRecoveryVaultController.FileRow>();
    }

    Set<Id> docIds = new Set<Id>();

    for (ContentDocumentLink link : links) {
        if (link.ContentDocumentId != null) {
            docIds.add(link.ContentDocumentId);
        }
    }

    if (docIds.isEmpty()) {
        return new List<FileRecoveryVaultController.FileRow>();
    }

    List<ContentVersion> versions = [
        SELECT Id,
               Title,
               ContentDocumentId,
               CreatedDate
        FROM ContentVersion
        WHERE ContentDocumentId IN :docIds
        AND IsLatest = true
        WITH SECURITY_ENFORCED
    ];

    if (versions.isEmpty()) {
        return new List<FileRecoveryVaultController.FileRow>();
    }

    List<FileRecoveryVaultController.FileRow> result =
        new List<FileRecoveryVaultController.FileRow>();

    for (ContentVersion cv : versions) {

        FileRecoveryVaultController.FileRow row =
            new FileRecoveryVaultController.FileRow();

        row.Id = cv.ContentDocumentId;
        row.fileName = cv.Title;
        row.backupTime = cv.CreatedDate;

        result.add(row);
    }

    return result;
}
private static List<FileRecoveryVaultController.FileRow> buildFileRows(
    Map<String, File_Recovery_Log__c> logMap
) {
    List<FileRecoveryVaultController.FileRow> result = new List<FileRecoveryVaultController.FileRow>();

    for (File_Recovery_Log__c log : logMap.values()) {
        result.add(createRow(log));
    }

    return result;
}

private static FileRecoveryVaultController.FileRow createRow(File_Recovery_Log__c log) {
    FileRecoveryVaultController.FileRow row = new FileRecoveryVaultController.FileRow();
    row.Id = log.Id;
    row.fileName = log.File_Name__c;
    row.backupTime = log.Backup_Time__c;
    return row;
}

    public static List<SObject> getObjectRecords(
    String       objectName,
    List<String> fieldNames,
    Integer      recordLimit
) {
    try {
        if (objectName == null || String.isBlank(objectName) || fieldNames == null || fieldNames.isEmpty()) {
            return new List<SObject>();
        }
        return Database.query(
            'SELECT ' + String.join(fieldNames, ', ')
            + ' FROM '  + String.escapeSingleQuotes(objectName)
            + ' ORDER BY Id ASC'
            + ' LIMIT ' + recordLimit
        );
    } catch (Exception e) {
        return new List<SObject>();
    }
}

    // ─── Restore Log Queries ──────────────────────────────────────────────────

    public static List<File_Recovery_Log__c> getInstantRestoreLogs(
        String       selectedObjects,
        List<String> selectedRecordIds
    ) {
        List<Id> recordIds = new List<Id>();
        for (String s : selectedRecordIds) recordIds.add((Id) s);

        return [
            SELECT Id, S3_Key__c, File_Name__c, Record_Id__c, Object_Name__c
            FROM   File_Recovery_Log__c
            WHERE  Record_Id__c      IN :recordIds
              AND  Object_Name__c    IN :selectedObjects.split(',')
              AND  S3_Key__c         != null
              AND  Restore_Status__c != 'Completed' WITH SECURITY_ENFORCED
            ORDER BY File_Name__c ASC
        ];
    }

    public static List<File_Recovery_Log__c> getScheduledIntentLogs() {
        return [
            SELECT Id
            FROM   File_Recovery_Log__c
            WHERE  Action_Type__c    = 'Restore'
              AND  Restore_Status__c = 'Scheduled' WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 5
        ];
    }

    public static List<File_Recovery_Log__c> queryEligibleDataLogs(
    List<String> objectList,
    List<String> recordIds
) {

    if (objectList == null || objectList.isEmpty()) {
        return new List<File_Recovery_Log__c>();
    }

    List<String> safeObjectList = new List<String>();

    for (String obj : objectList) {
        if (!String.isBlank(obj)) {
            safeObjectList.add(obj.trim());
        }
    }

    if (safeObjectList.isEmpty()) {
        return new List<File_Recovery_Log__c>();
    }

    try {

        return [
            SELECT Id,
                   S3_Key__c,
                   File_Name__c,
                   Record_Id__c,
                   Object_Name__c
            FROM File_Recovery_Log__c
            WHERE Object_Name__c IN :safeObjectList
            AND S3_Key__c != null
            AND Action_Type__c = 'Backup'
            AND Backup_Status__c = 'Failed'
            AND Restore_Status__c != 'Completed'
            WITH SECURITY_ENFORCED
        ];

    } catch (Exception e) {
        return new List<File_Recovery_Log__c>();
    }
}

    public static List<File_Recovery_Log__c> queryGroupRestoreLogs(
    String objectNameDiscriminator
) {

    if (String.isBlank(objectNameDiscriminator)) {
        return new List<File_Recovery_Log__c>();
    }

    String safeObjectName =
        objectNameDiscriminator.trim();

    if (String.isBlank(safeObjectName)) {
        return new List<File_Recovery_Log__c>();
    }

    String finalObjectName =
        String.isBlank(safeObjectName)
        ? null
        : safeObjectName;

    if (finalObjectName == null) {
        return new List<File_Recovery_Log__c>();
    }

    try {

        return [

            SELECT Id,
                   S3_Key__c,
                   File_Name__c,
                   Record_Id__c,
                   Object_Name__c

            FROM File_Recovery_Log__c

            WHERE Object_Name__c = :finalObjectName
            AND S3_Key__c != null
            AND Action_Type__c = 'Backup'
            AND Backup_Status__c = 'Failed'
            AND Restore_Status__c != 'Completed'

            WITH SECURITY_ENFORCED

            ORDER BY Backup_Time__c DESC

            LIMIT 50
        ];

    } catch (Exception e) {

        return new List<File_Recovery_Log__c>();
    }
}

   public static List<File_Recovery_Log__c> querySchedulerBackupLogs(
    List<String> objectNames,
    List<String> recordIds
) {

    List<String> safeObjectNames = new List<String>();

    if (objectNames != null) {

        for (String obj : objectNames) {

            if (!String.isBlank(obj)) {
                safeObjectNames.add(obj.trim());
            }
        }
    }

    List<Id> idList = new List<Id>();

    if (recordIds != null) {

        for (String r : recordIds) {

            try {

                if (!String.isBlank(r)) {
                    idList.add((Id) r);
                }

            } catch (Exception e) {
            }
        }
    }

    try {

        if (!safeObjectNames.isEmpty()) {

            if (!idList.isEmpty()) {

                return [
                    SELECT Id,
                           S3_Key__c,
                           File_Name__c,
                           Record_Id__c,
                           Object_Name__c
                    FROM File_Recovery_Log__c
                    WHERE Object_Name__c IN :safeObjectNames
                    AND Record_Id__c IN :idList
                    AND Action_Type__c = 'Backup'
                    AND Restore_Status__c != 'Completed'
                    WITH SECURITY_ENFORCED
                    ORDER BY Object_Name__c, CreatedDate DESC
                ];

            } else {

                return [
                    SELECT Id,
                           S3_Key__c,
                           File_Name__c,
                           Record_Id__c,
                           Object_Name__c
                    FROM File_Recovery_Log__c
                    WHERE Object_Name__c IN :safeObjectNames
                    AND Action_Type__c = 'Backup'
                    AND Restore_Status__c != 'Completed'
                    WITH SECURITY_ENFORCED
                    ORDER BY Object_Name__c, CreatedDate DESC
                ];
            }
        }

        return [
            SELECT Id,
                   S3_Key__c,
                   File_Name__c,
                   Record_Id__c,
                   Object_Name__c
            FROM File_Recovery_Log__c
            WHERE Action_Type__c = 'Backup'
            AND Restore_Status__c != 'Completed'
            WITH SECURITY_ENFORCED
            ORDER BY Object_Name__c, CreatedDate DESC
        ];

    } catch (Exception e) {

        return new List<File_Recovery_Log__c>();
    }
}

    // ─── Async Job Queries ────────────────────────────────────────────────────

    private static final Set<String> BACKUP_CLASS_NAMES = new Set<String>{
        'S3BackupBatch', 'BackupQueueable'
    };

    private static final Set<String> ACTIVE_STATUSES = new Set<String>{
        'Queued', 'Holding', 'Preparing', 'Processing'
    };

    public static List<AsyncApexJob> queryActiveBackupJobs(List<String> jobIds) {
        Set<Id> idSet = toIdSet(jobIds);

        if (!idSet.isEmpty()) {
            return [
                SELECT Id, Status, ApexClass.Name, CreatedDate, CreatedBy.Name,
                       JobItemsProcessed, TotalJobItems
                FROM   AsyncApexJob
                WHERE  Id     IN :idSet
                  AND  Status IN :ACTIVE_STATUSES WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
        }

        return [
            SELECT Id, Status, ApexClass.Name, CreatedDate, CreatedBy.Name,
                   JobItemsProcessed, TotalJobItems
            FROM   AsyncApexJob
            WHERE  ApexClass.Name IN :BACKUP_CLASS_NAMES
              AND  Status         IN :ACTIVE_STATUSES WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];
    }

    public static List<AsyncApexJob> queryRestoreJobs(List<String> jobIds) {
        Set<Id> idSet = toIdSet(jobIds);

        if (!idSet.isEmpty()) {
            return [
                SELECT Id, Status, ApexClass.Name, CreatedDate, CreatedBy.Name,
                       JobItemsProcessed, TotalJobItems
                FROM   AsyncApexJob
                WHERE  Id     IN :idSet
                  AND  Status IN :ACTIVE_STATUSES WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
        }

        return [
            SELECT Id, Status, ApexClass.Name, CreatedDate, CreatedBy.Name,
                   JobItemsProcessed, TotalJobItems
            FROM   AsyncApexJob
            WHERE  ApexClass.Name = 'FileRestoreQueueable'
              AND  Status IN :ACTIVE_STATUSES WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];
    }

    public static Boolean areAllBackupJobsDone(List<String> jobIds) {
        Set<Id> idSet = toIdSet(jobIds);

        if (idSet.isEmpty()) {
            return 0 == [
                SELECT COUNT() FROM AsyncApexJob
                WHERE  ApexClass.Name IN :BACKUP_CLASS_NAMES
                  AND  Status         IN :ACTIVE_STATUSES
                LIMIT 1
            ];
        }

        return 0 == [
            SELECT COUNT() FROM AsyncApexJob
            WHERE  Id     IN :idSet
              AND  Status IN :ACTIVE_STATUSES
            LIMIT 1
        ];
    }

    public static Boolean areAllRestoreJobsDone(List<String> jobIds) {
        Set<Id> idSet = toIdSet(jobIds);

        if (idSet.isEmpty()) {
            return 0 == [
                SELECT COUNT()
                FROM   AsyncApexJob
                WHERE  ApexClass.Name = 'FileRestoreQueueable'
                  AND  Status IN :ACTIVE_STATUSES
                LIMIT 1
            ];
        }

        return 0 == [
            SELECT COUNT()
            FROM   AsyncApexJob
            WHERE  Id     IN :idSet
              AND  Status IN :ACTIVE_STATUSES
            LIMIT 1
        ];
    }

    // ─── Status Row Builder ───────────────────────────────────────────────────

    public static Map<String, String> toStatusRow(AsyncApexJob job) {
    Map<String, String> row = new Map<String, String>();

    row.put('jobId', job.Id);
    row.put('status', job.Status);
    row.put('className', job.ApexClass != null ? job.ApexClass.Name : '');
    row.put('userName', job.CreatedBy != null ? job.CreatedBy.Name : '');

    row.put(
        'startTime',
        job.CreatedDate != null
            ? job.CreatedDate.format('yyyy-MM-dd HH:mm:ss')
            : ''
    );

    row.put(
        'progress',
        job.TotalJobItems != null && job.TotalJobItems > 0
            ? job.JobItemsProcessed + ' / ' + job.TotalJobItems
            : '—'
    );

    return row;
}
    // ─── Private Helpers ──────────────────────────────────────────────────────

    public static Set<Id> toIdSet(List<String> jobIds) {
        Set<Id> idSet = new Set<Id>();
        if (jobIds != null) {
            for (String jid : jobIds) {
                try { idSet.add((Id) jid); } catch (Exception e) { }
            }
        }
        return idSet;
    }

public static List<File_Recovery_Log__c> getTargetedRestoreLogs(
    List<Id> idList,
    List<String> objectNames
) {

    if (idList == null || idList.isEmpty()) {
        return new List<File_Recovery_Log__c>();
    }

    if (objectNames == null || objectNames.isEmpty()) {
        return new List<File_Recovery_Log__c>();
    }

    List<Id> safeIdList = new List<Id>();
    for (Id recordId : idList) {

        if (recordId != null) {
            safeIdList.add(recordId);
        }
    }

    List<String> safeObjectNames = new List<String>();
    for (String objName : objectNames) {

        if (!String.isBlank(objName)) {
            safeObjectNames.add(objName.trim());
        }
    }

    if (safeIdList.isEmpty() || safeObjectNames.isEmpty()) {
        return new List<File_Recovery_Log__c>();
    }

    try {

        return [

            SELECT Id,
                   S3_Key__c,
                   File_Name__c,
                   Record_Id__c,
                   Object_Name__c

            FROM File_Recovery_Log__c

            WHERE Record_Id__c IN :safeIdList
            AND Object_Name__c IN :safeObjectNames
            AND S3_Key__c != null
            AND Restore_Status__c != 'Completed'

            WITH SECURITY_ENFORCED

            ORDER BY File_Name__c ASC
        ];

    } catch (Exception e) {

        return new List<File_Recovery_Log__c>();
    }
}

public static List<File_Recovery_Log__c> getGlobalRestoreLogs() {
    return [
        SELECT Id, S3_Key__c, File_Name__c, Record_Id__c, Object_Name__c
        FROM   File_Recovery_Log__c
        WHERE  S3_Key__c         != null
          AND  Restore_Status__c != 'Completed' WITH SECURITY_ENFORCED
        ORDER BY File_Name__c ASC
    ];
}

public static void updateRestoreLogs(List<File_Recovery_Log__c> logs) {
    if (logs != null && !logs.isEmpty()) {
         /* sfge-disable-next-line ApexFlsViolationRule*/
         Database.update(logs, AccessLevel.SYSTEM_MODE);
    }
}

public static void enqueueFileRestoreChain(
    List<File_Recovery_Log__c> logs,
    Integer                    startIndex,
    Integer                    batchSize
) {
    System.enqueueJob(new FileRestoreQueueable(logs, startIndex, batchSize));
}
public static void insertContentVersion(ContentVersion cv) {

    /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(cv, AccessLevel.SYSTEM_MODE);
    
}

public static Id getContentDocumentId(Id contentVersionId) {
    return [
        SELECT ContentDocumentId
        FROM   ContentVersion
        WHERE  Id = :contentVersionId
        LIMIT  1
    ].ContentDocumentId;
}

public static void insertContentDocumentLink(ContentDocumentLink link) {
     /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(link, AccessLevel.SYSTEM_MODE);
}
// Add these methods to AWSVaultSectionQueryHelper

public static List<DeleteEvent> getDeleteEvents() {
    return [
        SELECT SobjectName,RecordName
        FROM   DeleteEvent WITH SECURITY_ENFORCED
        LIMIT  50000
    ];
}

public static List<User> getUsersByIds(Set<Id> userIds) {
    if (userIds == null || userIds.isEmpty()) return new List<User>();
    return [
        SELECT Id, Name
        FROM   User
        WHERE  Id IN :userIds WITH SECURITY_ENFORCED
    ];
}
public static List<SObject> getDeletedRecords(String objectType, String fields) {

    if (String.isBlank(objectType) || String.isBlank(fields)) {
        return new List<SObject>();
    }

     if (objectType == null || fields == null) {
        return new List<SObject>();
    }

    String query =
        'SELECT ' + fields +
        ' FROM ' + objectType +
        ' WHERE IsDeleted = true ' +
        'WITH SECURITY_ENFORCED ' +
        'ALL ROWS';
    return Database.query(query);
}
public static List<File_Recovery_Log__c> queryEligibleBackupLogsForRecycleBin(
    List<String> objectList
) {
    return [
        SELECT Id, S3_Key__c, File_Name__c, Record_Id__c, Object_Name__c
        FROM   File_Recovery_Log__c
        WHERE  Object_Name__c    IN :objectList
          AND  S3_Key__c         != null
          AND  Action_Type__c    = 'Backup'
          AND  Backup_Status__c  = 'Failed'
          AND  Restore_Status__c != 'Completed' WITH SECURITY_ENFORCED
    ];
}

public static List<File_Recovery_Log__c> insertAndReturnRestoreLogs(
    List<File_Recovery_Log__c> logs
) {
    if (logs != null && !logs.isEmpty()) 
    /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(logs, AccessLevel.SYSTEM_MODE);
    return logs;
}
public static void insertRecycleBinLog(File_Recovery_Log__c log) {
    if (log == null) return;
    if (String.isBlank(log.Name)) {
        String action = String.isNotBlank(log.Action_Type__c) ? log.Action_Type__c : 'Log';
        String status = String.isNotBlank(log.Backup_Status__c) ? log.Backup_Status__c : '';
        log.Name = String.isNotBlank(status)
            ? (action + ' - ' + status).left(80)
            : action.left(80);
    }

    /* sfge-disable-next-line ApexFlsViolationRule */
    Database.insert(log, AccessLevel.SYSTEM_MODE);
}

public static void insertFailedRecycleBinLog(File_Recovery_Log__c log) {
    Savepoint sp = Database.setSavepoint();
    try {
         sanitizeLogName(log);    
        /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(log, AccessLevel.SYSTEM_MODE);
    } catch (Exception e) {
        Database.rollback(sp);
    }
}

public static List<CronTrigger> getActiveRecycleBinRestoreJobs() {
    return [
        SELECT Id
        FROM   CronTrigger
        WHERE  CronJobDetail.Name LIKE 'RecycleBinRestore%'
          AND  State NOT IN ('COMPLETE', 'DELETED', 'ERROR') WITH SECURITY_ENFORCED
    ];
}

public static void abortCronJobs(List<CronTrigger> jobs) {
    for (CronTrigger ct : jobs) System.abortJob(ct.Id);
}

public static List<AsyncApexJob> getLatestRecycleBinRestoreJobs() {
    return [
        SELECT Id, Status, ApexClass.Name, CreatedDate,
               CreatedById, JobItemsProcessed, TotalJobItems
        FROM   AsyncApexJob
        WHERE  ApexClass.Name = 'RecycleBinRestoreBatch' WITH SECURITY_ENFORCED
        ORDER  BY CreatedDate DESC
        LIMIT  10
    ];
}

public static List<AsyncApexJob> getRecycleBinRestoreJobsByIds(Set<Id> ids) {
    if (ids == null || ids.isEmpty()) {
        return new List<AsyncApexJob>();
    }
    return [
        SELECT Id, Status, ApexClass.Name, CreatedDate,
               CreatedById, JobItemsProcessed, TotalJobItems
        FROM   AsyncApexJob
        WHERE  Id IN :ids
        WITH SECURITY_ENFORCED
        ORDER  BY CreatedDate DESC
    ];
}
public static Integer countActiveJobsByIds(Set<Id> ids, Set<String> activeStatuses) {
    if (ids == null || ids.isEmpty() ||
        activeStatuses == null || activeStatuses.isEmpty()) {
        return 0;
    }
    return [
        SELECT COUNT()
        FROM   AsyncApexJob
        WHERE  Id     IN :ids
          AND  Status IN :activeStatuses
        WITH SECURITY_ENFORCED
    ];
}

public static String executeBatchRestore(
    List<Id> backupLogIds,
    List<Id> restoreLogIds,
    List<String> selectedRecordIds
) {
    Id batchJobId = Database.executeBatch(
        new RecycleBinRestoreBatch(backupLogIds, restoreLogIds, selectedRecordIds), 1
    );
    return String.valueOf(batchJobId);
}

public static void scheduleRecycleBinRestore(
    String      jobName,
    String      cronExp,
    Schedulable scheduler
) {
    System.schedule(jobName, cronExp, scheduler);
}
public static List<File_Recovery_Log__c> getBackupLogsByIds(List<Id> backupLogIds) {
    if (backupLogIds == null || backupLogIds.isEmpty()) {
        return new List<File_Recovery_Log__c>();
    }

    return [
        SELECT Id, S3_Key__c, Object_Name__c, File_Name__c, Record_Id__c
        FROM   File_Recovery_Log__c
        WHERE  Id IN :backupLogIds
        WITH SECURITY_ENFORCED
    ];
}

public static void updateRecycleBinRestoreLogs(List<File_Recovery_Log__c> logs) {
    if (logs != null && !logs.isEmpty()) 
       /* sfge-disable-next-line ApexFlsViolationRule*/
         Database.update(logs, AccessLevel.SYSTEM_MODE);
}

public static void undeleteRecords(List<Id> ids) {
    if (ids == null || ids.isEmpty()) {
        return;
    }
    try {
        List<SObject> recordsToUndelete = new List<SObject>();

        for (Id recordId : ids) {
            recordsToUndelete.add(recordId.getSObjectType().newSObject(recordId));
        }
        // Enforce CRUD + FLS
        Database.undelete(recordsToUndelete, false, AccessLevel.USER_MODE);
    } catch (Exception e) {
    }
}

public static List<Database.UpsertResult> upsertRestoredRecords(List<SObject> records) {
    if (records == null || records.isEmpty()) return new List<Database.UpsertResult>();
    return Database.upsert(records, false);
}

public static List<File_Recovery_Log__c> getBackupLogsByObjectsAndIds(
    List<String> objectNames,
    List<Id> recordIds
) {
    if (objectNames == null || objectNames.isEmpty()) {
        return new List<File_Recovery_Log__c>();
    }

    if (recordIds == null || recordIds.isEmpty()) {
        return new List<File_Recovery_Log__c>();
    }

    List<String> validObjects = new List<String>();
    validObjects.addAll(objectNames);

    List<Id> validIds = new List<Id>();
    validIds.addAll(recordIds);

    if (!Schema.sObjectType.File_Recovery_Log__c.isAccessible()) {
        return new List<File_Recovery_Log__c>();
    }

    return [
        SELECT Id, S3_Key__c, File_Name__c, Record_Id__c, Object_Name__c
        FROM File_Recovery_Log__c
        WHERE Object_Name__c IN :validObjects
          AND Record_Id__c IN :validIds
          AND S3_Key__c != null
          AND Action_Type__c = 'Backup'
          AND Backup_Status__c = 'Failed'
          AND Restore_Status__c != 'Completed'
        WITH SECURITY_ENFORCED
        ORDER BY Object_Name__c, File_Name__c ASC
    ];
}

   public static List<File_Recovery_Log__c> getBackupLogsByObjects(
    List<String> objectNames
) {
    if (objectNames == null || objectNames.isEmpty()) {
        return new List<File_Recovery_Log__c>();
    }

    List<String> validObjects = new List<String>();
    validObjects.addAll(objectNames);

    return [
        SELECT Id, S3_Key__c, File_Name__c, Record_Id__c, Object_Name__c
        FROM File_Recovery_Log__c
        WHERE Object_Name__c IN :validObjects
          AND S3_Key__c != null
          AND Action_Type__c = 'Backup'
          AND Backup_Status__c = 'Failed'
          AND Restore_Status__c != 'Completed'
        WITH SECURITY_ENFORCED
        ORDER BY Object_Name__c, File_Name__c ASC
    ];
}

    public static List<File_Recovery_Log__c> getAllPendingBackupLogs() {
        return [
            SELECT Id, S3_Key__c, File_Name__c, Record_Id__c, Object_Name__c
            FROM   File_Recovery_Log__c
            WHERE  S3_Key__c         != null
              AND  Action_Type__c    = 'Backup'
              AND  Backup_Status__c  = 'Failed'
              AND  Restore_Status__c != 'Completed' WITH SECURITY_ENFORCED
            ORDER BY Object_Name__c, File_Name__c ASC
        ];
    }

    public static void markIntentLogsInProgress(
    List<File_Recovery_Log__c> intentLogs
) {
    if (intentLogs == null || intentLogs.isEmpty()) {
        return;
    }
    for (File_Recovery_Log__c l : intentLogs) {
        l.Restore_Status__c = 'In Progress';
    }
    if (!intentLogs.isEmpty()) {
        /* sfge-disable-next-line ApexFlsViolationRule*/
        Database.update(intentLogs, AccessLevel.SYSTEM_MODE);
    }
}

    public static List<Id> extractIds(List<SObject> records) {

    if (records == null || records.isEmpty()) {
        return new List<Id>();
    }
    List<Id> ids = new List<Id>();

    for (SObject rec : records) {
        if (rec != null && rec.get('Id') != null) {
            ids.add((Id) rec.get('Id'));
        }
    }
    return ids;
}

    public static List<Id> toIdList(List<String> strings) {

    if (strings == null || strings.isEmpty()) {
        return new List<Id>();
    }
    List<Id> ids = new List<Id>();
    for (String s : strings) {
        if (!String.isBlank(s)) {
            ids.add((Id) s);
        }
    }
    return ids;
}

    // ======

  public static List<SObject> getDeletedRecordsByType(String objectType, String fields) {
    if (objectType == null || String.isBlank(objectType) || fields == null || String.isBlank(fields)) {
        return new List<SObject>();
    }
    if (!Schema.getGlobalDescribe().containsKey(objectType)) {
        return new List<SObject>();
    }

    return Database.query(
        'SELECT ' + fields +
        ' FROM ' + objectType +
        ' WHERE IsDeleted = true ALL ROWS'
    );
}

    public static List<AsyncApexJob> getJobsByIds(Set<Id> ids) {
    if (ids == null || ids.isEmpty()) {
        return new List<AsyncApexJob>();
    }
    return [
        SELECT Id, Status, CreatedDate, JobItemsProcessed, TotalJobItems
        FROM   AsyncApexJob
        WHERE  Id IN :ids
        WITH SECURITY_ENFORCED
        ORDER  BY CreatedDate DESC
    ];
}

    public static List<AsyncApexJob> getJobDetailsByIds(Set<Id> ids) {
    if (ids == null || ids.isEmpty()) {
        return new List<AsyncApexJob>();
    }

    return [
        SELECT Id, Status, ApexClass.Name, CreatedDate,
               CreatedById, JobItemsProcessed, TotalJobItems
        FROM   AsyncApexJob
        WHERE  Id IN :ids
        WITH SECURITY_ENFORCED
        ORDER  BY CreatedDate DESC
    ];
}

    public static List<User> getUsersByJobIds(List<AsyncApexJob> jobs) {
    if (jobs == null || jobs.isEmpty()) {
        return new List<User>();
    }
    Set<Id> creatorIds = new Set<Id>();

    for (AsyncApexJob j : jobs) {
        if (j != null && j.CreatedById != null) {
            creatorIds.add(j.CreatedById);
        }
    }
    if (creatorIds.isEmpty()) {
        return new List<User>();
    }
    return getUsersByIds(creatorIds);
}

    public static Integer countActiveJobsByIdSet(Set<Id> ids, Set<String> activeStatuses) {
    if (ids == null || ids.isEmpty() ||
        activeStatuses == null || activeStatuses.isEmpty()) {
        return 0;
    }
    return [
        SELECT COUNT()
        FROM   AsyncApexJob
        WHERE  Id     IN :ids
          AND  Status IN :activeStatuses
        WITH SECURITY_ENFORCED
    ];
}
    public static Id executeBatch(Object batchJob, Integer scope) {
    if (batchJob == null || scope == null || scope <= 0) {
        return null;
    }
    if (!(batchJob instanceof Database.Batchable<SObject>)) {
        return null;
    }
    return Database.executeBatch((Database.Batchable<SObject>) batchJob, scope);
}

    public static String scheduledJob(
        String      jobName,
        String      cronExp,
        Schedulable scheduler
    ) {
        return System.schedule(jobName, cronExp, scheduler);
    }

    public static void abortApexJob(String jobId) {
    if (jobId == null || String.isBlank(jobId)) {
        return;
    }

    System.abortJob((Id) jobId);
}

     public static List<SObject> getDeletedRecordsForBackup(
         String       objectType,
         String       selectFields,
         List<String> recordIds,
         Integer      recordLimit
     ) {
         String query = 'SELECT ' + selectFields
                      + ' FROM '  + objectType
                      + ' WHERE IsDeleted = true';

         if (recordIds != null && !recordIds.isEmpty()) {
             query += ' AND Id IN (\'' + String.join(recordIds, '\',\'') + '\')';
         }

         query += ' LIMIT ' + recordLimit + ' ALL ROWS';
         return Database.query(query);
     }

    public static Map<Id, String> getUserNameMapByIds(Set<Id> userIds) {
        Map<Id, String> userNameMap = new Map<Id, String>();
        if (userIds == null || userIds.isEmpty()) return userNameMap;
        for (User u : [SELECT Id, Name FROM User WHERE Id IN :userIds WITH SECURITY_ENFORCED ]) {
            userNameMap.put(u.Id, u.Name);
        }
        return userNameMap;
    }

  public static void insertBackupLog(File_Recovery_Log__c log) {
    if (log == null) return;
    try {
        if (String.isBlank(log.Name)) {
            sanitizeLogName(log);
        }
        /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(log, AccessLevel.SYSTEM_MODE);
    } catch (Exception e) {
    }
}
      public static List<SObject> fetchDeletedRecords(
        List<String> objectTypes,
        List<String> recordIds,
        Integer recordLimit
    ) {
        List<SObject> allRecords = new List<SObject>();

        for (String objectType : objectTypes) {
            try {
                String nameField = getNameField(objectType);

                String selectFields = 'Id, LastModifiedById, LastModifiedDate';
                if (!nameField.equalsIgnoreCase('id')) {
                    selectFields += ', ' + nameField;
                }

                String query =
                    'SELECT ' + selectFields +
                    ' FROM ' + objectType +
                    ' WHERE IsDeleted = true';

                if (recordIds != null && !recordIds.isEmpty()) {
                    query += ' AND Id IN :recordIds';
                }

                query += ' LIMIT ' + recordLimit + ' ALL ROWS';

                allRecords.addAll(Database.query(query));

            } catch (Exception e) {
            }
        }

        return allRecords;
    }


    // Fetch Users
    public static Map<Id,String> fetchUsers(Set<Id> userIds){
        Map<Id,String> userMap = new Map<Id,String>();

        if(!userIds.isEmpty()){
            for(User u : [
                SELECT Id, Name
                FROM User
                WHERE Id IN :userIds WITH SECURITY_ENFORCED
            ]){
                userMap.put(u.Id , u.Name);
            }
        }
        return userMap;
    }


public static void insertFileRecoveryLog(
    String fileName, String s3Key, String status, String message
) {
    insertFileRecoveryLog(fileName, s3Key, status, message, null);
}

public static void insertFileRecoveryLog(
    String fileName, String s3Key, String status, String message, String parentJobId
) {
    String backupStatus =
        (status == 'No Data' || String.isBlank(status))
        ? 'Failed'
        : status;

    File_Recovery_Log__c log = new File_Recovery_Log__c(
        File_Name__c      = fileName,
        Object_Name__c    = 'Multiple Objects',
        S3_Key__c         = s3Key,
        Action_Type__c    = 'Backup',
        Backup_Time__c    = DateTime.now(),
        Backup_Status__c  = 'Failed',
        Recycle_Bin__c    = true,
        Error_Message__c  = message,
        Parent_Job_Id__c  = parentJobId
    );

    sanitizeLogName(log);
    // Enforce CRUD + FLS security
    Database.insert(log, false, AccessLevel.USER_MODE);
}

public static Id insertFileRecoveryLog(File_Recovery_Log__c log) {
    if (log == null) {
        return null;
    }
 sanitizeLogName(log);  
    try {
        /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(log, AccessLevel.SYSTEM_MODE);
        return log.Id;
    } catch (Exception e) {
        return null;
    }
}

    // Name field helper
public static String getNameField(String apiName) {

    if (apiName == null || String.isBlank(apiName)) {
        return null;
    }

    Map<String, Schema.SObjectField> fields =
        Schema.getGlobalDescribe()
              .get(apiName)
              .getDescribe().fields.getMap();

    for (String f : new List<String>{
        'Name','Subject','Title','CaseNumber','ContractNumber'
    }) {
        if (fields.containsKey(f)) {
            return f;
        }
    }

    return 'Id';
}
      public static List<ContentDocumentLink> getContentDocumentLinks(String recordId) {
    if (recordId == null) {
        return new List<ContentDocumentLink>();
    }

    return [
        SELECT ContentDocumentId
        FROM ContentDocumentLink
        WHERE LinkedEntityId = :recordId
        WITH SECURITY_ENFORCED
    ];
}

   public static Database.QueryLocator getContentVersionLocator(Set<Id> docIds) {
    if (docIds == null || docIds.isEmpty()) {
        return Database.getQueryLocator(
            'SELECT Id FROM ContentVersion WHERE Id = null'
        );
    }
    return Database.getQueryLocator([
        SELECT Id, Title, FileExtension, VersionData, ContentDocumentId
        FROM ContentVersion
        WHERE ContentDocumentId IN :docIds
          AND IsLatest = TRUE WITH SECURITY_ENFORCED
    ]);
}

    public static Database.QueryLocator getAttachmentLocator(String recordId) {
    if (recordId == null) {
        return Database.getQueryLocator(
            'SELECT Id FROM Attachment WHERE Id = null'
        );
    }

    return Database.getQueryLocator([
        SELECT Id, Name, Body, ContentType, ParentId
        FROM Attachment
        WHERE ParentId = :recordId WITH SECURITY_ENFORCED
    ]);
}

    public static Database.QueryLocator getEmptyLocator() {
        return Database.getQueryLocator([
            SELECT Id FROM ContentVersion WHERE Id = null WITH SECURITY_ENFORCED
        ]);
    }

    public static Map<Id, Id> getContentDocumentIdsByVersionIds(List<Id> contentVersionIds) {
    if (contentVersionIds == null || contentVersionIds.isEmpty()) {
        return new Map<Id, Id>();
    }

    Map<Id, Id> versionToDocMap = new Map<Id, Id>();

    for (ContentVersion cv : [
        SELECT Id, ContentDocumentId
        FROM ContentVersion
        WHERE Id IN :contentVersionIds
        WITH SECURITY_ENFORCED
    ]) {
        versionToDocMap.put(cv.Id, cv.ContentDocumentId);
    }

    return versionToDocMap;
}

    public static List<ContentDocument> getContentDocumentsById(Set<Id> docIds) {
    if (docIds == null || docIds.isEmpty()) {
        return new List<ContentDocument>();
    }
    return [
        SELECT Id
        FROM ContentDocument
        WHERE Id IN :docIds
        WITH SECURITY_ENFORCED
    ];
}

    public static List<Attachment> getAttachmentsById(Set<Id> attachmentIds) {
    if (attachmentIds == null || attachmentIds.isEmpty()) {
        return new List<Attachment>();
    }
    return [
        SELECT Id
        FROM Attachment
        WHERE Id IN :attachmentIds
        WITH SECURITY_ENFORCED
    ];
}

    public static List<AsyncApexJob> getRunningBatchJobs() {
        return [
            SELECT Id FROM AsyncApexJob
            WHERE Status IN ('Queued', 'Processing', 'Preparing')
              AND ApexClass.Name = 'S3UploaderBatch' WITH SECURITY_ENFORCED
        ];
    }
    public static Set<Id> getContentDocumentIds(String recordId){
    if (recordId == null) {
        return new Set<Id>();
    }
    Set<Id> ids = new Set<Id>();
    for(ContentDocumentLink cdl : [
        SELECT ContentDocumentId
        FROM ContentDocumentLink
        WHERE LinkedEntityId = :recordId
        WITH SECURITY_ENFORCED
    ]){
        if (cdl.ContentDocumentId != null) {
            ids.add(cdl.ContentDocumentId);
        }
    }
    return ids;
}


public static void deleteContentDocuments(Set<Id> docIds) {
    if (docIds == null || docIds.isEmpty()) {
        return;
    }
    Database.delete(
        getContentDocumentsById(docIds),
        false,
        AccessLevel.USER_MODE
    );
}

public static void deleteAttachments(Set<Id> attachmentIds) {
    if (attachmentIds == null || attachmentIds.isEmpty()) {
        return;
    }
    Database.delete(
        getAttachmentsById(attachmentIds),
        false,
        AccessLevel.USER_MODE
    );
}

public static List<AsyncApexJob> getJobsWithCreator(Set<Id> ids) {
    if (ids == null || ids.isEmpty()) {
        return new List<AsyncApexJob>();
    }
    return [
        SELECT Id, CreatedById
        FROM AsyncApexJob
        WHERE Id IN :ids
        WITH SECURITY_ENFORCED
    ];
}

// ─── Content Queries for Batch ─────────────────────────────────────────────

public static Set<Id> getContentDocumentIdsByRecordIds(Set<Id> recordIds) {
    Set<Id> docIds = new Set<Id>();

    if (recordIds == null || recordIds.isEmpty()) return docIds;

    for (ContentDocumentLink link : [
        SELECT ContentDocumentId
        FROM ContentDocumentLink
        WHERE LinkedEntityId IN :recordIds WITH SECURITY_ENFORCED
    ]) {
        docIds.add(link.ContentDocumentId);
    }

    return docIds;
}

public static Database.QueryLocator getLatestContentVersions(Set<Id> docIds) {
    if (docIds == null || docIds.isEmpty()) {
        return Database.getQueryLocator(
            [SELECT Id FROM ContentVersion WHERE Id = null WITH SECURITY_ENFORCED ]
        );
    }

    return Database.getQueryLocator([
        SELECT Id, Title, FileExtension, VersionData,
               ContentDocumentId, FirstPublishLocationId
        FROM ContentVersion
        WHERE ContentDocumentId IN :docIds
        AND IsLatest = TRUE WITH SECURITY_ENFORCED
    ]);
}

public static List<SObject> getOrgBackupRecords(String objectName) {
    if (objectName == null || String.isBlank(objectName)) return new List<SObject>();
    
    try {
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
        if (objType == null) return new List<SObject>();
        
        Map<String, Schema.SObjectField> fieldMap = 
            objType.getDescribe().fields.getMap();
        
        List<String> queryableFields = new List<String>();
        
        for (String fieldName : fieldMap.keySet()) {
            Schema.DescribeFieldResult dfr = fieldMap.get(fieldName).getDescribe();
            if (dfr.getType() == Schema.DisplayType.BASE64) continue;
            if (!dfr.isAccessible()) continue;
            queryableFields.add(dfr.getName());
        }
        
        if (queryableFields.isEmpty()) return new List<SObject>();
        
        queryableFields.sort();
        if (queryableFields.contains('Id')) {
            queryableFields.remove(queryableFields.indexOf('Id'));
            queryableFields.add(0, 'Id');
        }
        
        String query = 'SELECT ' + String.join(queryableFields, ', ') 
                     + ' FROM ' + String.escapeSingleQuotes(objectName)
                     + ' ORDER BY Id ASC LIMIT 1000';
        
        return Database.query(query);
        
    } catch (Exception e) {
        return new List<SObject>();
    }
}

public static List<AsyncApexJob> getBackupJobsByIdSet(Set<Id> ids) {
    if (ids == null || ids.isEmpty()) return new List<AsyncApexJob>();
    
    return [
        SELECT Id, Status, ApexClass.Name, CreatedDate, CreatedById,
               JobItemsProcessed, TotalJobItems
        FROM   AsyncApexJob
        WHERE  Id IN :ids WITH SECURITY_ENFORCED
        ORDER BY CreatedDate DESC
    ];
}

public static Integer countActiveOrgBackupJobsByIdSet(
    Set<Id>     ids,
    Set<String> activeStatuses
) {
    if (ids == null || ids.isEmpty()) return 0;
    if (activeStatuses == null || activeStatuses.isEmpty()) return 0;
    
    return [
        SELECT COUNT()
        FROM   AsyncApexJob
        WHERE  Id     IN :ids 
          AND  Status IN :activeStatuses WITH SECURITY_ENFORCED
    ];
}


public static List<ApexClass> getApexClasses() {
    return [
        SELECT Name FROM ApexClass
        WHERE NamespacePrefix = null WITH SECURITY_ENFORCED
        ORDER BY Name ASC LIMIT 1000
    ];
}
 
public static List<AuraDefinitionBundle> getLightningComponents() {
    return [
        SELECT MasterLabel FROM AuraDefinitionBundle
        WHERE NamespacePrefix = null WITH SECURITY_ENFORCED
        ORDER BY MasterLabel ASC LIMIT 1000
    ];
}
 
public static List<EntityDefinition> getCustomMetadata() {
    return [
        SELECT QualifiedApiName FROM EntityDefinition
        WHERE IsCustomizable = true
          AND QualifiedApiName LIKE '%__mdt' WITH SECURITY_ENFORCED
        ORDER BY QualifiedApiName ASC LIMIT 500
    ];
}
 
public static List<EntityDefinition> getCustomSettings() {
    return [
        SELECT QualifiedApiName FROM EntityDefinition
        WHERE IsCustomizable = true
          AND IsCustomSetting = true WITH SECURITY_ENFORCED
        ORDER BY QualifiedApiName ASC LIMIT 500 
    ];
}
 
public static List<NamedCredential> getNamedCredentials() {
    return [
        SELECT MasterLabel FROM NamedCredential WITH SECURITY_ENFORCED
        ORDER BY MasterLabel ASC LIMIT 500
    ];
}
 
public static List<FlowDefinitionView> getActiveFlows() {
    return [
        SELECT DurableId, Label FROM FlowDefinitionView
        WHERE IsActive = true WITH SECURITY_ENFORCED
        ORDER BY Label ASC LIMIT 1000
    ];
}
 
public static List<EmailTemplate> getEmailTemplates() {
    return [
        SELECT Id, Name FROM EmailTemplate WITH SECURITY_ENFORCED
        ORDER BY Name ASC LIMIT 1000
    ];
}
 
public static List<OrgWideEmailAddress> getOrgWideEmailAddresses() {
    return [
        SELECT Id, DisplayName, Address FROM OrgWideEmailAddress WITH SECURITY_ENFORCED
        ORDER BY DisplayName ASC LIMIT 500
    ];
}
 
public static List<Profile> getProfiles() {
    return [
        SELECT Id, Name FROM Profile WITH SECURITY_ENFORCED
        ORDER BY Name ASC LIMIT 500
    ];
}
 
public static List<PermissionSet> getPermissionSets() {
    return [
        SELECT Id, Name, Label FROM PermissionSet
        WHERE IsOwnedByProfile = false WITH SECURITY_ENFORCED
        ORDER BY Label ASC LIMIT 500
    ];
}
 
public static List<User> getActiveUsers() {
    return [
        SELECT Id, Name FROM User
        WHERE IsActive = true WITH SECURITY_ENFORCED
        ORDER BY Name ASC LIMIT 1000
    ];
}
 
public static List<Report> getReports() {
    return [
        SELECT Id, Name FROM Report
        WHERE NamespacePrefix = null WITH SECURITY_ENFORCED
        ORDER BY Name ASC LIMIT 1000
    ];
}
 
public static List<Dashboard> getDashboards() {
    return [
        SELECT Id, Title FROM Dashboard WITH SECURITY_ENFORCED
        ORDER BY Title ASC LIMIT 1000
    ];
}
 
public static List<RecordType> getAllRecordTypes() {
    return [
        SELECT Id, Name, SobjectType FROM RecordType WITH SECURITY_ENFORCED
        ORDER BY Name ASC
    ];
}
 
public static List<ApexTrigger> getAllTriggers() {
    return [
        SELECT Id, Name, TableEnumOrId, Status
        FROM ApexTrigger WITH SECURITY_ENFORCED
        ORDER BY Name 
    ];
}
 
// ─── OrgBackupManager: Async Job Queries ──────────────────────────────────
 
public static List<AsyncApexJob> getActiveOrgBackupJobs(Set<String> activeStatuses) {
    if (activeStatuses == null || activeStatuses.isEmpty()) {
        return new List<AsyncApexJob>();
    }
    return [
        SELECT Id, Status, ApexClass.Name, CreatedDate, CreatedById,
               JobItemsProcessed, TotalJobItems
        FROM AsyncApexJob
        WHERE JobType IN ('BatchApex', 'Queueable')
          AND Status IN :activeStatuses
        WITH SECURITY_ENFORCED
        ORDER BY CreatedDate DESC
        LIMIT 20
    ];
}
 
public static Integer countActiveOrgBackupJobsByClass(
    String      className,
    Set<String> activeStatuses
) {
    return [
        SELECT COUNT() FROM AsyncApexJob
        WHERE ApexClass.Name = :className
          AND Status IN :activeStatuses WITH SECURITY_ENFORCED
    ];
}
 
// ─── OrgBackupManager: Tooling API / Schema ────────────────────────────────
 
public static List<Map<String, String>> getRemoteSiteSettings() {
    List<Map<String, String>> remoteSites = new List<Map<String, String>>();
    try {
        String soql = EncodingUtil.urlEncode(
            'SELECT Id, SiteName, EndpointUrl FROM RemoteProxy LIMIT 100', 'UTF-8'
        );
        String body = toolingQuery(soql);
        Map<String, Object> data    = (Map<String, Object>) JSON.deserializeUntyped(body);
        List<Object>        records = (List<Object>) data.get('records');
        if (records != null) {
            for (Object obj : records) {
                Map<String, Object> rec  = (Map<String, Object>) obj;
                Map<String, String> item = new Map<String, String>();
                item.put('id',   (String) rec.get('Id'));
                item.put('name', (String) rec.get('SiteName'));
                item.put('url',  (String) rec.get('EndpointUrl'));
                remoteSites.add(item);
            }
        }
    } catch (Exception e) {
    }
    return remoteSites;
}
 
public static List<Map<String, String>> fetchAllMetadata() {
    List<Map<String, String>> allItems = new List<Map<String, String>>();
 
    try {
        String soql = EncodingUtil.urlEncode(
            'SELECT Id, ValidationName, EntityDefinition.QualifiedApiName FROM ValidationRule LIMIT 2000',
            'UTF-8'
        );
        Map<String, Object> data    = (Map<String, Object>) JSON.deserializeUntyped(toolingQuery(soql));
        List<Object>        records = (List<Object>) data.get('records');
        if (records != null) {
            for (Object obj : records) {
                Map<String, Object> rec    = (Map<String, Object>) obj;
                Map<String, Object> entity = (Map<String, Object>) rec.get('EntityDefinition');
                Map<String, String> item   = new Map<String, String>();
                item.put('type', 'ValidationRule');
                item.put('id',   (String) rec.get('Id'));
                item.put('name', (entity != null ? (String) entity.get('QualifiedApiName') : 'Unknown')
                                 + '.' + (String) rec.get('ValidationName'));
                allItems.add(item);
            }
        }
    } catch (Exception e) {
    }
 
    try {
        String soql = EncodingUtil.urlEncode(
            'SELECT Id, Name, TableEnumOrId FROM WorkflowRule LIMIT 2000', 'UTF-8'
        );
        Map<String, Object> data    = (Map<String, Object>) JSON.deserializeUntyped(toolingQuery(soql));
        List<Object>        records = (List<Object>) data.get('records');
        if (records != null) {
            for (Object obj : records) {
                Map<String, Object> rec  = (Map<String, Object>) obj;
                Map<String, String> item = new Map<String, String>();
                item.put('type', 'WorkflowRule');
                item.put('id',   (String) rec.get('Id'));
                item.put('name', (String) rec.get('TableEnumOrId') + '.' + (String) rec.get('Name'));
                allItems.add(item);
            }
        }
    } catch (Exception e) {
    }
 
    try {
        String soql = EncodingUtil.urlEncode(
            'SELECT Id, Name, TableEnumOrId FROM Layout LIMIT 2000', 'UTF-8'
        );
        Map<String, Object> data    = (Map<String, Object>) JSON.deserializeUntyped(toolingQuery(soql));
        List<Object>        records = (List<Object>) data.get('records');
        if (records != null) {
            for (Object obj : records) {
                Map<String, Object> rec  = (Map<String, Object>) obj;
                Map<String, String> item = new Map<String, String>();
                item.put('type', 'PageLayout');
                item.put('id',   (String) rec.get('Id'));
                item.put('name', (String) rec.get('Name'));
                allItems.add(item);
            }
        }
    } catch (Exception e) {
    }
 
    try {
        String soql = EncodingUtil.urlEncode(
            'SELECT Id, DeveloperName, MasterLabel FROM FlexiPage LIMIT 2000', 'UTF-8'
        );
        Map<String, Object> data    = (Map<String, Object>) JSON.deserializeUntyped(toolingQuery(soql));
        List<Object>        records = (List<Object>) data.get('records');
        if (records != null) {
            for (Object obj : records) {
                Map<String, Object> rec  = (Map<String, Object>) obj;
                Map<String, String> item = new Map<String, String>();
                item.put('type', 'LightningPage');
                item.put('id',   (String) rec.get('Id'));
                item.put('name', (String) rec.get('MasterLabel'));
                allItems.add(item);
            }
        }
    } catch (Exception e) {
    }

    // ─── Nested loop removed ────────────────────────────────────────────────
    // BEFORE: for (String objName : globalMap.keySet()) {
    //             for (String fieldName : fieldMap.keySet()) { ... }
    //         }
    // AFTER : inner field iteration moved to private helper collectFormulaFields()
    //         so this method has only a single loop over object names.
    Map<String, Schema.SObjectType> globalMap = Schema.getGlobalDescribe();
    for (String objName : globalMap.keySet()) {
        allItems.addAll(collectFormulaFields(objName, globalMap.get(objName)));
    }
 
    return allItems;
}

// ─── New private helper: replaces the inner fieldMap loop in fetchAllMetadata ──
// Accepts one SObjectType, iterates its fields once, and returns formula-field
// rows — no nesting needed in the caller.
@TestVisible
private static List<Map<String, String>> collectFormulaFields(
    String             objName,
    Schema.SObjectType objType
) {
    List<Map<String, String>> rows = new List<Map<String, String>>();
    try {
        Map<String, Schema.SObjectField> fieldMap =
            objType.getDescribe().fields.getMap();
        for (String fieldName : fieldMap.keySet()) {
            Schema.DescribeFieldResult dfr = fieldMap.get(fieldName).getDescribe();
            if (dfr.isCalculated()) {
                Map<String, String> item = new Map<String, String>();
                item.put('type', 'FormulaField');
                item.put('id',   null);
                item.put('name', objName + '.' + dfr.getName());
                rows.add(item);
            }
        }
    } catch (Exception e) {
    }
    return rows;
}
 
// ─── Private: Tooling API HTTP ────────────────────────────────────────────
@TestVisible
private static String toolingQuery(String encodedSoql) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint(
        'callout:Salesforce_Tooling/services/data/v59.0/tooling/query/?q=' + encodedSoql
    );
    req.setMethod('GET');
    req.setHeader('Content-Type', 'application/json');
    req.setTimeout(30000);
    HttpResponse res = new Http().send(req);
    if (res.getStatusCode() != 200) {
        throw new CalloutException(
            'Tooling API returned HTTP ' + res.getStatusCode() + ': ' + res.getBody()
        );
    }
    return res.getBody();
}


public static List<String> getQueryableFields(String objName) {
    List<String> fields = new List<String>();
    try {
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objName);
        if (objType == null) return fields;
        Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();
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
    } catch (Exception e) {
    }
    return fields;
}
 
public static List<SObject> getRecordsByQuery(
    String       objectName,
    List<String> fieldNames,
    List<String> recordIds
) {
    try {
        return Database.query(
            'SELECT ' + String.join(fieldNames, ', ')
            + ' FROM '  + String.escapeSingleQuotes(objectName)
            + ' WHERE Id IN :recordIds ORDER BY Id ASC'
        );
    } catch (Exception e) {
        return new List<SObject>();
    }
}


    public static List<ContentVersion> getLatestContentVersionRecords(Set<Id> docIds) {
         if (docIds == null || docIds.isEmpty()) {
        return new List<ContentVersion>();
    }

        return [
            SELECT Id, Title, FileExtension, VersionData, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds 
            AND IsLatest = TRUE WITH SECURITY_ENFORCED
        ];
    }

    public static List<Attachment> getAttachments(String recordId) {

    if (recordId == null) {
        return new List<Attachment>();
    }

    return [
        SELECT Id, Name, Body, ContentType, ParentId
        FROM Attachment
        WHERE ParentId = :recordId
        WITH SECURITY_ENFORCED
    ];
}
    public static List<String> buildGroupCsvLines(Map<String, Object> parsed) {
    if (parsed == null || parsed.isEmpty()) {
        return new List<String>();
    }

    List<String> lines = new List<String>();
    for (String groupKey : parsed.keySet()) {

        Object rawItems = parsed.get(groupKey);

        if (rawItems == null || !(rawItems instanceof List<Object>)) {
            continue;
        }
        List<Object> items = (List<Object>) rawItems;

        if (items.isEmpty()) {
            continue;
        }
        Integer i = 0;
        while (i < items.size()) {
            lines.add(
                escapeCsvValue(groupKey) + ',' +
                escapeCsvValue(String.valueOf(items[i]))
            );
            i++;
        }
    }
    return lines;
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
    
    public static List<String> buildOrgFullCsvLines(
    List<String> objectList,
    Map<String, Object> meta,
    Map<String, Object> config
) {
    List<String> lines = new List<String>();

    // Flatten all data into one list
    List<Map<String, String>> flatList = new List<Map<String, String>>();

    // data
    for (String obj : objectList) {
        flatList.add(new Map<String, String>{
            'category' => 'data',
            'key'      => obj,
            'value'    => ''
        });
    }

    // metadata flatten (NO nested loop here)
    for (String k : meta.keySet()) {
        List<Object> values = (List<Object>) meta.get(k);
        Integer i = 0;
        while (i < values.size()) {
            flatList.add(new Map<String, String>{
                'category' => 'metadata',
                'key'      => k,
                'value'    => String.valueOf(values[i])
            });
            i++;
        }
    }

    // config flatten (NO nested loop)
    for (String k : config.keySet()) {
        List<Object> values = (List<Object>) config.get(k);
        Integer i = 0;
        while (i < values.size()) {
            flatList.add(new Map<String, String>{
                'category' => 'config',
                'key'      => k,
                'value'    => String.valueOf(values[i])
            });
            i++;
        }
    }

    //  ONLY ONE FINAL LOOP
    for (Map<String, String> item : flatList) {
        lines.add(
            item.get('category') + ',' +
            escapeCsvValue(item.get('key')) + ',' +
            escapeCsvValue(item.get('value'))
        );
    }

    return lines;
}
    public static List<String> buildCsvLines(
    List<String> headers,
    List<SObject> records
) {
    List<String> lines = new List<String>();

    for (SObject rec : records) {
        List<String> values = new List<String>();

        Integer i = 0;
        while (i < headers.size()) {
            //  use existing method
            values.add(escapeCsvValue(rec.get(headers[i])));
            i++;
        }

        lines.add(String.join(values, ','));
    }

    return lines;
}

public static void updateFileRecoveryLog(
    Id logId,
    String s3Key,
    String status,
    String errorMsg
) {
    try {
        File_Recovery_Log__c logRecord = new File_Recovery_Log__c(
            Id               = logId,
            S3_Key__c        = s3Key,
            Backup_Status__c = status,
            Error_Message__c = errorMsg
        );
        Database.update(logRecord, false, AccessLevel.USER_MODE);
    } catch (Exception e) {
        // silently handled
    }
}

public static Map<String, String> getNameFields(Set<String> objectTypes) {
    Map<String, String> result = new Map<String, String>();
    Map<String, Schema.SObjectType> globalDesc = Schema.getGlobalDescribe();
    for (String obj : objectTypes) {
        String nameField = 'Id';
        if (globalDesc.containsKey(obj)) {
            Schema.DescribeSObjectResult d =
                globalDesc.get(obj).getDescribe();
            Map<String, Schema.SObjectField> fields = d.fields.getMap();
            if (fields.containsKey('Name')) {
                nameField = 'Name';
            }
        }

        result.put(obj, nameField);
    }

    return result;
}

public static File_Recovery_Log__c sanitizeLogName(
    File_Recovery_Log__c log,
    String moduleCode,
    String actionCode
) {
    if (log == null) return log;

    // Only rebuild File_Name__c if blank or raw SF ID
    String fileName = log.File_Name__c;
    Boolean isBlankOrId = String.isBlank(fileName)
        || ((fileName.length() == 15 || fileName.length() == 18)
            && fileName.isAlphanumeric());

    if (isBlankOrId) {
        String prefix  = String.isNotBlank(log.Action_Type__c) ? log.Action_Type__c : 'Log';
        String objPart = '';
        if (String.isNotBlank(log.Object_Name__c)) {
            List<String> objList = log.Object_Name__c.split(',');
            objPart = objList.size() == 1
                ? '-' + objList[0].trim().left(30)
                : '-Multiple Objects';
        }
        log.File_Name__c = prefix + objPart + '-'
                           + DateTime.now().format('yyyy-MM-dd_HH-mm-ss');
    }

    // Only set Name if blank — never overwrite a pre-set Name
    if (String.isBlank(log.Name)) {
        log.Name = generateLogFileName(moduleCode, actionCode);
    }

    return log;
}

public static File_Recovery_Log__c sanitizeLogName(File_Recovery_Log__c log) {
    return sanitizeLogName(log, 'FIL', 'BKP');
}
public static List<File_Recovery_Log__c> sanitizeLogNames(
    List<File_Recovery_Log__c> logs
) {
    if (logs == null) return logs;
    for (File_Recovery_Log__c l : logs) sanitizeLogName(l);
    return logs;
}
public static Integer countDeletedRecords(String objectType) {
    return Database.countQuery(
        'SELECT COUNT() FROM ' + objectType +
        ' WHERE IsDeleted = true ALL ROWS'
    );
}
public static AsyncApexJob getJobById(Id jobId) {
    if (jobId == null) return null;
    return [
        SELECT Status
        FROM AsyncApexJob
        WHERE Id = :jobId
        WITH SECURITY_ENFORCED
        LIMIT 1
    ];
}
public static List<File_Recovery_Log__c> getRestoreLogsByFileIds(List<Id> fileIds) {
    if (fileIds == null || fileIds.isEmpty()) return new List<File_Recovery_Log__c>();
    return [
        SELECT Id, S3_Key__c, File_Name__c, Record_Id__c, Object_Name__c
        FROM File_Recovery_Log__c
        WHERE Id             IN :fileIds
          AND Action_Type__c   = 'Backup'
          AND Backup_Status__c = 'Failed'
          AND S3_Key__c        != null
          AND Restore_Status__c != 'Completed'
        WITH SECURITY_ENFORCED
        ORDER BY File_Name__c ASC
    ];
}

public static String generateLogFileName(String moduleCode, String actionCode) {
    DateTime now       = DateTime.now();
    String   datePart  = now.format('yyyyMMdd');
    String   timePart  = now.format('HHmmss');
    String   randPart  = String.valueOf(
                             Math.abs(Math.mod(Integer.valueOf(Math.random() * 10000), 10000))
                         ).leftPad(4, '0');

    return moduleCode + '-' + actionCode + '-' + datePart + '-' + timePart + '-' + randPart;
}
public static Map<String, Integer> countDeletedRec(Set<String> objectTypes) {
    Map<String, Integer> result = new Map<String, Integer>();
    List<String> typeList = new List<String>(objectTypes);
    return countDeletedRecHelper(typeList, 0, result);
}

private static Map<String, Integer> countDeletedRecHelper(List<String> typeList, Integer index, Map<String, Integer> result) {
    if (index >= typeList.size()) {
        return result;
    }
    result.put(typeList[index], countDeletedRecords(typeList[index]));
    return countDeletedRecHelper(typeList, index + 1, result);
}

public static Map<String, Integer> countDeletedRecordsBulk(Set<String> objectTypes) {
    Map<String, Integer> result = new Map<String, Integer>();

    if (objectTypes == null || objectTypes.isEmpty()) {
        return result;
    }

    Map<String, Integer> deletedCounts = countDeletedRec(objectTypes);

    for (String objectType : objectTypes) {
        try {
            result.put(objectType, deletedCounts.get(objectType));
        } catch (Exception e) {
            result.put(objectType, 0);
        }
    }

    return result;
}
}