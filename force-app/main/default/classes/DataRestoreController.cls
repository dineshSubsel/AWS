public with sharing class DataRestoreController {

      @AuraEnabled
    public static String startDataRestore(
        String selectedObjects,
        List<String> selectedRecordIds
    ) {
        if (String.isBlank(selectedObjects)) {
            throw new AuraHandledException('At least one object is required.');
        }

        List<String> objectList = parseCommaList(selectedObjects);
        List<File_Recovery_Log__c> backupLogs =
            queryEligibleDataLogs(objectList, selectedRecordIds);

        if (backupLogs.isEmpty()) {
            insertFailedLogViaSavepoint(
    selectedObjects,
    parseCommaList(selectedObjects),
    selectedRecordIds,
    'No restorable backup files found. Ensure backup completed and has an S3 key.'
);
            throw new AuraHandledException(
                'No restorable backup files found. Ensure backup completed and has an S3 key.'
            );
        }

        AWSVaultSectionQueryHelper.insertLog(
            new File_Recovery_Log__c(
                File_Name__c      = 'DataRestore-' + String.join(objectList, ',').left(100),
                Object_Name__c    = selectedObjects.left(255),
                Action_Type__c    = 'Restore',
                Restore_Status__c = 'In Progress',
                Restore_Time__c   = DateTime.now(),
                Error_Message__c  = backupLogs.size() + ' file(s) queued for restore.',
                Record_Id__c      = (selectedRecordIds != null && !selectedRecordIds.isEmpty())
                                        ? selectedRecordIds[0] : null
            )
        );

        List<File_Recovery_Log__c> restoreLogs = createRestoreLogs(backupLogs);
        AWSVaultSectionQueryHelper.enqueueRestore(backupLogs, restoreLogs);

        return 'Data restore initiated for ' + backupLogs.size()
            + ' file(s) across ' + objectList.size() + ' object(s).';
    }

@AuraEnabled
public static String startGroupRestore(
    String restoreType,
    String groupPayload,
    String schedulePayload
) {
    if (String.isBlank(restoreType)) {
        throw new AuraHandledException('Restore type is required.');
    }
    if (String.isBlank(groupPayload)) {
        throw new AuraHandledException('Payload is required.');
    }

    Map<String, Object> schedParsed = String.isBlank(schedulePayload)
        ? new Map<String, Object>()
        : (Map<String, Object>) JSON.deserializeUntyped(schedulePayload);

    String frequency  = schedParsed.containsKey('frequency')
        ? (String) schedParsed.get('frequency') : 'once';
    String restoreTime = schedParsed.containsKey('time')
        ? (String) schedParsed.get('time') : '00:00';
    String weekday = schedParsed.containsKey('weekday')
        ? (String) schedParsed.get('weekday') : 'MON';
    Integer monthDay = schedParsed.containsKey('monthDay')
        ? Integer.valueOf(String.valueOf(schedParsed.get('monthDay'))) : 1;

    Boolean isScheduled = (frequency != 'once');

    Map<String, Object> parsed =
        (Map<String, Object>) JSON.deserializeUntyped(groupPayload);

    // ── DATA RESTORE ──────────────────────────────────────────────────────
    if (restoreType == 'data') {
        List<Object> objectsRaw = (List<Object>) parsed.get('objects');
List<Object> recordsRaw = (List<Object>) parsed.get('recordIds');
String objectLabel = parsed.containsKey('objectLabel')
    ? (String) parsed.get('objectLabel')
    : null;
    System.debug('objectLabel value: ' + objectLabel);
System.debug('parsed keys: ' + parsed.keySet());

        List<String> objectList = new List<String>();
        List<String> recordIds  = new List<String>();

        if (objectsRaw != null) {
            for (Object o : objectsRaw) objectList.add(String.valueOf(o));
        }
        if (recordsRaw != null) {
            for (Object r : recordsRaw) recordIds.add(String.valueOf(r));
        }

        if (objectList.isEmpty()) {
            throw new AuraHandledException('At least one object is required.');
        }

        // ── File_Name__c helper ───────────────────────────────────────────
        String dataObjectPart = objectList.size() > 1
    ? 'Multiple Objects'
    : objectList[0];

        if (isScheduled) {
            String cronExpr = buildCronExpression(frequency, restoreTime, weekday, monthDay);
            String jobName  = 'DataRestore-Scheduled-'
                + String.join(objectList, '_').left(40)
                + '-' + System.now().formatGmt('yyyy-MM-dd_HH-mm-ss');

            AWSVaultSectionQueryHelper.scheduleJob(
                jobName,
                cronExpr,
                new DataRestoreScheduler(objectList, recordIds)
            );
            return '{"msg":"Restore scheduled successfully.","jobId":null}';
        }

        // ── Instant data restore ──────────────────────────────────────────
        List<File_Recovery_Log__c> backupLogs =
            queryEligibleDataLogs(objectList, recordIds);

        if (backupLogs.isEmpty()) {
    insertFailedLogViaSavepoint(
    dataObjectPart,
    objectList,
    recordIds,
    'No restorable backup files found. Ensure backup completed and has an S3 key.'
);
            return 'ERROR: No restorable backup files found.';
        }

      AWSVaultSectionQueryHelper.insertLog(
    new File_Recovery_Log__c(
        Name              = AWSVaultSectionQueryHelper.generateLogFileName('DAT', 'RST'),
        File_Name__c      = 'Restore-' + dataObjectPart + '-'
                            + DateTime.now().format('yyyy-MM-dd_HH-mm-ss'),
        Object_Name__c    = objectList.size() > 1
                            ? JSON.serialize(objectList)
                            : objectList[0],
        Action_Type__c    = 'Restore',
        Restore_Status__c = 'Failed',
        Restore_Time__c   = DateTime.now(),
        Error_Message__c  = backupLogs.size() + ' file(s) queued for restore.',
        Record_Id__c      = (!recordIds.isEmpty()) ? recordIds[0] : null
    )
);
        List<File_Recovery_Log__c> restoreLogs = createRestoreLogs(backupLogs);
        AWSVaultSectionQueryHelper.enqueueRestore(backupLogs, restoreLogs);

        return 'Data restore initiated for ' + backupLogs.size()
            + ' file(s) across ' + objectList.size() + ' object(s).';
    }

    // ── METADATA / CONFIG / ORGFULL RESTORE ──────────────────────────────
    String objectNameDiscriminator = restoreType + '_backup';

    if (isScheduled) {
        String cronExpr = buildCronExpression(frequency, restoreTime, weekday, monthDay);
        String jobName  = restoreType + '-Restore-Scheduled-'
            + System.now().formatGmt('yyyy-MM-dd_HH-mm-ss');

        AWSVaultSectionQueryHelper.scheduleJob(
            jobName,
            cronExpr,
            new DataRestoreScheduler(
                new List<String>{ objectNameDiscriminator },
                new List<String>()
            )
        );
        return '{"msg":"Restore scheduled successfully.","jobId":null}';
    }

    // ── Instant metadata/config/orgfull restore ───────────────────────────
    List<File_Recovery_Log__c> backupLogs =
        AWSVaultSectionQueryHelper.queryGroupRestoreLogs(objectNameDiscriminator);

    if (backupLogs.isEmpty()) {
        String componentLabel = restoreType.capitalize() + ' backup';
        String errorMessage   = 'No S3 backup files found for ' + componentLabel
            + '. Please run a ' + restoreType + ' backup first.';

       AWSVaultSectionQueryHelper.insertLog(
    new File_Recovery_Log__c(
        Name              = AWSVaultSectionQueryHelper.generateLogFileName('DAT', 'RST'),
        File_Name__c      = 'Restore-Failed-'
                            + DateTime.now().format('yyyy-MM-dd_HH-mm-ss'),
        Object_Name__c    = restoreType + '_restore',
        Action_Type__c    = 'Restore',
        Restore_Status__c = 'Failed',
        Restore_Time__c   = DateTime.now(),
        Error_Message__c  = errorMessage
    )
);
        return 'ERROR:' + errorMessage;
    }

    AWSVaultSectionQueryHelper.insertLog(
    new File_Recovery_Log__c(
        Name              = AWSVaultSectionQueryHelper.generateLogFileName('DAT', 'RST'),
        File_Name__c      = 'Restore-' + restoreType + '-'
                            + DateTime.now().format('yyyy-MM-dd_HH-mm-ss'),
        Object_Name__c    = objectNameDiscriminator,
        Action_Type__c    = 'Restore',
        Restore_Status__c = 'In Progress',
        Restore_Time__c   = DateTime.now(),
        Error_Message__c  = backupLogs.size() + ' file(s) queued for restore.'
    )
);

    List<File_Recovery_Log__c> restoreLogs = createRestoreLogs(backupLogs);
    AWSVaultSectionQueryHelper.enqueueRestore(backupLogs, restoreLogs);

    return 'Restore started for ' + backupLogs.size() + ' file(s).';
}
   @AuraEnabled
public static String startScheduledDataRestore(
    String selectedObjects,
    List<String> selectedRecordIds,
    String frequency,
    String restoreTime
) {
    if (String.isBlank(selectedObjects)) throw new AuraHandledException('Object required.');
    if (String.isBlank(frequency))       throw new AuraHandledException('Frequency required.');
    if (String.isBlank(restoreTime))     throw new AuraHandledException('Time required.');

    // No insertLog here — log created inside DataRestoreScheduler.execute()
    String cronExp = buildCronExpression(frequency, restoreTime, 'MON', 1);
    String jobName = 'DataRestore-'
        + selectedObjects.replaceAll(',', '_').left(50)
        + '-' + frequency.toUpperCase()
        + '-' + System.now().formatGmt('yyyyMMdd_HHmmss');

    AWSVaultSectionQueryHelper.scheduleJob(
        jobName,
        cronExp,
        new DataRestoreScheduler(parseCommaList(selectedObjects), selectedRecordIds)
    );

    return jobName;
}
  public static void insertFailedLogViaSavepoint(
    String objectNames,
    List<String> objectList,
    List<String> recordIds,
    String errorMsg
){
    Savepoint sp = Database.setSavepoint();
    try {
        String fileName = 'Restore-' + (String.isNotBlank(objectNames) ? objectNames : 'Failed')
            + '-' + DateTime.now().format('yyyy-MM-dd_HH-mm-ss');

       File_Recovery_Log__c failedLog = new File_Recovery_Log__c(
    Name              = AWSVaultSectionQueryHelper.generateLogFileName('DAT', 'RST'),
    File_Name__c      = fileName,
    Object_Name__c    = (objectList.size() > 1
                        ? JSON.serialize(objectList)
                        : objectList[0]).left(255),
    Action_Type__c    = 'Restore',
    Restore_Status__c = 'Failed',
    Restore_Time__c   = DateTime.now(),
    Error_Message__c  = (errorMsg != null ? errorMsg : '').left(255),
    Record_Id__c      = (recordIds != null && !recordIds.isEmpty())
                            ? recordIds[0] : null
);
        AWSVaultSectionQueryHelper.insertLog(failedLog);
    } catch (Exception e) {
        Database.rollback(sp);
    }
}

    public static List<File_Recovery_Log__c> createRestoreLogs(
        List<File_Recovery_Log__c> backupLogs
    ) {
        List<File_Recovery_Log__c> logs = new List<File_Recovery_Log__c>();
        for (File_Recovery_Log__c bl : backupLogs) {
            logs.add(new File_Recovery_Log__c(
                File_Name__c      = bl.File_Name__c,
                S3_Key__c         = bl.S3_Key__c,
                Record_Id__c      = bl.Record_Id__c,
                Object_Name__c    = bl.Object_Name__c,
                Action_Type__c    = 'Restore',
                Restore_Status__c = 'In Progress',
                Restore_Time__c   = DateTime.now()
            ));
        }
        AWSVaultSectionQueryHelper.insertLogs(logs);
        return logs;
    }

    private static List<File_Recovery_Log__c> queryEligibleDataLogs(
    List<String> objectList,
    List<String> recordIds
){
    return AWSVaultSectionQueryHelper.queryEligibleDataLogs(objectList, recordIds);
}

    private static List<String> parseCommaList(String input) {
        List<String> result = new List<String>();
        if (String.isBlank(input)) return result;
        for (String s : input.split(',')) {
            String t = s.trim();
            if (!String.isBlank(t)) result.add(t);
        }
        return result;
    }

    private static String buildCronExpression(
    String frequency,
    String timeStr,
    String weekday,
    Integer monthDay
) {
    String cleanTime = timeStr.split(':')[0] + ':' + timeStr.split(':')[1];
    
    List<String> parts = cleanTime.split(':');
    Integer hour   = Integer.valueOf(parts[0]);
    Integer minute = Integer.valueOf(parts[1]);

    String base = '0 ' + minute + ' ' + hour + ' ';

    switch on frequency.toLowerCase() {
        when 'daily'   { return base + '* * ? *'; }
        when 'weekly'  { return base + '? * ' + weekday + ' *'; }
        when 'monthly' { return base + monthDay + ' * ? *'; }
        when else      {
            throw new AuraHandledException('Invalid frequency: ' + frequency);
        }
    }
}
}