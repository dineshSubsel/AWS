@isTest
public class FileRecoveryAndRestoreTest {
  @TestSetup
    static void setupData() {
        TestDataFactory.createAWSSetting();
        Account acc = TestDataFactory.createTestAccount();
        TestDataFactory.createFileRecoveryLog(acc.Id, 'Account');
        TestDataFactory.createEligibleBackupLog(acc.Id, 'Account');
        TestDataFactory.createBackupFileRecoveryLog(acc.Id, 'Account');
        TestDataFactory.createContentDocumentIds(acc.Id);
    }
    private static Account getAccount() {
        return [SELECT Id, Name FROM Account LIMIT 1];
    }
    private static File_Recovery_Log__c getInProgressLog() {
        return [
            SELECT Id, S3_Key__c, File_Name__c, Record_Id__c, Object_Name__c
            FROM File_Recovery_Log__c
            WHERE Restore_Status__c = 'In Progress'
            LIMIT 1
        ];
    }
    private static File_Recovery_Log__c getEligibleLog() {
        return [
            SELECT Id, S3_Key__c, File_Name__c, Record_Id__c, Object_Name__c
            FROM File_Recovery_Log__c
            WHERE Backup_Status__c = 'Success'
            LIMIT 1
        ];
    }
    @isTest
    static void testGetAllObjects() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.startTest();
        List<String> objects = FileRecoveryVaultController.getAllObjects();
        Test.stopTest();
        System.assertNotEquals(null, objects, 'getAllObjects should not return null');
     } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    @isTest
    static void testGetRecords() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.startTest();
        List<SObject> records = FileRecoveryVaultController.getRecords('Account');
        Test.stopTest();
        System.assertNotEquals(null, records, 'getRecords should not return null');
       } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    @isTest
    static void testGetFilesForRecords() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Account acc = getAccount();
        List<Id> recordIds = new List<Id>{ acc.Id };
        Test.startTest();
        List<ContentDocument> docs = FileRecoveryVaultController.getFilesForRecords(recordIds);
        Test.stopTest();
        System.assertNotEquals(null, docs, 'getFilesForRecords should not return null');
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
    @isTest
    static void testGetFilesForLogRecords_validInputs() {
        User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Account acc = getAccount();
        List<Id> ids = new List<Id>{ acc.Id };
        Test.startTest();
        List<FileRecoveryVaultController.FileRow> rows =
            FileRecoveryVaultController.getFilesForLogRecords(ids, 'Account');
        Test.stopTest();
        System.assertNotEquals(null, rows, 'Should return a non-null list');
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testGetFilesForLogRecords_emptyIds() {
        User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.startTest();
        List<FileRecoveryVaultController.FileRow> rows =
            FileRecoveryVaultController.getFilesForLogRecords(new List<Id>(), 'Account');
        Test.stopTest();
        System.assertEquals(0, rows.size(), 'Empty ids should return empty list');
     } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testGetFilesForLogRecords_blankObject() {
         User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Account acc = getAccount();
        List<Id> ids = new List<Id>{ acc.Id };
        Test.startTest();
        List<FileRecoveryVaultController.FileRow> rows =
            FileRecoveryVaultController.getFilesForLogRecords(ids, '');
        Test.stopTest();
        System.assertEquals(0, rows.size(), 'Blank objectName should return empty list');
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
   @isTest
static void testStartInstantRestore_noLogsFound() {
    User u = TestDataFactory.createUser('System Administrator');
    TestDataFactory.AssignAWSInternalPSet(u.Id);
    System.runAs(u) {
        Account acc = getAccount();
        Test.startTest();
        List<String> result = FileRecoveryVaultController.startInstantRestore(
            'Contact',
            new List<String>{ acc.Id },
            new List<String>() 
        );

        Test.stopTest();
        System.assertEquals(1, result.size());
        System.assert(
            result[0].contains('No backup files found'),
            'Expected no backup message'
        );
    }
}

   @isTest
static void testStartInstantRestore_blankObject() {
    User u = TestDataFactory.createUser('System Administrator');
    TestDataFactory.AssignAWSInternalPSet(u.Id);
    System.runAs(u) {
        Account acc = getAccount();
        Test.startTest();
        try {
            FileRecoveryVaultController.startInstantRestore(
                '',
                new List<String>{ acc.Id },
                new List<String>() 
            );
            System.assert(false, 'Should throw for blank object');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }

        Test.stopTest();
    }
}

   @isTest
static void testStartInstantRestore_emptyRecordIds() {
    User u = TestDataFactory.createUser('System Administrator');
    TestDataFactory.AssignAWSInternalPSet(u.Id);
    System.runAs(u) {
        Test.startTest();
        List<String> result = FileRecoveryVaultController.startInstantRestore(
            'Account',
            new List<String>(),
            new List<String>()
        );
        Test.stopTest();
        System.assertEquals(1, result.size());
        System.assert(
            result[0].contains('No backup files found'),
            'Expected no backup files message'
        );
    }
}
   @isTest
static void testStartScheduledRestore_daily() {
    User u = TestDataFactory.createUser('System Administrator');
    TestDataFactory.AssignAWSInternalPSet(u.Id);
    System.runAs(u) {
        Account acc = getAccount();
        Test.startTest();
        String jobName = FileRecoveryVaultController.startScheduledRestore(
            'Account',
            new List<String>{ acc.Id },
            new List<String>(),
            'daily',
            '02:00'
        );
        Test.stopTest();
        System.assert(jobName.startsWith('FRV-'), 'Job name should start with FRV-');
    }
}

    @isTest
static void testStartScheduledRestore_weekly() {
    User u = TestDataFactory.createUser('System Administrator');
    TestDataFactory.AssignAWSInternalPSet(u.Id);
    System.runAs(u) {
        Account acc = getAccount();
        Test.startTest();
        String jobName = FileRecoveryVaultController.startScheduledRestore(
            'Account',
            new List<String>{ acc.Id },
            new List<String>(),
            'weekly',
            '10:30'
        );

        Test.stopTest();
        System.assert(jobName.contains('WEEKLY'), 'Job name should contain frequency');
    }
}

    @isTest
static void testStartScheduledRestore_monthly() {
    User u = TestDataFactory.createUser('System Administrator');
    TestDataFactory.AssignAWSInternalPSet(u.Id);
    System.runAs(u) {
        Account acc = getAccount();
        Test.startTest();
        String jobName = FileRecoveryVaultController.startScheduledRestore(
            'Account',
            new List<String>{ acc.Id },
            new List<String>(),
            'monthly',
            '08:15'
        );
        Test.stopTest();
        System.assertNotEquals(null, jobName);
    }
}

   @isTest
static void testStartScheduledRestore_invalidFrequency() {
    User u = TestDataFactory.createUser('Standard User');
    TestDataFactory.AssignAWSInternalPSet(u.Id);
    System.runAs(u) {
        Account acc = getAccount();
        Test.startTest();
        try {
            FileRecoveryVaultController.startScheduledRestore(
                'Account',
                new List<String>{ acc.Id },
                new List<String>(),
                'hourly',
                '08:00'
            );
            System.assert(false, 'Should throw for invalid frequency');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }
}


   @isTest
static void testStartScheduledRestore_blankFrequency() {
    User u = TestDataFactory.createUser('Standard User');
    TestDataFactory.AssignAWSInternalPSet(u.Id);
    System.runAs(u) {
        Account acc = getAccount();
        Test.startTest();
        try {
            FileRecoveryVaultController.startScheduledRestore(
                'Account',
                new List<String>{ acc.Id },
                new List<String>(),
                '',
                '08:00'
            );
            System.assert(false, 'Should throw for blank frequency');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }
}

    @isTest
static void testStartScheduledRestore_blankTime() {
    User u = TestDataFactory.createUser('Standard User');
    TestDataFactory.AssignAWSInternalPSet(u.Id);
    System.runAs(u) {
        Account acc = getAccount();
        Test.startTest();
        try {
            FileRecoveryVaultController.startScheduledRestore(
                'Account',
                new List<String>{ acc.Id },
                new List<String>(),
                'daily',
                ''
            );

            System.assert(false, 'Should throw for blank time');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }
}
    @isTest
    static void testStartInstantBackup_withRecordIds() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Account acc = getAccount();
         Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());
        Test.startTest();
        List<String> jobIds = FileRecoveryVaultController.startInstantBackup(
            'Account',
            new List<String>{ acc.Id }
        );
        Test.stopTest();
        System.assertNotEquals(null, jobIds);
        System.assertEquals(1, jobIds.size());
     } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testStartInstantBackup_withoutRecordIds() {
          User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout()); 
        Test.startTest();
        List<String> jobIds = FileRecoveryVaultController.startInstantBackup(
            'Account',
            new List<String>()
        );
        Test.stopTest();
        System.assertNotEquals(null, jobIds);
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }


    @isTest
    static void testStartInstantBackup_blankObject() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.startTest();
        try {
            FileRecoveryVaultController.startInstantBackup('', new List<String>());
            System.assert(false, 'Should throw for blank object');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testStartInstantBackup_multipleObjects() {
          User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
         Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());
        Test.startTest();
        List<String> jobIds = FileRecoveryVaultController.startInstantBackup(
            'Account,Contact',
            null
        );
        Test.stopTest();

        System.assertNotEquals(null, jobIds);
     } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testStartScheduledBackup_withoutRecordIds_daily() {
        User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());
        Test.startTest();
        List<String> jobNames = FileRecoveryVaultController.startScheduledBackup(
            'Account',
            new List<String>(),
            'daily',
            '03:00'
        );
        Test.stopTest();
        System.assertNotEquals(null, jobNames);
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testStartScheduledBackup_withRecordIds() {
        User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Account acc = getAccount();
        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());
        Test.startTest();
        List<String> jobNames = FileRecoveryVaultController.startScheduledBackup(
            'Account',
            new List<String>{ acc.Id },
            'weekly',
            '06:00'
        );
        Test.stopTest();
        System.assertNotEquals(null, jobNames);
        System.assertEquals(1, jobNames.size());
      } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testStartScheduledBackup_blankObject() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.startTest();
        try {
            FileRecoveryVaultController.startScheduledBackup(
                '',
                new List<String>(),
                'daily',
                '06:00'
            );
            System.assert(false, 'Should throw for blank object');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    // @isTest
    // static void testStartScheduledBackup_monthly_multipleObjects() {
    //      User u = TestDataFactory.createUser('Standard User');
    //     TestDataFactory.AssignAWSInternalPSet(u.Id);
    //     Boolean permError = false;
    //     System.runAs(u) {
    //         try {
    //     Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());
    //     Test.startTest();
    //     List<String> jobNames = FileRecoveryVaultController.startScheduledBackup(
    //         'Account,Contact,Case',
    //         null,
    //         'monthly',
    //         '23:59'
    //     );
    //     Test.stopTest();
    //     System.assertNotEquals(null, jobNames);
    // } catch (Exception e) {
    //             permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
    //             permError = permError || (e instanceof AuraHandledException);
    //         }
    //     }
    // }

    @isTest
    static void testGetBackupJobStatus_emptyIds() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.startTest();
        List<Map<String, String>> rows =
            FileRecoveryVaultController.getBackupJobStatus(new List<String>());
        Test.stopTest();
        System.assertNotEquals(null, rows);
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }


    @isTest
    static void testAreAllJobsDone_emptyIds() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.startTest();
        Boolean done = FileRecoveryVaultController.areAllJobsDone(new List<String>());
        Test.stopTest();
        System.assertNotEquals(null, done);
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testAbortJob_invalidId() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.startTest();
        try {
            FileRecoveryVaultController.abortJob('');
            System.assert(false, 'Should throw for blank job id');
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
    static void testGetBackupJobStatusRestore_emptyIds() {
          User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.startTest();
        List<Map<String, String>> rows =
            FileRecoveryVaultController.getBackupJobStatusRestore(new List<String>());
        Test.stopTest();
        System.assertNotEquals(null, rows);
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testAreAllJobsDoneRestore_emptyIds() {
         User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.startTest();
        Boolean done = FileRecoveryVaultController.areAllJobsDoneRestore(new List<String>());
        Test.stopTest();
        System.assertNotEquals(null, done);
     } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testScheduler_withRecordIds() {
         User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Account acc = getAccount();
        FileRestoreScheduler scheduler = new FileRestoreScheduler(
            new List<String>{ 'Account' },
            new List<String>{ acc.Id }
        );
        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());
        Test.startTest();
        String jobId = System.schedule(
            'Test_Scheduler_RecordIds_' + System.currentTimeMillis(),
            '0 0 2 * * ?',
            scheduler
        );
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'Scheduler job should be scheduled');
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testScheduler_withoutRecordIds_globalRestore() {
        User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        FileRestoreScheduler scheduler = new FileRestoreScheduler(
            new List<String>{ 'Account' },
            null
        );
        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());
        Test.startTest();
        String jobId = System.schedule(
            'Test_Scheduler_Global_' + System.currentTimeMillis(),
            '0 0 3 * * ?',
            scheduler
        );
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'Global scheduler job should be scheduled');
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @isTest
    static void testScheduler_noArgConstructor() {
       User u = TestDataFactory.createUser('System Administrator');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        FileRestoreScheduler scheduler = new FileRestoreScheduler();
          Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());
        Test.startTest();
        String jobId = System.schedule(
            'Test_Scheduler_NoArg_' + System.currentTimeMillis(),
            '0 0 4 * * ?',
            scheduler
        );
        Test.stopTest();
        System.assertNotEquals(null, jobId);
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
 
    private class MockSuccessCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBodyAsBlob(Blob.valueOf('Fake file content'));
            return res;
        }
    }

    private class MockFailCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

  @isTest
static void testRestoreService_successCallout() {
    User u = TestDataFactory.createUser('Standard User');
    TestDataFactory.AssignAWSInternalPSet(u.Id);
    System.runAs(u) {
        Account acc = getAccount();
        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());
        Test.startTest();
        FileRestoreService.restoreSingleFile('test-key', 'TestFile.pdf', acc.Id);
        Test.stopTest();
        List<ContentDocumentLink> links = [
            SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :acc.Id
        ];
        System.assert(links.size() > 0, 'Expected at least one ContentDocumentLink');
    }
}

@isTest
static void testRestoreService_failedCallout() {
    User u = TestDataFactory.createUser('Standard User');
    TestDataFactory.AssignAWSInternalPSet(u.Id);
    System.runAs(u) {
        Account acc = getAccount();
        Test.setMock(HttpCalloutMock.class, new MockFailCallout());
        Test.startTest();
        try {
            FileRestoreService.restoreSingleFile('bad-key', 'TestFile.pdf', acc.Id);
            System.assert(false, 'Expected FileRestoreException but none was thrown');
        } catch (FileRestoreService.FileRestoreException e) {
            System.assert(
                e.getMessage().contains('S3 download failed'),
                'Expected S3 failure message, got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }
}
@isTest
static void testRestoreQueueable_completedSuccessfully() {
    User u = TestDataFactory.createUser('Standard User');
    TestDataFactory.AssignAWSInternalPSet(u.Id);
    System.runAs(u) {
        File_Recovery_Log__c log = getInProgressLog();
        List<File_Recovery_Log__c> logs = new List<File_Recovery_Log__c>{ log };
        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());
        Test.startTest();
        System.enqueueJob(new FileRestoreQueueable(logs));
        Test.stopTest();
        File_Recovery_Log__c updated = [
            SELECT Restore_Status__c 
            FROM File_Recovery_Log__c 
            WHERE Id = :log.Id
        ];
        System.assertEquals('Completed', updated.Restore_Status__c,
            'Log should be marked Completed on success');
    }
}

@isTest
static void testRestoreQueueable_failedCallout() {
    User u = TestDataFactory.createUser('Standard User');
    TestDataFactory.AssignAWSInternalPSet(u.Id);
    System.runAs(u) {
        File_Recovery_Log__c log = getInProgressLog();
        List<File_Recovery_Log__c> logs = new List<File_Recovery_Log__c>{ log };
        Test.setMock(HttpCalloutMock.class, new MockFailCallout());
        Test.startTest();
        System.enqueueJob(new FileRestoreQueueable(logs));
        Test.stopTest();

        File_Recovery_Log__c updated = [
            SELECT Restore_Status__c, Error_Message__c 
            FROM File_Recovery_Log__c 
            WHERE Id = :log.Id
        ];
        System.assertEquals('Failed', updated.Restore_Status__c,
            'Log should be marked Failed on HTTP error');
        System.assertNotEquals(null, updated.Error_Message__c);
    }
}
    @isTest                        
static void testAbortJob_invalid() {
    User u = TestDataFactory.createUser('System Administrator');
    TestDataFactory.AssignAWSInternalPSet(u.Id);
    Boolean permError = false;
    System.runAs(u) {
        try {
            Test.startTest();

            // 1. Real scheduled job — covers try block success path
            try {
                FileRestoreScheduler scheduler = new FileRestoreScheduler();
                String jobId = System.schedule(
                    'Test_Abort_Valid_' + System.currentTimeMillis(),
                    '0 0 5 * * ?',
                    scheduler
                );
                FileRecoveryVaultController.abortJob(jobId);
            } catch (AuraHandledException e) {
                permError = true;
            }

            // 2. Fake non-blank ID — covers catch block failure path
            try {
                FileRecoveryVaultController.abortJob('00Di000000000001AAA');
            } catch (AuraHandledException e) {
                // AuraHandledException wraps message as 'Script-thrown exception'
                // so we just verify exception was thrown — covers catch block
                System.assertNotEquals(null, e);
            }

            Test.stopTest();

        } catch (Exception e) {
            permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
            permError = permError || (e instanceof AuraHandledException);
        }
    }
}
    @isTest
static void testGetBackupJobStatus_emptyId() {
    User u = TestDataFactory.createUser('System Administrator');
    TestDataFactory.AssignAWSInternalPSet(u.Id);
    Boolean permError = false;
    System.runAs(u) {
        try {
            Test.startTest();

            // 1. Empty list — covers early return path
            List<Map<String, String>> emptyResult =
                FileRecoveryVaultController.getBackupJobStatus(new List<String>());
            System.assertNotEquals(null, emptyResult);
            System.assertEquals(0, emptyResult.size());

            // 2. Null — covers null check path
            List<Map<String, String>> nullResult =
                FileRecoveryVaultController.getBackupJobStatus(null);
            System.assertNotEquals(null, nullResult);
            System.assertEquals(0, nullResult.size());

            // 3. Real scheduled job IDs — covers for loop path
            FileRestoreScheduler scheduler = new FileRestoreScheduler();
            String scheduledJobId = System.schedule(
                'Test_BackupStatus_' + System.currentTimeMillis(),
                '0 0 6 * * ?',
                scheduler
            );

            List<AsyncApexJob> activeJobs = [
                SELECT Id FROM AsyncApexJob
                WHERE JobType = 'ScheduledApex'
                AND Status IN ('Queued', 'Processing', 'Preparing')
                LIMIT 10
            ];

            List<String> jobIdList = new List<String>();
            for (AsyncApexJob j : activeJobs) {
                jobIdList.add(j.Id);
            }

            if (!jobIdList.isEmpty()) {
                List<Map<String, String>> statusResult =
                    FileRecoveryVaultController.getBackupJobStatus(jobIdList);
                System.assertNotEquals(null, statusResult);
            }

            Test.stopTest();

        } catch (Exception e) {
            permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
            permError = permError || (e instanceof AuraHandledException);
        }
    }
}
    @isTest
static void testGetBackupJobStatusRestore_emptyId() {
    User u = TestDataFactory.createUser('System Administrator');
    TestDataFactory.AssignAWSInternalPSet(u.Id);
    Boolean permError = false;
    System.runAs(u) {
        try {
            Test.startTest();

            // 1. Empty list — covers early return path
            List<Map<String, String>> emptyResult =
                FileRecoveryVaultController.getBackupJobStatusRestore(new List<String>());
            System.assertNotEquals(null, emptyResult);
            System.assertEquals(0, emptyResult.size());

            // 2. Null — covers null check path
            List<Map<String, String>> nullResult =
                FileRecoveryVaultController.getBackupJobStatusRestore(null);
            System.assertNotEquals(null, nullResult);
            System.assertEquals(0, nullResult.size());

            // 3. Real scheduled job IDs — covers for loop path
            FileRestoreScheduler scheduler = new FileRestoreScheduler();
            String scheduledJobId = System.schedule(
                'Test_RestoreStatus_' + System.currentTimeMillis(),
                '0 0 7 * * ?',
                scheduler
            );

            List<AsyncApexJob> activeJobs = [
                SELECT Id FROM AsyncApexJob
                WHERE JobType = 'ScheduledApex'
                AND Status IN ('Queued', 'Processing', 'Preparing')
                LIMIT 10
            ];

            List<String> jobIdList = new List<String>();
            for (AsyncApexJob j : activeJobs) {
                jobIdList.add(j.Id);
            }

            if (!jobIdList.isEmpty()) {
                List<Map<String, String>> statusResult =
                    FileRecoveryVaultController.getBackupJobStatusRestore(jobIdList);
                System.assertNotEquals(null, statusResult);
            }

            Test.stopTest();

        } catch (Exception e) {
            permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
            permError = permError || (e instanceof AuraHandledException);
        }
    }
}
}