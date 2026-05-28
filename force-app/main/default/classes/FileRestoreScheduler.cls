global with sharing class FileRestoreScheduler implements Schedulable {

    private List<String> objectNames;
    private List<String> recordIds;
    private List<String> fileIds;

    global FileRestoreScheduler(List<String> objectNames, List<String> recordIds) {
        this.objectNames = objectNames;
        this.recordIds   = recordIds;
        this.fileIds     = new List<String>();
    }

    global FileRestoreScheduler(List<String> objectNames, List<String> recordIds, List<String> fileIds) {
        this.objectNames = objectNames;
        this.recordIds   = recordIds;
        this.fileIds     = fileIds != null ? fileIds : new List<String>();
    }

    global FileRestoreScheduler() {
        this.objectNames = null;
        this.recordIds   = null;
        this.fileIds     = new List<String>();
    }

  global void execute(SchedulableContext sc) {

    List<File_Recovery_Log__c> logs = new List<File_Recovery_Log__c>();

    if (this.fileIds != null && !this.fileIds.isEmpty()) {
        List<Id> fileIdList = new List<Id>();
        for (String fid : this.fileIds) fileIdList.add((Id) fid);
        List<File_Recovery_Log__c> tempLogs =
            AWSVaultSectionQueryHelper.getRestoreLogsByFileIds(fileIdList);
        if (tempLogs != null) logs.addAll(tempLogs);

    } else if (this.recordIds != null && !this.recordIds.isEmpty()) {
        List<Id> idList = new List<Id>();
        for (String rid : this.recordIds) idList.add((Id) rid);
        if (this.objectNames != null && !this.objectNames.isEmpty()) {
            List<File_Recovery_Log__c> tempLogs =
                AWSVaultSectionQueryHelper.getTargetedRestoreLogs(idList, this.objectNames);
            if (tempLogs != null) logs.addAll(tempLogs);
        }
    } else {
        List<File_Recovery_Log__c> tempLogs =
            AWSVaultSectionQueryHelper.getGlobalRestoreLogs();
        if (tempLogs != null) logs.addAll(tempLogs);
    }

    if (logs != null && !logs.isEmpty()) {
        // ── FIX: ONE single restore log for the scheduled operation ──
        String objName = (this.objectNames != null && !this.objectNames.isEmpty())
            ? String.join(this.objectNames, ',')
            : 'Multiple Objects';

        File_Recovery_Log__c restoreLog = new File_Recovery_Log__c(
            Object_Name__c    = objName,
            File_Name__c      = 'ScheduledRestore-' + objName + '-'
                                + DateTime.now().format('yyyy-MM-dd_HH-mm-ss'),
            Action_Type__c    = 'Restore',
            Restore_Status__c = 'In Progress',
            Restore_Time__c   = DateTime.now()
        );
        AWSVaultSectionQueryHelper.sanitizeLogName(restoreLog);
        AWSVaultSectionQueryHelper.insertLogs(
            new List<File_Recovery_Log__c>{ restoreLog }
        );

        AWSVaultSectionQueryHelper.enqueueFileRestore(logs);
    }
}
}