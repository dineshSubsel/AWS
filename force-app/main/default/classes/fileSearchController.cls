public with sharing class fileSearchController {
    public class WrapperUploadedFileInfo {
        @AuraEnabled public Integer recordStart  { get; set; }
        @AuraEnabled public Integer pageNumber   { get; set; }
        @AuraEnabled public Integer totalRecords { get; set; }
        @AuraEnabled public Integer recordEnd    { get; set; }
        @AuraEnabled public Integer pageSize     { get; set; }
        @AuraEnabled public List<Utils.UploadFileInfo> uploadedfile { get; set; }
    }

    private static final String FILTER_KEY_OBJECT_NAME  = 'objectName';
    private static final String FILTER_KEY_FILE_TYPE    = 'fileType';
    private static final String FILTER_KEY_CREATED_DATE = 'createdDate';
    private static final String FIELD_PARENT_NAME  = 'Parent_Name__c';
    private static final String FIELD_FILE_TYPE    = 'File_Type__c';
    private static final String FIELD_CREATED_DATE = 'CreatedDate';

    private static final Integer DEFAULT_PAGE_NUMBER = 1;
    private static final Integer DEFAULT_PAGE_SIZE   = 10;

    private static final List<String> SUPPORTED_FILE_TYPES = new List<String>{
        'image/jpeg', 'image/png', 'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'text/csv',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'application/vnd.ms-powerpoint',
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        'text/plain', 'application/pdf', 'application/x-zip-compressed'
    };

    @AuraEnabled(cacheable=true)
    public static String getRecentlyUploadedfile(Integer pageSize, Integer pageNumber) {
        if (pageSize == null || pageSize <= 0) {
        pageSize = 0;
    }
    if (pageNumber == null || pageNumber <= 0) {
        pageNumber = 0;
    }
        pageSize   = AWSQuerySharingHelper.sanitizeSize(pageSize);
        Integer totalRecords = AWSQuerySharingHelper.getTotalFileCount();
        pageNumber = AWSQuerySharingHelper.sanitizePage(pageNumber, totalRecords, pageSize);
        Integer offset = (pageNumber - 1) * pageSize;
        if(offset == null){
            offset = 0;
        }
        try {
            List<Uploaded_file_info__c> records =
                AWSQuerySharingHelper.getUploadedFiles(pageSize, offset);
            return JSON.serialize(
                buildWrapper(pageNumber, pageSize, offset, totalRecords, convertToWrapper(records))
            );
        } catch (Exception e) {
            return JSON.serialize(emptyWrapper(pageNumber, pageSize));
        }
    }

   @AuraEnabled(cacheable=true)
public static String getSearchedFile(String searchName, Integer pageSize, Integer pageNumber) {
if (searchName == null) {
    return JSON.serialize(emptyWrapper(pageNumber, pageSize));
}
if (pageSize == null || pageSize <= 0) {
    pageSize = 10;
}

if (pageNumber == null || pageNumber <= 0) {
    pageNumber = 1;
}
    pageSize = AWSQuerySharingHelper.sanitizeSize(pageSize);
    Integer totalRecords = 0;
    if (searchName != null) {
        totalRecords = AWSQuerySharingHelper.getTotalFileCount(searchName);
    }
    pageNumber = AWSQuerySharingHelper.sanitizePage(pageNumber, totalRecords, pageSize);
    Integer offset = (pageNumber - 1) * pageSize;
    try {
        List<Uploaded_File_Info__c> records =
            AWSQuerySharingHelper.getSearchFileRecords(searchName, pageSize, offset);
        return JSON.serialize(
            buildWrapper(pageNumber, pageSize, offset, totalRecords, convertToWrapper(records))
        );
    } catch (Exception e) {
        return JSON.serialize(emptyWrapper(pageNumber, pageSize));
    }
}
    @AuraEnabled(cacheable=true)
public static String filterfile(
    String searchname,
    String filter,
    String operator,
    String value,
    Integer pageSize,
    Integer pageNumber
) {
    if (searchname == null) return JSON.serialize(emptyWrapper(DEFAULT_PAGE_NUMBER, DEFAULT_PAGE_SIZE));
    if (pageSize == null) return JSON.serialize(emptyWrapper(DEFAULT_PAGE_NUMBER, DEFAULT_PAGE_SIZE));
    if (pageNumber == null) return JSON.serialize(emptyWrapper(DEFAULT_PAGE_NUMBER, DEFAULT_PAGE_SIZE));

    pageSize = AWSQuerySharingHelper.sanitizeSize(pageSize);
    String apexFieldName = resolveFieldName(filter);
    Integer totalRecords;
    Integer offset;
    List<Uploaded_file_info__c> records;
    if (apexFieldName == FIELD_PARENT_NAME) {
        totalRecords = AWSQuerySharingHelper.countByParentName(searchname, value, operator);
        pageNumber = AWSQuerySharingHelper.sanitizePage(pageNumber, totalRecords, pageSize);
        offset = (pageNumber - 1) * pageSize;
          if(offset == null){
            offset = 0;
          }
        records = AWSQuerySharingHelper.fetchByParentName(searchname, value, operator, pageSize, offset);

        return JSON.serialize(buildWrapper(pageNumber, pageSize, offset, totalRecords, convertToWrapper(records)));
    }

    if (apexFieldName == FIELD_FILE_TYPE) {
    totalRecords = AWSQuerySharingHelper.countByFileType(searchname, value, operator);
    pageNumber = AWSQuerySharingHelper.sanitizePage(pageNumber, totalRecords, pageSize);
    offset = (pageNumber - 1) * pageSize;
    if (offset == null) {
        offset = 0;
    }
    records = AWSQuerySharingHelper.fetchByFileType(searchname, value, operator, pageSize, offset);

    return JSON.serialize(buildWrapper(pageNumber, pageSize, offset, totalRecords, convertToWrapper(records)));
}
   if (apexFieldName == FIELD_CREATED_DATE) {
    if (value == null) {
        return JSON.serialize(emptyWrapper(DEFAULT_PAGE_NUMBER, DEFAULT_PAGE_SIZE));
    }

    Date dateValue = Date.valueOf(value);
    totalRecords = AWSQuerySharingHelper.getTotalRecords(
        searchname, FIELD_CREATED_DATE, operator, value, SUPPORTED_FILE_TYPES, dateValue
    );
    
    pageNumber = AWSQuerySharingHelper.sanitizePage(pageNumber, totalRecords, pageSize);
    offset = (pageNumber - 1) * pageSize;
    
    try {
        records = AWSQuerySharingHelper.getFileRecords(
            searchname, FIELD_CREATED_DATE, operator, value,
            SUPPORTED_FILE_TYPES, dateValue, pageSize, offset
        );
        
        return JSON.serialize(buildWrapper(pageNumber, pageSize, offset, totalRecords, convertToWrapper(records)));
    } catch (Exception e) {
        return JSON.serialize(emptyWrapper(DEFAULT_PAGE_NUMBER, DEFAULT_PAGE_SIZE));
    }
}
    return JSON.serialize(emptyWrapper(DEFAULT_PAGE_NUMBER, DEFAULT_PAGE_SIZE));
}

    @AuraEnabled(cacheable=true)
    public static String getParentNameOptions() {
        List<String> parentNames = AWSQuerySharingHelper.getDistinctParentNames();
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        Set<String> seen = new Set<String>();
        List<Map<String, String>> options = new List<Map<String, String>>();

        for (String pn : parentNames) {
            if (seen.contains(pn)) continue;
            seen.add(pn);

            String objKey = pn.toLowerCase();
            String lbl = globalDescribe.containsKey(objKey)
                ? globalDescribe.get(objKey).getDescribe().getLabel()
                : pn;

            options.add(new Map<String, String>{ 'label' => lbl, 'value' => pn });
        }
        return JSON.serialize(options);
    }

    @AuraEnabled(cacheable=true)
    public static String getFilterFields() {
        List<String> parentNames = AWSQuerySharingHelper.getDistinctParentNames();
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        Map<String, Schema.SObjectField> fieldMap =
            Schema.SObjectType.Uploaded_file_info__c.fields.getMap();

        Set<String>               addedValues = new Set<String>();
        List<Map<String, String>> options     = new List<Map<String, String>>();
        for (String parentVal : parentNames) {
            if (addedValues.contains(parentVal)) continue;
            String objKey = parentVal.toLowerCase();
            if (!globalDescribe.containsKey(objKey)) continue;

            String objLabel = globalDescribe.get(objKey).getDescribe().getLabel();
            options.add(new Map<String, String>{ 'label' => objLabel, 'value' => parentVal });
            addedValues.add(parentVal);
        }

        for (String fieldName : new List<String>{ FIELD_CREATED_DATE, FIELD_FILE_TYPE }) {
            String fieldKey = fieldName.toLowerCase();
            if (!fieldMap.containsKey(fieldKey)) continue;
            Schema.DescribeFieldResult dfr = fieldMap.get(fieldKey).getDescribe();
            options.add(new Map<String, String>{ 'label' => dfr.getLabel(), 'value' => dfr.getName() });
        }

        return JSON.serialize(options);
    }

    private static String resolveFieldName(String filterKey) {
        if (filterKey == FILTER_KEY_OBJECT_NAME)  return FIELD_PARENT_NAME;
        if (filterKey == FILTER_KEY_FILE_TYPE)     return FIELD_FILE_TYPE;
        if (filterKey == FILTER_KEY_CREATED_DATE)  return FIELD_CREATED_DATE;
        return null;
    }

    private static WrapperUploadedFileInfo buildWrapper(
        Integer pageNumber,
        Integer pageSize,
        Integer offset,
        Integer totalRecords,
        List<Utils.UploadFileInfo> files
    ) {
        WrapperUploadedFileInfo w = new WrapperUploadedFileInfo();
        w.pageNumber   = pageNumber;
        w.pageSize     = pageSize;
        w.recordStart  = (totalRecords == 0) ? 0 : offset + 1;
        w.totalRecords = totalRecords;
        w.recordEnd    = Math.min(pageSize * pageNumber, totalRecords);
        w.uploadedfile = files;
        return w;
    }

    private static WrapperUploadedFileInfo emptyWrapper(Integer pageNumber, Integer pageSize) {
        WrapperUploadedFileInfo w = new WrapperUploadedFileInfo();
        w.pageNumber   = pageNumber;
        w.pageSize     = pageSize;
        w.recordStart  = 0;
        w.recordEnd    = 0;
        w.totalRecords = 0;
        w.uploadedfile = new List<Utils.UploadFileInfo>();
        return w;
    }

    private static List<Utils.UploadFileInfo> convertToWrapper(
        List<Uploaded_file_info__c> uploadedFiles
    ) {
        List<Utils.UploadFileInfo> wrapperList = new List<Utils.UploadFileInfo>();
        if (uploadedFiles == null) return wrapperList;

        for (Uploaded_file_info__c rec : uploadedFiles) {
            Utils.UploadFileInfo w = new Utils.UploadFileInfo();
            w.id             = rec.Id;
            w.name           = rec.File_Name__c != null ? rec.File_Name__c : rec.Name;
            w.fileType       = rec.File_Type__c;
            w.fileSize       = rec.File_sizes__c != null ? String.valueOf(rec.File_sizes__c) : '0';
            w.fileURL        = rec.File_URL__c;
            w.parentName     = rec.Parent_Name__c;
            w.parentRecordId = rec.Parent_Record_Id__c;
            w.createdDate    = rec.CreatedDate;
            w.uploadedBy     = rec.CreatedBy != null ? rec.CreatedBy.Name : '';
            wrapperList.add(w);
        }
        return wrapperList;
    }
}