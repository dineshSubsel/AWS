public with sharing class FileMigrationHandlersync {

    private static final Set<String> BACKUP_CLASS_NAMES = new Set<String>{
        'S3UploaderBatch'
    };

    private static final Set<String> ACTIVE_STATUSES = new Set<String>{
        'Queued', 'Processing', 'Preparing', 'Holding'
    };

    private static final Set<String> SOQL_DML_KEYWORDS = new Set<String>{
        'delete', 'insert', 'update', 'merge'
    };

    private static final Map<String, String> DAY_TO_CRON = new Map<String, String>{
        'Sunday'    => 'SUN', 'Monday'  => 'MON', 'Tuesday' => 'TUE',
        'Wednesday' => 'WED', 'Thursday'=> 'THU', 'Friday'  => 'FRI',
        'Saturday'  => 'SAT'
    };

    @AuraEnabled
    public static List<String> startS3FileMigration(
        String  selectedObject,
        String  mode,
        Boolean deleteAfterMigration,
        String  filterType,
        String  soqlCondition
    ) {
        validateObjectAndMode(selectedObject, mode);
        validateSoqlCondition(filterType, soqlCondition);

        S3UploaderBatch.isAborted = false;
        S3UploaderBatch.abortedJobIds.clear();

        String query = buildQuery(selectedObject, filterType, soqlCondition);

        List<SObject> records;
        try {
            records = AWSQuerySharingHelper.getRecordsByQuery(query);
        } catch (Exception e) {
            throw new AuraHandledException('Invalid query: ' + e.getMessage());
        }

        if (records == null || records.isEmpty()) {
            throw new AuraHandledException('No records found.');
        }

        return AWSQuerySharingHelper.executeBatchPerRecord(
            records, selectedObject, mode, deleteAfterMigration
        );
    }

    @AuraEnabled
    public static void scheduleS3FileMigration(
        String  selectedObject,
        String  mode,
        Boolean deleteAfterMigration,
        String  filterType,
        String  soqlCondition,
        String  frequency,
        String  scheduledTime,
        String  daysOfWeek,
        String  monthlyType,
        String  dayOfMonth,
        String  weekOfMonth,
        String  monthlyDayOfWeek
    ) {
        validateObjectAndMode(selectedObject, mode);

        Integer hour   = parseTimePart(scheduledTime, 0, 'hour');
        Integer minute = parseTimePart(scheduledTime, 1, 'minute');

        String cronExpression = buildCronExpression(
            frequency, hour, minute,
            daysOfWeek, monthlyType, dayOfMonth, weekOfMonth, monthlyDayOfWeek
        );

        String jobName = 'S3 Migration - ' + selectedObject + ' - '
            + System.now().format();
        AWSQuerySharingHelper.scheduleS3MigrationJob(
            jobName, cronExpression, selectedObject, mode,
            deleteAfterMigration, filterType, soqlCondition
        );
    }

    @AuraEnabled
    public static List<Map<String, String>> getBackupJobStatus(List<String> jobIds) {
        Set<Id> idSet = toIdSet(jobIds);
        List<AsyncApexJob> jobs = idSet.isEmpty()
            ? AWSQuerySharingHelper.getJobStatusByClassName(BACKUP_CLASS_NAMES)
            : AWSQuerySharingHelper.getJobStatusByIds(idSet);

        List<Map<String, String>> rows = new List<Map<String, String>>();
        for (AsyncApexJob job : jobs) {
            rows.add(toStatusRow(job));
        }
        return rows;
    }

    @AuraEnabled
    public static Boolean areAllJobsDone(List<String> jobIds) {
        Set<Id> idSet = toIdSet(jobIds);
        Integer countActive = idSet.isEmpty()
            ? AWSQuerySharingHelper.countActiveJobsByClassName(BACKUP_CLASS_NAMES, ACTIVE_STATUSES)
            : AWSQuerySharingHelper.countActiveJobsByIds(idSet, ACTIVE_STATUSES);

        return countActive == 0;
    }

    @AuraEnabled
    public static void abortS3FileMigration(List<String> jobIds) {
        if (jobIds == null || jobIds.isEmpty()) {
            throw new AuraHandledException('No job IDs provided.');
        }

        S3UploaderBatch.isAborted = true;
        AWSQuerySharingHelper.abortJobsAndTrack(jobIds);
    }

    @AuraEnabled
    public static void abortJob(String jobId) {
        if (String.isBlank(jobId)) {
            throw new AuraHandledException('Invalid Job Id.');
        }
        try {
            AWSQuerySharingHelper.abortJobById(jobId);
        } catch (Exception e) {
            throw new AuraHandledException('Unable to abort job: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAllSObjects() {
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        List<Map<String, String>> sobjectList = new List<Map<String, String>>();
        for (String objName : globalDescribe.keySet()) {
            Schema.DescribeSObjectResult dr = globalDescribe.get(objName).getDescribe();
            if (!dr.isQueryable() || dr.isCustomSetting()) continue;

            String label = dr.getLabel();
            if (String.isBlank(label) || label.startsWith('__MISSING LABEL__')) continue;

            sobjectList.add(new Map<String, String>{
                'label' => label,
                'value' => objName
            });
        }
        sobjectList.sort(new MapLabelComparator());
        return sobjectList;
    }
    private static void validateObjectAndMode(String selectedObject, String mode) {
        if (String.isBlank(selectedObject) || String.isBlank(mode)) {
            throw new AuraHandledException('Selected object and mode are required.');
        }
    }

    private static void validateSoqlCondition(String filterType, String soqlCondition) {
        if (filterType != 'SOQL Filter') return;

        if (String.isBlank(soqlCondition)) {
            throw new AuraHandledException('Provide a valid SOQL condition.');
        }

        String lc = soqlCondition.toLowerCase();
        for (String keyword : SOQL_DML_KEYWORDS) {
            if (lc.contains(keyword)) {
                throw new AuraHandledException('DML operations are not allowed in SOQL filter.');
            }
        }
    }

 private static String buildQuery(
    String selectedObject,
    String filterType,
    String soqlCondition
) {
    return AWSQuerySharingHelper.buildQuery(selectedObject, filterType, soqlCondition);
}
    private static Integer parseTimePart(String timeStr, Integer index, String label) {
        if (String.isBlank(timeStr) || !timeStr.contains(':')) {
            throw new AuraHandledException('Invalid time format (HH:MM).');
        }
        try {
            return Integer.valueOf(timeStr.split(':')[index]);
        } catch (Exception e) {
            throw new AuraHandledException('Invalid ' + label + ' value.');
        }
    }

    private static String buildCronExpression(
        String  frequency,
        Integer hour,
        Integer minute,
        String  daysOfWeek,
        String  monthlyType,
        String  dayOfMonth,
        String  weekOfMonth,
        String  monthlyDayOfWeek
    ) {
        String base = '0 ' + minute + ' ' + hour + ' ';

        switch on frequency {
            when 'Once' {
                return base + '? * *';
            }
            when 'Daily' {
                return base + '* * ?';
            }
            when 'Weekly' {
                if (String.isBlank(daysOfWeek)) {
                    throw new AuraHandledException('Days of week are required for weekly schedule.');
                }
                return base + '? * ' + convertDaysToCron(daysOfWeek);
            }
            when 'Monthly' {
                if (monthlyType == 'day') {
                    if (String.isBlank(dayOfMonth)) {
                        throw new AuraHandledException('Day of month is required.');
                    }
                    return base + dayOfMonth.trim() + ' * ?';
                }
                String day = dayNameToCronAbbrev(monthlyDayOfWeek);
                return weekOfMonth == 'last'
                    ? base + '? * ' + day + 'L'
                    : base + '? * ' + day + '#' + weekOfMonth;
            }
            when else {
                throw new AuraHandledException('Unsupported frequency: ' + frequency);
            }
        }
    }

    private static String convertDaysToCron(String days) {
        List<String> result = new List<String>();
        for (String d : days.split(',')) {
            result.add(dayNameToCronAbbrev(d.trim()));
        }
        return String.join(result, ',');
    }

    private static String dayNameToCronAbbrev(String day) {
        if (!DAY_TO_CRON.containsKey(day)) {
            throw new AuraHandledException('Invalid day: ' + day);
        }
        return DAY_TO_CRON.get(day);
    }


    private static Set<Id> toIdSet(List<String> jobIds) {
        Set<Id> ids = new Set<Id>();
        if (jobIds == null) return ids;
        for (String s : jobIds) {
            try {
                ids.add((Id) s);
            } catch (Exception e) {
            }
        }
        return ids;
    }

    private static Map<String, String> toStatusRow(AsyncApexJob job) {
        return new Map<String, String>{
            'jobId'     => job.Id,
            'status'    => job.Status,
            'className' => job.ApexClass.Name,
            'userName'  => job.CreatedBy.Name,
            'startTime' => job.CreatedDate.format('yyyy-MM-dd HH:mm:ss'),
            'progress'  => job.TotalJobItems > 0
                ? job.JobItemsProcessed + '/' + job.TotalJobItems
                : '—'
        };
    }

    public class MapLabelComparator implements Comparator<Map<String, String>> {
        public Integer compare(Map<String, String> a, Map<String, String> b) {
            return a.get('label').toLowerCase()
                .compareTo(b.get('label').toLowerCase());
        }
    }

    @AuraEnabled
public static List<Map<String, Object>> previewSOQLRecords(
    String selectedObject,
    String soqlCondition
) {
    if (String.isBlank(selectedObject)) {
        throw new AuraHandledException('Object is required.');
    }

    validateSoqlCondition('SOQL Filter', soqlCondition);

    String query = 'SELECT Id, Name FROM ' + selectedObject;

    if (String.isNotBlank(soqlCondition) && soqlCondition.trim() != '') {
        query += ' WHERE ' + soqlCondition.trim();
    }

    if (!query.toLowerCase().contains(' limit ')) {
        query += ' LIMIT 10';
    }

    List<SObject> records;
    try {
        records = Database.query(query);
    } catch (Exception e) {
        throw new AuraHandledException('Invalid SOQL: ' + e.getMessage());
    }

    List<Map<String, Object>> result = new List<Map<String, Object>>();
    if (records == null || records.isEmpty()) return result;

    for (SObject rec : records) {
        result.add(new Map<String, Object>{
            'Id'   => rec.Id,
            'Name' => rec.get('Name')
        });
    }
    return result;
}
}