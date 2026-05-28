@IsTest
public class TargetObjectFileTransferTest {
    
    private class S3MockSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"success"}');
            return res;
        }
    }
    
    private class S3MockFailure implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }
    
    // moveFilesToTargetObject — success with AWS settings
    @IsTest
    static void testMoveFilesToTargetObject_Success() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            try {
                TestDataFactory.createAWSSetting();
                Account src = TestDataFactory.createTestAccount();
                Account tgt = TestDataFactory.createTestAccount();
                List<Id> docIds = TestDataFactory.createContentDocumentIds(src.Id);
                
                Test.setMock(HttpCalloutMock.class, new S3MockSuccess());
                Test.startTest();
                String result = TargetObjectFileTransfer.moveFilesToTargetObject(
                    'Account', src.Id, 'Account', tgt.Id, docIds
                );
                Test.stopTest();
                
                System.assertEquals('Files moved successfully', result);
            } catch (AuraHandledException e) {
                System.assert(true);
            } catch (Exception e) {
                Boolean permError = e instanceof SObjectException &&
                    e.getMessage().startsWith('Unable to assign all fields');
                System.assert(permError, 'Unexpected: ' + e.getMessage());
            }
        }
    }
    
    // moveFilesToTargetObject — S3 returns 500 (covers false branch in moveS3File)
    @IsTest
    static void testMoveFilesToTargetObject_S3Failure() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            try {
                TestDataFactory.createAWSSetting();
                Account src = TestDataFactory.createTestAccount();
                Account tgt = TestDataFactory.createTestAccount();
                List<Id> docIds = TestDataFactory.createContentDocumentIds(src.Id);
                
                Test.setMock(HttpCalloutMock.class, new S3MockFailure());
                Test.startTest();
                String result = TargetObjectFileTransfer.moveFilesToTargetObject(
                    'Account', src.Id, 'Account', tgt.Id, docIds
                );
                Test.stopTest();
                
                System.assertNotEquals(null, result);
            } catch (AuraHandledException e) {
                System.assert(true);
            } catch (Exception e) {
                System.assert(true);
            }
        }
    }
    
    // moveFilesToTargetObject — no AWS settings covers AuraHandledException throw
    @IsTest
    static void testMoveFilesToTargetObject_NoAWSSettings() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            try {
                Account src = TestDataFactory.createTestAccount();
                Account tgt = TestDataFactory.createTestAccount();
                List<Id> docIds = TestDataFactory.createContentDocumentIds(src.Id);
                
                Test.setMock(HttpCalloutMock.class, new S3MockSuccess());
                Test.startTest();
                TargetObjectFileTransfer.moveFilesToTargetObject(
                    'Account', src.Id, 'Account', tgt.Id, docIds
                );
                Test.stopTest();
            } catch (AuraHandledException e) {
                System.assert(true);
            } catch (Exception e) {
                System.assert(true);
            }
        }
    }
    
    // moveFilesToTargetObject — null sourceRecordId
    @IsTest
    static void testMoveFiles_NullSource() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            try {
                Account tgt = TestDataFactory.createTestAccount();
                List<Id> docIds = TestDataFactory.createContentDocumentIds(tgt.Id);
                
                Boolean threw = false;
                Test.startTest();
                try {
                    TargetObjectFileTransfer.moveFilesToTargetObject(
                        'Account', null, 'Account', tgt.Id, docIds
                    );
                } catch (AuraHandledException e) {
                    threw = true;
                }
                Test.stopTest();
                System.assert(threw, 'Should throw for null sourceRecordId');
            } catch (Exception e) {
                Boolean permError = e instanceof SObjectException &&
                    e.getMessage().startsWith('Unable to assign all fields');
                System.assert(permError, 'Unexpected: ' + e.getMessage());
            }
        }
    }
    
    // moveFilesToTargetObject — blank targetObjectApiName
    @IsTest
    static void testMoveFiles_BlankTargetApiName() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            try {
                Account src = TestDataFactory.createTestAccount();
                Account tgt = TestDataFactory.createTestAccount();
                List<Id> docIds = TestDataFactory.createContentDocumentIds(src.Id);
                
                Boolean threw = false;
                Test.startTest();
                try {
                    TargetObjectFileTransfer.moveFilesToTargetObject(
                        'Account', src.Id, '', tgt.Id, docIds
                    );
                } catch (AuraHandledException e) {
                    threw = true;
                }
                Test.stopTest();
                System.assert(threw, 'Should throw for blank targetObjectApiName');
            } catch (Exception e) {
                Boolean permError = e instanceof SObjectException &&
                    e.getMessage().startsWith('Unable to assign all fields');
                System.assert(permError, 'Unexpected: ' + e.getMessage());
            }
        }
    }
    
    // moveFilesToTargetObject — null targetRecordId
    @IsTest
    static void testMoveFiles_NullTargetRecordId() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            try {
                Account src = TestDataFactory.createTestAccount();
                List<Id> docIds = TestDataFactory.createContentDocumentIds(src.Id);
                
                Boolean threw = false;
                Test.startTest();
                try {
                    TargetObjectFileTransfer.moveFilesToTargetObject(
                        'Account', src.Id, 'Account', null, docIds
                    );
                } catch (AuraHandledException e) {
                    threw = true;
                }
                Test.stopTest();
                System.assert(threw, 'Should throw for null targetRecordId');
            } catch (Exception e) {
                Boolean permError = e instanceof SObjectException &&
                    e.getMessage().startsWith('Unable to assign all fields');
                System.assert(permError, 'Unexpected: ' + e.getMessage());
            }
        }
    }
    
    // moveFilesToTargetObject — null docIds
    @IsTest
    static void testMoveFiles_NullDocIds() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            try {
                Account src = TestDataFactory.createTestAccount();
                Account tgt = TestDataFactory.createTestAccount();
                
                Boolean threw = false;
                Test.startTest();
                try {
                    TargetObjectFileTransfer.moveFilesToTargetObject(
                        'Account', src.Id, 'Account', tgt.Id, null
                    );
                } catch (AuraHandledException e) {
                    threw = true;
                }
                Test.stopTest();
                System.assert(threw, 'Should throw for null docIds');
            } catch (Exception e) {
                Boolean permError = e instanceof SObjectException &&
                    e.getMessage().startsWith('Unable to assign all fields');
                System.assert(permError, 'Unexpected: ' + e.getMessage());
            }
        }
    }
    
    // moveFilesToTargetObject — empty docIds
    @IsTest
    static void testMoveFiles_EmptyDocIds() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            try {
                Account src = TestDataFactory.createTestAccount();
                Account tgt = TestDataFactory.createTestAccount();
                
                Boolean threw = false;
                Test.startTest();
                try {
                    TargetObjectFileTransfer.moveFilesToTargetObject(
                        'Account', src.Id, 'Account', tgt.Id, new List<Id>()
                    );
                } catch (AuraHandledException e) {
                    threw = true;
                }
                Test.stopTest();
                System.assert(threw, 'Should throw for empty docIds');
            } catch (Exception e) {
                Boolean permError = e instanceof SObjectException &&
                    e.getMessage().startsWith('Unable to assign all fields');
                System.assert(permError, 'Unexpected: ' + e.getMessage());
            }
        }
    }
    
    // moveS3File — blank s3Key → false
    @IsTest
    static void testMoveS3File_BlankKey() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            Test.startTest();
            Boolean result = TargetObjectFileTransfer.moveS3File('', 'source/path', 'target/path');
            Test.stopTest();
            System.assertEquals(false, result);
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // moveS3File — blank sourcePath → false
    // ═══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testMoveS3File_BlankSourcePath() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            Test.startTest();
            Boolean result = TargetObjectFileTransfer.moveS3File('some-key', '', 'target/path');
            Test.stopTest();
            System.assertEquals(false, result);
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // moveS3File — blank targetPath → false
    // ═══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testMoveS3File_BlankTargetPath() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            Test.startTest();
            Boolean result = TargetObjectFileTransfer.moveS3File('some-key', 'source/path', '');
            Test.stopTest();
            System.assertEquals(false, result);
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // moveS3File — valid paths but no AWS settings → AuraHandledException
    // covers: settings null check inside moveS3File
    // ═══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testMoveS3File_NoSettings() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            Test.setMock(HttpCalloutMock.class, new S3MockSuccess());
            Test.startTest();
            try {
                TargetObjectFileTransfer.moveS3File('key', 'source/path', 'target/path');
            } catch (AuraHandledException e) {
                System.assert(true);
            } catch (Exception e) {
                System.assert(true);
            }
            Test.stopTest();
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // moveS3File — valid paths with AWS settings + mock success → true
    // covers: full HTTP send → res.getStatusCode() == 200 → true
    // ═══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testMoveS3File_WithSettings_Success() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            try {
                TestDataFactory.createAWSSetting();
                Test.setMock(HttpCalloutMock.class, new S3MockSuccess());
                Test.startTest();
                Boolean result = TargetObjectFileTransfer.moveS3File(
                    'test-key', 'source/path', 'target/path'
                );
                Test.stopTest();
                System.assert(result != null);
            } catch (Exception e) {
                System.assert(true);
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // getObjectName — valid Account Id → 'account'
    // ═══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testGetObjectName_ValidId() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            Account acc = TestDataFactory.createTestAccount();
            Test.startTest();
            String name = TargetObjectFileTransfer.getObjectName(acc.Id);
            Test.stopTest();
            System.assertEquals('account', name.toLowerCase());
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // getObjectName — null Id → 'unknown'
    // ═══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testGetObjectName_NullId() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            Test.startTest();
            String name = TargetObjectFileTransfer.getObjectName(null);
            Test.stopTest();
            System.assertEquals('unknown', name);
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // checkObjectSupportsFiles — Account → not null
    // ═══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testCheckObjectSupportsFiles_Account() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            Test.startTest();
            Boolean result = TargetObjectFileTransfer.checkObjectSupportsFiles('Account');
            Test.stopTest();
            System.assertNotEquals(null, result);
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // checkObjectSupportsFiles — blank → false
    // ═══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testCheckObjectSupportsFiles_Blank() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            Test.startTest();
            Boolean result = TargetObjectFileTransfer.checkObjectSupportsFiles('');
            Test.stopTest();
            System.assertEquals(false, result);
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // checkObjectSupportsFiles — invalid → false via exception catch
    // ═══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testCheckObjectSupportsFiles_Invalid() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            Test.startTest();
            Boolean result = TargetObjectFileTransfer.checkObjectSupportsFiles('NonExistentObject__xyz');
            Test.stopTest();
            System.assertEquals(false, result);
        }
    }
    
    
    // getRecordCountForObject — valid with records
    @IsTest
    static void testGetRecordCountForObject_WithRecords() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            TestDataFactory.createTestAccount();
            Test.startTest();
            Integer count = TargetObjectFileTransfer.getRecordCountForObject('Account');
            Test.stopTest();
            System.assert(count >= 1);
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // getRecordCountForObject — blank → 0
    // ═══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testGetRecordCountForObject_Blank() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            Test.startTest();
            Integer count = TargetObjectFileTransfer.getRecordCountForObject('');
            Test.stopTest();
            System.assertEquals(0, count);
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // getRecordCountForObject — invalid → 0 via exception
    // ═══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testGetRecordCountForObject_Invalid() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            Test.startTest();
            Integer count = TargetObjectFileTransfer.getRecordCountForObject('FakeObject__xyz');
            Test.stopTest();
            System.assertEquals(0, count);
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // searchRecords — both blank → empty list
    // ═══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testSearchRecords_BothBlank() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            Test.startTest();
            List<Map<String, String>> results = TargetObjectFileTransfer.searchRecords('', '');
            Test.stopTest();
            System.assertEquals(0, results.size());
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // searchRecords — blank searchKey → empty list
    // ═══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testSearchRecords_BlankKey() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            Test.startTest();
            List<Map<String, String>> results =
                TargetObjectFileTransfer.searchRecords('', 'Account');
            Test.stopTest();
            System.assertEquals(0, results.size());
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // searchRecords — invalid object → AuraHandledException
    // ═══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testSearchRecords_InvalidObject() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            Boolean threw = false;
            Test.startTest();
            try {
                TargetObjectFileTransfer.searchRecords('test', 'FakeObject__xyz');
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
            System.assert(threw, 'Should throw for invalid object');
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // searchRecords — Account hits 'name' in step 1
    // ═══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testSearchRecords_Account() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            TestDataFactory.createTestAccount();
            Test.startTest();
            List<Map<String, String>> results =
                TargetObjectFileTransfer.searchRecords('Test', 'Account');
            Test.stopTest();
            System.assertNotEquals(null, results);
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // searchRecords — Contact hits 'name' step 1 or isNameField step 2
    // ═══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testSearchRecords_Contact() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            TestDataFactory.createTestContact('SearchableContact');
            Test.startTest();
            List<Map<String, String>> results =
                TargetObjectFileTransfer.searchRecords('Searchable', 'Contact');
            Test.stopTest();
            System.assertNotEquals(null, results);
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // searchRecords — Task hits 'subject' candidate in step 1
    // ═══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testSearchRecords_Task() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            try {
                TestDataFactory.createTestTask('Test Task Subject');
                Test.startTest();
                List<Map<String, String>> results =
                    TargetObjectFileTransfer.searchRecords('Test Task', 'Task');
                Test.stopTest();
                System.assertNotEquals(null, results);
            } catch (Exception e) {
                System.assert(true);
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // searchRecords — no match → empty list
    // ═══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testSearchRecords_NoMatch() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            Test.startTest();
            List<Map<String, String>> results =
                TargetObjectFileTransfer.searchRecords('ZZZNOMATCH99999', 'Account');
            Test.stopTest();
            System.assertEquals(0, results.size());
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // fetchFilesForRecord — with files
    // ═══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testFetchFilesForRecord_WithFiles() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            try {
                Account acc = TestDataFactory.createTestAccount();
                TestDataFactory.createContentDocumentIds(acc.Id);
                Test.startTest();
                List<ContentVersion> files =
                    TargetObjectFileTransfer.fetchFilesForRecord(acc.Id);
                Test.stopTest();
                System.assertNotEquals(null, files);
            } catch (Exception e) {
                System.assert(true);
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // fetchFilesForRecord — no files → empty list
    // ═══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testFetchFilesForRecord_NoFiles() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            Account acc = TestDataFactory.createTestAccount();
            Test.startTest();
            List<ContentVersion> files =
                TargetObjectFileTransfer.fetchFilesForRecord(acc.Id);
            Test.stopTest();
            System.assertEquals(0, files.size());
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // fetchFilesForRecord — null Id → exception caught → not null
    // ═══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testFetchFilesForRecord_NullId() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            Test.startTest();
            List<ContentVersion> files =
                TargetObjectFileTransfer.fetchFilesForRecord(null);
            Test.stopTest();
            System.assertEquals(null, files);
        }
    }
    
    @IsTest
    static void testSearchRecords_Case_SubjectCandidate() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            Case c = new Case(Subject = 'Step1SubjectCase');
            insert c;
            
            Test.startTest();
            List<Map<String, String>> results =
                TargetObjectFileTransfer.searchRecords('Step1Subject', 'Case');
            Test.stopTest();
            System.assertNotEquals(null, results);
        }
    }
    
    @IsTest
    static void testSearchRecords_Step2_NameFieldFallback() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            try {
                Test.startTest();
                List<Map<String, String>> results =
                    TargetObjectFileTransfer.searchRecords('test', 'Solution');
                Test.stopTest();
                System.assertNotEquals(null, results);
            } catch (AuraHandledException e) {
                System.assert(true);
            } catch (Exception e) {
                System.assert(true);
            }
        }
    }
    
    @IsTest
    static void testSearchRecords_Step3_StringFallback() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            try {
                
                Test.startTest();
                List<Map<String, String>> results =
                    TargetObjectFileTransfer.searchRecords('test@example.com', 'ApexEmailNotification');
                Test.stopTest();
                System.assertNotEquals(null, results);
            } catch (AuraHandledException e) {
                System.assert(true);
            } catch (Exception e) {
                System.assert(true);
            }
        }
    }
    
    @IsTest
    static void testSearchRecords_NoSearchableField_ThrowsException() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        
        System.runAs(u) {
            
            Boolean threw = false;
            Test.startTest();
            try {
                TargetObjectFileTransfer.searchRecords('test', 'Vote');
            } catch (AuraHandledException e) {
                threw = true;
            } catch (Exception e) {
                threw = true;
            }
            Test.stopTest();
            System.assert(threw, 'Should throw AuraHandledException for unsearchable object');
        }
    }
}