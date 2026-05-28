public with sharing class TestDataFactory { 
    
    public static User createUser(String profileName) {
        Profile userProfile = [SELECT Id FROM Profile WHERE Name = :profileName WITH SECURITY_ENFORCED LIMIT 1];
        User adminUser;          
        if (userProfile != null) {
            adminUser = new User(
                FirstName = 'Test',
                LastName = 'User',
                Username = 'testuser' + System.currentTimeMillis() + '@example.com',
                Email = 'testuser' + System.currentTimeMillis() + '@example.com',
                Alias = 'testu',
                TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                ProfileId = userProfile.Id,
                LanguageLocaleKey = 'en_US'
            );            
            /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(adminUser, AccessLevel.SYSTEM_MODE);         
        }                
        return adminUser; 
    }
    
    public static void AssignAWSAdminPSet(String userId) {    
        PermissionSet pset = [SELECT Id FROM PermissionSet WHERE Name = 'S3_org_Admin' WITH SECURITY_ENFORCED LIMIT 1];
        if (pset != null && userId != null) {
            assignPermissionSet(pset.Id, userId);
        }       
    }  
    
    public static void AssignAWSInternalPSet(String userId) {    
        PermissionSet pset = [SELECT Id FROM PermissionSet WHERE Name = 'S3_org_Standard' WITH SECURITY_ENFORCED LIMIT 1];
        if (pset != null && userId != null) {
            assignPermissionSet(pset.Id, userId);
        }       
    }  
    
    private static void assignPermissionSet(Id permissionSetId, String userId) {
        PermissionSetAssignment psa = new PermissionSetAssignment(AssigneeId = userId,
            PermissionSetId = permissionSetId
        );
        /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(psa, AccessLevel.SYSTEM_MODE); 
    }
   
    public static Uploaded_file_info__c createUploadedFileInfo(Id parentId, String parentName, String recordName) {
        Uploaded_file_info__c fileInfo = new Uploaded_file_info__c(
            Parent_Record_Id__c = parentId,
            Parent_Name__c = parentName,
            Parent_record_name__c = recordName,
            File_Type__c = 'pdf',
            File_url__c = 'https://s3.amazonaws.com/test-bucket/sample.pdf',
            File_Name__c = 'sample.pdf',
            ObjectKey__c = 'test/sample.pdf',
            File_sizes__c = '2.0');
        /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(fileInfo, AccessLevel.SYSTEM_MODE); 
        return fileInfo;
    }
    
    public static Uploaded_File_Info__c createUploadedFile(String fileName, String fileType, String fileUrl) {
        Uploaded_File_Info__c file = new Uploaded_File_Info__c(
            File_Name__c = fileName,
            File_Type__c = fileType,File_url__c = fileUrl);
        /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(file, AccessLevel.SYSTEM_MODE); 
        return file;
    }
    
    public static Folder__c createFolder(String name, String type, Id ownerId, Id parentId) {
        Folder__c folder = new Folder__c(Name = name, Type__c = type);
        if (ownerId != null) folder.OwnerId = ownerId;
        if (parentId != null) folder.Folder__c = parentId;
        /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(folder, AccessLevel.SYSTEM_MODE); 
        return folder;
    }
    
    public static List<Folder__c> createMultipleFolders() {
        return new List<Folder__c>{
            createFolder('Public Folder', 'public', null, null),
                createFolder('Private Folder', 'private', UserInfo.getUserId(), null),
                createFolder('Shared Folder', 'shared', UserInfo.getUserId(), null)
                };
                    }
    
    public static List<Uploaded_file_info__c> createFilesInFolder(Id folderId, Integer count) {
        List<Uploaded_file_info__c> files = new List<Uploaded_file_info__c>();
        for (Integer i = 0; i < count; i++) {
            files.add(new Uploaded_file_info__c(
                Folder__c = folderId,
                File_Name__c = 'File ' + i,
                ObjectKey__c = 'ObjectKey ' + i
            ));}
         /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(files, AccessLevel.SYSTEM_MODE); 
        return files;
    }
    
    public static Folder__Share createFolderShare(Id folderId, Id userId, String accessLevel) {

    Folder__Share share = new Folder__Share(
        ParentId = folderId,
        UserOrGroupId = userId,
        AccessLevel = accessLevel,
        RowCause = Schema.Folder__Share.RowCause.Manual
    );
    if (Schema.sObjectType.Folder__Share.isCreateable()) {
        /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(share, false);
    }
    return share;
}
    
    public static Uploaded_File_Info__c createTestFile(String fileName, String fileType, String fileUrl) {

    Uploaded_File_Info__c testFile = new Uploaded_File_Info__c(
        File_Name__c = fileName,
        File_Type__c = fileType,
        File_url__c  = fileUrl
    );

    Database.insert(testFile, AccessLevel.USER_MODE);

    return testFile;
}
    
    public static Folder__c createFolderHierarchy() { 
    Folder__c root = new Folder__c(Name = 'root',Type__c = 'public');
    /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(root, AccessLevel.SYSTEM_MODE); 
    Folder__c folder1 = new Folder__c(
        Name = 'folder1',
        Folder__c = root.Id,
        Type__c = 'public' 
    );
    /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(folder1, AccessLevel.SYSTEM_MODE); 
    Folder__c folder2 = new Folder__c(
        Name = 'folder2',
        Folder__c = folder1.Id,
        Type__c = 'public'   
    );
     /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(folder2, AccessLevel.SYSTEM_MODE); 
    return folder1; 
}
    
    public static Account createTestAccount() {
        Account acc = new Account(Name = 'Test Parent Account');
        /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(acc, AccessLevel.SYSTEM_MODE); 
        return acc;
    }
    
    public static List<Uploaded_file_info__c> createTestFilesUnderFolder(Id folderId, Integer count) {
        List<Uploaded_file_info__c> files = new List<Uploaded_file_info__c>();
        for (Integer i = 1; i <= count; i++) {
            files.add(new Uploaded_file_info__c(
                File_Name__c = 'SampleFile' + i + '.pdf',
                ObjectKey__c = 'public/sample/SampleFile' + i + '.pdf',
                Folder__c = folderId));}
         /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(files, AccessLevel.SYSTEM_MODE); 
        return files;
    }
    public static AWS_Settings__c createAWSSetting() {
        AWS_Settings__c awsSetting = new AWS_Settings__c();
        awsSetting.AWS_Access_Key_Id__c = 'testAccessKey';
        awsSetting.AWS_Secret_Access_Key__c = String.valueOf(Crypto.getRandomInteger()); 
        awsSetting.S3_Bucket_Name__c = 'testBucket';
        awsSetting.S3_Region_Name__c = 'test-east-01';
        awsSetting.API_Version__c = '2008-11-01';
        awsSetting.S3_Bucket_URL__c = 'https://test-bucket.s3.amazonaws.com'; 
        /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(awsSetting, AccessLevel.SYSTEM_MODE); 
        return awsSetting;
    }
    public static Folder__c createTestFolder(String name) {
        Folder__c folder = new Folder__c(Name = name);
         /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(folder, AccessLevel.SYSTEM_MODE); 
        return folder;
    }
    
   public static List<Uploaded_file_info__c> createTestUploadedFiles(Id parentFolderId) {
    Account acc1 = createTestAccount();
    Account acc2 = createTestAccount();
    List<Uploaded_file_info__c> files = new List<Uploaded_file_info__c>{
        new Uploaded_file_info__c(
            File_Name__c = 'FileOne',
            Parent_Name__c = parentFolderId,
            File_Type__c = 'image/jpeg'
        ),
        new Uploaded_file_info__c(
            File_Name__c = 'FileTwo',
            Parent_Name__c = acc1.Id, 
            File_Type__c = 'application/msword'
        ),
        new Uploaded_file_info__c(
            File_Name__c = 'FileThree',
            Parent_Name__c = acc2.Id,  
            File_Type__c = 'text/csv'
        ),
        new Uploaded_file_info__c(
            File_Name__c = 'SearchKeywordFile',
            Parent_Name__c = parentFolderId,
            File_Type__c = 'application/pdf'
        )};
      /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(files, AccessLevel.SYSTEM_MODE); 
    return files;
}
    
 public static void setupAWSFileUploadTestData() {
    Account acc = createTestAccount();
    User testUser = createUser('Standard User');
    Folder__c publicFolder = new Folder__c(
        Name = 'Public Test Folder',
        Type__c = 'public',
        Parent_Record_Id__c = acc.Id 
    );

    Folder__c privateFolder = new Folder__c(
        Name = 'Private Test Folder',
        Type__c = 'private',
        Parent_Record_Id__c = acc.Id  
    );

    insert new List<Folder__c>{publicFolder, privateFolder};
    List<Uploaded_file_info__c> files = new List<Uploaded_file_info__c>();
    for (Integer i = 0; i < 3; i++) {
        files.add(new Uploaded_file_info__c(
            File_Name__c = 'Public Test File ' + i,
            File_Type__c = 'pdf',
            File_sizes__c = '100KB',
            ObjectKey__c = 'test/public/file' + i + '.pdf',
            File_url__c = 'https://test/public/file' + i + '.pdf',
            Folder__c = publicFolder.Id,
            Parent_Record_Id__c = acc.Id   
        ));
    }

    for (Integer i = 0; i < 3; i++) {
        files.add(new Uploaded_file_info__c(
            File_Name__c = 'Private Test File ' + i,
            File_Type__c = 'pdf',
            File_sizes__c = '100KB',
            ObjectKey__c = 'test/private/file' + i + '.pdf',
            File_url__c = 'https://test/private/file' + i + '.pdf',
            Folder__c = privateFolder.Id,
            Parent_Record_Id__c = acc.Id   
        ));
    }

     /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(files, AccessLevel.SYSTEM_MODE); 
}
    
    public static List<Uploaded_File_Info__c> createUploadedFilesForAccount(Account acc, Integer fileCount) {
    List<Uploaded_File_Info__c> uploadedFiles = new List<Uploaded_File_Info__c>();

    for (Integer i = 0; i < fileCount; i++) {
        uploadedFiles.add(new Uploaded_File_Info__c(
            File_Name__c = 'TestFile' + i + '.pdf',
            Parent_Record_Name__c = acc.Name,
            Parent_Record_Id__c = acc.Id,
            ObjectKey__c = 'object-key-' + i,
            File_Url__c = 'https://example.com/file' + i,
            File_Sizes__c = '12345'
        ));
    }
    /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(uploadedFiles, AccessLevel.SYSTEM_MODE); 
    return uploadedFiles;
}

 public static Uploaded_file_info__c createTestUploadedFile(Id parentId) {
        Uploaded_file_info__c file = new Uploaded_file_info__c(
            File_Name__c = 'test.pdf',
            File_url__c = 'https://test.com/test.pdf',
            File_Type__c = 'pdf',
            ObjectKey__c = 'key',
            File_sizes__c = '1234',
            Parent_Record_Id__c = parentId);
        /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(file, AccessLevel.SYSTEM_MODE); 
        return file;
    }
    public static Folder__c createFolderForRecord(String name, String type, String parentObject, Id parentRecordId) {
    Folder__c folder = new Folder__c(
        Name = name,
        Type__c = 'public',
        Parent_Object__c = parentObject,
        Parent_Record_Id__c = parentRecordId);
     /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(folder, AccessLevel.SYSTEM_MODE); 
    return folder;
}

    public static List<Id> createContentDocumentIds(Id recordId){

    List<Id> docIds = new List<Id>();
    ContentVersion cv = new ContentVersion(
        Title = 'TestFile',
        PathOnClient = 'TestFile.pdf',
        VersionData = Blob.valueOf('Test File'),
        FirstPublishLocationId = recordId);
     /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(cv, AccessLevel.SYSTEM_MODE); 
    ContentVersion insertedVersion = [
        SELECT ContentDocumentId
        FROM ContentVersion
        WHERE Id = :cv.Id WITH SECURITY_ENFORCED LIMIT 1];
    docIds.add(insertedVersion.ContentDocumentId);
    return docIds;
}
public static File_Recovery_Log__c createFileRecoveryLog(Id recordId, String objectName) {
    File_Recovery_Log__c log = new File_Recovery_Log__c(
        File_Name__c = 'TestFile',
        S3_Key__c = 'test-key',
        Record_Id__c = recordId,
        Object_Name__c = objectName,
        Restore_Status__c = 'In Progress'
    );
    /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(log, AccessLevel.SYSTEM_MODE); 
    return log;
}

public static File_Recovery_Log__c createBackupFileRecoveryLog(Id recordId, String objectName) {
    File_Recovery_Log__c log = new File_Recovery_Log__c(
        File_Name__c      = 'BackupFile_' + objectName,
        S3_Key__c         = 'backups/' + objectName + '/test-key-' + System.currentTimeMillis(),
        Record_Id__c      = recordId,
        Object_Name__c    = objectName,
        Action_Type__c    = 'Backup',        
        Restore_Status__c = 'Completed',     
        Restore_Time__c   = DateTime.now()
    );
     /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(log, AccessLevel.SYSTEM_MODE); 
    return log;
}

public static File_Recovery_Log__c createEligibleBackupLog(Id recordId, String objectName) {
    File_Recovery_Log__c log = new File_Recovery_Log__c(
        File_Name__c      = 'BackupFile_' + objectName,
        S3_Key__c         = 'backups/' + objectName + '/key-' + System.currentTimeMillis(),
        Record_Id__c      = recordId,
        Object_Name__c    = objectName,
        Action_Type__c    = 'Backup',
        Backup_Status__c  = 'Success',
        Restore_Status__c = 'In Progress',
        Restore_Time__c   = DateTime.now());
    /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(log, AccessLevel.SYSTEM_MODE); 
    return log;
}

public static File_Recovery_Log__c createEligibleGroupBackupLog(Id recordId, String restoreType) {
    File_Recovery_Log__c log = new File_Recovery_Log__c(
        File_Name__c      = 'GroupBackup_' + restoreType,
        S3_Key__c         = 'backups/group/' + restoreType + '/key-' + System.currentTimeMillis(),
        Record_Id__c      = recordId,
        Object_Name__c    = restoreType + '_backup',
        Action_Type__c    = 'Backup',
        Backup_Status__c  = 'Success',
        Restore_Status__c = 'In Progress',
        Restore_Time__c   = DateTime.now());
    /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(log, AccessLevel.SYSTEM_MODE); 
    return log;
}
public static Account createDeletedAccount(String name) {
    Account acc = new Account(Name = name);
     /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(acc, AccessLevel.SYSTEM_MODE); 
    Database.delete(acc, AccessLevel.SYSTEM_MODE); 
    return acc;
}
public static File_Recovery_Log__c createRecycleBinBackupLog(String objectName, Id recordId) {
    File_Recovery_Log__c log = new File_Recovery_Log__c(
        File_Name__c      = 'test_file.csv',
        Object_Name__c    = objectName,
        S3_Key__c         = 'recycle-bin-backup/' + objectName + '/test.csv',
        Record_Id__c      = recordId,
        Action_Type__c    = 'Backup',
        Backup_Time__c    = DateTime.now(),
        Backup_Status__c  = 'Success',
        Restore_Status__c = 'In Progress',
        Recycle_Bin__c    = true
    );
   /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(log, AccessLevel.SYSTEM_MODE); 
    return log;
}
public static File_Recovery_Log__c createRecycleBinRestoreLog(String objectName, Id recordId) {
    File_Recovery_Log__c log = new File_Recovery_Log__c(
        File_Name__c      = 'test_file.csv',
        Object_Name__c    = objectName,
        S3_Key__c         = 'recycle-bin-backup/' + objectName + '/test.csv',
        Record_Id__c      = recordId,
        Action_Type__c    = 'Restore',
        Restore_Status__c = 'In Progress',
        Restore_Time__c   = DateTime.now(),
        Recycle_Bin__c    = true
    );
   /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(log, AccessLevel.SYSTEM_MODE); 
    return log;
}
public static File_Recovery_Log__c createScheduledRestoreIntentLog(String objectName) {
    File_Recovery_Log__c log = new File_Recovery_Log__c(
        File_Name__c      = 'Restore-' + objectName + '-2024-01-01',
        Object_Name__c    = objectName,
        Action_Type__c    = 'Restore',
        Restore_Status__c = 'Scheduled',
        Restore_Time__c   = DateTime.now()
    );
 /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(log, AccessLevel.SYSTEM_MODE); 
    return log;
}
public static Attachment createTestAttachment(Id parentId, String fileName, String contentType) {
    Attachment att = new Attachment(
        ParentId    = parentId,
        Name        = fileName,
        Body        = Blob.valueOf('Test file content'),
        ContentType = contentType
    );
   /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(att, AccessLevel.SYSTEM_MODE); 
    return att;
}

public static Contact createTestContact(String lastName) {
    Contact con = new Contact(LastName = lastName);
   /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(con, AccessLevel.SYSTEM_MODE); 
    return con;
}

public static Task createTestTask(String subject) {
    Task t = new Task(Subject = subject);
   /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(t, AccessLevel.SYSTEM_MODE); 
    return t;
}
public static Uploaded_file_info__c createUploadedFileInfoWithName(
    Id parentRecordId,
    String parentName,
    String fileName,
    String fileType,
    String fileUrl,
    String objectKey
) {
    Uploaded_file_info__c fileInfo = new Uploaded_file_info__c(
        Parent_Record_Id__c = parentRecordId,
        Parent_Name__c      = parentName,
        File_Name__c        = fileName,
        File_Type__c        = fileType,
        File_url__c         = fileUrl,
        ObjectKey__c        = objectKey,
        File_sizes__c       = '1.0'
    );
   /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(fileInfo, AccessLevel.SYSTEM_MODE); 
    return fileInfo;
}
 
}