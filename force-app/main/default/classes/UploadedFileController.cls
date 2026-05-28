/**
* @File Name : UploadedFileController.cls
* @Description : Controller class to handle file and folder operations.
**/
public with sharing class UploadedFileController {

    @AuraEnabled(cacheable=false)
    public static  List<Utils.UploadFileInfo> getFilesByParentId(Id parentId) {
        if (parentId == null) {
            return new  List<Utils.UploadFileInfo>();
        }
        return AWSQuerySharingHelper.getFilesByParentId(parentId);
    }

   @AuraEnabled
public static String deleteAllFiles(String parentId) {
    if (String.isBlank(parentId)) {
        throw new AuraHandledException('Parent ID is required.');
    }

    List<Uploaded_File_Info__c> filesToDelete = AWSQuerySharingHelper.getFilesForDelete(parentId);
    if (filesToDelete == null || filesToDelete.isEmpty()) {
        return 'No files found to delete';
    }
    Map<Id, String> errorById = AWSQuerySharingHelper.deleteFilesAndGetErrors(filesToDelete);
    if (!errorById.isEmpty()) {
        throw new AuraHandledException(
            'Some files could not be deleted: ' + String.join(errorById.values(), '; ')
        );
    }

    Integer successCount = filesToDelete.size() - errorById.size();
    return 'Successfully deleted ' + successCount + ' files';
}
    @AuraEnabled
    public static String deleteFile(String fileId) {
        try {
            if (String.isBlank(fileId)) {
                throw new AuraHandledException('File ID is required');
            }

            List<Uploaded_File_Info__c> filesToDelete = AWSQuerySharingHelper.getSingleFileById(fileId);
            if (filesToDelete == null || filesToDelete.isEmpty()) {
                throw new AuraHandledException('File not found');
            }

            AWSQuerySharingHelper.deleteSingleFile(filesToDelete[0]);
            return 'SUCCESS';

        } catch (Exception e) {
            throw new AuraHandledException('Error deleting file: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Boolean recordInsert(String parentObjectApiName, String parentRecordName, Id parentId,
                                       String fileName, String fileURL, String filetype, String objKey,
                                       Decimal filesize, Id folderId) {
        try {
            String objectName = '';
            String actualParentRecordName = parentRecordName;

            if (parentId != null) {
                try {
                    String objectType = parentId.getSObjectType().getDescribe().getName();
                    objectName = objectType;
                    if (String.isBlank(parentObjectApiName)) {
                        parentObjectApiName = objectType;
                    }
                } catch (Exception ex) {}
            }

            if (String.isBlank(objectName) && !String.isBlank(parentObjectApiName)) {
                objectName = parentObjectApiName;
            }

            if (String.isBlank(actualParentRecordName) && parentId != null && !String.isBlank(objectName)) {
                actualParentRecordName = AWSQuerySharingHelper.queryParentRecordName(parentId, objectName);
            }

            Uploaded_File_Info__c info = new Uploaded_File_Info__c(
                File_Type__c = filetype,
                Parent_Record_Name__c = actualParentRecordName,
                File_Url__c = fileURL,
                File_Name__c = fileName,
                Parent_Name__c = objectName,
                Parent_Record_Id__c = parentId,
                ObjectKey__c = objKey,
                File_Sizes__c = (filesize != null) ? String.valueOf(filesize) : null
            );

            AWSQuerySharingHelper.insertUploadedFileInfo(info);
            return true;

        } catch (Exception e) {
            throw new AuraHandledException('Error creating file record: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static String getParentRecordName(Id recordId, String objectApiName) {
        try {
            if (recordId == null) return '';
            if (String.isBlank(objectApiName)) {
                objectApiName = recordId.getSObjectType().getDescribe().getName();
            }
            return AWSQuerySharingHelper.queryParentRecordName(recordId, objectApiName);
        } catch (Exception e) {
            return '';
        }
    }

    @AuraEnabled(cacheable=false)
public static List<Utils.Folder> getFolders(Id recordId) {

    if (recordId == null) {
        return new List<Utils.Folder>();
    }

    return AWSQuerySharingHelper.getFoldersByRecord(recordId);
}
    @AuraEnabled
    public static Folder__c insertFolder(String name, Id parentFolderId, String parentObjectApiName, Id parentRecordId) {
    // Validate required inputs
    if (String.isBlank(name)) {
        throw new AuraHandledException('Folder name is required.');
    }

    if (parentRecordId == null) {
        throw new AuraHandledException('Parent record ID is required.');
    }

    if (String.isBlank(parentObjectApiName)) {
        throw new AuraHandledException('Parent object API name is required.');
    }

    String folderType = '';

    // Check if parent folder exists and get type
    if (parentFolderId != null) {
        Folder__c parentFolder = AWSQuerySharingHelper.getFolderDetails(parentFolderId);
        if (parentFolder != null && !String.isBlank(parentFolder.Type__c)) {
            folderType = parentFolder.Type__c;
        }
    }

    // Create new folder record
    Folder__c newFolder = new Folder__c(
        Name = name,
        Folder__c = parentFolderId,
        Type__c = folderType,
        Parent_Object__c = parentObjectApiName,
        Parent_Record_Id__c = parentRecordId
    );

    // Insert folder using helper
    AWSQuerySharingHelper.insertNewFolder(newFolder);
    return newFolder;
}

    @AuraEnabled(cacheable=true)
    public static Folder__c getFolderById(Id folderId) {
        if (folderId == null) return null;
        return AWSQuerySharingHelper.getFolderDetails(folderId);
    }

    @AuraEnabled
    public static void deleteFolder(Id folderId) {
        if (folderId != null) {
            AWSQuerySharingHelper.deleteFolderById(folderId);
        }
    }

    @AuraEnabled
    public static void deleteAllFolders(Id recordId) {
        if (recordId != null) {
            AWSQuerySharingHelper.deleteAllFoldersByRecordId(recordId);
        }
    }
    public class FolderFormConfig {
    @AuraEnabled public String objectApiName;
    @AuraEnabled public String nameField;
    @AuraEnabled public String parentFolderField;
}

@AuraEnabled
public static FolderFormConfig getFolderFormConfig() {
    FolderFormConfig config = new FolderFormConfig();
    config.objectApiName = 'Folder__c';
    config.nameField = 'Name';
    config.parentFolderField = 'Folder__c';
    return config;
}
}