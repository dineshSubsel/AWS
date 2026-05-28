import { LightningElement, track, wire, api } from "lwc";
import { getRecord } from "lightning/uiRecordApi";
import { loadScript } from 'lightning/platformResourceLoader';
import AWS_SDK from "@salesforce/resourceUrl/AWSSDK";
//import recordInsert from '@salesforce/apex/AWSfileupoadforproductController.recordInsert';
//import fetchMetaListLwc from '@salesforce/apex/AWSfileupoadforproductController.fetchMetaListLwc';
//import fetchExistingFileNames from '@salesforce/apex/AWSfileupoadforproductController.fetchExistingFileNames';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import FORM_FACTOR from "@salesforce/client/formFactor";

export default class AWSfileUploadforProduct extends LightningElement {


    /*========= Start - variable declaration =========*/
    /*s3;
    isAwsSdkInitialized = false;
    @track awsSettngRecordId;
    selectedFilesToUpload;
    @track showSpinner = false;
    @track fileName;
    @api recordId;
    @api objectApiName;
    @track objurlname;
    @track baseurl;
    @track dataTable;
    @track awsS3MetadataConfMain = {};
    @track existingFileNamesList = [];
    @api parentRecordId;
    @track dataTable = [];
    @track hasRendered = true;
    @track AWSStyleSheet_LoadTrack;
    @track isLoading = false;
    @track showDataTable = false;
    @track timeout;
    @track awsdeleted = false;
    @track sfdcdeleted = false;
    @track bucketname;
    timeSpan = 5000;
    @api isLoaded = false;
    deviceTypedesktop = false;
    deviceTypemobile = false;
    filecount = 0;
    actualsize;
    progress;
    showModal = false;
    url;
    uploadProgress = 0;
    uploadloaded = false;
    downloadonprogress = false;
    directdownloadflag = false;

    connectedCallback() {
        this.handleFormFactor();
        this.fetchExistingFileNamesMethod();

    }


   renderedCallback() {
        if (this.isAwsSdkInitialized) {
            return;
        }

        Promise.all([loadScript(this, AWS_SDK)])
        fetchMetaListLwc()
            .then((result) => {
                this.awsSettngRecordId = result.Id;
                this.bucketname = result.S3_Bucket_Name__c;
            })
            .catch(error => {
            });
    }



    awsConfigData({
        error,
        data
    }) {
        if (data) {
            let awsS3MetadataConf = {};
            let currentData = data.fields;
            awsS3MetadataConf = {
                s3bucketName: currentData.S3_Bucket_Name__c.value,
                awsAccessKeyId: currentData.AWS_Access_Key_Id__c.value,
                awsSecretAccessKey: currentData.AWS_Secret_Access_Key__c.value,
                s3RegionName: currentData.S3_Region_Name__c.value
            };
            this.awsS3MetadataConfMain = awsS3MetadataConf;
            this.baseurl = 'https://' + currentData.S3_Bucket_Name__c.value + '.s3.' + currentData.S3_Region_Name__c.value + '.amazonaws.com/';
            this.initializeAwsSdk(this.awsS3MetadataConfMain);
        } else if (error) {
        }
    }

   

    // Method - Initializing AWS SDK
    initializeAwsSdk(confData) {
        const AWS = window.AWS;
        AWS.config.update({
            accessKeyId: confData.awsAccessKeyId, //Assigning access key id
            secretAccessKey: confData.awsSecretAccessKey //Assigning secret access key
        });

        AWS.config.region = confData.s3RegionName; //Assigning region of S3 bucket

        this.s3 = new AWS.S3({
            apiVersion: "2012-10-17",
            signatureVersion: 'v4',
            params: {
                Bucket: confData.s3bucketName //Assigning S3 bucket name
            }
        });
        this.isAwsSdkInitialized = true;
    }
    // Method - Fetch the file name from user's selection
    handleSelectedFiles(event) {
        this.actualsize = event.target.files.length;
        if (event.target.files.length > 0) {
            for (var i = 0; i < event.target.files.length; i++) {
                this.selectedFilesToUpload = event.target.files[i];
                this.fileName = event.target.files[i].name;
            }
            var promises = [];
            for (var i = 0; i < event.target.files.length; i++) {
                const currentfileName = event.target.files[i].name;
                if (this.existingFileNamesList.includes(currentfileName)) {
                    this.handleShowToastMsgMethod('Duplicate Records', 'There is an existing file with the same name ', 'error');

                }
                else if (!this.existingFileNamesList.includes(currentfileName)) {
                    var file = event.target.files[i];
                    promises.push(this.uploadToAWS(file));
                    this.existingFileNamesList.push(currentfileName);
                    this.showSpinner = true;
                }
                else {
                }
            }
            Promise.all(promises).then(function (data) {
            }).catch(function (err) {
            })
            this.filename = '';
        }
    }

    // Method - Check for duplicate file using name
    fetchExistingFileNamesMethod() {
        fetchExistingFileNames({
            parentId: this.recordId
        })
            .then((result) => {
                let tempExistingFileNamesList = [];
                // result.forEach(function (item) {
                //     tempExistingFileNamesList.push(item.File_Name__c);
                // });
                this.existingFileNamesList.push(...tempExistingFileNamesList);
            })
            .catch(error => {
                this.handleShowToastMsgMethod('Error', error.message, 'error');
            });
    }

    uploadToAWS(file) {
        if (file) {
            let objKey = 'products' + '/' + file.name.replace(/\s+/g, "_").toLowerCase();

            //starting file upload
            this.s3.putObject({
                Key: objKey,
                Bucket: this.bucketname,
                ContentType: file.type,
                Body: file,
                ACL: "public-read"
            },error => {
                    if (error) {
                       // this.showSpinner = false;
                    } else {
                        //this.showSpinner = false;
                        //this.existingFileNamesList.push(this.fileName);
                        this.tracksucess(file, objKey);

                    }
                }
            );

        }
        this.showSpinner = false;
    }


    //listing all stored documents from S3 bucket
    tracksucess(file, objKey) {
        let url = this.baseurl + '' + objKey;
        recordInsert({

            fileName: file.name,
            fileURL: url,
            objKey: objKey

        })
            .then(result => {
                this.fileName = ' ';
                this.getUploadedFiles();
            })
            .catch(error => {
            })

        this.filecount = this.filecount + 1;
        if (this.filecount >= this.actualsize) {
            this.handleShowToastMsgMethod('Success', 'File has been uploaded Successfully', 'success')
            // this.uploadloaded = false;
        }
    }



    // Method - Logic close the method
    handleCloseModal() {
        this.showModal = false;
    }



    // Method - Logic to check the screen
    handleFormFactor() {
        if (FORM_FACTOR === "Large") {
            this.deviceTypeDesktop = true;
        } else if (FORM_FACTOR === "Medium") {
        } else if (FORM_FACTOR === "Small") {
            this.deviceTypeMobile = true;
        }
    }

    // Method - To show the toast msg
    handleShowToastMsgMethod(titleStr, msgStr, variantStr) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: titleStr,
                message: msgStr,
                variant: variantStr
            }),
        );
    }*/
}