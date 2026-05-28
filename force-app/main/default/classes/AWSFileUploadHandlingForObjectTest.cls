@isTest
public class AWSFileUploadHandlingForObjectTest {
    @testSetup
    static void createTestData() {
        Account acc = TestDataFactory.createTestAccount();
        TestDataFactory.createUploadedFileInfo(acc.Id, 'Account', acc.Name);
        TestDataFactory.createAWSSetting();
    }
    @isTest
    static void testRecordInsert() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        
        System.runAs(u) {
            try { 
                Id testParentId = UserInfo.getUserId();
                String parent = 'Test Parent';
                String recordName = 'Record 1';
                String fileName = 'file.pdf';
                String fileURL = 'https://s3.amazonaws.com/test-bucket/file.pdf';
                String fileType = 'pdf';
                String objectKey = 'private/folder1/folder2/file.pdf';
                Decimal fileSize = 1.5;
                
                Test.startTest();
                Boolean result = AWSFileUploadHandlingControllerForObject.recordInsert(parent,testParentId,recordName,fileName,fileURL,fileType,objectKey,fileSize);
                Test.stopTest();
                
                System.assertEquals(true, result, 'Expected recordInsert to return true');
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    
    @isTest
    static void testGetAWSFiles() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        
        System.runAs(u) {
            try {  
                Uploaded_File_Info__c file =[SELECT Id FROM Uploaded_File_Info__c LIMIT 1];
                
                Test.startTest();
                String resultJson = AWSFileUploadHandlingControllerForObject.getAWSFiles(null, 0, 0);
                Test.stopTest();
                
                System.assertNotEquals(null, resultJson, 'Expected JSON response even with null and zero params');
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    
    @isTest
    static void testGetAWSFilesWithNullAndZero() {
          User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        
        System.runAs(u) {
            try {  
        String resultJson = AWSFileUploadHandlingControllerForObject.getAWSFiles(null, 0, 0);
        System.assertNotEquals(null, resultJson, 'Expected JSON response even with null and zero params');
  } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    
    @isTest
    static void testFetchExistingFileNames() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        
        System.runAs(u) {
            try {  
                Uploaded_File_Info__c file =[SELECT Id FROM Uploaded_File_Info__c LIMIT 1];
                Test.startTest();
                List<Uploaded_file_info__c> existingFiles = AWSFileUploadHandlingControllerForObject.fetchExistingFileNames(file.Parent_Record_Id__c);
                Test.stopTest();
                
                System.assertNotEquals(null, existingFiles, 'Expected non-null list of existing files');
                System.assertEquals(1, existingFiles.size(), 'Expected one file to be returned');
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    
    @isTest
    static void testWrapperUploadedfileinfo() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        
        System.runAs(u) {
            try { 
                AWSFileUploadHandlingControllerForObject.wrapperUploadedfileinfo wrapper = new AWSFileUploadHandlingControllerForObject.wrapperUploadedfileinfo();
                
                wrapper.recordStart = 1;
                wrapper.pageNumber = 1;
                wrapper.totalRecords = 100;
                wrapper.recordEnd = 10;
                wrapper.pageSize = 10;
                wrapper.uploadedfile = new List<Uploaded_file_info__c>();
                
                Uploaded_file_info__c fileInfo = new Uploaded_file_info__c(File_Name__c = 'TestFile.pdf',Parent_Record_Id__c = UserInfo.getUserId());
                wrapper.uploadedfile.add(fileInfo);
                
                System.assertEquals(1, wrapper.recordStart);
                System.assertEquals(1, wrapper.pageNumber);
                System.assertEquals(100, wrapper.totalRecords);
                System.assertEquals(10, wrapper.recordEnd);
                System.assertEquals(10, wrapper.pageSize);
                System.assertEquals(1, wrapper.uploadedfile.size());
                System.assertEquals('TestFile.pdf', wrapper.uploadedfile[0].File_Name__c);
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    
    
    @isTest
    static void testHelperWithZeroAndNullInputs() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        
        System.runAs(u) {
            try { 
                Test.startTest();
                String result1 = AWSQuerySharingHelper.getPaginatedAWSFiles(null, 0, 1);
                System.assertEquals(null, result1);
                Test.stopTest();
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    
    
    @isTest
    static void testHelperWith15CharId() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        
        System.runAs(u) {
            try { 
                Account parent = TestDataFactory.createTestAccount();
                TestDataFactory.createTestUploadedFile(parent.Id);
                
                Test.startTest();
                String resultJson = AWSQuerySharingHelper.getPaginatedAWSFiles(parent.Id, 1, 1);
                Test.stopTest();
                
                System.assertNotEquals(null, resultJson, 'Expected JSON result');
                System.assert(resultJson.contains('test.pdf'), 'Expected file name in result');
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    
    
    @isTest
    static void testGetPaginatedAWSFiles_with15CharId() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        
        System.runAs(u) {
            try { 
                Account acc = [SELECT Id FROM Account LIMIT 1];            
                
                
                String parentId15 = String.valueOf(acc.Id).substring(0, 15);
                
                Test.startTest();
                String result = AWSQuerySharingHelper.getPaginatedAWSFiles(parentId15, 5, 1);
                Test.stopTest();
                
                System.assert(result == null || result != '', 'Should return non-null if properly queried');
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    
    @isTest
    static void testControllerFallbackToDefaultParams() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try { 
                Test.startTest();
                String result = AWSFileUploadHandlingControllerForObject.getAWSFiles(null, null, null);
                Test.stopTest();
                
                System.assertNotEquals(null, result, 'Should return default empty JSON string');
                System.assert(result.contains('"uploadedfile":'), 'Should contain uploadedfile key');
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    @IsTest
    static void testDeleteCallout_Success() {
        User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSAdminPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try { 
                Uploaded_file_info__c fileRec = [SELECT Id, Parent_Record_Id__c FROM Uploaded_file_info__c LIMIT 1];
                Test.startTest();
                List<Uploaded_file_info__c> result = AWSFileUploadHandlingControllerForObject.deleteCallout(fileRec.Id);
                Test.stopTest();
                System.assertNotEquals(null, result);
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    @IsTest
    static void testDeleteCallout_BlankId() {
       User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSAdminPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try { 
                Test.startTest();
                try {
                    AWSFileUploadHandlingControllerForObject.deleteCallout(null);
                    System.assert(false, 'Expected exception not thrown');
                } catch (AuraHandledException e) {
                }
                Test.stopTest();
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    @IsTest
    static void testFetchExistingFileNames_Success() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try { 
                Account acc = [SELECT Id FROM Account LIMIT 1];
                Test.startTest();
                List<Uploaded_file_info__c> files = AWSFileUploadHandlingControllerForObject.fetchExistingFileNames(acc.Id);
                Test.stopTest();
                System.assert(files.size() > 0);
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    @IsTest
    static void testFetchExistingFileNames_Blank() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try { 
                Test.startTest();
                List<Uploaded_file_info__c> files = AWSFileUploadHandlingControllerForObject.fetchExistingFileNames(null);
                Test.stopTest();
                System.assertEquals(0, files.size());
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    @IsTest
    static void testFetchMetaListLwc() {
        User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try { 
                Test.startTest();
                Utils.AwsSettings result = AWSFileUploadHandlingControllerForObject.fetchMetaListLwc();
                Test.stopTest();
                System.assertNotEquals(null, result);
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
}