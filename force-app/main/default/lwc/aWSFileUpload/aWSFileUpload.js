import { LightningElement, track, wire, api } from "lwc";
import { getRecord } from "lightning/uiRecordApi";
import { loadScript } from 'lightning/platformResourceLoader';
import getAWSFiles from '@salesforce/apex/AWSFileUploadHandlingControllerForObject.getAWSFiles';
import AWS_SDK from "@salesforce/resourceUrl/AWSSDK";
import recordInsert from '@salesforce/apex/AWSFileUploadHandlingControllerForObject.recordInsert';
import fetchExistingFileNames from '@salesforce/apex/AWSFileUploadHandlingControllerForObject.fetchExistingFileNames';
import deleteCallout from '@salesforce/apex/AWSFileUploadHandlingControllerForObject.deleteCallout';
import getAWSConfiguration from '@salesforce/apex/AWSFileUploadHandlingController.getAWSConfiguration';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import File_Upload from '@salesforce/label/c.File_Upload';
import FORM_FACTOR from "@salesforce/client/formFactor";

export default class FileUploadComponentLWC extends LightningElement {
    /*========= Start - variable declaration =========*/
    label = {
        File_Upload
    };
    s3; //store AWS S3 object
    isAwsSdkInitialized = false; //flag to check if AWS SDK initialized
    @track awsSettngRecordId; //store record id of custom metadata type where AWS configurations are stored
    selectedFilesToUpload; //store selected file
    @track showSpinner = false; //used for when to show spinner
    @track fileName = ''; //to display the selected file name
    @api recordId;
    @api objectApiName;
    @api recordrecordName;
    @track objurlname;
    @track baseurl;
    @track dataTable = [];
    @track awsS3MetadataConfMain = {};
    @track existingFileNamesList = [];
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
    showModal = false;
    url;
    directdownloadflag = false;
    @track downloadPopup = false;
    @track fileSize = '';
    @track selectedfile;
    @track fieldName;
    @track showUploadPopup = false;
    @track showDownloadModal = false;

    @track draggedFiles = [];
    @track selectedFiles = [];
    @track isUploadDisabled = true;
    @track fileUploading = false;
    @track uploadAreaClass = 'upload-area';

    @track createdDate = '';
    @track progress = 0;
    @track downloadComplete = false;

    @track selectedFileForPreview = null;
    @track previewUrl = '';
    @track previewError = false;
    @track previewLoading = true;

    recordEnd = 0;
    recordStart = 0;
    totalRecords = 0;
    pageNumber = 1;
    totalPages = 0;
    pageSize = 10;
    isPrev = true;
    isNext = true;
    @track folderlist = [];

    @track downloadDate = '';



    get progressStyle() {
        return `width: ${this.progress}%;`;
    }

    // Getter for progress bar CSS class
    get progressBarClass() {
        return this.downloadComplete ? 'progress-bar completed' : 'progress-bar';
    }

    // In your JavaScript controller
    handleDownloadComplete() {
        this.downloadComplete = true;
        this.progress = 100;
    }

    handleCloseDownload() {
        if (this.downloadComplete) {
            this.downloadPopup = false;
            this.downloadComplete = false;
            this.progress = 0;
        } else {
            this.handleShowToastMsgMethod('Download in Progress', 'Please wait for the download to complete', 'warning');
        }
    }

    // Example of how to trigger the download popup
    startDownload(file) {
        this.fileName = file.File_Name__c;
        this.fileSize = this.formatFileSize(file.File_Sizes__c);
        this.createdBy = 'Current User'; // You can replace with actual user
        this.createdDate = this.formatDate(new Date()); // Use file.CreatedDate if available
        this.downloadPopup = true;
        this.progress = 0;

        // Simulate download progress
        let progress = 0;
        const interval = setInterval(() => {
            progress += 5;
            this.progress = Math.min(progress, 100);

            if (progress >= 100) {
                clearInterval(interval);
                this.handleDownloadComplete();
            }
        }, 200);
          setTimeout(() => this.initializeAwsSdk(confData), 100);
                return;
    }

    formatDate(date) {
        const options = { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' };
        return date.toLocaleDateString('en-US', options);
    }

    gettingsharingdetails(parentid, type) {
        this.accesslist = [];
        this.accesslistsize = 0;
        this.showaccesstable = false;
        getssharingdetails({
            parentId: parentid,
            type: type
        }).then((result) => {
            result = JSON.parse(result);
            this.accesslist = result.map(currentItem => {
                if (currentItem.AccessLevel == 'All') {
                    currentItem.isAll = true;
                }
                else {
                    currentItem.isAll = false;
                }
                return currentItem;
            });
            this.accesslistsize = result.length;
        }).catch((err) => {
        });
    }

    handleEditAccess(event) {
        if (this.showaccesstable) {
            this.showaccesstable = false;
        }
        else {
            this.showaccesstable = true;
        }
    }

    hidePopup() {
        this.isPopupVisible = false;
    }

    cancelPopup() {
        this.type = null;
        this.selectedUser = null;
        this.selectedAccess = null;
        this.fileId = null;
        this.deletedaccesslist = [];
        this.folderId = null;
        this.isPopupVisible = false;
        this.showaccesstable = false;
    }

    handleChange(event) {
        const type = event.target.dataset.type;
        if (type == 'user') {
            this.selectedUser = event.detail.value;
        } else if (type == 'access') {
            this.selectedAccess = event.detail.value;
        }
        else if (type == 'delete') {
            var item = this.accesslist.find((item) => item.Id == event.target.dataset.id);
            if (!this.deletedaccesslist.includes(item.Id)) {
                this.deletedaccesslist.push(item.Id);
            }
            this.accesslist = this.accesslist.filter((element) => { return element.Id !== item.Id });
            this.accesslistsize = this.accesslist.length;
        }
        else if (type == 'table') {
            this.accesslist = this.accesslist.map((item) => {
                if (item.Id === event.target.dataset.id) {
                    var oldAccessLevel = item.AccessLevel;

                    updatingAccess({
                        Id: item.Id,
                        AccessLevel: event.detail.value,
                        Type: this.type
                    }).then((result) => {
                        if (result) {
                            item.AccessLevel = event.detail.value;
                            this.handleShowToastMsgMethod('Success ', 'Access Level Updated Successfully in \'' + item.UserOrGroup.Name + '\'.', 'success');
                        } else {
                            item.AccessLevel = oldAccessLevel;
                            this.handleShowToastMsgMethod('Error ', 'Error in Updating Access Level in \'' + item.UserOrGroup.Name + '\'.', 'error');
                        }
                    }).catch((err) => {
                        item.AccessLevel = oldAccessLevel;
                        this.handleShowToastMsgMethod('Error ', 'Error in Updating Access Level in \'' + item.UserOrGroup.Name + '\'.', 'error');
                    });
                }
                return item;
            })
        }
    }

    handleClose() {
        this.showPopup = false;
    }

    connectedCallback() {
        this.handleFormFactor();
        this.loadAWSConfiguration(); // Load AWS config first
        this.getUploadedFiles(this.pageSize, this.pageNumber);
        this.fetchExistingFileNamesMethod();
    }

    renderedCallback() {
        if (this.isAwsSdkInitialized) {
            return;
        }
        Promise.all([loadScript(this, AWS_SDK)])
            .then(() => {
                console.log('AWS SDK loaded successfully');
                if (this.awsS3MetadataConfMain && Object.keys(this.awsS3MetadataConfMain).length > 0) {
                    this.initializeAwsSdk(this.awsS3MetadataConfMain);
                }
            })
            .catch(error => {
                console.error('Error loading AWS SDK:', error);
                this.handleShowToastMsgMethod('Error', 'Failed to load AWS SDK', 'error');
            });
    }

    handleDragOver(event) {
        event.preventDefault();
        event.stopPropagation();
        this.uploadAreaClass = 'upload-area drag-over';
    }

    handleDragLeave(event) {
        event.preventDefault();
        event.stopPropagation();
        this.uploadAreaClass = 'upload-area';
    }

    handleDrop(event) {
        event.preventDefault();
        event.stopPropagation();
        this.uploadAreaClass = 'upload-area';

        const files = Array.from(event.dataTransfer.files);
        this.processSelectedFiles(files);
    }

    handleFileInputChange(event) {
        const files = Array.from(event.target.files);
        this.processSelectedFiles(files);
    }

    processSelectedFiles(files) {
        if (files.length === 0) return;

        this.draggedFiles = [];

        files.forEach((file, index) => {
            const maxSize = 10 * 1024 * 1024; // 10MB
            if (file.size > maxSize) {
                this.handleShowToastMsgMethod('File Too Large', `${file.name} exceeds 10MB limit`, 'warning');
                return;
            }

            const fileObj = {
                file: file,
                name: file.name,
                size: this.formatFileSize(file.size),
                type: file.type,
                progress: 0,
                style: 'width: 0%;'
            };

            this.draggedFiles.push(fileObj);
        });

        this.isUploadDisabled = this.draggedFiles.length === 0;
    }

    openFileDialog() {
        const fileInput = this.template.querySelector('.file-input-hidden');
        if (fileInput) {
            fileInput.click();
        }
    }

    // Remove individual file
    removeFile(event) {
        const index = parseInt(event.target.dataset.index);
        this.draggedFiles.splice(index, 1);

        // Update upload button state
        this.isUploadDisabled = this.draggedFiles.length === 0;

        // Reset file input
        const fileInput = this.template.querySelector('.file-input-hidden');
        if (fileInput) {
            fileInput.value = '';
        }
    }

    // Get upload progress for display
    get getUploadProgress() {
        return this.draggedFiles.map(file => ({
            name: file.name,
            size: file.size,
            progress: file.progress || 0,
            style: file.style || 'width: 0%;'
        }));
    }

    // Handle individual file actions menu
    handleFileMenuSelect(event) {
        const selectedValue = event.detail.value;
        const fileId = event.target.dataset.fileId;
        console.log('File menu item selected:', selectedValue, 'for file:', fileId);

        const selectedFile = this.allFiles.find(file => file.Id === fileId);
        if (!selectedFile) {
            console.warn('File not found for ID:', fileId);
            return;
        }

        if (selectedValue === 'preview') {
            this.openModal(selectedFile);
        } else if (selectedValue === 'download') {
            this.openDownloadModal(selectedFile);
        } else if (selectedValue === 'delete') {
            this.selectedFileForDeletion = selectedFile;
            this.showDeleteConfirmation = true;
        }
    }

    openModal(file) {
        this.previewError = false;
        this.previewLoading = true;
        this.selectedFileForPreview = file;

        try {
            if (!this.s3 || !this.isAwsSdkInitialized) {
                throw new Error('AWS SDK not initialized');
            }

            const objectKey = file.ObjectKey__c ||
                `${this.objectApiName}/${this.recordId}/${file.File_Name__c.replace(/\s+/g, "_").toLowerCase()}`;

            if (!objectKey) {
                throw new Error('Unable to determine object key for file');
            }

            this.previewUrl = this.s3.getSignedUrl('getObject', {
                Bucket: this.bucketname,
                Key: objectKey,
                Expires: 300 // 5 minutes
            });

            this.showModal = true;
            this.previewLoading = false;
        } catch (error) {
            console.error('Error generating preview URL:', error);
            this.previewError = true;
            this.previewLoading = false;
            this.handleShowToastMsgMethod('Preview Error', 'Failed to generate preview URL: ' + error.message, 'error');
            this.showModal = true;
        }
    }

    openFileInNewTab() {
        if (this.previewUrl) {
            window.open(this.previewUrl, '_blank');
            this.closePreviewModal(); 
        }
    }

    closePreviewModal() {
        this.showModal = false;
        this.selectedFileForPreview = null;
        this.previewUrl = '';
        this.previewError = false;
        this.previewLoading = true;
    }

    uploadToAWS(file, index) {
        return new Promise((resolve, reject) => {
            const currentFileName = file?.name || 'Unknown file';

            if (!file) {
                reject('No file provided');
                return;
            }

            let objName = this.objectApiName + '/' + this.recordId;
            let objKey = objName + '/' + file.name.replace(/\s+/g, "_").toLowerCase();

            try {
                const presignedUrl = this.s3.getSignedUrl('putObject', {
                    Key: objKey,
                    ContentType: file.type,
                    Expires: 60000
                });

                const xhr = new XMLHttpRequest();
                xhr.open("PUT", presignedUrl, true);

                xhr.upload.addEventListener("progress", (event) => {
                    if (event.lengthComputable) {
                        const percentComplete = (event.loaded / event.total) * 100;
                        this.uploadProgress = Math.round(percentComplete);
                        if (index !== undefined && this.draggedFiles[index]) {
                            this.draggedFiles[index].progress = this.uploadProgress;
                            this.draggedFiles[index].style = `width: ${this.uploadProgress}%;`;
                        }
                    }
                });

                xhr.onreadystatechange = () => {
                    if (xhr.readyState === 4) {
                        if (xhr.status === 200) {
                            this.trackSuccess(file, objKey);
                            resolve();
                        } else {
                            console.error('Upload failed with status:', xhr.status);
                            this.handleShowToastMsgMethod('Error', `[${currentFileName}] Upload failed with status: ${xhr.status}`, 'error');
                            reject('Upload failed');
                        }
                    }
                };

                xhr.onerror = () => {
                    this.handleShowToastMsgMethod('Error', `[${currentFileName}] Upload request failed`, 'error');
                    reject('Upload request failed');
                };

                xhr.send(file);
            } catch (error) {
                console.error('Error creating presigned URL:', error);
                this.handleShowToastMsgMethod('Error', `[${currentFileName}] Error creating presigned URL: ${error.message}`, 'error');
                reject(error);
            }
        });
    }

    trackSuccess(file, objKey) {
        const presignedGETURL = this.s3.getSignedUrl('getObject', {
            Bucket: this.bucketname,
            Key: objKey,
            Expires: 604800 // This URL expires in 7 days
        });

        recordInsert({
            parent: this.objectApiName,
            parentId: this.recordId,
            parentRecordName: this.recordrecordName,
            fileName: file.name,
            fileURL: presignedGETURL,
            filetype: file.type,
            objKey: objKey,
            filesize: file.size
        })
            .then(result => {
                this.fileName = '';
                this.filecount = this.filecount + 1;
                if (this.filecount >= this.actualsize) {
                    this.handleShowToastMsgMethod('Success', 'All files uploaded successfully', 'success');
                    this.uploadloaded = false;
                    this.fileUploading = false;
                    this.isUploadDisabled = true;
                    this.closeUploadPopup();
                    this.pageNumber = 1;
                    this.getUploadedFiles(this.pageSize, this.pageNumber);
                }
            })
            .catch(error => {
                console.error('Error saving file record:', error);
                this.handleShowToastMsgMethod('Error', 'Failed to save file record', 'error');
                this.fileUploading = false;
            });
    }

    proceedWithUpload() {
        if (!this.draggedFiles || this.draggedFiles.length === 0) {
            this.handleShowToastMsgMethod('No Files', 'Please select files to upload', 'warning');
            return;
        }

        if (!this.isAwsSdkInitialized) {
            this.handleShowToastMsgMethod('Error', 'AWS SDK not initialized', 'error');
            return;
        }

        this.isUploadDisabled = true;
        this.fileUploading = true;
        this.filecount = 0;
        this.actualsize = this.draggedFiles.length;

        const promises = [];

        for (let i = 0; i < this.draggedFiles.length; i++) {
            const currentFileName = this.draggedFiles[i].name;

            if (this.existingFileNamesList.includes(currentFileName)) {
                this.handleShowToastMsgMethod('Duplicate File', `${currentFileName} already exists`, 'error');
                this.closeUploadPopup();
                this.fileUploading = false;
                continue;
            }

            const file = this.draggedFiles[i].file;
            promises.push(this.uploadToAWS(file, i));
            this.existingFileNamesList.push(currentFileName);
        }

        if (promises.length > 0) {
            this.uploadloaded = true;
            Promise.all(promises)
                .then(() => {
                    console.log('All files uploaded successfully');
                })
                .catch(error => {
                    console.error('Error uploading files:', error);
                    this.handleShowToastMsgMethod('Error', 'Failed to upload some files', 'error');
                    this.fileUploading = false;
                });
        } else {
            this.fileUploading = false;
            this.isUploadDisabled = false;
        }
    }

    /* Wire Method - Start */
    @wire(getRecord, { recordId: '$recordId', fields: ['ObjectApiName__c.Name'] })
    wiredRecord({ error, data }) {
        if (data) {
            this.recordrecordName = data.fields.Name.value;
        } else if (error) {
            console.error('Error fetching record:', error);
        }
    }

    /* Wire Method - End */
    loadAWSConfiguration() {
        getAWSConfiguration()
            .then(result => {
                console.log('AWS Configuration loaded:', result);
                if (result) {
                    let awsS3MetadataConf = {
                        s3bucketName: result.S3_Bucket_Name__c,
                        awsAccessKeyId: result.AWS_Access_Key_Id__c,
                        awsSecretAccessKey: result.AWS_Secret_Access_Key__c,
                        s3RegionName: result.S3_Region_Name__c
                    };
                    this.awsS3MetadataConfMain = awsS3MetadataConf;
                    this.bucketname = result.S3_Bucket_Name__c; // Set bucket name
                    this.baseurl = 'https://' + result.S3_Bucket_Name__c + '.s3.' + result.S3_Region_Name__c + '.amazonaws.com/';

                    console.log('AWS Config set:', this.awsS3MetadataConfMain);
                    if (window.AWS && this.awsS3MetadataConfMain) {
                        this.initializeAwsSdk(this.awsS3MetadataConfMain);
                    }
                } else {
                    this.handleShowToastMsgMethod('Error', 'AWS Configuration not found', 'error');
                }
            })
            .catch(error => {
                console.error('Error loading AWS configuration:', error);
                this.handleShowToastMsgMethod('Error', 'Failed to load AWS configuration: ' + error.body?.message, 'error');
            });
    }

    initializeAwsSdk(confData) {
        const AWS = window.AWS;
        AWS.config.update({
            accessKeyId: confData.awsAccessKeyId, 
            secretAccessKey: confData.awsSecretAccessKey 
        });

        AWS.config.region = confData.s3RegionName; 

        this.s3 = new AWS.S3({
            apiVersion: "2012-10-17",
            signatureVersion: 'v4',
            params: {
                Bucket: confData.s3bucketName 
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

    handleDownloadMethod(rowdetail) {
        const row = rowdetail;
        const objectKey = row['ObjectKey__c'];
        this.fileName = row['File_Name__c'];
        this.fileSize = row['File_sizes__c'];
        this.createdDate = row['CreatedDate'] || new Date().toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });

        this.downloadPopup = true;
        this.downloadComplete = false;
        this.progress = 0;

        const presignedGETURL = this.s3.getSignedUrl('getObject', {
            Bucket: this.bucketname,
            Key: objectKey,
            Expires: 60
        });

        var xhr = new XMLHttpRequest();
        xhr.open('GET', presignedGETURL, true);
        xhr.responseType = 'blob';

        xhr.onprogress = (e) => {
            if (e.lengthComputable) {
                this.progress = parseInt((e.loaded / e.total) * 100);
                this.template.querySelector('c-file-upload-component-lwc').requestUpdate();
            }
        };

        xhr.onload = (e) => {
            if (xhr.status === 200) {
                this.progress = 100;
                this.downloadComplete = true;
                this.imageDownload(xhr.response, this.fileName);
            }
        };

        xhr.onerror = () => {
            this.handleShowToastMsgMethod('Error', 'Download failed', 'error');
            this.downloadPopup = false;
        };

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

    getUploadedFiles(size, number) {
        this.dataTable = [];
        getAWSFiles({
            parentId: this.recordId,
            pageSize: size,
            pageNumber: number
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
                    CreatedDate: new Date(record.CreatedDate).toLocaleDateString('en-US', {
                        year: 'numeric',
                        month: 'short',
                        day: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit'
                    })
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

    formateicon(files) {
        return files.map((item) => {
            const newItem = { ...item };
            let fileType = '';
            let className = 'file-type-box ';

            switch (item.File_Type__c) {
                case 'image/jpeg':
                case 'image/png':
                    fileType = 'JPEG';
                    className += 'file-type-jpeg';
                    break;
                case 'application/pdf':
                    fileType = 'PDF';
                    className += 'file-type-pdf';
                    break;
                case 'text/plain':
                    fileType = 'TXT';
                    className += 'file-type-txt';
                    break;
                case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
                case 'text/csv':
                    fileType = 'XLSX';
                    className += 'file-type-xlsx';
                    break;
                case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
                case 'application/msword':
                    fileType = 'WORD';
                    className += 'file-type-word';
                    break;
                case 'application/x-zip-compressed':
                    fileType = 'ZIP';
                    className += 'file-type-zip';
                    break;
                case 'application/vnd.ms-powerpoint':
                case 'application/vnd.openxmlformats-officedocument.presentationml.presentation':
                    fileType = 'PPT';
                    className += 'file-type-ppt';
                    break;
                case 'Folder':
                    fileType = 'Folder';
                    className += 'file-type-folder';
                    break;
                default:
                    fileType = 'DLL';
                    className += 'file-type-dll';
            }

            newItem.File_Type__c = fileType;
            newItem.fileTypeBoxClass = className;
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
        }
    }

    handleCloseModal() {
        this.showModal = false;
    }


    handleFormFactor() {
        if (FORM_FACTOR === "Large") {
            this.deviceTypeDesktop = true;
        } else if (FORM_FACTOR === "Medium") {
        } else if (FORM_FACTOR === "Small") {
            this.deviceTypeMobile = true;
        }
    }

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
        a.classList.add('hidden-download-link');
        a.href = url;
        a.download = fileName;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        window.URL.revokeObjectURL(url);
    }
    handleButtonClick1(event) {

        const actionName = event.currentTarget.dataset.value;
        const fileId = event.currentTarget.dataset.id;
        const row = this.dataTable.find(file => file.Id === fileId);

        if (!row) {
            return;
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
                link.classList.add('hidden-download-link');
                document.body.appendChild(link);
                link.click();
                document.body.removeChild(link);
            }
            else if (filetype.includes('doctype:pdf')) {
                const link = document.createElement('a');
                link.href = presignedGETURL;
                link.target = '_blank'
                link.download = true;
                link.classList.add('hidden-download-link');
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
    showdelete = true;

    toggleDropdown(event) {
        const fileId = event.currentTarget.dataset.id;
        this.dataTable = this.dataTable.map(file => ({
            ...file,
            isDropdownOpen: file.Id === fileId ? !file.isDropdownOpen : false
        }));
    }

    showdelete = true;

    handleButtonClick1(event) {
        const fileId = event.currentTarget.dataset.id;
        const row = this.dataTable.find(file => file.Id === fileId);
        if (row) {
            this.openModal(row);
        }
    }

    handleButtonClick2(event) {
        const actionName = event.currentTarget.dataset.value;
        const fileId = event.currentTarget.dataset.id;
        const row = this.dataTable.find(file => file.Id === fileId);

        if (!row) return;

        if (actionName === 'Preview') {
            this.openModal(row);
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

            if (filetype == 'XLSX' || filetype == 'WORD' || filetype == 'ZIP' || filetype == 'PPT') {

                this.downloadPopup = true;

                setTimeout(() => {
                    this.downloadPopup = false;
                }, 2000);

                const link = document.createElement('a');
                link.href = presignedGETURL;
                link.download = true;
                link.classList.add('hidden-download-link');
                document.body.appendChild(link);
                link.click();
                document.body.removeChild(link);


            } 
            else if (filetype.includes('doctype:pdf')) {
                const link = document.createElement('a');
                link.href = presignedGETURL;
                link.target = '_blank'
                link.download = true;
                link.classList.add('hidden-download-link');
                document.body.appendChild(link);
                link.click();
                document.body.removeChild(link);
            } else {
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
    handlecloseDropdownbtn(event) {
        if (event.target.closest('.dropdown-menu') || event.target.closest('lightning-button-icon')) {
            return;
        }
        this.dataTable = this.dataTable.map(file => {
            return { ...file, isDropdownOpen: false };
        });
        this.folderlist = this.folderlist.map(folder => {
            return { ...folder, isDropdownOpen: false };
        });
    }
    handleUpload() {
        console.log('Upload Files clicked');
        this.showUploadPopup = true;
    }

    closeUploadPopup() {
        this.showUploadPopup = false;
        this.draggedFiles = [];
        this.selectedFiles = [];
        this.isUploadDisabled = true;
    }
}