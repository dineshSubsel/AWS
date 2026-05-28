@IsTest
public class S3ConfigController_Test {

    @IsTest
    static void testCreateAWSMetadataSuccess() {
        User testUser = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(testUser.Id);
        System.runAs(testUser) {
            TestDataFactory.createAWSSetting();
            Test.startTest();
            String result = S3ConfigController.createAWSMetadata('newAccessKey', 'newSecretKey', 'newBucket', 'test-west-2');
            Test.stopTest();
            System.assertEquals('Success', result);
            AWS_Settings__c settings = AWS_Settings__c.getOrgDefaults();
            System.assertEquals('newAccessKey', settings.AWS_Access_Key_Id__c);
            System.assertEquals('newSecretKey', settings.AWS_Secret_Access_Key__c);
            System.assertEquals('newBucket', settings.S3_Bucket_Name__c);
            System.assertEquals('test-west-2', settings.S3_Region_Name__c);
        }
    }    
    @IsTest
    static void testCreateAWSMetadataException() {
        User testUser = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(testUser.Id);

        System.runAs(testUser) {
            try {
                S3ConfigController.createAWSMetadata(null, null, null, null);
                System.assert(false, 'Exception was expected but not thrown.');
            } catch (Exception e) {
            }
        }
    }
     @IsTest
    static void testGetSettingValuesSuccess() {
        User testUser = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(testUser.Id);
        System.runAs(testUser) {
            AWS_Settings__c setting = TestDataFactory.createAWSSetting();
            Test.startTest();
            Utils.AwsSettings result = S3ConfigController.getSettingValues();
            Test.stopTest();
            System.assertNotEquals(null, result);
            System.assertEquals(setting.AWS_Access_Key_Id__c, result.awsAccessKeyId);
            System.assertEquals(setting.AWS_Secret_Access_Key__c, result.awsSecretAccessKey);
            System.assertEquals(setting.S3_Bucket_Name__c, result.s3BucketName);
            System.assertEquals(setting.S3_Region_Name__c, result.s3RegionName);
        }
    }

    @IsTest
    static void testGetSettingValues_NoData() {
          User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try { 
            Test.startTest();
            try {
                S3ConfigController.getSettingValues();
            } catch (AuraHandledException e) {
            }
            Test.stopTest();
         } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
                System.assert(!permError, 'Unexpected exception occurred: ' + e.getMessage());
            }
        }
    }
}