public with sharing class RecycleBinRestoreBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {

    private List<Id>     backupLogIds;
    private List<Id>     restoreLogIds;
    private List<String> selectedRecordIds;

    public RecycleBinRestoreBatch(
        List<Id>     backupLogIds,
        List<Id>     restoreLogIds,
        List<String> selectedRecordIds
    ) {
        this.backupLogIds      = backupLogIds;
        this.restoreLogIds     = restoreLogIds;
        this.selectedRecordIds = selectedRecordIds;
    }

    public List<SObject> start(Database.BatchableContext bc) {
        return AWSVaultSectionQueryHelper.getBackupLogsByIds(backupLogIds);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        String restoreStatus = 'Completed';
        String errorMessage  = null;
        for (SObject s : scope) {
            File_Recovery_Log__c bl = (File_Recovery_Log__c) s;
            try {
                RecycleBinRestoreService.restoreFromS3(
                    bl.S3_Key__c,
                    bl.Object_Name__c,
                    this.selectedRecordIds
                );
            } catch (Exception e) {
                restoreStatus = 'Failed';
                errorMessage  = e.getMessage().left(255);
            }
        }

        List<File_Recovery_Log__c> toUpdate = new List<File_Recovery_Log__c>();
        for (Id rlId : restoreLogIds) {
            toUpdate.add(new File_Recovery_Log__c(
                Id                = rlId,
                Restore_Status__c = restoreStatus,
                Restore_Time__c   = DateTime.now(),
                Error_Message__c  = errorMessage
            ));
        }

        AWSVaultSectionQueryHelper.updateRecycleBinRestoreLogs(toUpdate);
    }

  public void finish(Database.BatchableContext bc) {
    // String jobId = String.valueOf(bc.getJobId());

    // List<File_Recovery_Log__c> toUpdate = new List<File_Recovery_Log__c>();
    // for (Id rlId : restoreLogIds) {
    //     toUpdate.add(new File_Recovery_Log__c(
    //         Id               = rlId,
    //         Parent_Job_Id__c = jobId
    //     ));
    // }

    // if (!toUpdate.isEmpty()) {
    //     AWSVaultSectionQueryHelper.updateRecycleBinRestoreLogs(toUpdate);
    // }
}
}