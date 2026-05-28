/**
* ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
* Class Name      : s3Wrapper
* Author          : <YourName>
* Created Date    : Mar 12, 2026
* Last Modified By: <YourName>
* Last Modified On: Mar 12, 2026
* Description     : This class implements for......
* ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
*/


public with sharing class Utils {
    
    public class UploadFileInfo {
            @AuraEnabled public Id id { get; set; }  
        @AuraEnabled public String fileName { get; set; }       
        @AuraEnabled public String fileSize { get; set; }       
        @AuraEnabled public String fileType { get; set; }       
        @AuraEnabled public String fileURL { get; set; }         
        @AuraEnabled public String folder { get; set; }         
        @AuraEnabled public String parentName { get; set; }      
        @AuraEnabled public String parentRecordId { get; set; }  
        @AuraEnabled public String name { get; set; } 
       @AuraEnabled public Datetime createdDate { get; set; }
    @AuraEnabled public String uploadedBy { get; set; } 
     @AuraEnabled public String objectKey {get;set;}
     @AuraEnabled public Datetime lastModifiedDate {get;set;}   
    }
    
    public class Folder {
        @AuraEnabled public String awsFolderPath { get; set; }     
        @AuraEnabled public String folderId { get; set; }          
        @AuraEnabled public String folderName { get; set; }         
        @AuraEnabled public Boolean parentFolder { get; set; }     
        @AuraEnabled public String parentObject { get; set; }      
        @AuraEnabled public String parentRecordId { get; set; }     
        @AuraEnabled public Boolean shareFolder { get; set; }      
        @AuraEnabled public String type { get; set; }  
        @AuraEnabled public String objectApiName { get; set; } 

         @AuraEnabled public Id id {get;set;}
    @AuraEnabled public String name {get;set;}
    @AuraEnabled public Datetime createdDate {get;set;}
    @AuraEnabled public String createdBy {get;set;}
    @AuraEnabled public Id ownerId {get;set;}
    @AuraEnabled public Id createdById {get;set;}      
    }
    
    public class AwsSettings {
        @AuraEnabled public String awsAccessKeyId { get; set; } 
        @AuraEnabled public String awsSecretAccessKey { get; set; }
        @AuraEnabled public String s3BucketName { get; set; }
        @AuraEnabled public String s3RegionName { get; set; }
        @AuraEnabled public String apiVersion { get; set; }
        @AuraEnabled public String signatureVersion { get; set; }
    }
    
}