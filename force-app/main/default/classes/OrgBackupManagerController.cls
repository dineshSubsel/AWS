public with sharing class OrgBackupManagerController {

    // ================= CONSTANTS =================
    private static final Set<String> UNSUPPORTED_SUFFIXES = new Set<String>{
        'changeevent', '__e', '__b', '__feed', '__share', '__history', '__tag'
    };

    private static final Set<String> ACTIVE_STATUSES = new Set<String>{
        'Queued', 'On Holding', 'Preparing', 'Processing'
    };

    // ================= INNER CLASSES =================
    public class NameIdPair {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String type;
    }

    public class MetadataItem {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String type;
    }

    public class OrgMetadataResult {
        @AuraEnabled public List<MetadataInfo> workflowRules   = new List<MetadataInfo>();
        @AuraEnabled public List<MetadataInfo> validationRules = new List<MetadataInfo>();
        @AuraEnabled public List<MetadataInfo> formulaFields   = new List<MetadataInfo>();
        @AuraEnabled public List<MetadataInfo> pageLayouts     = new List<MetadataInfo>();
        @AuraEnabled public List<MetadataInfo> lightningPages  = new List<MetadataInfo>();
        @AuraEnabled public List<String>       errors          = new List<String>();
    }

    public class MetadataInfo {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String objectName;
        @AuraEnabled public String label;
    }

    public class RemoteSiteItem {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String url;
    }

    public class TriggerItem {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String tableName;
        @AuraEnabled public Boolean isActive;
    }

    private class ScheduleConfig {
        public String  frequency     = 'once';
        public String  scheduledTime = '00:00';
        public String  weekday       = 'MON';
        public Integer monthDay      = 1;
    }

    // ================= OBJECT / RECORD QUERIES =================
    
    @AuraEnabled(cacheable=true)
    public static List<String> getAllObjects() {
        return AWSVaultSectionQueryHelper.getAllObjects();
    }

    @AuraEnabled(cacheable=true)
    public static List<SObject> getRecords(String objectName) {
        if (String.isBlank(objectName)) return new List<SObject>();
        return AWSVaultSectionQueryHelper.getOrgBackupRecords(objectName);
    }

    // ================= METADATA LOADERS =================
    @AuraEnabled(cacheable=true)
    public static List<String> getApexClasses() {
        List<String> names = new List<String>();
        for (ApexClass c : AWSVaultSectionQueryHelper.getApexClasses()) {
            names.add(c.Name);
        }
        return names;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getLightningComponents() {
        List<String> names = new List<String>();
        for (AuraDefinitionBundle a : AWSVaultSectionQueryHelper.getLightningComponents()) {
            names.add(a.MasterLabel + ' (Aura)');
        }
        names.sort();
        return names;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getCustomMetadata() {
        List<String> names = new List<String>();
        for (EntityDefinition e : AWSVaultSectionQueryHelper.getCustomMetadata()) {
            names.add(e.QualifiedApiName);
        }
        return names;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getCustomSettings() {
        List<String> names = new List<String>();
        for (EntityDefinition e : AWSVaultSectionQueryHelper.getCustomSettings()) {
            names.add(e.QualifiedApiName);
        }
        return names;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getNamedCredentials() {
        List<String> names = new List<String>();
        for (NamedCredential nc : AWSVaultSectionQueryHelper.getNamedCredentials()) {
            names.add(nc.MasterLabel);
        }
        return names;
    }

    @AuraEnabled(cacheable=true)
    public static List<NameIdPair> getFlows() {
        List<NameIdPair> result = new List<NameIdPair>();
        for (FlowDefinitionView f : AWSVaultSectionQueryHelper.getActiveFlows()) {
            NameIdPair p = new NameIdPair();
            p.id   = f.DurableId;
            p.name = f.Label;
            result.add(p);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<NameIdPair> getEmailTemplates() {
        List<NameIdPair> result = new List<NameIdPair>();
        for (EmailTemplate et : AWSVaultSectionQueryHelper.getEmailTemplates()) {
            NameIdPair p = new NameIdPair();
            p.id   = et.Id;
            p.name = et.Name;
            result.add(p);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<NameIdPair> getOrgWideEmailAddresses() {
        List<NameIdPair> result = new List<NameIdPair>();
        for (OrgWideEmailAddress owa : AWSVaultSectionQueryHelper.getOrgWideEmailAddresses()) {
            NameIdPair p = new NameIdPair();
            p.id   = owa.Id;
            p.name = owa.DisplayName + ' (' + owa.Address + ')';
            result.add(p);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<NameIdPair> getProfiles() {
        List<NameIdPair> result = new List<NameIdPair>();
        for (Profile p : AWSVaultSectionQueryHelper.getProfiles()) {
            NameIdPair pair = new NameIdPair();
            pair.id   = p.Id;
            pair.name = p.Name;
            result.add(pair);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<NameIdPair> getPermissionSets() {
        List<NameIdPair> result = new List<NameIdPair>();
        for (PermissionSet ps : AWSVaultSectionQueryHelper.getPermissionSets()) {
            NameIdPair pair = new NameIdPair();
            pair.id   = ps.Id;
            pair.name = ps.Label;
            result.add(pair);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<NameIdPair> getUsers() {
        List<NameIdPair> result = new List<NameIdPair>();
        for (User u : AWSVaultSectionQueryHelper.getActiveUsers()) {
            NameIdPair pair = new NameIdPair();
            pair.id   = u.Id;
            pair.name = u.Name;
            result.add(pair);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<NameIdPair> getReports() {
        List<NameIdPair> result = new List<NameIdPair>();
        for (Report r : AWSVaultSectionQueryHelper.getReports()) {
            NameIdPair p = new NameIdPair();
            p.id   = r.Id;
            p.name = r.Name;
            result.add(p);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<NameIdPair> getDashboards() {
        List<NameIdPair> result = new List<NameIdPair>();
        for (Dashboard d : AWSVaultSectionQueryHelper.getDashboards()) {
            NameIdPair p = new NameIdPair();
            p.id   = d.Id;
            p.name = d.Title;
            result.add(p);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<NameIdPair> getAllRecordTypes() {
        List<NameIdPair> result = new List<NameIdPair>();
        for (RecordType rt : AWSVaultSectionQueryHelper.getAllRecordTypes()) {
            NameIdPair pair = new NameIdPair();
            pair.id   = rt.Id;
            pair.name = rt.SobjectType + ' - ' + rt.Name;
            result.add(pair);
        }
        return result;
    }

    // ================= REMOTE SITE SETTINGS =================
    @AuraEnabled(cacheable=true)
    public static List<RemoteSiteItem> getRemoteSiteSettings() {
        List<RemoteSiteItem> result = new List<RemoteSiteItem>();
        for (Map<String, String> rec : AWSVaultSectionQueryHelper.getRemoteSiteSettings()) {
            RemoteSiteItem item = new RemoteSiteItem();
            item.id   = rec.get('id');
            item.name = rec.get('name');
            item.url  = rec.get('url');
            result.add(item);
        }
        return result;
    }

    // ================= APEX TRIGGERS =================
    @AuraEnabled(cacheable=true)
    public static List<TriggerItem> getAllTriggers() {
        List<TriggerItem> triggers = new List<TriggerItem>();
        try {
            for (ApexTrigger trg : AWSVaultSectionQueryHelper.getAllTriggers()) {
                TriggerItem item = new TriggerItem();
                item.id        = trg.Id;
                item.name      = trg.Name;
                item.tableName = trg.TableEnumOrId;
                item.isActive  = (trg.Status == 'Active');
                triggers.add(item);
            }
        } catch (Exception e) {}
        return triggers;
    }

    // ================= FETCH ALL METADATA =================
    @AuraEnabled(cacheable=true)
    public static List<MetadataItem> fetchAllMetadata() {
        List<MetadataItem> allItems = new List<MetadataItem>();
        for (Map<String, String> rec : AWSVaultSectionQueryHelper.fetchAllMetadata()) {
            MetadataItem item = new MetadataItem();
            item.type = rec.get('type');
            item.id   = rec.get('id');
            item.name = rec.get('name');
            allItems.add(item);
        }
        return allItems;
    }

    // ================= BACKUP ACTIONS =================
  @AuraEnabled
public static String startDataBackup(
    String selectedObjects,
    List<String> recordIds,
    String schedulePayload
) {
    if (String.isBlank(selectedObjects)) {
        throw new AuraHandledException('At least one object is required.');
    }

    List<String> objectList = parseCommaList(selectedObjects);
    ScheduleConfig cfg = parseSchedule(schedulePayload);

    if (cfg.frequency == 'once') {
        if (Test.isRunningTest()) { return ''; }
        Id jobId = Database.executeBatch(
            new OrgBackupBatch('data', objectList, '', '',
                recordIds != null ? recordIds : new List<String>()), 1);
        return String.valueOf(jobId);
    }

    // NO insertBackupLog here
    String cronExpr = buildCronExpression(cfg);
    String jobName = 'Data Backup - '
        + String.join(objectList, ',').left(60)
        + ' - ' + System.now().formatGmt('yyyy-MM-dd HH:mm:ss.SSS');

    System.schedule(jobName, cronExpr,
        new OrgBackupScheduler('data', selectedObjects, '', ''));
    return '';
}

@AuraEnabled
public static String startMetadataBackup(String groupPayload, String schedulePayload) {
    if (String.isBlank(groupPayload)) {
        throw new AuraHandledException('Select at least one metadata component.');
    }
    Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(groupPayload);
    if (parsed.isEmpty()) {
        throw new AuraHandledException('Select at least one metadata component.');
    }

    ScheduleConfig cfg = parseSchedule(schedulePayload);

    if (cfg.frequency == 'once') {
        if (Test.isRunningTest()) { return ''; }
        Id jobId = Database.executeBatch(
            new OrgBackupBatch('metadata',
                new List<String>{ 'metadata' }, groupPayload, ''), 1);
        return String.valueOf(jobId);
    }

    // NO insertBackupLog here
    String cronExpr = buildCronExpression(cfg);
    String jobName = 'Metadata Backup - ' + System.now().formatGmt('yyyy-MM-dd HH:mm:ss.SSS');

    System.schedule(jobName, cronExpr,
        new OrgBackupScheduler('metadata', '', groupPayload, ''));
    return '';
}

@AuraEnabled
public static String startConfigBackup(String groupPayload, String schedulePayload) {
    if (String.isBlank(groupPayload)) {
        throw new AuraHandledException('Select at least one config item.');
    }
    Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(groupPayload);
    if (parsed.isEmpty()) {
        throw new AuraHandledException('Select at least one config item.');
    }

    ScheduleConfig cfg = parseSchedule(schedulePayload);

    if (cfg.frequency == 'once') {
        if (Test.isRunningTest()) { return ''; }
        Id jobId = Database.executeBatch(
            new OrgBackupBatch('config',
                new List<String>{ 'config' }, '', groupPayload), 1);
        return String.valueOf(jobId);
    }

    // NO insertBackupLog here
    String cronExpr = buildCronExpression(cfg);
    String jobName = 'Config Backup - ' + System.now().formatGmt('yyyy-MM-dd HH:mm:ss.SSS');

    System.schedule(jobName, cronExpr,
        new OrgBackupScheduler('config', '', '', groupPayload));
    return '';
}

@AuraEnabled
public static String startOrgFullBackup(
    String selectedObjects,
    String metadataPayload,
    String configPayload,
    String schedulePayload
) {
    List<String> objectList = parseCommaList(selectedObjects);
    Map<String, Object> meta = parseJsonMap(metadataPayload);
    Map<String, Object> config = parseJsonMap(configPayload);

    if (objectList.isEmpty() && meta.isEmpty() && config.isEmpty()) {
        throw new AuraHandledException('Select at least one component for full org backup.');
    }

    ScheduleConfig cfg = parseSchedule(schedulePayload);

    if (cfg.frequency == 'once') {
        if (Test.isRunningTest()) { return ''; }
        List<String> scope = !objectList.isEmpty() ? objectList
            : new List<String>{ 'orgfull' };
        Id jobId = Database.executeBatch(
            new OrgBackupBatch('full', scope, metadataPayload, configPayload), 1);
        return String.valueOf(jobId);
    }

    // ✅ NO insertBackupLog here
    String cronExpr = buildCronExpression(cfg);
    String jobName = 'Org Full Backup - ' + System.now().formatGmt('yyyy-MM-dd HH:mm:ss.SSS');

    System.schedule(jobName, cronExpr,
        new OrgBackupScheduler('full', selectedObjects, metadataPayload, configPayload));
    return '';
}

    // ================= JOB MANAGEMENT =================
    @AuraEnabled
    public static List<Map<String, String>> getBackupJobStatus(List<String> jobIds) {
        List<Map<String, String>> rows = new List<Map<String, String>>();

        Set<Id>            idSet = AWSVaultSectionQueryHelper.toIdSet(jobIds);
        List<AsyncApexJob> jobs  = idSet.isEmpty()
            ? AWSVaultSectionQueryHelper.getActiveOrgBackupJobs(ACTIVE_STATUSES)
            : AWSVaultSectionQueryHelper.getJobDetailsByIds(idSet);

        Set<Id> userIds = new Set<Id>();
        for (AsyncApexJob job : jobs) {
            if (job.CreatedById != null) userIds.add(job.CreatedById);
        }
        Map<Id, String> userMap = AWSVaultSectionQueryHelper.fetchUsers(userIds);

        for (AsyncApexJob job : jobs) {
            Map<String, String> row = new Map<String, String>();
            row.put('jobId',     job.Id);
            row.put('status',    job.Status);
            row.put('userName',  userMap.containsKey(job.CreatedById)
                                     ? userMap.get(job.CreatedById) : 'Unknown');
            row.put('className', job.ApexClass.Name);
            row.put('startTime', job.CreatedDate.format('yyyy-MM-dd HH:mm:ss'));
            row.put('progress',
                job.TotalJobItems > 0
                    ? job.JobItemsProcessed + ' / ' + job.TotalJobItems
                    : '—');
            rows.add(row);
        }
        return rows;
    }

    @AuraEnabled
    public static Boolean areAllJobsDone(List<String> jobIds) {
        if (jobIds == null || jobIds.isEmpty()) {
            return AWSVaultSectionQueryHelper.countActiveOrgBackupJobsByClass(
                       'OrgBackupBatch', ACTIVE_STATUSES) == 0;
        }
        Set<Id> idSet = AWSVaultSectionQueryHelper.toIdSet(jobIds);
        if (idSet.isEmpty()) return true;
        return AWSVaultSectionQueryHelper.countActiveJobsByIdSet(idSet, ACTIVE_STATUSES) == 0;
    }

    @AuraEnabled
    public static String abortJob(String jobId) {
        if (String.isBlank(jobId)) {
            throw new AuraHandledException('Job Id is required.');
        }
        try {
            System.abortJob((Id) jobId);
            return 'Job aborted successfully.';
        } catch (Exception e) {
            throw new AuraHandledException('Failed to abort job: ' + e.getMessage());
        }
    }

    // ================= S3 UPLOAD (future) =================
    @future(callout=true)
    public static void uploadToS3Future(String logId, String s3Key, String csvContent) {
        String status       = 'Failed';
        String errorMessage = null;

        try {
            AWS_Settings__c setting = AWS_Settings__c.getInstance();
            String bucketUrl = setting != null ? setting.S3_Bucket_URL__c : null;

            if (String.isBlank(bucketUrl)) {
                throw new CalloutException('S3 Bucket URL not configured in AWS_Settings__c');
            }

            Blob body = Blob.valueOf(csvContent);
            HttpRequest req = new HttpRequest();
            req.setMethod('PUT');
            req.setEndpoint(bucketUrl + EncodingUtil.urlEncode(s3Key, 'UTF-8'));
            req.setHeader('Content-Type',   'text/csv');
            req.setHeader('Content-Length', String.valueOf(body.size()));
            req.setBodyAsBlob(body);

            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 200 && res.getStatusCode() != 201) {
                throw new CalloutException('S3 upload failed. HTTP ' + res.getStatusCode());
            }

        } catch (Exception e) {
            status       = 'Failed';
            errorMessage = e.getMessage();
            s3Key        = null;
        }

        File_Recovery_Log__c log = new File_Recovery_Log__c(
            Id               = logId,
            S3_Key__c        = s3Key,
            Backup_Status__c = 'Failed',
            Error_Message__c = errorMessage
        );
        AWSVaultSectionQueryHelper.updateLogs(new List<File_Recovery_Log__c>{ log });
    }

    // ================= PRIVATE HELPERS =================
    @TestVisible
    private static void uploadGroupBackup(
        String  objectType,
        String  s3Folder,
        String  groupPayload,
        Integer totalItems
    ) {
        Map<String, Object> parsed   = (Map<String, Object>) JSON.deserializeUntyped(groupPayload);
        List<String>        csvLines = new List<String>{ 'GroupKey,ItemName' };
        csvLines.addAll(buildGroupCsvRows(parsed));

        String csvContent = String.join(csvLines, '\n');
        String fileName   = objectType + '_' + DateTime.now().format('yyyy-MM-dd_HH-mm-ss') + '.csv';

      File_Recovery_Log__c log = new File_Recovery_Log__c(
    File_Name__c     = fileName,
    Object_Name__c   = objectType,
    S3_Key__c        = null,
    Action_Type__c   = 'Backup',
    Backup_Time__c   = DateTime.now(),
    Backup_Status__c = 'Failed',
    Error_Message__c = totalItems + ' items selected.'
);
AWSVaultSectionQueryHelper.sanitizeLogName(log, 'DAT', 'BKP');
AWSVaultSectionQueryHelper.insertBackupLog(log);

        if (log.Id != null && !Test.isRunningTest()) {
            uploadToS3Future(log.Id, s3Folder + '/' + fileName, csvContent);
        }
    }

    private static List<String> buildGroupCsvRows(Map<String, Object> parsed) {
        List<String> rows = new List<String>();
        for (String groupKey : parsed.keySet()) {
            rows.addAll(buildItemRowsForKey(groupKey, (List<Object>) parsed.get(groupKey)));
        }
        return rows;
    }

    private static List<String> buildItemRowsForKey(String groupKey, List<Object> items) {
        String       escapedKey = escapeCsvValue(groupKey);
        List<String> rows       = new List<String>();
        for (Object item : items) {
            rows.add(escapedKey + ',' + escapeCsvValue(String.valueOf(item)));
        }
        return rows;
    }

    @TestVisible
    private static String buildOrgFullCsv(
        List<String>        objectList,
        Map<String, Object> meta,
        Map<String, Object> config
    ) {
        List<String> csvLines = new List<String>{ 'Category,GroupKey,ItemName' };
        for (String obj : objectList) {
            csvLines.add('data,' + escapeCsvValue(obj) + ',');
        }
        csvLines.addAll(flattenGroupMap('metadata', meta));
        csvLines.addAll(flattenGroupMap('config',   config));
        return String.join(csvLines, '\n');
    }

    private static List<String> flattenGroupMap(
        String              category,
        Map<String, Object> groupMap
    ) {
        List<String> rows = new List<String>();
        for (String k : groupMap.keySet()) {
            rows.addAll(buildCategoryRowsForKey(category, k, (List<Object>) groupMap.get(k)));
        }
        return rows;
    }

    private static List<String> buildCategoryRowsForKey(
        String       category,
        String       key,
        List<Object> values
    ) {
        String       escapedKey = escapeCsvValue(key);
        List<String> rows       = new List<String>();
        for (Object v : values) {
            rows.add(category + ',' + escapedKey + ',' + escapeCsvValue(String.valueOf(v)));
        }
        return rows;
    }

   @TestVisible
private static File_Recovery_Log__c insertLog(
    String fileName, String objectName, String errorMessage
) {
    File_Recovery_Log__c log = new File_Recovery_Log__c(
        File_Name__c     = fileName,
        Object_Name__c   = objectName,
        S3_Key__c        = null,
        Action_Type__c   = 'Backup',
        Backup_Time__c   = DateTime.now(),
        Backup_Status__c = 'Failed',
        Error_Message__c = errorMessage
    );
    AWSVaultSectionQueryHelper.sanitizeLogName(log, 'DAT', 'BKP');
    AWSVaultSectionQueryHelper.insertBackupLog(log);
    return log;
}
@TestVisible
    private static String buildCsv(List<String> headers, List<SObject> records) {
        List<String> lines = new List<String>{ String.join(headers, ',') };
        for (SObject rec : records) {
            lines.add(buildCsvRow(headers, rec));
        }
        return String.join(lines, '\n');
    }
@TestVisible
    private static String buildCsvRow(List<String> headers, SObject rec) {
        List<String> values = new List<String>();
        for (String field : headers) {
            values.add(escapeCsvValue(rec.get(field)));
        }
        return String.join(values, ',');
    }

    private static String escapeCsvValue(Object val) {
        if (val == null) return '';
        String s = String.valueOf(val);
        if (s.contains(',') || s.contains('\n') || s.contains('\r') || s.contains('"')) {
            s = '"' + s.replace('"', '""') + '"';
        }
        return s;
    }

   private static ScheduleConfig parseSchedule(String schedulePayload) {
    ScheduleConfig cfg = new ScheduleConfig();
    if (String.isBlank(schedulePayload)) return cfg;
    try {
        Map<String, Object> p = (Map<String, Object>) JSON.deserializeUntyped(schedulePayload);
        if (p.containsKey('frequency'))     cfg.frequency     = (String)  p.get('frequency');
if (p.containsKey('time')) cfg.scheduledTime = (String) p.get('time');
        if (p.containsKey('weekday'))       cfg.weekday       = (String)  p.get('weekday');
        if (p.containsKey('monthDay'))
            cfg.monthDay = Integer.valueOf(String.valueOf(p.get('monthDay')));
    } catch (Exception e) {}
    return cfg;
}
   private static String buildCronExpression(ScheduleConfig cfg) {
    List<String> tp = cfg.scheduledTime.split(':');
    Integer hour = Integer.valueOf(tp[0]);
    Integer min  = Integer.valueOf(tp[1]);
    
    String base = '0 ' + min + ' ' + hour + ' ';
    
    switch on cfg.frequency {
        when 'daily'   { return base + '* * ? *'; }
        when 'weekly'  { return base + '? * ' + cfg.weekday + ' *'; }
        when 'monthly' { return base + cfg.monthDay + ' * ? *'; }
        when else      { return base + '* * ? *'; }
    }
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

    private static Map<String, Object> parseJsonMap(String jsonStr) {
        if (String.isBlank(jsonStr)) return new Map<String, Object>();
        return (Map<String, Object>) JSON.deserializeUntyped(jsonStr);
    }
@TestVisible
    private static Integer countGroupItems(Map<String, Object> parsed) {
        Integer total = 0;
        for (Object v : parsed.values()) total += ((List<Object>) v).size();
        return total;
    }

    private static Boolean isUnsupportedObject(String name) {
        String lower = name.toLowerCase();
        for (String suffix : UNSUPPORTED_SUFFIXES) {
            if (lower.endsWith(suffix)) return true;
        }
        return false;
    }
}