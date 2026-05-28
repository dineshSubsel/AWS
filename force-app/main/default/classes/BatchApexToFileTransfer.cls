public with sharing class BatchApexToFileTransfer Implements Database.Batchable<sObject>,Database.AllowsCallouts {
    
    
    public Database.QueryLocator start(Database.BatchableContext Context)
    {
        Set<Id> ids=new Set<Id>();
        for(ContentDocumentLink link:[SELECT ContentDocumentId,LinkedEntityId FROM ContentDocumentLink where LinkedEntityId='0015j000019LAydAAG'])
        {
            ids.add(link.ContentDocumentId);
        }
        if(ids.isEmpty())
        {
            system.debug('Error provide valid Id'); 
        }
        
        
        return Database.getQueryLocator('SELECT VersionData,Title,ContentDocumentId,FileExtension,FileType,ContentSize FROM ContentVersion WHERE ContentDocumentId IN :ids AND IsLatest = true');
    }
    
    
    public void execute(Database.BatchableContext Context,List<ContentVersion> records)
    {
        List<HttpResponse> responses = new List<HttpResponse>();
        Http http = new Http();
        for(contentversion record:records)      
        {
            string endPoint='callout:awsfiletransfer/'+record.Title;
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endPoint);
            req.setMethod('PUT');
            req.setHeader('Content-Type', record.FileType);
            // req.setHeader('Content-Length', String.valueOf(record.ContentSize)); 
            req.setHeader('x-amz-acl', 'public-read');
            req.setBodyasblob(record.VersionData);
            HttpResponse res = http.send(req);
            responses.add(res);
        }
        for (HttpResponse res : responses) 
        {
            if (res.getStatusCode() == 200) 
            {
                system.debug('Status code'+res.getStatusCode());
                system.debug('Response Body'+ res.getBody());
                
            } 
            else 
            {
                system.debug('Status code'+res.getStatusCode());
                system.debug('Response Body'+ res.getBody());
            }
        }
    }
    
    public void finish(Database.BatchableContext Context)
    {
        
    }}