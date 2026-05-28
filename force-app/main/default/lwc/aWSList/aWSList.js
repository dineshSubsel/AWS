import { LightningElement, api, track, wire } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAWSConfiguration from '@salesforce/apex/AWSFileUploadHandlingController.getAWSConfiguration';
import AWS_SDK from '@salesforce/resourceUrl/AWSSDK';

export default class AwsS3FilesAndFoldersTable extends LightningElement {
    @api bucketName; // Optional: specific bucket name
    @api rootPath = ''; // Optional: specific root path to start from
    
    @track allItems = [];
    @track filteredItems = [];
    @track isLoading = false;
    @track isAwsSdkInitialized = false;
    @track currentPath = '';
    @track searchTerm = '';
    @track sortedBy = 'name';
    @track sortDirection = 'asc';
    @track selectedItems = [];
    @track showBreadcrumb = true;
    
    // Upload related properties
    @track isUploading = false;
    @track uploadProgress = 0;
    @track uploadedFiles = [];
    @track failedUploads = [];
    @track showUploadModal = false;
    @track dragOver = false;
    @track totalFilesToUpload = 0;
    @track currentFileUploading = '';
    
    @track awsS3MetadataConfMain = {};
    @track s3;
    @track bucketname;
    @track baseurl;
    
    columns = [
    {
        label: 'Name',
        fieldName: 'name',
        type: 'text',
        sortable: true,
        cellAttributes: {
            iconName: { fieldName: 'icon' },
            iconPosition: 'left'
        }
    },
    {
        label: 'Type',
        fieldName: 'type',
        type: 'text',
        sortable: true
    },
    {
        label: 'Size',
        fieldName: 'formattedSize',
        type: 'text',
        sortable: true
    },
    {
        label: 'Last Modified',
        fieldName: 'lastModified',
        type: 'date',
        sortable: true,
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        }
    },
    {
        label: 'Actions',
        type: 'action',
        typeAttributes: {
            rowActions: this.getRowActions
        }
    }
];


    // Dynamic row actions based on item type
    getRowActions(row, doneCallback) {
        const actions = [];
        
        if (row.isFolder) {
            actions.push(
                { label: 'Open Folder', name: 'open', iconName: 'utility:open_folder' }
            );
        } else {
            actions.push(
                { label: 'Download', name: 'download', iconName: 'utility:download' },
                { label: 'Preview', name: 'preview', iconName: 'utility:preview' },
                { label: 'Copy URL', name: 'copyurl', iconName: 'utility:copy' }
            );
        }
        
        actions.push(
            { label: 'Delete', name: 'delete', iconName: 'utility:delete' }
        );
        
        doneCallback(actions);
    }

    // Getters
    get breadcrumbItems() {
        const items = [{ label: 'Root', name: '' }];
        if (this.currentPath) {
            const pathParts = this.currentPath.split('/').filter(part => part);
            let currentPath = '';
            pathParts.forEach(part => {
                currentPath += part + '/';
                items.push({
                    label: part,
                    name: currentPath
                });
            });
        }
        return items;
    }

    get hasItems() {
        return this.filteredItems && this.filteredItems.length > 0;
    }

    get itemCount() {
        return this.filteredItems ? this.filteredItems.length : 0;
    }

    get folderCount() {
        return this.filteredItems ? this.filteredItems.filter(item => item.type === 'Folder').length : 0;
    }

    get fileCount() {
        return this.filteredItems ? this.filteredItems.filter(item => item.type !== 'Folder').length : 0;
    }

    get uploadProgressPercentage() {
        return Math.round(this.uploadProgress);
    }

    get hasUploadedFiles() {
        return this.uploadedFiles && this.uploadedFiles.length > 0;
    }

    get hasFailedUploads() {
        return this.failedUploads && this.failedUploads.length > 0;
    }

    get uploadStatusText() {
        if (this.isUploading && this.totalFilesToUpload > 0) {
            const completed = this.uploadedFiles.length + this.failedUploads.length;
            return `Uploading ${this.currentFileUploading} (${completed + 1}/${this.totalFilesToUpload})`;
        }
        return '';
    }

    connectedCallback() {
        console.log('AWS S3 Table Component initialized');
        this.currentPath = this.rootPath || '';
        this.loadAWSConfiguration();
        
        this.addEventListener('dragover', this.handleDragOver.bind(this));
        this.addEventListener('dragleave', this.handleDragLeave.bind(this));
        this.addEventListener('drop', this.handleDrop.bind(this));
    }

    disconnectedCallback() {
        this.removeEventListener('dragover', this.handleDragOver.bind(this));
        this.removeEventListener('dragleave', this.handleDragLeave.bind(this));
        this.removeEventListener('drop', this.handleDrop.bind(this));
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
                this.showToast('Error', 'Failed to load AWS SDK', 'error');
            });
    }

    // Load AWS Configuration
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
                    this.bucketname = this.bucketName || result.S3_Bucket_Name__c;
                    this.baseurl = 'https://' + this.bucketname + '.s3.' + result.S3_Region_Name__c + '.amazonaws.com/';

                    if (window.AWS && this.awsS3MetadataConfMain) {
                        this.initializeAwsSdk(this.awsS3MetadataConfMain);
                    }
                } else {
                    this.showToast('Error', 'AWS Configuration not found', 'error');
                }
            })
            .catch(error => {
                console.error('Error loading AWS configuration:', error);
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
            apiVersion: "2012-10-17",
            signatureVersion: 'v4',
            params: {
                Bucket: confData.s3bucketName
            }
        });
        this.isAwsSdkInitialized = true;
        console.log('AWS SDK initialized successfully');
        
        this.loadFilesAndFolders();
    }

    loadFilesAndFolders() {
        if (!this.isAwsSdkInitialized) {
            console.warn('AWS SDK not initialized yet');
            return;
        }

        this.isLoading = true;
        const params = {
            Bucket: this.bucketname,
            Prefix: this.currentPath,
            Delimiter: '/'
        };

        console.log('Loading S3 contents with params:', params);

        this.s3.listObjectsV2(params, (err, data) => {
            if (err) {
                console.error('Error loading S3 contents:', err);
                this.showToast('Error', 'Failed to load S3 contents: ' + err.message, 'error');
                this.isLoading = false;
                return;
            }

            console.log('S3 data received:', data);
            this.processS3Data(data);
            this.isLoading = false;
        });
    }

    processS3Data(data) {
        const items = [];

        if (data.CommonPrefixes) {
            data.CommonPrefixes.forEach(prefix => {
                const folderName = prefix.Prefix.replace(this.currentPath, '').replace('/', '');
                if (folderName) {
                    items.push({
                        id: prefix.Prefix,
                        name: folderName,
                        type: 'Folder',
                        size: 0,
                        formattedSize: '-',
                        lastModified: null,
                        key: prefix.Prefix,
                        isFolder: true,
                        icon: 'standard:folder'
                    });
                }
            });
        }

        if (data.Contents) {
            data.Contents.forEach(obj => {
                if (obj.Key === this.currentPath) {
                    return;
                }

                const fileName = obj.Key.replace(this.currentPath, '');
                if (fileName && !fileName.includes('/')) {
                    const fileExtension = this.getFileExtension(fileName);
                    items.push({
                        id: obj.Key,
                        name: fileName,
                        type: this.getFileType(fileExtension),
                        size: obj.Size,
                        formattedSize: this.formatFileSize(obj.Size),
                        lastModified: obj.LastModified,
                        key: obj.Key,
                        isFolder: false,
                        icon: this.getFileIcon(fileExtension),
                        etag: obj.ETag
                    });
                }
            });
        }

        this.allItems = items;
        this.applyFilters();
        this.sortData();
    }

    applyFilters() {
        let filtered = [...this.allItems];

        if (this.searchTerm) {
            const term = this.searchTerm.toLowerCase();
            filtered = filtered.filter(item => 
                item.name.toLowerCase().includes(term) ||
                item.type.toLowerCase().includes(term)
            );
        }

        this.filteredItems = filtered;
    }

    sortData() {
        if (!this.sortedBy) return;

        this.filteredItems.sort((a, b) => {
            if (a.isFolder && !b.isFolder) return -1;
            if (!a.isFolder && b.isFolder) return 1;

            let aVal = a[this.sortedBy];
            let bVal = b[this.sortedBy];

            if (this.sortedBy === 'size') {
                aVal = a.size || 0;
                bVal = b.size || 0;
            } else if (this.sortedBy === 'lastModified') {
                aVal = a.lastModified ? new Date(a.lastModified).getTime() : 0;
                bVal = b.lastModified ? new Date(b.lastModified).getTime() : 0;
            } else {
                aVal = (aVal || '').toString().toLowerCase();
                bVal = (bVal || '').toString().toLowerCase();
            }

            let result = 0;
            if (aVal < bVal) result = -1;
            if (aVal > bVal) result = 1;

            return this.sortDirection === 'desc' ? result * -1 : result;
        });
    }

    handleSort(event) {
        const fieldName = event.detail.fieldName;
        if (this.sortedBy === fieldName) {
            this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
        } else {
            this.sortedBy = fieldName;
            this.sortDirection = 'asc';
        }
        this.sortData();
    }

    handleSearch(event) {
        this.searchTerm = event.target.value;
        this.applyFilters();
        this.sortData();
    }

    handleRefresh() {
        this.loadFilesAndFolders();
    }

    handleUploadClick() {
        this.resetUploadState();
        this.showUploadModal = true;
    }

    handleCloseUploadModal() {
        this.showUploadModal = false;
        this.resetUploadState();
    }

    handleFileSelection(event) {
        const files = event.target.files;
        if (files && files.length > 0) {
            this.processSelectedFiles(Array.from(files));
        }
    }

    handleFolderSelection(event) {
        const files = event.target.files;
        if (files && files.length > 0) {
            this.processSelectedFiles(Array.from(files));
        }
    }

    processSelectedFiles(files) {
        console.log('Processing selected files:', files.length);
        
        const filesByPath = this.groupFilesByPath(files);
        
        console.log('Files grouped by path:', filesByPath);
        
        this.uploadFiles(files);
    }

    groupFilesByPath(files) {
        const pathMap = {};
        
        files.forEach(file => {
            const relativePath = file.webkitRelativePath || file.name;
            const pathParts = relativePath.split('/');
            
            if (pathParts.length > 1) {
                const folderPath = pathParts.slice(0, -1).join('/');
                if (!pathMap[folderPath]) {
                    pathMap[folderPath] = [];
                }
                pathMap[folderPath].push(file);
            } else {
                if (!pathMap['_root']) {
                    pathMap['_root'] = [];
                }
                pathMap['_root'].push(file);
            }
        });
        
        return pathMap;
    }

    resetUploadState() {
        this.isUploading = false;
        this.uploadProgress = 0;
        this.uploadedFiles = [];
        this.failedUploads = [];
        this.totalFilesToUpload = 0;
        this.currentFileUploading = '';
    }

    async uploadFiles(files) {
        if (!this.isAwsSdkInitialized) {
            this.showToast('Error', 'AWS SDK not initialized', 'error');
            return;
        }

        if (!files || files.length === 0) {
            this.showToast('Warning', 'No files selected', 'warning');
            return;
        }

        this.isUploading = true;
        this.uploadedFiles = [];
        this.failedUploads = [];
        this.totalFilesToUpload = files.length;
        
        console.log(`Starting upload of ${files.length} files to path: ${this.currentPath}`);

        await this.createFolderStructure(files);

        const totalFiles = files.length;
        let completedFiles = 0;

        for (const file of files) {
            try {
                this.currentFileUploading = file.name;
                await this.uploadSingleFile(file);
                this.uploadedFiles.push({
                    name: file.webkitRelativePath || file.name,
                    size: this.formatFileSize(file.size),
                    status: 'success'
                });
            } catch (error) {
                console.error(`Failed to upload ${file.name}:`, error);
                this.failedUploads.push({
                    name: file.webkitRelativePath || file.name,
                    size: this.formatFileSize(file.size),
                    error: error.message || 'Upload failed',
                    status: 'error'
                });
            }

            completedFiles++;
            this.uploadProgress = (completedFiles / totalFiles) * 100;
        }

        this.isUploading = false;
        this.currentFileUploading = '';

        const successCount = this.uploadedFiles.length;
        const failureCount = this.failedUploads.length;

        if (successCount > 0 && failureCount === 0) {
            this.showToast('Success', `Successfully uploaded ${successCount} file(s)`, 'success');
        } else if (successCount > 0 && failureCount > 0) {
            this.showToast('Warning', `Uploaded ${successCount} file(s), ${failureCount} failed`, 'warning');
        } else {
            this.showToast('Error', `Failed to upload ${failureCount} file(s)`, 'error');
        }

        setTimeout(() => {
            this.loadFilesAndFolders();
        }, 1000);
    }

    async createFolderStructure(files) {
        const foldersToCreate = new Set();
        
        files.forEach(file => {
            const relativePath = file.webkitRelativePath || file.name;
            const pathParts = relativePath.split('/');
            
            if (pathParts.length > 1) {
                let currentPath = this.currentPath;
                for (let i = 0; i < pathParts.length - 1; i++) {
                    currentPath += pathParts[i] + '/';
                    foldersToCreate.add(currentPath);
                }
            }
        });
        
        for (const folderPath of foldersToCreate) {
            try {
                await this.createFolderIfNotExists(folderPath);
            } catch (error) {
                console.warn(`Failed to create folder ${folderPath}:`, error);
            }
        }
    }

    createFolderIfNotExists(folderPath) {
        return new Promise((resolve, reject) => {
            const params = {
                Bucket: this.bucketname,
                Key: folderPath,
                Body: '',
                ContentType: 'application/x-directory'
            };

            this.s3.headObject({ Bucket: this.bucketname, Key: folderPath }, (err, data) => {
                if (err && err.code === 'NotFound') {
                    this.s3.putObject(params, (putErr, putData) => {
                        if (putErr) {
                            reject(putErr);
                        } else {
                            console.log(`Created folder: ${folderPath}`);
                            resolve(putData);
                        }
                    });
                } else if (err) {
                    reject(err);
                } else {
                    resolve(data);
                }
            });
        });
    }

    uploadSingleFile(file) {
        return new Promise((resolve, reject) => {
            const relativePath = file.webkitRelativePath || file.name;
            const fileKey = this.currentPath + relativePath;
            const existingFile = this.allItems.find(item => item.key === fileKey);
            if (existingFile) {
                const overwrite = confirm(`File "${relativePath}" already exists. Do you want to overwrite it?`);
                if (!overwrite) {
                    reject(new Error('Upload cancelled by user'));
                    return;
                }
            }

            const uploadParams = {
                Bucket: this.bucketname,
                Key: fileKey,
                Body: file,
                ContentType: file.type || 'application/octet-stream',
                Metadata: {
                    'uploaded-by': 'salesforce-lwc',
                    'upload-date': new Date().toISOString(),
                    'original-name': file.name,
                    'relative-path': relativePath
                }
            };

            console.log('Uploading file:', relativePath, 'to key:', fileKey);

            const upload = this.s3.upload(uploadParams);

            upload.on('httpUploadProgress', (progress) => {
                const percentComplete = Math.round((progress.loaded / progress.total) * 100);
                console.log(`Upload progress for ${relativePath}: ${percentComplete}%`);
            });

            upload.send((err, data) => {
                if (err) {
                    console.error('Upload error:', err);
                    reject(err);
                } else {
                    console.log('Upload success:', data);
                    resolve(data);
                }
            });
        });
    }

    createFolder() {
        const folderName = prompt('Enter folder name:');
        if (!folderName) {
            return;
        }

        if (folderName.includes('/') || folderName.includes('\\')) {
            this.showToast('Error', 'Folder name cannot contain slashes', 'error');
            return;
        }

        const folderKey = this.currentPath + folderName + '/';
        
        const existingFolder = this.allItems.find(item => item.key === folderKey);
        if (existingFolder) {
            this.showToast('Error', 'Folder already exists', 'error');
            return;
        }

        const params = {
            Bucket: this.bucketname,
            Key: folderKey,
            Body: '',
            ContentType: 'application/x-directory'
        };

        this.s3.putObject(params, (err, data) => {
            if (err) {
                console.error('Error creating folder:', err);
                this.showToast('Error', `Failed to create folder: ${err.message}`, 'error');
            } else {
                console.log('Folder created successfully:', data);
                this.showToast('Success', `Folder "${folderName}" created successfully`, 'success');
                this.loadFilesAndFolders();
            }
        });
    }

    handleDragOver(event) {
        event.preventDefault();
        event.stopPropagation();
        this.dragOver = true;
    }

    handleDragLeave(event) {
        event.preventDefault();
        event.stopPropagation();
        this.dragOver = false;
    }

    handleDrop(event) {
        event.preventDefault();
        event.stopPropagation();
        this.dragOver = false;
        
        const items = event.dataTransfer.items;
        const files = event.dataTransfer.files;
        
        if (items && items.length > 0) {
            this.handleDroppedItems(Array.from(items));
        } else if (files && files.length > 0) {
            this.uploadFiles(Array.from(files));
        }
    }

    async handleDroppedItems(items) {
        const allFiles = [];
        
        for (const item of items) {
            if (item.kind === 'file') {
                const entry = item.webkitGetAsEntry();
                if (entry) {
                    const files = await this.processDroppedEntry(entry, '');
                    allFiles.push(...files);
                }
            }
        }
        
        if (allFiles.length > 0) {
            this.uploadFiles(allFiles);
        }
    }

    processDroppedEntry(entry, path) {
        return new Promise((resolve) => {
            if (entry.isFile) {
                entry.file((file) => {
                    Object.defineProperty(file, 'webkitRelativePath', {
                        value: path + file.name,
                        writable: false
                    });
                    resolve([file]);
                });
            } else if (entry.isDirectory) {
                const dirReader = entry.createReader();
                dirReader.readEntries(async (entries) => {
                    const allFiles = [];
                    for (const childEntry of entries) {
                        const childFiles = await this.processDroppedEntry(childEntry, path + entry.name + '/');
                        allFiles.push(...childFiles);
                    }
                    resolve(allFiles);
                });
            } else {
                resolve([]);
            }
        });
    }

    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        
        switch (action.name) {
            case 'open':
                this.openFolder(row);
                break;
            case 'download':
                this.downloadFile(row);
                break;
            case 'preview':
                this.previewFile(row);
                break;
            case 'copyurl':
                this.copyFileUrl(row);
                break;
            case 'delete':
                this.deleteItem(row);
                break;
        }
    }

    handleRowSelection(event) {
        this.selectedItems = event.detail.selectedRows;
    }

    handleBreadcrumbClick(event) {
        event.preventDefault();
        const targetPath = event.target.name;
        this.navigateToPath(targetPath);
    }

    navigateToPath(path) {
        this.currentPath = path;
        this.loadFilesAndFolders();
    }

    openFolder(folder) {
        if (!folder.isFolder) {
            this.showToast('Info', 'This is not a folder', 'info');
            return;
        }
        
        console.log('Opening folder:', folder.name, 'Path:', folder.key);
        this.currentPath = folder.key;
        this.loadFilesAndFolders();
    }

    downloadFile(file) {
        if (file.isFolder) {
            this.showToast('Info', 'Cannot download folders', 'info');
            return;
        }

        try {
            const downloadUrl = this.s3.getSignedUrl('getObject', {
                Bucket: this.bucketname,
                Key: file.key,
                Expires: 300
            });

            const link = document.createElement('a');
            link.href = downloadUrl;
            link.download = file.name;
            link.style.display = 'none';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);

            this.showToast('Success', `Download started for ${file.name}`, 'success');
        } catch (error) {
            console.error('Error generating download URL:', error);
            this.showToast('Error', 'Failed to generate download URL', 'error');
        }
    }

    previewFile(file) {
        if (file.isFolder) {
            this.showToast('Info', 'Cannot preview folders', 'info');
            return;
        }

        try {
            const previewUrl = this.s3.getSignedUrl('getObject', {
                Bucket: this.bucketname,
                Key: file.key,
                Expires: 300
            });

            window.open(previewUrl, '_blank');
        } catch (error) {
            console.error('Error generating preview URL:', error);
            this.showToast('Error', 'Failed to generate preview URL', 'error');
        }
    }

    copyFileUrl(file) {
        if (file.isFolder) {
            this.showToast('Info', 'Cannot copy URL for folders', 'info');
            return;
        }

        try {
            const fileUrl = this.s3.getSignedUrl('getObject', {
                Bucket: this.bucketname,
                Key: file.key,
                Expires: 3600 // 1 hour
            });

            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(fileUrl).then(() => {
                    this.showToast('Success', 'File URL copied to clipboard', 'success');
                }).catch(() => {
                    this.fallbackCopyToClipboard(fileUrl);
                });
            } else {
                this.fallbackCopyToClipboard(fileUrl);
            }
        } catch (error) {
            console.error('Error generating file URL:', error);
            this.showToast('Error', 'Failed to generate file URL', 'error');
        }
    }

    fallbackCopyToClipboard(text) {
        const textArea = document.createElement('textarea');
        textArea.value = text;
        textArea.style.position = 'fixed';
        textArea.style.left = '-999999px';
        textArea.style.top = '-999999px';
        document.body.appendChild(textArea);
        textArea.focus();
        textArea.select();
        
        try {
            document.execCommand('copy');
            this.showToast('Success', 'File URL copied to clipboard', 'success');
        } catch (err) {
            this.showToast('Error', 'Failed to copy URL to clipboard', 'error');
        }
        
        document.body.removeChild(textArea);
    }

    deleteItem(item) {
        if (confirm(`Are you sure you want to delete ${item.name}?`)) {
            const params = {
                Bucket: this.bucketname,
                Key: item.key
            };

            this.s3.deleteObject(params, (err, data) => {
                if (err) {
                    console.error('Error deleting item:', err);
                    this.showToast('Error', `Failed to delete ${item.name}`, 'error');
                } else {
                    this.showToast('Success', `${item.name} deleted successfully`, 'success');
                    this.loadFilesAndFolders();
                }
            });
        }
    }

    formatFileSize(bytes) {
        if (!bytes || bytes === 0) return '0 Bytes';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }

    getFileExtension(filename) {
        return filename.split('.').pop().toLowerCase();
    }

    getFileType(extension) {
        const typeMap = {
            pdf: 'PDF',
            jpg: 'Image', jpeg: 'Image', png: 'Image', gif: 'Image', bmp: 'Image', svg: 'Image',
            doc: 'Document', docx: 'Document', txt: 'Text',
            xls: 'Spreadsheet', xlsx: 'Spreadsheet', csv: 'Spreadsheet',
            ppt: 'Presentation', pptx: 'Presentation',
            zip: 'Archive', rar: 'Archive', '7z': 'Archive', tar: 'Archive', gz: 'Archive',
            mp4: 'Video', avi: 'Video', mov: 'Video', wmv: 'Video', mkv: 'Video',
            mp3: 'Audio', wav: 'Audio', wma: 'Audio', flac: 'Audio'
        };
        return typeMap[extension] || 'File';
    }

    getFileIcon(extension) {
        const iconMap = {
            pdf: 'doctype:pdf',
            jpg: 'doctype:image', jpeg: 'doctype:image', png: 'doctype:image', gif: 'doctype:image', svg: 'doctype:image',
            doc: 'doctype:word', docx: 'doctype:word',
            txt: 'doctype:txt',
            xls: 'doctype:excel', xlsx: 'doctype:excel', csv: 'doctype:csv',
            ppt: 'doctype:ppt', pptx: 'doctype:ppt',
            zip: 'doctype:zip', rar: 'doctype:zip', '7z': 'doctype:zip',
            mp4: 'doctype:mp4', avi: 'doctype:mp4', mov: 'doctype:mp4',
            mp3: 'doctype:audio', wav: 'doctype:audio'
        };
        return iconMap[extension] || 'doctype:unknown';
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }
}