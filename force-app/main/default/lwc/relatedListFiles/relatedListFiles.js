import { LightningElement, api, track, wire } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getFilesByParentId from '@salesforce/apex/UploadedFileController.getFilesByParentId';
import getAWSConfiguration from '@salesforce/apex/AWSFileUploadHandlingController.getAWSConfiguration';
import fetchExistingFileNames from '@salesforce/apex/AWSFileUploadHandlingController.fetchExistingFileNames';
import recordInsert from '@salesforce/apex/UploadedFileController.recordInsert';
import deleteFile from '@salesforce/apex/UploadedFileController.deleteFile';
import getParentRecordName from '@salesforce/apex/UploadedFileController.getParentRecordName';
import AWS_SDK from '@salesforce/resourceUrl/AWSSDK';

export default class RelatedListFiles extends LightningElement {
    @api recordId;
    @api objectApiName;

    @track allFiles = [];
    @track files = [];
    @track draggedFiles = [];
    @track isViewAll = false;
    @track showUploadPopup = false;
    @track uploadProgress = 0;
    @track isUploadDisabled = true;
    @track showDeleteAllConfirmation = false;
    @track isDeletingAll = false;

    // Individual delete properties
    @track showDeleteConfirmation = false;
    @track selectedFileForDeletion = null;
    @track isDeletingFile = false;

    // AWS related properties
    @track awsS3MetadataConfMain = {};
    @track s3;
    @track bucketname;
    @track baseurl;
    @track isAwsSdkInitialized = false;
    @track existingFileNamesList = [];
    @track parentRecordName = '';

    // Upload related properties
    selectedFilesToUpload;
    fileName;
    filecount = 0;
    actualsize = 0;
    uploadloaded = false;

    // Modal properties
    @track showDownloadModal = false;
    @track selectedFile = {};
    @track downloadProgress = 0;
    @track downloadInProgress = false;
    @track downloadCompleted = false;
    @track downloadStatus = 'Ready to download';
    selectedFiles = [];
    @track fileUploading = false;

    // Add these properties to your component
    @track showPreviewModal = false;
    @track selectedFileForPreview = null;
    @track previewUrl = '';
    @track previewError = false;
    @track previewLoading = true;

    get viewLabel() {
        return this.isViewAll ? 'View Less' : 'View All';
    }

    get downloadButtonLabel() {
        return this.downloadInProgress ? 'Downloading...' :
            this.downloadCompleted ? 'Downloaded' : 'Download';
    }

    get progressBarStyle() {
        return `width: ${this.downloadProgress}%;`;
    }

    get isDeleteAllDisabled() {
        return this.allFiles.length === 0 || this.isDeletingAll;
    }

    get uploadAreaClass() {
        return 'upload-area slds-align_absolute-center slds-p-around_large slds-border_dashed';
    }

    get fileSize() {
        return this.draggedFiles.length > 0 ? this.draggedFiles[0].size : '';
    }
    get getUploadProgress() {
        return this.draggedFiles;
    }

    get filesExist() {
    return this.files && this.files.length > 0;
}


    async loadParentRecordName() {
        if (this.recordId && this.objectApiName) {
            try {
                const result = await getParentRecordName({
                    recordId: this.recordId,
                    objectApiName: this.objectApiName
                });
                this.parentRecordName = result;
            } catch (error) {
            }
        }
    }

    connectedCallback() {
       
        this.files = this.allFiles.slice(0, 5);
        if (this.recordId) {
            this.loadAWSConfiguration();
            this.loadFiles();
            this.fetchExistingFileNamesMethod();
            this.loadParentRecordName();
        } else {
        }
    }

    renderedCallback() {
        if (this.isAwsSdkInitialized) {
            return;
        }
        Promise.all([loadScript(this, AWS_SDK)])
            .then(() => {
                if (this.awsS3MetadataConfMain && Object.keys(this.awsS3MetadataConfMain).length > 0) {
                    this.initializeAwsSdk(this.awsS3MetadataConfMain);
                }
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load AWS SDK', 'error');
            });
    }

  loadAWSConfiguration() {
    getAWSConfiguration()
        .then(result => {

            if (result) {

                let awsS3MetadataConf = {
                    s3bucketName: result.s3BucketName,
                    awsAccessKeyId: result.awsAccessKeyId,
                    awsSecretAccessKey: result.awsSecretAccessKey,
                    s3RegionName: result.s3RegionName,
                    apiVersion: result.apiVersion,
                    signatureVersion: result.signatureVersion
                };

                this.awsS3MetadataConfMain = awsS3MetadataConf;
                this.bucketname = result.s3BucketName;
                this.baseurl =
                    'https://' +
                    result.s3BucketName +
                    '.s3.' +
                    result.s3RegionName +
                    '.amazonaws.com/';
                if (window.AWS && this.awsS3MetadataConfMain) {
                    this.initializeAwsSdk(this.awsS3MetadataConfMain);
                }

            } else {
                this.showToast('Error', 'AWS Configuration not found', 'error');
            }
        })
        .catch(error => {
            this.showToast(
                'Error',
                'Failed to load AWS configuration: ' + (error.body?.message || error.message),
                'error'
            );
        });
}

    // Initialize AWS SDK
    initializeAwsSdk(confData) {
        const AWS = window.AWS;
        AWS.config.update({
            accessKeyId: confData.awsAccessKeyId,
            secretAccessKey: confData.awsSecretAccessKey
        });

        AWS.config.region = confData.s3RegionName;

        this.s3 = new AWS.S3({
             apiVersion: confData.apiVersion,
            signatureVersion: confData.signatureVersion,
            params: {
                Bucket: confData.s3bucketName
            }
        });
        this.isAwsSdkInitialized = true;
    }

 loadFiles() {
    getFilesByParentId({ parentId: this.recordId })
        .then((data) => {
            const seenFileNames = new Set();
            this.allFiles = data
                .filter(file => {
                    const fileName = file.fileName || ''; 
                    if (!seenFileNames.has(fileName)) {
                        seenFileNames.add(fileName);
                        return true;
                    }
                    return false;
                })
                .map(file => {
                    return {
                        ...file,
                        fileLink: `/lightning/r/${file.id}/view`,
                        createdByName: file.uploadedBy, 
                        createdDateFormatted: file.createdDate
                            ? new Date(file.createdDate).toLocaleDateString()
                            : ''
                    };
                })
                .sort((a, b) => {
                    const nameA = (a.fileName || '').toLowerCase(); 
                    const nameB = (b.fileName || '').toLowerCase();
                    return nameA.localeCompare(nameB);
                });

            this.files = this.allFiles.slice(0, 5);
        })
        .catch(error => {
            this.showToast('Error', 'Failed to load files', 'error');
        });
}

    // Fetch existing file names to check for duplicates

    fetchExistingFileNamesMethod() {
    return fetchExistingFileNames({ parentId: this.recordId })
        .then((result) => {
            this.existingFileNamesList = result.map(item => item.fileName);
        })
        .catch(error => {
            this.showToast('Error', error.message, 'error');
        });
}
  
    // Handle individual file actions menu
    handleFileMenuSelect(event) {
        const selectedValue = event.detail.value;
        const fileId = event.target.dataset.fileId;
        const selectedFile = this.allFiles.find(file => file.Id === fileId);
        if (!selectedFile) {
            return;
        }

        if (selectedValue === 'preview') {
            this.openPreviewModal(selectedFile);
        } else if (selectedValue === 'download') {
            this.openDownloadModal(selectedFile);
        } else if (selectedValue === 'delete') {
            this.selectedFileForDeletion = selectedFile;
            this.showDeleteConfirmation = true;
        }
    }

    // Download functionality
    openDownloadModal(file) {
        this.formattedFileSize = this.formatFileSize(file.fileSize);
        this.selectedFile = file;
        this.showDownloadModal = true;
        this.startDownload();
        this.resetDownloadState();
    }

    closeDownloadModal() {
        this.showDownloadModal = false;
        this.resetDownloadState();
    }

    resetDownloadState() {
        this.downloadProgress = 0;
        this.downloadInProgress = false;
        this.downloadCompleted = false;
        this.downloadStatus = 'Ready to download';
    }

    startDownload() {
        this.downloadInProgress = true;
        this.downloadCompleted = false;
        this.downloadStatus = 'Downloading...';
        this.generateDownloadUrl();
    }

   generateDownloadUrl() {
    const currentFileName = this.selectedFile?.fileName || 'Unknown file'; 

    try {
        if (!this.s3 || !this.isAwsSdkInitialized) {
            throw new Error('AWS SDK not initialized');
        }
        let objectKey = this.selectedFile?.objectKey;
        if (!objectKey && this.selectedFile?.fileName) {
            objectKey = this.generateObjectKey(this.selectedFile.fileName);
        }

        if (!objectKey) {
            throw new Error('Unable to determine object key for file: ' + currentFileName);
        }
        const downloadUrl = this.s3.getSignedUrl('getObject', {
            Bucket: this.bucketname,
            Key: objectKey,
            Expires: 300 
        });
        this.simulateDownloadProgress(downloadUrl);

    } catch (error) {
        this.showToast('Error', `[${currentFileName}] Failed to generate download URL: ${error.message}`, 'error');
        this.downloadInProgress = false;
        this.downloadStatus = 'Download failed';
    }
}



simulateDownloadProgress(downloadUrl) {
    let progress = 0;
    const interval = setInterval(() => {
        progress += Math.random() * 20;
        if (progress >= 100) {
            progress = 100;
            this.downloadProgress = progress;
            this.downloadCompleted = true;
            this.downloadInProgress = false;
            this.downloadStatus = 'Completed';
            clearInterval(interval);
            this.performDownload(downloadUrl)
                .then(() => {
                    
                    setTimeout(() => {
                        this.closeDownloadModal();
                    }, 500);
                })
                .catch(error => {
                });
        } else {
            this.downloadProgress = Math.floor(progress);
        }
    }, 150);
}
    async performDownload(downloadUrl) {
    const currentFileName = this.selectedFile?.fileName || 'download';
        try {
            const response = await fetch(downloadUrl);
            const blob = await response.blob();

            const url = window.URL.createObjectURL(blob);
            const link = document.createElement('a');
            link.href = url;
            link.download = currentFileName;
            link.click();

            window.URL.revokeObjectURL(url);

            this.showToast('Success', ` download completed successfully`, 'success');

        } catch (error) {
            this.showToast('Error', `[${currentFileName}] Download failed: ${error.message}`, 'error');
            this.downloadInProgress = false;
            this.downloadCompleted = false;
            this.downloadStatus = 'Download failed';
        }
    }

    // Menu handlers
    handleMenuSelect(event) {
        const selected = event.detail.value;
        if (selected === 'deleteAll') {
            this.handleDeleteAll();
        }
    }

 handleViewToggle() {
        this.isViewAll = !this.isViewAll;
        this.files = this.isViewAll ? this.allFiles : this.allFiles.slice(0, 5);
    }

     handleUpload() {
    this.fetchExistingFileNamesMethod()
        .then(() => {
            this.showUploadPopup = true;
            this.fileUploading = false;
        })
        .catch(error => {
            this.showToast('Error', 'Could not verify existing files', 'error');
        });
}

    closeUploadPopup() {
        this.showUploadPopup = false;
        this.draggedFiles = [];
        this.selectedFiles = [];
        this.isUploadDisabled = true;
    }

    // Individual file delete functionality
    handleDeleteFile(event) {
        const fileId = event.target.dataset.fileId;
        const file = this.allFiles.find(f => f.Id === fileId);
        if (file) {
            this.selectedFileForDeletion = file;
            this.showDeleteConfirmation = true;
        }
    }

    closeDeleteConfirmation() {
        this.showDeleteConfirmation = false;
        this.selectedFileForDeletion = null;
    }

   confirmDeleteFile() {
    const fileToDelete = this.selectedFileForDeletion;
    if (!fileToDelete) {
        this.showToast('Error', 'No file selected for deletion', 'error');
        return;
    }

    if (!this.awsS3MetadataConfMain?.awsAccessKeyId) {
        this.showToast('Error', 'AWS configuration not loaded', 'error');
        return;
    }

    const currentFileName = fileToDelete?.fileName || 'Unknown file';
    this.isDeletingFile = true;
    this.handleFileDeleteMethod(fileToDelete)
        .then(() => {
            this.showToast('Success', `[${currentFileName}] File deleted successfully`, 'success');
            this.loadFiles();
            const index = this.existingFileNamesList.indexOf(currentFileName);
            if (index > -1) {
                this.existingFileNamesList.splice(index, 1);
            }

            this.closeDeleteConfirmation();
        })
        .catch(error => {
            this.showToast('Error', `[${currentFileName}] Failed to delete file: ${error.message}`, 'error');
        })
        .finally(() => {
            this.isDeletingFile = false;
        });
}

    // Helper method to get object key from file record
   getObjectKeyFromFile(file) {
    return file?.objectKey || null;
}

    // Generate object key if not present
    generateObjectKey(fileName) {
        if (!fileName || !this.objectApiName || !this.recordId) {
            return null;
        }

        let objName = this.objectApiName + '/' + this.recordId;
        let objKey = objName + '/' + fileName.replace(/\s+/g, "_").toLowerCase();
        return objKey;
    }

    // Enhanced file deletion method
    handleFileDeleteMethod(row) {
    return new Promise((resolve, reject) => {
        try {
            const rowId = row.id; 
            const tempFileName = row.fileName || 'Unknown file'; 
            let objectKey = row.objectKey;
            if (!objectKey && tempFileName) {
                objectKey = this.generateObjectKey(tempFileName);
            }
            
            if (!objectKey) {
                deleteFile({ fileId: rowId })
                    .then(() => resolve(true))
                    .catch(error => reject(error));

                return;
            }
            const params = {
                Bucket: this.bucketname,
                Key: objectKey
            };
            this.s3.deleteObject(params, (err) => {

                if (err) {
                    if (err.code === 'NoSuchKey' || err.statusCode === 404) {
                    } else {
                    }
                } else {
                }
                deleteFile({ fileId: rowId })
                    .then(() => {
                        this.getUploadedFiles(this.folderParentId);
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

    // Delete All functionality
    handleDeleteAll() {
        this.showDeleteAllConfirmation = true;
    }

    closeDeleteAllConfirmation() {
        this.showDeleteAllConfirmation = false;
    }

    confirmDeleteAll() {
        if (!this.awsS3MetadataConfMain || !this.awsS3MetadataConfMain.awsAccessKeyId) {
            this.showToast('Error', 'AWS configuration not loaded', 'error');
            return;
        }

        if (this.allFiles.length === 0) {
            this.showToast('Info', 'No files to delete', 'info');
            this.closeDeleteAllConfirmation();
            return;
        }

        this.isDeletingAll = true;

        this.deleteAllFilesWithMethod()
            .then((results) => {
                const successCount = results.filter(r => r.success).length;
                const failCount = results.filter(r => !r.success).length;

                if (failCount === 0) {
                    this.showToast('Success', `All ${successCount} files deleted successfully`, 'success');
                } else {
                    const failedFiles = results.filter(r => !r.success).map(r => r.file).join(', ');
                    this.showToast('Warning',
                        `${successCount} files deleted successfully, ${failCount} files failed to delete [${failedFiles}]`, 'warning');
                }

                this.loadFiles();
                this.existingFileNamesList = [];
                this.closeDeleteAllConfirmation();
            })
            .catch(error => {
                this.showToast('Error', 'Failed to delete files: ' + error.message, 'error');
            })
            .finally(() => {
                this.isDeletingAll = false;
            });
    }

    async deleteAllFilesWithMethod() {
        const deletePromises = this.allFiles.map(file =>
            this.handleFileDeleteMethod(file)
                .then(() => ({ file: file.fileName, success: true }))
                .catch(error => {
                    return { file: file.fileName, success: false, error: error.message };
                })
        );

        return Promise.all(deletePromises);
    }

    // Drag and drop handlers
    handleDragOver(event) {
        event.preventDefault();
        event.currentTarget.classList.add('drag-over');
    }

    handleDragLeave(event) {
        event.preventDefault();
        event.currentTarget.classList.remove('drag-over');
    }

    handleDrop(event) {
        event.preventDefault();
        event.currentTarget.classList.remove('drag-over');
        const files = Array.from(event.dataTransfer.files);
        this.selectedFiles = [...this.selectedFiles, ...files];
        this.processSelectedFiles(this.selectedFiles);
    }

    openFileDialog() {
        const fileInput = this.template.querySelector('.file-input-hidden');
        fileInput.click();
    }

    handleFileInputChange(event) {
        const files = Array.from(event.target.files);
        this.selectedFiles = [...this.selectedFiles, ...files];
        this.processSelectedFiles(this.selectedFiles);
    }

    
    processSelectedFiles(files) {
    const uniqueFiles = [];
    const seenNames = new Set();
    
    files.forEach(file => {
        if (!seenNames.has(file.name)) {
            seenNames.add(file.name);
            uniqueFiles.push(file);
        } else {
        }
    });
    
    this.draggedFiles = uniqueFiles.map(file => ({
        name: file.name,
        size: this.formatFileSize(file.size),
        file: file,
        progress: 0
            }));
    
    this.isUploadDisabled = this.draggedFiles.length === 0;
}

    removeFile(event) {
        const index = parseInt(event.target.dataset.index);
        this.draggedFiles.splice(index, 1);
        this.selectedFiles.splice(index, 1);

        this.draggedFiles = [...this.draggedFiles];
        this.isUploadDisabled = this.draggedFiles.length === 0;
    }

formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';
    if (!bytes) return ''; 
    
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

   getUploadedFiles(folderid) {
    this.dataTable = [];
    getAWSFiles({
        parentId: folderid,
        foldertype: this.folderType
    })
        .then(data => {
            this.dataTable = data.map(record => ({
                ...record,
                fileSizeFormatted: this.formatFileSize(parseInt(record.fileSize, 10)),
                createdDateFormatted: record.createdDate
                    ? new Date(record.createdDate).toLocaleDateString()
                    : '',
                isDropdownOpen: false
            }));

            this.isdataTable = this.dataTable.length > 0;
            this.dataTable = this.dataTable.map((item) => {
                let newItem = { ...item };
                switch (item.fileType) {
                    case 'image/jpeg':
                    case 'image/png':
                        newItem.fileTypeLabel = 'JPEG';
                        newItem.cssClass = 'file-jpeg';
                        break;
                    case 'application/pdf':
                        newItem.fileTypeLabel = 'PDF';
                        newItem.cssClass = 'file-pdf';
                        break;
                    case 'Folder':
                        newItem.fileTypeLabel = 'Folder';
                        newItem.cssClass = 'file-folder';
                        break;
                    case 'text/plain':
                        newItem.fileTypeLabel = 'TXT';
                        newItem.cssClass = 'file-txt';
                        break;
                    case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
                    case 'text/csv':
                        newItem.fileTypeLabel = 'XLSX';
                        newItem.cssClass = 'file-xlsx';
                        break;
                    case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
                    case 'application/msword':
                        newItem.fileTypeLabel = 'WORD';
                        newItem.cssClass = 'file-word';
                        break;
                    case 'application/x-zip-compressed':
                        newItem.fileTypeLabel = 'ZIP';
                        newItem.cssClass = 'file-zip';
                        break;
                    case 'application/vnd.ms-powerpoint':
                    case 'application/vnd.openxmlformats-officedocument.presentationml.presentation':
                        newItem.fileTypeLabel = 'PPT';
                        newItem.cssClass = 'file-ppt';
                        break;

                    default:
                        newItem.fileTypeLabel = 'OTHER';
                        newItem.cssClass = 'file-dll';
                }
                newItem.fileTypeBoxClass = 'file-type-box ' + newItem.cssClass;
                return newItem;
            });

        })
        .catch(error => {
            this.handleShowToastMsgMethod(
                'Error',
                error.message || 'Failed to load files',
                'error'
            );
        });
}

    proceedWithUpload() {
    this.isUploadDisabled = true;
    this.fileUploading = true;
    if (!this.isAwsSdkInitialized) {
        this.showToast('Error', 'AWS SDK not initialized', 'error');
        return;
    }
    const uploadFileNames = this.draggedFiles.map(file => file.name);
    const uniqueFileNames = new Set(uploadFileNames);
    
    if (uploadFileNames.length !== uniqueFileNames.size) {
        this.showToast('Error', 'Duplicate files detected in your selection', 'error');
        this.fileUploading = false;
        return;
    }
        const duplicates = uploadFileNames.filter(name => 
        this.existingFileNamesList.includes(name)
    );
    
    if (duplicates.length > 0) {
        this.showToast('Error', `These files already exist: ${duplicates.join(', ')}`, 'error');
        this.fileUploading = false;
        return;
    }

    this.actualsize = this.draggedFiles.length;
    this.filecount = 0;

    const promises = [];

    for (let i = 0; i < this.draggedFiles.length; i++) {
        const file = this.draggedFiles[i].file;
        promises.push(this.uploadToAWS(file, i));
        this.existingFileNamesList.push(file.name);
    }

    if (promises.length > 0) {
        this.uploadloaded = true;
        Promise.all(promises)
            .then(() => {
                this.showToast('Success', 'All files uploaded successfully', 'success');
                this.closeUploadPopup();
            })
            .catch(error => {
                this.showToast('Error', 'Failed to upload some files', 'error');
            });
    }
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
                        this.draggedFiles[index].progress = this.uploadProgress;
                        this.draggedFiles[index].style = `width: ${this.uploadProgress}%;`;
                    }
                });

                xhr.onreadystatechange = () => {
                    if (xhr.readyState === 4) {
                        if (xhr.status === 200) {
                            this.trackSuccess(file, objKey);
                            resolve();
                        } else {
                            this.showToast('Error', `[${currentFileName}] Upload failed with status: ${xhr.status}`, 'error');
                            reject('Upload failed');
                        }
                    }
                };

                xhr.onerror = () => {
                    this.showToast('Error', `[${currentFileName}] Upload request failed`, 'error');
                    reject('Upload request failed');
                };

                xhr.send(file);
            } catch (error) {
                this.showToast('Error', `[${currentFileName}] Error creating presigned URL: ${error.message}`, 'error');
                reject(error);
            }
        });
    }
    trackSuccess(file, objKey) {
        const currentFileName = file?.name || 'Unknown file';
        try {
            const presignedGETURL = this.s3.getSignedUrl('getObject', {
                Bucket: this.bucketname,
                Key: objKey,
                Expires: 604800 // URL expires in 7 days
            });

            recordInsert({
                parentObjectApiName: this.objectApiName,
                parentRecordName: this.parentRecordName,
                parentId: this.recordId,
                fileName: file.name,
                fileURL: presignedGETURL,
                filetype: file.type,
                objKey: objKey,
                filesize: file.size,
                folderId: null
            })
                .then(result => {
                    this.fileName = '';
                    this.loadFiles();
                })
                .catch(error => {
                    this.showToast('Error', `[${currentFileName}] Failed to create file record: ${error.message}`, 'error');
                });

            this.filecount++;
            if (this.filecount >= this.actualsize) {
                this.uploadloaded = false;
                this.closeUploadPopup();
                this.fileUploading = false;
            }
        } catch (error) {
            this.showToast('Error', `[${currentFileName}] Error in trackSuccess: ${error.message}`, 'error');
        }
    }

    // Show toast message
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }

    // Simplified openPreviewModal method
    openPreviewModal(file) {
        this.selectedFileForPreview = file;
        this.showPreviewModal = true;
        this.previewError = false;
        this.previewLoading = true;
        this.generatePreviewUrl(file);
    }

   generatePreviewUrl(file) {
    const currentFileName = file?.fileName || 'Unknown file'; 

    try {
        if (!this.s3 || !this.isAwsSdkInitialized) {
            throw new Error('AWS SDK not initialized');
        }
        let objectKey = file.objectKey;
        if (!objectKey && file.fileName) {
            objectKey = this.generateObjectKey(file.fileName);
        }
        if (!objectKey) {
            throw new Error('Unable to determine object key for file: ' + currentFileName);
        }
        const previewUrl = this.s3.getSignedUrl('getObject', {
            Bucket: this.bucketname,
            Key: objectKey,
            Expires: 300
        });
        this.previewUrl = previewUrl;
        this.previewLoading = false;

    } catch (error) {
        this.previewError = true;
        this.previewLoading = false;

        this.showToast(
            'Error',
            'Failed to generate preview URL: ' + error.message,
            'error'
        );
    }
}

    // Method to open file in new tab
    openFileInNewTab() {
        if (this.previewUrl) {
            window.open(this.previewUrl, '_blank');
            this.closePreviewModal();
        }
    }

    // Simplified closePreviewModal method
    closePreviewModal() {
        this.showPreviewModal = false;
        this.selectedFileForPreview = null;
        this.previewUrl = '';
        this.previewError = false;
        this.previewLoading = true;
    }
}