global with sharing class DataRestoreScheduler implements Schedulable {

    private List<String> objectNames;
    private List<String> recordIds;

    global DataRestoreScheduler(List<String> objectNames, List<String> recordIds) {
        this.objectNames = objectNames;
        this.recordIds   = recordIds;
    }

    global DataRestoreScheduler() {
        this.objectNames = null;
        this.recordIds   = null;
    }

    global void execute(SchedulableContext sc) {
    List<File_Recovery_Log__c> backupLogs = new List<File_Recovery_Log__c>();

    if (this.objectNames != null && !this.objectNames.isEmpty()) {
        Boolean isDataRestore = !this.objectNames[0].endsWith('_backup');

        if (isDataRestore) {
            backupLogs = AWSVaultSectionQueryHelper.queryEligibleDataLogs(
                this.objectNames,
                this.recordIds != null ? this.recordIds : new List<String>()
            );
        } else {
            backupLogs = AWSVaultSectionQueryHelper.querySchedulerBackupLogs(
                this.objectNames,
                this.recordIds != null ? this.recordIds : new List<String>()
            );
        }
    }

    // ── File_Name__c ──────────────────────────────────────────────────────
    String objectDisplayPart;
    if (this.objectNames == null || this.objectNames.isEmpty()) {
        objectDisplayPart = 'Unknown';
    } else if (this.objectNames.size() > 1) {
        objectDisplayPart = 'Multiple Objects';
    } else {
        objectDisplayPart = this.objectNames[0];
    }

    String logStatus  = backupLogs.isEmpty() ? 'Failed' : 'In Progress';
    String logMessage = backupLogs.isEmpty()
    ? 'No backup files found. Please run backup first.'
    : 'Scheduled restore executed successfully. '
      + backupLogs.size() + ' file(s) queued for restore.';
    try {
       AWSVaultSectionQueryHelper.insertLog(
    new File_Recovery_Log__c(
        Name              = AWSVaultSectionQueryHelper.generateLogFileName('DAT', 'RST'),
        File_Name__c      = 'Restore-' + objectDisplayPart + '-'
                            + DateTime.now().format('yyyy-MM-dd_HH-mm-ss'),
        Object_Name__c    = (this.objectNames == null || this.objectNames.isEmpty())
                            ? 'unknown'
                            : this.objectNames.size() > 1
                                ? JSON.serialize(this.objectNames)
                                : this.objectNames[0],
        Action_Type__c    = 'Restore',
        Restore_Status__c = logStatus,
        Restore_Time__c   = DateTime.now(),
        Error_Message__c  = logMessage
    )
);
    } catch (Exception e) {
        System.debug('insertLog failed: ' + e.getMessage());
    }

    if (backupLogs.isEmpty()) return;

    List<File_Recovery_Log__c> intentLogs =
        AWSVaultSectionQueryHelper.getScheduledIntentLogs();

    if (!intentLogs.isEmpty()) {
        for (File_Recovery_Log__c l : intentLogs) {
            l.Restore_Status__c = 'In Progress';
        }
        AWSVaultSectionQueryHelper.updateLogs(intentLogs);
    }

    System.enqueueJob(new DataRestoreQueueable(backupLogs));
}
}