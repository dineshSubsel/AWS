public with sharing class FileMigrationHandler {

    private static final Set<String> EXCLUDED_OBJECT_KEYWORDS = new Set<String>{
        'history', 'share', 'feed', 'tag', 'event', 'changeevent',
        'approval', 'async', 'duplicate', 'collaboration',
        'content', 'datamask', 'permission', 'setup'
    };

    private static final Set<String> SOQL_DML_KEYWORDS = new Set<String>{
        'delete', 'insert', 'update', 'merge'
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

        List<SObject> records;
        try {
            records = AWSQuerySharingHelper.getRecordsByObjectAndFilter(
                selectedObject, filterType, soqlCondition
            );
        } catch (Exception e) {
            throw new AuraHandledException('Invalid query: ' + e.getMessage());
        }

        if (records == null || records.isEmpty()) {
            throw new AuraHandledException('No records found with given filter.');
        }
        return AWSQuerySharingHelper.executeBatchForRecords(
            records, selectedObject, mode, deleteAfterMigration
        );
    }

    @AuraEnabled
    public static void abortS3FileMigration(List<String> jobIds) {
        if (jobIds == null || jobIds.isEmpty()) {
            throw new AuraHandledException('No job IDs provided to abort.');
        }
        S3UploaderBatch.isAborted = true;
        AWSQuerySharingHelper.abortJobs(jobIds);
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
        String  dayOfMonth,
        Boolean isHourly
    ) {
        validateObjectAndMode(selectedObject, mode);

        String cronExpression = buildCronExpression(
            frequency, scheduledTime, daysOfWeek, dayOfMonth
        );
        AWSQuerySharingHelper.scheduleS3Migration(
            cronExpression, selectedObject, mode,
            deleteAfterMigration, filterType, soqlCondition, isHourly
        );
    }
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAllSObjects() {
        Map<String, Schema.SObjectType> globalMap = Schema.getGlobalDescribe();

        List<String> filteredNames = new List<String>();
        for (String objName : globalMap.keySet()) {
            if (isExcludedObject(objName, globalMap)) continue;
            filteredNames.add(objName);
        }
        filteredNames.sort();

        List<Map<String, String>> options = new List<Map<String, String>>();
        for (String name : filteredNames) {
            options.add(new Map<String, String>{
                'label' => globalMap.get(name).getDescribe().getLabel(),
                'value' => name
            });
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getObjectManagerObjects() {
        List<EntityDefinition> entityList = AWSQuerySharingHelper.getEntityDefinitions();
        Map<String, String> objectsMap = new Map<String, String>();
        for (EntityDefinition ed : entityList) {
            objectsMap.put(ed.QualifiedApiName, ed.Label);
        }
        try {
           String soql = AWSQuerySharingHelper.getEntityDefinitionToolingQuery();

            String responseBody = toolingQuery(soql);
            Map<String, Object> responseMap =
                (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            List<Object> records = (List<Object>) responseMap.get('records');

            processToolingRecords(records, objectsMap);

        } catch (Exception e) {
        }

        List<String> sortedKeys = new List<String>(objectsMap.keySet());
        sortedKeys.sort();

        List<Map<String, String>> objectsList = new List<Map<String, String>>();
        for (String key : sortedKeys) {
            objectsList.add(new Map<String, String>{
                'label' => objectsMap.get(key),
                'value' => key
            });
        }

        return new Map<String, Object>{
            'count'   => objectsList.size(),
            'objects' => objectsList
        };
    }

    private static void validateObjectAndMode(String selectedObject, String mode) {
        if (String.isBlank(selectedObject) || String.isBlank(mode)) {
            throw new AuraHandledException('Selected object and mode are required.');
        }
    }
 @TestVisible
    private static void validateSoqlCondition(String filterType, String soqlCondition) {
        if (filterType != 'SOQL Filter') return;

        if (String.isBlank(soqlCondition)) {
            throw new AuraHandledException('Please provide a valid SOQL filter condition.');
        }

        String lowerCondition = soqlCondition.toLowerCase();
        for (String keyword : SOQL_DML_KEYWORDS) {
            if (lowerCondition.contains(keyword)) {
                throw new AuraHandledException(
                    'Invalid SOQL filter condition. DML operations are not allowed.'
                );
            }
        }
    }
 @TestVisible
    private static String buildCronExpression(
        String frequency,
        String scheduledTime,
        String daysOfWeek,
        String dayOfMonth
    ) {
        if (String.isBlank(scheduledTime)) {
            throw new AuraHandledException('Scheduled time is required.');
        }

        List<String> timeParts = scheduledTime.split(':');
        if (timeParts.size() != 2) {
            throw new AuraHandledException('Invalid time format. Use HH:MM.');
        }

        Integer hour;
        Integer minute;
        try {
            hour   = Integer.valueOf(timeParts[0]);
            minute = Integer.valueOf(timeParts[1]);
        } catch (Exception e) {
            throw new AuraHandledException('Invalid time values.');
        }

        String cron;
        switch on frequency {
            when 'Once' {
                cron = '0 ' + minute + ' ' + hour + ' ? * *';
            }
            when 'Daily' {
                cron = '0 ' + minute + ' ' + hour + ' * * ?';
            }
            when 'Weekly' {
                if (String.isBlank(daysOfWeek)) {
                    throw new AuraHandledException('Days of week are required for weekly schedule.');
                }
                String firstDay = daysOfWeek.contains(',')
                    ? daysOfWeek.split(',')[0].trim()
                    : daysOfWeek.trim();
                cron = '0 ' + minute + ' ' + hour + ' ? * ' + firstDay;
            }
            when 'Monthly' {
                if (String.isBlank(dayOfMonth)) {
                    throw new AuraHandledException('Day of month is required for monthly schedule.');
                }
                cron = '0 ' + minute + ' ' + hour + ' ' + dayOfMonth.trim() + ' * ?';
            }
            when else {
                throw new AuraHandledException('Invalid frequency: ' + frequency);
            }
        }
        return cron;
    }
 @TestVisible
    private static Boolean isExcludedObject(
        String objName,
        Map<String, Schema.SObjectType> globalMap
    ) {
        String lower = objName.toLowerCase();
        for (String keyword : EXCLUDED_OBJECT_KEYWORDS) {
            if (lower.contains(keyword)) return true;
        }

        Schema.DescribeSObjectResult d = globalMap.get(objName).getDescribe();
        return (
            d.isCustom()         ||
            !d.isQueryable()     ||
            !d.isCreateable()    ||
            !d.isUpdateable()    ||
            !d.isDeletable()     ||
            !d.isAccessible()    ||
            d.getKeyPrefix() == null
        );
    }
    private static String toolingQuery(String encodedSoql) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(
            'callout:Salesforce_Tooling/services/data/v60.0/tooling/query/?q=' + encodedSoql
        );
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(30000);
        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new CalloutException(
                'Tooling API returned HTTP ' + res.getStatusCode() + ': ' + res.getBody()
            );
        }
        return res.getBody();
    }
    @TestVisible
    private static void processToolingRecords(
        List<Object> records,
        Map<String, String> objectsMap
    ) {
        if (records == null) return;

        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();

        for (Object rec : records) {
            Map<String, Object> record = (Map<String, Object>) rec;

            String  apiName        = (String)  record.get('QualifiedApiName');
            String  label          = (String)  record.get('Label');
            Boolean isCustomSetting = (Boolean) record.get('IsCustomSetting');
            Boolean isDeprecated   = (Boolean) record.get('IsDeprecatedAndHidden');
            Boolean isCustomizable = (Boolean) record.get('IsCustomizable');

            if (apiName == null || label == null) continue;
            if (isCustomSetting == true)          continue;
            if (isDeprecated    == true)          continue;
            if (objectsMap.containsKey(apiName))  continue;

            Schema.SObjectType objType = globalDescribe.get(apiName);
            if (objType == null) continue;

            Schema.DescribeSObjectResult dr = objType.getDescribe();
            if (dr.isQueryable() && dr.isAccessible() &&
                (dr.isCreateable() || dr.isUpdateable() || isCustomizable == true)
            ) {
                objectsMap.put(apiName, label);
            }
        }
    }

    @TestVisible
    private static void processRecords(
        List<Object> records,
        Map<String, String> objectsMap
    ) {
        if (records == null) return;
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        for (Object rec : records) {
            Map<String, Object> record = (Map<String, Object>) rec;
            String  apiName        = (String)  record.get('QualifiedApiName');
            String  label          = (String)  record.get('Label');
            Boolean isCustomSetting = (Boolean) record.get('IsCustomSetting');
            Boolean isDeprecated   = (Boolean) record.get('IsDeprecatedAndHidden');
            Boolean isCustomizable = (Boolean) record.get('IsCustomizable');

            if (apiName == null || label == null) continue;
            if (isCustomSetting == true)          continue;
            if (isDeprecated    == true)          continue;
            if (objectsMap.containsKey(apiName))  continue;

            Schema.SObjectType objType = globalDescribe.get(apiName);
            if (objType == null) continue;

            Schema.DescribeSObjectResult dr = objType.getDescribe();
            if (dr.isQueryable() && dr.isAccessible() &&
                (dr.isCreateable() || dr.isUpdateable() || isCustomizable == true)
            ) {
                objectsMap.put(apiName, label);
            }
        }
    }
    public class MapLabelComparator implements Comparator<Map<String, String>> {
        public Integer compare(Map<String, String> a, Map<String, String> b) {
            return a.get('label').toLowerCase().compareTo(b.get('label').toLowerCase());
        }
    }
}