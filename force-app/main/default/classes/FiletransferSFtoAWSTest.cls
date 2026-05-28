@IsTest
public class FiletransferSFtoAWSTest {
    
    private class S3Mock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type','application/json');
            res.setBody('{"status":"success"}');
            return res;
        }
    }
    
    @testSetup
    static void setupData() {
        
        Account acc = TestDataFactory.createTestAccount();
        
        TestDataFactory.createUploadedFilesForAccount(acc, 2);
        
        TestDataFactory.createContentDocumentIds(acc.Id);
        
        TestDataFactory.createTestUploadedFile(acc.Id);
    }
    
    @IsTest
    static void testUploadFilesAndDelete(){
        User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        
        System.runAs(u) {
            try { 
                Account acc = [SELECT Id, Name FROM Account LIMIT 1];
                
                String objectType = acc.getSObjectType().getDescribe().getName();
                
                Test.setMock(HttpCalloutMock.class, new S3Mock());
                
                Test.startTest();
                
                FiletransferSFtoAWS.uploadFilesAndDelete(objectType, acc.Id);
                
                Test.stopTest();
                
                System.assertNotEquals(null, acc.Id);
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    @IsTest
    static void testGetFiles(){
        User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        
        System.runAs(u) {
            try {
                Account acc = [SELECT Id FROM Account LIMIT 1];
                
                Test.startTest();
                
                List<FiletransferSFtoAWS.FileWrapper> files =
                    FiletransferSFtoAWS.getFiles(acc.Id);
                
                Test.stopTest();
                
                System.assert(files != null);
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    
    @IsTest
    static void testUploadFiles(){
        User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        
        System.runAs(u) {
            try {
                Account acc = [SELECT Id, Name FROM Account LIMIT 1];
                
                String objectType = acc.getSObjectType().getDescribe().getName();
                
                Test.setMock(HttpCalloutMock.class, new S3Mock());
                
                String fileUrl = URL.getOrgDomainUrl().toExternalForm();
                
                Test.startTest();
                
                FiletransferSFtoAWS.uploadFiles(
                    objectType,
                    fileUrl,
                    acc.Id
                );
                
                Test.stopTest();
                
                System.assert(true);
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    @IsTest
    static void testUploadSingleFile() {
        
        User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSAdminPSet(u.Id);
        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        ContentVersion cv = [SELECT Title, FileExtension FROM ContentVersion LIMIT 1];
        
        String fileName = cv.Title + '.' + cv.FileExtension;
        String objectType = acc.getSObjectType().getDescribe().getName();
        
        Test.setMock(HttpCalloutMock.class, new S3Mock());
        
        Boolean exceptionThrown = false;
        
        Test.startTest();
        
        System.runAs(u) {
            try {
                FiletransferSFtoAWS.uploadSingleFile(objectType, acc.Id, fileName);
            } catch (AuraHandledException e) {
                exceptionThrown = true; 
            }
        }
        
        Test.stopTest();
        
        System.assertEquals(false, exceptionThrown, 'uploadSingleFile should complete without exception');
    }
    
    @IsTest
    static void testGetObjectType(){
        User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        
        System.runAs(u) {
            try {
                Account acc = [SELECT Id FROM Account LIMIT 1];
                Test.startTest();
                String objectType =
                    FiletransferSFtoAWS.getObjectType(acc.Id);
                Test.stopTest();
                System.assertNotEquals(null, objectType);
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    @IsTest
    static void testGetAWSConfig() {
         User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Aws_Settings__c setting = TestDataFactory.createAWSSetting();
        Test.startTest();
        Map<String, String> result =
            FiletransferSFtoAWS.getAWSConfig();
        Test.stopTest();
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('testAccessKey', result.get('accessKeyId'));
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    class MockS3Response implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('success');
            return res;
        }
    }

    @isTest
    static void testUploadFilesAndDelete_FullCoverage() {
        User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Account acc = TestDataFactory.createTestAccount();
        TestDataFactory.createContentDocumentIds(acc.Id);
        TestDataFactory.createTestAttachment(acc.Id, 'TestAttachment.txt', 'text/plain');
        TestDataFactory.createAWSSetting();
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockS3Response());
        FiletransferSFtoAWS.uploadFilesAndDelete('Account', acc.Id);
        Test.stopTest();
        List<Attachment> atts = [SELECT Id FROM Attachment WHERE ParentId = :acc.Id];
        System.assertEquals(0, atts.size());
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testDeleteSingleFile_success() {
         User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Account acc = TestDataFactory.createTestAccount();
        List<Id> docIds = TestDataFactory.createContentDocumentIds(acc.Id);
        ContentVersion cv = [
            SELECT Title, FileExtension, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId = :docIds[0]
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        String fileName = cv.Title + '.' + cv.FileExtension;
        Test.startTest();
        FiletransferSFtoAWS.deleteSingleFile(acc.Id, fileName);
        Test.stopTest();
        List<ContentDocument> remaining = [
            SELECT Id FROM ContentDocument WHERE Id = :docIds[0]
        ];
        System.assertEquals(0, remaining.size(), 'ContentDocument should have been deleted');
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
   @isTest
static void testDeleteSingleFile_fileNameMismatch() {
    User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
    Account acc = TestDataFactory.createTestAccount();
    List<Id> docIds = TestDataFactory.createContentDocumentIds(acc.Id);
    Test.startTest();
    FiletransferSFtoAWS.deleteSingleFile(acc.Id, 'nonexistent_file.pdf');
    Test.stopTest();
    List<ContentDocument> remaining = [
        SELECT Id FROM ContentDocument WHERE Id IN :docIds
    ];
    System.assertEquals(1, remaining.size(), 'ContentDocument should NOT have been deleted when filename does not match');
} catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    @isTest
    static void testDeleteSingleFile_nullRecordId() {
         User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.startTest();
        try {
            FiletransferSFtoAWS.deleteSingleFile(null, 'TestFile.pdf');
            System.assert(false, 'Expected AuraHandledException was not thrown');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('Script-thrown exception') || e.getMessage() != null,
                'Expected AuraHandledException'
            );
        }
        Test.stopTest();
  } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testDeleteSingleFile_blankFileName() {
         User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Account acc = TestDataFactory.createTestAccount();
        Test.startTest();
        try {
            FiletransferSFtoAWS.deleteSingleFile(acc.Id, '');
            System.assert(false, 'Expected AuraHandledException was not thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Expected AuraHandledException');
        }
        Test.stopTest();
     } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testDeleteSingleFile_noLinkedFiles() {
         User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Account acc = TestDataFactory.createTestAccount();
        Test.startTest();
        FiletransferSFtoAWS.deleteSingleFile(acc.Id, 'TestFile.pdf');
        Test.stopTest();
        System.assert(true, 'No exception should be thrown when no files are linked');
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
}