public with sharing class S3UploaderScheduler implements Schedulable {
 
    private String  selectedObject;
    private String  mode;
    private Boolean deleteAfterMigration;
    private String  filterType;
    private String  soqlCondition;
 
    public S3UploaderScheduler(
        String  selectedObject,
        String  mode,
        Boolean deleteAfterMigration,
        String  filterType,
        String  soqlCondition
    ) {
        this.selectedObject       = selectedObject;
        this.mode                 = mode;
        this.deleteAfterMigration = deleteAfterMigration;
        this.filterType           = filterType;
        this.soqlCondition        = soqlCondition;
    }
 
    public S3UploaderScheduler(
        String  selectedObject,
        String  mode,
        Boolean deleteAfterMigration,
        String  filterType,
        String  soqlCondition,
        Boolean isHourly
    ) {
        this(selectedObject, mode, deleteAfterMigration, filterType, soqlCondition);
    }
 
    public void execute(SchedulableContext sc) {
        try {
            FileMigrationHandlersync.startS3FileMigration(
                selectedObject,
                mode,
                deleteAfterMigration,
                filterType,
                soqlCondition
            );
        } catch (AuraHandledException e) {
        } catch (Exception e) {
        }
    }
}