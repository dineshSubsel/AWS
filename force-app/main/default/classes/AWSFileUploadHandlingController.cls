public with sharing class AWSFileUploadHandlingController {

@AuraEnabled
public static Boolean updatingAccess(String Id, String AccessLevel, String Type) {
    try {
        List<SObject> recordsToUpdate = AWSQuerySharingHelper.getRecordsToUpdate(Id, Type);
        
        if (recordsToUpdate == null || recordsToUpdate.isEmpty()) {
            return false;
        }
        
        for (SObject record : recordsToUpdate) {
            record.put('AccessLevel', AccessLevel);
        }
        
        AWSQuerySharingHelper.updateAccessLevel(recordsToUpdate);
        return true;
    } catch (Exception e) {
        return false;
    }
}

@AuraEnabled
public static String updateFolderOwner(String folderId, String newOwnerId, String accessLevel) {
    try {
        folder__share folderShare = new folder__share();
        folderShare.ParentId = folderId;
        folderShare.UserOrGroupId = newOwnerId;
        folderShare.AccessLevel = accessLevel;
        folderShare.RowCause = Schema.folder__share.RowCause.Manual;
        Database.SaveResult sr =
            AWSQuerySharingHelper.insertFolderShare(folderShare);
        if (sr != null && sr.isSuccess()) {
            return 'Success';
        }
        return 'Insert Failed';
    } catch (Exception e) {
        return 'Error: ' + e.getMessage();
    }
}

@AuraEnabled
public static String updateFileOwner(String fileId, String newOwnersId, String accessLevel) {
    try {
        Uploaded_File_Info__share fileShare =
            new Uploaded_File_Info__share();
        fileShare.ParentId = fileId;
        fileShare.UserOrGroupId = newOwnersId;
        fileShare.AccessLevel = accessLevel;
        fileShare.RowCause =
            Schema.Uploaded_File_Info__share.RowCause.Manual;
        Database.SaveResult sr =
            AWSQuerySharingHelper.insertFileShare(fileShare);
        if (sr != null && sr.isSuccess()) {
            return 'Success';
        }
        return 'Insert Failed';
    } catch (Exception e) {

        return 'Error: ' + e.getMessage();
    }
}
@AuraEnabled 
public static Boolean recordInsert(
    String parent, 
    String parentRecordName, 
    Id parentId, 
    String fileName, 
    String fileURL, 
    String filetype, 
    String objKey, 
    Decimal filesize
) {
    try {
        // Extract folder names from object key
        List<String> keylist = objKey.split('/');
        keylist.remove(keylist.size() - 1);
        
        // Retrieve existing folders once
        List<Folder__c> existingFolders = AWSQuerySharingHelper.getAllFolders();
        
        // Map to track which folders need to be created
        Set<String> existingFolderNames = new Set<String>();
        for (Folder__c folder : existingFolders) {
            existingFolderNames.add(folder.Id);
        }
        
        // List to hold folders that need to be created
        List<Folder__c> foldersToInsert = new List<Folder__c>();
        
        // Check which folders need to be created
        for (String folderName : keylist) {
            if (!existingFolderNames.contains(folderName)) {
                Folder__c newFolder = new Folder__c();
                newFolder.Name = folderName;
                
                // Determine folder type based on first segment
                if (!keylist.isEmpty()) {
                    String rootFolder = keylist[0];
                    if (rootFolder == 'private' || rootFolder == 'public' || rootFolder == 'shared') {
                        newFolder.Type__c = rootFolder;
                    }
                }
                
                foldersToInsert.add(newFolder);
                // Add to tracking set to avoid duplicates in this batch
                existingFolderNames.add(folderName);
            } else {
                break;
            }
        }
        
        if (foldersToInsert != null && !foldersToInsert.isEmpty()) {
            AWSQuerySharingHelper.insertFolderList(foldersToInsert);
        }
        
        // Create the file info record
        Uploaded_File_Info__c info = new Uploaded_File_Info__c();
        info.Folder__c = parent;
        info.File_Type__c = filetype;
        info.Parent_Record_Name__c = parentRecordName;
        info.File_Url__c = fileURL;
        info.File_Name__c = fileName;
        info.Parent_Name__c = parent;
        info.Parent_Record_Id__c = (String) parentId;
        info.ObjectKey__c = objKey;
        info.File_Sizes__c = String.valueOf(filesize);
        
        AWSQuerySharingHelper.insertUploadedFileInfo(info);
        
        return true;
    } catch (Exception e) {
        // Log the exception and return false
        return false;
    }
}

//deleting the record from upload file info object by getting record Id as parameter
@AuraEnabled(cacheable=false)
public static List<Utils.UploadFileInfo> deleteCallout(String recordId) {

    if (String.isEmpty(recordId)) {
        return new List<Utils.UploadFileInfo>();
    }

    try {
        Uploaded_File_Info__c oldRec =  new Uploaded_File_Info__c();
        if(recordId != null){
           oldRec = AWSQuerySharingHelper.getUploadedFileInfoById(recordId);
        }
        
        if (oldRec != null) {
            AWSQuerySharingHelper.deleteFileRecord(oldRec);

            return AWSQuerySharingHelper.getUploadedFileInfosByParentId(oldRec.Parent_Record_Id__c);
        }

    } catch (Exception e) {
        return new List<Utils.UploadFileInfo>();
    }

    return new List<Utils.UploadFileInfo>();
}

//Getting records for check the duplicates 
@AuraEnabled(cacheable=false)
public static List<Utils.UploadFileInfo> fetchExistingFileNames(Id parentId) {
    if(parentId == null){
        return new List<Utils.UploadFileInfo>();
    }
    return AWSQuerySharingHelper.getUploadedFileInfosByParentId(parentId);
}
@AuraEnabled(cacheable=false)
public static List<Utils.UploadFileInfo> fetchExistingFileNameunderFolder(String folderId) {

    List<Utils.UploadFileInfo> wrapperList = new List<Utils.UploadFileInfo>();

    List<Uploaded_File_Info__c> fileList = AWSQuerySharingHelper.getUploadedFileInfosByFolderId(folderId);

    for(Uploaded_File_Info__c fileRec : fileList){
        Utils.UploadFileInfo wrap = new Utils.UploadFileInfo();

        wrap.id = fileRec.Id;
        wrap.fileName = fileRec.File_Name__c;
        wrap.fileURL = fileRec.File_Url__c;
        wrap.fileSize = fileRec.File_Sizes__c;
        wrap.parentName = fileRec.Parent_Record_Name__c;
        wrap.parentRecordId = fileRec.Parent_Record_Id__c;
        wrap.createdDate = fileRec.CreatedDate;
        wrap.uploadedBy = fileRec.CreatedBy.Name;

        wrapperList.add(wrap);
    }

    return wrapperList;
}

@AuraEnabled
public static List<Utils.UploadFileInfo> getAWSFiles(String parentId, String foldertype) {

    List<Utils.UploadFileInfo> resultWrapper = new List<Utils.UploadFileInfo>();

    List<Uploaded_file_info__c> files =
        AWSQuerySharingHelper.getAWSFilesByParentAndFolderType(parentId, foldertype);

    for (Uploaded_file_info__c rec : files) {

        Utils.UploadFileInfo wrap = new Utils.UploadFileInfo();

        wrap.id = rec.Id;
        wrap.fileName = rec.File_Name__c;
        wrap.fileSize = rec.File_sizes__c;
        wrap.fileType = rec.File_Type__c;
        wrap.fileURL = rec.File_url__c;
        wrap.createdDate = rec.CreatedDate;
        wrap.uploadedBy = rec.CreatedBy.Name;
        wrap.objectKey = rec.ObjectKey__c;
        wrap.lastModifiedDate = rec.LastModifiedDate;

        resultWrapper.add(wrap);
    }

    return resultWrapper;
}

@AuraEnabled(cacheable=true)
public static List<User> getUsers() {
    return AWSQuerySharingHelper.getUsersByProfile();
}

@AuraEnabled(cacheable=false)
public static String getssharingdetails(String parentId, String type) {
    return AWSQuerySharingHelper.getSharingDetailsByParentIdAndType(parentId, type);
}

@AuraEnabled
public static Boolean removeAccess(List<Id> IDs, String type) {
    return AWSQuerySharingHelper.removeAccessByIdsAndType(IDs, type);
}

@AuraEnabled
public static void updateUrl(String ID, String URL) {
    if (ID == null || URL == null) {
        return;
    }
    Uploaded_File_Info__c file = new Uploaded_File_Info__c();
    file.Id = ID;
    file.File_Url__c = URL;

    AWSQuerySharingHelper.updateUploadedFileUrl(file);
}

@AuraEnabled
public static Boolean deleteAccess(String fileId, String objectName) {
    if (fileId == null || objectName == null) {
        return false;
    }

    return AWSQuerySharingHelper.checkAccessAndOwnership(fileId, objectName);
}
  @AuraEnabled
public static Utils.AwsSettings getAWSConfiguration() {

        return AWSQuerySharingHelper.fetchAWSConfiguration();
 
}
}