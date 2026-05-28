public with sharing class BackupQueueable implements Queueable {

    private static final Integer BATCH_SIZE = 10;

    private final List<String> objectNames;
    private final List<String> recordIds;
    private final Integer currentIndex;
    public String jobId;

    public BackupQueueable(String objectName, List<String> recordIds) {
    this(new List<String>{ objectName }, recordIds, 0);
}

    public BackupQueueable(List<String> objectName, List<String> recordIds) {
        this(objectName, recordIds, 0);
    }

    public BackupQueueable(List<String> objectNames, Integer currentIndex) {
        this(objectNames, null, currentIndex);
    }

    private BackupQueueable(
        List<String> objectNames,
        List<String> recordIds,
        Integer currentIndex
    ) {
        this.objectNames = objectNames;
        this.recordIds = recordIds;
        this.currentIndex = currentIndex;
        this.jobId = 'BQ-' + objectNames[0] + '-' + System.now().getTime();
    }

    public void execute(QueueableContext context) {

    if (currentIndex >= objectNames.size()) return;

    String objectName = objectNames[currentIndex].trim();
    if (String.isBlank(objectName)) { chainNext(); return; }

    List<String> idsToProcess = resolveRecordIds(objectName);

    String sharedJobName = this.jobId;

    S3BackupBatch batch = new S3BackupBatch(
        objectName,
        idsToProcess,          
        'File',
        false,
        DateTime.now(),
        sharedJobName,
        objectNames,
        currentIndex
    );
    Database.executeBatch(batch, 10);
}
    private List<String> resolveRecordIds(String objectName) {
        if (recordIds != null && !recordIds.isEmpty()) {
            return recordIds;
        }
        return AWSQuerySharingHelper.getAllRecordIdsByObjectName(objectName);
    }

    private void launchBatch(String objectName, List<String> ids) {
        S3BackupBatch batch = new S3BackupBatch(
            objectName,
            ids,
            'File',
            false,
            DateTime.now()
        );

        Database.executeBatch(batch, BATCH_SIZE);
    }

    private void chainNext() {
        Integer nextIndex = currentIndex + 1;

        if (nextIndex < objectNames.size()) {
            System.enqueueJob(
                new BackupQueueable(objectNames, nextIndex)
            );
        }
    }
}