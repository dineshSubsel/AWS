import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { loadScript } from 'lightning/platformResourceLoader';
import getFolders from '@salesforce/apex/UploadedFileController.getFolders';
import getFolderById from '@salesforce/apex/UploadedFileController.getFolderById';
import insertFolder from '@salesforce/apex/UploadedFileController.insertFolder';
import deleteFolder from '@salesforce/apex/UploadedFileController.deleteFolder';
import deleteAllFolders from '@salesforce/apex/UploadedFileController.deleteAllFolders';
import getAWSConfiguration from '@salesforce/apex/AWSFileUploadHandlingController.getAWSConfiguration';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getFolderFormConfig from '@salesforce/apex/UploadedFileController.getFolderFormConfig';
import AWS_SDK from '@salesforce/resourceUrl/AWSSDK';

export default class RelatedListFolder extends LightningElement {
    @track files = [];
    @track visibleFiles = [];
    @track showAll = false;
    @track error;
    @track showModal = false;

    @api recordId;
    @api objectApiName;

    // AWS related properties
    @track awsS3MetadataConfMain = {};
    @track s3;
    @track bucketname;
    @track baseurl;
    @track isAwsSdkInitialized = false;
    folderObjectApiName;
nameField;
parentFolderField;

    @wire(CurrentPageReference)
    currentPageReference;

    get currentRecordId() {
        if (this.recordId) return this.recordId;
        const url = window.location.href;
        const match = url.match(/\/([a-zA-Z0-9]{15,18})(?:\/|$)/);
        if (match) return match[1];
        return new URLSearchParams(window.location.search).get('recordId');
    }

    get currentObjectApiName() {
        return this.objectApiName || this.currentPageReference?.attributes?.objectApiName;
    }

    get isDeleteAllDisabled() {
        return this.files.length === 0;
    }

    get toggleViewLabel() {
        return this.showAll ? 'View Less' : 'View All';
    }


    connectedCallback() {
 this.loadFolderFormConfig();
    if (this.currentRecordId && this.currentObjectApiName) {
        this.loadAWSConfiguration();
        this.loadFolders();
    }
    }
loadFolderFormConfig() {
    getFolderFormConfig()
        .then(result => {
            this.folderObjectApiName = result.objectApiName;
            this.nameField = result.nameField;
            this.parentFolderField = result.parentFolderField;

        })
        .catch(error => {

            this.handleShowToastMsgMethod(
                "Error",
                error.message,
                "error"
            );

        });
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
                    s3RegionName: result.s3RegionName
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
            this.showToast('Error', 'Failed to load AWS configuration: ' + error.body?.message, 'error');
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
   loadFolders() {
    if (!this.currentRecordId) return;
    getFolders({ recordId: this.currentRecordId })
        .then(result => {
            this.files = result.map(file => ({
                Id: file.folderId,
                Name: file.folderName,
                folderLink: `/lightning/r/${file.objectApiName}/${file.folderId}/view`
            }));
            this.updateVisibleFiles();
        })
        .catch(error => {
            this.files = [];
            this.visibleFiles = [];
        });
}
    updateVisibleFiles() {
        this.visibleFiles = this.showAll ? this.files : this.files.slice(0, 5);
    }

    handleToggleView() {
        this.showAll = !this.showAll;
        this.updateVisibleFiles();
    }

    handleUpload() {
        this.showModal = true;
    }

    closeModal() {
        this.showModal = false;
    }

   handleFormSubmit(event) {
    event.preventDefault();
    const fields = event.detail.fields;
    const name = fields[this.nameField];
    const parentId = fields[this.parentFolderField];
    if (!this.currentRecordId || !this.currentObjectApiName) {
        this.showToast('Error', 'Missing page context. Please refresh the page.', 'error');
        return;
    }
    if (!this.isAwsSdkInitialized) {
        this.showToast('Error', 'AWS SDK not initialized. Please refresh the page.', 'error');
        return;
    }
    const insertAndCreateAWSFolder = (folderType = null) => {
        insertFolder({
            name: name,
            parentFolderId: parentId || null,
            parentObjectApiName: this.currentObjectApiName,
            parentRecordId: this.currentRecordId
        })
        .then((salesforceFolder) => {
            this.createAWSFolder(salesforceFolder, name, parentId)
                .then(() => {
                    this.showToast(
                        'Success',
                        `Folder "${name}" created successfully in both Salesforce and AWS`,
                        'success'
                    );
                    this.closeModal();
                    this.loadFolders();

                })
                .catch(awsError => {
                    this.showToast(
                        'Warning',
                        'Salesforce folder created but AWS folder creation failed: ' + awsError.message,
                        'warning'
                    );
                    this.closeModal();
                    this.loadFolders();

                });

        })
        .catch(error => {
            this.showToast('Error', 'Failed to create Salesforce folder', 'error');

        });
    };

    if (parentId) {

        getFolderById({ folderId: parentId })
            .then(parentFolder => insertAndCreateAWSFolder(parentFolder.type))
            .catch(error => {
                this.showToast(
                    'Error',
                    'Failed to fetch parent folder type',
                    'error'
                );
            });

    } else {
        insertAndCreateAWSFolder();
    }
}

    // Create AWS S3 folder
    createAWSFolder(salesforceFolder, folderName, parentFolderId = null) {
        return new Promise((resolve, reject) => {
            try {
                if (!this.s3 || !this.isAwsSdkInitialized) {
                    reject(new Error('AWS SDK not initialized'));
                    return;
                }
                const folderPath = this.generateAWSFolderPath(folderName, parentFolderId);
                const params = {
                    Bucket: this.bucketname,
                    Key: folderPath,
                    Body: '',
                    ContentType: 'application/x-directory',
                    Metadata: {
                        'salesforce-folder-id': salesforceFolder.Id,
                        'parent-object': this.currentObjectApiName,
                        'parent-record-id': this.currentRecordId,
                        'created-date': new Date().toISOString()
                    }
                };

                this.s3.putObject(params, (err, data) => {
                    if (err) {
                        reject(err);
                    } else {
                        this.updateSalesforceFolderWithAWSPath(salesforceFolder.Id, folderPath)
                            .then(() => {
                                resolve(data);
                            })
                            .catch(updateError => {
                                resolve(data);
                            });
                    }
                });

            } catch (error) {
                reject(error);
            }
        });
    }

    // Generate AWS folder path
    generateAWSFolderPath(folderName, parentFolderId = null) {
        let basePath = `${this.currentObjectApiName}/${this.currentRecordId}/`;
        if (parentFolderId) {
            const parentFolderPath = this.getParentFolderPath(parentFolderId);
            return `${basePath}${parentFolderPath}${folderName.replace(/\s+/g, "_").toLowerCase()}/`;
        }
        return `${basePath}${folderName.replace(/\s+/g, "_").toLowerCase()}/`;
    }
    getParentFolderPath(parentFolderId) {
    const parentFolder = this.files.find(
        folder => folder.folderId === parentFolderId
    );
    if (parentFolder && parentFolder.awsFolderPath) {
        return parentFolder.awsFolderPath.replace(
            new RegExp(`^${this.currentObjectApiName}/${this.currentRecordId}/`)
        , '');
    } else if (parentFolder) {
        return `${parentFolder.folderName.replace(/\s+/g, "_").toLowerCase()}/`;
    }
    return '';
}

    updateSalesforceFolderWithAWSPath(folderId, awsFolderPath) {
        return new Promise((resolve, reject) => {
            resolve();
        });
    }

    handleSaveSuccess(event) {
        event.preventDefault();

        const fields = event.detail.fields;
        const name = fields.Name;
        this.showToast('Success', 'Folder created successfully' + name, 'success');
        this.closeModal();
        this.loadFolders();
    }

    handleSaveError() {
        this.showToast('Error', 'Please fill all required fields.', 'error');
    }

    handleMenuSelect(event) {
        const selectedValue = event.detail.value;
        if (selectedValue === 'deleteAll') {
            this.handleDeleteAllFolders();
        }
    }

    handleFileMenuSelect(event) {
        const selectedValue = event.detail.value;
        const fileId = event.target.dataset.fileId;

        if (selectedValue === 'delete') {
            this.handleDeleteFile(fileId);
        }
    }

    handleDeleteFile(fileId) {
        const folderToDelete = this.files.find(folder => folder.Id === fileId);

        if (!folderToDelete) {
            this.showToast('Error', 'Folder not found', 'error');
            return;
        }
        this.deleteAWSFolder(folderToDelete)
            .then(() => {
                return deleteFolder({ folderId: fileId });
            })
            .then(() => {
                this.showToast('Success', 'Folder deleted from both AWS and Salesforce', 'success');
                this.loadFolders();
            })
            .catch(error => {
                deleteFolder({ folderId: fileId })
                    .then(() => {
                        this.showToast('Warning', 'Salesforce folder deleted, but AWS deletion may have failed', 'warning');
                        this.loadFolders();
                    })
                    .catch(sfError => {
                        this.showToast('Error', 'Failed to delete folder', 'error');
                    });
            });
    }

    // Delete AWS folder
    deleteAWSFolder(folder) {
        return new Promise((resolve, reject) => {
            try {
                if (!this.s3 || !this.isAwsSdkInitialized) {
                    resolve(); // Don't fail the operation
                    return;
                }
                const folderPath = this.generateAWSFolderPath(folder.Name, folder.folderId);
                const listParams = {
                    Bucket: this.bucketname,
                    Prefix: folderPath
                };

                this.s3.listObjectsV2(listParams, (err, data) => {
                    if (err) {
                        reject(err);
                        return;
                    }

                    if (data.Contents.length === 0) {
                        resolve();
                        return;
                    }
                    const deleteObjects = data.Contents.map(obj => ({ Key: obj.Key }));

                    const deleteParams = {
                        Bucket: this.bucketname,
                        Delete: {
                            Objects: deleteObjects
                        }
                    };

                    this.s3.deleteObjects(deleteParams, (deleteErr, deleteData) => {
                        if (deleteErr) {
                            reject(deleteErr);
                        } else {
                            resolve(deleteData);
                        }
                    });
                });

            } catch (error) {
                reject(error);
            }
        });
    }

    handleDeleteAllFolders() {
        if (!this.isAwsSdkInitialized) {
            deleteAllFolders({ recordId: this.currentRecordId })
                .then(() => {
                    this.showToast('Success', 'All Salesforce folders deleted', 'success');
                    this.loadFolders();
                })
                .catch(error => {
                    this.showToast('Error', 'Failed to delete all folders', 'error');
                });
            return;
        }
        Promise.all(this.files.map(folder => this.deleteAWSFolder(folder)))
            .then(() => {
                return deleteAllFolders({ recordId: this.currentRecordId });
            })
            .then(() => {
                this.showToast('Success', 'All folders deleted from both AWS and Salesforce', 'success');
                this.loadFolders();
            })
            .catch(error => {
                this.showToast('Error', 'Failed to delete all folders', 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}