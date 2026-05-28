/*public with sharing class filderController_Clone {
    @AuraEnabled(cacheable=true)
    public static List<Folder__c> getFolderList(String folderId) {
        if (folderId == null) {
            return new List<Folder__c>();
        }
        
        List<Folder__c> folders = [SELECT Id, Name, CreatedDate, CreatedBy.Name FROM Folder__c WHERE Id = :folderId];
        return (List<Folder__c>) Security.stripInaccessible(AccessType.READABLE, folders).getRecords();
    }
    
    @AuraEnabled
    public static String addFolder(Id parentId, String folderName) {
        try {
            if (parentId == null || String.isEmpty(folderName)) {
                return 'Invalid input parameters';
            }

            Folder__c parentFolder = [SELECT Id, Name, Type__c FROM Folder__c WHERE Id = :parentId LIMIT 1];
            
            if (parentFolder.Type__c == null) {
                return 'Parent folder type is missing';
            }
            
            List<Folder__c> allFolders = [SELECT Name FROM Folder__c WHERE Type__c = :parentFolder.Type__c];
            
            for (Folder__c existingFolder : allFolders) {
                if (folderName.equalsIgnoreCase(existingFolder.Name)) {
                    return 'Duplicate folder name found: ' + folderName;
                }
            }
            
            Folder__c newFolder = new Folder__c(
                Name = folderName,
                Type__c = parentFolder.Type__c,
                Folder__c = parentFolder.Id
            );
            
            SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, new List<Folder__c>{newFolder});
            List<SObject> accessibleRecords = decision.getRecords();
            
            if (!accessibleRecords.isEmpty()) {
                insert (List<Folder__c>) accessibleRecords;
            }
            
            return 'Folder added successfully';
        } catch (Exception e) {
            return 'An error occurred: ' + e.getMessage();
        }
    }
    
    @AuraEnabled(cacheable=false)
    public static List<Folder__c> getChildFolder(String parentName) {
        if (String.isEmpty(parentName)) {
            return new List<Folder__c>();
        }
        
        List<Folder__c> result = [SELECT Id, Name, Folder__c FROM Folder__c WHERE Folder__r.Name = :parentName];
        return (List<Folder__c>) Security.stripInaccessible(AccessType.READABLE, result).getRecords();
    }
    
    @AuraEnabled(cacheable=false)
    public static List<TreeNode> getTreeData() {
        List<TreeNode> treeData = new List<TreeNode>();
        Map<Id, TreeNode> nodeMap = new Map<Id, TreeNode>();
        
        List<Folder__c> records = [SELECT Id, Name, Folder__c FROM Folder__c];
        records = (List<Folder__c>) Security.stripInaccessible(AccessType.READABLE, records).getRecords();
        
        for (Folder__c record : records) {
            TreeNode node = new TreeNode(record.Name, String.valueOf(record.Id));
            nodeMap.put(record.Id, node);
            
            if (record.Folder__c == null) {
                treeData.add(node);
            }
        }
        
        for (Folder__c record : records) {
            TreeNode childNode = nodeMap.get(record.Id);
            TreeNode parentNode = nodeMap.get(record.Folder__c);
            
            if (childNode != null && parentNode != null) {
                parentNode.items.add(childNode);
            }
        }
        
        return treeData;
    }
    
    public class TreeNode {
        @AuraEnabled public String label;
        @AuraEnabled public String name;
        @AuraEnabled public Boolean expanded = false;
        @AuraEnabled public List<TreeNode> items = new List<TreeNode>();
        
        public TreeNode(String label, String name) {
            this.label = '📂 ' + label;
            this.name = name;
        }
    }
    
    @AuraEnabled(cacheable=false)
    public static List<TreeNode> getChildComponents(Id folderId) {
        List<TreeNode> treeData = new List<TreeNode>();
        Map<Id, TreeNode> nodeMap = new Map<Id, TreeNode>();
        Set<Id> visitedFolderIds = new Set<Id>();
        List<Folder__c> childList = new List<Folder__c>();
        
        getChildrenRecursive(folderId, nodeMap, visitedFolderIds, childList);
        
        for (Folder__c childFolder : childList) {
            TreeNode node = new TreeNode(childFolder.Name, String.valueOf(childFolder.Id));
            nodeMap.put(childFolder.Id, node);
            
            if (childFolder.Folder__c != null) {
                treeData.add(node);
            }
        }
        
        for (Folder__c childFolder : childList) {            
            TreeNode childNode = nodeMap.get(childFolder.Id);
            TreeNode parentNode = nodeMap.get(childFolder.Folder__c);
            
            if (childNode != null && parentNode != null) {
                parentNode.items.add(childNode);
            }   
            
            if (parentNode != null) {
                treeData.add(parentNode);
            }                            
        }
        
        return treeData;
    }
    
    private static void getChildrenRecursive(Id folderId, Map<Id, TreeNode> nodeMap, Set<Id> visitedFolderIds, List<Folder__c> childList) {
        if (folderId == null || visitedFolderIds.contains(folderId)) {
            return;
        }
        
        visitedFolderIds.add(folderId);
        List<Folder__c> childFolders = [SELECT Id, Name, Folder__c FROM Folder__c WHERE Folder__c = :folderId];
        childFolders = (List<Folder__c>) Security.stripInaccessible(AccessType.READABLE, childFolders).getRecords();
        
        childList.addAll(childFolders);
        
        for (Folder__c childFolder : childFolders) {
            getChildrenRecursive(childFolder.Id, nodeMap, visitedFolderIds, childList);
        }
    }
}*/


// Original code Keep on Below
public  with sharing  class filderController_Clone {
     @AuraEnabled(cacheable=true)
    public static List<Folder__c> getFolderList(String folderId) {
        List<Folder__c> folders = new List<Folder__c>();
        if(folderId != Null){ //null Check added
         folders = [SELECT Id,Name,CreatedDate,CreatedBy.Name FROM Folder__c WHERE Folder__c=:folderId WITH SECURITY_ENFORCED ];
         }
            return folders;
    }
    // @AuraEnabled
    // public static Boolean addFolder(Id parentId, String folderName){
    //     try {
    //         Folder__c parentFolder = [SELECT Id,Name, Type__c FROM Folder__c WHERE Id = :parentId LIMIT 1];
    //       list < Folder__c> allFolder = [SELECT Name FROM Folder__c WHERE Type__c =:parentFolder.Type__c];
    //         System.debug('AllFolders......>>>'+allFolder);
    //         if (parentFolder != null) {
    //             Folder__c newFolder = new Folder__c(
    //                 Name = folderName,
    //                 Type__c = parentFolder.Type__c,
    //                 Folder__c = parentFolder.Id
    //             );
    //             System.debug('parentType'+ parentFolder.Type__c + 'parentId'+parentFolder.Id);
    //             insert newFolder;

    //             return true;
    //         } else {
    //             System.debug('Parent folder not found.');
    //             return false;
    //         }
    //     } catch (Exception e) {
    //         System.debug('An error occurred: ' + e.getMessage());
    //         return false;
    //     }
  
    // }

    //////////////////////////////////////////////
@AuraEnabled
public static String addFolder(Id parentId, String folderName) {
    try {
        if(parentId != null){
        // Query for the parent folder
        Folder__c parentFolder = [SELECT Id, Name, Type__c FROM Folder__c WHERE Id = :parentId LIMIT 1 ];
        if(parentFolder.Type__c != null){ // null check added
        // Query for all folders with the same Type__c as the parent folder
        List<Folder__c> allFolders = [SELECT Name FROM Folder__c WHERE Type__c = :parentFolder.Type__c WITH SECURITY_ENFORCED ];
      
        // Check for duplicate folder names
        for (Folder__c existingFolder : allFolders) {
            if (folderName.equalsIgnoreCase(existingFolder.Name)) {
                System.debug('Duplicate folder name found: ' + folderName);
                return 'Duplicate folder name found: ' + folderName;
            }
        }
        }

        // If no duplicate is found, proceed with folder creation
        Folder__c newFolder = new Folder__c(
            Name = folderName,
            Type__c = parentFolder.Type__c,
            Folder__c = parentFolder.Id
        );
        if(ValidateFSLClass.checkCreateAccessDynamic(new List<Folder__c> {newFolder})){
        /* sfge-disable-next-line ApexFlsViolationRule */
        Database.insert(newFolder, AccessLevel.SYSTEM_MODE);
        }
        }
        return 'Folder added successfully';
    } catch (QueryException qe) {
        System.debug('Query Exception: ' + qe.getMessage());
        return 'Query Exception: ' + qe.getMessage();
    } catch (Exception e) {
        System.debug('An error occurred: ' + e.getMessage());
        return 'An error occurred: ' + e.getMessage();
    }
}



    ////////////////////////////////////////////////
    @AuraEnabled(cacheable=false)
    public static List<Folder__c> getChildFolder(String parentName){
        list<Folder__c> Result=new List<Folder__c>();
        try{
            if(parentName != null){
            Result=[SELECT Id,Name,Folder__c FROM Folder__c WHERE Folder__r.Name=:parentName WITH SECURITY_ENFORCED];
            }
            return Result;
        }
        catch(Exception e){
            System.debug('An error occurred: ' + e.getMessage());
            return null;
        }
    }
    
    
    @AuraEnabled(cacheable=false)
    public static List<TreeNode> getTreeData() {
        List<TreeNode> treeData = new List<TreeNode>();
        Map<Id, TreeNode> nodeMap = new Map<Id, TreeNode>();
        List<Folder__c> records = [SELECT Id, Name, Folder__c FROM Folder__c WITH SECURITY_ENFORCED];
        
        
        System.debug('Folder Records List'+records);
        for (Folder__c record : records) {
            TreeNode node = new TreeNode();
            node.label = '📂 ' + record.Name;
            node.name = String.valueOf(record.Id);
            node.expanded = false;
            node.items = new List<TreeNode>();

            nodeMap.put(record.Id, node);
            
            if (record.Folder__c == null) {
                treeData.add(node);
            }
        }
        
        for (Folder__c record : records) {            
            TreeNode childNode = nodeMap.get(record.Id);
            TreeNode parentNode = nodeMap.get(record.Folder__c);            
            if (childNode != null && parentNode != null) {
                parentNode.items.add(childNode);
            }                                    
        }
       System.debug('treeDataParent'+treeData);
        return treeData;
    }
    
    public class TreeNode {
        @AuraEnabled public String label; 
        @AuraEnabled public String name; 
        @AuraEnabled public Boolean expanded;
        @AuraEnabled public List<TreeNode> items;
    }
    
  
   @AuraEnabled(cacheable=false)
public static List<TreeNode> getChildComponents(Id folderId) {
    List<TreeNode> treeData = new List<TreeNode>();
    List<Folder__c> childList = new List<Folder__c>();  // Create a list to store childFolders

    Map<Id, TreeNode> nodeMap = new Map<Id, TreeNode>();
    Set<Id> visitedFolderIds = new Set<Id>();
    
    getChildrenRecursive(folderId, nodeMap, visitedFolderIds, childList); // Pass childList as a parameter

    // Process the childList to create tree nodes or perform other actions if needed
    for (Folder__c childFolder : childList) {
        TreeNode node = new TreeNode();
        node.label = '📂 ' + childFolder.Name;
        node.name = String.valueOf(childFolder.Id);
        node.expanded = false;
        node.items = new List<TreeNode>();

        nodeMap.put(childFolder.Id, node);
            
            if (childFolder.Folder__c != null) {
                treeData.add(node);
            }
    }

    // Get the top-level nodes (folders without a parent)
        for (Folder__c childFolder : childList) {            
            TreeNode childNode = nodeMap.get(childFolder.Id);
            TreeNode parentNode = nodeMap.get(childFolder.Folder__c);            
            if (childNode != null && parentNode != null) {
                parentNode.items.add(childNode);
            }   
           // treeData.add(childNode);     
            treeData.add(parentNode);
                System.debug('ParentNode  ..>>'+parentNode);                             
        }

    System.debug('childList  ..>>'+childList);
    System.debug('treeData...' + treeData);
    return treeData;
}

private static void getChildrenRecursive(Id folderId, Map<Id, TreeNode> nodeMap, Set<Id> visitedFolderIds, List<Folder__c> childList) {
    visitedFolderIds.add(folderId);
    if(folderId != null){
    List<Folder__c> childFolders = [SELECT Id, Name, Folder__c FROM Folder__c WHERE Folder__c = :folderId WITH SECURITY_ENFORCED ];
    
    // Add childFolders to the childList
    childList.addAll(childFolders);
    for (Folder__c childFolder : childFolders) {
        TreeNode node = new TreeNode();
        node.label = '📂 ' + childFolder.Name;
        node.name = String.valueOf(childFolder.Id);
        node.expanded = false;
        node.items = new List<TreeNode>();

        nodeMap.put(childFolder.Id, node);

        getChildrenRecursive(childFolder.Id, nodeMap, visitedFolderIds, childList);
    }
}
}
}