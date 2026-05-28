import { LightningElement, track, wire, api } from "lwc";
import USER_ID from '@salesforce/user/Id';
import { getRecord } from "lightning/uiRecordApi";
import { loadScript } from 'lightning/platformResourceLoader';
import getAWSFiles from '@salesforce/apex/AWSFileUploadHandlingController.getAWSFiles';
import deleteAcess from '@salesforce/apex/AWSFileUploadHandlingController.deleteAccess';
import updateUrl from '@salesforce/apex/AWSFileUploadHandlingController.updateUrl';
import AWS_SDK from "@salesforce/resourceUrl/AWSSDK";
import recordInsert from '@salesforce/apex/AWSFileUploadHandlingController.recordInsert';
import updatingAccess from '@salesforce/apex/AWSFileUploadHandlingController.updatingAccess';
import fetchExistingFileNameunderFolder from '@salesforce/apex/AWSFileUploadHandlingController.fetchExistingFileNameunderFolder';
import addFolder from '@salesforce/apex/folderController.addFolder';
import deleteCallout from '@salesforce/apex/AWSFileUploadHandlingController.deleteCallout';
import getfolderbelowparent from '@salesforce/apex/folderController.getFolderList';
import getRootParent from '@salesforce/apex/folderController.getRootParent';
import get_files_Folder_for_Del from '@salesforce/apex/folderController.getAllFilesAndFoldersInFolder';
import apexFolderDelete from '@salesforce/apex/folderController.deletefolder';
import getBackToParent from '@salesforce/apex/folderController.getBackToParent';
import getFolderName from '@salesforce/apex/folderController.getFolderName';
import getUsers from '@salesforce/apex/AWSFileUploadHandlingController.getUsers';
import removeAccess from '@salesforce/apex/AWSFileUploadHandlingController.removeAccess';
import getssharingdetails from '@salesforce/apex/AWSFileUploadHandlingController.getssharingdetails';
import updateFolderOwner from '@salesforce/apex/AWSFileUploadHandlingController.updateFolderOwner';
import updateFileOwner from '@salesforce/apex/AWSFileUploadHandlingController.updateFileOwner';


import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';

export default class FileDisplay extends LightningElement {

    @api sharedRootId;
    @api folderViewType;
    @api folderParentId;
    @api parentRecordNames;
    @api folderType;
    @api type;
    s3; //store AWS S3 object
    isAwsSdkInitialized = false; //flag to check if AWS SDK initialized
    awsSettngRecordId; //store record id of custom metadata type where AWS configurations are stored
    selectedFilesToUpload; //store selected file
    // showSpinner = false; //used for when to show spinner
    fileName; //to display the selected file name
    @api recordId;
    @api objectApiName;
    @api folderName;
    privateFolderIds = [];
    objurlname;
    showFile = false;
    noFile = false;
    parentTemp = true;
    isfolderList = false;
    showShare = false;
    baseurl;
    // fileMessage='No Files and Folders Found ...';
    // dataTable;
    awsS3MetadataConfMain = {};
    existingFileNamesList = [];
    @api parentRecordId;
    dataTable = [];
    folderlist = [];


    isModalOpen = false;
    // hasRendered = true;
    // isLoading = false;
    //showDataTable = false;
    timeout;
    //awsdeleted = false;
    //sfdcdeleted = false;
    bucketname;
    timeSpan = 5000;
    // @api isLoaded = false;
    // deviceTypedesktop = false;
    // deviceTypemobile = false;
    filecount = 0;
    fileSize = '';
    actualsize;
    progress;
    showModal = false;
    url;
    uploadProgress = 0;
    uploadloaded = false;
    // downloadonprogress = false;
    // directdownloadflag = false;
    fileInput;
    userId = USER_ID;
    folderNameInput = '';
    currentFolderName;
    @track isPopupVisible = false;
    @track popupTitle = 'Popup Title';
    @track popupMessage = 'Popup Message';
    @track selectedUser = '';
    @track userOptions = [];
    @wire(getUsers)
    wiredUsers({ error, data }) {
        if (data) {
            this.userOptions = data.map(user => ({
                label: user.Name,
                value: user.Id
            }));
        } else if (error) {
        }
    }
    type;
    folderId;
    fileId;
    accessLabel;
    selectedAccess;
    accessoptions = [{ label: "Read Only", value: 'Read' }, { label: "Read/Write", value: 'Edit' }];
    accessoptionsfortable = [{ label: "All", value: 'All' }, { label: "Read Only", value: 'Read' }, { label: "Read/Write", value: 'Edit' }];
    accesslist = [];
    deletedaccesslist = [];
    accesslistsize = 0;
    showaccesstable = false;

    showPopup() {
        this.type = event.target.dataset.type;
        this.isPopupVisible = true;
        if (this.type == 'folder') {
            this.fileId = null;
            this.accessLabel = 'Folder Access Level';
            this.folderId = event.target.dataset.id;
            this.gettingsharingdetails(this.folderId, this.type);

        } else if (this.type == 'file') {
            this.folderId = null;
            this.accessLabel = 'File Access Level';
            this.fileId = (event.target.value).Id;
            this.gettingsharingdetails(this.fileId, this.type);
        }
        else {
            this.isPopupVisible = false;
        }

    }


    gettingsharingdetails(parentid, type) {
        this.accesslist = [];
        this.accesslistsize = 0;
        this.showaccesstable = false;
        getssharingdetails({
            parentid: parentid,
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
            //    this.accesslist=result;
            this.accesslistsize = result.length;
        }).catch((err) => {
        });
    }

    handleEditAccess(event) {
        // this.showaccesstable = true;
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
        else {
        }
    }
    connectedCallback() {
        this.getUploadedFiles(this.folderParentId);
        this.fetchExistingFileNamesMethod(this.folderParentId);
        this.parentFolderCheck();
        this.getfolderlist(this.folderParentId);
        this.handleFetchRecordData();
        this.iconClass = 'icon-shrink';

    }
    renderedCallback() {

        this.fileCheck();

        if (!this.fileInput) {
            this.fileInput = this.template.querySelector('input[type="file"]');
            this.fileInput.addEventListener('change', this.handleFileChange.bind(this));
        }
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

    awsConffigData({
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

    handleButtonClickfolder() {
        // Click the file input
        this.fileInput.click();

    }



    handleFileChange(event) {
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
    /* Method - Check for duplicate file using name*/
    fetchExistingFileNamesMethod(folderid) {
        fetchExistingFileNameunderFolder({
            folderID: folderid
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
            let objName;
            if (this.folderType == 'private') {
                objName = this.folderParentId + '/' + this.userId;
            }
            else if (this.folderType == 'public') {
                objName = this.folderParentId;

            }
            else {
                objName = this.folderParentId + '/' + this.userId;
            }
            let objKey = objName + '/' + file.name
                .replace(/\s+/g, "_")
                .toLowerCase();
            const presignedUrl = this.s3.getSignedUrl('putObject', {
                Key: objKey,
                ContentType: file.type,
                Expires: 600000
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

        // let url = this.baseurl + '' + objKey;
        const presignedGETURL = this.s3.getSignedUrl('getObject', {
            Bucket: this.bucketname,
            Key: objKey,
            Expires: 604800 // This URL is Experied iN 7 days
        });
        recordInsert({
            parent: this.folderParentId,
            parentId: this.recordId,
            parentRecordName: this.parentRecordNames,
            fileName: file.name,
            fileURL: presignedGETURL,
            filetype: file.type,
            objKey: objKey,
            filesize: file.size

        })

            .then(result => {
                this.fileName = ' ';
                this.fetchExistingFileNamesMethod(this.folderParentId);
                // this.getUploadedFiles();
            })
            .catch(error => {
            })

        this.filecount = this.filecount + 1;
        if (this.filecount >= this.actualsize) {
            setTimeout(() => {
                this.handleShowToastMsgMethod('Success', 'File has been uploaded Successfully', 'success');
                //this.getUploadedFiles();
                this.uploadloaded = false;

                this.getUploadedFiles(this.folderParentId);
                this.templeteVisibleFunction();
            }, 1000);
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


    handleClickAccordion(event) {
        const sectionId = event.currentTarget.dataset.sectionid;
        const contentEl = this.template.querySelector(`[data-contentid="${sectionId}"]`);

        if (contentEl) {
            const isHidden = contentEl.getAttribute('aria-hidden') === 'true';
            contentEl.setAttribute('aria-hidden', String(!isHidden));
        }
    }

    //------------------------------------------------------------------------------------------------------------
    handleModalOpen() {
        // Open the modal dialog
        this.isModalOpen = true;

    }
    handleModalClose() {
        // Close the modal dialog
        this.isModalOpen = false;
        this.folderNameInput = '';
    }
    handleFolderNameChange(event) {
        // Update the folderNameInput property with the input value
        this.folderNameInput = event.target.value;
    }

    handleClick() {

        if (!this.folderParentId || !this.folderNameInput) {
            // Handle validation if needed (e.g., show an error toast)
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Please provide an Folder name.',
                    variant: 'error'
                })
            );
            return;
        }

        addFolder({ parentId: this.folderParentId, folderName: this.folderNameInput })
            .then(result => {
                if (result === 'Folder added successfully') {
                    this.getfolderlist(this.folderParentId);
                    this.showToast('Success', result, 'success');
                }
                else {
                    this.showToast('Error', result, 'error');
                }
            })
            .catch(error => {
                // Handle error
                this.showToast('Error', error.body.message, 'error');
            });
        this.isModalOpen = false;
        this.folderNameInput = '';

        const event = new CustomEvent('recordinserted');
        setTimeout(() => {
            this.templeteVisibleFunction();
            this.dispatchEvent(event);
        }, 1000);

    }
    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
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

    getUploadedFiles(folderid) {
        this.dataTable = []; // Clear existing data

        return getAWSFiles({
            parentId: folderid,
            foldertype: this.folderType
        })
            .then(data => {
                this.dataTable = data.map(record => ({
                    ...record,
                    File_sizes__c: this.formatFileSize(parseInt(record.File_sizes__c, 10)),
                    CreatedDate: new Date(record.CreatedDate).toLocaleDateString()
                }));

                this.processFileTypes(); // Format file types
                this.fileCheck(); // Check if files/folders exist

                return this.dataTable;
            })
            .catch(error => {
                this.handleShowToastMsgMethod('Error', 'Failed to retrieve files', 'error');
                throw error;
            });
    }

    // Add this method to separate the file type formatting logic
    processFileTypes() {
        this.dataTable = this.dataTable.map((file) => {
            let typeIcon = 'doctype:attachment';

            if (file.File_Type__c === 'image/jpeg' || file.File_Type__c === 'image/png') {
                typeIcon = 'doctype:image';
            } else if (file.File_Type__c === 'application/pdf') {
                typeIcon = 'doctype:pdf';
            } else if (file.File_Type__c === 'text/plain') {
                typeIcon = 'doctype:txt';
            } else if (file.File_Type__c === 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' || file.File_Type__c === 'text/csv') {
                typeIcon = 'doctype:gsheet';
            } else if (file.File_Type__c === 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' || file.File_Type__c === 'application/msword') {
                typeIcon = 'doctype:word';
            } else if (file.File_Type__c === 'application/x-zip-compressed') {
                typeIcon = 'doctype:zip';
            } else if (file.File_Type__c === 'application/vnd.ms-powerpoint' || file.File_Type__c === 'application/vnd.openxmlformats-officedocument.presentationml.presentation') {
                typeIcon = 'doctype:ppt';
            }

            return {
                ...file,
                File_Type__c: typeIcon
            };
        });
    }

    // ------------------- Templete refresh Action-------------------------
    templeteVisibleFunction() {
        setTimeout(() => {

            if (this.showFile === false) {
                this.showFile = true;
            } else {
                this.showFile = false;
                this.showFile = true;
            }

        }, 1000);
    }

    callParentMethod() {

        const event = new CustomEvent('callparentmethod');


        this.dispatchEvent(event);
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

        if (actionName === 'Delete') {
            this.handleConfirmClick(row);
        }

        if (actionName === 'Copy URL') {
            this.copyTextToClipboard(row);
        }

    }
    // Method - Logic to confirm click
    async handleConfirmClick(row) {
        try {
            const result = await LightningConfirm.open({
                message: "Do you want to delete the selected " + this.fieldName + " file ?",
                variant: "default",
                label: "Delete a file"
            });

            if (!result) {
                return; // User canceled, exit early
            }

            // Check access permissions
            const accessGranted = await deleteAcess({
                fileId: row.Id,
                objectname: 'file'
            }).catch(err => {
                return false;
            });

            if (!accessGranted) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error !',
                    message: 'The User does not have delete permission for this File ',
                    variant: 'error'
                }));
                return; // No permission, exit early
            }

            // Delete the file
            await this.handleFileDeleteMethod(row);

            // After successful deletion, refresh the data
            this.handleShowToastMsgMethod('Deleted ' + this.fieldName, ' Deleted Successfully', 'success');

            // Signal to parent component
            this.dispatchEvent(new CustomEvent('sendtoparent', {
                detail: { folderParentId: this.folderParentId }
            }));

            // Force data refresh
            this.dataTable = [];
            await this.fetchExistingFileNamesMethod(this.folderParentId);
            await this.getUploadedFiles(this.folderParentId);
            this.templeteVisibleFunction();

        } catch (error) {
            this.handleShowToastMsgMethod('Error', 'Failed to delete file. Please try again.', 'error');
        }
    }
    // Method - Logic to confirm click
    async handleConfirmfolderClick(foldername, files, folders) {
        const result = await LightningConfirm.open({
            message: "Do you want to delete the selected " + foldername + " Folder ?",
            variant: "default",
            label: "Delete a Folder"
        });
        if (result) {

            if (files.length != 0) {
                var promises = files.map(row => {
                    return this.handleFileDeleteMethod(row);
                });

                Promise.all(promises)
                    .then(results => {
                        this.deletefolder(folders)
                            .then((folderflag) => {
                                if (folderflag === true) {
                                    this.handleShowToastMsgMethod('Deleted ' + foldername, 'Deleted Successfully', 'success');
                                    this.getfolderlist(this.folderParentId);
                                    this.fetchExistingFileNamesMethod(this.folderParentId);
                                    const customEvent = new CustomEvent('sendtoparent', {
                                        detail: { folderParentId: this.folderParentId }
                                    });
                                    this.dispatchEvent(customEvent);
                                    const deleteevent = new CustomEvent('recordinserted');
                                    this.templeteVisibleFunction();
                                    this.dispatchEvent(deleteevent);

                                } else {
                                }
                            })
                            .catch((error) => {
                            });
                    })
                    .catch(error => {
                    });

            }
            else {
                this.deletefolder(folders)
                    .then((folderflag) => {
                        if (folderflag === true) {
                            this.handleShowToastMsgMethod('Deleted ' + foldername, 'Deleted Successfully', 'success');
                            this.getfolderlist(this.folderParentId);
                            this.fetchExistingFileNamesMethod(this.folderParentId);

                            const deleteevent = new CustomEvent('recordinserted');
                            this.templeteVisibleFunction();
                            this.dispatchEvent(deleteevent);

                        } else {
                        }
                    })
                    .catch((error) => {
                    });

            }


        } else {
        }

    }

    deletefolder(folders) {
        return new Promise((resolve, reject) => {
            apexFolderDelete({ folderlist: folders })
                .then((result) => {
                    resolve(result);

                }).catch((err) => {
                });

        });

    }

    handleFolderDelete(event) {
        const folderId = event.target.getAttribute('data-folder-id');
        const foldername = event.target.getAttribute('data-folder-name');
        // var folderdetails = event.target.value;
        get_files_Folder_for_Del({ folderId: folderId })
            .then((result) => {
                var file = [];
                var folder = [];
                file = result.files;
                folder = result.folders;
                this.handleConfirmfolderClick(foldername, file, folder);
            })
            .catch((err) => {
            });

    }
    // Method - Logic for deleting file
    handleFileDeleteMethod(row) {
        return new Promise((resolve, reject) => {
            try {
                const rowId = row['Id'];
                const tempFileName = row['File_Name__c'];
                const objectKey = row['ObjectKey__c'];

                // Configure AWS
                const AWS = window.AWS;
                AWS.config.update({
                    accessKeyId: this.awsS3MetadataConfMain.awsAccessKeyId,
                    secretAccessKey: this.awsS3MetadataConfMain.awsSecretAccessKey
                });

                this.s3 = new AWS.S3({
                    apiVersion: '2012-10-17',
                    region: 'us-west-2'
                });

                const params = {
                    Bucket: this.bucketname,
                    Key: objectKey
                };

                // Delete from S3
                this.s3.deleteObject(params, (err, data) => {
                    if (err) {
                        reject(err);
                        return;
                    }

                    // Now delete from Salesforce
                    deleteCallout({ recordId: rowId })
                        .then(result => {
                            resolve(true);
                        })
                        .catch(error => {
                            reject(error);
                        });
                });
            } catch (error) {
                reject(error);
            }
        });
    }

    // Method - Logic close the method
    handleCloseModal() {
        this.showModal = false;
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

    async parentFolderCheck() {
        try {
            const result = await getRootParent();

            this.folderIds = result.map(folder => folder.Id);

            if (this.folderIds.includes(this.folderParentId)) {
                this.parentTemp = true;
                // this.fileMessage ='No Folders Found ...';                
            }
            else {
                this.parentTemp = false;
            }
        } catch (error) {
        }
    }

    showdelete = false;
    Accesstype;
    getfolderlist(folderid) {
        getfolderbelowparent({
            folderId: folderid,
            foldertype: this.folderType
        })
            .then((result) => {
                //this.type = result.Accesstype;
                this.Accesstype = result.Accesstype;
                if (result.Accesstype == 'private') {
                    this.showShare = true;
                    this.showdelete = true;
                }
                else if (result.Accesstype == 'public') {
                    this.showShare = false;
                    this.showdelete = true;
                }
                else {
                    this.showShare = false;
                    this.showdelete = false;
                }
                result.folder = result.folder.map(record => ({
                    ...record,
                    CreatedDate: new Date(record.CreatedDate).toLocaleDateString()
                }));
                if (result.folder.length > 0) {
                    this.showFile = true;
                    this.isfolderList = true;
                } else {
                    this.noFile = true;
                    this.isfolderList = false;
                }
                this.folderlist = [...result.folder];

                // Store ids of folders with Type__c equal to 'Private'
                // const privateFolderIds = this.folderlist
                //     .filter(folder => folder.Type__c === 'private')
                //     .map(folder => folder.Id);
                // if (privateFolderIds.length > 0) {
                // this.showShare = true;
                // }
            }).catch((err) => {
            });
    }


    folderclick(event) {
        this.folderParentId = event.target.dataset.id;
        this.folderType = event.target.dataset.type;
        this.parentTemp = false;
        this.isfolderList = false;
        this.getfolderlist(this.folderParentId);
        this.getUploadedFiles(this.folderParentId);
        this.fetchExistingFileNamesMethod(this.folderParentId);
        this.handleFetchRecordData();
        this.fileCheck();
    }

    fileCheck() {

        if ((!this.dataTable || this.dataTable.length === 0) && (!this.folderlist || this.folderlist.length === 0)) {
            this.noFile = true;
            this.showFile = false;
        } else {
            this.noFile = false;
            this.showFile = true;
        }

    }
    /*
        handleBack() {
    
            getBackToParent({ parentId: this.folderParentId })
                .then((result) => {
    
                    this.folderParentId = result.Folder__r.Id;
                    this.getfolderlist(this.folderParentId);
                    this.getUploadedFiles(this.folderParentId);
                    this.fetchExistingFileNamesMethod(this.folderParentId);
                    this.fileCheck();
                    this.parentFolderCheck();
                })
                .catch(error => {
                });
    
    
        }
    */

    handleBack() {

        getBackToParent({ parentId: this.folderParentId })
            .then((result) => {
                const parentFolder = result.Folder__r;

                // If we're in Shared view and parent is Private, stop at shared root
                if (this.folderViewType === 'shared') {
                    this.folderParentId = this.sharedRootId;
                } else {
                    this.folderParentId = parentFolder.Id;
                    try {
                        this.dispatchEvent(new CustomEvent('backevent', {
                            detail: { folderParentId: this.folderParentId }
                        }));
                    }
                    catch (err) {

                    }
                }

                this.getfolderlist(this.folderParentId);
                this.getUploadedFiles(this.folderParentId);
                this.fetchExistingFileNamesMethod(this.folderParentId);
                this.fileCheck();
                this.parentFolderCheck();
            })
            .catch(error => {
            });
    }

    handleFetchRecordData() {
        getFolderName({ recordId: this.folderParentId })
            .then(result => {
                this.currentFolderName = result.Name;
            })
            .catch(error => {
            });
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

    handleShare(event) {
        if (this.deletedaccesslist.length != 0) {
            removeAccess({
                IDs: this.deletedaccesslist,
                Type: this.type
            }).then((result) => {
                if (result == true && this.selectedUser != null && this.selectedAccess != null) {
                    this.handleFolderShare();
                } else if (result == true && (this.selectedUser == null || this.selectedAccess == null)) {
                    this.handleShowToastMsgMethod('Sucessfully !!!', 'Access Removed successfully.', 'success');
                    this.cancelPopup();
                }
                else {
                }

            }).catch((err) => {
            });
        } else if (this.selectedUser != null && this.selectedAccess != null) {
            this.handleFolderShare();
        } else {
            this.cancelPopup();
        }
    }

    async handleFolderShare() {

        if (this.type == 'folder') {
            var confirm = await LightningConfirm.open({
                message: "Files and Folders below this Folder also Shared.",
                variant: "default",
                label: "Do you want to share the Folder!"
            });
            if (confirm) {
                updateFolderOwner({ folderId: this.folderId, newOwnerId: this.selectedUser, AccessLevel: this.selectedAccess })
                    .then(result => {
                        this.handleShowToastMsgMethod('Shared Sucessfully !!!', 'Folder Sharing successfully.', 'success');
                        this.cancelPopup();
                    })
                    .catch(error => {
                    });
            } else {
                this.cancelPopup();
            }
        }
        else if (this.type == 'file') {
            updateFileOwner({ fileId: this.fileId, newOwnersId: this.selectedUser, AccessLevel: this.selectedAccess })
                .then(result => {

                    this.handleShowToastMsgMethod('Shared Sucessfully !!!', 'File Sharing successfully.', 'success');
                    this.cancelPopup();
                })
                .catch(error => {
                });
        }
        else {
            this.cancelPopup();
        }

    }

    forceRefresh() {

        Promise.all([
            this.getUploadedFiles(this.folderParentId),
            this.getfolderlist(this.folderParentId)
        ])
            .then(() => {
                this.fileCheck();
                this.templeteVisibleFunction();
            })
            .catch(error => {
            });
    }
}