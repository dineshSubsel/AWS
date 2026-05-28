public with sharing class FileRestoreQueueable implements Queueable, Database.AllowsCallouts {

    private List<File_Recovery_Log__c> logs;
    private Integer                    batchSize;
    private Integer                    startIndex;

    private static final Integer DEFAULT_BATCH = 5;

    public FileRestoreQueueable(List<File_Recovery_Log__c> logs) {
        this(logs, 0, DEFAULT_BATCH);
    }

    public FileRestoreQueueable(
        List<File_Recovery_Log__c> logs,
        Integer                    startIndex,
        Integer                    batchSize
    ) {
        this.logs       = logs;
        this.startIndex = startIndex;
        this.batchSize  = batchSize;
    }

    public void execute(QueueableContext context) {
        Integer endIndex = Math.min(this.startIndex + this.batchSize, this.logs.size());

        List<File_Recovery_Log__c> batch = new List<File_Recovery_Log__c>();
        for (Integer i = this.startIndex; i < endIndex; i++) {
            batch.add(this.logs[i]);
        }

        List<File_Recovery_Log__c> toUpdate = new List<File_Recovery_Log__c>();

        for (File_Recovery_Log__c log : batch) {
            try {
                FileRestoreService.restoreSingleFile(
                    log.S3_Key__c,
                    log.File_Name__c,
                    log.Record_Id__c
                );

                toUpdate.add(new File_Recovery_Log__c(
                    Id               = log.Id,
                    File_Name__c     = log.File_Name__c,
                    S3_Key__c        = log.S3_Key__c,
                    Record_Id__c     = log.Record_Id__c,
                    Object_Name__c   = log.Object_Name__c,
                    Action_Type__c   = 'Restore',
                    Restore_Status__c = 'Completed',
                    Restore_Time__c  = DateTime.now()
                ));

            } catch (Exception e) {

                toUpdate.add(new File_Recovery_Log__c(
                    Id               = log.Id,
                    File_Name__c     = log.File_Name__c,
                    S3_Key__c        = log.S3_Key__c,
                    Record_Id__c     = log.Record_Id__c,
                    Object_Name__c   = log.Object_Name__c,
                    Action_Type__c   = 'Restore',
                    Restore_Status__c = 'Failed',
                    Restore_Time__c  = DateTime.now(),
                    Error_Message__c = e.getMessage().left(255)
                ));
            }
        }

        AWSVaultSectionQueryHelper.updateRestoreLogs(toUpdate);

        if (endIndex < this.logs.size()) {
            AWSVaultSectionQueryHelper.enqueueFileRestoreChain(
                this.logs,
                endIndex,
                this.batchSize
            );
        }
    }
}