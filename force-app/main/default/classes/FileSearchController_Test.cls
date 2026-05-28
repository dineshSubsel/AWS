@isTest
public class FileSearchController_Test {

    @testSetup
    static void setupData() {
        Folder__c folder = TestDataFactory.createTestFolder('Test Folder');

        List<Uploaded_file_info__c> files =
            TestDataFactory.createTestUploadedFiles(folder.Id);

        System.assert(files != null && files.size() > 0);
    }

    private static User runUser() {
        User u = TestDataFactory.createUser('Standard User');
        TestDataFactory.AssignAWSInternalPSet(u.Id);
        return u;
    }

    // ================= SEARCH =================
    @isTest
    static void testSearch() {
        User u = runUser();

        System.runAs(u) {
            Test.startTest();
            String res = FileSearchController.getSearchedFile('test', 1, 1);
            Test.stopTest();

            System.assertNotEquals(null, res);
        }
    }

    // ================= NULL SEARCH =================
    @isTest
    static void testSearchNull() {
        User u = runUser();

        System.runAs(u) {
            Test.startTest();
            String res = FileSearchController.getSearchedFile(null, null, null);
            Test.stopTest();

            System.assertNotEquals(null, res);
        }
    }

    // ================= CREATED DATE FILTER =================
    @isTest
    static void testCreatedDate() {
        User u = runUser();

        System.runAs(u) {
            String today = String.valueOf(Date.today());

            Test.startTest();
            String res = FileSearchController.filterfile(
                'test',
                'CreatedDate',
                'equal',
                today,
                10,
                1
            );
            Test.stopTest();

            System.assert(res != null);
        }
    }

    // ================= OBJECT NAME PATH =================
    @isTest
    static void testObjectNameFilter() {
        User u = runUser();

        System.runAs(u) {
            Test.startTest();
            String res = FileSearchController.filterfile(
                'test',
                'objectName',
                'equal',
                'Test Folder',
                10,
                1
            );
            Test.stopTest();

            System.assert(res != null);
        }
    }

    // ================= FILE TYPE PATH =================
    @isTest
    static void testFileTypeFilter() {
        User u = runUser();

        System.runAs(u) {
            Test.startTest();
            String res = FileSearchController.filterfile(
                'test',
                'fileType',
                'equal',
                'pdf',
                10,
                1
            );
            Test.stopTest();

            System.assert(res != null);
        }
    }

    // ================= INVALID FIELD =================
    @isTest
    static void testInvalidField() {
        User u = runUser();

        System.runAs(u) {
            Test.startTest();
            String res = FileSearchController.filterfile(
                'test',
                'xyz_invalid',
                'equal',
                'test',
                10,
                1
            );
            Test.stopTest();

            System.assert(res != null);
        }
    }

    // ================= INVALID OPERATOR =================
    @isTest
    static void testInvalidOperator() {
        User u = runUser();

        System.runAs(u) {
            String today = String.valueOf(Date.today());

            Test.startTest();
            String res = FileSearchController.filterfile(
                'test',
                'CreatedDate',
                'unknown',
                today,
                10,
                1
            );
            Test.stopTest();

            System.assert(res != null);
        }
    }

    // ================= RECENT FILES =================
    @isTest
    static void testRecent() {
        User u = runUser();

        System.runAs(u) {
            Test.startTest();
            String res = FileSearchController.getRecentlyUploadedfile(5, 1);
            Test.stopTest();

            System.assert(res != null);
        }
    }

    // ================= EDGE CASES =================
    @isTest
    static void testEdgeCases() {
        User u = runUser();

        System.runAs(u) {
            Test.startTest();

            FileSearchController.getRecentlyUploadedfile(0, 0);
            String res = FileSearchController.getSearchedFile('', 0, 0);

            Test.stopTest();

            System.assert(res != null);
        }
    }

    // ================= OPTIONS =================
    @isTest
    static void testOptions() {
        User u = runUser();

        System.runAs(u) {
            Test.startTest();

            String res1 = FileSearchController.getParentNameOptions();
            String res2 = FileSearchController.getFilterFields();

            Test.stopTest();

            System.assert(res1 != null);
            System.assert(res2 != null);
        }
    }

    // ================= WRAPPER EDGE =================
    @isTest
    static void testWrapperConversionEdge() {
        User u = runUser();

        System.runAs(u) {
            Folder__c folder = TestDataFactory.createTestFolder('Edge Folder');

            List<Uploaded_file_info__c> files =
                TestDataFactory.createTestUploadedFiles(folder.Id);

            files[0].File_Name__c = null;
            files[0].File_sizes__c = null;

            update files;

            Test.startTest();
            String res = FileSearchController.getRecentlyUploadedfile(10, 1);
            Test.stopTest();

            System.assert(res != null);
        }
    }
}