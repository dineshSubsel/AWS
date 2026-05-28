public with sharing class deleteContactBatchApex Implements Database.Batchable<sObject> {
    
    
    
    public Database.QueryLocator start(Database.BatchableContext bc){
        
        return Database.getQueryLocator('SELECT Id FROM Contact WHERE Createddate=Today');
        
    }
    public void execute(Database.BatchableContext bc,List<sObject>Scope)
    {
        
        List<Contact>conList= new List<Contact>();
        conList=Scope;
        
        if(conList.size()>0)
        {
            Delete conList;
        }
        
        
    }
    
    public void finish(Database.BatchableContext bc ){
        
        
    }
    
    
    
    
}