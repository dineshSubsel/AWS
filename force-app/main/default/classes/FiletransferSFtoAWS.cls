public with sharing class FiletransferSFtoAWS {

 @AuraEnabled
public static void uploadFilesAndDelete(String objectType, Id recordId) {

    if(recordId == null){
        return;
    }

    String objectName = getObjectName(recordId).toLowerCase().trim();
    String basePath = objectName + '/' + recordId;
    Set<Id> docsToDelete = new Set<Id>();
    List<Attachment> attachmentsToDelete = new List<Attachment>();
    Map<String, String> config = getAWSConfig();
    String bucket = config.get('bucketName');
    String region = config.get('region');
    List<ContentDocumentLink> links =
        AWSQuerySharingHelper.getContentDocumentLinks(recordId);
    Set<Id> contentDocIds = new Set<Id>();
    for(ContentDocumentLink l : links){
        contentDocIds.add(l.ContentDocumentId);
    }

    List<ContentVersion> versions =
        AWSQuerySharingHelper.get_LatestContentVersions(contentDocIds);
    List<HttpRequest> fileRequests = new List<HttpRequest>();
    List<ContentVersion> fileList = new List<ContentVersion>();
    for(ContentVersion v : versions){
        String fileName = v.Title + '.' + v.FileExtension;
        String s3Key = objectType + '/' + recordId + '/' + fileName;
        String fullPath = basePath + '/' + fileName;
        HttpRequest req = new HttpRequest();
        String endpoint = 'https://' + bucket +
                          '.s3.' + region +
                          '.amazonaws.com/' +
                          EncodingUtil.urlEncode(s3Key, 'UTF-8');

        req.setEndpoint(endpoint);
        req.setMethod('PUT');
        req.setHeader('Content-Type', 'application/json');
        Map<String, Object> payload = new Map<String, Object>{
            'filePath' => fullPath,
            'base64Data' => EncodingUtil.base64Encode(v.VersionData)
        };

        req.setBody(JSON.serialize(payload));
        fileRequests.add(req);
        fileList.add(v);
    }

    List<Attachment> attachments =
        AWSQuerySharingHelper.getAttachments(recordId);
    List<HttpRequest> attachmentRequests = new List<HttpRequest>();
    List<Attachment> attachmentList = new List<Attachment>();
    for (Attachment a : attachments) {
        String s3Key = objectType + '/' + recordId + '/' + a.Name;
        String fullPath = basePath + '/' + a.Name;
        HttpRequest req = new HttpRequest();
        String endpoint = 'https://' + bucket +
                          '.s3.' + region +
                          '.amazonaws.com/' +
                          EncodingUtil.urlEncode(s3Key, 'UTF-8');

        req.setEndpoint(endpoint);
        req.setMethod('PUT');
        req.setHeader('Content-Type', 'application/json');
        Map<String, Object> payload = new Map<String, Object>{
            'filePath' => fullPath,
            'base64Data' => EncodingUtil.base64Encode(a.Body)
        };

        req.setBody(JSON.serialize(payload));
        attachmentRequests.add(req);
        attachmentList.add(a);
    }

    Http http = new Http();
    for(Integer i = 0; i < fileRequests.size(); i++){
        HttpResponse res = http.send(fileRequests[i]);
        if(res.getStatusCode() == 200){
            docsToDelete.add(fileList[i].ContentDocumentId);
        } else {
            throw new AuraHandledException('Failed to upload: ' + fileList[i].Title);
        }
    }

    for(Integer i = 0; i < attachmentRequests.size(); i++){
        HttpResponse res = http.send(attachmentRequests[i]);
        if(res.getStatusCode() == 200){
            attachmentsToDelete.add(attachmentList[i]);
        } else {
            throw new AuraHandledException('Failed to upload attachment: ' + attachmentList[i].Name);
        }
    }
    if(!docsToDelete.isEmpty()){
        AWSQuerySharingHelper.deleteContentDocuments(docsToDelete);
    }
    if(!attachmentsToDelete.isEmpty()){
        AWSQuerySharingHelper.deleteAttachments(attachmentsToDelete);
    }
}
   private static Boolean uploadToS3(String s3, String filePath, String base64Data) {
    AWS_Settings__c settings = AWS_Settings__c.getOrgDefaults();
    String bucketName = settings.S3_Bucket_Name__c;
    String region = settings.S3_Region_Name__c;
    HttpRequest req = new HttpRequest();
    String endpoint = 'https://' + bucketName + '.s3.' + region + '.amazonaws.com/' + EncodingUtil.urlEncode(s3, 'UTF-8');
    req.setEndpoint(endpoint);
    req.setMethod('PUT');
    req.setHeader('Content-Type', 'application/json');
    Map<String, Object> payload = new Map<String, Object>{
        'filePath' => filePath,
        'base64Data' => base64Data
    };
    req.setBody(JSON.serialize(payload));
    Http http = new Http();
    HttpResponse res = http.send(req);

    return res.getStatusCode() == 200;
}

   private static String getObjectName(String recordId) {
    if (String.isBlank(recordId)) {
        return null;
    }
    try {
        Id recId = (Id) recordId;
        return recId.getSObjectType().getDescribe().getName();
    } catch (Exception e) {
        return 'unknown';
    }
}
     @AuraEnabled(cacheable=true)
    public static List<FileWrapper> getFiles(Id accountId) {
        if(accountId == null){
            return null;
        }
        List<FileWrapper> results = new List<FileWrapper>();
        Set<String> uploadedFileNames = new Set<String>();
        List<Uploaded_File_Info__c> uploadedFiles =
            AWSQuerySharingHelper.getUploadedFiles(accountId);
        for(Uploaded_File_Info__c info : uploadedFiles){
            uploadedFileNames.add(info.File_Name__c);
        }

        List<ContentDocumentLink> links =
            AWSQuerySharingHelper.fetchDocumentLinksByRecord(accountId);
        Set<Id> docIds = new Set<Id>();
        for(ContentDocumentLink link : links){
            docIds.add(link.ContentDocumentId);
        }

        List<ContentVersion> versions =
            AWSQuerySharingHelper.fetchLatestFileVersions(docIds);
        for(ContentVersion v : versions){
            String fullFileName = v.Title + '.' + v.FileExtension;
            if(!uploadedFileNames.contains(fullFileName)){
                results.add(
                    new FileWrapper(
                        fullFileName,
                        formatSize(v.ContentSize),
                        'Pending',
                        0,
                        v.FileExtension,
                        null
                    )
                );
            }
        }

        return results;
    }

    public class FileWrapper {
        @AuraEnabled public String name;
        @AuraEnabled public String size;
        @AuraEnabled public String status;
        @AuraEnabled public Integer progress;
        @AuraEnabled public String fileType;
        @AuraEnabled public String objectKey;

        public FileWrapper(String name,String size,String status,Integer progress,String fileType,String objectKey){
            this.name = name;
            this.size = size;
            this.status = status;
            this.progress = progress;
            this.fileType = fileType;
            this.objectKey = objectKey;
        }
    }

    private static String formatSize(Integer bytes){
        Decimal kb = bytes / 1024.0;
        return String.valueOf(kb.setScale(2)) + ' KB';
    }

    @AuraEnabled(cacheable=true)
    public static String getObjectType(Id recordId) {
        if(recordId == null){
            return null;
        }
        return getObjectName(recordId); 
    }

   @AuraEnabled
public static void uploadFiles(String objectType, String fileURL, Id recordId) {

    if (recordId == null) {
        throw new AuraHandledException('Record Id cannot be null');
    }
    String objectName = (objectType != null)
        ? objectType.toLowerCase().trim()
        : '';
    String baseFolder = objectName + '/' + recordId;
    List<ContentDocumentLink> links =
        AWSQuerySharingHelper.fetchDocumentLinksByRecord(recordId);

    Set<Id> contentDocIds = new Set<Id>();
    for (ContentDocumentLink l : links) {
        contentDocIds.add(l.ContentDocumentId);
    }

    List<ContentVersion> versions =
        AWSQuerySharingHelper.fetchLatestFileVersionsWithData(contentDocIds);
    String recordName =
        AWSQuerySharingHelper.fetchRecordName(objectType, recordId);
    List<Uploaded_File_Info__c> fileInfosToInsert =
        new List<Uploaded_File_Info__c>();
    List<Map<String, String>> uploadPayloads =
        new List<Map<String, String>>();

    for (ContentVersion v : versions) {
        String fileName = v.Title + '.' + v.FileExtension;
        String s3Key = baseFolder + '/' + fileName;
        Map<String, String> payload = new Map<String, String>();
        payload.put('s3Key', s3Key);
        payload.put('fullPath', s3Key);
        payload.put('base64Data', EncodingUtil.base64Encode(v.VersionData));
        payload.put('fileName', fileName);
        payload.put('fileExt', v.FileExtension);
        payload.put('fileSize', String.valueOf(v.ContentSize));

        uploadPayloads.add(payload);
    }

    List<String> failedFiles = uploadToS3Bulk(uploadPayloads);
    if (!failedFiles.isEmpty()) {
        throw new AuraHandledException(
            'Failed to upload files: ' + String.join(failedFiles, ', ')
        );
    }

    for (Map<String, String> p : uploadPayloads) {
        Uploaded_File_Info__c info = new Uploaded_File_Info__c();
        info.File_Type__c = p.get('fileExt');
        info.File_Name__c = p.get('fileName');
        info.File_Url__c = fileURL;
        info.Parent_Name__c = recordName;
        info.Parent_Record_Id__c = String.valueOf(recordId);
        info.ObjectKey__c = p.get('s3Key');
        info.File_Sizes__c = p.get('fileSize');

        fileInfosToInsert.add(info);
    }
    AWSQuerySharingHelper.insertUploadedFileInfos(fileInfosToInsert);
}
     @AuraEnabled
public static void uploadSingleFile(String objectType, Id recordId, String fileName) {
    if (recordId == null || String.isBlank(fileName)) {
        throw new AuraHandledException('Invalid input');
    }

    String objectName = String.isBlank(objectType) 
        ? 'unknown' 
        : objectType.toLowerCase().trim();

    String basePath = objectName + '/' + recordId;
    String s3Key    = basePath + '/' + fileName;
    String fullPath = s3Key;
    List<ContentDocumentLink> links =
        AWSQuerySharingHelper.fetchDocumentLinksByRecord(recordId);

    if (links == null || links.isEmpty()) {
        throw new AuraHandledException('No files found for record');
    }

    Set<Id> docIds = new Set<Id>();
    for (ContentDocumentLink link : links) {
        if (link != null && link.ContentDocumentId != null) {
            docIds.add(link.ContentDocumentId);
        }
    }

    if (docIds.isEmpty()) {
        throw new AuraHandledException('No valid document IDs found');
    }
    List<ContentVersion> versions =
        AWSQuerySharingHelper.fetchLatestFileVersionsWithData(docIds);
    if (versions == null || versions.isEmpty()) {
        throw new AuraHandledException('No file versions found');
    }
    ContentVersion targetFile;
    for (ContentVersion v : versions) {
        if (v != null &&
            v.Title != null &&
            v.FileExtension != null &&
            (v.Title + '.' + v.FileExtension) == fileName) {

            targetFile = v;
            break;
        }
    }

    if (targetFile == null) {
        throw new AuraHandledException('File not found: ' + fileName);
    }

    if (targetFile.VersionData == null) {
        throw new AuraHandledException('File data is empty');
    }

    String base64Data = EncodingUtil.base64Encode(targetFile.VersionData);
    Boolean success = uploadToS3(s3Key, fullPath, base64Data);

    if (success == null || !success) {
        throw new AuraHandledException('Failed to upload: ' + fileName);
    }
    Uploaded_File_Info__c info = new Uploaded_File_Info__c();
    info.File_Type__c = targetFile.FileExtension;
    info.File_Name__c = fileName;
    info.Parent_Record_Id__c = String.valueOf(recordId);
    info.ObjectKey__c = s3Key;
    info.File_Sizes__c = targetFile.ContentSize != null
        ? String.valueOf(targetFile.ContentSize)
        : null;

    AWSQuerySharingHelper.insertUploadedFileInfo(info);
}
public static List<String> uploadToS3Bulk(List<Map<String, String>> uploads) {
    List<String> failedFiles = new List<String>();
    processUploads(uploads, 0, failedFiles);
    return failedFiles;
}

private static void processUploads(List<Map<String, String>> uploads, Integer index, List<String> failedFiles) {
    if (uploads == null || index >= uploads.size()) {
        return;
    }

    Map<String, String> u = uploads[index];
    if (u != null) {
        try {
            Boolean success = uploadToS3(
                u.get('s3Key'),
                u.get('fullPath'),
                u.get('base64Data')
            );
            if (!success) {
                failedFiles.add(u.get('fileName'));
            }
        } catch (Exception e) {
            failedFiles.add(u.get('fileName'));
        }
    }
    processUploads(uploads, index + 1, failedFiles);
}
@AuraEnabled(cacheable=true)
public static Map<String, String> getAWSConfig() {

    Aws_Settings__c setting = AWSQuerySharingHelper.getAwsSettings();

    Map<String, String> config = new Map<String, String>();

    config.put('accessKeyId', setting.AWS_Access_Key_Id__c);
    config.put('secretAccessKey', setting.AWS_Secret_Access_Key__c);
    config.put('region', setting.S3_Region_Name__c);
    config.put('bucketName', setting.S3_Bucket_Name__c);

    return config;
}
   @AuraEnabled
public static void deleteSingleFile(Id recordId, String fileName) {

    if (recordId == null || String.isBlank(fileName)) {
        throw new AuraHandledException('Invalid input');
    }

    List<ContentDocumentLink> links =
        AWSQuerySharingHelper.fetchDocumentLinksByRecord(recordId);

    Set<Id> docIds = new Set<Id>();

    for (ContentDocumentLink l : links) {
        docIds.add(l.ContentDocumentId);
    }

    List<ContentVersion> versions =
        AWSQuerySharingHelper.fetchLatestFileVersions(docIds);

    List<ContentDocument> toDelete = new List<ContentDocument>();

    for (ContentVersion v : versions) {
        if ((v.Title + '.' + v.FileExtension) == fileName) {

            toDelete.add(new ContentDocument(Id = v.ContentDocumentId));
            break;
        }
    }

    if (!toDelete.isEmpty()) {
        AWSQuerySharingHelper.deleteContentDocuments(toDelete);
    }
}
}