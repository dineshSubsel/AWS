import { LightningElement, track,wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createAWSMetadata from '@salesforce/apex/CustomMetadataController.createAWSMetadata';
import getSettingValues from '@salesforce/apex/CustomMetadataController.getSettingValues';


export default class CustomMetaDataInput extends LightningElement {
    //@track label = '';
    @track accessKeyId ;
    @track secretAccessKey ;
    @track s3BucketName ;
    @track s3RegionName ;

    result;
fieldDisable= true;
    button = true;
    saveButton= false;
    connectedCallback() {
   this.getMetadata();
}
getMetadata()
{
  getSettingValues()
  
        .then((data) => {
                  this.result=data[0];
            this.accessKeyId = this.result.AWS_Access_Key_Id__c;
            this.secretAccessKey = this.result.AWS_Secret_Access_Key__c;
            this.s3BucketName = this.result.S3_Bucket_Name__c;
            this.s3RegionName = this.result.S3_Region_Name__c;            
        })

        .catch((error)=>
        {
        })
  
}

    handleLabel(event) {
        this.label = event.target.value;
    }
    
    handleAccessKeyIdChange(event) {
        this.accessKeyId = event.target.value;
    }

    handleSecretAccessKeyChange(event) {
        this.secretAccessKey = event.target.value;
    }

    handleS3BucketNameChange(event) {
        this.s3BucketName = event.target.value;
    }

    handleS3RegionNameChange(event) {
        this.s3RegionName = event.target.value;
    }


createCustomMetadata() {
    if (!this.accessKeyId || !this.secretAccessKey || !this.s3BucketName || !this.s3RegionName) {
        const event = new ShowToastEvent({
            title: 'Error',
            message: 'All fields are required. Please provide values for all required fields.',
            variant: 'error'
        });
            this.button = false;
            this.saveButton= true;
        this.dispatchEvent(event);
        return;
    }

    createAWSMetadata({
        accessKey: this.accessKeyId,
        secretKey: this.secretAccessKey,
        bucketName: this.s3BucketName,
        region: this.s3RegionName
    })
    .then(result => {

        const successEvent = this.createToastEvent('Success', 'AWS Setting Updated successfully', 'success');
        this.dispatchEvent(successEvent);
        this.fieldDisable = true;
        this.button = true;

    })
    .catch(error => {
        const errorEvent = this.createToastEvent('Error', 'Error updating AWS Setting', 'error');
        this.dispatchEvent(errorEvent);
    });
}

createToastEvent(title, message, variant) {
    return new ShowToastEvent({
        title: title,
        message: message,
        variant: variant
    });
}
cancelButton()
{
    this.fieldDisable = true;
    this.getMetadata();
    this.button = true;
    this.saveButton= false;
}
editCustomMetadata()
{
    this.button = false;
     this.fieldDisable = false;
    this.saveButton= true;
}
saveCustomMetadata()
{
     this.saveButton= false;
     this.createCustomMetadata();
}

}