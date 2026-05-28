import { LightningElement, track, wire, api } from 'lwc';
import getrecentFile from '@salesforce/apex/fileSearchController.getRecentlyUploadedfile';
import getsearchedFile from '@salesforce/apex/fileSearchController.getSearchedFile';
import getfilterFile from '@salesforce/apex/fileSearchController.filterfile';
// import Nofilefound from "@salesforce/resourceUrl/Nofilefound";
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadScript } from 'lightning/platformResourceLoader';
import AWS_SDK from "@salesforce/resourceUrl/AWSSDK";
import { getRecord } from "lightning/uiRecordApi";
import fetchMetaListLwc from '@salesforce/apex/AWSFileUploadHandlingControllerForObject.fetchMetaListLwc';

export default class FileSearch extends LightningElement {

    /*-----------------------------------------------Global varible Declaration---------------------------*/

    recordEnd = 0;
    recordStart = 0;
    totalRecords = 0;
    pageNumber = 1;
    totalPages = 0;
    pageSize = 10;
    isPrev = true;
    isNext = true;


    searchTerm = '';
    filervalue = '';
    filter = '';
    operator = '';
    uiname = 'Recent Uploaded file';
    // imagesrc = Nofilefound;
    isdataTable = false;
    isgetrecent = false;
    showfilter = false;
    dataTable = [];
    isdate = false;
    istype = false;
    spinner = false;

    isAwsSdkInitialized = false;
    dataTable;
    fieldName;
    bucketname;
    showModal;
    url;
    s3;
    awsS3MetadataConfMain;
    baseurl;
    awsSettngRecordId;
    progress;
    downloadonprogress = false;



    /*-----------------------------------------------Life cycle hooks starts--------------------------------------*/
    connectedCallback() {
        this.getrecent();
    }
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
    /*-----------------------------------------------Life cycle hooks ends--------------------------------------*/

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

    /*-----------------------------------------------Getter variables--------------------------------------*/

    get filterOptions() {
        return [
            { label: 'Object Name', value: 'Parent_Name__c' },
            { label: 'Created Date', value: 'CreatedDate' },
            { label: ' File Type', value: 'File_Type__c' },
        ];
    }
    get operatorOptions() {
        return [
            { label: 'Equals', value: 'equal' },
            { label: 'Not Equals', value: 'notequal' },
            { label: 'Starts with', value: 'startwith' },
            { label: 'contains', value: 'contains' },
            { label: 'Not contains', value: 'notcontains' },

        ];
    }
    get typeOptions() {
        return [
            { label: 'Image', value: 'image/jpeg' },
            { label: 'Text', value: 'text/plain' },
            { label: 'PDF', value: 'application/pdf' },
            { label: 'Document', value: 'application/msword' },
            { label: 'XLSheet', value: 'text/csv' },
            { label: 'PowerPoint', value: 'application/vnd.ms-powerpoint' },
            { label: 'Zip', value: 'application/x-zip-compressed' },
            { label: 'Others', value: 'others' }
        ];
    }
    get operatorOptions2() {
        return [
            { label: 'Equals', value: 'equal' },
            { label: 'Not Equals', value: 'notequal' },
        ];
    }


    /*-----------------------------------------------Detail page redirection--------------------------------------*/
    clickredirectButton(event) {
        var fileId = event.target.dataset.id;
        var row = this.dataTable.find(file => file.Id === fileId);
        var parentid = row.Parent_Record_Id__c;
        var pageurl = window.location.origin + '/' + parentid;

        const link = document.createElement('a');
        link.href = pageurl;
        link.target = '_blank'
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);

    }
    /*-----------------------------------------------Input and Input clear function---------------------------*/
    // Method - Logic close the method
    handleCloseModal() {
        this.showModal = false;
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
                Expires: 60
            });
            this.showModal = true;
            this.url = presignedGETURL;
        }


        if (actionName === 'Download') {

            const objectKey = row['ObjectKey__c'];
            const presignedGETURL = this.s3.getSignedUrl('getObject', {
                Bucket: this.bucketname,
                Key: objectKey,
                Expires: 60
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
            Expires: 60 // Time to expire in seconds
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
    redirectButton(event) {
        const value = event.target.getAttribute('value');
        const formattedValue = value.Id;
    }
    valuechange(event) {
        this.filervalue = event.detail.value;
        if (this.filervalue == null || this.filervalue == undefined || this.filervalue == '') {
            this.filervalue = event.target.value;
        }
    }

    handleChangefilter(event) {
        this.filter = event.detail.value;
        this.operator = '';
        this.filervalue = '';
        if (this.filter == 'File_Type__c') {
            this.isdate = false;
            this.istype = true;
        } else if (this.filter == 'CreatedDate') {
            this.istype = false;
            this.isdate = true;
        }
        else {
            this.isdate = false;
            this.istype = false;
        }
    }
    handleChangeoperator(event) {
        this.operator = event.detail.value;
    }
    handleclearClick() {
        this.filervalue = '';
        this.filter = '';
        this.operator = '';
    }
    handleClearClick() {
        this.uiname = 'Recent Uploaded file';
        this.searchTerm = '';
        this.showfilter = false;
        this.getrecent();
    }
    addfilter() {
        this.showfilter = !this.showfilter;
        if (this.showfilter == false) {
            this.filervalue = '';
            this.filter = '';
            this.operator = '';
        }
    }
    searchval(event) {
        this.isdataTable = false;
        this.spinner = true;
        this.searchTerm = event.detail.value;
        if (this.searchTerm == '' || this.searchTerm == null) {
            this.getrecent();
        } else {
            this.searchfile(this.searchTerm);
        }
    }

    handlefilterClick() {
        this.pageNumber = 1;
        this.pageSize = 10;
        if ((this.searchTerm == undefined || this.searchTerm == null || this.searchTerm == '') || (this.filervalue == undefined || this.filervalue == null || this.filervalue == '') || (this.filter == undefined || this.filter == null || this.filter == '') || (this.operator == undefined || this.operator == null || this.operator == '')) {
            this.showToast('Field Missing', 'Please fill the missing field', 'error');
        }
        else {
            this.spinner = true;
            this.isdataTable = false;
            this.fiterfile(this.searchTerm, this.filter, this.operator, this.filervalue);
        }
    }
    handlePagePrevAction() {
        this.pageNumber = this.pageNumber - 1;
        if ((this.filervalue == undefined || this.filervalue == null || this.filervalue == '') || (this.filter == undefined || this.filter == null || this.filter == '') || (this.operator == undefined || this.operator == null || this.operator == '')) {
            this.searchfile(this.searchTerm);
        }
        else {
            this.fiterfile(this.searchTerm, this.filter, this.operator, this.filervalue);
        }

    }
    handlePageNextAction() {
        this.pageNumber = this.pageNumber + 1;
        if ((this.filervalue == undefined || this.filervalue == null || this.filervalue == '') || (this.filter == undefined || this.filter == null || this.filter == '') || (this.operator == undefined || this.operator == null || this.operator == '')) {
            this.searchfile(this.searchTerm);
        }
        else {
            this.fiterfile(this.searchTerm, this.filter, this.operator, this.filervalue);
        }

    }

    /*-----------------------------------------------Utility Function--------------------------------------*/

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
    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }

    /*-----------------------------------------------Apex calling Functions--------------------------------------*/

    searchfile(searchTerm) {
        getsearchedFile({ searchname: searchTerm, pageSize: this.pageSize, pageNumber: this.pageNumber })
            .then((result) => {
                var resultData = JSON.parse(result);
                this.recordEnd = resultData.recordEnd;
                this.totalRecords = resultData.totalRecords;
                this.recordStart = resultData.recordStart;
                this.dataTable = resultData.uploadedfile;
                this.pageNumber = resultData.pageNumber;
                this.totalPages = Math.ceil(resultData.totalRecords / this.pageSize);
                this.isNext = (this.pageNumber == this.totalPages || this.totalPages == 0);
                this.isPrev = (this.pageNumber == 1 || this.totalRecords < this.pageSize);
                if (this.dataTable.length > 0) {
                    this.isdataTable = true;
                    this.isgetrecent = true;
                  this.uiname = 'Name Related to "' + this.searchTerm + '"';

                }
                this.dataTable = this.dataTable.map(record => ({
                    ...record,
                    File_sizes__c: this.formatFileSize(parseInt(record.File_sizes__c, 10)),
                    CreatedDate: new Date(record.CreatedDate).toLocaleDateString()

                }));
                this.dataTable = this.formateicon(this.dataTable);
                this.spinner = false;
            }).catch((err) => {
                this.spinner = false;
            });

    }

    getrecent() {
        this.isgetrecent = false;
        this.spinner = true;
        getrecentFile()
            .then((result) => {
                if (result.length > 0) {
                    this.isdataTable = true;
                }
                this.uiname = 'Recent Uploaded file';
                this.dataTable = result;
                this.dataTable = this.dataTable.map(record => ({
                    ...record,
                    File_sizes__c: this.formatFileSize(parseInt(record.File_sizes__c, 10)),
                    CreatedDate: new Date(record.CreatedDate).toLocaleDateString()

                }));
                this.dataTable = this.formateicon(this.dataTable);
                this.spinner = false;
            }).catch((err) => {
                this.spinner = false;
            });
    }

    fiterfile(searchTerm, filter, operator, filervalue) {
        getfilterFile({
            searchname: searchTerm,
            filter: filter,
            operator: operator,
            value: filervalue,
            pageSize: this.pageSize,
            pageNumber: this.pageNumber
        })
            .then((result) => {
                var resultData = JSON.parse(result);
                this.recordEnd = resultData.recordEnd;
                this.totalRecords = resultData.totalRecords;
                this.recordStart = resultData.recordStart;
                this.dataTable = resultData.uploadedfile;
                this.pageNumber = resultData.pageNumber;
                this.totalPages = Math.ceil(resultData.totalRecords / this.pageSize);
                this.isNext = (this.pageNumber == this.totalPages || this.totalPages == 0);
                this.isPrev = (this.pageNumber == 1 || this.totalRecords < this.pageSize);
                if (this.dataTable.length > 0) {
                    this.isdataTable = true;
                    this.isgetrecent = true;
                    this.uiname = 'Name Related to ' + this.searchTerm;
                }
                this.dataTable = this.dataTable.map(record => ({
                    ...record,
                    File_sizes__c: this.formatFileSize(parseInt(record.File_sizes__c, 10)),
                    CreatedDate: new Date(record.CreatedDate).toLocaleDateString()

                }));
                this.dataTable = this.formateicon(this.dataTable);
                this.spinner = false;
            }).catch((err) => {
                this.spinner = false;
            });
    }
}