public with sharing class FileRecoveryVaultController {

    public class FileRow {
        @AuraEnabled public String   Id;
        @AuraEnabled public String   fileName;
        @AuraEnabled public Datetime backupTime;
    }


   @AuraEnabled(cacheable=true)
    public static List<String> getAllObjects() {
        return AWSVaultSectionQueryHelper.getAllObjects();
    }

    @AuraEnabled(cacheable=true)
    public static List<SObject> getRecords(String objectName) {
        if (objectName == null) return new List<SObject>();
        return AWSVaultSectionQueryHelper.getRecords(objectName);
    }


    @AuraEnabled(cacheable=true)
    public static List<ContentDocument> getFilesForRecords(List<Id> recordIds) {
        if (recordIds == null) return new List<ContentDocument>();
        return AWSVaultSectionQueryHelper.getFilesForRecords(recordIds);
    }

  @AuraEnabled(cacheable=true)
public static List<FileRow> getFilesForLogRecords(
    List<Id> selectedRecordIds,
    String objectName
) {
    if (selectedRecordIds == null || selectedRecordIds.isEmpty()) {
        return new List<FileRow>();
    }
    if (String.isBlank(objectName)) {
        return new List<FileRow>();
    }

    // Normalize to match stored value
    String normalizedObject = objectName.substring(0,1).toUpperCase() 
                            + objectName.substring(1).toLowerCase();

    return AWSVaultSectionQueryHelper.getFilesForLogRecords(
        selectedRecordIds, normalizedObject
    );
}

@AuraEnabled
public static List<String> startInstantRestore(
    String       selectedObjects,
    List<String> selectedRecordIds,
    List<String> selectedFileIds
) {
    if (String.isBlank(selectedObjects))
        throw new AuraHandledException('At least one object is required.');

    List<String> objectList = selectedObjects.split(',');
    for (Integer i = 0; i < objectList.size(); i++) {
        objectList[i] = objectList[i].trim();
    }

    String objectNameValue = objectList.size() == 1
        ? objectList[0]
        : JSON.serialize(objectList);

    List<Id> recordIdList = new List<Id>();
    if (selectedRecordIds != null && !selectedRecordIds.isEmpty()) {
        for (String s : selectedRecordIds) recordIdList.add((Id) s);
    }

    List<Id> fileIdList = new List<Id>();
    if (selectedFileIds != null && !selectedFileIds.isEmpty()) {
        for (String s : selectedFileIds) fileIdList.add((Id) s);
    }

    List<File_Recovery_Log__c> backupLogs = new List<File_Recovery_Log__c>();

    if (!fileIdList.isEmpty()) {
        backupLogs = [
            SELECT Id, S3_Key__c, File_Name__c, Record_Id__c, Object_Name__c
            FROM File_Recovery_Log__c
            WHERE Id              IN :fileIdList
              AND Action_Type__c    = 'Backup'
              AND Backup_Status__c  = 'Failed'
              AND S3_Key__c         != null
              AND Restore_Status__c != 'Completed'
            WITH SECURITY_ENFORCED
            ORDER BY File_Name__c ASC
        ];
    } else if (!recordIdList.isEmpty()) {
        backupLogs = [
            SELECT Id, S3_Key__c, File_Name__c, Record_Id__c, Object_Name__c
            FROM File_Recovery_Log__c
            WHERE Record_Id__c      IN :recordIdList
              AND Object_Name__c    IN :objectList
              AND Action_Type__c    = 'Backup'
              AND Backup_Status__c  = 'Failed'
              AND S3_Key__c         != null
              AND Restore_Status__c != 'Completed'
            WITH SECURITY_ENFORCED
            ORDER BY File_Name__c ASC
        ];
    }

    if (!backupLogs.isEmpty()) {
        // ── ONE single restore log for the entire operation ──
        File_Recovery_Log__c restoreLog = new File_Recovery_Log__c(
            Object_Name__c    = objectNameValue,
            Action_Type__c    = 'Restore',
            Restore_Status__c = 'In Progress',
            Restore_Time__c   = DateTime.now()
        );
        AWSVaultSectionQueryHelper.sanitizeLogName(restoreLog);
        AWSVaultSectionQueryHelper.insertLogs(
            new List<File_Recovery_Log__c>{ restoreLog }
        );

        AWSVaultSectionQueryHelper.enqueueFileRestore(backupLogs);

        return new List<String>{
            'Restore initiated for ' + backupLogs.size() + ' file(s).'
        };
    }

    // ── No backup files found — ONE single failed log ──
    File_Recovery_Log__c failedLog = new File_Recovery_Log__c(
        Object_Name__c    = objectNameValue,
        Action_Type__c    = 'Restore',
        Restore_Status__c = 'Failed',
        Restore_Time__c   = DateTime.now(),
        Error_Message__c  = 'No backup files found. Please run backup first.'
    );
    AWSVaultSectionQueryHelper.sanitizeLogName(failedLog);
    AWSVaultSectionQueryHelper.insertLogs(
        new List<File_Recovery_Log__c>{ failedLog }
    );

    return new List<String>{ 'No backup files found for ' + objectNameValue };
}
@AuraEnabled
public static String startScheduledRestore(
    String       selectedObjects,
    List<String> selectedRecordIds,
    List<String> selectedFileIds,        // ← NEW parameter
    String       frequency,
    String       restoreTime
) {
    validateRestoreInputs(selectedObjects, selectedRecordIds);
    validateScheduleInputs(frequency, restoreTime);
    List<String> objectList = parseObjectList(selectedObjects);

    List<String> timeParts = restoreTime.split(':');
    Integer schedHour = Integer.valueOf(timeParts[0]);
    Integer schedMin  = timeParts.size() > 1 ? Integer.valueOf(timeParts[1]) : 0;

    Date today = Date.today();
    DateTime scheduledDateTime = DateTime.newInstance(
        today.year(), today.month(), today.day(),
        schedHour, schedMin, 0
    );

    String restoreObjectPart;
    if (objectList.size() > 1) {
        restoreObjectPart = 'Multiple Objects';
    } else {
        String obj = objectList[0];
        restoreObjectPart = obj.substring(0,1).toUpperCase() + obj.substring(1);
    }

    String cronExp = generateCronExpression(frequency, restoreTime);

    String jobName = 'FRV-' + selectedObjects.replaceAll(',', '_')
                   + '-' + frequency.toUpperCase()
                   + '-' + System.now().format('yyyyMMdd_HHmmss');

    FileRestoreScheduler scheduler = new FileRestoreScheduler(
        selectedObjects.split(','),
        (selectedRecordIds != null && !selectedRecordIds.isEmpty())
            ? selectedRecordIds
            : new List<String>(),
        (selectedFileIds != null && !selectedFileIds.isEmpty())
            ? selectedFileIds
            : new List<String>()
    );

    AWSVaultSectionQueryHelper.scheduleJob(jobName, cronExp, scheduler);
    return jobName;
}

    @AuraEnabled
public static List<String> startInstantBackup(
    String       selectedObjects,
    List<String> recordIds
) {
    if (String.isBlank(selectedObjects)) {
        throw new AuraHandledException('At least one object is required.');
    }

    List<String> objectList = parseObjectList(selectedObjects);
    List<String> jobIds     = new List<String>();
    List<File_Recovery_Log__c> logs = new List<File_Recovery_Log__c>();

    // ✅ Always ONE log — whether records selected or not
  /*  File_Recovery_Log__c log = new File_Recovery_Log__c(
        Object_Name__c   = JSON.serialize(objectList),
        Action_Type__c   = 'Backup',
        Backup_Status__c = 'Failed',
        Backup_Time__c   = DateTime.now()
    );
    AWSVaultSectionQueryHelper.sanitizeLogName(log);
    logs.add(log);

    AWSVaultSectionQueryHelper.insertLogs(logs); */

    if (recordIds == null || recordIds.isEmpty()) {
        BackupQueueable q = new BackupQueueable(objectList, 0);
        if (!Test.isRunningTest()) System.enqueueJob(q);
        jobIds.add(q.jobId);
    } else {
        BackupQueueable q = new BackupQueueable(objectList, recordIds);
        if (!Test.isRunningTest()) System.enqueueJob(q);
        jobIds.add(q.jobId);
    }

    return jobIds;
}

@AuraEnabled
public static List<String> startScheduledBackup(
    String selectedObjects,
    List<String> recordIds,
    String frequency,
    String backupTime
) {
    if (String.isBlank(selectedObjects)) {
        throw new AuraHandledException('At least one object is required.');
    }
    validateScheduleInputs(frequency, backupTime);
    String cronExp = generateCronExpression(frequency, backupTime);
    List<String> objectList = parseObjectList(selectedObjects);
    List<String> jobNames = new List<String>();

    if (objectList == null || objectList.isEmpty()) {
        throw new AuraHandledException('No objects to schedule.');
    }

    if (recordIds == null || recordIds.isEmpty()) {
        BackupScheduler scheduler = new BackupScheduler(objectList);
        String jobName = buildJobName(String.join(objectList, '_'), frequency);
        jobNames.add(jobName);
        AWSVaultSectionQueryHelper.scheduleJob(jobName, cronExp, scheduler);
    } else {
        BackupScheduler scheduler = new BackupScheduler(objectList[0], recordIds);
        String jobName = buildJobName(objectList[0], frequency);
        jobNames.add(jobName);
        AWSVaultSectionQueryHelper.scheduleJob(jobName, cronExp, scheduler);
    }

    return jobNames;
}

   @AuraEnabled
public static List<Map<String, String>> getBackupJobStatus(List<String> jobIds) {
    List<Map<String, String>> result = new List<Map<String, String>>();

    if (jobIds == null || jobIds.isEmpty()) {
        return result;
    }

    List<AsyncApexJob> jobs = AWSVaultSectionQueryHelper.queryActiveBackupJobs(jobIds);

    for (AsyncApexJob job : jobs) {
        result.add(AWSVaultSectionQueryHelper.toStatusRow(job));
    }

    return result;
}

    @AuraEnabled
    public static Boolean areAllJobsDone(List<String> jobIds) {
        return AWSVaultSectionQueryHelper.areAllBackupJobsDone(jobIds);
    }

    @AuraEnabled
    public static void abortJob(String jobId) {
        if (String.isBlank(jobId)) throw new AuraHandledException('Invalid Job Id');
        try {
            AWSVaultSectionQueryHelper.abortJob(jobId);
        } catch (Exception e) {
            throw new AuraHandledException('Failed to abort job: ' + e.getMessage());
        }
    }

   @AuraEnabled
public static List<Map<String, String>> getBackupJobStatusRestore(List<String> jobIds) {
    List<Map<String, String>> result = new List<Map<String, String>>();

    if (jobIds == null || jobIds.isEmpty()) {
        return result;
    }

    List<AsyncApexJob> jobs = AWSVaultSectionQueryHelper.queryRestoreJobs(jobIds);

    for (AsyncApexJob job : jobs) {
        result.add(AWSVaultSectionQueryHelper.toStatusRow(job));
    }

    return result;
}

    @AuraEnabled
    public static Boolean areAllJobsDoneRestore(List<String> jobIds) {
        return AWSVaultSectionQueryHelper.areAllRestoreJobsDone(jobIds);
    }

   private static void validateRestoreInputs(String selectedObjects, List<String> selectedRecordIds) {
    if (String.isBlank(selectedObjects))
        throw new AuraHandledException('At least one object is required.');
    
    List<String> objectList = parseObjectList(selectedObjects);
    if (objectList.size() == 1 && (selectedRecordIds == null || selectedRecordIds.isEmpty()))
        throw new AuraHandledException('At least one record is required.');
}
    private static void validateScheduleInputs(String frequency, String scheduleTime) {
        if (String.isBlank(frequency))
            throw new AuraHandledException('Restore/backup frequency is required.');
        if (String.isBlank(scheduleTime))
            throw new AuraHandledException('Restore/backup time is required.');
    }

    private static String generateCronExpression(String frequency, String timeStr) {
        List<String> parts  = timeStr.split(':');
        Integer      hour   = Integer.valueOf(parts[0]);
        Integer      minute = parts.size() > 1 ? Integer.valueOf(parts[1]) : 0;

        switch on frequency.toLowerCase() {
            when 'daily'   { return '0 ' + minute + ' ' + hour + ' * * ?';   }
            when 'weekly'  { return '0 ' + minute + ' ' + hour + ' ? * MON'; }
            when 'monthly' { return '0 ' + minute + ' ' + hour + ' 1 * ?';   }
            when else {
                throw new AuraHandledException('Invalid frequency: ' + frequency);
            }
        }
    }

    private static List<String> parseObjectList(String selectedObjects) {
        List<String> result = new List<String>();
        for (String obj : selectedObjects.split(',')) {
            String trimmed = obj.trim();
            if (!String.isBlank(trimmed)) result.add(trimmed);
        }
        return result;
    }

    private static String buildJobName(String objectName, String frequency) {
        return 'FRV-' + objectName + '-' + frequency + '-' + System.now().getTime();
    }
}