public with sharing class OrgMetadataRetriever {

    public class MetadataWrapper {
        @AuraEnabled public String name;
        @AuraEnabled public String type;
        @AuraEnabled public String objectName;
    }

    @AuraEnabled(cacheable=false)
    public static List<MetadataWrapper> fetchMetadata() {

        List<MetadataWrapper> result = new List<MetadataWrapper>();

        /* -------- FORMULA FIELDS -------- */
        Map<String, Schema.SObjectType> globalMap = Schema.getGlobalDescribe();

        for(String objName : globalMap.keySet()){
            Map<String, Schema.SObjectField> fields =
                globalMap.get(objName).getDescribe().fields.getMap();

            for(String fieldName : fields.keySet()){
                if(fields.get(fieldName).getDescribe().isCalculated()){

                    MetadataWrapper wrap = new MetadataWrapper();
                    wrap.name = fieldName;
                    wrap.type = 'FormulaField';
                    wrap.objectName = objName;
                    result.add(wrap);
                }
            }
        }

        /* -------- REMOTE SITE SETTINGS (Tooling API) -------- */
        try {

            String query =
                'SELECT Id, SiteName, EndpointUrl FROM RemoteProxy';

            HttpRequest req = new HttpRequest();
            req.setEndpoint(
                'callout:Salesforce_Tooling/services/data/v59.0/tooling/query?q='
                + EncodingUtil.urlEncode(query,'UTF-8')
            );

            req.setMethod('GET');
            req.setHeader('Content-Type','application/json');

            Http http = new Http();
            HttpResponse res = http.send(req);

            System.debug('RemoteProxy response ===> ' + res.getBody());

            if(res.getStatusCode() == 200){

                Map<String,Object> jsonMap =
                    (Map<String,Object>)JSON.deserializeUntyped(res.getBody());

                List<Object> records =
                    (List<Object>) jsonMap.get('records');

                for(Object obj : records){

                    Map<String,Object> rec =
                        (Map<String,Object>) obj;

                    MetadataWrapper wrap = new MetadataWrapper();
                    wrap.name = (String) rec.get('SiteName');
                    wrap.type = 'RemoteSiteSetting';
                    wrap.objectName = (String) rec.get('EndpointUrl');

                    result.add(wrap);
                }
            }

        } catch(Exception e){
            System.debug('RemoteProxy error ' + e.getMessage());
        }

        return result;
    }
}