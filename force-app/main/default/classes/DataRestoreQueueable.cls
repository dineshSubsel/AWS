public with sharing class DataRestoreQueueable implements Queueable, Database.AllowsCallouts {

    private List<File_Recovery_Log__c> backupLogs;
    private List<File_Recovery_Log__c> restoreLogs;
    private Integer startIndex;
    private Integer batchSize;

    private static final Integer DEFAULT_BATCH = 5;
    public DataRestoreQueueable(
        List<File_Recovery_Log__c> backupLogs,
        List<File_Recovery_Log__c> restoreLogs
    ) {
        this(backupLogs, restoreLogs, 0, DEFAULT_BATCH);
    }
    public DataRestoreQueueable(List<File_Recovery_Log__c> backupLogs) {
        this(backupLogs, null, 0, DEFAULT_BATCH);
    }
    private DataRestoreQueueable(
        List<File_Recovery_Log__c> backupLogs,
        List<File_Recovery_Log__c> restoreLogs,
        Integer startIndex,
        Integer batchSize
    ) {
        this.backupLogs  = backupLogs;
        this.restoreLogs = restoreLogs;
        this.startIndex  = startIndex;
        this.batchSize   = batchSize;
    }

  public void execute(QueueableContext ctx) {

    if (this.restoreLogs == null) {
        this.restoreLogs = DataRestoreController.createRestoreLogs(this.backupLogs);
    }
    File_Recovery_Log__c bl = this.backupLogs[this.startIndex];
    File_Recovery_Log__c rl = this.restoreLogs[this.startIndex];

    String restoreStatus = 'Completed';
    String errorMessage = null;

    try {
        DataRestoreService.restoreObjectData(
            bl.S3_Key__c,
            bl.Object_Name__c
        );
    } catch (Exception e) {
        restoreStatus = 'Failed';
        errorMessage = e.getMessage().left(255);
    }

    File_Recovery_Log__c updateLog = new File_Recovery_Log__c(
        Id = rl.Id,
        Restore_Status__c = restoreStatus,
        Restore_Time__c = DateTime.now(),
        Error_Message__c = errorMessage
    );

    AWSVaultSectionQueryHelper.updateLogs(new List<File_Recovery_Log__c>{ updateLog });
    Integer nextIndex = this.startIndex + 1;

    if (nextIndex < this.backupLogs.size()) {
        System.enqueueJob(new DataRestoreQueueable(
            this.backupLogs,
            this.restoreLogs,
            nextIndex,
            this.batchSize
        ));
    }
}
}