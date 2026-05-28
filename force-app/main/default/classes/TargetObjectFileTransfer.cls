public with sharing class TargetObjectFileTransfer {

    @AuraEnabled
    public static String moveFilesToTargetObject(
        String objectType,
        Id sourceRecordId,
        String targetObjectApiName,
        Id targetRecordId,
        List<Id> selectedContentDocumentIds
    ) {
        if (sourceRecordId == null) {
            throw new AuraHandledException('Source record ID is required.');
        }
        if (String.isBlank(targetObjectApiName)) {
            throw new AuraHandledException('Target object API name is required.');
        }
        if (targetRecordId == null) {
            throw new AuraHandledException('Target record ID is required.');
        }
        if (selectedContentDocumentIds == null || selectedContentDocumentIds.isEmpty()) {
            throw new AuraHandledException('No files selected for moving.');
        }

        List<ContentVersion> versions = AWSQuerySharingHelper.getContentVersions(
            new Set<Id>(selectedContentDocumentIds)
        );

        for (ContentVersion version : versions) {
            if (version == null || String.isBlank(version.Title) || String.isBlank(version.FileExtension)) {
                continue;
            }

            String fileName = version.Title + '.' + version.FileExtension;
            String s3Key = objectType + '/' + sourceRecordId + '/' + fileName;
            String sourcePath = getObjectName(sourceRecordId) + '/' + sourceRecordId + '/' + fileName;
            String targetPath = targetObjectApiName.toLowerCase() + '/' + targetRecordId + '/' + fileName;

            moveS3File(s3Key, sourcePath, targetPath);
        }

        AWSQuerySharingHelper.insertDocumentLinks(targetRecordId, selectedContentDocumentIds);
        AWSQuerySharingHelper.deleteOldLinks(sourceRecordId, selectedContentDocumentIds);

        return 'Files moved successfully';
    }

@AuraEnabled
public static Boolean checkObjectSupportsFiles(String objectApiName) {
    if (String.isBlank(objectApiName)) return false;

    try {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        Schema.SObjectType targetType = gd.get(objectApiName);
        if (targetType == null) return false;
        Schema.DescribeSObjectResult describeResult = targetType.getDescribe();
        if (!describeResult.isQueryable()) return false;
        Schema.SObjectType cdlType = gd.get('ContentDocumentLink');
        if (cdlType == null) return false;
        Schema.DescribeFieldResult linkedEntityField =
            cdlType.getDescribe().fields.getMap().get('LinkedEntityId').getDescribe();
        if (linkedEntityField == null) return false;
        List<Schema.SObjectType> referenceTo = linkedEntityField.getReferenceTo();
        for (Schema.SObjectType refType : referenceTo) {
            if (refType.getDescribe().getName().equalsIgnoreCase(objectApiName)) {
                return true;
            }
        }
        return false;
    } catch (Exception e) {
        return false;
    }
}
@AuraEnabled
public static Integer getRecordCountForObject(String objectApiName) {
    if (String.isBlank(objectApiName)) return 0;

    try {
        Map<String, Schema.SObjectType> globalMap = Schema.getGlobalDescribe();

        if (!globalMap.containsKey(objectApiName)) {
            return 0;
        }

        Schema.DescribeSObjectResult describeResult =
            globalMap.get(objectApiName).getDescribe();

        if (!describeResult.isQueryable()) {
            return 0;
        }

        String safeObjectName = String.escapeSingleQuotes(objectApiName);

        String query = 'SELECT COUNT(Id) cnt FROM ' + safeObjectName;

        List<AggregateResult> result = Database.query(query);

        return result.isEmpty() ? 0 : (Integer) result[0].get('cnt');

    } catch (Exception e) {
        return 0;
    }
}
 @AuraEnabled
public static List<Map<String, String>> searchRecords(String searchKey, String objectApiName) {

    if (String.isBlank(searchKey) || String.isBlank(objectApiName)) {
        return new List<Map<String, String>>();
    }

    Map<String, Schema.SObjectType> globalMap = Schema.getGlobalDescribe();
    if (!globalMap.containsKey(objectApiName)) {
        throw new AuraHandledException('Invalid object API name: ' + objectApiName);
    }

    Schema.DescribeSObjectResult describeResult = globalMap.get(objectApiName).getDescribe();
    Map<String, Schema.SObjectField> fieldsMap = describeResult.fields.getMap();

    String nameField;

    for (String candidate : new List<String>{ 'name', 'subject', 'title' }) {
        if (fieldsMap.containsKey(candidate)) {
            Schema.DescribeFieldResult f = fieldsMap.get(candidate).getDescribe();
            if (f.isFilterable()) {
                nameField = f.getName();
                break;
            }
        }
    }

    if (nameField == null) {
        for (Schema.SObjectField f : fieldsMap.values()) {
            Schema.DescribeFieldResult d = f.getDescribe();
            if (d.isNameField() && d.isFilterable()) {
                nameField = d.getName();
                break;
            }
        }
    }

    if (nameField == null) {
        for (Schema.SObjectField f : fieldsMap.values()) {
            Schema.DescribeFieldResult d = f.getDescribe();
            if (d.isFilterable() &&
                d.getType() == Schema.DisplayType.STRING &&
                !d.isAutoNumber()) {
                nameField = d.getName();
                break;
            }
        }
    }

    if (nameField == null) {
        throw new AuraHandledException(
            'Object "' + objectApiName + '" does not have any searchable field.'
        );
    }

    String likePattern = '%' + searchKey + '%';

    String query =
        'SELECT Id, ' + nameField +
        ' FROM ' + objectApiName +
        ' WHERE ' + nameField + ' LIKE :likePattern' +
        ' LIMIT 50';

    List<SObject> records = Database.query(query);

    List<Map<String, String>> results = new List<Map<String, String>>();

    for (SObject rec : records) {
        String recId = (String) rec.get('Id');
        String recLabel = (String) rec.get(nameField);

        if (recId != null && recLabel != null) {
            results.add(new Map<String, String>{
                'label' => recLabel,
                'Id'    => recId
            });
        }
    }

    return results;
}
    @AuraEnabled
    public static List<ContentVersion> fetchFilesForRecord(Id recordId) {
        try {
            if(recordId != null){
               return AWSQuerySharingHelper.getLatestVersionsForRecord(recordId);
            } 
            return null;
            
        } catch (Exception e) {
            return new List<ContentVersion>();
        }
    }

@TestVisible
private static String getObjectName(Id recordId) {
    return (recordId != null && recordId.getSObjectType() != null)
        ? recordId.getSObjectType().getDescribe().getName().toLowerCase()
        : 'unknown';
}

    @TestVisible
    private static Boolean moveS3File(String s3Key, String sourcePath, String targetPath) {
        if (String.isBlank(s3Key) || String.isBlank(sourcePath) || String.isBlank(targetPath)) {
            return false;
        }
        AWS_Settings__c settings = AWS_Settings__c.getOrgDefaults();
        if (settings == null ||
            String.isBlank(settings.S3_Bucket_Name__c) ||
            String.isBlank(settings.S3_Region_Name__c)) {
            throw new AuraHandledException('AWS Settings are not configured.');
        }
        String bucketName = settings.S3_Bucket_Name__c;
        String region = settings.S3_Region_Name__c;
        HttpRequest req = new HttpRequest();
        String endpoint = 'https://' + bucketName + '.s3.' + region + '.amazonaws.com/' +
            EncodingUtil.urlEncode(s3Key, 'UTF-8');
        req.setEndpoint(endpoint);
        req.setMethod('PUT');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(new Map<String, String>{
            'sourcePath' => sourcePath,
            'targetPath' => targetPath
        }));
        Http http = new Http();
        HttpResponse res;
        try {
            res = http.send(req);
        } catch (Exception e) {
            return false;
        }
        return res != null && res.getStatusCode() == 200;
    }
}