public with sharing class BackupScheduler implements Schedulable {

    // ─── State ────────────────────────────────────────────────────────────────
    private final List<String> objectNames;
    private final List<String> recordIds;

    // ─── Public Constructors ──────────────────────────────────────────────────

    public BackupScheduler(String objectName, List<String> recordIds) {
        this.objectNames = new List<String>{ objectName };
        this.recordIds   = recordIds;
    }

    public BackupScheduler(List<String> objectNames) {
        this.objectNames = objectNames;
        this.recordIds   = null;
    }

    // ─── Execute ──────────────────────────────────────────────────────────────
    public void execute(SchedulableContext context) {

        String objectNameValue = String.join(objectNames, ', ');

        File_Recovery_Log__c log = new File_Recovery_Log__c(
            Name             = AWSVaultSectionQueryHelper.generateLogFileName('FIL', 'BKP'),
            Object_Name__c   = objectNameValue,
            Action_Type__c   = 'Backup',
            Backup_Status__c = 'Failed',
            Backup_Time__c   = DateTime.now()
        );

        AWSVaultSectionQueryHelper.insertBackupLog(log);

        if (isSpecificRecordMode()) {
            System.enqueueJob(new BackupQueueable(objectNames, recordIds));
        } else {
            System.enqueueJob(new BackupQueueable(objectNames, 0));
        }
    }

    private Boolean isSpecificRecordMode() {
        return recordIds != null && !recordIds.isEmpty();
    }
}