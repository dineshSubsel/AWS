public with sharing class NotesAndAttachHandler {
    public noteandattachment[] NotesList { get; set; }

    public NotesAndAttachHandler(ApexPages.StandardController std) {
        NotesList = new noteandattachment[]{};
        String contactId = ApexPages.currentPage().getParameters().get('id');
        if (contactId != null) {
            Contact[] cNotes = [SELECT Id, (SELECT isnote, title, lastmodifieddate, createdby.name FROM NotesAndAttachments) FROM Contact WHERE Id = :contactId];
            for (Contact c : cNotes) {
                for (NoteAndAttachment obj : c.NotesAndAttachments) {
                    NotesList.add(obj);
                }
            }
        }
    }
}