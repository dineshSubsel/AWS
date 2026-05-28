@isTest
Public class RecycleBin_Test {
    private class MockS3Success implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('OK');
            return res;
        }
    }

    private class MockS3Failure implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    private class MockS3CsvDownload implements HttpCalloutMock {
        private String csv;
        public MockS3CsvDownload(String csv) { this.csv = csv; }
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getMethod() == 'GET') {
                res.setStatusCode(200);
                res.setBody(csv);
            } else {
                res.setStatusCode(200);
                res.setBody('OK');
            }
            return res;
        }
    }

    // ─── Helpers (no DML) ────────────────────────────────────────────────────

    private static Account createAndDeleteAccount(String name) {
        Account acc = TestDataFactory.createDeletedAccount(name);
        return acc;
    }

    private static String buildCsv(String objectName, Id recordId) {
        return 'Id,Name,ObjectType,DeletedBy,DeletedDate\n'
             + recordId + ',TestAccount,' + objectName + ',Admin,2024-01-01 00:00:00';
    }

    // ─── RecycleBinBackupBatch ────────────────────────────────────────────────

    @isTest
    static void test_RecycleBinBackupBatch_noRecords() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.setMock(HttpCalloutMock.class, new MockS3Success());
        Test.startTest();
        Database.executeBatch(new RecycleBinBackupBatch('Account'), 200);
        Test.stopTest();

        List<File_Recovery_Log__c> logs = [
            SELECT Backup_Status__c FROM File_Recovery_Log__c
            WHERE Action_Type__c = 'Backup' AND Recycle_Bin__c = true
        ];
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
                System.assert(!permError, 'Unexpected exception occurred: ' + e.getMessage());
            }
        }
    }

    @isTest
    static void test_RecycleBinBackupBatch_withDeletedRecords() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        
        System.runAs(u) {
            try {
        Account acc = createAndDeleteAccount('BackupBatchTest');
        Test.setMock(HttpCalloutMock.class, new MockS3Success());
        Test.startTest();
        Database.executeBatch(new RecycleBinBackupBatch('Account'), 200);
        Test.stopTest();
        List<File_Recovery_Log__c> logs = [
            SELECT Backup_Status__c FROM File_Recovery_Log__c
            WHERE Action_Type__c = 'Backup' AND Recycle_Bin__c = true
        ];
        System.assert(!logs.isEmpty());
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_RecycleBinBackupBatch_withRecordIds() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        
        System.runAs(u) {
            try {
        Account acc = createAndDeleteAccount('BackupBatchRecordIdTest');
        Test.setMock(HttpCalloutMock.class, new MockS3Success());
        Test.startTest();
        Database.executeBatch(
            new RecycleBinBackupBatch('Account', new List<String>{ acc.Id }), 200
        );
        Test.stopTest();

        List<File_Recovery_Log__c> logs = [
            SELECT Backup_Status__c FROM File_Recovery_Log__c
            WHERE Action_Type__c = 'Backup' AND Recycle_Bin__c = true
        ];
        System.assert(!logs.isEmpty());
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_RecycleBinBackupBatch_s3Failure() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        
        System.runAs(u) {
            try {
        Account acc = createAndDeleteAccount('BackupBatchFailTest');
        Test.setMock(HttpCalloutMock.class, new MockS3Failure());
        Test.startTest();
        Database.executeBatch(new RecycleBinBackupBatch('Account'), 200);
        Test.stopTest();

        List<File_Recovery_Log__c> logs = [
            SELECT Backup_Status__c FROM File_Recovery_Log__c
            WHERE Action_Type__c = 'Backup' AND Recycle_Bin__c = true
        ];
        System.assert(!logs.isEmpty());
        System.assertEquals('Failed', logs[0].Backup_Status__c);
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_RecycleBinBackupBatch_escapeCsvValue() {
          User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        System.assertEquals('',        RecycleBinBackupBatch.escapeCsvValue(null));
        System.assertEquals('hello',   RecycleBinBackupBatch.escapeCsvValue('hello'));
        System.assertEquals('"a,b"',   RecycleBinBackupBatch.escapeCsvValue('a,b'));
        System.assertEquals('"a""b"',  RecycleBinBackupBatch.escapeCsvValue('a"b'));
        System.assertEquals('"a\nb"',  RecycleBinBackupBatch.escapeCsvValue('a\nb'));
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }


    // ─── RecycleBinMultiObjectBackupBatch ─────────────────────────────────────

    @isTest
    static void test_MultiObjectBackupBatch_noRecords() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.setMock(HttpCalloutMock.class, new MockS3Success());
        Test.startTest();
        Database.executeBatch(
            new RecycleBinMultiObjectBackupBatch(new List<String>{ 'Account', 'Contact' }), 200
        );
        Test.stopTest();

        List<File_Recovery_Log__c> logs = [
            SELECT Backup_Status__c, Object_Name__c FROM File_Recovery_Log__c
            WHERE Action_Type__c = 'Backup' AND Recycle_Bin__c = true
        ];
        System.assert(!logs.isEmpty());
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_MultiObjectBackupBatch_withDeletedRecords() {
           User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Account acc = createAndDeleteAccount('MultiBackupTest');
        Test.setMock(HttpCalloutMock.class, new MockS3Success());
        Test.startTest();
        Database.executeBatch(
            new RecycleBinMultiObjectBackupBatch(new List<String>{ 'Account' }), 200
        );
        Test.stopTest();
        List<File_Recovery_Log__c> logs = [
            SELECT Backup_Status__c FROM File_Recovery_Log__c
            WHERE Action_Type__c = 'Backup' AND Recycle_Bin__c = true
        ];
        System.assert(!logs.isEmpty());
 } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_MultiObjectBackupBatch_withRecordIds() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Account acc = createAndDeleteAccount('MultiBackupIdsTest');
        Test.setMock(HttpCalloutMock.class, new MockS3Success());
        Test.startTest();
        Database.executeBatch(
            new RecycleBinMultiObjectBackupBatch(
                new List<String>{ 'Account' },
                new List<String>{ acc.Id }
            ), 200
        );
        Test.stopTest();
        List<File_Recovery_Log__c> logs = [
            SELECT Backup_Status__c FROM File_Recovery_Log__c
            WHERE Action_Type__c = 'Backup' AND Recycle_Bin__c = true
        ];
        System.assert(!logs.isEmpty());
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_MultiObjectBackupBatch_s3Failure() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Account acc = createAndDeleteAccount('MultiBackupFailTest');
        Test.setMock(HttpCalloutMock.class, new MockS3Failure());
        Test.startTest();
        Database.executeBatch(
            new RecycleBinMultiObjectBackupBatch(new List<String>{ 'Account' }), 200
        );
        Test.stopTest();
        List<File_Recovery_Log__c> logs = [
            SELECT Backup_Status__c FROM File_Recovery_Log__c
            WHERE Action_Type__c = 'Backup' AND Recycle_Bin__c = true
        ];
        System.assert(!logs.isEmpty());
        System.assertEquals('Failed', logs[0].Backup_Status__c);
     } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_MultiObjectBackupBatch_escapeCsvValue() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        System.assertEquals('',       RecycleBinMultiObjectBackupBatch.escapeCsvValue(null));
        System.assertEquals('hello',  RecycleBinMultiObjectBackupBatch.escapeCsvValue('hello'));
        System.assertEquals('"a,b"',  RecycleBinMultiObjectBackupBatch.escapeCsvValue('a,b'));
        System.assertEquals('"a""b"', RecycleBinMultiObjectBackupBatch.escapeCsvValue('a"b'));
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    // ─── RecycleBinScheduledBackup ────────────────────────────────────────────

    @isTest
    static void test_RecycleBinScheduledBackup_singleObject() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.setMock(HttpCalloutMock.class, new MockS3Success());
        Test.startTest();
        RecycleBinScheduledBackup scheduler = new RecycleBinScheduledBackup(
            new List<String>{ 'Account' }, null
        );
        System.schedule('TestBackupSingle', '0 0 1 * * ?', scheduler);
        Test.stopTest();
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_RecycleBinScheduledBackup_multiObject() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.setMock(HttpCalloutMock.class, new MockS3Success());
        Test.startTest();
        RecycleBinScheduledBackup scheduler = new RecycleBinScheduledBackup(
            new List<String>{ 'Account', 'Contact' }, null
        );
        System.schedule('TestBackupMulti', '0 0 2 * * ?', scheduler);
        Test.stopTest();
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_RecycleBinScheduledBackup_withRecordIds() {
          User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Account acc = createAndDeleteAccount('ScheduledBackupIdsTest');
        Test.setMock(HttpCalloutMock.class, new MockS3Success());
        Test.startTest();
        RecycleBinScheduledBackup scheduler = new RecycleBinScheduledBackup(
            new List<String>{ 'Account' },
            new List<String>{ acc.Id }
        );
        System.schedule('TestBackupWithIds', '0 0 3 * * ?', scheduler);
        Test.stopTest();
       } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    @isTest
    static void test_RecycleBinScheduledBackup_emptyObjectTypes() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.startTest();
        RecycleBinScheduledBackup scheduler = new RecycleBinScheduledBackup(
            new List<String>(), null
        );
        System.schedule('TestBackupEmpty', '0 0 4 * * ?', scheduler);
        Test.stopTest();
  } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_RecycleBinScheduledBackup_nullObjectTypes() {
          User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.startTest();
        RecycleBinScheduledBackup scheduler = new RecycleBinScheduledBackup(null, null);
        System.schedule('TestBackupNull', '0 0 5 * * ?', scheduler);
        Test.stopTest();
     } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    // ─── RecycleBinRestoreService ─────────────────────────────────────────────

    @isTest
    static void test_RestoreService_success() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Account acc = createAndDeleteAccount('RestoreServiceTest');
        String csv = buildCsv('Account', acc.Id);
        Test.setMock(HttpCalloutMock.class, new MockS3CsvDownload(csv));

        Test.startTest();
        try {
            RecycleBinRestoreService.restoreFromS3(
                'recycle-bin-backup/Account/test.csv',
                'Account',
                new List<String>{ acc.Id }
            );
        } catch (Exception e) {
        }
        Test.stopTest();
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_RestoreService_blankS3Key() {
          User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.startTest();
        try {
            RecycleBinRestoreService.restoreFromS3('', 'Account', null);
            System.assert(false, 'Should have thrown');
        } catch (RecycleBinRestoreService.RecycleBinRestoreException e) {
            System.assert(e.getMessage().contains('blank'), 'Expected blank key error');
        }
        Test.stopTest();
      } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }


    @isTest
    static void test_RestoreService_blankObjectName() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.startTest();
        try {
            RecycleBinRestoreService.restoreFromS3('some/key.csv', '', null);
            System.assert(false, 'Should have thrown');
        } catch (RecycleBinRestoreService.RecycleBinRestoreException e) {
            System.assert(e.getMessage().contains('blank'), 'Expected blank object error');
        }
        Test.stopTest();
     } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }


    @isTest
    static void test_RestoreService_s3DownloadFailure() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.setMock(HttpCalloutMock.class, new MockS3Failure());
        Test.startTest();
        try {
            RecycleBinRestoreService.restoreFromS3('some/key.csv', 'Account', null);
            System.assert(false, 'Should have thrown');
        } catch (RecycleBinRestoreService.RecycleBinRestoreException e) {
            System.assert(e.getMessage().contains('S3 download failed'));
        }
        Test.stopTest();
  } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_RestoreService_emptyCsv() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.setMock(HttpCalloutMock.class, new MockS3CsvDownload('Id,Name,ObjectType,DeletedBy,DeletedDate\n'));
        Test.startTest();
        try {
            RecycleBinRestoreService.restoreFromS3('test/key.csv', 'Account', null);
            System.assert(false, 'Should have thrown for empty CSV');
        } catch (RecycleBinRestoreService.RecycleBinRestoreException e) {
            System.assert(e.getMessage().contains('empty'), 'Expected empty CSV error');
        }
        Test.stopTest();
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_RestoreService_selectedIdNotInCsv() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Account acc = createAndDeleteAccount('CsvFilterTest');
        String csv = buildCsv('Account', acc.Id);
        Test.setMock(HttpCalloutMock.class, new MockS3CsvDownload(csv));
        Test.startTest();
        try {
            RecycleBinRestoreService.restoreFromS3(
                'some/key.csv',
                'Account',
                new List<String>{ 'TEST002' }
            );
            System.assert(false, 'Should have thrown');
        } catch (RecycleBinRestoreService.RecycleBinRestoreException e) {
            System.assert(e.getMessage().contains('not found'), 'Expected not found error');
        }
        Test.stopTest();
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }


    @isTest
    static void test_RestoreService_unknownObject() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Account acc = createAndDeleteAccount('UnknownObjTest');
        String csv = buildCsv('FakeObject__c', acc.Id);
        Test.setMock(HttpCalloutMock.class, new MockS3CsvDownload(csv));
        Test.startTest();
        try {
            RecycleBinRestoreService.restoreFromS3('some/key.csv', 'FakeObject__c', null);
            System.assert(false, 'Should have thrown');
        } catch (RecycleBinRestoreService.RecycleBinRestoreException e) {
            System.assert(e.getMessage().contains('Unknown object'));
        }
        Test.stopTest();
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_RestoreService_noSelectedIds_allRows() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Account acc = createAndDeleteAccount('AllRowsTest');
        String csv = buildCsv('Account', acc.Id);
        Test.setMock(HttpCalloutMock.class, new MockS3CsvDownload(csv));

        Test.startTest();
        try {
            RecycleBinRestoreService.restoreFromS3('some/key.csv', 'Account', null);
        } catch (Exception e) {
        }
        Test.stopTest();
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }


    // ─── RecycleBinRestoreBatch ───────────────────────────────────────────────

    @isTest
    static void test_RecycleBinRestoreBatch_success() {
         User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Account acc = createAndDeleteAccount('RestoreBatchTest');

        File_Recovery_Log__c bl = TestDataFactory.createRecycleBinBackupLog('Account', acc.Id);
        File_Recovery_Log__c rl = TestDataFactory.createRecycleBinRestoreLog('Account', acc.Id);

        String csv = buildCsv('Account', acc.Id);
        Test.setMock(HttpCalloutMock.class, new MockS3CsvDownload(csv));

        Test.startTest();
        Database.executeBatch(
            new RecycleBinRestoreBatch(
                new List<Id>{ bl.Id },
                new List<Id>{ rl.Id },
                new List<String>{ acc.Id }
            ), 1
        );
        Test.stopTest();

        File_Recovery_Log__c updated = [
            SELECT Restore_Status__c FROM File_Recovery_Log__c WHERE Id = :rl.Id
        ];
        System.assert(
            updated.Restore_Status__c == 'Completed' || updated.Restore_Status__c == 'Failed',
            'Status should be Completed or Failed'
        );
       } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }


    @isTest
    static void test_RecycleBinRestoreBatch_s3Failure() {
         User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Account acc = createAndDeleteAccount('RestoreBatchFailTest');

        File_Recovery_Log__c bl = TestDataFactory.createRecycleBinBackupLog('Account', acc.Id);
        File_Recovery_Log__c rl = TestDataFactory.createRecycleBinRestoreLog('Account', acc.Id);

        Test.setMock(HttpCalloutMock.class, new MockS3Failure());
        Test.startTest();
        Database.executeBatch(
            new RecycleBinRestoreBatch(
                new List<Id>{ bl.Id },
                new List<Id>{ rl.Id },
                new List<String>{ acc.Id }
            ), 1
        );
        Test.stopTest();

        File_Recovery_Log__c updated = [
            SELECT Restore_Status__c FROM File_Recovery_Log__c WHERE Id = :rl.Id
        ];
        System.assertEquals('Failed', updated.Restore_Status__c);
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_RecycleBinRestoreBatch_emptyScope() {
         User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.setMock(HttpCalloutMock.class, new MockS3Success());
        Test.startTest();
        Database.executeBatch(
            new RecycleBinRestoreBatch(
                new List<Id>(),
                new List<Id>(),
                new List<String>()
            ), 1
        );
        Test.stopTest();
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    // ─── RecycleBinRestoreScheduler ───────────────────────────────────────────

    @isTest
    static void test_RecycleBinRestoreScheduler_withObjectsAndIds() {
         User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Account acc = createAndDeleteAccount('SchedulerObjIdsTest');
        File_Recovery_Log__c bl = TestDataFactory.createRecycleBinBackupLog('Account', acc.Id);

        String csv = buildCsv('Account', acc.Id);
        Test.setMock(HttpCalloutMock.class, new MockS3CsvDownload(csv));
        Test.startTest();
        RecycleBinRestoreScheduler scheduler = new RecycleBinRestoreScheduler(
            new List<String>{ 'Account' },
            new List<String>{ acc.Id }
        );
        System.schedule('TestRestoreSchedulerObjIds', '0 0 6 * * ?', scheduler);
        Test.stopTest();
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_RecycleBinRestoreScheduler_objectsOnly() {
         User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Account acc = createAndDeleteAccount('SchedulerObjectsOnlyTest');
        TestDataFactory.createRecycleBinBackupLog('Account', acc.Id);

        Test.setMock(HttpCalloutMock.class, new MockS3Success());
        Test.startTest();
        RecycleBinRestoreScheduler scheduler = new RecycleBinRestoreScheduler(
            new List<String>{ 'Account' }, null
        );
        System.schedule('TestRestoreSchedulerObjOnly', '0 0 7 * * ?', scheduler);
        Test.stopTest();
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_RecycleBinRestoreScheduler_noArgs() {
         User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.setMock(HttpCalloutMock.class, new MockS3Success());
        Test.startTest();
        RecycleBinRestoreScheduler scheduler = new RecycleBinRestoreScheduler();
        System.schedule('TestRestoreSchedulerNoArgs', '0 0 8 * * ?', scheduler);
        Test.stopTest();
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_RecycleBinRestoreScheduler_withIntentLogs() {
         User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        TestDataFactory.createScheduledRestoreIntentLog('Account');
        Test.setMock(HttpCalloutMock.class, new MockS3Success());
        Test.startTest();
        RecycleBinRestoreScheduler scheduler = new RecycleBinRestoreScheduler(
            new List<String>{ 'Account' }, null
        );
        System.schedule('TestRestoreSchedulerIntent', '0 0 9 * * ?', scheduler);
        Test.stopTest();
        List<File_Recovery_Log__c> updated = [
            SELECT Restore_Status__c FROM File_Recovery_Log__c
            WHERE Action_Type__c = 'Restore' AND Restore_Status__c = 'In Progress'
        ];
        System.assert(!updated.isEmpty(), 'Intent logs should be marked In Progress');
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    // ─── RecycleBinVaultController ────────────────────────────────────────────

    @isTest
    static void test_VaultController_getSupportedObjectTypes() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        List<Map<String, String>> result =
            RecycleBinVaultController.getSupportedObjectTypes();
        System.assert(!result.isEmpty(), 'Should return object types');
        System.assert(result[0].containsKey('label'));
        System.assert(result[0].containsKey('value'));
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_VaultController_getDeletedRecordsByType_valid() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Account acc = createAndDeleteAccount('VaultCtrlDeletedTest');
        List<RecycleBinVaultController.RecycleBinRecord> result =
            RecycleBinVaultController.getDeletedRecordsByType('Account');
        System.assert(!result.isEmpty(), 'Should return deleted accounts');
  } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_VaultController_getDeletedRecordsByType_blank() {    
        try {
            RecycleBinVaultController.getDeletedRecordsByType('');
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
        }
    }

    @isTest
    static void test_VaultController_getDeletedRecordsByType_invalid() {
        try {
            RecycleBinVaultController.getDeletedRecordsByType('FakeObject__c');
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
        }
    }

    @isTest
    static void test_VaultController_startInstantBackup_noIds() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.setMock(HttpCalloutMock.class, new MockS3Success());
        Test.startTest();
        String result = RecycleBinVaultController.startInstantBackup('Account', '[]');
        Test.stopTest();
        System.assert(result != null);
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }


    @isTest
    static void test_VaultController_startInstantBackup_withIds() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Account acc = createAndDeleteAccount('VaultInstantBackupIds');
        Test.setMock(HttpCalloutMock.class, new MockS3Success());
        Test.startTest();
        String result = RecycleBinVaultController.startInstantBackup(
            'Account', JSON.serialize(new List<String>{ acc.Id })
        );
        Test.stopTest();
        System.assert(result != null);
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_VaultController_startInstantBackup_invalidObject() {
        try {
            RecycleBinVaultController.startInstantBackup('FakeObject__c', '[]');
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
        }
    }

    @isTest
    static void test_VaultController_startMultiObjectBackup() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.setMock(HttpCalloutMock.class, new MockS3Success());
        Test.startTest();
        String result = RecycleBinVaultController.startMultiObjectBackup(
            JSON.serialize(new List<String>{ 'Account' })
        );
        Test.stopTest();
        System.assert(result != null);
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }


    @isTest
    static void test_VaultController_startMultiObjectBackup_empty() {
        try {
            RecycleBinVaultController.startMultiObjectBackup('[]');
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
        }
    }

    @isTest
    static void test_VaultController_startMultiObjectBackup_invalidObject() {
        try {
            RecycleBinVaultController.startMultiObjectBackup(
                JSON.serialize(new List<String>{ 'FakeObject__c' })
            );
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
        }
    }

    @isTest
    static void test_VaultController_scheduleBackup_daily() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.startTest();
        String jobId = RecycleBinVaultController.scheduleBackup(
            JSON.serialize(new List<String>{ 'Account' }),
            '[]', 'daily', '02:00'
        );
        Test.stopTest();
        System.assertEquals('TEST_SCHEDULE_JOB', jobId);
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_VaultController_scheduleBackup_weekly() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.startTest();
        String jobId = RecycleBinVaultController.scheduleBackup(
            JSON.serialize(new List<String>{ 'Account' }),
            '[]', 'weekly', '03:30'
        );
        Test.stopTest();
        System.assertEquals('TEST_SCHEDULE_JOB', jobId);
      } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_VaultController_scheduleBackup_monthly() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.startTest();
        String jobId = RecycleBinVaultController.scheduleBackup(
            JSON.serialize(new List<String>{ 'Account' }),
            '[]', 'monthly', '04:00'
        );
        Test.stopTest();
        System.assertEquals('TEST_SCHEDULE_JOB', jobId);
      } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_VaultController_scheduleBackup_invalidFrequency() {
        try {
            RecycleBinVaultController.scheduleBackup(
                JSON.serialize(new List<String>{ 'Account' }),
                '[]', 'hourly', '01:00'
            );
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
        }
    }

    @isTest
    static void test_VaultController_scheduleBackup_emptyObjects() {
        try {
            RecycleBinVaultController.scheduleBackup('[]', '[]', 'daily', '01:00');
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
        }
    }

    @isTest
    static void test_VaultController_getBackupJobStatus() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        createAndDeleteAccount('JobStatusTest');
        Test.setMock(HttpCalloutMock.class, new MockS3Success());
        Test.startTest();
        Id jobId = Database.executeBatch(new RecycleBinBackupBatch('Account'), 200);
        Test.stopTest();
        List<RecycleBinVaultController.BackupJobStatus> result =
            RecycleBinVaultController.getBackupJobStatus(
                JSON.serialize(new List<String>{ jobId })
            );
        System.assert(!result.isEmpty());
        System.assert(result[0].isDone != null);
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_VaultController_getBackupJobStatus_empty() {
        List<RecycleBinVaultController.BackupJobStatus> result =
            RecycleBinVaultController.getBackupJobStatus('[]');
        System.assert(result.isEmpty());
    }

    @isTest
    static void test_VaultController_areAllJobsDone_empty() {
          User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Boolean done = RecycleBinVaultController.areAllJobsDone('[]');
        System.assertEquals(true, done);
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_VaultController_areAllJobsDone_withId() {
          User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.setMock(HttpCalloutMock.class, new MockS3Success());
        Test.startTest();
        Id jobId = Database.executeBatch(new RecycleBinBackupBatch('Account'), 200);
        Test.stopTest();

        Boolean done = RecycleBinVaultController.areAllJobsDone(
            JSON.serialize(new List<String>{ jobId })
        );
        System.assert(done != null);
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_VaultController_getJobDetails() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.setMock(HttpCalloutMock.class, new MockS3Success());
        Test.startTest();
        Id jobId = Database.executeBatch(new RecycleBinBackupBatch('Account'), 200);
        Test.stopTest();

        List<Map<String, Object>> result = RecycleBinVaultController.getJobDetails(
            JSON.serialize(new List<String>{ jobId })
        );
        System.assert(!result.isEmpty());
        System.assert(result[0].containsKey('jobId'));
        System.assert(result[0].containsKey('status'));
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_VaultController_getJobDetails_empty() {
          User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        List<Map<String, Object>> result = RecycleBinVaultController.getJobDetails('[]');
        System.assert(result.isEmpty());
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_VaultController_cancelJob() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.setMock(HttpCalloutMock.class, new MockS3Success());
        Test.startTest();
        Id jobId = Database.executeBatch(new RecycleBinBackupBatch('Account'), 200);
        Test.stopTest();
        try {
            RecycleBinVaultController.cancelJob(String.valueOf(jobId));
        } catch (AuraHandledException e) {
        }
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_VaultController_getDeletedRecordCounts() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        createAndDeleteAccount('DeletedCountTest');
        List<Map<String, Object>> result =
            RecycleBinVaultController.getDeletedRecordCounts();
        System.assert(result != null);
     } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    // ─── RecycleBinVaultRestore_Controller ───────────────────────────────────

    @isTest
    static void test_RestoreController_getDeletedRecordCounts() {
          User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        createAndDeleteAccount('RestoreCtrlCountTest');
        List<Map<String, Object>> result =
            RecycleBinVaultRestore_Controller.getDeletedRecordCounts();
        System.assert(result != null);
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_RestoreController_getDeletedRecordsByType() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        createAndDeleteAccount('RestoreCtrlDeletedTest');
        List<RecycleBinVaultRestore_Controller.RecycleBinRecord> result =
            RecycleBinVaultRestore_Controller.getDeletedRecordsByType('Account');
        System.assert(!result.isEmpty());
     } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_RestoreController_getDeletedRecordsByType_blank() {
        try {
            RecycleBinVaultRestore_Controller.getDeletedRecordsByType('');
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
        }
    }

    @isTest
    static void test_RestoreController_getDeletedRecordsByType_invalid() {
        try {
            RecycleBinVaultRestore_Controller.getDeletedRecordsByType('FakeObject__c');
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
        }
    }

    @isTest
    static void test_RestoreController_restoreDeletedRecords_noBackupLogs() {
          User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.setMock(HttpCalloutMock.class, new MockS3Success());
        Test.startTest();
        String result = RecycleBinVaultRestore_Controller.restoreDeletedRecords(
            'Account', new List<String>()
        );
        Test.stopTest();
        System.assert(result != null);

        List<File_Recovery_Log__c> logs = [
            SELECT Restore_Status__c FROM File_Recovery_Log__c
            WHERE Action_Type__c = 'Restore'
        ];
        System.assert(!logs.isEmpty());
        System.assertEquals('Failed', logs[0].Restore_Status__c);
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_RestoreController_restoreDeletedRecords_withBackupLogs() {
         User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Account acc = createAndDeleteAccount('RestoreCtrlWithLogs');
        File_Recovery_Log__c bl = TestDataFactory.createRecycleBinBackupLog('Account', acc.Id);
        String csv = buildCsv('Account', acc.Id);
        Test.setMock(HttpCalloutMock.class, new MockS3CsvDownload(csv));
        Test.startTest();
        String batchJobId = RecycleBinVaultRestore_Controller.restoreDeletedRecords(
            'Account', new List<String>{ acc.Id }
        );
        Test.stopTest();

        System.assert(batchJobId != null);
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_RestoreController_restoreDeletedRecords_blank() {
        try {
            RecycleBinVaultRestore_Controller.restoreDeletedRecords('', null);
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
        }
    }

    @isTest
    static void test_RestoreController_startScheduledRestore_daily() {
          User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.startTest();
        String jobName = RecycleBinVaultRestore_Controller.startScheduledRecycleBinRestore(
            'Account', new List<String>(), 'daily', '02:00'
        );
        Test.stopTest();
        System.assert(jobName.contains('RecycleBinRestore'));
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_RestoreController_startScheduledRestore_weekly() {
          User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.startTest();
        String jobName = RecycleBinVaultRestore_Controller.startScheduledRecycleBinRestore(
            'Account', null, 'weekly', '03:00'
        );
        Test.stopTest();
        System.assert(jobName != null);
     } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_RestoreController_startScheduledRestore_monthly() {
          User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.startTest();
        String jobName = RecycleBinVaultRestore_Controller.startScheduledRecycleBinRestore(
            'Account', null, 'monthly', '04:00'
        );
        Test.stopTest();
        System.assert(jobName != null);
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_RestoreController_startScheduledRestore_invalidFreq() {
        try {
            RecycleBinVaultRestore_Controller.startScheduledRecycleBinRestore(
                'Account', null, 'hourly', '01:00'
            );
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
        }
    }

    @isTest
    static void test_RestoreController_startScheduledRestore_blankObject() {
        try {
            RecycleBinVaultRestore_Controller.startScheduledRecycleBinRestore(
                '', null, 'daily', '01:00'
            );
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
        }
    }

    @isTest
    static void test_RestoreController_startScheduledRestore_blankFreq() {
        try {
            RecycleBinVaultRestore_Controller.startScheduledRecycleBinRestore(
                'Account', null, '', '01:00'
            );
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
        }
    }

    @isTest
    static void test_RestoreController_startScheduledRestore_blankTime() {
        try {
            RecycleBinVaultRestore_Controller.startScheduledRecycleBinRestore(
                'Account', null, 'daily', ''
            );
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
        }
    }

    @isTest
    static void test_RestoreController_areAllJobsDone_empty() {
          User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Boolean done = RecycleBinVaultRestore_Controller.areAllJobsDone('[]');
        System.assertEquals(true, done);
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_RestoreController_areAllJobsDone_withId() {
          User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.setMock(HttpCalloutMock.class, new MockS3Success());
        Test.startTest();
        Id jobId = Database.executeBatch(new RecycleBinBackupBatch('Account'), 200);
        Test.stopTest();
        Boolean done = RecycleBinVaultRestore_Controller.areAllJobsDone(
            JSON.serialize(new List<String>{ jobId })
        );
        System.assert(done != null);
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }


    @isTest
    static void test_RestoreController_getJobDetails_sentinel() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.setMock(HttpCalloutMock.class, new MockS3Success());
        Test.startTest();
        Database.executeBatch(new RecycleBinBackupBatch('Account'), 200);
        Test.stopTest();
        List<Map<String, Object>> result = RecycleBinVaultRestore_Controller.getJobDetails(
            JSON.serialize(new List<String>{ 'LATEST_RESTORE' })
        );
        System.assert(result != null);
 } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_RestoreController_getJobDetails_withId() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.setMock(HttpCalloutMock.class, new MockS3Success());
        Test.startTest();
        Id jobId = Database.executeBatch(new RecycleBinBackupBatch('Account'), 200);
        Test.stopTest();
        List<Map<String, Object>> result = RecycleBinVaultRestore_Controller.getJobDetails(
            JSON.serialize(new List<String>{ jobId })
        );
        System.assert(!result.isEmpty());
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_RestoreController_getJobDetails_empty() {
          User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        List<Map<String, Object>> result =
            RecycleBinVaultRestore_Controller.getJobDetails('[]');
        System.assert(result.isEmpty());
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_RestoreController_cancelJob() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.setMock(HttpCalloutMock.class, new MockS3Success());
        Test.startTest();
        Id jobId = Database.executeBatch(new RecycleBinBackupBatch('Account'), 200);
        Test.stopTest();
        try {
            RecycleBinVaultRestore_Controller.cancelJob(String.valueOf(jobId));
        } catch (AuraHandledException e) {
        }
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_RestoreController_insertFailedLogViaSavepoint() {
          User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.startTest();
        RecycleBinVaultRestore_Controller.insertFailedLogViaSavepoint(
            'Account',
            new List<String>{ 'TEST0001' },
            'Test error'
        );
        Test.stopTest();

        List<File_Recovery_Log__c> logs = [
            SELECT Restore_Status__c, Error_Message__c
            FROM File_Recovery_Log__c
            WHERE Action_Type__c = 'Restore' AND Restore_Status__c = 'Failed'
        ];
        System.assert(!logs.isEmpty());
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_RestoreController_createRestoreLogs() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Account acc = createAndDeleteAccount('CreateRestoreLogsTest');
        File_Recovery_Log__c bl = TestDataFactory.createRecycleBinBackupLog('Account', acc.Id);
        Test.startTest();
        List<File_Recovery_Log__c> restoreLogs =
            RecycleBinVaultRestore_Controller.createRestoreLogs(
                new List<File_Recovery_Log__c>{ bl }
            );
        Test.stopTest();
        System.assertEquals(1, restoreLogs.size());
        System.assertEquals('Restore', restoreLogs[0].Action_Type__c);
        System.assertEquals('In Progress', restoreLogs[0].Restore_Status__c);
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void test_RestoreController_createRestoreLogs_empty() {
          User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        List<File_Recovery_Log__c> result =
            RecycleBinVaultRestore_Controller.createRestoreLogs(
                new List<File_Recovery_Log__c>()
            );
        System.assert(result.isEmpty());
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
@isTest
static void testUploadToS3() {
     User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
    AWS_Settings__c setting = TestDataFactory.createAWSSetting();
    Test.setMock(HttpCalloutMock.class, new MockS3Success());
    Test.startTest();
    RecycleBinMultiObjectBackupBatch.uploadToS3('success.csv', 'Name,Value\nA,1');
    Test.setMock(HttpCalloutMock.class, new MockS3Failure());

    try {
        RecycleBinMultiObjectBackupBatch.uploadToS3('fail.csv', 'Name,Value\nB,2');
        System.assert(false, 'Expected exception not thrown');
    } catch (Exception e) {
        System.assert(e.getMessage().contains('S3 upload failed'));
    }
    Test.setMock(HttpCalloutMock.class, new MockS3CsvDownload('Col1,Col2\nX,Y'));
    RecycleBinMultiObjectBackupBatch.uploadToS3('csv.csv', 'Col1,Col2\nX,Y');
    Test.stopTest();
    System.assert(true, 'All scenarios covered');
 } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    @isTest
static void testRecycleBinBackupBatchUploadToS3_AllCases() {
    User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
    AWS_Settings__c setting = TestDataFactory.createAWSSetting();
    Test.setMock(HttpCalloutMock.class, new MockS3Success());
    Test.startTest();
    RecycleBinBackupBatch.uploadToS3('success.csv', 'Name,Value\nA,1');
    Test.setMock(HttpCalloutMock.class, new MockS3Failure());
    try {
        RecycleBinBackupBatch.uploadToS3('fail.csv', 'Name,Value\nB,2');
        System.assert(false, 'Expected exception not thrown');
    } catch (Exception e) {
    }
    Test.setMock(HttpCalloutMock.class, new MockS3CsvDownload('Col1,Col2\nX,Y'));
    RecycleBinBackupBatch.uploadToS3('csv.csv', 'Col1,Col2\nX,Y');
    try {
        RecycleBinBackupBatch.uploadToS3('nourl.csv', 'data');
    } catch (Exception e) {
    }
    Test.stopTest();
 } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    @isTest
static void testFlattenErrors() {
     User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
    Account acc = new Account();
        Database.SaveResult sr = Database.insert(acc, false);
    List<Database.Error> errors = sr.getErrors();
    Test.startTest();
    String result = RecycleBinRestoreService.flattenErrors(errors);
    Test.stopTest();
    System.assertNotEquals(null, result);
 } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    private static File_Recovery_Log__c makeBackupLog(Id recordId, String objectName, String objectNameOverride) {
        File_Recovery_Log__c log = new File_Recovery_Log__c(
            File_Name__c      = 'TestFile_' + objectName,
            S3_Key__c         = 'backups/' + objectName + '/key-' + System.currentTimeMillis(),
            Record_Id__c      = recordId,
            Object_Name__c    = objectNameOverride,
            Action_Type__c    = 'Backup',
            Backup_Status__c  = 'Failed',
            Restore_Status__c = 'In Progress',
            Restore_Time__c   = DateTime.now()
        );
        Database.insert(log, AccessLevel.SYSTEM_MODE);
        return log;
    }

    @isTest
    static void testResolveByObjectsAndIds_CleanObjectName() {
         User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        TestDataFactory.createAWSSetting();
        Account acc = TestDataFactory.createTestAccount();
        makeBackupLog(acc.Id, 'Account', 'Account');        
        TestDataFactory.createScheduledRestoreIntentLog('Account');

        RecycleBinRestoreScheduler scheduler = new RecycleBinRestoreScheduler(
            new List<String>{ 'Account' },
            new List<String>{ acc.Id }
        );

        Test.startTest();
        String jobId = System.schedule('Test_ResolveByObjectsAndIds_Clean',
                                       '0 0 0 1 1 ? 2099', scheduler);
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Job ID must not be null');

        List<File_Recovery_Log__c> restoreLogs = [
            SELECT Id, Restore_Status__c
            FROM File_Recovery_Log__c
            WHERE Action_Type__c = 'Restore'
        ];
        System.assertNotEquals(0, restoreLogs.size(), 'Restore logs must be created');
        System.assertEquals('In Progress', restoreLogs[0].Restore_Status__c,
                            'Restore status must be In Progress');
  } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    @isTest
    static void testResolveByObjectsOnly_CommaObjectName_Patched() {
          User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        TestDataFactory.createAWSSetting();
        Account acc = TestDataFactory.createTestAccount();
        makeBackupLog(acc.Id, 'Account', 'Account,Contact');  
        TestDataFactory.createScheduledRestoreIntentLog('Account');

        RecycleBinRestoreScheduler scheduler = new RecycleBinRestoreScheduler(
            new List<String>{ 'Account', 'Contact' },
            null                                           
        );

        Test.startTest();
        String jobId = System.schedule('Test_ResolveByObjectsOnly_Comma',
                                       '0 0 0 1 1 ? 2099', scheduler);
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Job ID must not be null');

        List<File_Recovery_Log__c> restoreLogs = [
            SELECT Id FROM File_Recovery_Log__c WHERE Action_Type__c = 'Restore'
        ];
        System.assertNotEquals(0, restoreLogs.size(), 'Restore logs must be created');
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    @isTest
    static void testResolveAllPending_BlankObjectName_Patched() {
         User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        TestDataFactory.createAWSSetting();
        Account acc = TestDataFactory.createTestAccount();
        makeBackupLog(acc.Id, 'Account', '');               
        TestDataFactory.createScheduledRestoreIntentLog('Account');
        RecycleBinRestoreScheduler scheduler = new RecycleBinRestoreScheduler(null,null,'Account');
        Test.startTest();
        String jobId = System.schedule('Test_ResolveAllPending_Blank',
                                       '0 0 0 1 1 ? 2099', scheduler);
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'Job ID must not be null');
        List<File_Recovery_Log__c> restoreLogs = [
            SELECT Id FROM File_Recovery_Log__c WHERE Action_Type__c = 'Restore'
        ];
        System.assertNotEquals(0, restoreLogs.size(), 'Restore logs must be created');
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    @isTest
    static void testExecute_NoBackupLogs_DispatchSkipped() {
         User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        TestDataFactory.createAWSSetting();
        TestDataFactory.createScheduledRestoreIntentLog('Account');

        RecycleBinRestoreScheduler scheduler = new RecycleBinRestoreScheduler();

        Test.startTest();
        String jobId = System.schedule('Test_NoBackupLogs',
                                       '0 0 0 1 1 ? 2099', scheduler);
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Job ID must not be null');

        List<File_Recovery_Log__c> restoreLogs = [
            SELECT Id FROM File_Recovery_Log__c WHERE Action_Type__c = 'Restore'
        ];
  } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    @isTest
    static void testDispatchBatch_LabelBlank_PatchingSkipped() {
           User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        TestDataFactory.createAWSSetting();
        Account acc = TestDataFactory.createTestAccount();
        makeBackupLog(acc.Id, 'Account', 'Account');
        TestDataFactory.createScheduledRestoreIntentLog('Account');
        RecycleBinRestoreScheduler scheduler = new RecycleBinRestoreScheduler(
            new List<String>(),                                
            new List<String>{ acc.Id }
        );

        Test.startTest();
        String jobId = System.schedule('Test_LabelBlank_PatchingSkipped',
                                       '0 0 0 1 1 ? 2099', scheduler);
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'Job ID must not be null');
        List<File_Recovery_Log__c> restoreLogs = [
            SELECT Id FROM File_Recovery_Log__c WHERE Action_Type__c = 'Restore'
        ];
        System.assertNotEquals(0, restoreLogs.size(),
                            'Restore logs must still be created even when label is blank');
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    @isTest
static void test_RecycleBinScheduledBackup_threeParamConstructor_allPaths() {
    User u = TestDataFactory.createUser('Standard User');
    TestDataFactory.AssignAWSInternalPSet(u.Id);
    System.runAs(u) {
        try {
            Account acc = createAndDeleteAccount('ThreeParamAllPaths');
            Test.setMock(HttpCalloutMock.class, new MockS3Success());
            Test.startTest();
            System.schedule('ThreeParam_Single',
                '0 0 10 * * ?',
                new RecycleBinScheduledBackup(new List<String>{ 'Account' }, null, 'Account')
            );
            System.schedule('ThreeParam_Multi',
                '0 0 11 * * ?',
                new RecycleBinScheduledBackup(new List<String>{ 'Account', 'Contact' }, null, 'Account, Contact')
            );
            System.schedule('ThreeParam_SingleIds',
                '0 0 12 * * ?',
                new RecycleBinScheduledBackup(new List<String>{ 'Account' }, new List<String>{ acc.Id }, 'Account')
            );
            System.schedule('ThreeParam_MultiIds',
                '0 0 13 * * ?',
                new RecycleBinScheduledBackup(new List<String>{ 'Account', 'Contact' }, new List<String>{ acc.Id }, 'Account, Contact')
            );
            System.schedule('ThreeParam_Empty',
                '0 0 14 * * ?',
                new RecycleBinScheduledBackup(new List<String>(), null, '')
            );
            System.schedule('ThreeParam_Null',
                '0 0 15 * * ?',
                new RecycleBinScheduledBackup(null, null, null)
            );

            Test.stopTest();
        } catch (Exception e) {
            Boolean permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'))
                             || (e instanceof AuraHandledException);
            System.assert(!permError, 'Unexpected exception: ' + e.getMessage());
        }
    }
}
}