Public with sharing class contactUpdateBatchApex Implements Database.Batchable<sObject>{
    
    
    
    Public Database.QueryLocator start(Database.BatchableContext bc ){
        
        return Database.getQueryLocator('SELECT Id FROM Contact WHERE UnSubsribeDate__c <Today');
    }
    
    Public void execute(Database.BatchableContext bc,List<sObject>Contacts){
        
        for(sObject contact: Contacts)
        {
            contact.put('DoNotCall',true);
            contact.put('HasOptedOutOfEmail',true);
            contact.put('HasOptedOutOfFax',true);
            
            
        }
       
        Update Contacts;
      
    }
    Public void finish(Database.BatchableContext bc ){
        
    }
    
}