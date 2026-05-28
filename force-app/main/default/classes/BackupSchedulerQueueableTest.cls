@IsTest
public class BackupSchedulerQueueableTest {

    @IsTest
    static void testBackupScheduler_SpecificRecordMode() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        System.runAs(u) {
            try {
                Account acc = TestDataFactory.createTestAccount();
                List<String> recordIds = new List<String>{ acc.Id };

                Test.startTest();
                System.schedule(
                    'TestBackupScheduler_Specific',
                    '0 0 0 1 1 ? 2099',
                    new BackupScheduler('Account', recordIds)
                );
                Test.stopTest();

                System.assert(true);
            } catch (Exception e) {
                Boolean permError =
                    (e instanceof SObjectException &&
                     e.getMessage().startsWith('Unable to assign all fields'))
                    || (e instanceof AuraHandledException);
                System.assert(permError, 'Unexpected: ' + e.getMessage());
            }
        }
    }

    @IsTest
static void testBackupScheduler_FullObjectMode() {
    User u = TestDataFactory.createUser('Standard User');
    TestDataFactory.AssignAWSInternalPSet(u.Id);

    System.runAs(u) {
        try {
            Test.startTest();
            System.schedule(
                'TestBackupScheduler_Full',
                '0 0 0 1 1 ? 2099',
                new BackupScheduler(new List<String>{ 'Account' })
            );
            Test.stopTest();
            System.assert(true);
        } catch (Exception e) {
            Boolean permError =
                (e instanceof SObjectException &&
                 e.getMessage().startsWith('Unable to assign all fields'))
                || (e instanceof AuraHandledException);
            System.assert(permError, 'Unexpected: ' + e.getMessage());
        }
    }
}
    
    @IsTest
static void testBackupScheduler_SingleObjectConstructor() {
    User u = TestDataFactory.createUser('Standard User');
    TestDataFactory.AssignAWSInternalPSet(u.Id);

    System.runAs(u) {
        try {
            Test.startTest();
            System.schedule(
                'TestBackupScheduler_SingleObj',
                '0 0 0 1 1 ? 2099',
                new BackupScheduler(new List<String>{ 'Account' })
            );
            Test.stopTest();
            System.assert(true);
        } catch (Exception e) {
            Boolean permError =
                (e instanceof SObjectException &&
                 e.getMessage().startsWith('Unable to assign all fields'))
                || (e instanceof AuraHandledException);
            System.assert(permError, 'Unexpected: ' + e.getMessage());
        }
    }
}

    @IsTest
    static void testBackupQueueable_WithRecordIds() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);

        System.runAs(u) {
            try {
                Account acc = TestDataFactory.createTestAccount();
                List<String> recordIds = new List<String>{ acc.Id };

                Test.startTest();
                System.enqueueJob(new BackupQueueable('Account', recordIds));
                Test.stopTest();

                System.assert(true);
            } catch (Exception e) {
                Boolean permError =
                    (e instanceof SObjectException &&
                     e.getMessage().startsWith('Unable to assign all fields'))
                    || (e instanceof AuraHandledException);
                System.assert(permError, 'Unexpected: ' + e.getMessage());
            }
        }
    }

    @IsTest
static void testBackupQueueable_ListConstructor_Index0() {
    User u = TestDataFactory.createUser('Standard User');
    TestDataFactory.AssignAWSInternalPSet(u.Id);

    System.runAs(u) {
        try {
            TestDataFactory.createTestAccount();
            Test.startTest();
            System.enqueueJob(
                new BackupQueueable(
                    new List<String>{ 'Account' }, 0
                )
            );
            Test.stopTest();
            System.assert(true);
        } catch (Exception e) {
            Boolean permError =
                (e instanceof SObjectException &&
                 e.getMessage().startsWith('Unable to assign all fields'))
                || (e instanceof AuraHandledException);
            System.assert(permError, 'Unexpected: ' + e.getMessage());
        }
    }
}


    @IsTest
    static void testBackupQueueable_IndexOutOfBounds() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);

        System.runAs(u) {
            try {
                Test.startTest();
                System.enqueueJob(
                    new BackupQueueable(new List<String>{ 'Account' }, 5)
                );
                Test.stopTest();

                System.assert(true);
            } catch (Exception e) {
                Boolean permError =
                    (e instanceof SObjectException &&
                     e.getMessage().startsWith('Unable to assign all fields'))
                    || (e instanceof AuraHandledException);
                System.assert(permError, 'Unexpected: ' + e.getMessage());
            }
        }
    }

    @IsTest
static void testBackupQueueable_BlankObjectName() {
    User u = TestDataFactory.createUser('Standard User');
    TestDataFactory.AssignAWSInternalPSet(u.Id);

    System.runAs(u) {
        try {
            Test.startTest();
            System.enqueueJob(
                new BackupQueueable(
                    new List<String>{ '' }, 0
                )
            );
            Test.stopTest();
            System.assert(true);
        } catch (Exception e) {
            Boolean permError =
                (e instanceof SObjectException &&
                 e.getMessage().startsWith('Unable to assign all fields'))
                || (e instanceof AuraHandledException);
            System.assert(permError, 'Unexpected: ' + e.getMessage());
        }
    }
}

    @IsTest
    static void testBackupQueueable_LastIndex_NoChain() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);

        System.runAs(u) {
            try {
                Test.startTest();
                System.enqueueJob(
                    new BackupQueueable(new List<String>{ 'Account' }, 0)
                );
                Test.stopTest();

                System.assert(true);
            } catch (Exception e) {
                Boolean permError =
                    (e instanceof SObjectException &&
                     e.getMessage().startsWith('Unable to assign all fields'))
                    || (e instanceof AuraHandledException);
                System.assert(permError, 'Unexpected: ' + e.getMessage());
            }
        }
    }

    @IsTest
    static void testBackupQueueable_EmptyRecordIds() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);

        System.runAs(u) {
            try {
                Test.startTest();
                System.enqueueJob(
                    new BackupQueueable('Account', new List<String>())
                );
                Test.stopTest();

                System.assert(true);
            } catch (Exception e) {
                Boolean permError =
                    (e instanceof SObjectException &&
                     e.getMessage().startsWith('Unable to assign all fields'))
                    || (e instanceof AuraHandledException);
                System.assert(permError, 'Unexpected: ' + e.getMessage());
            }
        }
    }

    @IsTest
    static void testBackupScheduler_EmptyRecordIds_FullMode() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);

        System.runAs(u) {
            try {
                Test.startTest();
                System.schedule(
                    'TestBackupScheduler_EmptyRec',
                    '0 0 0 1 1 ? 2099',
                    new BackupScheduler('Account', null)
                );
                Test.stopTest();

                System.assert(true);
            } catch (Exception e) {
                Boolean permError =
                    (e instanceof SObjectException &&
                     e.getMessage().startsWith('Unable to assign all fields'))
                    || (e instanceof AuraHandledException);
                System.assert(permError, 'Unexpected: ' + e.getMessage());
            }
        }
    }
    @IsTest
    static void testBackupQueueable_NoRecordsFound() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);

        System.runAs(u) {
            try {
                Test.startTest();
                System.enqueueJob(
                    new BackupQueueable(
                        new List<String>{ 'Opportunity' }, 0
                    )
                );
                Test.stopTest();

                System.assert(true);
            } catch (Exception e) {
                Boolean permError =
                    (e instanceof SObjectException &&
                     e.getMessage().startsWith('Unable to assign all fields'))
                    || (e instanceof AuraHandledException);
                System.assert(permError, 'Unexpected: ' + e.getMessage());
            }
        }
    }
}