public with sharing class AWSFileUploadHandlingControllerForObject {

    // Wrapper class for pagination support
    public class wrapperUploadedfileinfo {
        public Integer recordStart { get; set; }
        public Integer pageNumber { get; set; }
        public Integer totalRecords { get; set; }
        public Integer recordEnd { get; set; }
        public Integer pageSize { get; set; }       
        public List<Uploaded_file_info__c> uploadedfile { get; set; }
    }

    // Insert record after AWS upload
    @AuraEnabled
    public static Boolean recordInsert(
        String parent,
        Id parentId,
        String parentRecordName,
        String fileName,
        String fileURL,
        String filetype,
        String objKey,
        Decimal filesize
    ) {
        if (String.isBlank(parent) || parentId == null || String.isBlank(parentRecordName) ||
            String.isBlank(fileName) || String.isBlank(fileURL) || String.isBlank(filetype) ||
            String.isBlank(objKey) || filesize == null) {
            throw new AuraHandledException('All fields are required. One or more are missing or invalid.');
        }

        Uploaded_file_info__c info = new Uploaded_file_info__c();
        info.Parent_record_name__c = parentRecordName;
        info.Parent_Record_Id__c = parentId;
        info.File_Type__c = filetype;
        info.File_url__c = fileURL;
        info.File_Name__c = fileName;
        info.Parent_Name__c = parent;
        info.ObjectKey__c = objKey;
        info.File_sizes__c = String.valueOf(filesize);

        AWSQuerySharingHelper.insertUploadedFileInfo(info);
        return true;
    }

    // Get paginated AWS file records
    @AuraEnabled
    public static String getAWSFiles(String parentId, Integer pageSize, Integer pageNumber) {
        if (parentId == null) {
            parentId = null;
        }

        if (pageSize == null || pageSize < 1) {
            pageSize = 10;
        }

        if (pageNumber == null || pageNumber < 1) {
            pageNumber = 1;
        }

        String result = AWSQuerySharingHelper.getPaginatedAWSFiles(parentId, pageSize, pageNumber);

        if (result == null) {
            result = '{"uploadedfile": [], "totalRecords": 0, "pageNumber": 1, "pageSize": 10}';
           
        }
        return result;
    }

   @AuraEnabled(cacheable=false)
public static List<Uploaded_file_info__c> deleteCallout(String recordId) {
    if (recordId == null) {
        throw new AuraHandledException('Record Id cannot be null or blank.');
    }

    Uploaded_file_info__c oldRec = AWSQuerySharingHelper.getFileRecordById(recordId);
    AWSQuerySharingHelper.deleteFileRecord(oldRec);

    if (oldRec.Parent_Record_Id__c != null) {
        return AWSQuerySharingHelper.getFilesByParentId(oldRec.Parent_Record_Id__c);
    }
    return new List<Uploaded_file_info__c>();
}
    // Fetch uploaded files for duplicate checking
    @AuraEnabled(cacheable=false)
    public static List<Uploaded_file_info__c> fetchExistingFileNames(String parentId) {
        if (parentId == null) {
            return new List<Uploaded_file_info__c>(); 
        }

        return AWSQuerySharingHelper.getFilesByParentId(parentId);
    }
@AuraEnabled(cacheable=true)
public static Utils.AwsSettings fetchMetaListLwc() {

    Aws_Settings__c setting = AWSQuerySharingHelper.getAwsSettings();

    Utils.AwsSettings conf = new Utils.AwsSettings();
    conf.awsAccessKeyId = setting.AWS_Access_Key_Id__c;
    conf.awsSecretAccessKey = setting.AWS_Secret_Access_Key__c;
    conf.s3BucketName = setting.S3_Bucket_Name__c;
    conf.s3RegionName = setting.S3_Region_Name__c;
    conf.apiVersion = setting.API_Version__c;
    conf.signatureVersion = setting.Signature_Version__c;

    return conf;
}
}