public  with sharing class ValidateFSLClass {
/*
    public static Boolean checkUpdateAccessDynamic(List<sObject> listOfsObjectRecord)
    {
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPDATABLE, listOfsObjectRecord);
        String objName = listOfsObjectRecord[0].getSObjectType().getDescribe().getLocalName();
        if (decision.getRemovedFields().containsKey(objName) && !decision.getRemovedFields().get(objName).isEmpty())
        {
            SObjectException ex = new SObjectException();          
            List<String> removedFieldsList = new List<String>(decision.getRemovedFields().get(objName));            
            ex.setMessage('Unable to assign all fields for update, insufficient user FLS:\n' + String.join(removedFieldsList, '\n'));  
            throw ex;
        }
        
        return true;
    }
    */
    public static Boolean checkUpdateAccessDynamic(List<SObject> listOfsObjectRecord) {
    String objName = listOfsObjectRecord[0].getSObjectType().getDescribe().getLocalName();

    
    if (objName.endsWith('__Share')) {
        return true;
    }

    SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPDATABLE, listOfsObjectRecord);

    if (decision.getRemovedFields().containsKey(objName) && !decision.getRemovedFields().get(objName).isEmpty()) {
        List<String> removedFieldsList = new List<String>(decision.getRemovedFields().get(objName));
        throw new SObjectException('Unable to assign all fields for update, insufficient user FLS:\n' + String.join(removedFieldsList, '\n'));
    }

    return true;
}

    
    public static Boolean checkCreateAccessDynamic(List<sObject> listOfsObjectRecord)
    {
        
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, listOfsObjectRecord);
        String objName = listOfsObjectRecord[0].getSObjectType().getDescribe().getLocalName();
        if (decision.getRemovedFields().containsKey(objName) && !decision.getRemovedFields().get(objName).isEmpty())
        {
            SObjectException ex = new SObjectException();
            List<String> removedFieldsList = new List<String>(decision.getRemovedFields().get(objName));
            ex.setMessage('Unable to assign all fields for Insert, insufficient user FLS:\n' + String.join(removedFieldsList, '\n'));
            throw ex;
        }
        return true;
    }

     
    public static List<Folder__c> getFolderListQuery(String folderId, String foldertype, String userid) {
        String queryBase = 'SELECT Id, Name, CreatedDate, CreatedBy.Name, Type__c, CreatedById, OwnerId FROM Folder__c WHERE ';
        List<Folder__c> folderRecords;
        
        if(foldertype == 'private' && folderId != null) {
            queryBase += ' Folder__c = :folderId AND CreatedById = :userid AND OwnerId = :userid ORDER BY Name';
            folderRecords = Database.query(queryBase);
            
        } else if(foldertype == 'shared') {
            Set<Id> folderIds = new Set<Id>();
            List<Folder__share> shareRecords = getFolderShareRecords(userid);
            for(Folder__share shareRecord : shareRecords) {
                folderIds.add(shareRecord.ParentId);
            }
            if(!folderIds.isEmpty()) {
                queryBase += ' Id IN :folderIds ORDER BY Name';
                folderRecords = Database.query(queryBase);
            } else {
                folderRecords = new List<Folder__c>();
            }
            
        } else if(foldertype == 'public') {
            queryBase += ' Folder__c = :folderId AND Type__c = \'public\' ORDER BY Name';
            folderRecords = Database.query(queryBase);
        } else {
            folderRecords = new List<Folder__c>();
        }
        
        return folderRecords;
    }
    
    // New helper method for fetching Folder__share records
    public static List<Folder__share> getFolderShareRecords(String userid) {
        return [
            SELECT Id, UserOrGroup.Name, RowCause, Parent.Name, ParentId 
            FROM Folder__share 
            WHERE UserOrGroupId = :userid
        ];
    }



    public static Folder__c getParentFolderRecord(Id parentId) {
        return [
            SELECT Id, Name, Type__c 
            FROM Folder__c 
            WHERE Id = :parentId 
            LIMIT 1
        ];
    }
    
    // New method to fetch child folders
    public static List<Folder__c> getChildFolders(Id parentId) {
        return [
            SELECT Name, Type__c, Folder__c 
            FROM Folder__c 
            WHERE Folder__r.Id = :parentId
        ];
    }

    public static List<Folder__c> getChildFoldersByParentName(String parentName) {
        return [
            SELECT Id, Name, Folder__c 
            FROM Folder__c 
            WHERE Folder__r.Name = :parentName
        ];
    }
    public static List<Folder__c> getRootParentFolders() {
        return [
            SELECT Id, Name, Folder__c, Type__c 
            FROM Folder__c 
            WHERE Folder__c = NULL
        ];
    }

    public static List<Folder__c> getFoldersById(Id folderId) {
        return [
            SELECT Id, Name 
            FROM Folder__c 
            WHERE Id = :folderId
        ];
    }

     public static List<uploaded_file_info__c> getFilesInFolder(Id folderId) {
        return [
            SELECT Folder__r.Name, Id, File_Name__c, ObjectKey__c
            FROM uploaded_file_info__c
            WHERE Folder__c = :folderId
        ];
    }

    
    public static List<Folder__c> getChildFoldersInFolder(Id folderId) {
        return [
            SELECT Id, Name
            FROM Folder__c
            WHERE Folder__c = :folderId
        ];
    }

     public static List<Folder__c> getAllFolderRecords() {
        return [
            SELECT Id, Name, Folder__c, Type__c, CreatedById, OwnerId 
            FROM Folder__c
        ];
    }
    

     public static Folder__c getFolderById(Id folderId) {
        List<Folder__c> result = [
            SELECT Name, Folder__r.Id 
            FROM Folder__c 
            WHERE Id = :folderId
        ];
        return (result.isEmpty()) ? null : result[0];
    }

    public static List<Folder__c> getFolderById1(Id folderId) {
    
    if (folderId == null) {
       
        return new List<Folder__c>();
    }

   
    return [
        SELECT Name
        FROM Folder__c
        WHERE Id = :folderId
    ];
}

   public static List<Folder__c> getRootFolders() {
        return [
            SELECT Id, Name, Folder__c, Type__c, CreatedById, OwnerId
            FROM Folder__c
            WHERE Folder__c = NULL
        ];
    }

    
    public static List<Folder__c> getFoldersByTypeAndParent(String parentId, String type) {
        String stringQuery = 'SELECT Id, Name, Folder__c, Type__c, CreatedById, OwnerId FROM Folder__c WHERE ';

        String userId = UserInfo.getUserId();
        if (type == 'private') {
            stringQuery += 'Folder__c = :parentId AND CreatedById = :userId AND OwnerId = :userId';
        } else if (type == 'shared') {
           
            stringQuery += 'Id IN (SELECT ParentId FROM Folder__share WHERE UserOrGroupId = :userId AND RowCause = \'Manual\')';
        } else { 
            stringQuery += 'Folder__c = :parentId AND Type__c = \'public\'';
        }

        return Database.query(stringQuery);
    }



}