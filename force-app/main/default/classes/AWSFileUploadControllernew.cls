/**
* @File Name : AWSFileUploadControllernew.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : June 18, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | June 18, 2025 |   | Initial Version
**/

public with sharing class AWSFileUploadControllernew {
    
    @AuraEnabled
public static Boolean uploadFileToAWS(
    Id parentId,
    String strfileName,
    String fileType,
    String fileContent
) {
    System.debug('Received Parameters: parentId=' + parentId + ', strfileName=' + strfileName + ', fileType=' + fileType);

    // Null or empty validation
    if (parentId == null || String.isBlank(strfileName) || String.isBlank(fileType) || String.isBlank(fileContent)) {
        System.debug('One or more required parameters are null or blank.');
        return false;
    }

    try {
        Blob base64Content;
        try {
            base64Content = EncodingUtil.base64Decode(EncodingUtil.urlDecode(fileContent, 'UTF-8'));
        } catch (Exception decodeEx) {
            System.debug('Error decoding file content: ' + decodeEx.getMessage());
            return false;
        }

        String formattedDateString = Datetime.now().formatGMT('EEE, dd MMM yyyy HH:mm:ss z');
        String dateString = Datetime.now().format('ddMMYYYYHHmmss');        
        String filename = dateString + '_' + parentId + '_' + strfileName;

        // AWS credentials and bucket info (ensure these are stored securely, e.g., Custom Metadata/Custom Settings)
        String key = 'Provide AWS key'; 
        String secret = 'Provide AWS Secret key';
        String bucketname = 'Provide AWS bucket'; 
        String host = 's3.amazonaws.com:443'; 

        String method = 'PUT';
        String endPoint = 'https://' + bucketname + '.' + host + '/' + filename;

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:awsfiletransfer');
        req.setMethod(method);

        // Headers
        req.setHeader('Host', bucketname + '.' + host);
        req.setHeader('Access-Control-Allow-Origin', '*');
        req.setHeader('Content-Length', String.valueOf(fileContent.length()));
        req.setHeader('Content-Encoding', 'UTF-8');
        req.setHeader('Content-type', fileType);
        req.setHeader('Connection', 'keep-alive');
        req.setHeader('Date', formattedDateString);
        req.setHeader('ACL', 'public-read');

        req.setBodyAsBlob(base64Content);

        // Signature (optional – currently commented out)
        String stringToSign = 'PUT\n\n' + fileType + '\n' + formattedDateString + '\n' + '/' + bucketname + '/' + filename;
        // Blob mac = Crypto.generateMac('HMACSHA1', Blob.valueOf(stringToSign), Blob.valueOf(secret));
        // String signedKey = EncodingUtil.base64Encode(mac);
        // String authHeader = 'AWS ' + key + ':' + signedKey;
        // req.setHeader('Authorization', authHeader);

        Http http = new Http();
        HttpResponse res = http.send(req);

        System.debug('RESPONSE STRING: ' + res.toString());
        System.debug('RESPONSE STATUS: ' + res.getStatus());
        System.debug('STATUS_CODE: ' + res.getStatusCode());

        return res.getStatusCode() == 200;
    } catch (Exception ex) {
        System.debug('Exception in uploadFileToAWS: ' + ex.getMessage());
        return false;
    }
}
}