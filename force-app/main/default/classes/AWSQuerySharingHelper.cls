public without sharing class AWSQuerySharingHelper {

    public static List<SObject> getRecordsToUpdate(String Id, String Type) {
    if (String.isBlank(Type)) return null;

    String queryString;

    if (Type.toLowerCase() == 'folder') {

        if (!Folder__Share.SObjectType.getDescribe().isAccessible() ||
            !Folder__Share.AccessLevel.getDescribe().isAccessible()) {
            return null;
        }

        queryString = 'SELECT Id, AccessLevel FROM Folder__Share ' +
                      'WHERE ParentId = :Id AND RowCause = \'Manual\' WITH SECURITY_ENFORCED';

    } else if (Type.toLowerCase() == 'file') {

        if (!Uploaded_File_Info__Share.SObjectType.getDescribe().isAccessible() ||
            !Uploaded_File_Info__Share.AccessLevel.getDescribe().isAccessible()) {
            return null;
        }

        queryString = 'SELECT Id, AccessLevel FROM Uploaded_File_Info__Share ' +
                      'WHERE ParentId = :Id AND RowCause = \'Manual\' WITH SECURITY_ENFORCED';

    } else {
        return null;
    }

    try {
        List<SObject> queried = Database.query(queryString);
        List<SObject> cleanRecords = new List<SObject>();

        for (SObject rec : queried) {
            SObject clean = rec.getSObjectType().newSObject((Id)rec.get('Id'));
            clean.put('AccessLevel', rec.get('AccessLevel'));
            cleanRecords.add(clean);
        }

        return cleanRecords;

    } catch (Exception e) {
        return null;
    }
}


// Folder__c
public static List<Folder__c> getAllFolders() {

    if (!Folder__c.SObjectType.getDescribe().isAccessible() ||
        !Folder__c.Name.getDescribe().isAccessible() ||
        !Folder__c.Folder__c.getDescribe().isAccessible()) {
        return new List<Folder__c>();
    }

    try {
        return [
            SELECT Id, Name, Folder__c
            FROM Folder__c
            WITH SECURITY_ENFORCED
        ];

    } catch (Exception e) {
        return new List<Folder__c>();
    }
}

     //Uploaded_File_Info__c
public static Uploaded_File_Info__c getUploadedFileInfoById(String recordId) {

    if (String.isBlank(recordId)) {
        return null;
    }

    // CRUD/FLS Check
    if (!Uploaded_File_Info__c.SObjectType.getDescribe().isAccessible() ||
        !Uploaded_File_Info__c.Parent_Record_Id__c.getDescribe().isAccessible()) {
        return null;
    }

    try {

        List<Uploaded_File_Info__c> records = [
            SELECT Id, Parent_Record_Id__c
            FROM Uploaded_File_Info__c
            WHERE Id = :recordId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        return records.isEmpty() ? null : records[0];

    } catch (Exception e) {
        return null;
    }
}

    @AuraEnabled(cacheable=true)
    public static List<Utils.UploadFileInfo> getUploadedFileInfosByParentId(Id parentRecordId) {
        List<Utils.UploadFileInfo> result = new List<Utils.UploadFileInfo>();
        if (parentRecordId == null) {
            return result;
        }
        try {
            List<Uploaded_File_Info__c> fileList = [
                SELECT Id, File_Name__c, Parent_Record_Name__c, Parent_Record_Id__c,
                       ObjectKey__c, File_Url__c, File_Sizes__c, CreatedDate, CreatedBy.Name
                FROM Uploaded_File_Info__c
                WHERE Parent_Record_Id__c = :parentRecordId
                WITH SECURITY_ENFORCED
            ];

            for (Uploaded_File_Info__c file : fileList) {
                Utils.UploadFileInfo wrapper = new Utils.UploadFileInfo();
                wrapper.id = file.Id;
                wrapper.fileName = file.File_Name__c;
                wrapper.fileURL = file.File_Url__c;
                wrapper.fileSize = file.File_Sizes__c;
                wrapper.parentRecordId = file.Parent_Record_Id__c;
                wrapper.objectKey = file.ObjectKey__c;
                wrapper.createdDate = file.CreatedDate;
                wrapper.uploadedBy = file.CreatedBy.Name;
                result.add(wrapper);
            }

        } catch (Exception e) {
            return new List<Utils.UploadFileInfo>();
        }

        return result;
    }

    public static List<Uploaded_File_Info__c> getUploadedFileInfosByFolderId(Id folderId) {
        if (folderId == null) {
            return new List<Uploaded_File_Info__c>();
        }

        try {
            return [
                SELECT Id,
                       File_Name__c,
                       Parent_Record_Name__c,
                       Parent_Record_Id__c,
                       ObjectKey__c,
                       File_Url__c,
                       File_Sizes__c,
                       CreatedDate,
                       CreatedBy.Name
                FROM Uploaded_File_Info__c
                WHERE Folder__c = :folderId
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception e) {
            return new List<Uploaded_File_Info__c>();
        }
    }


    public class wrapperUploadedfileinfo {
        public Integer recordStart {get; set;}
        public Integer pageNumber {get; set;}
        public Integer totalRecords {get; set;}
        public Integer recordEnd {get; set;}
        public Integer pageSize {get; set;}
        public List<Uploaded_file_info__c> uploadedfile {get; set;}
    }


    public static List<Uploaded_file_info__c> getAWSFilesByParentAndFolderType(String parentId, String foldertype) {
        try {
            if (String.isBlank(parentId) || String.isBlank(foldertype)) {
                return new List<Uploaded_file_info__c>();
            }

            String userId = UserInfo.getUserId();
            if (userId == null) {
                return new List<Uploaded_file_info__c>();
            }

            String baseQuery =
                'SELECT Id, File_Name__c, CreatedBy.Name, File_sizes__c, CreatedDate, ObjectKey__c, ' +
                'File_Type__c, File_url__c, LastModifiedDate, CreatedById, OwnerId ' +
                'FROM Uploaded_file_info__c';

            String orderBy = ' ORDER BY File_Name__c';
            String securityClause = ' WITH SECURITY_ENFORCED';
            String whereClause = '';

            if (foldertype == 'private') {
                List<Folder__Share> folderShares = [
                    SELECT Id
                    FROM Folder__Share
                    WHERE UserOrGroupId = :userId AND RowCause = 'Manual'
                    WITH SECURITY_ENFORCED
                ];

                if (!folderShares.isEmpty()) {
                    whereClause = ' WHERE Folder__c = :parentId';
                    return Database.query(baseQuery + whereClause + securityClause + orderBy);
                } else {
                    whereClause = ' WHERE Folder__c = :parentId AND CreatedById = :userId AND OwnerId = :userId';
                    return Database.query(baseQuery + whereClause + securityClause + orderBy);
                }
            } else if (foldertype == 'shared') {
                List<Uploaded_File_Info__Share> fileShares = [
                    SELECT ParentId
                    FROM Uploaded_File_Info__Share
                    WHERE UserOrGroupId = :userId AND RowCause = 'Manual'
                    WITH SECURITY_ENFORCED
                ];

                Set<Id> fileIds = new Set<Id>();
                for (Uploaded_File_Info__Share share : fileShares) {
                    fileIds.add(share.ParentId);
                }

                if (!fileIds.isEmpty()) {
                    whereClause = ' WHERE Id IN :fileIds';
                    return Database.query(baseQuery + whereClause + securityClause + orderBy);
                } else {
                    return new List<Uploaded_file_info__c>();
                }
            } else if (foldertype == 'public') {
                whereClause = ' WHERE Folder__c = :parentId AND Folder__r.Type__c = \'public\'';
                return Database.query(baseQuery + whereClause + securityClause + orderBy);
            } else {
                return new List<Uploaded_file_info__c>();
            }

        } catch (Exception e) {
            return new List<Uploaded_file_info__c>();
        }
    }

    public static List<User> getUsersByProfile() {
        try {
            List<String> userProfile = (System.Label.User_filter).split(',');
            String currentUserId = UserInfo.getUserId();

            String queryString = 'SELECT Id, Name FROM User WHERE Profile.Name IN :userProfile AND Id != :currentUserId WITH SECURITY_ENFORCED';
            return Database.query(queryString);
        } catch (Exception e) {
            return new List<User>();
        }
    }


    public static String getSharingDetailsByParentIdAndType(String parentId, String type) {
        try {
            String queryString = 'SELECT Id, AccessLevel, RowCause, UserOrGroup.Name, Parent.Name, UserOrGroup.Type FROM ';

            if (type == 'folder') {
                queryString += 'Folder__Share';
            } else if (type == 'file') {
                queryString += 'Uploaded_File_Info__Share';
            } else {
                return null;
            }

            queryString += ' WHERE ParentId = :parentId WITH SECURITY_ENFORCED';

            return JSON.serialize(Database.query(queryString));
        } catch (Exception e) {
            return null;
        }
    }

    public static Boolean removeAccessByIdsAndType(List<Id> IDs, String type) {
        try {
            if (IDs == null || IDs.isEmpty()) {
                return false;
            }

            String queryString = 'SELECT Id FROM ';

            if (type == 'folder') {
                queryString += 'Folder__Share';
            } else if (type == 'file') {
                queryString += 'Uploaded_File_Info__Share';
            } else {
                return false;
            }
            queryString += ' WHERE Id IN :IDs WITH SECURITY_ENFORCED';
            List<SObject> recordsToDelete = Database.query(queryString);

            if (!recordsToDelete.isEmpty()) {
                /* sfge-disable-next-line ApexFlsViolationRule */
                Database.delete(recordsToDelete, AccessLevel.SYSTEM_MODE);
                return true;
            }

            return false;
        } catch (Exception e) {
            return false;
        }
    }

    public static Boolean checkAccessAndOwnership(
    String fileId,
    String objectName
) {

    if (String.isBlank(fileId) ||
        String.isBlank(objectName)) {

        return false;
    }

    Boolean hasAccess = false;

    try {

        Id recordId;

        try {

            recordId = (Id) fileId;

        } catch (Exception ex) {

            return false;
        }

        if (recordId == null) {
            return false;
        }

        Id userId = UserInfo.getUserId();

        if (userId == null) {
            return false;
        }

        if (objectName == 'file') {

            List<Uploaded_file_info__c> files = [

                SELECT Id,
                       CreatedById,
                       OwnerId

                FROM Uploaded_file_info__c

                WHERE Id = :recordId

                WITH SECURITY_ENFORCED

                LIMIT 1
            ];

            if (!files.isEmpty()) {

                Uploaded_file_info__c file = files[0];

                if (file.CreatedById == userId &&
                    file.OwnerId == userId) {

                    hasAccess = true;
                }
            }

        } else if (objectName == 'folder') {

            List<Folder__c> folders = [

                SELECT Id,
                       CreatedById,
                       OwnerId

                FROM Folder__c

                WHERE Id = :recordId

                WITH SECURITY_ENFORCED

                LIMIT 1
            ];

            if (!folders.isEmpty()) {

                Folder__c folder = folders[0];

                if (folder.CreatedById == userId &&
                    folder.OwnerId == userId) {

                    hasAccess = true;
                }
            }
        }

        return hasAccess;

    } catch (Exception e) {

        return false;
    }
}
public static String getPaginatedAWSFiles(
    String parentId,
    Integer pageSize,
    Integer pageNumber
) {
    if (String.isBlank(parentId)) {
        throw new AuraHandledException('Parent Id cannot be null');
    }

    Id validId;
    try {
        validId = (Id) parentId;
    } catch (Exception e) {
        throw new AuraHandledException('Invalid record Id');
    }
    if (validId == null) {
        throw new AuraHandledException('Invalid record Id');
    }

    Integer safePageSize = 10;
    if (pageSize != null && pageSize > 0) {
        safePageSize = pageSize;
    }

    Integer safePageNumber = 1;
    if (pageNumber != null && pageNumber > 0) {
        safePageNumber = pageNumber;
    }

    Integer safeOffset = (safePageNumber - 1) * safePageSize;

    Integer finalLimitValue = safePageSize;
    Integer finalOffsetValue = safeOffset;

    if (finalLimitValue == null) {
        finalLimitValue = 10;
    }
    if (finalOffsetValue == null) {
        finalOffsetValue = 0;
    }

    Integer totalRecords = [
        SELECT COUNT()
        FROM Uploaded_file_info__c
        WHERE Parent_Record_Id__c = :validId
        WITH SECURITY_ENFORCED
    ];

    wrapperUploadedfileinfo wrapper = new wrapperUploadedfileinfo();
    wrapper.pageNumber   = safePageNumber;
    wrapper.pageSize     = finalLimitValue;
    wrapper.recordStart  = finalOffsetValue + 1;
    wrapper.recordEnd    = Math.min(finalLimitValue * safePageNumber, totalRecords);
    wrapper.totalRecords = totalRecords;
    wrapper.uploadedfile = [
        SELECT Id,
               Parent_record_name__c,
               File_Name__c,
               Parent_Name__c,
               CreatedBy.Name,
               Parent_Record_Id__c,
               File_sizes__c,
               CreatedDate,
               ObjectKey__c,
               File_Type__c,
               Owner_Name__c
        FROM Uploaded_file_info__c
        WHERE Parent_Record_Id__c = :validId
        WITH SECURITY_ENFORCED
        ORDER BY CreatedDate DESC
        LIMIT :finalLimitValue
        OFFSET :finalOffsetValue
    ];

    return JSON.serialize(wrapper);
}
    public static Uploaded_file_info__c getFileRecordById(String recordId) {
        if (String.isBlank(recordId)) {
            return null;
        }
        try {
            List<Uploaded_file_info__c> records = [
                SELECT Id, Parent_Record_Id__c
                FROM Uploaded_file_info__c
                WHERE Id = :recordId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            return records.isEmpty() ? null : records[0];
        } catch (Exception e) {
            return null;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Utils.UploadFileInfo> getFilesByParentId(Id parentId) {
        if (parentId == null) {
            return new List<Utils.UploadFileInfo>();
        }

        List<Utils.UploadFileInfo> result = new List<Utils.UploadFileInfo>();

        try {
            for (Uploaded_File_Info__c file : [
                SELECT Id, File_Name__c, File_URL__c, File_Type__c, File_sizes__c,
                       CreatedDate, ObjectKey__c, CreatedBy.Name
                FROM Uploaded_File_Info__c
                WHERE Parent_Record_Id__c = :parentId
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
            ]) {
                Utils.UploadFileInfo wrapper = new Utils.UploadFileInfo();
                wrapper.id = file.Id;
                wrapper.fileName = file.File_Name__c;
                wrapper.fileURL = file.File_URL__c;
                wrapper.fileType = file.File_Type__c;
                wrapper.fileSize = file.File_sizes__c;
                wrapper.createdDate = file.CreatedDate;
                wrapper.objectKey = file.ObjectKey__c;
                wrapper.uploadedBy = file.CreatedBy.Name;
                result.add(wrapper);
            }
        } catch (Exception e) {
            return new List<Utils.UploadFileInfo>();
        }

        return result;
    }

    public static Map<String, Folder__c> getAllFolderById(Set<String> folderIds) {
        if (folderIds != null && !folderIds.isEmpty()) {
            Map<String, Folder__c> foldersMap = new Map<String, Folder__c>();
            try {
                for (Folder__c folder : [
                    SELECT Id, Name
                    FROM Folder__c
                    WHERE Id IN :folderIds
                    WITH SECURITY_ENFORCED
                ]) {
                    foldersMap.put(folder.Id, folder);
                }
                if (!foldersMap.isEmpty()) {
                    return foldersMap;
                }
            } catch (Exception e) {
                return null;
            }
        }
        return null;
    }

    public static List<Folder__c> getRootFolders() {
        try {
            return [
                SELECT Id, Name, Folder__c, Type__c, CreatedById, OwnerId
                FROM Folder__c
                WHERE Folder__c = null
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception e) {
            return new List<Folder__c>();
        }
    }

    public static List<Folder__c> getChildFolders(
    String parentId,
    String type
) {

    if (String.isBlank(parentId) ||
        String.isBlank(type)) {

        return new List<Folder__c>();
    }

    Id recordId;
    Id userId;

    try {

        recordId = (Id) parentId;
        userId   = UserInfo.getUserId();

    } catch (Exception e) {

        return new List<Folder__c>();
    }

    if (recordId == null) {
        return new List<Folder__c>();
    }

    if (userId == null) {
        return new List<Folder__c>();
    }

    List<Folder__c> folders = new List<Folder__c>();

    try {

        Id safeRecordId = recordId;
        Id safeUserId   = userId;

        if (safeRecordId == null || safeUserId == null) {
            return new List<Folder__c>();
        }

        if (type == 'private') {

            folders = [
                SELECT Id,
                       Name,
                       Folder__c,
                       Type__c,
                       CreatedById,
                       OwnerId
                FROM Folder__c
                WHERE Folder__c = :safeRecordId
                AND CreatedById = :safeUserId
                AND OwnerId = :safeUserId
                WITH SECURITY_ENFORCED
            ];

        } else if (type == 'shared') {

            Set<Id> sharedFolderIds = new Set<Id>();

            for (Folder__Share shareRecord : [
                SELECT Id,
                       UserOrGroupId,
                       ParentId
                FROM Folder__Share
                WHERE UserOrGroupId = :safeUserId
                AND RowCause = 'Manual'
                WITH SECURITY_ENFORCED
            ]) {

                if (shareRecord != null &&
                    shareRecord.ParentId != null) {

                    sharedFolderIds.add(shareRecord.ParentId);
                }
            }

            if (!sharedFolderIds.isEmpty()) {

                folders = [
                    SELECT Id,
                           Name,
                           Folder__c,
                           Type__c,
                           CreatedById,
                           OwnerId
                    FROM Folder__c
                    WHERE Id IN :sharedFolderIds
                    WITH SECURITY_ENFORCED
                ];
            }

        } else {

            folders = [
                SELECT Id,
                       Name,
                       Folder__c,
                       Type__c,
                       CreatedById,
                       OwnerId
                FROM Folder__c
                WHERE Folder__c = :safeRecordId
                AND Type__c = 'public'
                WITH SECURITY_ENFORCED
            ];
        }

    } catch (Exception e) {

        return new List<Folder__c>();
    }

    return folders;
}

    public static Folder__c getFolderByIds(Id recordId) {
        if(recordId == null){
            return null;
        }
        try {
            List<Folder__c> folders = [
                SELECT Name, Folder__c.Type__c
                FROM Folder__c
                WHERE Id = :recordId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            return folders.isEmpty() ? null : folders[0];
        } catch (Exception e) {
            return null;
        }
    }

    public static Folder__c getParentFolder(Id parentId) {
        if(parentId == null){
            return null;
        }
        try {
            List<Folder__c> folders = [
                SELECT Name, Folder__r.Id
                FROM Folder__c
                WHERE Id = :parentId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            return folders.isEmpty() ? null : folders[0];
        } catch (Exception e) {
            return null;
        }
    }

    public static List<Uploaded_file_info__c> getFilesInFolder(Id folderId) {
           if(folderId == null){
             return new List<Uploaded_file_info__c>();
        }
        try {
            return [
                SELECT Folder__r.Name, Id, File_Name__c, ObjectKey__c
                FROM Uploaded_file_info__c
                WHERE Folder__c = :folderId
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception e) {
            return new List<Uploaded_file_info__c>();
        }
    }

    public static List<Folder__c> getChildFolders(Id folderId) {
           if(folderId == null){
             return new List<Folder__c>();
        }
        try {
            return [
                SELECT Id, Name
                FROM Folder__c
                WHERE Folder__c = :folderId
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception e) {
            return new List<Folder__c>();
        }
    }

    public static Folder__c getSingleFolderById(Id folderId) {
          if(folderId == null){
             return null;
        }
        try {
            List<Folder__c> folders = [
                SELECT Id, Name
                FROM Folder__c
                WHERE Id = :folderId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            return folders.isEmpty() ? null : folders[0];
        } catch (Exception e) {
            return null;
        }
    }

    public static List<Folder__c> getRootParentFolders() {
        try {
            return [
                SELECT Id, Name, Folder__c, Type__c
                FROM Folder__c
                WHERE Folder__c = NULL
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception e) {
            return new List<Folder__c>();
        }
    }

    public static List<Folder__c> getAllFolder() {
        try {
            return [
                SELECT Id, Name, Folder__c, Type__c, CreatedById, OwnerId
                FROM Folder__c
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception e) {
            return new List<Folder__c>();
        }
    }

    public static List<Folder__c> getChildFoldersByParentName(String parentName) {
          if(parentName == null){
             return new List<Folder__c>();
        }
        try {
            return [
                SELECT Id, Name, Folder__c
                FROM Folder__c
                WHERE Folder__r.Name = :parentName
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception e) {
            return new List<Folder__c>();
        }
    }

    public static List<Folder__c> getPrivateFolders(String folderId, String userId) {
        if(folderId == null){
            return new List<Folder__c>();
        }
         if(userId == null){
            return  new List<Folder__c>();
        }
        try {
            return [
                SELECT Id, Name, CreatedDate, CreatedBy.Name, Type__c, CreatedById, OwnerId
                FROM Folder__c
                WHERE Folder__c = :folderId
                AND CreatedById = :userId
                AND OwnerId = :userId
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception e) {
            return new List<Folder__c>();
        }
    }

    public static List<Folder__c> getSharedFolderList(String folderId) {
        if(folderId == null){
              return new List<Folder__c>(); 
        }
        try {
            return [
                SELECT Id, Name, CreatedDate, CreatedBy.Name, Type__c, CreatedById, OwnerId
                FROM Folder__c
                WHERE Folder__c = :folderId
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception e) {
            return new List<Folder__c>();
        }
    }

    public static Boolean isFolderSharedWithUser(String folderId, String userId) {
        if(folderId == null){
            return false;
        }
          if(userId == null){
            return false;
        }
        try {
            List<Folder__share> folderShares = [
                SELECT Id, ParentId, RowCause
                FROM Folder__share
                WHERE UserOrGroupId = :userId AND ParentId = :folderId
                WITH SECURITY_ENFORCED
            ];

            for (Folder__share share : folderShares) {
                if (share.RowCause == Schema.Folder__Share.RowCause.Manual) {
                    return true;
                }
            }
            return false;
        } catch (Exception e) {
            return false;
        }
    }

    public static List<Folder__c> getSharedFolders(String userId) {
        if(userId == null){
            return new List<Folder__c>();
        }
        try {
            List<Folder__share> shares = [
                SELECT ParentId
                FROM Folder__share
                WHERE UserOrGroupId = :userId AND RowCause = 'Manual'
                WITH SECURITY_ENFORCED
            ];
            Set<Id> folderIds = new Set<Id>();
            for (Folder__share share : shares) {
                folderIds.add(share.ParentId);
            }

            return [
                SELECT Id, Name, CreatedDate, CreatedBy.Name, Type__c, CreatedById, OwnerId
                FROM Folder__c
                WHERE Id IN :folderIds
                WITH SECURITY_ENFORCED
                ORDER BY Name
            ];
        } catch (Exception e) {
            return new List<Folder__c>();
        }
    }

    public static List<Folder__c> getPublicFolders(String folderId) {
        if(folderId == null){
            return new List<Folder__c>();
        }
        try {
            return [
                SELECT Id, Name, CreatedDate, CreatedBy.Name, Type__c, CreatedById, OwnerId
                FROM Folder__c
                WHERE Folder__c = :folderId AND Type__c = 'public'
                WITH SECURITY_ENFORCED
                ORDER BY Name
            ];
        } catch (Exception e) {
            return new List<Folder__c>();
        }
    }

    public static Map<String, Object> getRecentlyUploadedFiles(Integer pageSize, Integer pageNumber) {
        try {
            Integer offset = (pageNumber - 1) * pageSize;
              if(offset == null){
            offset = 0;
          }
            Integer totalRecords = [SELECT COUNT() FROM Uploaded_file_info__c WITH SECURITY_ENFORCED];

            List<Uploaded_file_info__c> files = [
                SELECT Id, File_Name__c, File_Type__c, CreatedDate, File_sizes__c,
                       CreatedBy.Name, ObjectKey__c, Parent_Record_Id__c
                FROM Uploaded_file_info__c
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
                LIMIT :pageSize
                OFFSET :offset
            ];

            Integer recordStart = offset + 1;
            Integer recordEnd = Math.min(offset + pageSize, totalRecords);

            Map<String, Object> response = new Map<String, Object>{
                'uploadedfile' => files,
                'totalRecords' => totalRecords,
                'recordStart' => recordStart,
                'recordEnd' => recordEnd,
                'pageNumber' => pageNumber
            };

            return response;
        } catch (Exception e) {
            return new Map<String, Object>();
        }
    }

    public static void insertUploadedFileInfo(Uploaded_file_info__c fileInfo) {
        if (fileInfo != null) {
            /* sfge-disable-next-line ApexFlsViolationRule */
            Database.insert(fileInfo, AccessLevel.SYSTEM_MODE);
        }
    }

    public static void insertsFolder(Folder__c newFolder) {
          if(newFolder == null){
            return;
        }
        if (newFolder != null) {
            /* sfge-disable-next-line ApexFlsViolationRule */
            Database.insert(newFolder, AccessLevel.SYSTEM_MODE);
        }
    }

  public static Database.SaveResult insertFolderShare(folder__share folderShareRecord) {
        if (folderShareRecord != null) {
            /* sfge-disable-next-line ApexFlsViolationRule */
            Database.SaveResult sr =
                Database.insert(folderShareRecord, AccessLevel.SYSTEM_MODE);
            return sr;
        }
        return null;
    }

  public static Database.SaveResult insertFileShare(
    Uploaded_File_Info__share fileShareRecord) {
    if (fileShareRecord != null) {
        /* sfge-disable-next-line ApexFlsViolationRule */
        Database.SaveResult sr =
            Database.insert(fileShareRecord, AccessLevel.SYSTEM_MODE);
        return sr;
    }
    return null;
}
    public static void insertFolderList(List<Folder__c> folderRecordList) {
        if (folderRecordList != null && !folderRecordList.isEmpty()) {
            /* sfge-disable-next-line ApexFlsViolationRule */
            Database.insert(folderRecordList, AccessLevel.SYSTEM_MODE);
        }
    }

    public static void updateUploadedFileUrl(Uploaded_File_Info__c fileRecord) {
        if (fileRecord != null) {
            /* sfge-disable-next-line ApexFlsViolationRule */
            Database.update(fileRecord, AccessLevel.SYSTEM_MODE);
        }
    }

    public static void updateAccessLevel(List<SObject> recordsToUpdate) {
        try {
            if (recordsToUpdate == null || recordsToUpdate.isEmpty()) {
                return;
            }
            /* sfge-disable-next-line ApexFlsViolationRule */
            Database.update(recordsToUpdate, AccessLevel.SYSTEM_MODE);
        } catch (Exception e) {
        }
    }

    public static void deleteFolders(List<Folder__c> folderList) {
          if(folderList == null){
             return;
        }
        if (folderList != null && !folderList.isEmpty()) {
            /* sfge-disable-next-line ApexFlsViolationRule */
            Database.delete(folderList, AccessLevel.SYSTEM_MODE);
        }
    }

    public static void saveOrUpdateAWSSettings(String accessKey, String secretKey, String bucketName, String region) {
        AWS_Settings__c awsSettings = AWS_Settings__c.getOrgDefaults();

        if (awsSettings == null || awsSettings.Id == null) {
            awsSettings = new AWS_Settings__c();
            awsSettings.SetupOwnerId = UserInfo.getOrganizationId();
        }

        awsSettings.AWS_Access_Key_Id__c = accessKey;
        awsSettings.AWS_Secret_Access_Key__c = secretKey;
        awsSettings.S3_Bucket_Name__c = bucketName;
        awsSettings.S3_Region_Name__c = region;

        /* sfge-disable-next-line ApexFlsViolationRule */
        Database.upsert(awsSettings, AccessLevel.SYSTEM_MODE);
    }

    public static Boolean isDuplicateFolderName(Id parentId, String folderName, String folderType, Id userId) {
          if(parentId == null){
            return false;
        }
         if(userId == null){
            return false;
        }
          if(folderType == null || folderName == null){
            return false;
        }
        try {
            List<Folder__c> duplicates = new List<Folder__c>();

            if (folderType == 'public') {
                duplicates = [
                    SELECT Id FROM Folder__c
                    WHERE Folder__c = :parentId
                    AND Name = :folderName
                    AND Type__c = 'public'
                    WITH SECURITY_ENFORCED
                    LIMIT 1
                ];
            } else if (folderType == 'private') {
                duplicates = [
                    SELECT Id FROM Folder__c
                    WHERE Folder__c = :parentId
                    AND Name = :folderName
                    AND Type__c = 'private'
                    AND OwnerId = :userId
                    WITH SECURITY_ENFORCED
                    LIMIT 1
                ];
            }

            return !duplicates.isEmpty();
        } catch (Exception e) {
            return false;
        }
    }

    public static Utils.AwsSettings fetchAWSConfiguration() {
        try {
            AWS_Settings__c settings = AWS_Settings__c.getOrgDefaults();

            if (settings == null) {
                return null;
            }

            Utils.AwsSettings wrapper = new Utils.AwsSettings();
            wrapper.awsAccessKeyId = settings.AWS_Access_Key_Id__c;
            wrapper.awsSecretAccessKey = settings.AWS_Secret_Access_Key__c;
            wrapper.s3BucketName = settings.S3_Bucket_Name__c;
            wrapper.s3RegionName = settings.S3_Region_Name__c;
            wrapper.apiVersion = settings.API_Version__c;
            wrapper.signatureVersion = settings.Signature_Version__c;

            return wrapper;
        } catch (Exception e) {
            return null;
        }
    }

    public static List<ContentVersion> getContentVersions(Set<Id> docIds) {
        if (docIds == null || docIds.isEmpty()) {
            return new List<ContentVersion>();
        }
        Set<Id> validDocIds = new Set<Id>();
        validDocIds.addAll(docIds);
        return [
            SELECT Id, Title, FileExtension, ContentDocumentId, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId IN :validDocIds
            WITH SECURITY_ENFORCED
        ];
    }

    public static void insertDocumentLinks(Id targetId, List<Id> docIds) {
        if (targetId == null || docIds == null || docIds.isEmpty()) {
            return;
        }
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (Id docId : docIds) {
            if (docId == null) continue;
            links.add(new ContentDocumentLink(
                ContentDocumentId = docId,
                LinkedEntityId = targetId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            ));
        }
        if (!links.isEmpty()) {
           /* sfge-disable-next-line ApexFlsViolationRule */
            Database.insert(links, AccessLevel.SYSTEM_MODE);
        }
    }

    public static void deleteOldLinks(Id sourceId, List<Id> docIds) {
        if (sourceId == null || docIds == null || docIds.isEmpty()) {
            return;
        }
        List<Id> validDocIds = new List<Id>();
        validDocIds.addAll(docIds);
        List<ContentDocumentLink> oldLinks = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :sourceId
              AND ContentDocumentId IN :validDocIds
            WITH SECURITY_ENFORCED
        ];
        if (!oldLinks.isEmpty()) {
            /* sfge-disable-next-line ApexFlsViolationRule */
            Database.delete(oldLinks, AccessLevel.SYSTEM_MODE);
        }
    }

    public static List<ContentVersion> getLatestVersionsForRecord(Id recordId) {
        try {
            Set<Id> contentDocIds = getContentDocumentIdsForRecord(recordId);
            if (contentDocIds.isEmpty()) return new List<ContentVersion>();
            return [
                SELECT Id, Title, ContentDocumentId, FileExtension
                FROM ContentVersion
                WHERE ContentDocumentId IN :contentDocIds
                AND IsLatest = TRUE
                WITH SECURITY_ENFORCED
                ORDER BY Title
            ];
        } catch (Exception e) {
            return new List<ContentVersion>();
        }
    }

    private static Set<Id> getContentDocumentIdsForRecord(Id recordId) {
        try {
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :recordId
                WITH SECURITY_ENFORCED
            ];
            Set<Id> ids = new Set<Id>();
            for (ContentDocumentLink link : links) {
                ids.add(link.ContentDocumentId);
            }
            return ids;
        } catch (Exception e) {
            return new Set<Id>();
        }
    }

    public static Set<Id> getContentDocumentIds(Id recordId) {
        Set<Id> ids = new Set<Id>();
        try {
            for (ContentDocumentLink link : [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :recordId
                WITH SECURITY_ENFORCED
            ]) {
                ids.add(link.ContentDocumentId);
            }
        } catch (Exception e) {
        }
        return ids;
    }

    public static NamedCredential getNamedCredential(String credentialName) {
        try {
            List<NamedCredential> creds = [
                SELECT DeveloperName, Endpoint
                FROM NamedCredential
                WHERE DeveloperName = :credentialName
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            return creds.isEmpty() ? null : creds[0];
        } catch (Exception e) {
            return null;
        }
    }

    public static ContentVersion getLatestVersion(Id contentDocumentId) {
        try {
            List<ContentVersion> versions = [
                SELECT VersionData, Title, FileExtension
                FROM ContentVersion
                WHERE ContentDocumentId = :contentDocumentId
                AND IsLatest = true
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            return versions.isEmpty() ? null : versions[0];
        } catch (Exception e) {
            return null;
        }
    }

    public static List<Uploaded_File_Info__c> getFilesForDelete(Id parentId) {
        try {
            return [
                SELECT Id, File_Name__c, Parent_Name__c, Parent_Record_Id__c, ObjectKey__c
                FROM Uploaded_File_Info__c
                WHERE Parent_Record_Id__c = :parentId
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception e) {
            return new List<Uploaded_File_Info__c>();
        }
    }

    public static void deleteFiles(List<Uploaded_File_Info__c> filesToDelete) {
        /* sfge-disable-next-line ApexFlsViolationRule */
        Database.delete(filesToDelete, AccessLevel.SYSTEM_MODE);
    }

    public static List<Uploaded_File_Info__c> getSingleFileById(Id fileId) {
        try {
            return [
                SELECT Id, File_Name__c, Parent_Name__c, Parent_Record_Id__c, ObjectKey__c
                FROM Uploaded_File_Info__c
                WHERE Id = :fileId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
        } catch (Exception e) {
            return new List<Uploaded_File_Info__c>();
        }
    }

    public static void deleteSingleFile(Uploaded_File_Info__c file) {
        /* sfge-disable-next-line ApexFlsViolationRule */
        Database.delete(file, AccessLevel.SYSTEM_MODE);
    }

    public static String queryParentRecordName(Id recordId, String objectApiName) {
        try {
            Map<String, Schema.SObjectType> objMap = Schema.getGlobalDescribe();
            if (!objMap.containsKey(objectApiName)) {
                return '';
            }
            String queryStr = 'SELECT Name FROM ' + objectApiName + ' WHERE Id = :recordId WITH SECURITY_ENFORCED LIMIT 1';
            List<SObject> results = Database.query(queryStr);
            if (!results.isEmpty()) {
                return (String) results[0].get('Name');
            }
            return '';
        } catch (Exception e) {
            return '';
        }
    }

    public static List<Utils.Folder> getFoldersByRecord(Id recordId) {
        List<Utils.Folder> folderList = new List<Utils.Folder>();
        if (recordId == null) {
            return folderList;
        }
        try {
            List<Folder__c> folders = [
                SELECT Id, Name, Folder__c, Parent_Record_Id__c
                FROM Folder__c
                WHERE Parent_Record_Id__c = :recordId
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
            ];
            for (Folder__c folder : folders) {
                Utils.Folder wrapper = new Utils.Folder();
                wrapper.folderId = folder.Id;
                wrapper.folderName = folder.Name;
                wrapper.awsFolderPath = folder.Folder__c;
                wrapper.parentRecordId = folder.Parent_Record_Id__c;
                wrapper.objectApiName = 'Folder__c';
                folderList.add(wrapper);
            }
        } catch (Exception e) {
            return new List<Utils.Folder>();
        }
        return folderList;
    }

    public static Folder__c getFolderDetails(Id folderId) {
        try {
            List<Folder__c> folders = [
                SELECT Id, Type__c
                FROM Folder__c
                WHERE Id = :folderId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            return folders.isEmpty() ? null : folders[0];
        } catch (Exception e) {
            return null;
        }
    }

    public static void deleteFolderById(Id folderId) {
        if (folderId == null) {
            return;
        }
        try {
            List<Folder__c> folders = [
                SELECT Id
                FROM Folder__c
                WHERE Id = :folderId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            if (!folders.isEmpty()) {
                /* sfge-disable-next-line ApexFlsViolationRule */
                Database.delete(folders, AccessLevel.SYSTEM_MODE);
            }
        } catch (Exception e) {
        }
    }

    public static void deleteAllFoldersByRecordId(Id recordId) {
        try {
            List<Folder__c> folders = [
                SELECT Id
                FROM Folder__c
                WHERE Parent_Record_Id__c = :recordId
                WITH SECURITY_ENFORCED
            ];
            /* sfge-disable-next-line ApexFlsViolationRule */
            Database.delete(folders, AccessLevel.SYSTEM_MODE);
        } catch (Exception e) {
        }
    }

    public static void insertNewFolder(Folder__c newFolder) {
        /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(newFolder, AccessLevel.SYSTEM_MODE);
    }

  public static Integer getTotalRecords(String searchName, String filter, String operator, String value, List<String> typeList, Date dateValue) {
    if (searchName == null) return 0;
    if (filter == null) filter = '';
    if (operator == null) operator = '';
    if (value == null) value = '';
    if (typeList == null) typeList = new List<String>();
   String namePat = '';
if (searchName != null) {
    namePat = '%' + searchName + '%';
}
    if (namePat == null || namePat == '') {
        return 0;
    }

    String valStart = value + '%';
    String valContains = '%' + value + '%';
    String q = 'SELECT COUNT() FROM Uploaded_file_info__c WHERE File_Name__c LIKE :namePat';
    if (filter != '' && operator != '' && value != '') {
        if (filter == 'CreatedDate') {
            q += (operator == 'equal') ? ' AND DAY_ONLY(CreatedDate) = :dateValue' : ' AND DAY_ONLY(CreatedDate) != :dateValue';
        } else if (operator == 'equal') {
            q += (value == 'others') ? ' AND ' + filter + ' NOT IN :typeList' : ' AND ' + filter + ' = :value';
        } else if (operator == 'notequal') {
            q += ' AND ' + filter + ' != :value';
        } else if (operator == 'startwith') {
            q += ' AND ' + filter + ' LIKE :valStart';
        } else if (operator == 'contains') {
            q += ' AND ' + filter + ' LIKE :valContains';
        } else if (operator == 'notcontains') {
            q += ' AND NOT ' + filter + ' LIKE :valContains';
        }
    }

    q += ' WITH SECURITY_ENFORCED';
    return Database.countQuery(q);
}

    public static List<Uploaded_file_info__c> getFileRecords(
    String searchName,
    String filter,
    String operator,
    String value,
    List<String> typeList,
    Date dateValue,
    Integer pageSize,
    Integer offsetVal
) {

    if (String.isBlank(searchName)) {
        return new List<Uploaded_file_info__c>();
    }

    String safeNamePattern = '%' + searchName.trim() + '%';

    if (String.isBlank(safeNamePattern)) {
        return new List<Uploaded_file_info__c>();
    }

    Integer safePageSize =
        (pageSize == null || pageSize <= 0)
        ? 10
        : pageSize;

    Integer safeOffset =
        (offsetVal == null || offsetVal < 0)
        ? 0
        : offsetVal;

    String valuePatternStart =
        (value == null)
        ? null
        : value + '%';

    String valuePatternContains =
        (value == null)
        ? null
        : '%' + value + '%';

    String query =
        'SELECT Id, File_Name__c, Parent_record_name__c, Parent_Name__c, CreatedBy.Name,' +
        ' Parent_Record_Id__c, File_sizes__c, CreatedDate, ObjectKey__c, File_Type__c,' +
        ' File_URL__c ' +
        'FROM Uploaded_file_info__c ' +
        'WHERE File_Name__c LIKE :safeNamePattern';

    Set<String> allowedFields = new Set<String>{
        'File_Type__c',
        'Parent_Name__c',
        'CreatedDate'
    };

    if (filter != null &&
        operator != null &&
        value != null &&
        allowedFields.contains(filter)) {

        if (filter == 'CreatedDate') {

            if (operator == 'equal') {

                query +=
                    ' AND DAY_ONLY(CreatedDate) = :dateValue';

            } else {

                query +=
                    ' AND DAY_ONLY(CreatedDate) != :dateValue';
            }

        } else {

            if (operator == 'equal') {

                if (value == 'others') {

                    query +=
                        ' AND ' + filter + ' NOT IN :typeList';

                } else {

                    query +=
                        ' AND ' + filter + ' = :value';
                }

            } else if (operator == 'notequal') {

                query +=
                    ' AND ' + filter + ' != :value';

            } else if (operator == 'startwith') {

                query +=
                    ' AND ' + filter + ' LIKE :valuePatternStart';

            } else if (operator == 'contains') {

                query +=
                    ' AND ' + filter + ' LIKE :valuePatternContains';

            } else if (operator == 'notcontains') {

                query +=
                    ' AND NOT ' + filter + ' LIKE :valuePatternContains';
            }
        }
    }

    query +=
        ' WITH SECURITY_ENFORCED' +
        ' ORDER BY CreatedDate DESC' +
        ' LIMIT :safePageSize' +
        ' OFFSET :safeOffset';

    try {

        return Database.query(query);

    } catch (Exception e) {

        return new List<Uploaded_file_info__c>();
    }
}

    public static List<ContentVersion> get_LatestContentVersions(Set<Id> contentDocIds) {
        if (contentDocIds.isEmpty()) {
            return new List<ContentVersion>();
        }
        try {
            return [
                SELECT Id, ContentDocumentId, VersionData, Title, FileExtension
                FROM ContentVersion
                WHERE ContentDocumentId IN :contentDocIds
                AND IsLatest = TRUE
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception e) {
            return new List<ContentVersion>();
        }
    }

    public static List<ContentDocument> getContentDocuments(Set<Id> docIds) {
        if (docIds.isEmpty()) {
            return new List<ContentDocument>();
        }
        try {
            return [
                SELECT Id
                FROM ContentDocument
                WHERE Id IN :docIds
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception e) {
            return new List<ContentDocument>();
        }
    }

    public static List<Attachment> getAttachments(Id recordId) {
        try {
            return [
                SELECT Id, Name, Body, ContentType, ParentId
                FROM Attachment
                WHERE ParentId = :recordId
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception e) {
            return new List<Attachment>();
        }
    }

    public static List<Uploaded_File_Info__c> getUploadedFiles(Id accountId) {
        try {
            return [
                SELECT File_Name__c
                FROM Uploaded_File_Info__c
                WHERE Parent_Record_Id__c = :accountId
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception e) {
            return new List<Uploaded_File_Info__c>();
        }
    }

    public static List<ContentDocumentLink> fetchDocumentLinksByRecord(
    Id recordId
) {

    if (recordId == null) {
        return new List<ContentDocumentLink>();
    }

    Id safeRecordId = recordId;

    if (safeRecordId == null) {
        return new List<ContentDocumentLink>();
    }

    try {

        return [

            SELECT ContentDocumentId

            FROM ContentDocumentLink

            WHERE LinkedEntityId = :safeRecordId

            WITH SECURITY_ENFORCED
        ];

    } catch (Exception e) {

        return new List<ContentDocumentLink>();
    }
}

    public static List<ContentVersion> fetchLatestFileVersions(Set<Id> documentIds) {
        if (documentIds.isEmpty()) {
            return new List<ContentVersion>();
        }
        try {
            return [
                SELECT Title, FileExtension, ContentSize,ContentDocumentId  
                FROM ContentVersion
                WHERE ContentDocumentId IN :documentIds
                AND IsLatest = TRUE
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception e) {
            return new List<ContentVersion>();
        }
    }

    public static List<ContentVersion> fetchLatestFileVersionsWithData(Set<Id> documentIds) {
        if (documentIds.isEmpty()) {
            return new List<ContentVersion>();
        }
        try {
            return [
                SELECT Id, ContentDocumentId, VersionData, Title, FileExtension, ContentSize
                FROM ContentVersion
                WHERE ContentDocumentId IN :documentIds
                AND IsLatest = TRUE
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception e) {
            return new List<ContentVersion>();
        }
    }

    public static String fetchRecordName(String objectType, Id recordId) {
        String recordName = '';
        try {
            Map<String, Schema.SObjectType> objMap = Schema.getGlobalDescribe();
            if (!objMap.containsKey(objectType)) {
                return '';
            }
            String queryStr = 'SELECT Name FROM ' + objectType + ' WHERE Id = :recordId WITH SECURITY_ENFORCED LIMIT 1';
            List<SObject> results = Database.query(queryStr);
            if (!results.isEmpty()) {
                recordName = (String) results[0].get('Name');
            }
        } catch (Exception e) {
        }
        return recordName;
    }

    public static ContentVersion fetchLatestContentVersionByDocumentId(String contentDocumentId) {
        try {
            List<ContentVersion> versions = [
                SELECT Id, Title, FileExtension
                FROM ContentVersion
                WHERE ContentDocumentId = :contentDocumentId
                WITH SECURITY_ENFORCED
                ORDER BY VersionNumber DESC
                LIMIT 1
            ];
            return versions.isEmpty() ? null : versions[0];
        } catch (Exception e) {
            return null;
        }
    }

    public static List<Uploaded_file_info__c> getFilesByParentId(String parentId) {
        try {
            return [
                SELECT Id, File_Name__c, File_Type__c, File_Url__c,
                       Parent_Name__c, Parent_Record_Id__c, ObjectKey__c,
                       File_Sizes__c, CreatedDate
                FROM Uploaded_file_info__c
                WHERE Parent_Record_Id__c = :parentId
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
            ];
        } catch (Exception e) {
            return new List<Uploaded_file_info__c>();
        }
    }

    public static List<Uploaded_file_info__c> deleteFileAndReturnList(String recordId) {
        Uploaded_file_info__c oldRec = getFileRecordById(recordId);
        /* sfge-disable-next-line ApexFlsViolationRule */
        Database.delete(oldRec, AccessLevel.SYSTEM_MODE);
        if (oldRec.Parent_Record_Id__c != null) {
            return getFilesByParentId(oldRec.Parent_Record_Id__c);
        }
        return new List<Uploaded_file_info__c>();
    }

    public static void deleteFileRecord(Uploaded_file_info__c fileRec) {
        if (fileRec != null) {
            /* sfge-disable-next-line ApexFlsViolationRule */
            Database.delete(fileRec, AccessLevel.SYSTEM_MODE);
        }
    }

    public static void deleteContentDocuments(Set<Id> docIds) {
        if (docIds.isEmpty()) {
            return;
        }
        List<ContentDocument> docs = getContentDocuments(docIds);
        if (!docs.isEmpty()) {
            /* sfge-disable-next-line ApexFlsViolationRule */
            Database.delete(docs, AccessLevel.SYSTEM_MODE);
        }
    }

    public static void deleteAttachments(List<Attachment> attachments) {
        if (attachments != null && !attachments.isEmpty()) {
            /* sfge-disable-next-line ApexFlsViolationRule */
            Database.delete(attachments, AccessLevel.SYSTEM_MODE);
        }
    }

    public static List<Uploaded_file_info__c> getUploadedFiles(Integer pageSize, Integer offset) {
        if (pageSize == null) pageSize = 0;
        if (offset == null) offset = 0;
        try {
            return [
                SELECT Id, File_Name__c, File_Type__c, File_sizes__c, File_URL__c,
                       Parent_Name__c, Parent_Record_Id__c, CreatedDate, CreatedBy.Name
                FROM Uploaded_file_info__c
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
                LIMIT :pageSize OFFSET :offset
            ];
        } catch (Exception e) {
            return new List<Uploaded_file_info__c>();
        }
    }

    public static Integer getTotalFileCount() {
        return [SELECT COUNT() FROM Uploaded_file_info__c WITH SECURITY_ENFORCED];
    }

 public static Integer getTotalFileCount(String searchName) {

    if (String.isBlank(searchName)) {
        return 0;
    }

    String safeSearchName = searchName.trim();
    if (String.isBlank(safeSearchName)) {
        return 0;
    }

    String searchPattern = '%' + safeSearchName + '%';

    String safeFinalSearchPattern = '';
    if (searchPattern != null) {
        safeFinalSearchPattern = searchPattern;
    }

    if (safeFinalSearchPattern == null) {
        safeFinalSearchPattern = '';
    }

    try {
        Id userId = UserInfo.getUserId();
        if (userId == null) {
            return 0;
        }
        return [
            SELECT COUNT()
            FROM Uploaded_File_Info__c
            WHERE File_Name__c LIKE :safeFinalSearchPattern
            AND (
                Folder__c = null
                OR Folder__r.Type__c != 'private'
                OR OwnerId = :userId
            )
            WITH SECURITY_ENFORCED
        ];
    } catch (Exception e) {
        return 0;
    }
}

public static List<Uploaded_File_Info__c> getSearchFileRecords(
    String searchName,
    Integer pageSize,
    Integer offsetValue
) {

    if (String.isBlank(searchName)) {
        return new List<Uploaded_File_Info__c>();
    }

    String safeSearchName = searchName.trim();
    if (String.isBlank(safeSearchName)) {
        return new List<Uploaded_File_Info__c>();
    }

    Integer finalQueryLimit = 10;
    if (pageSize != null && pageSize > 0) {
        finalQueryLimit = pageSize;
    }

    Integer finalQueryOffset = 0;
    if (offsetValue != null && offsetValue >= 0) {
        finalQueryOffset = offsetValue;
    }

    String finalQuerySearchPattern = '%' + safeSearchName + '%';
    if (finalQuerySearchPattern == null) {
        finalQuerySearchPattern = '';
    }
    if (finalQueryLimit == null) {
        finalQueryLimit = 10;
    }
    if (finalQueryOffset == null) {
        finalQueryOffset = 0;
    }

    try {
        Id userId = UserInfo.getUserId();
        if (userId == null) {
            return new List<Uploaded_File_Info__c>();
        }

        return [
            SELECT Id,
                   File_Name__c,
                   Parent_Name__c,
                   Parent_Record_Name__c,
                   Parent_Record_Id__c,
                   File_Type__c,
                   File_Sizes__c,
                   File_URL__c,
                   CreatedBy.Name,
                   CreatedDate
            FROM Uploaded_File_Info__c
            WHERE File_Name__c LIKE :finalQuerySearchPattern
            AND (
                Folder__c = null
                OR Folder__r.Type__c != 'private'
                OR OwnerId = :userId
            )
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT :finalQueryLimit
            OFFSET :finalQueryOffset
        ];

    } catch (Exception e) {
        return new List<Uploaded_File_Info__c>();
    }
}
    public static Integer sanitizeSize(Integer pageSize) {
        return (pageSize == null || pageSize < 1) ? 10 : pageSize;
    }

    public static Integer sanitizePage(Integer pageNumber, Integer totalRecords, Integer pageSize) {
        if (pageNumber == null || totalRecords == null || pageSize == null) return 0;
        if (pageSize <= 0) return 0;
        if (pageNumber < 1) return 1;
        Integer totalPages = (totalRecords + pageSize - 1) / pageSize;
        if (totalPages == 0) return 1;
        return Math.min(pageNumber, totalPages);
    }

    public static Aws_Settings__c getAwsSettings() {
        try {
            return [
                SELECT AWS_Access_Key_Id__c, AWS_Secret_Access_Key__c,
                       S3_Bucket_Name__c, API_Version__c, Signature_Version__c,
                       S3_Region_Name__c
                FROM Aws_Settings__c
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
        } catch (Exception e) {
            return null;
        }
    }

    public static List<ContentDocumentLink> getContentDocumentLinks(String recordId) {
        try {
            return [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :recordId
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception e) {
            return new List<ContentDocumentLink>();
        }
    }

    public static List<ContentDocumentLink> getContentDocumentLinksByIds(List<Id> recordIds) {
        try {
            return [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :recordIds
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception e) {
            return new List<ContentDocumentLink>();
        }
    }

    public static List<ContentVersion> getLatestContentVersions(Set<Id> docIds) {
        try {
            return [
                SELECT Id, Title, FileExtension, VersionData, ContentDocumentId
                FROM ContentVersion
                WHERE ContentDocumentId IN :docIds AND IsLatest = TRUE
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception e) {
            return new List<ContentVersion>();
        }
    }

    public static List<ContentDocument> getContentDocumentsByIds(Set<Id> docIds) {
        try {
            return [
                SELECT Id, Title, FileType, CreatedDate
                FROM ContentDocument
                WHERE Id IN :docIds
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception e) {
            return new List<ContentDocument>();
        }
    }

    public static List<SObject> getRecordsByObjectName(String objectName) {
        try {
            Map<String, Schema.SObjectType> objMap = Schema.getGlobalDescribe();
            if (!objMap.containsKey(objectName)) {
                return new List<SObject>();
            }
            String query = 'SELECT Id, Name FROM ' + objectName + ' WITH SECURITY_ENFORCED';
            return Database.query(query);
        } catch (Exception e) {
            return new List<SObject>();
        }
    }

    public static List<String> getAllRecordIdsByObjectName(String objectName) {
        List<String> ids = new List<String>();
        try {
            Map<String, Schema.SObjectType> objMap = Schema.getGlobalDescribe();
            if (!objMap.containsKey(objectName)) {
                return ids;
            }
            String query = 'SELECT Id FROM ' + objectName + ' WITH SECURITY_ENFORCED';
            for (SObject rec : Database.query(query)) {
                ids.add((String) rec.get('Id'));
            }
        } catch (Exception e) {
        }
        return ids;
    }

    public static List<String> getDistinctParentNames() {
        List<String> result = new List<String>();
        try {
            List<AggregateResult> records = [
                SELECT Parent_Name__c
                FROM Uploaded_file_info__c
                WHERE Parent_Name__c != null
                WITH SECURITY_ENFORCED
                GROUP BY Parent_Name__c
                LIMIT 1000
            ];
            for (AggregateResult ar : records) {
                result.add((String) ar.get('Parent_Name__c'));
            }
        } catch (Exception e) {
        }
        return result;
    }

  public static Integer countByParentName(String searchname, String value, String operator) {
    if (searchname == null) return 0;
    if (value == null) value = '';
    if (operator == null) operator = '';
String namePat = '';
if (searchname != null) {
    namePat = '%' + searchname + '%';
}  
   if (namePat == null || namePat == '') {
        return 0;
    }

    try {
        if (operator == 'equal') {
            return [
                SELECT COUNT()
                FROM Uploaded_file_info__c
                WHERE File_Name__c LIKE :namePat
                AND Parent_Name__c = :value
                WITH SECURITY_ENFORCED
            ];
        }
        return [
            SELECT COUNT()
            FROM Uploaded_file_info__c
            WHERE File_Name__c LIKE :namePat
            AND Parent_Name__c != :value
            WITH SECURITY_ENFORCED
        ];
    } catch (Exception e) {
        return 0;
    }
}

   public static List<Uploaded_file_info__c> fetchByParentName(
    String searchname, String value, String operator, Integer pageSize, Integer offset
) {
    if (searchname == null) return new List<Uploaded_file_info__c>();
    if (value == null) value = '';
    if (operator == null) operator = '';
    if (pageSize == null || pageSize <= 0) pageSize = 10;
    if (offset == null || offset < 0) offset = 0;
   String namePat = '';
if (searchname != null) {
    namePat = '%' + searchname + '%';
}
  if (namePat == null || namePat == '') {
    return new List<Uploaded_file_info__c>();
}
    try {
        if (operator == 'equal') {
            return [
                SELECT Id, File_Name__c, Name, File_Type__c, File_sizes__c,
                       File_URL__c, Parent_Name__c, Parent_Record_Id__c,
                       CreatedDate, CreatedBy.Name
                FROM Uploaded_file_info__c
                WHERE File_Name__c LIKE :namePat
                AND Parent_Name__c = :value
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
                LIMIT :pageSize OFFSET :offset
            ];
        }
        return [
            SELECT Id, File_Name__c, Name, File_Type__c, File_sizes__c,
                   File_URL__c, Parent_Name__c, Parent_Record_Id__c,
                   CreatedDate, CreatedBy.Name
            FROM Uploaded_file_info__c
            WHERE File_Name__c LIKE :namePat
            AND Parent_Name__c != :value
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT :pageSize OFFSET :offset
        ];
    } catch (Exception e) {
        return new List<Uploaded_file_info__c>();
    }
}
 public static Integer countByFileType(
    String searchname,
    String value,
    String operator
) {

    if (String.isBlank(searchname)) {
        return 0;
    }

    value = (value == null) ? '' : value;

    operator = (operator == null) ? '' : operator;

    String safeSearchName = searchname.trim();

    if (String.isBlank(safeSearchName)) {
        return 0;
    }

    String safeNamePattern = '%' + safeSearchName + '%';

    if (String.isBlank(safeNamePattern)) {
        return 0;
    }

    String finalNamePattern = '';

    if (safeNamePattern != null) {
        finalNamePattern = safeNamePattern;
    }

    if (String.isBlank(finalNamePattern)) {
        return 0;
    }

    Id userId = UserInfo.getUserId();

    if (userId == null) {
        return 0;
    }

    // IMAGE_GROUP
    if (value == 'IMAGE_GROUP') {

        String imagePat = 'image/%';

        List<String> imageExts = new List<String>{
            'jpeg',
            'jpg',
            'png',
            'gif',
            'webp',
            'svg',
            'bmp'
        };

        try {

            return (operator == 'equal')

                ?

                [
                    SELECT COUNT()
                    FROM Uploaded_file_info__c
                    WHERE File_Name__c LIKE :finalNamePattern
                    AND (
                        File_Type__c LIKE :imagePat
                        OR File_Type__c IN :imageExts
                    )
                    AND (
                        Folder__c = null
                        OR Folder__r.Type__c != 'private'
                        OR OwnerId = :userId
                    )
                    WITH SECURITY_ENFORCED
                ]

                :

                [
                    SELECT COUNT()
                    FROM Uploaded_file_info__c
                    WHERE File_Name__c LIKE :finalNamePattern
                    AND (
                        NOT File_Type__c LIKE :imagePat
                    )
                    AND File_Type__c NOT IN :imageExts
                    AND (
                        Folder__c = null
                        OR Folder__r.Type__c != 'private'
                        OR OwnerId = :userId
                    )
                    WITH SECURITY_ENFORCED
                ];

        } catch (Exception e) {

            return 0;
        }
    }

    List<String> rawEquivalents = getEquivalentTypes(value);

    List<String> equivalents = new List<String>();

    if (rawEquivalents != null) {
        equivalents.addAll(rawEquivalents);
    }

    if (equivalents == null || equivalents.isEmpty()) {
        return 0;
    }

    List<String> safeEquivalents = new List<String>();

    for (String ext : equivalents) {

        if (!String.isBlank(ext)) {
            safeEquivalents.add(ext.trim());
        }
    }

    if (safeEquivalents.isEmpty()) {
        return 0;
    }

    List<String> finalEquivalents = new List<String>();

    if (safeEquivalents != null && !safeEquivalents.isEmpty()) {
        finalEquivalents.addAll(safeEquivalents);
    }

    if (finalEquivalents == null || finalEquivalents.isEmpty()) {
        return 0;
    }

    try {

        return (operator == 'equal')

            ?

            [
                SELECT COUNT()
                FROM Uploaded_file_info__c
                WHERE File_Name__c LIKE :finalNamePattern
                AND File_Type__c IN :finalEquivalents
                AND (
                    Folder__c = null
                    OR Folder__r.Type__c != 'private'
                    OR OwnerId = :userId
                )
                WITH SECURITY_ENFORCED
            ]

            :

            [
                SELECT COUNT()
                FROM Uploaded_file_info__c
                WHERE File_Name__c LIKE :finalNamePattern
                AND File_Type__c NOT IN :finalEquivalents
                AND (
                    Folder__c = null
                    OR Folder__r.Type__c != 'private'
                    OR OwnerId = :userId
                )
                WITH SECURITY_ENFORCED
            ];

    } catch (Exception e) {

        return 0;
    }
}
 public static List<Uploaded_file_info__c> fetchByFileType(
    String searchname, String value, String operator,
    Integer pageSize, Integer offset
) {
    if (searchname == null) return new List<Uploaded_file_info__c>();
    if (value == null) value = '';
    if (operator == null) operator = '';
    if (pageSize == null || pageSize <= 0) pageSize = 10;
    if (offset == null || offset < 0) offset = 0;

String namePat = '';
if (searchname != null) {
    namePat = '%' + searchname + '%';
}   
  if (namePat == null || namePat == '') {
    return new List<Uploaded_file_info__c>();
}
 if (value == 'IMAGE_GROUP') {
        String imagePat = 'image/%';
        List<String> imageExts = new List<String>{'jpeg','jpg','png','gif','webp','svg','bmp'};
        try {
            return (operator == 'equal') ?
                [SELECT Id, File_Name__c, Name, File_Type__c, File_sizes__c,
                        File_URL__c, Parent_Name__c, Parent_Record_Id__c,
                        CreatedDate, CreatedBy.Name
                 FROM Uploaded_file_info__c
                 WHERE File_Name__c LIKE :namePat
                 AND (File_Type__c LIKE :imagePat OR File_Type__c IN :imageExts)
                 AND (Folder__c = null OR Folder__r.Type__c != 'private' OR OwnerId = :UserInfo.getUserId())
                 WITH SECURITY_ENFORCED
                 ORDER BY CreatedDate DESC
                 LIMIT :pageSize OFFSET :offset] :
                [SELECT Id, File_Name__c, Name, File_Type__c, File_sizes__c,
                        File_URL__c, Parent_Name__c, Parent_Record_Id__c,
                        CreatedDate, CreatedBy.Name
                 FROM Uploaded_file_info__c
                 WHERE File_Name__c LIKE :namePat
                 AND (NOT File_Type__c LIKE :imagePat)
                 AND File_Type__c NOT IN :imageExts
                 AND (Folder__c = null OR Folder__r.Type__c != 'private' OR OwnerId = :UserInfo.getUserId())
                 WITH SECURITY_ENFORCED
                 ORDER BY CreatedDate DESC
                 LIMIT :pageSize OFFSET :offset];
        } catch (Exception e) {
            return new List<Uploaded_file_info__c>();
        }
    }

    List<String> rawEquivalents = getEquivalentTypes(value);
   List<String> equivalents = new List<String>();

if (rawEquivalents != null) {
    equivalents.addAll(rawEquivalents);
}

    try {
        return (operator == 'equal') ?
            [SELECT Id, File_Name__c, Name, File_Type__c, File_sizes__c,
                    File_URL__c, Parent_Name__c, Parent_Record_Id__c,
                    CreatedDate, CreatedBy.Name
             FROM Uploaded_file_info__c
             WHERE File_Name__c LIKE :namePat
             AND File_Type__c IN :equivalents
             AND (Folder__c = null OR Folder__r.Type__c != 'private' OR OwnerId = :UserInfo.getUserId())
             WITH SECURITY_ENFORCED
             ORDER BY CreatedDate DESC
             LIMIT :pageSize OFFSET :offset] :
            [SELECT Id, File_Name__c, Name, File_Type__c, File_sizes__c,
                    File_URL__c, Parent_Name__c, Parent_Record_Id__c,
                    CreatedDate, CreatedBy.Name
             FROM Uploaded_file_info__c
             WHERE File_Name__c LIKE :namePat
             AND File_Type__c NOT IN :equivalents
             AND (Folder__c = null OR Folder__r.Type__c != 'private' OR OwnerId = :UserInfo.getUserId())
             WITH SECURITY_ENFORCED
             ORDER BY CreatedDate DESC
             LIMIT :pageSize OFFSET :offset];
    } catch (Exception e) {
        return new List<Uploaded_file_info__c>();
    }
}

    // ── NEW: Equivalent MIME types map (handles inconsistent File_Type__c values) ──
    private static List<String> getEquivalentTypes(String value) {
        Map<String, List<String>> typeMap = new Map<String, List<String>>{
            'application/x-zip-compressed' => new List<String>{
                'application/x-zip-compressed', 'application/zip', 'zip'
            },
            'application/zip' => new List<String>{
                'application/x-zip-compressed', 'application/zip', 'zip'
            },
            'application/pdf' => new List<String>{
                'application/pdf', 'pdf'
            },
            'text/plain' => new List<String>{
                'text/plain', 'txt'
            },
            'text/csv' => new List<String>{
                'text/csv', 'csv',
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'xlsx', 'xls'
            },
            'application/msword' => new List<String>{
                'application/msword',
                'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                'doc', 'docx'
            },
            'application/vnd.ms-powerpoint' => new List<String>{
                'application/vnd.ms-powerpoint',
                'application/vnd.openxmlformats-officedocument.presentationml.presentation',
                'ppt', 'pptx'
            }
        };
        return typeMap.containsKey(value) ? typeMap.get(value) : new List<String>{ value };
    }

    public static Map<Id, String> deleteFilesAndGetErrors(List<Uploaded_File_Info__c> filesToDelete) {
        Map<Id, String> fileNameById = new Map<Id, String>();
        for (Uploaded_File_Info__c f : filesToDelete) {
            fileNameById.put(f.Id, f.File_Name__c);
        }
        /* sfge-disable-next-line ApexFlsViolationRule */
        Database.DeleteResult[] deleteResults = Database.delete(filesToDelete, false);

        Map<Id, String> errorById = new Map<Id, String>();
        for (Database.DeleteResult result : deleteResults) {
            if (!result.isSuccess()) {
                errorById.put(
                    result.getId(),
                    'Error deleting file "' + fileNameById.get(result.getId()) + '": ' +
                        getErrorMessages(result.getErrors())
                );
            }
        }
        return errorById;
    }

    @TestVisible
    private static String getErrorMessages(List<Database.Error> errors) {
        List<String> errTexts = new List<String>();
        for (Database.Error err : errors) {
            errTexts.add(err.getMessage());
        }
        return String.join(errTexts, ', ');
    }

    public static List<SObject> getRecordsByObjectAndFilter(
        String selectedObject,
        String filterType,
        String soqlCondition
    ) {
        try {
            Map<String, Schema.SObjectType> objMap = Schema.getGlobalDescribe();
            if (!objMap.containsKey(selectedObject)) {
                return new List<SObject>();
            }
            String query = 'SELECT Id FROM ' + selectedObject;
            if (filterType == 'SOQL Filter' && !String.isBlank(soqlCondition)) {
                query += ' WHERE ' + soqlCondition;
            }
            query += ' WITH SECURITY_ENFORCED LIMIT 10000';
            return Database.query(query);
        } catch (Exception e) {
            return new List<SObject>();
        }
    }

    public static List<EntityDefinition> getEntityDefinitions() {
        try {
            return [
                SELECT QualifiedApiName, Label
                FROM EntityDefinition
                WHERE IsCustomSetting = false
                AND IsDeprecatedAndHidden = false
                AND IsCustomizable = true
                WITH SECURITY_ENFORCED
                ORDER BY QualifiedApiName
            ];
        } catch (Exception e) {
            return new List<EntityDefinition>();
        }
    }

    public static List<String> executeBatchForRecords(
        List<SObject> records,
        String selectedObject,
        String mode,
        Boolean deleteAfterMigration
    ) {
        Boolean shouldDelete = deleteAfterMigration != null ? deleteAfterMigration : false;
        Map<String, String> recordIdMap = new Map<String, String>();
        for (SObject obj : records) {
            if (obj == null || obj.get('Id') == null) continue;
            recordIdMap.put((String) obj.get('Id'), (String) obj.get('Id'));
        }

        if (!recordIdMap.isEmpty()) {
            S3UploaderBatch batch = new S3UploaderBatch(
                selectedObject,
                String.join(new List<String>(recordIdMap.keySet()), ','),
                mode,
                shouldDelete
            );
            return new List<String>{ String.valueOf(Database.executeBatch(batch, 1)) };
        }

        return new List<String>();
    }

    public static void abortJobs(List<String> jobIds) {
        Map<Id, Id> jobMap = new Map<Id, Id>();
        for (String jobId : jobIds) {
            if (String.isBlank(jobId)) continue;
            jobMap.put((Id) jobId, (Id) jobId);
        }
        S3UploaderBatch.abortedJobIds.addAll(jobMap.keySet());
        for (Id jobId : jobMap.keySet()) {
            try {
                System.abortJob(jobId);
            } catch (Exception e) {
            }
        }
    }

    public static void scheduleS3Migration(
        String cronExpression,
        String selectedObject,
        String mode,
        Boolean deleteAfterMigration,
        String filterType,
        String soqlCondition,
        Boolean isHourly
    ) {
        System.schedule(
            'S3 Migration - ' + selectedObject + ' - ' + System.now(),
            cronExpression,
            new S3UploaderScheduler(
                selectedObject,
                mode,
                deleteAfterMigration != null ? deleteAfterMigration : false,
                filterType,
                soqlCondition,
                isHourly != null ? isHourly : false
            )
        );
    }

    public static String getEntityDefinitionToolingQuery() {
        return 'SELECT+QualifiedApiName,Label+FROM+EntityDefinition'
            + '+WHERE+IsCustomSetting=false'
            + '+AND+IsDeprecatedAndHidden=false'
            + '+AND+IsCustomizable=true'
            + '+ORDER+BY+QualifiedApiName';
    }

    public static List<SObject> getRecordsByQuery(String query) {
        return Database.query(query);
    }

    public static void insertUploadedFileInfos(List<Uploaded_File_Info__c> records) {
        if (records == null || records.isEmpty()) {
            return;
        }
        /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(records, AccessLevel.SYSTEM_MODE);
    }

    public static List<AsyncApexJob> getJobStatusByIds(Set<Id> idSet) {
        try {
            return [
                SELECT Id, Status, ApexClass.Name, CreatedDate, CreatedBy.Name,
                       JobItemsProcessed, TotalJobItems
                FROM AsyncApexJob
                WHERE Id IN :idSet
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
            ];
        } catch (Exception e) {
            return new List<AsyncApexJob>();
        }
    }

    public static List<AsyncApexJob> getJobStatusByClassName(Set<String> classNames) {
        try {
            return [
                SELECT Id, Status, ApexClass.Name, CreatedDate, CreatedBy.Name,
                       JobItemsProcessed, TotalJobItems
                FROM AsyncApexJob
                WHERE ApexClass.Name IN :classNames
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
        } catch (Exception e) {
            return new List<AsyncApexJob>();
        }
    }

    public static Integer countActiveJobsByIds(Set<Id> idSet, Set<String> activeStatuses) {
        try {
            return [
                SELECT COUNT()
                FROM AsyncApexJob
                WHERE Id IN :idSet
                AND Status IN :activeStatuses
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception e) {
            return 0;
        }
    }

    public static Integer countActiveJobsByClassName(Set<String> classNames, Set<String> activeStatuses) {
        try {
            return [
                SELECT COUNT()
                FROM AsyncApexJob
                WHERE ApexClass.Name IN :classNames
                AND Status IN :activeStatuses
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception e) {
            return 0;
        }
    }

    public static List<String> executeBatchPerRecord(
        List<SObject> records,
        String selectedObject,
        String mode,
        Boolean deleteAfterMigration
    ) {
        Boolean shouldDelete = deleteAfterMigration != null ? deleteAfterMigration : false;
        Set<Id> recordIdsSet = new Set<Id>();
        for (SObject obj : records) {
            if (obj == null || obj.get('Id') == null) continue;
            recordIdsSet.add((Id) obj.get('Id'));
        }

        if (!recordIdsSet.isEmpty()) {
            List<String> recordIds = new List<String>();
            for (Id recId : recordIdsSet) {
                recordIds.add(String.valueOf(recId));
            }
            String joinedIds = String.join(recordIds, ',');
            S3UploaderBatch batch = new S3UploaderBatch(selectedObject, joinedIds, mode, shouldDelete);
            return new List<String>{ String.valueOf(Database.executeBatch(batch, 1)) };
        }

        return new List<String>();
    }

    public static void scheduleS3MigrationJob(
        String jobName,
        String cronExpression,
        String selectedObject,
        String mode,
        Boolean deleteAfterMigration,
        String filterType,
        String soqlCondition
    ) {
        System.schedule(
            jobName,
            cronExpression,
            new S3UploaderScheduler(
                selectedObject,
                mode,
                deleteAfterMigration != null ? deleteAfterMigration : false,
                filterType,
                soqlCondition
            )
        );
    }

    public static void abortJobById(String jobId) {
        System.abortJob(jobId);
    }

    public static void abortJobsAndTrack(List<String> jobIds) {
        Map<Id, Id> jobMap = new Map<Id, Id>();
        for (String jobId : jobIds) {
            if (String.isBlank(jobId)) continue;
            jobMap.put((Id) jobId, (Id) jobId);
        }
        S3UploaderBatch.abortedJobIds.addAll(jobMap.keySet());
        for (Id jobId : jobMap.keySet()) {
            try {
                System.abortJob(jobId);
            } catch (Exception e) {
            }
        }
    }

    public static String buildQuery(
        String selectedObject,
        String filterType,
        String soqlCondition
    ) {
        String query = 'SELECT Id FROM ' + String.escapeSingleQuotes(selectedObject);
        if (filterType == 'SOQL Filter' && !String.isBlank(soqlCondition)) {
            query += ' WHERE ' + soqlCondition;
        }
        return query + ' WITH SECURITY_ENFORCED LIMIT 10000';
    }

    public static Integer getRecordCount(String objectApiName) {
        if (String.isBlank(objectApiName)) return 0;
        try {
            List<AggregateResult> result = Database.query(
                'SELECT COUNT(Id) cnt FROM ' + objectApiName + ' WITH SECURITY_ENFORCED'
            );
            return result.isEmpty() ? 0 : (Integer) result[0].get('cnt');
        } catch (Exception e) {
            return 0;
        }
    }

    public static List<SObject> searchRecords(String objectApiName, String nameField, String searchKey) {
        if (String.isBlank(objectApiName) || String.isBlank(nameField) || String.isBlank(searchKey)) {
            return new List<SObject>();
        }
        try {
            String query =
                'SELECT Id, ' + nameField +
                ' FROM ' + objectApiName +
                ' WHERE ' + nameField +
                ' LIKE \'%' + String.escapeSingleQuotes(searchKey) + '%\'' +
                ' WITH SECURITY_ENFORCED LIMIT 50';
            return Database.query(query);
        } catch (Exception e) {
            return new List<SObject>();
        }
    }

    public static List<SObject> getManualShareRecords(String recordId, String type) {
        try {
            if (recordId == null || type == null) return null;

            String queryString;
            if (type.toLowerCase() == 'folder') {
                queryString = 'SELECT Id, AccessLevel FROM Folder__Share WHERE ParentId = :recordId AND RowCause = \'Manual\' WITH SECURITY_ENFORCED';
            } else if (type.toLowerCase() == 'file') {
                queryString = 'SELECT Id, AccessLevel FROM Uploaded_File_Info__Share WHERE ParentId = :recordId AND RowCause = \'Manual\' WITH SECURITY_ENFORCED';
            } else {
                return null;
            }
            return Database.query(queryString);
        } catch (Exception e) {
            return null;
        }
    }

    public static ContentVersion getContentDocumentByVersionId(String contentVersionId) {
        if (String.isBlank(contentVersionId)) {
            return null;
        }
        try {
            List<ContentVersion> versions = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :contentVersionId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            return versions.isEmpty() ? null : versions[0];
        } catch (Exception e) {
            return null;
        }
    }
   public static void deleteContentDocuments(List<ContentDocument> documentsToDelete) {

    if (documentsToDelete == null || documentsToDelete.isEmpty()) {
        return;
    }
    // Enforce CRUD/FLS using USER_MODE
    Database.delete(documentsToDelete, false, AccessLevel.USER_MODE);
}
}