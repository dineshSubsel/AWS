public with sharing class FileRestoreService {

    public static void restoreSingleFile(
        String s3Key,
        String fileName,
        Id     recordId
    ) {
        Http        http = new Http();
        HttpRequest req  = new HttpRequest();
        req.setEndpoint('callout:S3_Named_Credential/' + EncodingUtil.urlEncode(s3Key, 'UTF-8'));
        req.setMethod('GET');
        req.setTimeout(120000);

        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Blob fileBody = res.getBodyAsBlob();

            ContentVersion cv  = new ContentVersion();
            cv.Title           = fileName;
            cv.PathOnClient    = fileName;
            cv.VersionData     = fileBody;
            cv.IsMajorVersion  = true;
            AWSVaultSectionQueryHelper.insertContentVersion(cv);

            Id contentDocId = AWSVaultSectionQueryHelper.getContentDocumentId(cv.Id);

            ContentDocumentLink link  = new ContentDocumentLink();
            link.ContentDocumentId    = contentDocId;
            link.LinkedEntityId       = recordId;
            link.ShareType            = 'V';
            link.Visibility           = 'AllUsers';
            AWSVaultSectionQueryHelper.insertContentDocumentLink(link);

        } else {
            throw new FileRestoreException(
                'S3 download failed for key [' + s3Key + ']. ' +
                'HTTP ' + res.getStatusCode() + ': ' + res.getBody()
            );
        }
    }

    public class FileRestoreException extends Exception {}
}