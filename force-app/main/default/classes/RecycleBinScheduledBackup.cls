public with sharing class RecycleBinScheduledBackup implements Schedulable {

    private List<String> objectTypes;
    private List<String> recordIds;
        private String       objectNamesLabel;  


    public RecycleBinScheduledBackup(List<String> objectTypes, List<String> recordIds) {
        this.objectTypes = objectTypes;
        this.recordIds   = (recordIds != null && !recordIds.isEmpty()) ? recordIds : null;
                this.objectNamesLabel = String.join(objectTypes, ', ');  // fallback to API names

    }

    public RecycleBinScheduledBackup(List<String> objectTypes, List<String> recordIds, String objectNamesLabel) {
        this.objectTypes      = objectTypes;
        this.recordIds        = (recordIds != null && !recordIds.isEmpty()) ? recordIds : null;
        this.objectNamesLabel = objectNamesLabel;
    }

    public void execute(SchedulableContext sc) {
        if (objectTypes == null || objectTypes.isEmpty()) return;

        if (objectTypes.size() == 1) {
            RecycleBinBackupBatch batch = (recordIds != null && !recordIds.isEmpty())
                ? new RecycleBinBackupBatch(objectTypes[0], recordIds, objectNamesLabel)  
                : new RecycleBinBackupBatch(objectTypes[0], objectNamesLabel);             

            Database.executeBatch(batch, 200);
        } else {
            RecycleBinMultiObjectBackupBatch batch = (recordIds != null && !recordIds.isEmpty())
                ? new RecycleBinMultiObjectBackupBatch(objectTypes, recordIds, objectNamesLabel)  
                : new RecycleBinMultiObjectBackupBatch(objectTypes, objectNamesLabel);             

            Database.executeBatch(batch, 200);
        }
    }
}