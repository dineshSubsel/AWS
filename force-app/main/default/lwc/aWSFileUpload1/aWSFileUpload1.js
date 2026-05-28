import { LightningElement, track, wire, api } from "lwc";
import { getRecord } from "lightning/uiRecordApi";
import { loadScript } from 'lightning/platformResourceLoader';
import getAWSFiles from '@salesforce/apex/AWSFileUploadHandlingControllerForObject.getAWSFiles';
import AWS_SDK from "@salesforce/resourceUrl/AWSSDK";
import recordInsert from '@salesforce/apex/AWSFileUploadHandlingControllerForObject.recordInsert';
import fetchMetaListLwc from '@salesforce/apex/AWSFileUploadHandlingControllerForObject.fetchMetaListLwc';
import fetchExistingFileNames from '@salesforce/apex/AWSFileUploadHandlingControllerForObject.fetchExistingFileNames';
import deleteCallout from '@salesforce/apex/AWSFileUploadHandlingControllerForObject.deleteCallout';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import { loadStyle } from 'lightning/platformResourceLoader';
import FORM_FACTOR from "@salesforce/client/formFactor";

export default class FileUploadComponentLWC extends LightningElement {
    /*========= Start - variable declaration =========*/
    awsS3MetadataConf; // Add this declaration

    s3; //store AWS S3 object
    isAwsSdkInitialized = false; //flag to check if AWS SDK initialized
    @track awsSettngRecordId; //store record id of custom metadata type where AWS configurations are stored
    selectedFilesToUpload; //store selected file
    @track showSpinner = false; //used for when to show spinner
    @track fileName; //to display the selected file name
    @api recordId;
    @api objectApiName;
    @api recordrecordName;
    @track objurlname;
    @track baseurl;
    @track dataTable;
    @track awsS3MetadataConfMain = {};
    @track existingFileNamesList = [];
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

    totalPages = 0;
    totalRecords = 0;
    isLoading = false;

    pageSizeOptions = [
        { label: '5', value: 5 },
        { label: '10', value: 10 },
        { label: '15', value: 15 },
         { label: '20', value: 20 }
    ];

    recordsToDisplay = [];
    @track pageSize = 5;
    @track pageNumber = 1;
    @track pageOptions = []; // Make sure this is initialized elsewhere in your component

    handleChange(event) {
        this.pageNumber = parseInt(event.detail.value, 10);
        this.getUploadedFiles();
    }
    get bDisableFirst() {
        return this.pageNumber == 1;
    }
    get bDisableLast() {
        return this.pageNumber == this.totalPages;
    }

     populatePageOptions() {
        // Customize this logic based on your totalRecords
        const totalRecords = 100; // Example total number of records
        const pageSize = 10; // Example page size
        const totalPages = Math.ceil(totalRecords / pageSize);

        this.pageOptions = Array.from({ length: totalPages }, (_, i) => ({
            label: String(i + 1),
            value: String(i + 1)
        }));
    }
 connectedCallback() {
        this.handleFormFactor();
        this.getUploadedFiles(this.pageSize, this.pageNumber);
        this.populatePageOptions();
        this.fetchExistingFileNamesMethod();
        this.label = {
            File_Upload: 'File Upload' // Add a value for the File_Upload key
        };
    }

    label;
    renderedCallback() {
        if (this.isAwsSdkInitialized) {
            return;
        }
        Promise.all([loadScript(this, AWS_SDK)])
        fetchMetaListLwc()
            .then((result) => {
                this.awsSettngRecordId = result[0].Id;
                this.bucketname = result[0].S3_Bucket_Name__c;

            })
            .catch(error => {
            });
    }

    awsConfigData({ error, data }) {
        if (data) {
            let currentData = data.fields;
            this.awsS3MetadataConf = { // Change awsS3MetadataConf to this.awsS3MetadataConf
                s3bucketName: currentData.S3_Bucket_Name__c.value,
                awsAccessKeyId: currentData.AWS_Access_Key_Id__c.value,
                awsSecretAccessKey: currentData.AWS_Secret_Access_Key__c.value,
                s3RegionName: currentData.S3_Region_Name__c.value
            };
            this.awsS3MetadataConfMain = this.awsS3MetadataConf; // Also update this line
            this.baseurl = 'https://' + currentData.S3_Bucket_Name__c.value + '.s3.' + currentData.S3_Region_Name__c.value + '.amazonaws.com/';
            if (this.awsS3MetadataConfMain) {
                this.initializeAwsSdk(this.awsS3MetadataConfMain);
            }
        } else if (error) {
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields: ['ObjectApiName__c.Name'] })
    wiredRecord({ error, data }) {
        if (data) {
            this.recordrecordName = data.fields.Name.value;
        } else if (error) {

        }
    }


    /* Wire Method - End */

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
                    this.uploadloaded = true;
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
                result.forEach(function (item) {
                    tempExistingFileNamesList.push(item.File_Name__c);
                });
                this.existingFileNamesList.push(...tempExistingFileNamesList);
            })
            .catch(error => {
                this.handleShowToastMsgMethod('Error', error.message, 'error');
            });
    }
    //file upload to AWS S3 bucket

    uploadToAWS(file) {

        if (file) {
            let objName = this.objectApiName + '/' + this.recordId;
            let objKey = objName + '/' + file.name
                .replace(/\s+/g, "_")
                .toLowerCase();

            const presignedUrl = this.s3.getSignedUrl('putObject', {
                Key: objKey,
                ContentType: file.type,
                Expires: 86400
            });
            const xhr = new XMLHttpRequest();
            xhr.open("PUT", presignedUrl, true);

            xhr.upload.addEventListener("progress", (event) => {
                if (event.lengthComputable) {
                    const percentComplete = (event.loaded / event.total) * 100;
                    this.uploadProgress = Math.round(percentComplete);

                }
            });

            xhr.onreadystatechange = () => {
                if (xhr.readyState === 4) {
                    if (xhr.status === 200) {
                        this.tracksucess(file, objKey);
                    } else {
                    }
                }
            };

            xhr.send(file);
        }
        else {
        }
    }



    //listing all stored documents from S3 bucket
    tracksucess(file, objKey) {
        let url = this.baseurl + '' + objKey;
        recordInsert({
            parent: this.objectApiName,
            parentId: this.recordId,
            parentRecordName: this.recordrecordName,
            fileName: file.name,
            fileURL: url,
            filetype: file.type,
            objKey: objKey,
            filesize: file.size

        })
            .then(result => {
                this.fileName = ' ';
                this.pageNumber = 1;
                this.getUploadedFiles(this.pageSize, this.pageNumber);
            })
            .catch(error => {
            })

        this.filecount = this.filecount + 1;
        if (this.filecount >= this.actualsize) {
            this.handleShowToastMsgMethod('Success', 'File has been uploaded Successfully', 'success')
            this.uploadloaded = false;
        }
    }

    // Method - Logic for downloading
    handleDownloadMethod(rowdetail) {
        const row = rowdetail;
        const objectKey = row['ObjectKey__c'];
        let fileName = row['File_Name__c'];
        let filesize = row['File_sizes__c'];

        const presignedGETURL = this.s3.getSignedUrl('getObject', {
            Bucket: this.bucketname,
            Key: objectKey,
            Expires: 86400 // Time to expire in seconds
        });
        const progressWindow = window.open('', '_blank', 'width=400,height=200');
        progressWindow.document.body.innerHTML = `
    <div>
                        <h2>Download Manager</h2>
                        <table>
                            <tr>
                                <td>File Name:</td>
                                <td>${fileName}</td> 
                            </tr>
                            <tr>
                                <td> File Size:</td>
                                <td> ${filesize}</td>
                            </tr>
                            <tr> 
                            <td  colspan="2">
                                <progress value={progress} max="100"></progress>
                            </td>
                            </tr>
                        </table>
   </div>   
                        <style>
                            .download-manager {
                                display: block;
                                font-family: Arial, sans-serif;
                                padding: 30px;
                                background-color: #f8f8f8;
                                border: 1px solid #ccc;
                                border-radius: 8px;
                                box-shadow: 0px 2px 4px rgba(0, 0, 0, 0.1);
                                width: 400px;
                                margin: 35px;
                            }
                        div{
                            padding-top: 1px;
                            padding-bottom: 10px;
                            padding-right: 10px;
                            padding-left: 10px;
                            background-image: Linear-gradient(180deg, #318ce7 , #72a0c1);
                            box-shadow: 4px 4px 16px rgba(0, 0, 0, 0.5);
                        }
                            h2 {
                                font-size: 24px;
                                color: #000;
                                margin-top:10px;
                                margin-bottom: 1px;
                                background-color: #E8E8E8;
                                padding: 11px;
                                text-align: center;
                                width:auto;
                              box-shadow: 2px 3px 3px rgba(0,0,0,0.5);
                                font-family:Arial;                            
}

                            table {
                                width: 100%;
                              box-shadow: 2px 3px 3px rgba(0,0,0,0.5);                              
                                border-collapse: collapse;
                                background-color: white;
                                font-family:Arial;
                                padding: 3px;                            
                            }

                            td {
                                padding: 7px;
                                                             
                            }

                            td:nth-child(1) {
                                font-weight: bold;
                                color: #000;
                                width: 40%;                            
                            }

                            td:nth-child(2) {
                                color: #000;
                                width: 60%;
                                text-align: center;
                                font-size: 15px;
                            }

                            progress {
                                width: 100%;
                                height: 20px;
                                margin-top: 5px;
                                margin-bottom: 5px;
                            }

                            progress::-webkit-progress-value {
                                background-color: #3498db;
                             
                            }

                            progress::-webkit-progress-bar {
                                background-color: #f2f2f2;
                           
                            }
                        </style> 
`;

        var xhr = new XMLHttpRequest();
        xhr.open('GET', presignedGETURL, true);
        xhr.responseType = 'blob';
        xhr.onprogress = (e) => {
            this.downloadonprogress = true;
            this.progress = parseInt((e.loaded / e.total) * 100)
            if (this.progress === 100) {
                this.progress = 0;
                this.downloadonprogress = false;
                progressWindow.close();
            }
            progressWindow.document.querySelector('progress').value = this.progress;
        }
        xhr.onload = e => this.imageDownload(xhr.response, fileName)
        xhr.send();


    }

    // Method - Logic for deleting file
    handleFileDeleteMethod(rowDetail) {
        let row = rowDetail;
        var rowId = row['Id'];
        let tempFileName = row['File_Name__c'];
        var parentId = row['Parent_Record_Id__c'];
        const AWS = window.AWS;
        AWS.config.update({
            accessKeyId: this.awsS3MetadataConfMain.awsAccessKeyId,
            secretAccessKey: this.awsS3MetadataConfMain.awsSecretAccessKey
        });
        const objectKey = row['ObjectKey__c'];
        this.s3 = new AWS.S3({
            apiVersion: '2012-10-17',
            region: 'us-west-2'
        });
        var params = {
            Bucket: this.bucketname,
            Key: objectKey
        };

        this.s3.deleteObject(params, (err, data) => {
            if (err) {
                this.awsdeleted = false;
            } else {
                if (data) {
                    this.filename = '';
                    this.awsdeleted = true;
                    this.dataTable = [];
                    deleteCallout({
                        recordId: rowId
                    })
                        .then(data => {
                            this.sfdcdeleted = true;
                            this.pageNumber = 1;
                            this.handleShowToastMsgMethod('Deleted ' + tempFileName, ' Deleted Successfully', 'success')
                            this.getUploadedFiles(this.pageSize, this.pageNumber);
                            if (this.sfdcdeleted && this.awsdeleted) {
                                this.timeSpan = this.timeSpan;

                            } else {
                                this.timeSpan = this.timeSpan + 1000;
                            }
                        })
                        .catch(error => {
                            this.sfdcdeleted = false;
                        })
                }
            }
        });
        this.existingFileNamesList = this.existingFileNamesList.filter(item => item != tempFileName);
    }

    getUploadedFiles() {
       this.isLoading = true;
        getAWSFiles({
            parentId: this.recordId,
            pageSize: this.pageSize,
            pageNumber: this.pageNumber
        })
            .then(result => {
                var resultData = JSON.parse(result);
                this.recordEnd = resultData.recordEnd;
                this.totalRecords = resultData.totalRecords;
                this.recordStart = resultData.recordStart;
                this.dataTable = resultData.uploadedfile;
                this.pageNumber = resultData.pageNumber;
                this.totalPages = Math.ceil(resultData.totalRecords / this.pageSize);
                this.isNext = (this.pageNumber == this.totalPages || this.totalPages == 0);
                this.isPrev = (this.pageNumber == 1 || this.totalRecords < this.pageSize);

                this.dataTable = this.dataTable.map(record => ({
                    ...record,
                    File_sizes__c: this.formatFileSize(parseInt(record.File_sizes__c, 10)),
                    CreatedDate: new Date(record.CreatedDate).toLocaleDateString()

                }));
                this.dataTable = this.formateicon(this.dataTable);
                if ((this.dataTable).length > 0) {
                    this.showDataTable = true;
                } else {
                    this.showDataTable = false;
                }
            })
            .catch(error => {
                this.handleShowToastMsgMethod('Review the display Records', error.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    handlePagePrevAction() {
        this.pageNumber = this.pageNumber - 1;
        this.getUploadedFiles(this.pageSize, this.pageNumber);

    }
    handlePageNextAction() {
        this.pageNumber = this.pageNumber + 1;
        this.getUploadedFiles(this.pageSize, this.pageNumber);

    }

    handleRecordsPerPage(event) {
        this.pageSize = parseInt(event.target.value, 10);
        this.totalPages = Math.ceil(this.totalRecords / this.pageSize);
        this.pageNumber = 1;
        this.getUploadedFiles();
    }
    handlePageNavigation(event) {
        const direction = event.target.dataset.nav;
        if (direction === 'prev' && this.pageNumber > 1) {
            this.pageNumber--;
        } else if (direction === 'next' && this.pageNumber < this.totalPages) {
            this.pageNumber++;
        }
        this.getUploadedFiles();
    }
    formateicon(files) {
        return files.map((item) => {
            const newItem = { ...item };
            if (item.File_Type__c === 'image/jpeg' || item.File_Type__c === 'image/png') {
                newItem.File_Type__c = 'doctype:image';
            } else if (item.File_Type__c === 'application/pdf') {
                newItem.File_Type__c = 'doctype:pdf';
            } else if (item.File_Type__c === 'text/plain') {
                newItem.File_Type__c = 'doctype:txt';
            } else if (item.File_Type__c === 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' || item.File_Type__c === 'text/csv') {
                newItem.File_Type__c = 'doctype:gsheet';
            } else if (item.File_Type__c === 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' || item.File_Type__c === 'application/msword') {
                newItem.File_Type__c = 'doctype:word';
            } else if (item.File_Type__c === 'application/x-zip-compressed') {
                newItem.File_Type__c = 'doctype:zip';
            } else if (item.File_Type__c === 'application/vnd.ms-powerpoint' || item.File_Type__c === 'application/vnd.openxmlformats-officedocument.presentationml.presentation') {
                newItem.File_Type__c = 'doctype:ppt';
            } else {
                newItem.File_Type__c = 'doctype:attachment';
            }
            return newItem;
        });

    }
    formatFileSize(bytes) {
        if (bytes < 1024) {
            return bytes + ' B';
        } else if (bytes < 1048576) {
            return (bytes / 1024).toFixed(2) + ' KB';
        } else if (bytes < 1073741824) {
            return (bytes / 1048576).toFixed(2) + ' MB';
        } else {
            return (bytes / 1073741824).toFixed(2) + ' GB';
        }
    }

    // Method - Logic to confirm click
    async handleConfirmClick(row) {
        const result = await LightningConfirm.open({
            message: "Do you want to delete the selected " + this.fieldName + " file ?",
            variant: "default",
            label: "Delete a file"
        });
        if (result) {
            this.handleFileDeleteMethod(row);
        } else {
        }
    }

    // Method - Logic close the method
    handleCloseModal() {
        this.showModal = false;
    }
    get rangeInfo() {
        const startRange = (this.pageNumber - 1) * this.pageSize + 1;
        const endRange = Math.min(this.pageNumber * this.pageSize, this.totalRecords);
        return `${startRange}-${endRange} of ${this.totalRecords} items`;
    }
    handleButtonClick(event) {
        var actionName = event.target.label;
        var row = event.target.value;
        if (actionName == '' || actionName == null || actionName == 'undefined') {
            actionName = 'Preview';
            var fileId = event.target.dataset.id;
            row = this.dataTable.find(file => file.Id === fileId);
        }

        this.fieldName = row['File_Name__c'];
        if (actionName === 'Preview') {
            const objectKey = row['ObjectKey__c'];

            const presignedGETURL = this.s3.getSignedUrl('getObject', {
                Bucket: this.bucketname,
                Key: objectKey,
                Expires: 86400
            });
            this.showModal = true;
            this.url = presignedGETURL;

        }


        if (actionName === 'Download') {

            const objectKey = row['ObjectKey__c'];
            const presignedGETURL = this.s3.getSignedUrl('getObject', {
                Bucket: this.bucketname,
                Key: objectKey,
                Expires: 86400
            });

            const filetype = row['File_Type__c'];

            if (filetype.includes('doctype:word') ||
                filetype.includes('doctype:gsheet') ||
                filetype.includes('doctype:zip') ||
                filetype.includes('doctype:ppt')) {

                const link = document.createElement('a');
                link.href = presignedGETURL;
                link.download = true;
                link.style.display = 'none';
                document.body.appendChild(link);
                link.click();
                document.body.removeChild(link);
            }

            else if (filetype.includes('doctype:pdf')) {

                const link = document.createElement('a');
                link.href = presignedGETURL;
                link.target = '_blank'
                link.download = true;
                link.style.display = 'none';
                document.body.appendChild(link);
                link.click();
                document.body.removeChild(link);
            }

            else {
                this.handleDownloadMethod(row);
            }
        }

        if (actionName === 'Delete') {
            this.handleConfirmClick(row);
        }
         if (actionName === 'Copy URL') {
            this.copyTextToClipboard(row);
        }
    }
async copyTextToClipboard(file) {
        var bool = true;
        const CurrentDate = new Date();
        const CreatedDate = new Date(file.CreatedDate);
        const LastModifiedDate = new Date(file.LastModifiedDate);
        var differenceInMilliseconds = Math.abs(CurrentDate - CreatedDate);
        var differenceInDays = Math.ceil(differenceInMilliseconds / (1000 * 60 * 60 * 24));
        if (differenceInDays < 7) {
            bool = true;
        }
        else {
            differenceInMilliseconds = Math.abs(CurrentDate - LastModifiedDate);
            differenceInDays = Math.ceil(differenceInMilliseconds / (1000 * 60 * 60 * 24));
            if (differenceInDays < 7) {
                bool = true;
            }
            else {
                bool = false;
            }
        }
        var fileurl;
        if (bool == false) {
            const presignedGETURL = this.s3.getSignedUrl('getObject', {
                Bucket: this.bucketname,
                Key: file.ObjectKey__c,
                Expires: 604800 // Time to expire in seconds
            });
            updateUrl({
                ID: file.Id,
                URL: presignedGETURL
            })
                .then((result) => {
                }).catch((err) => {
                });
            fileurl = presignedGETURL;
        } else {
            fileurl = file.File_url__c;
        }
        const result = await LightningConfirm.open({
            message: "This Link is Expire Within 7 Day. Do You Want to Copy?",
            variant: "default",
            label: "Caution !"
        });
        if (result) {
            navigator.clipboard.writeText(fileurl)
                .then(() => {
                    const evt = new ShowToastEvent({
                        title: 'Copy Successfully',
                        message: "Public URL link is successfully Copied to Your clipboard !",
                        variant: 'success',
                    });
                    this.dispatchEvent(evt);
                })
                .catch((error) => {
                });

        }


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
    }
    imageDownload(blob, fileName) {

        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.style.display = 'none';
        a.href = url;
        a.download = fileName;
        document.body.appendChild(a);
        a.click();
        window.URL.revokeObjectURL(url);
    }
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }


}