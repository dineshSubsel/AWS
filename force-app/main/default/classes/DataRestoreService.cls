public with sharing class DataRestoreService {

    private static final String S3_NC = 'S3_Named_Credential'; 
    public static void restoreObjectData(String s3Key, String objectName) {
        if (String.isBlank(s3Key))      
            throw new DataRestoreException('S3 key is blank.');
        if (String.isBlank(objectName)) 
            throw new DataRestoreException('Object name is blank.');
        String csvContent = fetchCsvFromS3(s3Key);
        List<Map<String, String>> rows = parseCsv(csvContent);
        if (rows.isEmpty()) {
            throw new DataRestoreException(
                'CSV for [' + s3Key + '] is empty — nothing to restore.'
            );
        }
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
        if (objType == null) {
            throw new DataRestoreException('Unknown object: ' + objectName);
        }
        Map<String, Schema.SObjectField> fieldMap =
            objType.getDescribe().fields.getMap();

        List<SObject> records = buildSObjects(rows, objectName, fieldMap);
        if (records.isEmpty()) {
            throw new DataRestoreException('No valid records built from CSV.');
        }
        List<Database.UpsertResult> results =
            AWSVaultSectionQueryHelper.upsertRecords(records);
        List<String> failures = new List<String>();

        for (Database.UpsertResult r : results) {
            if (!r.isSuccess() && r.getErrors() != null && r.getErrors().size() > 0) {
                failures.add(r.getErrors()[0].getMessage());
            }
        }
        if (!failures.isEmpty()) {
            throw new DataRestoreException(
                failures.size() + ' row(s) failed: ' +
                String.join(failures, '; ').left(200)
            );
        }
    }

    // ─── S3 fetch ─────────────────────────────────────────────────────────────
    private static String fetchCsvFromS3(String s3Key) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(
            'callout:' + S3_NC + '/' +
            EncodingUtil.urlEncode(s3Key, 'UTF-8')
        );
        req.setMethod('GET');
        req.setTimeout(120000);
        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (System.CalloutException ce) {
            throw new DataRestoreException('S3 callout failed: ' + ce.getMessage());
        }

        if (res.getStatusCode() != 200) {
            throw new DataRestoreException(
                'S3 download failed for [' + s3Key + ']. HTTP ' +
                res.getStatusCode() + ': ' + res.getBody().left(200)
            );
        }

        return res.getBody();
    }

    // ─── CSV parser ───────────────────────────────────────────────────────────
    public static List<Map<String, String>> parseCsv(String csv) {
        List<Map<String, String>> rows = new List<Map<String, String>>();
        List<String> lines = csv.split('\n');
        if (lines.isEmpty()) return rows;
        List<String> headers = splitCsvLine(lines[0].trim());
        for (Integer i = 1; i < lines.size(); i++) {
            String line = lines[i].trim();
            if (String.isBlank(line)) continue;
            List<String> values = splitCsvLine(line);
            rows.add(buildRow(headers, values));
        }
        return rows;
    }

    private static Map<String, String> buildRow(
        List<String> headers,
        List<String> values
    ){
        Map<String, String> row = new Map<String, String>();
        for (Integer j = 0; j < headers.size(); j++) {
            row.put(headers[j], j < values.size() ? values[j] : '');
        }
        return row;
    }

    private static List<String> splitCsvLine(String line) {
        List<String> fields = new List<String>();
        Boolean inQuotes = false;
        String current = '';
        for (Integer i = 0; i < line.length(); i++) {
            String ch = line.substring(i, i + 1);
            if (ch == '"') {
                if (inQuotes &&
                    i + 1 < line.length() &&
                    line.substring(i + 1, i + 2) == '"') {
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

    @TestVisible
    private static List<SObject> buildSObjects(
        List<Map<String, String>> rows,
        String objectName,
        Map<String, Schema.SObjectField> fieldMap
    ) {

        List<SObject> records = new List<SObject>();
        for (Map<String, String> row : rows) {
            String rowId = row.get('Id');
            if (String.isBlank(rowId)) continue;
            SObject rec = Schema.getGlobalDescribe()
                      .get(objectName)
                      .newSObject();
            rec.put('Id', rowId);
            populateFields(rec, row, fieldMap);
            records.add(rec);
        }

        return records;
    }

  @TestVisible
    private static void populateFields(
        SObject rec,
        Map<String, String> row,
        Map<String, Schema.SObjectField> fieldMap
    ){
        for (String fieldName : row.keySet()) {
            if (fieldName == 'Id') continue;
            Schema.SObjectField sField =
                fieldMap.get(fieldName.toLowerCase());
            if (sField == null) continue;
            Schema.DescribeFieldResult dfr = sField.getDescribe();
            if (!dfr.isUpdateable() && !dfr.isCreateable()) continue;
            if (dfr.isAutoNumber()) continue;
            String rawValue = row.get(fieldName);
            if (String.isBlank(rawValue)) continue;

            try {
                Object typedValue = castFieldValue(dfr.getType(), rawValue);
                if (typedValue != null) {
                    rec.put(fieldName, typedValue);
                }
            } catch (Exception castEx) {
            }
        }
    }

     @TestVisible
    private static Object castFieldValue(
        Schema.DisplayType dtype,
        String raw
    ) {
        switch on dtype {
            when BOOLEAN {
                return Boolean.valueOf(raw);
            }
            when INTEGER {
                return Integer.valueOf(raw);
            }
            when LONG {
                return Long.valueOf(raw);
            }
            when DOUBLE, CURRENCY, PERCENT {
                return Double.valueOf(raw);
            }
            when DATE {
                return Date.valueOf(raw);
            }
            when DATETIME {
                return DateTime.valueOf(raw.replace('T', ' '));
            }
            when BASE64 {
                return null;
            }
            when else {
                return raw;
            }
        }
    }

    public class DataRestoreException extends Exception {}
}