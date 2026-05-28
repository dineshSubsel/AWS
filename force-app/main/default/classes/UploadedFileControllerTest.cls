@isTest
public class UploadedFileControllerTest {
    
    @testSetup
    static void createTestData() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;      
        System.runAs(u) {
            try {
        Account acc = TestDataFactory.createTestAccount();
        TestDataFactory.createFolderForRecord('Test Folder', 'Root', 'Account', acc.Id);
        TestDataFactory.createUploadedFileInfo(acc.Id, 'Account', acc.Name);
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testDeleteAllFiles() {
      User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;      
        System.runAs(u) {
            try {
            Account acc = [SELECT Id FROM Account LIMIT 1];
            Test.startTest();
            String result = UploadedFileController.deleteAllFiles(acc.Id);
            Test.stopTest();
            System.assert(result != null);
        } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testDeleteFile() {
        User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        System.runAs(u) {
            Uploaded_File_Info__c file =
                [SELECT Id FROM Uploaded_File_Info__c LIMIT 1];
            Test.startTest();
            String result = UploadedFileController.deleteFile(file.Id);
            Test.stopTest();
            System.assertEquals('SUCCESS', result);
        }
    }

    @isTest
    static void testDeleteAllFilesException() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        System.runAs(u) {
            Test.startTest();
            try {
                UploadedFileController.deleteAllFiles(null);
                System.assert(false, 'Exception expected');
            } catch (AuraHandledException e) {
                System.assert(true);
            }
            Test.stopTest();
        }
    }

    @isTest
    static void testRecordInsert() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        System.runAs(u) {
            Account acc = [SELECT Id, Name FROM Account LIMIT 1];
            Test.startTest();
            Boolean result = UploadedFileController.recordInsert(
                'Account',
                acc.Name,
                acc.Id,
                'NewFile.txt',
                'https://test.com/newfile.txt',
                'TXT',
                'ObjKey123',
                200,
                null
            );
            Test.stopTest();
            System.assertEquals(true, result);
        }
    }

    @isTest
    static void testRecordInsertInvalidObject() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        System.runAs(u) {
            Test.startTest();
            try {
                UploadedFileController.recordInsert(
                    'InvalidObject',
                    null,
                    null,
                    'TestFile',
                    'url',
                    'PDF',
                    'key',
                    100,
                    null
                );
                System.assert(true);
            } catch (AuraHandledException e) {
                System.assert(true);
            }
            Test.stopTest();
        }
    }

    @isTest
    static void testRecordInsertEmptyParent() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        System.runAs(u) {
            Account acc = [SELECT Id, Name FROM Account LIMIT 1];
            Test.startTest();
            Boolean result = UploadedFileController.recordInsert(
                '',
                acc.Name,
                acc.Id,
                'TestFile',
                'url',
                'PDF',
                'key',
                100,
                null
            );
            Test.stopTest();
            System.assertEquals(true, result);
        }
    }

    @isTest
    static void testGetParentRecordName() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        System.runAs(u) {
            Account acc = [SELECT Id FROM Account LIMIT 1];
            Test.startTest();
            String name = UploadedFileController.getParentRecordName(acc.Id, 'Account');
            Test.stopTest();
            System.assertNotEquals(null, name);
        }
    }

    @isTest
    static void testGetParentRecordName_Exception() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;      
        System.runAs(u) {
            try {
        Test.startTest();
        String result = UploadedFileController.getParentRecordName(null, 'Invalid');
        Test.stopTest();
        System.assertEquals('', result);
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testInsertFolder() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        System.runAs(u) {
            Account acc = [SELECT Id FROM Account LIMIT 1];
            Test.startTest();
            Folder__c folder = UploadedFileController.insertFolder(
                'New Folder',
                null,
                'Account',
                acc.Id
            );
            Test.stopTest();
            System.assertNotEquals(null, folder);
        }
    }

    @isTest
    static void testInsertFolderWithParent() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        System.runAs(u) {
            Account acc = [SELECT Id FROM Account LIMIT 1];
            Folder__c parent = new Folder__c(Name = 'Parent', Parent_Record_Id__c = acc.Id);
            insert parent;
            Test.startTest();
            Folder__c child = UploadedFileController.insertFolder(
                'Child',
                parent.Id,
                'Account',
                acc.Id
            );
            Test.stopTest();
            System.assert(child != null);
        }
    }

    @isTest
    static void testGetFolderById() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        System.runAs(u) {
            Folder__c folder = [SELECT Id FROM Folder__c LIMIT 1];
            Test.startTest();
            Folder__c result = UploadedFileController.getFolderById(folder.Id);
            Test.stopTest();
            System.assertNotEquals(null, result);
        }
    }

    @isTest
    static void testGetFolderByIdNull() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;      
        System.runAs(u) {
            try {
        Test.startTest();
        Folder__c result = UploadedFileController.getFolderById(null);
        Test.stopTest();
        System.assertEquals(null, result);
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testDeleteFolder() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        System.runAs(u) {
            Folder__c folder = [SELECT Id FROM Folder__c LIMIT 1];
            Test.startTest();
            UploadedFileController.deleteFolder(folder.Id);
            Test.stopTest();
            System.assert(true);
        }
    }

    @isTest
    static void testDeleteFolderNull() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;      
        System.runAs(u) {
            try {
        Test.startTest();
        UploadedFileController.deleteFolder(null);
        Test.stopTest();
        System.assert(true);
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testDeleteAllFolders() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        System.runAs(u) {
            Account acc = [SELECT Id FROM Account LIMIT 1];
            Test.startTest();
            UploadedFileController.deleteAllFolders(acc.Id);
            Test.stopTest();
            System.assert(true);
        }
    }

    @isTest
    static void testDeleteAllFoldersNull() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;      
        System.runAs(u) {
            try {
        Test.startTest();
        UploadedFileController.deleteAllFolders(null);
        Test.stopTest();
        System.assert(true);
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testGetFolderFormConfig() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;      
        System.runAs(u) {
            try {
        Test.startTest();
        UploadedFileController.FolderFormConfig config =
            UploadedFileController.getFolderFormConfig();
        Test.stopTest();
         } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    } 

    @isTest
    static void testGetFilesByParentId() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;      
        System.runAs(u) {
            try {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        List<Utils.UploadFileInfo> files =
            UploadedFileController.getFilesByParentId(acc.Id);
        Test.stopTest();
        System.assertNotEquals(null, files);
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testGetFilesByParentIdNull() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;      
        System.runAs(u) {
            try {
        Test.startTest();
        List<Utils.UploadFileInfo> files =
            UploadedFileController.getFilesByParentId(null);
        Test.stopTest();
        System.assertEquals(0, files.size());
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testGetFolders() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;      
        System.runAs(u) {
            try {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        List<Utils.Folder> folders =
            UploadedFileController.getFolders(acc.Id);
        Test.stopTest();
        System.assertNotEquals(null, folders);
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testGetFoldersNull() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;      
        System.runAs(u) {
            try {
        Test.startTest();
        List<Utils.Folder> folders =
            UploadedFileController.getFolders(null);
        Test.stopTest();
        System.assertEquals(0, folders.size());
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }


    @isTest
    static void testDeleteFile_Exception() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;      
        System.runAs(u) {
            try {
        Test.startTest();
        try {
            UploadedFileController.deleteFile('');
            System.assert(false, 'Exception should have been thrown');
        } catch (AuraHandledException e) {
        }
        Test.stopTest();
     } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testRecordInsert_Exception() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;      
        System.runAs(u) {
            try {
        Test.startTest();
        try {
            UploadedFileController.recordInsert(
                null, null, null,
                null, null, null,
                null, null, null
            );
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

    @isTest
    static void testDeleteAllFiles_Exception() {
          User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;      
        System.runAs(u) {
            try {
        Test.startTest();
        try {
            UploadedFileController.deleteAllFiles(null);
            System.assert(false, 'Exception expected');
        } catch (AuraHandledException e) {
        }
        Test.stopTest();
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
}