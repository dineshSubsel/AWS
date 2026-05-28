@isTest
public class ValidateFSLClassTest {
    @testSetup
    static void setupTestData() {
        // Create a test account record
        Account acc = new Account(Name = 'Test Account');
        insert acc;
    }

    @isTest
    static void testCheckUpdateAccessDynamic() {
        // Fetch the test account
        Account acc = [SELECT Id, Name FROM Account LIMIT 1];
        acc.Name = 'Updated Test Account';
        
        Test.startTest();
        try {
            Boolean result = ValidateFSLClass.checkUpdateAccessDynamic(new List<sObject>{acc});
            System.assertEquals(true, result, 'User should have update access to all fields.');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Unable to assign all fields for update'), 'Unexpected exception message: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testCheckCreateAccessDynamic() {
        // Create a new account record
        Account acc = new Account(Name = 'New Test Account');
        
        Test.startTest();
        try {
            Boolean result = ValidateFSLClass.checkCreateAccessDynamic(new List<sObject>{acc});
            System.assertEquals(true, result, 'User should have create access to all fields.');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Unable to assign all fields for Insert'), 'Unexpected exception message: ' + e.getMessage());
        }
        Test.stopTest();
    }
    
}