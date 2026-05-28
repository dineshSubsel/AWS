public with sharing class AWSFileUploadController {
    @AuraEnabled
    public static boolean uploadFileToAWS(Id parentId,
                                          String strfileName, String fileType,
                                          String fileContent){
                                             if (parentId == null || String.isBlank(strfileName) || String.isBlank(fileType) || String.isBlank(fileContent)) {
                                            return false;
                                            }

                                              System.debug('parentId=' + parentId);
                                              System.debug('strfileName=' + strfileName);
                                              System.debug('fileType=' + fileType);
                                              HttpRequest req = new HttpRequest();
                                              
                                              Blob base64Content = EncodingUtil.base64Decode(EncodingUtil.urlDecode(fileContent, 'UTF-8'));
                                              String attachmentBody =  fileContent;           
                                              String formattedDateString = Datetime.now().formatGMT('EEE, dd MMM yyyy HH:mm:ss z');
                                              String dateString = Datetime.now().format('ddMMYYYYHHmmss');        
                                              String filename = 'test';
                                              
                                              //AWS specific information
                                              String key = 'samplekey'; //AWS key
                                              String secret = 'sampleSecretKey'; //AWS Secret key
                                              String bucketname = 'sfdcfiles2024'; //AWS bucket name
                                             String host = 's3.amazonaws.com';
                                              
                                              String method = 'PUT';
                                              String endPoint = 'https://' + bucketname + '.' + host + '/'+ filename;
                                              
                                              req.setMethod(method);
                                              req.setEndpoint(endPoint);
                                              
                                              system.debug('Endpoint='+endPoint);
                                              //create header information
                                              req.setHeader('Host', bucketname + '.' + host);
                                              req.setHeader('Access-Control-Allow-Origin', '*');
                                              req.setHeader('Content-Length', String.valueOf(attachmentBody.length()));
                                              req.setHeader('Content-Encoding', 'UTF-8');
                                              req.setHeader('Content-type', fileType);
                                              req.setHeader('Connection', 'keep-alive');
                                              req.setHeader('Date', formattedDateString); 
                                              req.setHeader('ACL', 'public-read');
                                              //store file as blob       
                                              req.setBodyAsBlob(base64Content);
                                              
                                              //prepare for signing information
                                              String stringToSign = 'PUT\n\n' +
                                                  fileType + '\n' +
                                                  formattedDateString + '\n' + '/' + bucketname + '/' + filename;
                                              
                                              String encodedStringToSign = EncodingUtil.urlEncode(stringToSign, 'UTF-8');
                                              Blob mac = Crypto.generateMac('HMACSHA1', blob.valueof(stringToSign),blob.valueof(secret));
                                              String signedKey  = EncodingUtil.base64Encode(mac);
                                              
                                              //assign Authorization information
                                              String authHeader = 'AWS' + ' ' + key + ':' + signedKey;                    
                                              req.setHeader('Authorization',authHeader);
                                              
                                              //finally send information to AWS        
                                              Http http = new Http();
                                              HTTPResponse res = http.send(req);
                                              
                                              System.debug('*Resp:' + String.ValueOF(res.getBody()));
                                              System.debug('RESPONSE STRING: ' + res.toString());
                                              System.debug('RESPONSE STATUS: ' + res.getStatus());
                                              System.debug('STATUS_CODE: ' + res.getStatusCode());
                                              
                                              if(res.getStatusCode() == 200){
                                                  // insertAttachmentRecord (parentId,strfileName,endPoint);
                                                  return true;
                                              }
                                              return false;
                                          }
    
    
}