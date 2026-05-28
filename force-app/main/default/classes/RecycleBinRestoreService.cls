public with sharing class RecycleBinRestoreService {

    private static final String S3_NC = 'S3_Named_Credential';

    public static void restoreFromS3(
        String       s3Key,
        String       objectName,
        List<String> selectedRecordIds
    ) {
        if (String.isBlank(s3Key))      throw new RecycleBinRestoreException('S3 key is blank.');
        if (String.isBlank(objectName)) throw new RecycleBinRestoreException('Object name is blank.');
        String csvContent = fetchCsvFromS3(s3Key);
        List<Map<String, String>> rows = parseCsv(csvContent);
        if (rows.isEmpty()) {
            throw new RecycleBinRestoreException(
                'CSV for [' + s3Key + '] is empty — nothing to restore.'
            );
        }

        rows = filterRowsBySelectedIds(rows, s3Key, selectedRecordIds);
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
        if (objType == null) {
            throw new RecycleBinRestoreException('Unknown object: ' + objectName);
        }
        Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();
        List<SObject> records = buildSObjects(rows, objectName, fieldMap);
        if (records.isEmpty()) {
            throw new RecycleBinRestoreException(
                'No valid records could be built from CSV [' + s3Key + '].'
            );
        }

        List<Id> idsToUndelete = collectIds(records);
        AWSVaultSectionQueryHelper.undeleteRecords(idsToUndelete);
        List<Database.UpsertResult> results =
            AWSVaultSectionQueryHelper.upsertRestoredRecords(records);
        String failureSummary = collectFailures(results);
        if (String.isNotBlank(failureSummary)) {
            throw new RecycleBinRestoreException(failureSummary);
        }
    }


    private static String fetchCsvFromS3(String s3Key) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(
            'callout:' + S3_NC + '/'
            + EncodingUtil.urlEncode(s3Key, 'UTF-8')
        );
        req.setMethod('GET');
        req.setTimeout(120000);
        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (System.CalloutException ce) {
            throw new RecycleBinRestoreException('S3 callout failed: ' + ce.getMessage());
        }
        if (res.getStatusCode() != 200) {
            throw new RecycleBinRestoreException(
                'S3 download failed for [' + s3Key + ']. HTTP '
                + res.getStatusCode() + ': ' + res.getBody().left(200)
            );
        }
        return res.getBody();
    }


    private static List<Map<String, String>> filterRowsBySelectedIds(
        List<Map<String, String>> rows,
        String                    s3Key,
        List<String>              selectedRecordIds
    ) {
        if (selectedRecordIds == null || selectedRecordIds.isEmpty()) return rows;
        Set<String> idSet = new Set<String>(selectedRecordIds);
        List<Map<String, String>> filtered = new List<Map<String, String>>();
        for (Map<String, String> row : rows) {
            if (idSet.contains(row.get('Id'))) filtered.add(row);
        }
        if (filtered.isEmpty()) {
            throw new RecycleBinRestoreException(
                'Selected record(s) not found in S3 file [' + s3Key + '].'
            );
        }
        return filtered;
    }

    private static List<Id> collectIds(List<SObject> records) {
        List<Id> ids = new List<Id>();
        for (SObject rec : records) ids.add((Id) rec.get('Id'));
        return ids;
    }

    private static String collectFailures(List<Database.UpsertResult> results) {
        List<String> failures = new List<String>();
        Integer failCount = 0;

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) continue;
            failCount++;
            failures.add(flattenErrors(r.getErrors()));
        }

        if (failures.isEmpty()) return null;

        return failCount + ' row(s) failed: '
            + String.join(failures, '; ').left(200);
    }
@TestVisible
    private static String flattenErrors(List<Database.Error> errors) {
        List<String> msgs = new List<String>();
        for (Database.Error err : errors) {
            msgs.add(err.getMessage());
        }
        return String.join(msgs, ', ');
    }

    private static List<Map<String, String>> parseCsv(String csv) {
        List<Map<String, String>> rows  = new List<Map<String, String>>();
        List<String>              lines = csv.split('\n');
        if (lines.isEmpty()) return rows;

        List<String> headers = splitCsvLine(lines[0].trim());

        for (Integer i = 1; i < lines.size(); i++) {
            String line = lines[i].trim();
            if (String.isBlank(line)) continue;
            rows.add(buildRowMap(headers, splitCsvLine(line)));
        }
        return rows;
    }

    private static Map<String, String> buildRowMap(
        List<String> headers,
        List<String> values
    ) {
        Map<String, String> row = new Map<String, String>();
        for (Integer j = 0; j < headers.size(); j++) {
            row.put(headers[j], j < values.size() ? values[j] : '');
        }
        return row;
    }

    private static List<String> splitCsvLine(String line) {
        List<String> fields   = new List<String>();
        Boolean      inQuotes = false;
        String       current  = '';

        for (Integer i = 0; i < line.length(); i++) {
            String ch = line.substring(i, i + 1);

            if (ch == '"') {
                if (inQuotes && i + 1 < line.length()
                        && line.substring(i + 1, i + 2) == '"') {
                    current += '"';
                    i++;
                } else {
                    inQuotes = !inQuotes;
                }
            } else if (ch == ',' && !inQuotes) {
                fields.add(current);
                current = '';
            } else {
                current += ch;
            }
        }
        fields.add(current);
        return fields;
    }

    private static List<SObject> buildSObjects(
        List<Map<String, String>>        rows,
        String                           objectName,
        Map<String, Schema.SObjectField> fieldMap
    ) {
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
        List<SObject> records = new List<SObject>();

        for (Map<String, String> row : rows) {
            SObject rec = buildSingleSObject(row, objType, fieldMap);
            if (rec != null) records.add(rec);
        }
        return records;
    }
    private static SObject buildSingleSObject(
        Map<String, String>              row,
        Schema.SObjectType               objType,
        Map<String, Schema.SObjectField> fieldMap
    ) {
        String rowId = row.get('Id');
        if (String.isBlank(rowId)) return null;

        SObject rec = objType.newSObject();
        rec.put('Id', rowId);

        for (String fieldName : row.keySet()) {
            if (fieldName == 'Id') continue;

            Schema.SObjectField sField = fieldMap.get(fieldName.toLowerCase());
            if (sField == null) continue;

            Schema.DescribeFieldResult dfr = sField.getDescribe();
            if ((!dfr.isUpdateable() && !dfr.isCreateable()) || dfr.isAutoNumber()) continue;

            String rawValue = row.get(fieldName);
            if (String.isBlank(rawValue)) continue;

            try {
                Object typed = castFieldValue(dfr.getType(), rawValue);
                if (typed != null) rec.put(fieldName, typed);
            } catch (Exception castEx) {
            }
        }
        return rec;
    }

    private static Object castFieldValue(Schema.DisplayType dtype, String raw) {
        switch on dtype {
            when BOOLEAN                   { return Boolean.valueOf(raw); }
            when INTEGER                   { return Integer.valueOf(raw); }
            when LONG                      { return Long.valueOf(raw);    }
            when DOUBLE, CURRENCY, PERCENT { return Double.valueOf(raw);  }
            when DATE                      { return Date.valueOf(raw);    }
            when DATETIME                  { return DateTime.valueOf(raw.replace('T', ' ')); }
            when BASE64                    { return null; }
            when else                      { return raw;  }
        }
    }

    public class RecycleBinRestoreException extends Exception {}
}