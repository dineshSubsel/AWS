public with sharing class CustomMetadataController {
    
    // Create or update AWS custom metadata values
    @AuraEnabled
    public static String createAWSMetadata(String accessKey, String secretKey, String bucketName, String region) {
        // Null and blank checks
        if (String.isBlank(accessKey) || String.isBlank(secretKey) || 
            String.isBlank(bucketName) || String.isBlank(region)) {
            throw new AuraHandledException('All AWS credentials (Access Key, Secret Key, Bucket Name, and Region) are required.');
        }

        try {
            AWSQuerySharingHelper.saveOrUpdateAWSSettings(accessKey, secretKey, bucketName, region);
            return 'Success';
        } catch (Exception ex) {
            throw new AuraHandledException('Error while updating AWS Setting: ' + ex.getMessage());
        }
    }

    // Fetch current AWS metadata record (named instance)
    @AuraEnabled(cacheable=true)
    public static AWS_Settings__c getSettingValues() {
        AWS_Settings__c result = AWS_Settings__c.getInstance('AWS_Setting');

        if (result == null) {
            throw new AuraHandledException('AWS Setting metadata not found. Please ensure the AWS_Settings__mdt record exists.');
        }

        return result;
    }
}