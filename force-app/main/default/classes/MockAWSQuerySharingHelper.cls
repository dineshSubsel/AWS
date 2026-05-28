public with sharing class MockAWSQuerySharingHelper {
        public static Boolean throwException = false;
    public class CustomException extends Exception {}
        static void saveOrUpdateAWSSettings(String accessKey, String secretKey, String bucketName, String region) {
            if (throwException) {
                throw new CustomException('Test Exception in saveOrUpdateAWSSettings');
            }
        }
    }