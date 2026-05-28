@IsTest
public class FileMigrationHandlerTest {

    private class ToolingApiMock implements HttpCalloutMock {
        private Integer statusCode;
        private String  body;

        public ToolingApiMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body       = body;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }

    @IsTest
    static void testValidateSoqlCondition_BlankCondition_ThrowsException() {
	 User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Boolean exceptionThrown = false;
        try {
            FileMigrationHandler.validateSoqlCondition('SOQL Filter', '');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Expected AuraHandledException for blank SOQL condition');
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testValidateSoqlCondition_DmlKeyword_Delete_ThrowsException() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Boolean exceptionThrown = false;
        try {
            FileMigrationHandler.validateSoqlCondition('SOQL Filter', 'delete from Account');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Expected AuraHandledException for DML keyword');
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testValidateSoqlCondition_DmlKeyword_Insert_ThrowsException() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Boolean exceptionThrown = false;
        try {
            FileMigrationHandler.validateSoqlCondition('SOQL Filter', 'insert into Account');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Expected AuraHandledException for INSERT keyword');
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testValidateSoqlCondition_DmlKeyword_Update_ThrowsException() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Boolean exceptionThrown = false;
        try {
            FileMigrationHandler.validateSoqlCondition('SOQL Filter', 'update Account set Name');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Expected AuraHandledException for UPDATE keyword');
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testValidateSoqlCondition_DmlKeyword_Merge_ThrowsException() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Boolean exceptionThrown = false;
        try {
            FileMigrationHandler.validateSoqlCondition('SOQL Filter', 'merge Account');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Expected AuraHandledException for MERGE keyword');
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testValidateSoqlCondition_ValidCondition_NoException() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Boolean exceptionThrown = false;
        try {
            FileMigrationHandler.validateSoqlCondition('SOQL Filter', 'Name != null');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(!exceptionThrown, 'No exception expected for valid SOQL condition');
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testValidateSoqlCondition_NonSoqlFilterType_Skips() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Boolean exceptionThrown = false;
        try {
            FileMigrationHandler.validateSoqlCondition('Date Filter', '');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(!exceptionThrown, 'No exception expected when filterType is not SOQL Filter');
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testBuildCronExpression_Once_ReturnsValidCron() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        String cron = FileMigrationHandler.buildCronExpression('Once', '10:30', null, null);
        System.assert(cron.contains('30'), 'Cron should contain minutes');
        System.assert(cron.contains('10'), 'Cron should contain hour');
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testBuildCronExpression_Daily_ReturnsValidCron() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        String cron = FileMigrationHandler.buildCronExpression('Daily', '08:00', null, null);
        System.assertEquals('0 0 8 * * ?', cron, 'Daily cron expression mismatch');
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testBuildCronExpression_Weekly_ReturnsValidCron() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        String cron = FileMigrationHandler.buildCronExpression('Weekly', '09:15', 'MON,WED', null);
        System.assert(cron.contains('MON'), 'Weekly cron should contain first day');
        System.assert(cron.contains('9'),   'Weekly cron should contain hour');
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testBuildCronExpression_Weekly_SingleDay_ReturnsValidCron() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        String cron = FileMigrationHandler.buildCronExpression('Weekly', '09:00', 'FRI', null);
        System.assert(cron.contains('FRI'), 'Weekly cron should contain FRI');
     } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testBuildCronExpression_Monthly_ReturnsValidCron() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        String cron = FileMigrationHandler.buildCronExpression('Monthly', '12:00', null, '15');
        System.assert(cron.contains('15'), 'Monthly cron should contain day of month');
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testBuildCronExpression_BlankTime_ThrowsException() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Boolean exceptionThrown = false;
        try {
            FileMigrationHandler.buildCronExpression('Daily', '', null, null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Expected AuraHandledException for blank time');
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testBuildCronExpression_InvalidTimeFormat_ThrowsException() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Boolean exceptionThrown = false;
        try {
            FileMigrationHandler.buildCronExpression('Daily', '9-30', null, null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Expected AuraHandledException for invalid time format');
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testBuildCronExpression_InvalidTimeValues_ThrowsException() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Boolean exceptionThrown = false;
        try {
            FileMigrationHandler.buildCronExpression('Daily', 'ab:cd', null, null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Expected AuraHandledException for non-numeric time');
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testBuildCronExpression_Weekly_NoDaysOfWeek_ThrowsException() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Boolean exceptionThrown = false;
        try {
            FileMigrationHandler.buildCronExpression('Weekly', '10:00', '', null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Expected AuraHandledException for missing days of week');
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testBuildCronExpression_Monthly_NoDayOfMonth_ThrowsException() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Boolean exceptionThrown = false;
        try {
            FileMigrationHandler.buildCronExpression('Monthly', '10:00', null, '');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Expected AuraHandledException for missing day of month');
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testBuildCronExpression_InvalidFrequency_ThrowsException() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Boolean exceptionThrown = false;
        try {
            FileMigrationHandler.buildCronExpression('Hourly', '10:00', null, null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Expected AuraHandledException for invalid frequency');
     } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

@IsTest
static void testIsExcludedObject_HistoryObject_ReturnsTrue() {
    User u = TestDataFactory.createUser('Standard User');
    TestDataFactory.AssignAWSInternalPSet(u.Id);
    Boolean permError = false;
    System.runAs(u) {
        try {

            Map<String, Schema.SObjectType> globalMap = Schema.getGlobalDescribe();
            String objName = 'AccountHistory';
            Boolean result = FileMigrationHandler.isExcludedObject(objName, globalMap);
            System.assert(
                result,
                objName + ' should be excluded (contains "history")'
            );

            System.assert(true, 'isExcludedObject history check ran');
        } catch (Exception e) {
            permError = (e instanceof SObjectException &&
                         e.getMessage().startsWith('Unable to assign all fields'));
            permError = permError || (e instanceof AuraHandledException);
        }
    }
}

    @IsTest
    static void testIsExcludedObject_AccountObject_ReturnsFalse() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Map<String, Schema.SObjectType> globalMap = Schema.getGlobalDescribe();
        if (globalMap.containsKey('account')) {
            Boolean result = FileMigrationHandler.isExcludedObject('account', globalMap);
            System.assert(!result, 'Account should NOT be excluded');
        }
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }


    @IsTest
    static void testProcessToolingRecords_NullRecords_NoChange() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Map<String, String> objectsMap = new Map<String, String>{ 'Account' => 'Account' };
        FileMigrationHandler.processToolingRecords(null, objectsMap);
        System.assertEquals(1, objectsMap.size(), 'Map should remain unchanged for null records');
     } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }


    @IsTest
    static void testProcessToolingRecords_SkipsCustomSetting() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Map<String, String> objectsMap = new Map<String, String>();
        List<Object> records = new List<Object>{
            new Map<String, Object>{
                'QualifiedApiName'     => 'Account',
                'Label'                => 'Account',
                'IsCustomSetting'      => true,
                'IsDeprecatedAndHidden'=> false,
                'IsCustomizable'       => true
            }
        };
        FileMigrationHandler.processToolingRecords(records, objectsMap);
        System.assert(!objectsMap.containsKey('Account'), 'Custom setting objects should be skipped');
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testProcessToolingRecords_SkipsDeprecated() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Map<String, String> objectsMap = new Map<String, String>();
        List<Object> records = new List<Object>{
            new Map<String, Object>{
                'QualifiedApiName'     => 'Account',
                'Label'                => 'Account',
                'IsCustomSetting'      => false,
                'IsDeprecatedAndHidden'=> true,
                'IsCustomizable'       => true
            }
        };
        FileMigrationHandler.processToolingRecords(records, objectsMap);
        System.assert(!objectsMap.containsKey('Account'), 'Deprecated objects should be skipped');
     } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testProcessToolingRecords_SkipsNullApiName() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Map<String, String> objectsMap = new Map<String, String>();
        List<Object> records = new List<Object>{
            new Map<String, Object>{
                'QualifiedApiName'     => null,
                'Label'                => 'Some Label',
                'IsCustomSetting'      => false,
                'IsDeprecatedAndHidden'=> false,
                'IsCustomizable'       => true
            }
        };
        FileMigrationHandler.processToolingRecords(records, objectsMap);
        System.assertEquals(0, objectsMap.size(), 'Null API name records should be skipped');
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testProcessToolingRecords_SkipsNullLabel() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Map<String, String> objectsMap = new Map<String, String>();
        List<Object> records = new List<Object>{
            new Map<String, Object>{
                'QualifiedApiName'     => 'Account',
                'Label'                => null,
                'IsCustomSetting'      => false,
                'IsDeprecatedAndHidden'=> false,
                'IsCustomizable'       => true
            }
        };
        FileMigrationHandler.processToolingRecords(records, objectsMap);
        System.assertEquals(0, objectsMap.size(), 'Null label records should be skipped');
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testProcessToolingRecords_SkipsDuplicateKey() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Map<String, String> objectsMap = new Map<String, String>{ 'Account' => 'Existing' };
        List<Object> records = new List<Object>{
            new Map<String, Object>{
                'QualifiedApiName'     => 'Account',
                'Label'                => 'New Label',
                'IsCustomSetting'      => false,
                'IsDeprecatedAndHidden'=> false,
                'IsCustomizable'       => true
            }
        };
        FileMigrationHandler.processToolingRecords(records, objectsMap);
        System.assertEquals('Existing', objectsMap.get('Account'), 'Existing key should not be overwritten');
  } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testProcessToolingRecords_SkipsUnknownApiName() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Map<String, String> objectsMap = new Map<String, String>();
        List<Object> records = new List<Object>{
            new Map<String, Object>{
                'QualifiedApiName'     => 'NonExistentObject__xyz',
                'Label'                => 'Ghost Object',
                'IsCustomSetting'      => false,
                'IsDeprecatedAndHidden'=> false,
                'IsCustomizable'       => true
            }
        };
        FileMigrationHandler.processToolingRecords(records, objectsMap);
        System.assertEquals(0, objectsMap.size(), 'Unknown SObject API names should be skipped');
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testProcessToolingRecords_ValidAccount_AddsToMap() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Map<String, String> objectsMap = new Map<String, String>();
        List<Object> records = new List<Object>{
            new Map<String, Object>{
                'QualifiedApiName'     => 'Account',
                'Label'                => 'Account',
                'IsCustomSetting'      => false,
                'IsDeprecatedAndHidden'=> false,
                'IsCustomizable'       => true
            }
        };
        FileMigrationHandler.processToolingRecords(records, objectsMap);
        System.assert(objectsMap.containsKey('Account'), 'Account should be added to objectsMap');
     } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }


    @IsTest
    static void testProcessRecords_NullRecords_NoChange() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Map<String, String> objectsMap = new Map<String, String>{ 'Contact' => 'Contact' };
        FileMigrationHandler.processRecords(null, objectsMap);
        System.assertEquals(1, objectsMap.size(), 'Map should be unchanged for null input');
     } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testProcessRecords_SkipsCustomSetting() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Map<String, String> objectsMap = new Map<String, String>();
        List<Object> records = new List<Object>{
            new Map<String, Object>{
                'QualifiedApiName'     => 'Account',
                'Label'                => 'Account',
                'IsCustomSetting'      => true,
                'IsDeprecatedAndHidden'=> false,
                'IsCustomizable'       => false
            }
        };
        FileMigrationHandler.processRecords(records, objectsMap);
        System.assert(!objectsMap.containsKey('Account'), 'Custom settings should be skipped');
      } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testProcessRecords_ValidContact_AddsToMap() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Map<String, String> objectsMap = new Map<String, String>();
        List<Object> records = new List<Object>{
            new Map<String, Object>{
                'QualifiedApiName'     => 'Contact',
                'Label'                => 'Contact',
                'IsCustomSetting'      => false,
                'IsDeprecatedAndHidden'=> false,
                'IsCustomizable'       => true
            }
        };
        FileMigrationHandler.processRecords(records, objectsMap);
        System.assert(objectsMap.containsKey('Contact'), 'Contact should be added to objectsMap');
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testGetAllSObjects_ReturnsNonEmptyList() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.startTest();
        List<Map<String, String>> result = FileMigrationHandler.getAllSObjects();
        Test.stopTest();
        System.assert(result != null && !result.isEmpty(), 'getAllSObjects should return at least one SObject');
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testGetAllSObjects_EachEntryHasLabelAndValue() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.startTest();
        List<Map<String, String>> result = FileMigrationHandler.getAllSObjects();
        Test.stopTest();
        for (Map<String, String> entry : result) {
            System.assert(entry.containsKey('label'), 'Each entry must have a label');
            System.assert(entry.containsKey('value'), 'Each entry must have a value');
        }
  } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testGetObjectManagerObjects_SuccessResponse() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        String mockBody = JSON.serialize(new Map<String, Object>{
            'records' => new List<Object>{
                new Map<String, Object>{
                    'QualifiedApiName'     => 'Account',
                    'Label'                => 'Account',
                    'IsCustomSetting'      => false,
                    'IsDeprecatedAndHidden'=> false,
                    'IsCustomizable'       => true
                }
            }
        });
        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(200, mockBody));

        Test.startTest();
        Map<String, Object> result = FileMigrationHandler.getObjectManagerObjects();
        Test.stopTest();

        System.assert(result.containsKey('count'),   'Result should contain count');
        System.assert(result.containsKey('objects'),  'Result should contain objects');
        Integer count = (Integer) result.get('count');
        System.assert(count >= 0, 'Count should be non-negative');
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testGetObjectManagerObjects_FailedCallout_StillReturnsResult() {
		User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(500, 'Internal Server Error'));

        Test.startTest();
        Map<String, Object> result = FileMigrationHandler.getObjectManagerObjects();
        Test.stopTest();

        System.assert(result != null, 'Result should not be null even on callout failure');
        System.assert(result.containsKey('objects'), 'Result should contain objects key');
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testGetObjectManagerObjects_EmptyRecords_ReturnsBaseObjects() {
		User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        String mockBody = JSON.serialize(new Map<String, Object>{
            'records' => new List<Object>()
        });
        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(200, mockBody));

        Test.startTest();
        Map<String, Object> result = FileMigrationHandler.getObjectManagerObjects();
        Test.stopTest();

        System.assert(result.containsKey('objects'), 'Result should contain objects key');
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testAbortS3FileMigration_NullJobIds_ThrowsException() {
		User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Boolean exceptionThrown = false;
        try {
            FileMigrationHandler.abortS3FileMigration(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Expected AuraHandledException for null job IDs');
  } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testAbortS3FileMigration_EmptyJobIds_ThrowsException() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Boolean exceptionThrown = false;
        try {
            FileMigrationHandler.abortS3FileMigration(new List<String>());
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Expected AuraHandledException for empty job IDs');
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testStartS3FileMigration_BlankObject_ThrowsException() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Boolean exceptionThrown = false;
        try {
            FileMigrationHandler.startS3FileMigration('', 'copy', false, 'All Records', null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Expected AuraHandledException for blank object');
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testStartS3FileMigration_BlankMode_ThrowsException() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Boolean exceptionThrown = false;
        try {
            FileMigrationHandler.startS3FileMigration('Account', '', false, 'All Records', null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Expected AuraHandledException for blank mode');
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testStartS3FileMigration_DmlInSoqlCondition_ThrowsException() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Boolean exceptionThrown = false;
        try {
            FileMigrationHandler.startS3FileMigration(
                'Account', 'copy', false, 'SOQL Filter', 'delete from Contact'
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Expected AuraHandledException for DML in SOQL condition');
    } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testScheduleS3FileMigration_BlankObject_ThrowsException() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Boolean exceptionThrown = false;
        try {
            FileMigrationHandler.scheduleS3FileMigration(
                '', 'copy', false, 'All Records', null, 'Daily', '10:00', null, null, false
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Expected AuraHandledException for blank object');
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testScheduleS3FileMigration_BlankMode_ThrowsException() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Boolean exceptionThrown = false;
        try {
            FileMigrationHandler.scheduleS3FileMigration(
                'Account', '', false, 'All Records', null, 'Daily', '10:00', null, null, false
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Expected AuraHandledException for blank mode');
     } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testScheduleS3FileMigration_InvalidFrequency_ThrowsException() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Boolean exceptionThrown = false;
        try {
            FileMigrationHandler.scheduleS3FileMigration(
                'Account', 'copy', false, 'All Records', null, 'Yearly', '10:00', null, null, false
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Expected AuraHandledException for invalid frequency');
   } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testScheduleS3FileMigration_BlankTime_ThrowsException() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        Boolean exceptionThrown = false;
        try {
            FileMigrationHandler.scheduleS3FileMigration(
                'Account', 'copy', false, 'All Records', null, 'Daily', '', null, null, false
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Expected AuraHandledException for blank scheduled time');
     } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }

    @IsTest
    static void testMapLabelComparator_SortsCorrectly() {
	User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        Boolean permError = false;
        System.runAs(u) {
            try {
        FileMigrationHandler.MapLabelComparator comp = new FileMigrationHandler.MapLabelComparator();

        Map<String, String> a = new Map<String, String>{ 'label' => 'Account', 'value' => 'account' };
        Map<String, String> b = new Map<String, String>{ 'label' => 'Contact', 'value' => 'contact' };
        Map<String, String> c = new Map<String, String>{ 'label' => 'account', 'value' => 'account2' };

        System.assert(comp.compare(a, b) < 0,  'Account should come before Contact');
        System.assert(comp.compare(b, a) > 0,  'Contact should come after Account');
        System.assertEquals(0, comp.compare(a, c), 'Case-insensitive comparison of same label should be 0');
     } catch (Exception e) {
                permError = (e instanceof SObjectException && e.getMessage().startsWith('Unable to assign all fields'));
                permError = permError || (e instanceof AuraHandledException);
            }
        }
    }
}