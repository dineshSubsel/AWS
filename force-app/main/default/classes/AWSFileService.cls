public with sharing class AWSFileService {
    
    public static String ContentType(String fileType) {
        if (String.isBlank(fileType)) {
            return 'image/jpeg';
        }

        switch on fileType.toLowerCase() {
            when 'docx' {
                return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
            }
            when 'csv' {
                return 'application/vnd.ms-excel';
            }
            when 'wav' {
                return 'audio/wav';
            }
            when 'wmv' {
                return 'video/x-ms-wmv';
            }
            when 'mp3' {
                return 'audio/mpeg';
            }
            when 'mp4' {
                return 'video/mp4';
            }
            when 'png' {
                return 'image/png';
            }
            when 'pdf' {
                return 'application/pdf';
            }
            when else {
                return 'image/jpeg';
            }
        }
    }

    public static Boolean UploadDocuments() {
        Id recordId = '0015j000019LAydAAG'; // Replace with dynamic ID as needed
        if (recordId == null) {
            System.debug('Record ID is null');
            return false;
        }

        Set<Id> ids = AWSQuerySharingHelper.getContentDocumentIds(recordId);
        if (ids == null || ids.isEmpty()) {
            System.debug('Document ID set is null or empty');
            return false;
        }

        List<ContentVersion> versions = AWSQuerySharingHelper.getLatestContentVersions(ids);
        if (versions == null || versions.isEmpty()) {
            System.debug('No ContentVersion records found');
            return false;
        }

        NamedCredential named = AWSQuerySharingHelper.getNamedCredential('awsfiletransfer');
        if (named == null || String.isBlank(named.Endpoint)) {
            System.debug('Named Credential is null or has no endpoint');
            return false;
        }

        for (ContentVersion attach : versions) {
            if (attach == null || attach.VersionData == null || String.isBlank(attach.Title) || String.isBlank(attach.FileExtension)) {
                continue;
            }

            try {
                String attachmentBody = EncodingUtil.base64Encode(attach.VersionData);
                String fileUrl = named.Endpoint + '/' + attach.Title.toLowerCase() + '.' + attach.FileExtension.toLowerCase();
                String contentType = ContentType(attach.FileExtension);

                System.debug('contentType: ' + contentType);
                System.debug('fileUrl: ' + fileUrl);

                HttpRequest req = new HttpRequest();
                req.setMethod('PUT');
                req.setEndpoint('callout:awsfiletransfer');

                Blob pdfBlob = EncodingUtil.base64Decode(attachmentBody);
                req.setBodyAsBlob(pdfBlob);
                req.setHeader('Content-Type', contentType);

                Http http = new Http();
                HttpResponse res = http.send(req);

                System.debug('<<Resp>> ' + String.valueOf(res.getBody()));
                System.debug('<<RESPONSE STRING>> ' + res.toString());
                System.debug('<<RESPONSE STATUS>> ' + res.getStatus());
                System.debug('<<STATUS_CODE>> ' + res.getStatusCode());

                if (res != null && (res.getStatusCode() == 200 || res.getStatusCode() == 201)) {
                    return true;
                }
            } catch (Exception ex) {
                System.debug('Exception: ' + ex.getMessage());
            }
        }

        return false;
    }
}