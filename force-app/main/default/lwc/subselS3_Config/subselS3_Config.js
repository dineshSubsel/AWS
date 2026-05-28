import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import createAWSMetadata from '@salesforce/apex/S3ConfigController.createAWSMetadata';
import getSettingValues from '@salesforce/apex/S3ConfigController.getSettingValues';

export default class SubselS3_Config extends LightningElement {

    @track showForm = false;

    @track accessKeyId;
    @track secretAccessKey;
    @track s3BucketName;
    @track s3RegionName;

    fieldDisable = true;
    button = true;
    saveButton = false;

    connectedCallback() {
        this.getMetadata();
    }

    getMetadata() {

        getSettingValues()
            .then((data) => {

                if(data){

                    this.accessKeyId = data.awsAccessKeyId || '';
                    this.secretAccessKey = data.awsSecretAccessKey || '';
                    this.s3BucketName = data.s3BucketName || '';
                    this.s3RegionName = data.s3RegionName || '';

                }

            })
            .catch((error) => {

                this.showToast(
                    'Error',
                    error?.body?.message || 'Error loading AWS settings',
                    'error'
                );

            });
    }

    navigateToConfig() {

        this.showForm = true;
        this.fieldDisable = true;
        this.button = true;
        this.saveButton = false;

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

            this.showToast(
                'Error',
                'All fields are required. Please provide values for all required fields.',
                'error'
            );

            return;
        }

        createAWSMetadata({
            accessKey: this.accessKeyId,
            secretKey: this.secretAccessKey,
            bucketName: this.s3BucketName,
            region: this.s3RegionName
        })
        .then(() => {

            this.showToast(
                'Success',
                'AWS Setting Updated successfully',
                'success'
            );

            this.showForm = false;

            this.getMetadata();

        })
        .catch((error) => {

            this.showToast(
                'Error',
                error?.body?.message || 'Error updating AWS Setting',
                'error'
            );

        });
    }

    cancelButton() {

        this.getMetadata();

        this.showForm = false;
        this.fieldDisable = true;
        this.button = true;
        this.saveButton = false;

    }

    editCustomMetadata() {

        this.button = false;
        this.fieldDisable = false;
        this.saveButton = true;

    }

    saveCustomMetadata() {

        this.createCustomMetadata();

    }

    showToast(title, message, variant){

        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );

    }
}