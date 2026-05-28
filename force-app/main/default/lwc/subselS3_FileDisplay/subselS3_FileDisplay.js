import { LightningElement, track, wire, api } from "lwc";
import USER_ID from "@salesforce/user/Id";
import { loadScript } from "lightning/platformResourceLoader";
import getAWSFiles from "@salesforce/apex/AWSFileUploadHandlingController.getAWSFiles";
import deleteAcess from "@salesforce/apex/AWSFileUploadHandlingController.deleteAccess";
import updateUrl from "@salesforce/apex/AWSFileUploadHandlingController.updateUrl";
import AWS_SDK from "@salesforce/resourceUrl/AWSSDK";
import recordInsert from "@salesforce/apex/AWSFileUploadHandlingController.recordInsert";
import updatingAccess from "@salesforce/apex/AWSFileUploadHandlingController.updatingAccess";
import fetchExistingFileNameunderFolder from "@salesforce/apex/AWSFileUploadHandlingController.fetchExistingFileNameunderFolder";
import addFolder from "@salesforce/apex/folderController.addFolder";
import deleteCallout from "@salesforce/apex/AWSFileUploadHandlingController.deleteCallout";
import getfolderbelowparent from "@salesforce/apex/folderController.getFolderList";
import getSharedFolderList from "@salesforce/apex/folderController.getSharedFolderList";
import getRootParent from "@salesforce/apex/folderController.getRootParent";
import get_files_Folder_for_Del from "@salesforce/apex/folderController.getAllFilesAndFoldersInFolder";
import apexFolderDelete from "@salesforce/apex/folderController.deletefolder";
import getBackToParent from "@salesforce/apex/folderController.getBackToParent";
import getFolderName from "@salesforce/apex/folderController.getFolderName";
import getUsers from "@salesforce/apex/AWSFileUploadHandlingController.getUsers";
import removeAccess from "@salesforce/apex/AWSFileUploadHandlingController.removeAccess";
import getssharingdetails from "@salesforce/apex/AWSFileUploadHandlingController.getssharingdetails";
import updateFolderOwner from "@salesforce/apex/AWSFileUploadHandlingController.updateFolderOwner";
import updateFileOwner from "@salesforce/apex/AWSFileUploadHandlingController.updateFileOwner";
import getAWSConfiguration from "@salesforce/apex/AWSFileUploadHandlingController.getAWSConfiguration";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import LightningConfirm from "lightning/confirm";

export default class FileDisplay extends LightningElement {
    // ─── Public API Properties ─────
    @api sharedRootId;
    @api folderViewType;
    @api selectedLabel;
    @api parentRecordNames;
    @api folderType;
    @api type;
    @api recordId;
    @api objectApiName;
    @api folderName;
    @api parentRecordId;
    @api ancestorStack = [];
    @api
    refreshDisplay() {
        this.refreshCompleteUI();
    }
    @api
    get navStack() {
        return this._navStack;
    }
    set navStack(value) {
        this._navStack = value ? [...value] : [];
        this.parentTemp = this._navStack.length === 0;
    }

    // ─── AWS / S3 ────────
    s3;
    isAwsSdkInitialized = false;
    awsS3MetadataConfMain = {};
    bucketname;
    baseurl;

    // ─── UI State ─────────
    showSpinner = false;
    showFile = false;
    noFile = false;
    parentTemp = true;
    isfolderList = false;
    showShare = false;
    showFolder = true;
    showAddFolder;
    showdelete = false;
    isdataTable = false;
    @track isDropdownOpen = false;
    @track isModalOpen = false;
    @track showUploadPopup = false;
    @track showPreviewModal = false;
    isFromClick;
    dataTable = [];
    folderlist = [];
    privateFolderIds = [];
    folderIds = [];
    existingFileNamesList = [];
    currentFolderName;
    folderNameInput = "";
    _navStack = [];
    selectedFilesToUpload;
    @track draggedFiles = [];
    selectedFiles = [];
    @track fileUploading = false;
    isDragOver = false;
    uploadProgress = 0;
    filecount = 0;
    actualsize;
    timeSpan = 5000;
    @track downloadPopup = false;
    @track downloadComplete = false;
    @track progress = 0;
    downloadInProgress = false;
    downloadCompleted = false;
    downloadStatus = "";
    downloadProgress = 0;
    @track fileName = "";
    @track fileSize = "";
    @track createdDate = "";
    fieldName;
    selectedFile;

    @track selectedFileForPreview = null;
    @track previewUrl = "";
    @track previewError = false;
    @track previewLoading = true;

    @track isPopupVisible = false;
    @track selectedUser = "";
    @track userOptions = [];
    @track selectedAccess = "";
    folderId;
    fileId;
    accessLabel;
    Accesstype;
    accessoptions = [
        { label: "Read Only", value: "Read" },
        { label: "Read/Write", value: "Edit" }
    ];
    accessoptionsfortable = [
        { label: "All", value: "All" },
        { label: "Read Only", value: "Read" },
        { label: "Read/Write", value: "Edit" }
    ];
    accesslist = [];
    deletedaccesslist = [];
    accesslistsize = 0;
    showaccesstable = false;

    userId = USER_ID;
    fileInput;
    iconClass;

    @wire(getUsers)
    wiredUsers({ error, data }) {
        if (data) {
            this.userOptions = data.map((user) => ({
                label: user.Name,
                value: user.Id
            }));
        } else if (error) {
        }
    }


    get progressStyle() {
        return `width: ${this.progress}%;`;
    }

    get progressBarClass() {
        return this.downloadComplete ? "progress-bar completed" : "progress-bar";
    }

    get uploadAreaClass() {
        return this.isDragOver ? "upload-area drag-over" : "upload-area";
    }

    get isUploadDisabled() {
        return this.draggedFiles.length === 0 || this.fileUploading;
    }

    get getUploadProgress() {
        return this.draggedFiles;
    }

    get showBackButton() {
        return this.parentTemp === false;
    }

    get isRootFolder() {
    const rootLabels = ['📂 Public Folder', '📂 Private Folder', '📂 Shared with Me'];
    return rootLabels.includes(this.selectedLabel);
}


    connectedCallback() {
        this.showFolder = this.folderType !== "shared";
        this.navigationStack = [];
        this.loadAWSConfiguration();
        this.getUploadedFiles(this.folderParentId);
        this.fetchExistingFileNamesMethod(this.folderParentId);
        this.parentFolderCheck();
        this.getfolderlist(this.folderParentId);
        this.handleFetchRecordData();
        this.iconClass = "icon-shrink";
    }

    renderedCallback() {
        if (!this.fileInput) {
            this.fileInput = this.template.querySelector('input[type="file"]');
            if (this.fileInput) {
                this.fileInput.addEventListener("change", this.handleFileChange.bind(this));
            }
        }

        if (this.isAwsSdkInitialized) return;
        Promise.all([loadScript(this, AWS_SDK)]).catch((error) => {
        });
    }


    loadAWSConfiguration() {
        getAWSConfiguration()
            .then((result) => {
                if (result) {
                    this.awsS3MetadataConfMain = {
                        s3bucketName: result.s3BucketName,
                        awsAccessKeyId: result.awsAccessKeyId,
                        awsSecretAccessKey: result.awsSecretAccessKey,
                        s3RegionName: result.s3RegionName
                    };
                    this.bucketname = result.s3BucketName;
                    this.baseurl =
                        "https://" +
                        result.s3BucketName +
                        ".s3." +
                        result.s3RegionName +
                        ".amazonaws.com/";
                    this.initializeAwsSdk(this.awsS3MetadataConfMain);
                }
            })
            .catch(() => {
                this.handleShowToastMsgMethod(
                    "Configuration Error",
                    "Failed to load AWS configuration",
                    "error"
                );
            });
    }

    initializeAwsSdk(confData) {
        if (!window.AWS) {
            setTimeout(() => this.initializeAwsSdk(confData), 100);
            return;
        }

        try {
            const AWS = window.AWS;

            AWS.config.update({
                accessKeyId: confData.awsAccessKeyId,
                secretAccessKey: confData.awsSecretAccessKey
            });

            AWS.config.region = confData.s3RegionName;

            this.s3 = new AWS.S3({
                apiVersion: confData.apiVersion,
                signatureVersion: confData.signatureVersion,
                params: { Bucket: confData.s3bucketName }
            });

            this.isAwsSdkInitialized = true;

        } catch (error) {
        }
    }

    handleFileChange(event) {
        this.actualsize = event.target.files.length;
        if (event.target.files.length === 0) return;

        const promises = [];
        for (let i = 0; i < event.target.files.length; i++) {
            const currentfileName = event.target.files[i].name;
            if (this.existingFileNamesList.includes(currentfileName)) {
                this.handleShowToastMsgMethod(
                    "Duplicate Records",
                    "There is an existing file with the same name",
                    "error"
                );
                return;
            }
            const file = event.target.files[i];
            promises.push(this.uploadToAWS(file, i));
            this.existingFileNamesList.push(currentfileName);
        }
        Promise.all(promises).catch();
        this.fileName = "";
    }

    fetchExistingFileNamesMethod(folderid) {
        return fetchExistingFileNameunderFolder({ folderId: folderid })
            .then((result) => {
                this.existingFileNamesList = result.map((item) => item.fileName);
            })
            .catch((error) => {
                this.handleShowToastMsgMethod("Error", error.message, "error");
            });
    }

    uploadToAWS(file, index) {
        if (!file) return Promise.reject(new Error("No file provided"));

        try {
            let objName;
            if (this.folderType === "public") {
                objName = this.folderParentId;
            } else {
                objName = this.folderParentId + "/" + this.userId;
            }

            const objKey = objName + "/" + file.name.replace(/\s+/g, "_").toLowerCase();
            const presignedUrl = this.s3.getSignedUrl("putObject", {
                Key: objKey,
                ContentType: file.type,
                Expires: 600000
            });

            return new Promise((resolve, reject) => {
                const xhr = new XMLHttpRequest();
                xhr.open("PUT", presignedUrl, true);

                xhr.upload.addEventListener("progress", (event) => {
                    if (event.lengthComputable) {
                        const percentComplete = Math.round((event.loaded / event.total) * 100);
                        this.uploadProgress = percentComplete;
                        if (this.draggedFiles[index]) {
                            this.draggedFiles[index].progress = percentComplete;
                            this.draggedFiles[index].style = `width: ${percentComplete}%;`;
                        }
                    }
                });

                xhr.onreadystatechange = () => {
                    if (xhr.readyState === 4) {
                        if (xhr.status === 200) {
                            this.tracksucess(file, objKey);
                            resolve();
                        } else {
                            reject(new Error("Upload failed with status: " + xhr.status));
                        }
                    }
                };

                xhr.send(file);
            });
        } catch (err) {
            return Promise.reject(err);
        }
    }

    tracksucess(file, objKey) {
        const presignedGETURL = this.s3.getSignedUrl("getObject", {
            Bucket: this.bucketname,
            Key: objKey,
            Expires: 604800
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
            .then(() => {
                this.fileName = "";
                this.fetchExistingFileNamesMethod(this.folderParentId);
            })
            .catch();

        this.filecount++;

        if (this.filecount >= this.actualsize) {
            setTimeout(() => {
                this.handleShowToastMsgMethod("Success", "File has been uploaded Successfully", "success");
                this.refreshCompleteUI();
                this.templeteVisibleFunction();
                this.closeUploadPopup();
                this.fileUploading = false;
                this.filecount = 0;
            }, 1000);
        }
    }

    handleButtonClickfolder() {
        this.showUploadPopup = true;
        this.fileUploading = false;
    }

    closeUploadPopup() {
        this.showUploadPopup = false;
        this.draggedFiles = [];
        this.selectedFiles = [];
        this.isDragOver = false;
    }

    openFileDialog() {
        const fileInput = this.template.querySelector(".file-input-hidden");
        if (fileInput) fileInput.click();
    }

    handleDragOver(event) {
        event.preventDefault();
        this.isDragOver = true;
    }

    handleDragLeave(event) {
        event.preventDefault();
        this.isDragOver = false;
    }

    handleDrop(event) {
        event.preventDefault();
        this.isDragOver = false;
        const files = Array.from(event.dataTransfer.files);
        this.selectedFiles = [...this.selectedFiles, ...files];
        this.processSelectedFiles(this.selectedFiles);
    }

    handleFileInputChange(event) {
        const files = Array.from(event.target.files);
        this.selectedFiles = [...this.selectedFiles, ...files];
        this.processSelectedFiles(this.selectedFiles);
    }

    processSelectedFiles(files) {
        if (files && files.length > 0) {
            this.draggedFiles = files.map((file) => ({
                name: file.name,
                size: this.formatFileSize(file.size),
                file: file
            }));
            this.validateFiles(files);
        }
    }

    validateFiles(files) {
        const maxSize = 10 * 1024 * 1024;
        const validFiles = [];
        const invalidFiles = [];

        files.forEach((file) => {
            if (file.size > maxSize) {
                invalidFiles.push(file.name + " (exceeds 10MB limit)");
            } else {
                validFiles.push(file);
            }
        });

        if (invalidFiles.length > 0) {
            this.handleShowToastMsgMethod(
                "File Size Error",
                "The following files exceed the size limit: " + invalidFiles.join(", "),
                "error"
            );
        }

        if (validFiles.length > 0) {
            this.selectedFilesToUpload = validFiles;
        }
    }

    removeFile(event) {
        const index = parseInt(event.target.dataset.index);
        if (index >= 0 && index < this.draggedFiles.length) {
            this.draggedFiles.splice(index, 1);
            this.selectedFiles.splice(index, 1);
            this.draggedFiles = [...this.draggedFiles];
            if (this.selectedFilesToUpload) {
                this.selectedFilesToUpload = this.draggedFiles.map((item) => item.file);
            }
            this.handleShowToastMsgMethod("File Removed", "File has been removed from upload list", "success");
        }
    }

    proceedWithUpload() {
        this.fileUploading = true;
        if (this.draggedFiles.length === 0) {
            this.handleShowToastMsgMethod("No Files", "Please select files to upload", "warning");
            return;
        }

        const files = this.draggedFiles.map((item) => item.file);

        for (const file of files) {
            if (this.existingFileNamesList.includes(file.name)) {
                this.handleShowToastMsgMethod(
                    "Duplicate Records",
                    "There is an existing file with the same name: " + file.name,
                    "error"
                );
                this.closeUploadPopup();
                return;
            }
        }

        this.actualsize = files.length;
        this.filecount = 0;

        const promises = files.map((file, i) => {
            this.existingFileNamesList.push(file.name);
            return this.uploadToAWS(file, i);
        });

        Promise.all(promises).catch((error) => {
            this.handleShowToastMsgMethod("Upload Error", "Some files failed to upload", "error");
        });
    }

    handleFileMenuSelect(event) {
        const selectedValue = event.detail.value;
        const fileId = event.target.dataset.fileId;

        const selectedFile = this.dataTable.find((file) => file.id === fileId);
        if (!selectedFile) return;

        if (selectedValue === "preview") {
            this.openPreviewModal(selectedFile);
        } else if (selectedValue === "download") {
            this.handleDownloadMethod(selectedFile);
        } else if (selectedValue === "delete") {
            this.handleConfirmClick(selectedFile);
        }
    }

    handleButtonClick(event) {
        const actionName = event.currentTarget.dataset.value;
        const fileId = event.currentTarget.dataset.id;

        const row = this.dataTable.find((file) => file.id === fileId);
        if (!row) {
            return;
        }
        this.fieldName = row.fileName;
        this.fileName = row.fileName;
        this.fileSize = row.fileSize;

        if (actionName === "Preview") {
            this.openPreviewModal(row);
        } else if (actionName === "Download") {
            this._handleDownloadAction(row);
        } else if (actionName === "Delete") {
            this.dataTable = this.dataTable.map((file) => ({ ...file, isDropdownOpen: false }));
            this.handleConfirmClick(row);
        } else if (actionName === "Copy URL") {
            this.copyTextToClipboard(row);
        }
    }

    handleButtonClick1(event) {
        const fileId = event.currentTarget.dataset.id;
        const row = this.dataTable.find((file) => file.id === fileId);
        if (row) {
            this.openPreviewModal(row);
        }
    }

    _handleDownloadAction(row) {
        const objectKey = row.objectKey;
        const presignedGETURL = this.s3.getSignedUrl("getObject", {
            Bucket: this.bucketname,
            Key: objectKey,
            Expires: 60
        });

        const filetype = row.fileType;
        if (["XLSX", "WORD", "ZIP", "PPT"].includes(filetype)) {
            this.downloadPopup = true;
            setTimeout(() => { this.downloadPopup = false; }, 2000);
            const link = document.createElement("a");
            link.href = presignedGETURL;
            link.download = true;
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        } else if (filetype.includes("doctype:pdf")) {
            const link = document.createElement("a");
            link.href = presignedGETURL;
            link.target = "_blank";
            link.download = true;
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        } else {
            this.handleDownloadMethod(row);
        }
    }

    openPreviewModal(file) {
        this.previewError = false;
        this.previewLoading = true;
        this.selectedFileForPreview = file;

        try {
            if (!this.s3 || !this.isAwsSdkInitialized)
                throw new Error("AWS SDK not initialized");

            const objectKey =
                file.objectKey ||
                `${this.objectApiName}/${this.recordId}/${file.fileName.replace(/\s+/g, "_").toLowerCase()}`;

            if (!objectKey)
                throw new Error("Unable to determine object key for file");

            this.previewUrl = this.s3.getSignedUrl("getObject", {
                Bucket: this.bucketname,
                Key: objectKey,
                Expires: 300
            });

            this.showPreviewModal = true;
            this.previewLoading = false;

        } catch (error) {
            this.previewError = true;
            this.previewLoading = false;
            this.showPreviewModal = true;
            this.handleShowToastMsgMethod("Preview Error", "Failed to generate preview URL", "error");
        }
    }

    openFileInNewTab() {
        if (this.previewUrl) {
            window.open(this.previewUrl, "_blank");
            this.closePreviewModal();
        }
    }

    closePreviewModal() {
        this.showPreviewModal = false;
        this.selectedFileForPreview = null;
        this.previewUrl = "";
        this.previewError = false;
        this.previewLoading = true;
    }
    handleDownloadMethod(rowdetail) {
        const objectKey = rowdetail.objectKey;
        this.fileName = rowdetail.fileName;
        this.fileSize = rowdetail.fileSize;

        this.createdDate =
            new Date(rowdetail.createdDate).toLocaleDateString("en-GB", {
                day: "2-digit",
                month: "short",
                year: "numeric"
            }) +
            ", " +
            new Date(rowdetail.createdDate)
                .toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit", hour12: true })
                .toLowerCase();

        this.downloadPopup = true;
        this.downloadComplete = false;
        this.progress = 0;

        const presignedGETURL = this.s3.getSignedUrl("getObject", {
            Bucket: this.bucketname,
            Key: objectKey,
            Expires: 60
        });

        this.simulateDownloadProgress();
        this.performActualDownload(presignedGETURL);
    }

    simulateDownloadProgress() {
        let progress = 0;
        const interval = setInterval(() => {
            progress += Math.random() * 20;
            if (progress >= 100) {
                progress = 100;
                clearInterval(interval);
            }
            this.progress = Math.floor(Math.min(progress, 100));
        }, 150);

        setTimeout(() => {
            this.downloadPopup = false;
            this.resetDownloadState();
        }, 1000);
    }

    async performActualDownload(downloadUrl) {
        try {
            const response = await fetch(downloadUrl);
            if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);

            const blob = await response.blob();
            const url = window.URL.createObjectURL(blob);
            const link = document.createElement("a");
            link.href = url;
            link.download = this.fileName;
            document.body.appendChild(link);
            link.click();
            window.URL.revokeObjectURL(url);
            document.body.removeChild(link);

            this.handleShowToastMsgMethod("Success", "Download completed successfully", "success");
        } catch (error) {
            this.handleShowToastMsgMethod(
                "Download Error",
                `Failed to download ${this.fileName}: ${error.message}`,
                "error"
            );
            this.downloadComplete = true;
        }
    }

    handleCloseDownload() {
        if (this.downloadComplete) {
            this.downloadPopup = false;
            this.resetDownloadState();
        } else {
            this.handleShowToastMsgMethod("Download in Progress", "Please wait for the download to complete", "warning");
        }
    }

    resetDownloadState() {
        this.downloadComplete = false;
        this.progress = 0;
        this.fileName = "";
        this.fileSize = "";
        this.createdDate = "";
    }

    async handleConfirmClick(row) {
        const fileNameToDelete = row.fileName || this.fieldName || 'this file';

        const result = await LightningConfirm.open({
            message: "Do you want to delete the selected " + fileNameToDelete + " file ?",
            variant: "default",
            label: "Delete a file"
        });

        if (!result) return;

        const fileRecordId = row.id || row.Id;
        let accessGranted = false;

        try {
            const res = await deleteAcess({ fileId: fileRecordId, objectName: "file" });
            if (!res) {
                this.handleShowToastMsgMethod(
                    "Error !",
                    "The User does not have delete permission for this File",
                    "error"
                );
            }
            accessGranted = res;
        } catch (err) {
            return;
        }

        if (accessGranted) {
            this.handleShowToastMsgMethod(
                "Deleted " + fileNameToDelete,
                "Deleted Successfully",
                "success"
            );
            this.handleFileDeleteMethod(row)
                .then(() => {
                    this._notifyParentRefresh("fileDeleted");
                    this.fetchExistingFileNamesMethod(this.folderParentId);
                })
                .catch();
        }
    }

    async handleConfirmfolderClick(foldername, files, folders) {
        const result = await LightningConfirm.open({
            message: "Do you want to delete the selected " + foldername + " Folder ?",
            variant: "default",
            label: "Delete a Folder"
        });

        if (!result) return;

        try {
            const normalizedFiles = (files || []).map(f => ({
                ...f,
                id: f.id || f.Id,
                objectKey: f.objectKey || f.objKey
            }));

            const deletableFiles = normalizedFiles.filter(f => f.objectKey);
            if (deletableFiles.length > 0) {
                await Promise.all(
                    deletableFiles.map(row => this.handleFileDeleteMethod(row))
                );
            }

            const deleteResult = await this.deletefolder(folders);

            if (!deleteResult) {
                this.handleShowToastMsgMethod("Delete Error", "Folder could not be deleted", "error");
                return;
            }
            await this.refreshCompleteUI();
            this._notifyParentRefresh("folderDeleted");

            this.handleShowToastMsgMethod("Deleted " + foldername, "Folder deleted successfully", "success");

        } catch (error) {
            this.handleShowToastMsgMethod("Delete Error", error.message, "error");
        }
    }

    deletefolder(folders) {
        const folderObjects = folders.map((f) => ({ Id: f.Id || f.id }));
        return apexFolderDelete({ folderList: folderObjects });
    }

    handleFolderDelete(event) {
        event.stopPropagation();
        event.preventDefault();

        if (event.target.tagName !== 'BUTTON' && !event.currentTarget.dataset.folderId) {
            return;
        }

        const folderId = event.currentTarget.dataset.folderId
            || event.currentTarget.getAttribute("data-folder-id");
        const foldername = event.currentTarget.dataset.folderName
            || event.currentTarget.getAttribute("data-folder-name");

        if (!folderId) {
            return;
        }
        this.folderlist = this.folderlist.map((f) => ({ ...f, isDropdownOpen: false }));

        get_files_Folder_for_Del({ folderId: folderId })
            .then((result) => {
                this.handleConfirmfolderClick(
                    foldername,
                    result.files || [],
                    result.folders || []
                );
            })
            .catch();
    }

    handleFileDeleteMethod(row) {
        return new Promise((resolve, reject) => {
            const rowId = row.id || row.Id;
            const objectKey = row.objectKey || row.objKey;

            if (!window.AWS || !this.awsS3MetadataConfMain || !this.bucketname || !objectKey) {
                reject(new Error("Missing required AWS configuration or object key"));
                return;
            }

            const AWS = window.AWS;

            AWS.config.update({
                accessKeyId: this.awsS3MetadataConfMain.awsAccessKeyId,
                secretAccessKey: this.awsS3MetadataConfMain.awsSecretAccessKey,
                region: this.awsS3MetadataConfMain.s3RegionName
            });

            this.s3 = new AWS.S3({
                apiVersion: this.awsS3MetadataConfMain.apiVersion,
                signatureVersion: this.awsS3MetadataConfMain.signatureVersion
            });

            this.s3.deleteObject(
                { Bucket: this.bucketname, Key: objectKey },
                (err) => {
                    if (err) {
                        reject(err);
                        return;
                    }

                    deleteCallout({ recordId: rowId })
                        .then(() => {
                            this.refreshCompleteUI();
                            resolve(true);
                        })
                        .catch((sfError) => {
                            reject(sfError);
                        });
                }
            );
        });
    }
    async copyTextToClipboard(file) {
        const now = new Date();
        const createdDate = new Date(file.createdDate);
        const lastModifiedDate = new Date(file.lastModifiedDate);

        const daysDiff = (from, to) =>
            Math.ceil(Math.abs(to - from) / (1000 * 60 * 60 * 24));

        const isRecent =
            daysDiff(now, createdDate) < 7 || daysDiff(now, lastModifiedDate) < 7;

        let fileurl;

        if (!isRecent) {
            const presignedGETURL = this.s3.getSignedUrl("getObject", {
                Bucket: this.bucketname,
                Key: file.objectKey,
                Expires: 604800
            });

            updateUrl({ ID: file.id, URL: presignedGETURL })
                .catch();

            fileurl = presignedGETURL;
        } else {
            fileurl = file.fileURL;
        }

        const confirmed = await LightningConfirm.open({
            message: "This Link is Expire Within 7 Day. Do You Want to Copy?",
            variant: "default",
            label: "Caution !"
        });

        if (confirmed) {
            navigator.clipboard.writeText(fileurl)
                .then(() => {
                    this.handleShowToastMsgMethod(
                        "Copy Successfully",
                        "Public URL link is successfully Copied to Your clipboard !",
                        "success"
                    );
                })
                .catch();
        }
    }
    handleModalOpen() {
        this.isModalOpen = true;
    }

    handleModalClose() {
        this.isModalOpen = false;
        this.folderNameInput = "";
    }

    handleFolderNameChange(event) {
        this.folderNameInput = event.target.value;
    }

    handleClick() {
        if (!this.folderParentId || !this.folderNameInput) {
            this.handleShowToastMsgMethod("Error", "Please provide a Folder name.", "error");
            return;
        }

        addFolder({
            parentId: this.folderParentId,
            folderName: this.folderNameInput
        })
            .then((result) => {
                if (result === "Folder added successfully") {
                    this.showToast("Success", result, "success");
                    this.refreshCompleteUI().then(() => {
                        this._notifyParentRefresh("folderAdded");
                    });

                    this.isModalOpen = false;
                    this.folderNameInput = "";
                } else {
                    this.showToast("Error", result, "error");
                }
            })
            .catch((error) => {
                this.showToast("Error", error?.body?.message || error.message, "error");
            });
    }

    _notifyParentRefresh(action) {
        this.dispatchEvent(
            new CustomEvent("callparentmethod", {
                detail: {
                    folderId: this.folderParentId,
                    refreshTree: true,
                    action: action
                },
                bubbles: true,
                composed: true
            })
        );
    }

    getfolderlist(folderid, isFromClick = false) {
    if (this.selectedLabel.includes("Shared with Me") && this.folderType !== "shared") {
        return getSharedFolderList({ folderId: folderid })
            .then((result) => {
                this.showAddFolder = false;
                this.showShare = false;
                this.showdelete = false;

                result.folder = result.folder.map((record) => ({
                    ...record,
                    CreatedDate: record.createdDate
                        ? new Date(record.createdDate).toLocaleDateString()
                        : "-"
                }));

                this.isfolderList = result.folder.length > 0;
                this.folderlist = [...result.folder];
                this.showFile = this.isfolderList || this.dataTable.length > 0;
                this.noFile = !this.showFile;

                if (this.folderlist.length >= 0 && this.folderType === "shared") {
                    this.showFolder = false;
                }
            })
            .catch();
    } else {
        return getfolderbelowparent({ folderId: folderid, foldertype: this.folderType })
            .then((result) => {
                this.Accesstype = result.Accesstype;

                if (this.selectedLabel === "📂 Private Folder") {
                    // Private Folder root - show both delete and share
                    this.showShare = true;
                    this.showdelete = true;
                    this.showAddFolder = true;
                } else if (result.Accesstype === "private") {
                    // Inside private subfolder - show both delete and share
                    this.showShare = true;
                    this.showdelete = true;
                    this.showAddFolder = isFromClick ? false : true;
                } else if (result.Accesstype === "public") {
                    this.showShare = false;
                    this.showdelete = true;
                    this.showAddFolder = true;
                } else if (result.Accesstype === "shared") {
                    this.showShare = false;
                    this.showdelete = false;
                    this.showAddFolder = false;
                } else {
                    this.showShare = false;
                    this.showdelete = false;
                    this.showAddFolder = false;
                }

                result.folder = result.folder.map((record) => ({
                    ...record,
                    CreatedDate: record.createdDate
                        ? new Date(record.createdDate).toLocaleDateString()
                        : "-"
                }));

                this.isfolderList = result.folder.length > 0;
                this.folderlist = [...result.folder];
                this.showFile = this.isfolderList || this.dataTable.length > 0;
                this.noFile = !this.showFile;

                if (this.folderlist.length >= 0 && this.folderType === "shared") {
                    this.showFolder = false;
                }
            })
            .catch();
    }
}


    folderclick(event) {
        this._navStack = [...this._navStack, this.folderParentId];

        this.folderParentId = event.target.dataset.id;
        this.folderType = event.target.dataset.type;
        this.parentTemp = false;
        this.isdataTable = false;
        this.isfolderList = false;
        this.dataTable = [];
        this.folderlist = [];
        this.noFile = false;

        this.getfolderlist(this.folderParentId, true);
        this.getUploadedFiles(this.folderParentId);
        this.fetchExistingFileNamesMethod(this.folderParentId);
        this.handleFetchRecordData();
    }

    handleBack() {
        if (this._navStack.length === 0) return;

        const updatedStack = [...this._navStack];
        const previousFolderId = updatedStack.pop();
        this._navStack = updatedStack;

        this.dataTable = [];
        this.folderlist = [];
        this.noFile = false;
        this.isdataTable = false;
        this.isfolderList = false;
        this.folderParentId = previousFolderId;

        if (this._navStack.length === 0) {
            this.parentTemp = true;
            this.showFile = false;
            this.isdataTable = false;
        } else {
            this.parentTemp = false;
        }

        this.dispatchEvent(
            new CustomEvent('backevent', {
                detail: { folderParentId: previousFolderId }
            })
        );

        this.getfolderlist(previousFolderId);
        this.getUploadedFiles(previousFolderId);
        this.fetchExistingFileNamesMethod(previousFolderId);
        this.handleFetchRecordData();
    }

    async parentFolderCheck() {
        try {
            const result = await getRootParent();
            this.folderIds = result.map((folder) => folder.Id);
            const isAtRoot = this.folderIds.includes(this.folderParentId);

            this.parentTemp = isAtRoot;

            if (isAtRoot) {
                this.isdataTable = false;
                this.navigationStack = [];
                this.dataTable = [];
                this.folderlist = [];
                this.noFile = false;
                this.showFile = false;
            }
        } catch (error) {
        }
    }

    handleFetchRecordData() {
        getFolderName({ recordId: this.folderParentId })
            .then((result) => {
                this.currentFolderName = result.Name;
            })
            .catch();
    }
    getUploadedFiles(folderid) {
        this.dataTable = [];

        return getAWSFiles({ parentId: folderid, foldertype: this.folderType })
            .then((data) => {
                if (!data || data.length === 0) {
                    this.isdataTable = false;
                    this.showFile = this.folderlist.length > 0;
                    this.noFile = !this.showFile;
                    return;
                }

                this.dataTable = data.map((record) => {
                    return {
                        id: record.Id || record.id,
                        fileName: record.fileName || record.FileName || record.Name,
                        fileType: record.fileType || record.FileType || record.type,
                        objectKey: record.objectKey || record.objKey,
                        fileURL: record.fileURL || record.url,
                        fileSize: this.formatFileSize(
                            parseInt(record.fileSize || record.size || 0, 10)
                        ),
                        createdDate: record.createdDate
                            ? new Date(record.createdDate).toLocaleDateString()
                            : "-",
                        isDropdownOpen: false
                    };
                });

                this.dataTable = this.dataTable.map((item) => {
                    const typeMap = {
                        "image/jpeg": ["JPEG", "file-jpeg"],
                        "image/png": ["PNG", "file-png"],
                        "application/pdf": ["PDF", "file-pdf"],
                        "text/plain": ["TXT", "file-txt"],
                        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": ["XLSX", "file-xlsx"],
                        "text/csv": ["XLSX", "file-xlsx"],
                        "application/vnd.openxmlformats-officedocument.wordprocessingml.document": ["WORD", "file-word"],
                        "application/msword": ["WORD", "file-word"],
                        "application/x-zip-compressed": ["ZIP", "file-zip"],
                        "application/vnd.ms-powerpoint": ["PPT", "file-ppt"],
                        "application/vnd.openxmlformats-officedocument.presentationml.presentation": ["PPT", "file-ppt"]
                    };

                    const [label, cssClass] = typeMap[item.fileType] || ["FILE", "file-generic"];

                    return {
                        ...item,
                        fileTypeLabel: label,
                        cssClass: cssClass,
                        fileTypeBoxClass: "file-type-box " + cssClass
                    };
                });

                this.isdataTable = this.dataTable.length > 0;
                this.showFile = this.isdataTable || this.folderlist.length > 0;
                this.noFile = !this.showFile;
            })
            .catch((error) => {
                this.handleShowToastMsgMethod("Error", "Failed to load files", "error");
            });
    }

    refreshCompleteUI() {
        this.showSpinner = true;

        return Promise.all([
            this.getUploadedFiles(this.folderParentId),
            this.getfolderlist(this.folderParentId),
            this.fetchExistingFileNamesMethod(this.folderParentId)
        ]).then(() => {
            this.isfolderList = this.folderlist.length > 0;
            this.isdataTable = this.dataTable.length > 0;
            this.showFile = this.isfolderList || this.isdataTable;
            this.noFile = !this.showFile;
            this.showSpinner = false;
        }).catch(error => {
            this.showSpinner = false;
        });
    }

    syncUI(folderId) {
        Promise.all([
            this.getUploadedFiles(folderId),
            this.getfolderlist(folderId),
            this.fetchExistingFileNamesMethod(folderId)
        ]).then(() => {
            this.isfolderList = this.folderlist.length > 0;
            this.isdataTable = this.dataTable.length > 0;
            this.showFile = this.isfolderList || this.isdataTable;
            this.noFile = !this.showFile;

            this.dispatchEvent(
                new CustomEvent("callparentmethod", {
                    detail: {
                        folderId: folderId,
                        syncComplete: true,
                        refreshTree: true
                    }
                })
            );
        }).catch(error => {
        });
    }

    fileCheck() {
        if (this.dataTable.length === 0 && this.folderlist.length === 0) {
            this.noFile = true;
            this.showFile = false;
        } else {
            this.noFile = false;
            this.showFile = true;
            this.isdataTable = this.dataTable.length > 0;
        }
    }

    toggleDropdown(event) {
        const fileId = event.currentTarget.dataset.id;
        this.folderlist = this.folderlist.map((item) => ({ ...item, isDropdownOpen: false }));
        this.dataTable = this.dataTable.map((file) => ({
            ...file,
            isDropdownOpen: file.id === fileId ? !file.isDropdownOpen : false
        }));
    }

    toggleDropdown1(event) {
        const selectedId = event.currentTarget.dataset.id;
        this.dataTable = this.dataTable.map((item) => ({ ...item, isDropdownOpen: false }));
        this.folderlist = this.folderlist.map((folder) => ({
            ...folder,
            isDropdownOpen: folder.id === selectedId ? !folder.isDropdownOpen : false
        }));
    }

    handlecloseDropdownbtn(event) {
        const target = event.target;
        if (
            target.closest(".dropdown-menu") ||
            target.closest(".dropdown-item") ||
            target.closest("lightning-button-icon") ||
            target.closest("button")
        ) {
            return;
        }
        this.dataTable = this.dataTable.map((file) => ({ ...file, isDropdownOpen: false }));
        this.folderlist = this.folderlist.map((folder) => ({ ...folder, isDropdownOpen: false }));
    }

    refreshFileList() {
        Promise.all([
            this.getUploadedFiles(this.folderParentId),
            this.getfolderlist(this.folderParentId)
        ]).then(() => {
            this.isfolderList = this.folderlist.length > 0;
            this.isdataTable = this.dataTable.length > 0;
            this.showFile = this.isfolderList || this.isdataTable;
            this.noFile = !this.showFile;
        });
    }

    showPopup(event) {
    const type = event.currentTarget.dataset.type;
    const id = event.currentTarget.dataset.id;
    
    if (!type || !id) {
        this.handleShowToastMsgMethod("Error", "Invalid selection", "error");
        return;
    }
    
    this.type = type;
    this.isPopupVisible = true;

    if (type === "folder") {
        this.fileId = null;
        this.accessLabel = "Folder Access Level";
        this.folderId = id;
        this.gettingsharingdetails(this.folderId, type);
    } else if (type === "file") {
        this.folderId = null;
        this.accessLabel = "File Access Level";
        this.fileId = id;
        this.gettingsharingdetails(this.fileId, type);
    } else {
        this.isPopupVisible = false;
    }
}

    gettingsharingdetails(parentid, type) {
    this.accesslist = [];
    this.accesslistsize = 0;
    this.showaccesstable = false;
    
    getssharingdetails({ parentId: parentid, type: type })
        .then((result) => {
            if (!result) {
                this.accesslist = [];
                this.accesslistsize = 0;
                return;
            }
            try {
                const parsed = JSON.parse(result);
                if (!Array.isArray(parsed)) {
                    this.accesslist = [];
                    this.accesslistsize = 0;
                    return;
                }
                this.accesslist = parsed.map((item) => ({
                    ...item,
                    isAll: item.AccessLevel === "All"
                }));
                this.accesslistsize = this.accesslist.length;
            } catch (e) {
                this.accesslist = [];
                this.accesslistsize = 0;
            }
        })
        .catch(() => {
            this.accesslist = [];
            this.accesslistsize = 0;
        });
}

    handleEditAccess() {
        this.showaccesstable = !this.showaccesstable;
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
        if (type === "user") {
            this.selectedUser = event.detail.value;
        } else if (type === "access") {
            this.selectedAccess = event.detail.value;
        } else if (type === "delete") {
            const item = this.accesslist.find((i) => i.Id === event.target.dataset.id);
            if (item && !this.deletedaccesslist.includes(item.Id)) {
                this.deletedaccesslist.push(item.Id);
            }
            this.accesslist = this.accesslist.filter((el) => el.Id !== item.Id);
            this.accesslistsize = this.accesslist.length;
        } else if (type === "table") {
            this.accesslist = this.accesslist.map((item) => {
                if (item.Id !== event.target.dataset.id) return item;

                const oldAccessLevel = item.AccessLevel;
                updatingAccess({ Id: item.Id, AccessLevel: event.detail.value, Type: this.type })
                    .then((result) => {
                        if (result) {
                            item.AccessLevel = event.detail.value;
                            this.handleShowToastMsgMethod(
                                "Success",
                                `Access Level Updated Successfully in '${item.UserOrGroup.Name}'.`,
                                "success"
                            );
                        } else {
                            item.AccessLevel = oldAccessLevel;
                            this.handleShowToastMsgMethod(
                                "Error",
                                `Error in Updating Access Level in '${item.UserOrGroup.Name}'.`,
                                "error"
                            );
                        }
                    })
                    .catch(() => {
                        item.AccessLevel = oldAccessLevel;
                        this.handleShowToastMsgMethod(
                            "Error",
                            `Error in Updating Access Level in '${item.UserOrGroup.Name}'.`,
                            "error"
                        );
                    });

                return item;
            });
        }
    }

    handleShare() {
        const allValid = this.validateFields();
        if (!allValid) {
            this.handleShowToastMsgMethod("Error", "Please fill all required fields.", "error");
            return;
        }

        if (this.deletedaccesslist.length > 0) {
            removeAccess({ IDs: this.deletedaccesslist, Type: this.type })
                .then((result) => {
                    if (result && this.selectedUser && this.selectedAccess) {
                        this.handleFolderShare();
                    } else if (result) {
                        this.handleShowToastMsgMethod("Successfully !!!", "Access Removed successfully.", "success");
                        this.cancelPopup();
                    }
                })
                .catch();
        } else if (this.selectedUser && this.selectedAccess) {
            this.handleFolderShare();
        } else {
            this.handleShowToastMsgMethod("Error", "Please fill all required fields.", "error");
        }
    }

    validateFields() {
        const inputFields = this.template.querySelectorAll('lightning-combobox[required="true"]');
        let isValid = true;
        inputFields.forEach((field) => {
            if (!field.value) {
                field.reportValidity();
                isValid = false;
            }
        });
        return isValid;
    }

    async handleFolderShare() {
        if (this.type === "folder") {
            const confirmed = await LightningConfirm.open({
                message: "Files and Folders below this Folder also Shared.",
                variant: "default",
                label: "Do you want to share the Folder!"
            });
            if (confirmed) {
                updateFolderOwner({
                    folderId: this.folderId,
                    newOwnerId: this.selectedUser,
                    AccessLevel: this.selectedAccess
                })
                    .then(() => {
                        this.handleShowToastMsgMethod("Shared Successfully !!!", "Folder Sharing successfully.", "success");
                        this.cancelPopup();
                    })
                    .catch();
            } else {
                this.cancelPopup();
            }
        } else if (this.type === "file") {
            updateFileOwner({
                fileId: this.fileId,
                newOwnersId: this.selectedUser,
                AccessLevel: this.selectedAccess
            })
                .then(() => {
                    this.handleShowToastMsgMethod("Shared Successfully !!!", "File Sharing successfully.", "success");
                    this.cancelPopup();
                })
                .catch();
        } else {
            this.cancelPopup();
        }
    }
    handleShowToastMsgMethod(titleStr, msgStr, variantStr) {
        this.dispatchEvent(
            new ShowToastEvent({ title: titleStr, message: msgStr, variant: variantStr })
        );
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    templeteVisibleFunction() {
        setTimeout(() => {
            this.showFile = false;
            setTimeout(() => { this.showFile = true; }, 0);
        }, 1000);
    }

    callParentMethod() {
        this.dispatchEvent(new CustomEvent("callparentmethod"));
    }

    handleClickAccordion(event) {
        const sectionId = event.currentTarget.dataset.sectionid;
        const contentEl = this.template.querySelector(`[data-contentid="${sectionId}"]`);
        if (contentEl) {
            const isHidden = contentEl.getAttribute("aria-hidden") === "true";
            contentEl.setAttribute("aria-hidden", String(!isHidden));
        }
    }

    formatFileSize(bytes) {
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1048576) return (bytes / 1024).toFixed(2) + " KB";
        if (bytes < 1073741824) return (bytes / 1048576).toFixed(2) + " MB";
        return (bytes / 1073741824).toFixed(2) + " GB";
    }

    formatDate(date) {
        return date.toLocaleDateString("en-US", {
            year: "numeric",
            month: "2-digit",
            day: "2-digit"
        });
    }

    imageDownload(blob, fileName) {
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.classList.add("hidden-download-link");
        a.href = url;
        a.download = fileName;
        document.body.appendChild(a);
        a.click();
        window.URL.revokeObjectURL(url);
    }

    _folderParentId;

    @api
    get folderParentId() {
        return this._folderParentId;
    }

    set folderParentId(value) {
        this._folderParentId = value;

    if (value) {
        this.refreshCompleteUI();
        this.handleFetchRecordData();
    }
}
}