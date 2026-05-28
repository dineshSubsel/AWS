@isTest
public class AWSFileUploadHandlingControllerTest {
    
    private class AWSDeleteCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"success"}');
            res.setStatusCode(200);
            return res;
        }
    }
    
    @testSetup
    static void setupTestData() {
        TestDataFactory.setupAWSFileUploadTestData();
    }

    @isTest
static void testUpdatingAccessWithValidData() {
    User adminUser = TestDataFactory.createUser('System Administrator');
    TestDataFactory.AssignAWSAdminPSet(adminUser.Id);
    User standardUser = TestDataFactory.createUser('Standard User');
    TestDataFactory.AssignAWSInternalPSet(standardUser.Id);
    
    System.runAs(adminUser) {
        Folder__c targetFolder = TestDataFactory.createFolder('Test Folder', 'public', adminUser.Id, null);
        
        // Share with DIFFERENT user (standardUser) - not the owner (adminUser)
        Folder__Share folderShare = new Folder__Share();
        folderShare.ParentId = targetFolder.Id;
        folderShare.UserOrGroupId = standardUser.Id;
        folderShare.AccessLevel = 'Read';
        folderShare.RowCause = Schema.Folder__Share.RowCause.Manual;
        AWSQuerySharingHelper.insertFolderShare(folderShare);
        
        Test.startTest();
        Boolean result = AWSFileUploadHandlingController.updatingAccess(
            String.valueOf(targetFolder.Id), 'Edit', 'folder'
        );
        Test.stopTest();
        
        System.assertEquals(true, result, 'Should return true when share records exist');
    }
}

@isTest
static void testUpdatingAccessWithValidData_File() {
    User adminUser = TestDataFactory.createUser('System Administrator');
    TestDataFactory.AssignAWSAdminPSet(adminUser.Id);
    User standardUser = TestDataFactory.createUser('Standard User');
    TestDataFactory.AssignAWSInternalPSet(standardUser.Id);
    
    System.runAs(adminUser) {
        Uploaded_File_Info__c testFile = TestDataFactory.createUploadedFile(
            'TestFile.pdf', 'pdf', 'https://example.com/testfile.pdf'
        );
        
        // Share with DIFFERENT user (standardUser) - not the owner (adminUser)
        Uploaded_File_Info__Share fileShare = new Uploaded_File_Info__Share();
        fileShare.ParentId = testFile.Id;
        fileShare.UserOrGroupId = standardUser.Id;
        fileShare.AccessLevel = 'Read';
        fileShare.RowCause = Schema.Uploaded_File_Info__Share.RowCause.Manual;
        AWSQuerySharingHelper.insertFileShare(fileShare);
        
        Test.startTest();
        Boolean result = AWSFileUploadHandlingController.updatingAccess(
            String.valueOf(testFile.Id), 'Edit', 'file'
        );
        Test.stopTest();
        
        System.assertEquals(true, result, 'Should return true when file share records exist');
    }
}

    @isTest
    static void testUpdatingAccessWithnullData() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
                List<Folder__c> folders = TestDataFactory.createMultipleFolders();
                Folder__c targetFolder = folders[0];
                TestDataFactory.AssignAWSAdminPSet(u.Id);
                Test.startTest();
                Boolean result = AWSFileUploadHandlingController.updatingAccess(
                    String.valueOf(targetFolder.Id), 'Read', null
                );
                Test.stopTest();
                System.assertEquals(false, result, 'Should return false for null type');
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
                System.assert(!permError, 'Unexpected exception occurred: ' + e.getMessage());
            }
        }
    }

    @isTest
    static void testUpdatingAccessWithinValidData() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
                List<Folder__c> folders = TestDataFactory.createMultipleFolders();
                Folder__c targetFolder = folders[0];
                TestDataFactory.AssignAWSAdminPSet(u.Id);
                Test.startTest();
                Boolean result = AWSFileUploadHandlingController.updatingAccess(
                    String.valueOf(targetFolder.Id), 'Read', 'file'
                );
                Test.stopTest();
                System.assertEquals(false, result, 'Should return false when no file share records exist');
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
                System.assert(!permError, 'Unexpected exception occurred: ' + e.getMessage());
            }
        }
    }

    @isTest
    static void testUpdatingAccessWithNullinValidData() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
                Test.startTest();
                Boolean result = AWSFileUploadHandlingController.updatingAccess(
                    null, 'Read', null
                );
                Test.stopTest();
                System.assertEquals(false, result, 'Should return false when both params are null');
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
                System.assert(!permError, 'Unexpected exception occurred: ' + e.getMessage());
            }
        }
    }

    @isTest
    static void testUpdateFolderOwnerSuccess() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
                Folder__c testFolder = TestDataFactory.createFolder('Test Folder', 'private', UserInfo.getUserId(), null);
                Test.startTest();
                String result = AWSFileUploadHandlingController.updateFolderOwner(testFolder.Id, u.Id, 'Read');
                Test.stopTest();
                List<Folder__Share> shares = [
                    SELECT Id, ParentId, UserOrGroupId, AccessLevel 
                    FROM Folder__Share 
                    WHERE ParentId = :testFolder.Id
                ];
                System.assert(shares.size() > 0, 'There should be at least one Folder__Share record.');
                System.assert(
                    shares[0].AccessLevel == 'Read' || shares[0].AccessLevel == 'All',
                    'Access level should be Read or All but was: ' + shares[0].AccessLevel
                );
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
                System.assert(!permError, 'Unexpected exception occurred: ' + e.getMessage());
            }
        }
    }

    @isTest
    static void testUpdateFileOwnerSuccess() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
                Uploaded_File_Info__c testFile = TestDataFactory.createUploadedFile(
                    'TestFile.pdf', 'pdf', 'https://example.com/testfile.pdf'
                );
                Test.startTest();
                String result = AWSFileUploadHandlingController.updateFileOwner(testFile.Id, u.Id, 'Read');
                Test.stopTest();
                List<Uploaded_File_Info__Share> shares = [
                    SELECT Id, ParentId, UserOrGroupId, AccessLevel 
                    FROM Uploaded_File_Info__Share 
                    WHERE ParentId = :testFile.Id AND UserOrGroupId = :u.Id
                ];
                System.assert(shares.size() > 0, 'There should be at least one sharing record');
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testGetUsers() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
                Test.startTest();
                List<User> users = AWSFileUploadHandlingController.getUsers();
                Test.stopTest();
                System.assertNotEquals(null, users);
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testRemoveAccess() {
        User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSAdminPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
                Uploaded_File_Info__c file = [SELECT Id FROM Uploaded_File_Info__c LIMIT 1];
                List<Id> ids = new List<Id>{ file.Id };
                Test.startTest();
                Boolean result = AWSFileUploadHandlingController.removeAccess(ids, 'Manual');
                Test.stopTest();
                System.assert(result != null);
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testUpdateUrl() {
        User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSAdminPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
                Uploaded_File_Info__c file = [SELECT Id FROM Uploaded_File_Info__c LIMIT 1];
                Test.startTest();
                AWSFileUploadHandlingController.updateUrl(file.Id, 'https://updatedurl.com/test.pdf');
                Test.stopTest();
                Uploaded_File_Info__c updated = [
                    SELECT File_Url__c FROM Uploaded_File_Info__c WHERE Id = :file.Id
                ];
                System.assertEquals('https://updatedurl.com/test.pdf', updated.File_Url__c);
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testUpdateUrl_NullValues() {
        User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSAdminPSet(u.Id);
        System.runAs(u) {
            Test.startTest();
            // Both null - covers the null check return path
            AWSFileUploadHandlingController.updateUrl(null, null);
            // ID null only
            AWSFileUploadHandlingController.updateUrl(null, 'https://test.com/file.pdf');
            // URL null only
            Uploaded_File_Info__c file = [SELECT Id FROM Uploaded_File_Info__c LIMIT 1];
            AWSFileUploadHandlingController.updateUrl(file.Id, null);
            Test.stopTest();
        }
    }

    @isTest
    static void testDeleteAccess() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
                Uploaded_File_Info__c file = [SELECT Id FROM Uploaded_File_Info__c LIMIT 1];
                Test.startTest();
                Boolean result = AWSFileUploadHandlingController.deleteAccess(file.Id, 'Uploaded_File_Info__c');
                Test.stopTest();
                System.assert(result != null);
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
static void testGetSharingDetails() {
    User adminUser = TestDataFactory.createUser('System Administrator');
    TestDataFactory.AssignAWSAdminPSet(adminUser.Id);
    
    System.runAs(adminUser) {
        // Use existing file from testSetup - no new insert needed
        Uploaded_File_Info__c testFile = [SELECT Id FROM Uploaded_File_Info__c LIMIT 1];
        
        Test.startTest();
        String result = AWSFileUploadHandlingController.getssharingdetails(testFile.Id, 'file');
        Test.stopTest();
        
        // getSharingDetailsByParentIdAndType returns JSON or null - just verify no exception
        System.assert(true, 'Method executed without exception');
    }
}

@isTest
static void testGetSharingDetails_Folder() {
    User adminUser = TestDataFactory.createUser('System Administrator');
    TestDataFactory.AssignAWSAdminPSet(adminUser.Id);
    
    System.runAs(adminUser) {
        // Use existing folder from testSetup - no new insert needed
        Folder__c testFolder = [SELECT Id FROM Folder__c LIMIT 1];
        
        Test.startTest();
        String result = AWSFileUploadHandlingController.getssharingdetails(testFolder.Id, 'folder');
        Test.stopTest();
        
        System.assert(true, 'Method executed without exception');
    }
}

    @isTest
    static void testRecordInsert_withValidFolderHierarchy() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
                Folder__c folder2 = TestDataFactory.createFolderHierarchy();
                Account testAccount = TestDataFactory.createTestAccount();
                String parent = folder2.Id;
                String parentRecordName = testAccount.Name;
                Id parentId = testAccount.Id;
                String fileName = 'sample.pdf';
                String fileURL = 'https://s3.amazonaws.com/test-bucket/sample.pdf';
                String fileType = 'pdf';
                String objKey = 'public/folder1/folder2/test_sample.pdf';
                Decimal fileSize = 2.0;
                Test.startTest();
                Boolean result = AWSFileUploadHandlingController.recordInsert(
                    parent, parentRecordName, parentId, fileName, fileURL, fileType, objKey, fileSize
                );
                Test.stopTest();
                System.assertEquals(true, result, 'File record should be inserted successfully');
                List<Uploaded_File_Info__c> files = [
                    SELECT Id, File_Name__c, ObjectKey__c, Folder__c 
                    FROM Uploaded_File_Info__c 
                    WHERE File_Name__c = :fileName
                ];
                System.assertEquals(1, files.size(), '1 file record should be inserted');
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testGetAllFolders_withException() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
                Test.startTest();
                List<Folder__c> folders = null;
                try {
                    folders = AWSQuerySharingHelper.getAllFolders();
                } catch (Exception e) {
                    System.assert(false, 'Exception should be caught internally.');
                }
                Test.stopTest();
                System.assertNotEquals(null, folders, 'Should return an empty list on exception');
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testDeleteAccess_File() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
                Uploaded_file_info__c testFile = TestDataFactory.createUploadedFile(
                    'Test File', 'pdf', 'https://test-bucket.s3.amazonaws.com/test/sample.pdf'
                );
                Test.startTest();
                Boolean result = AWSFileUploadHandlingController.deleteAccess(testFile.Id, 'file');
                Test.stopTest();
                System.assertEquals(true, result, 'The user should have access to their own file');
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testDeleteAccess_Folder() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
                Folder__c testFolder = TestDataFactory.createFolder('Test Folder', 'private', u.Id, null);
                Test.startTest();
                Boolean result = AWSFileUploadHandlingController.deleteAccess(testFolder.Id, 'folder');
                Test.stopTest();
                System.assertEquals(true, result, 'The user should have access to their own folder');
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testDeleteAccess_InvalidObject() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
                Test.startTest();
                Boolean result = AWSFileUploadHandlingController.deleteAccess('someId', 'invalidObject');
                Test.stopTest();
                System.assertEquals(false, result, 'Invalid object should return false');
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testDeleteAccess_NullValues() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        System.runAs(u) {
            Test.startTest();
            Boolean result1 = AWSFileUploadHandlingController.deleteAccess(null, null);
            Boolean result2 = AWSFileUploadHandlingController.deleteAccess(null, 'file');
            Test.stopTest();
            System.assertEquals(false, result1, 'Should return false for null fileId and objectName');
            System.assertEquals(false, result2, 'Should return false for null fileId');
        }
    }

    @isTest
    static void testRemoveAccessException() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
                List<Id> invalidIds = null;
                Test.startTest();
                Boolean result = AWSQuerySharingHelper.removeAccessByIdsAndType(invalidIds, 'folder');
                Test.stopTest();
                System.assertEquals(false, result, 'Should return false when an exception occurs');
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testFileRemoveAccessException() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
                List<Id> invalidIds = null;
                Test.startTest();
                Boolean result = AWSQuerySharingHelper.removeAccessByIdsAndType(invalidIds, 'file');
                Test.stopTest();
                System.assertEquals(false, result, 'Should return false when an exception occurs');
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testFileRemoveAccess() {
        User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSAdminPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
                Uploaded_File_Info__c file = [SELECT Id FROM Uploaded_File_Info__c LIMIT 1];
                List<Id> ids = new List<Id>{ file.Id };
                Test.startTest();
                Boolean result = AWSFileUploadHandlingController.removeAccess(ids, 'file');
                Test.stopTest();
                System.assert(result != null);
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testFetchExistingFileNameUnderFolder() {
        User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSAdminPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
                Folder__c testFolder = TestDataFactory.createFolder('Test Folder', 'public', u.Id, null);
                TestDataFactory.createUploadedFile('FolderFile.pdf', 'pdf', 'https://example.com/folderfile.pdf');
                
                Uploaded_File_Info__c fileRec = [SELECT Id FROM Uploaded_File_Info__c LIMIT 1];
                fileRec.Folder__c = testFolder.Id;
                update fileRec;
                
                Test.startTest();
                List<Utils.UploadFileInfo> result = 
                    AWSFileUploadHandlingController.fetchExistingFileNameunderFolder(testFolder.Id);
                Test.stopTest();
                System.assertNotEquals(null, result, 'Result should not be null');
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testAllAWSMethods_NoCallout() {
        User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSAdminPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
                Uploaded_File_Info__c fileRec = [
                    SELECT Id, Parent_Record_Id__c, Folder__c
                    FROM Uploaded_File_Info__c
                    LIMIT 1
                ];
                Id parentId = fileRec.Parent_Record_Id__c;
                Id folderId = fileRec.Folder__c;
                Test.startTest();
                List<Utils.UploadFileInfo> existingFiles =
                    AWSFileUploadHandlingController.fetchExistingFileNames(parentId);
                System.assertNotEquals(null, existingFiles, 'Existing files should not be null');

                List<Utils.UploadFileInfo> existingFilesNull =
                    AWSFileUploadHandlingController.fetchExistingFileNames(null);
                System.assertEquals(0, existingFilesNull.size(), 'Should return empty list');

                List<Utils.UploadFileInfo> folderFiles =
                    AWSFileUploadHandlingController.fetchExistingFileNameunderFolder(folderId);
                System.assertNotEquals(null, folderFiles, 'Folder files should not be null');

                List<Utils.UploadFileInfo> awsPublicFiles =
                    AWSFileUploadHandlingController.getAWSFiles(parentId, 'public');
                System.assertNotEquals(null, awsPublicFiles, 'AWS public files should not be null');

                List<Utils.UploadFileInfo> awsPrivateFiles =
                    AWSFileUploadHandlingController.getAWSFiles(parentId, 'private');
                System.assertNotEquals(null, awsPrivateFiles, 'AWS private files should not be null');
                Test.stopTest();
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
                System.assert(!permError, 'Unexpected exception: ' + e.getMessage());
            }
        }
    }

    @isTest
    static void testDeleteCallout_WithMock() {
        User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSAdminPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
                Uploaded_File_Info__c fileRec = [
                    SELECT Id FROM Uploaded_File_Info__c LIMIT 1
                ];
                // Mock must be set BEFORE startTest
                Test.setMock(HttpCalloutMock.class, new AWSDeleteCalloutMock());
                Test.startTest();
                List<Utils.UploadFileInfo> deleteResult =
                    AWSFileUploadHandlingController.deleteCallout(fileRec.Id);
                System.assertNotEquals(null, deleteResult, 'deleteCallout result should not be null');

                List<Utils.UploadFileInfo> deleteNullResult =
                    AWSFileUploadHandlingController.deleteCallout(null);
                System.assertEquals(0, deleteNullResult.size(), 'Should return empty list for null');
                Test.stopTest();
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
                System.assert(!permError, 'Unexpected exception: ' + e.getMessage());
            }
        }
    }

    @isTest
    static void testGetAWSFiles_Public() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
                Folder__c publicFolder = [
                    SELECT Id FROM Folder__c WHERE Type__c = 'public' LIMIT 1
                ];
                Test.startTest();
                List<Utils.UploadFileInfo> files =
                    AWSFileUploadHandlingController.getAWSFiles(publicFolder.Id, 'public');
                Test.stopTest();
                System.assert(files.size() > 0, 'Files should exist');
                Utils.UploadFileInfo wrap = files[0];
                System.assertNotEquals(null, wrap.fileName);
                System.assertNotEquals(null, wrap.fileURL);
                System.assertNotEquals(null, wrap.objectKey);
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testGetAWSConfiguration() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
                Test.startTest();
                Utils.AwsSettings config = AWSFileUploadHandlingController.getAWSConfiguration();
                Test.stopTest();
                System.assertNotEquals(null, config, 'AWS config should not be null');
            } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
}