/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : RestoreFailureLogger
 * Author          : <YourName>
 * Created Date    : Mar 23, 2026
 * Last Modified By: <YourName>
 * Last Modified On: Mar 23, 2026
 * Description     : This class implements for......
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Mar 23, 2026  │ <YourName>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
public with sharing class RestoreFailureLogger implements Queueable {

    private String objectNames;
    private List<String> recordIds;
    private String errorMsg;

    public RestoreFailureLogger(String objectNames, List<String> recordIds, String errorMsg) {
        this.objectNames = objectNames;
        this.recordIds   = recordIds;
        this.errorMsg    = errorMsg;
    }

    public void execute(QueueableContext context) {
        insert new File_Recovery_Log__c(
            File_Name__c      = 'Restore-Failed-' + Datetime.now().format('yyyy-MM-dd_HH-mm-ss'),
            Object_Name__c    = objectNames,
            Action_Type__c    = 'Restore',
            Restore_Status__c = 'Failed',
            Restore_Time__c   = Datetime.now(),
            Error_Message__c  = errorMsg,
            Record_Id__c      = (recordIds != null && !recordIds.isEmpty())
                                    ? recordIds[0] : null
        );
    }
	//   @future
    // public static void logFailure(String objectNames, String errorMsg){
    //     insert new File_Recovery_Log__c(
    //         File_Name__c = 'Restore-Failed-' + Datetime.now(),
    //         Object_Name__c = objectNames,
    //         Action_Type__c = 'Restore',
    //         Restore_Status__c = 'Failed',
    //         Restore_Time__c = Datetime.now(),
    //         Error_Message__c = errorMsg
    //     );
    // }
}