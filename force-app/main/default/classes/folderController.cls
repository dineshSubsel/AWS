public with sharing class folderController {
    public class TreeNode {
        @AuraEnabled public String label; 
        @AuraEnabled public String name; 
        @AuraEnabled public Boolean expanded;
        @AuraEnabled public String type;
        @AuraEnabled public List<TreeNode> items;
        @AuraEnabled public string CreatedById;
        @AuraEnabled public string OwnerId;
    }
    
    public class FileAndFolderWrapper {
        @AuraEnabled public List<uploaded_file_info__c> files { get; set; }
        @AuraEnabled public List<Folder__c> folders { get; set; }
    }
    
    public class folderwrapper {
        @AuraEnabled public List<Utils.Folder> folder { get; set; }
        @AuraEnabled public String Accesstype { get; set; }
        
        public folderwrapper(List<Utils.Folder> folder, String Accesstype) {
            this.folder = folder != null ? folder : new List<Utils.Folder>();
            this.Accesstype = Accesstype;
        }
    }
    
    @AuraEnabled(cacheable=false)
    public static folderwrapper getFolderList(String folderId, String foldertype) {
        if(folderId == null){
            return null;
        }
        String accesstype = foldertype;
        String userId = UserInfo.getUserId();
        
        List<Folder__c> folders = new List<Folder__c>();
        
        if (foldertype == 'private' && folderId != null && userId != null) {
            folders = AWSQuerySharingHelper.getPrivateFolders(folderId, userId);
            
            if (AWSQuerySharingHelper.isFolderSharedWithUser(folderId, userId)) {
                accesstype = 'shared';
            }
            
        } 
        else if (foldertype == 'shared' && userId != null) {
            folders = AWSQuerySharingHelper.getSharedFolders(userId);
        } 
        else if (foldertype == 'public' && folderId != null && userId != null) {
            folders = AWSQuerySharingHelper.getPublicFolders(folderId);
        }
        
        List<Utils.Folder> wrapperList = convertFolders(folders);
        return new folderwrapper(wrapperList, accesstype);
    }
    @TestVisible
    private static List<Utils.Folder> convertFolders(List<Folder__c> folders){
        
        List<Utils.Folder> result = new List<Utils.Folder>();
        
        if(folders == null) return result;
        
        for(Folder__c f : folders){
            
            Utils.Folder wrap = new Utils.Folder();
            
            wrap.id = f.Id;
            wrap.name = f.Name;
            wrap.createdDate = f.CreatedDate;
            wrap.createdBy = f.CreatedBy.Name;
            wrap.type = f.Type__c;
            wrap.ownerId = f.OwnerId;
            wrap.createdById = f.CreatedById;
            
            result.add(wrap);
        }
        
        return result;
    }
    @AuraEnabled(cacheable=false)
    public static folderwrapper getSharedFolderList(String folderId) {
        List<Folder__c> folders = new List<Folder__c>();
        if (folderId != null) {
            folders = AWSQuerySharingHelper.getSharedFolderList(folderId);
        }
        return new folderwrapper(convertFolders(folders), 'Shared');
    }
    @AuraEnabled
    public static String addFolder(Id parentId, String folderName) {
        if (parentId == null || folderName == null) {
            return 'Parent ID and folder name are required.';
        }
        
        try {
            Folder__c parentFolder = AWSQuerySharingHelper.getFolderByIds(parentId);
            if (parentFolder == null) {
                return 'Parent folder not found.';
            }
            
            String folderType = parentFolder.Type__c;
            Id currentUserId = UserInfo.getUserId();
            
            Boolean isDuplicate = false;
            if(currentUserId != null){
               isDuplicate = AWSQuerySharingHelper.isDuplicateFolderName(parentId, folderName, folderType, currentUserId);
            }
            if (isDuplicate) {
                return 'Duplicate folder name found: ' + folderName;
            }
            
            Folder__c newFolder = new Folder__c(
                Name = folderName,
                Type__c = folderType,
                Folder__c = parentFolder.Id
            );
            
            AWSQuerySharingHelper.insertsFolder(newFolder);
            return 'Folder added successfully';
            
        } catch (QueryException qe) {
            return 'Query Exception: ' + qe.getMessage();
        } catch (Exception e) {
            return 'An error occurred: ' + e.getMessage();
        }
    }
    
    @AuraEnabled(cacheable=false)
    public static List<Folder__c> getChildFolder(String parentName) {
        try {
            if (parentName != null) {
                return AWSQuerySharingHelper.getChildFoldersByParentName(parentName);
            }
        } catch (Exception e) {}
        return new List<Folder__c>(); 
    }
    
    @AuraEnabled(cacheable=false)
    public static List<TreeNode> getTreeData() {
        List<TreeNode> treeData = new List<TreeNode>();
        Map<Id, TreeNode> nodeMap = new Map<Id, TreeNode>();
        
        List<Folder__c> records = AWSQuerySharingHelper.getAllFolder();
        if (records == null) {
            return treeData; 
        }
        
        for (Folder__c record : records) {
            TreeNode node = new TreeNode();
            node.label = record.Name;
            node.type = record.Type__c;
            node.name = String.valueOf(record.Id);
            node.expanded = false;
            node.CreatedById = record.CreatedById;
            node.OwnerId = record.OwnerId;
            node.items = new List<TreeNode>();
            nodeMap.put(record.Id, node);
            
            if (record.Folder__c == null) {
                treeData.add(node);
            }
        }
        
        for (Folder__c record : records) {
            if (nodeMap.containsKey(record.Id) && nodeMap.containsKey(record.Folder__c)) {
                nodeMap.get(record.Folder__c).items.add(nodeMap.get(record.Id));
            }
        }
        
        return treeData;
    }
    
    @AuraEnabled(cacheable=false)
    public static List<Folder__c> getRootParent() {
        try {
            List<Folder__c> roots = AWSQuerySharingHelper.getRootParentFolders();
            return roots != null ? roots : new List<Folder__c>();
        } catch (Exception e) {
            return new List<Folder__c>();
        }
    }
    
    @AuraEnabled(cacheable=false)
    public static FileAndFolderWrapper getAllFilesAndFoldersInFolder(Id folderId) {
        FileAndFolderWrapper result = new FileAndFolderWrapper();
        result.files = new List<uploaded_file_info__c>();
        result.folders = new List<Folder__c>();
        
        if (folderId != null) {
            Folder__c folder = AWSQuerySharingHelper.getSingleFolderById(folderId);
            if (folder != null) {
                result.folders.add(folder);
            }
        }
        
        Check(folderId, result);
        return result;
    }
    
    private static void Check(Id folderId, FileAndFolderWrapper result) {
        if (folderId != null && result != null) {
            List<uploaded_file_info__c> files = AWSQuerySharingHelper.getFilesInFolder(folderId);
            List<Folder__c> childFolders = AWSQuerySharingHelper.getChildFolders(folderId);
            
            if (files != null) result.files.addAll(files); 
            if (childFolders != null) {
                result.folders.addAll(childFolders);
                for (Folder__c folder : childFolders) {
                    Check(folder.Id, result);
                }
            }
        }
    }
    
    @AuraEnabled
    public static Boolean deletefolder(List<Folder__c> folderList) {
        try {
            
            if (folderList == null || folderList.isEmpty()) {
                return false; 
            }
            AWSQuerySharingHelper.deleteFolders(folderList);
            return true;
        } catch (Exception e) {
            return false;
        }
    }
    
    @AuraEnabled(cacheable=false)
    public static Folder__c getBackToParent(Id parentId) {
        if (parentId == null) return null;
        try {
            return AWSQuerySharingHelper.getParentFolder(parentId);
        } catch (Exception e) {
            return null;
        }
    }
    
    @AuraEnabled(cacheable=false)
    public static Folder__c getFolderName(Id recordId) {
        if (recordId == null) return null; 
        try {
            return AWSQuerySharingHelper.getFolderByIds(recordId);
        } catch (Exception e) {
            return null;
        }
    }
    
    @AuraEnabled(cacheable=false)
    public static List<TreeNode> getfoldertree(String parentId, String type) {
        List<TreeNode> treeData = new List<TreeNode>();
        
        if (parentId == null && type == null) {
            List<Folder__c> rootFolders = AWSQuerySharingHelper.getRootFolders();
            if (rootFolders == null) return treeData; 
            for (Folder__c record : rootFolders) {
                TreeNode node = new TreeNode();
                node.label = record.Name;
                node.type = record.Type__c;
                node.name = String.valueOf(record.Id);
                node.expanded = false;
                node.CreatedById = record.CreatedById;
                node.OwnerId = record.OwnerId;
                node.items = getfoldertree(String.valueOf(record.Id), record.Type__c);
                treeData.add(node);
            }
        } else {
            List<Folder__c> childFolders = AWSQuerySharingHelper.getChildFolders(parentId, type);
            if (childFolders != null) {
                for (Folder__c record : childFolders) {
                    TreeNode node = new TreeNode();
                    node.label = record.Name;
                    node.type = record.Type__c;
                    node.name = String.valueOf(record.Id);
                    node.expanded = false;
                    node.CreatedById = record.CreatedById;
                    node.OwnerId = record.OwnerId;
                    node.items = getfoldertree(String.valueOf(record.Id), record.Type__c);
                    treeData.add(node);
                }
            }
        }
        
        return treeData; 
    }
}