global with sharing class RecycleBinRestoreScheduler implements Schedulable {

    private List<String> objectNames;
    private List<String> recordIds;
        private String       objectNamesLabel;  
    global RecycleBinRestoreScheduler(List<String> objectNames, List<String> recordIds) {
        this.objectNames = objectNames;
        this.recordIds   = recordIds;
        this.objectNamesLabel = (objectNames != null && !objectNames.isEmpty())
                                    ? String.join(objectNames, ', ')
                                    : null;
    }
    global RecycleBinRestoreScheduler() {
        this.objectNames = null;
        this.recordIds   = null;
                this.objectNamesLabel = null;
    }

    global RecycleBinRestoreScheduler(List<String> objectNames, List<String> recordIds, String objectNamesLabel) {
        this.objectNames      = objectNames;
        this.recordIds        = recordIds;
        this.objectNamesLabel = objectNamesLabel;
    }

    global void execute(SchedulableContext sc) {
        List<File_Recovery_Log__c> backupLogs = resolveBackupLogs();
        List<File_Recovery_Log__c> intentLogs =
            AWSVaultSectionQueryHelper.getScheduledIntentLogs();
        AWSVaultSectionQueryHelper.markIntentLogsInProgress(intentLogs);
        if (!backupLogs.isEmpty()) {
            dispatchBatch(backupLogs);
        }
    }

    private List<File_Recovery_Log__c> resolveBackupLogs() {
        Boolean hasObjects = this.objectNames != null && !this.objectNames.isEmpty();
        Boolean hasIds     = this.recordIds   != null && !this.recordIds.isEmpty();

        if (hasObjects && hasIds) {
            List<Id> idList = AWSVaultSectionQueryHelper.toIdList(this.recordIds);
            return AWSVaultSectionQueryHelper.getBackupLogsByObjectsAndIds(
                this.objectNames, idList
            );
        }

        if (hasObjects) {
            return AWSVaultSectionQueryHelper.getBackupLogsByObjects(this.objectNames);
        }

        return AWSVaultSectionQueryHelper.getAllPendingBackupLogs();
    }

    private void dispatchBatch(List<File_Recovery_Log__c> backupLogs) {
        // Patch Object_Name__c on backupLogs before creating restore logs,
        // so createRestoreLogs() writes the human-readable label
        if (String.isNotBlank(objectNamesLabel)) {
            for (File_Recovery_Log__c bl : backupLogs) {
                if (String.isBlank(bl.Object_Name__c) || bl.Object_Name__c.contains(',')) {
                    bl.Object_Name__c = objectNamesLabel;  // ← use label for multi-object
                }
            }
        }

        List<Id> backupLogIds = AWSVaultSectionQueryHelper.extractIds(backupLogs);
        List<File_Recovery_Log__c> restoreLogs =
            RecycleBinVaultRestore_Controller.createRestoreLogs(backupLogs);
        List<Id> restoreLogIds = AWSVaultSectionQueryHelper.extractIds(restoreLogs);

        Database.executeBatch(
            new RecycleBinRestoreBatch(backupLogIds, restoreLogIds, this.recordIds),
            1
        );
    }
}