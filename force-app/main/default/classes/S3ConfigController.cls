public with sharing class S3ConfigController {
    
    @AuraEnabled
    public static String createAWSMetadata(String accessKey, String secretKey, String bucketName, String region) {
        try {
            // Validate all required fields
            if (String.isBlank(accessKey) || String.isBlank(secretKey) || String.isBlank(bucketName) || String.isBlank(region)) {
                throw new AuraHandledException('All fields (Access Key, Secret Key, Bucket Name, Region) are required.');
            }

            AWSQuerySharingHelper.saveOrUpdateAWSSettings(accessKey, secretKey, bucketName, region);
            return 'Success';
        } catch (Exception ex) {
            throw new AuraHandledException('Error while updating AWS Setting: ' + ex.getMessage());
        }
    }

    @AuraEnabled
public static Utils.AwsSettings getSettingValues() {
    try {

        AWS_Settings__c settings = AWS_Settings__c.getOrgDefaults();

        if(settings == null){
            throw new AuraHandledException('No AWS Settings found.');
        }
       if(String.isBlank(settings.AWS_Access_Key_Id__c)){
            throw new AuraHandledException('Invalid AWS Settings');
        }
        Utils.AwsSettings wrapper = new Utils.AwsSettings();

        wrapper.awsAccessKeyId = settings.AWS_Access_Key_Id__c;
        wrapper.awsSecretAccessKey = settings.AWS_Secret_Access_Key__c;
        wrapper.s3BucketName = settings.S3_Bucket_Name__c;
        wrapper.s3RegionName = settings.S3_Region_Name__c;

        return wrapper;

    } catch (Exception ex) {

        throw new AuraHandledException(
            'Error retrieving AWS Settings: ' + ex.getMessage()
        );
    }
}

}