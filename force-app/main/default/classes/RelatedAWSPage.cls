// validation added the moodified class

/*public with sharing class RelatedAWSPage {
    
    public List<NoteAndAttachment> NotesList { get; set; }

    public RelatedAWSPage(ApexPages.StandardController std) {
        NotesList = new List<NoteAndAttachment>();
        GetNotes();
    }

    public PageReference HandleEdit() {
        String NoteID = ApexPages.currentPage().getParameters().get('NoteID');
        System.debug(NoteID);
        if (NoteID != NULL) {
            String EditPageURL = '/' + NoteID + '/e?retURL=%2F' + NoteID;
            PageReference pageRef = new PageReference(EditPageURL);
            pageRef.setRedirect(true);
            return pageRef;
        }
        return NULL;
    }

    public PageReference HandleDelete() {
        String NoteID = ApexPages.currentPage().getParameters().get('NoteID');
        String ContactID = ApexPages.currentPage().getParameters().get('id');
        System.debug(NoteID);

        if (NoteID != NULL) { 
            // ✅ CRUD Security Check for DELETE Operation
            if (Schema.sObjectType.Note.isDeletable()) {
                List<Note> notes = [SELECT Id, Title FROM Note WHERE Id = :NoteID];

                if (!notes.isEmpty()) {
                    delete notes;
                    System.debug('HandleDelete FN');
                }
            } else {
                System.debug('User does not have permission to delete Note records.');
                return null;
            }
        }

        this.GetNotes();
        String EditPageURL = '/apex/DelVF?id=' + ContactID;
        PageReference pageRef = new PageReference(EditPageURL);
        pageRef.setRedirect(true);
        return pageRef;
    }

    public void GetNotes() {
        System.debug('GetNotes FN');
        String ContactID = ApexPages.currentPage().getParameters().get('id');

        if (ContactID == NULL) {
            System.debug('No Id available');
        } else {
            Contact[] CNotes = [SELECT Id, 
                                       (SELECT Id, IsNote, Title, LastModifiedDate, CreatedBy.Name 
                                        FROM NotesAndAttachments)  
                                FROM Contact WHERE Id = :ContactID];

            // ✅ Enforce FLS on NotesAndAttachments fields
            List<Contact> safeContacts = (List<Contact>) Security.stripInaccessible(AccessType.READABLE, CNotes).getRecords();

            for (Contact c : safeContacts) {
                for (NoteAndAttachment obj : c.NotesAndAttachments) {
                    NotesList.add(obj);
                }
            }
        }
    }
}*/



// validation fls violation old class
public with sharing class RelatedAWSPage{
    
    public noteandattachment[] NotesList{get;set;}
    
    public RelatedAWSPage(ApexPages.standardController std){
        NotesList=new noteandattachment[]{};
            GetNotes();
    }
    
    public pagereference HandleEdit(){
        String NoteID=ApexPages.currentPage().getParameters().get('NoteID');
        system.debug(NoteID);
        if(NoteID!=NULL){
            String EditPageURL='/'+NoteID+'/e?retURL=%2F'+NoteID;
            PageReference pageRef = new PageReference(EditPageURL);
            pageref.setRedirect(true);
            return pageRef;
        }
        return NULL;
    }
    
    public pagereference HandleDelete(){
        String NoteID=ApexPages.currentPage().getParameters().get('NoteID');
        string ContactID=ApexPages.currentPage().getParameters().get('id');
        system.debug(NoteID);
        if(NoteId != NULL){ // null Check added
            note n=[select id, title from note where id=:NoteID WITH SECURITY_ENFORCED ];
            delete n;
            system.debug('HandleDelete FN');
        }
        
        this.GetNotes();
        String EditPageURL='/apex/DelVF?id='+ContactID;
        PageReference pageRef = new PageReference(EditPageURL);
        pageref.setRedirect(true);
        return pageRef;
        //return NULL;
    }
    
    public void GetNotes(){
        system.debug('GetNotes FN');
        string ContactID=ApexPages.currentPage().getParameters().get('id');
        if(ContactID==NULL){
            system.debug('No Id available');
        }
        else{
            contact[] CNotes=new contact[]{};
                CNotes=[Select id,(select id,isnote,title,lastmodifieddate,createdby.name from NotesAndAttachments)  from contact where id =:ContactID WITH SECURITY_ENFORCED ];
            for( contact c:Cnotes ){
                for(NoteAndAttachment obj:c.NotesAndAttachments ){
                    NotesList.add(obj);
                }
            }
        }
    }
}