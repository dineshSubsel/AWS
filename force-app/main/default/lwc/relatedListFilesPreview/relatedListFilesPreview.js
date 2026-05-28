import { LightningElement, api, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getFilesByParentId from '@salesforce/apex/UploadedFileController.getFilesByParentId';
import getAWSConfiguration from '@salesforce/apex/AWSFileUploadHandlingController.getAWSConfiguration';
import fetchExistingFileNames from '@salesforce/apex/AWSFileUploadHandlingController.fetchExistingFileNames';
import recordInsert from '@salesforce/apex/UploadedFileController.recordInsert';
import deleteFile from '@salesforce/apex/UploadedFileController.deleteFile';
import getParentRecordName from '@salesforce/apex/UploadedFileController.getParentRecordName';
import AWS_SDK from '@salesforce/resourceUrl/AWSSDK';

export default class RelatedListFilesPreview extends LightningElement {
    @api recordId;
    @api objectApiName;

    // File data properties
    @track allFiles = [];
    @track files = [];
    @track filteredFiles = [];
    @track isViewAll = false;
    @track isFiltered = false;

    // Upload properties
    @track draggedFiles = [];
    @track showUploadPopup = false;
    @track uploadProgress = 0;
    @track isUploadDisabled = true;
    @track selectedFilesToUpload;
    @track fileName;
    @track filecount = 0;
    @track actualsize = 0;
    @track uploadloaded = false;
    @track fileUploading = false;

    // Delete properties
    @track showDeleteAllConfirmation = false;
    @track isDeletingAll = false;
    @track showDeleteConfirmation = false;
    @track selectedFileForDeletion = null;
    @track isDeletingFile = false;

    // AWS properties
    @track awsS3MetadataConfMain = {};
    @track s3;
    @track bucketname;
    @track baseurl;
    @track isAwsSdkInitialized = false;
    @track existingFileNamesList = [];
    @track parentRecordName = '';

    // Download properties
    @track showDownloadModal = false;
    @track selectedFile = {};
    @track downloadProgress = 0;
    @track downloadInProgress = false;
    @track downloadCompleted = false;
    @track downloadStatus = 'Ready to download';
    @track selectedFiles = [];

    // Preview properties
    @track showPreviewModal = false;
    @track selectedFileForPreview = null;
    @track previewUrl = '';
    @track previewError = false;
    @track previewLoading = true;

    // Filter properties
    @track searchKeyword = '';
    @track showFilter = false;
    @track selectedFilterField = '';
    @track selectedOperator = '';
    @track filterValue = '';
    @track filterFields = [
        { label: 'File Name', value: 'fileName' },
        { label: 'File Type', value: 'fileType' }
    ];
    @track operatorOptions = [];
    @track formattedFileSize = '';
    @track filterFieldError = false;
    @track filterOperatorError = false;
    @track filterValueError = false;
    @track filterFieldError = false;
    @track filterOperatorError = false;
    @track filterValueError = false;
    @track filterFieldTouched = false;
    @track filterOperatorTouched = false;
    @track filterValueTouched = false;
    @track searchFieldError = false;
    @track showFilterFields = true;

    // ─── Getters ──────────────────────────────────────────────────────────────

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

    get isDateField() {
        return this.selectedFilterField === 'createdDate';
    }

    get isFileTypeField() {
        return this.selectedFilterField === 'fileType';
    }

    get isTextField() {
        return this.selectedFilterField !== 'createdDate' &&
            this.selectedFilterField !== 'fileType';
    }

    // Disabled state for Value input when no filter field selected yet
    get isValueDisabled() {
        return !this.selectedFilterField;
    }

    // Placeholder for value input
    get filterValuePlaceholder() {
        return this.selectedFilterField ? 'Enter a value' : 'Enter a value';
    }

    // Clear button active only when a filter has been fully applied
    get isClearDisabled() {
        return !this.isFiltered &&
            !this.selectedFilterField &&
            !this.selectedOperator &&
            !this.filterValue;
    }

    get filterFieldClass() {
        return this.filterFieldError ? 'filter-error-border' : '';
    }
    get filterOperatorClass() {
        return this.filterOperatorError ? 'filter-error-border' : '';
    }
    get filterValueClass() {
        return this.filterValueError ? 'filter-error-border' : '';
    }

    get filterFieldClass() {
        return this.filterFieldError ? 'slds-has-error' : '';
    }
    get filterOperatorClass() {
        return this.filterOperatorError ? 'slds-has-error' : '';
    }
    get filterValueClass() {
        return this.filterValueError ? 'slds-has-error' : '';
    }

    // Error class getters for comboboxes
    get filterFieldComboClass() {
        return this.filterFieldError ? 'combo-error' : '';
    }

    get filterOperatorComboClass() {
        return this.filterOperatorError ? 'combo-error' : '';
    }

    // Value field error classes — shows red border when filter name selected but value empty
    get filterValueComboClass() {
        return this.filterValueError ? 'combo-error' : '';
    }

    get filterValueInputClass() {
        return this.filterValueError ? 'input-error' : '';
    }

    get showViewToggle() {
        const source = this.isFiltered ? this.filteredFiles : this.allFiles;
        return source.length > 5;
    }

    get searchInputClass() {
        return this.searchFieldError ? 'slds-input search-input-error' : 'slds-input';
    }

    get noFilesFound() {
        return this.files && this.files.length === 0 &&
            (this.searchKeyword || this.isFiltered);
    }

    // ─── Lifecycle ────────────────────────────────────────────────────────────

    connectedCallback() {
        this.files = this.allFiles.slice(0, 5);

        if (this.recordId) {
            this.loadAWSConfiguration();
            this.loadFiles();
            this.fetchExistingFileNamesMethod();
            this.loadParentRecordName();
        }
    }

    renderedCallback() {
        if (this.isAwsSdkInitialized) return;

        loadScript(this, AWS_SDK)
            .then(() => {
                if (this.awsS3MetadataConfMain && Object.keys(this.awsS3MetadataConfMain).length > 0) {
                    this.initializeAwsSdk(this.awsS3MetadataConfMain);
                }
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load AWS SDK', 'error');
            });
    }

    // ─── AWS Configuration Methods ────────────────────────────────────────────

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
                    if (window.AWS) {
                        this.initializeAwsSdk(this.awsS3MetadataConfMain);
                    }
                }
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load AWS configuration', 'error');
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
            apiVersion: confData.apiVersion,
            signatureVersion: confData.signatureVersion,
            params: { Bucket: confData.s3bucketName }
        });
        this.isAwsSdkInitialized = true;
    }

    // ─── File Management Methods ──────────────────────────────────────────────

    loadFiles() {
        getFilesByParentId({ parentId: this.recordId })
            .then(data => {
                const uniqueMap = new Map();

                data.forEach(file => {
                    const uniqueKey = file.fileName;
                    if (!uniqueMap.has(uniqueKey)) {
                        uniqueMap.set(uniqueKey, file);
                    }
                });

                this.allFiles = Array.from(uniqueMap.values()).map(file => {
                    const fileName = file.fileName || '';
                    const extension = fileName.split('.').pop().toLowerCase();

                    let iconName = 'doctype:unknown';
                    let isImage = false;

                    switch (extension) {
                        case 'pdf': iconName = 'doctype:pdf'; break;
                        case 'doc':
                        case 'docx': iconName = 'doctype:word'; break;
                        case 'xls':
                        case 'xlsx': iconName = 'doctype:excel'; break;
                        case 'ppt':
                        case 'pptx': iconName = 'doctype:ppt'; break;
                        case 'jpg':
                        case 'jpeg':
                        case 'png':
                        case 'gif':
                        case 'webp':
                            iconName = 'doctype:image';
                            isImage = true;
                            break;
                    }

                    return {
                        ...file,
                        fileLink: `/lightning/r/${file.id}/view`,
                        fileIcon: iconName,
                        isImagePreview: isImage && !!file.fileURL,
                        selected: false,
                        createdByName: 'Current User'
                    };

                }).sort((a, b) => {
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

    fetchExistingFileNamesMethod() {
        fetchExistingFileNames({ parentId: this.recordId })
            .then((result) => {
                this.existingFileNamesList = result.map(item => item.fileName);
            })
            .catch(error => {
                this.showToast('Error', error.message, 'error');
            });
    }

    async loadParentRecordName() {
        if (this.recordId && this.objectApiName) {
            try {
                this.parentRecordName = await getParentRecordName({
                    recordId: this.recordId,
                    objectApiName: this.objectApiName
                });
            } catch (error) {
            }
        }
    }

    // ─── Search & Filter Handlers ─────────────────────────────────────────────

    handleSearchBlur() {
        this.searchFieldError = !this.searchKeyword || !this.searchKeyword.trim();
    }

    handleInputChange(event) {
        this.searchKeyword = event.target.value;
        if (this.searchKeyword && this.searchKeyword.trim()) {
            this.searchFieldError = false;
        } else {
            this.files = this.allFiles.slice(0, 5);
        }
        this.applyFilters();
    }

    // Apply button handler — validates filter if open, then applies
    handleSearch() {
        if (this.showFilter) {
            const isValid = this.validateFilterFields();
            if (!isValid) return;
        }
        this.applyFilters();
    }

    resetFilterState() {
        this.selectedFilterField = '';
        this.selectedOperator = '';
        this.filterValue = '';
        this.filterFieldError = false;
        this.filterOperatorError = false;
        this.filterValueError = false;
        this.filterFieldTouched = false;
        this.filterOperatorTouched = false;
        this.filterValueTouched = false;
        this.isFiltered = false;
        this.operatorOptions = [];
    }

    // Clear resets only filter fields, not the search keyword
    handleClearFilter() {
        this.resetFilterState();
        this.isFiltered = false;
        this.showFilter = false;
        Promise.resolve().then(() => {
            this.showFilter = true;
        });
        this.applyFilters();
    }


    isFilterComplete() {
        return this.showFilter &&
            this.selectedFilterField &&
            this.selectedOperator &&
            this.filterValue;
    }

    validateFilterFields() {
        this.filterFieldTouched = true;
        this.filterOperatorTouched = true;
        this.filterValueTouched = true;
        this.filterFieldError = !this.selectedFilterField;
        this.filterOperatorError = !this.selectedOperator;

        // Only validate value if the field is NOT disabled (i.e., a filter field is selected)
        if (this.selectedFilterField) {
            this.filterValueError = !this.filterValue || !this.filterValue.trim();
        } else {
            this.filterValueError = false;
        }

        if (this.filterFieldError || this.filterOperatorError || this.filterValueError) {
            this.showToast('Field Missing', 'Please Complete the Missing Fields', 'error');
            return false;
        }
        return true;
    }

    toggleFilter() {
        if (this.showFilter) {
            this.resetFilterState();
            this.showFilter = false;
            this.applyFilters();
        } else {
            if (!this.searchKeyword || !this.searchKeyword.trim()) {
                this.searchFieldError = true;
                return;
            }
            this.searchFieldError = false;
            this.showFilter = true;
        }
    }

    handleFilterFieldBlur() {
        this.filterFieldTouched = true;
        this.filterFieldError = !this.selectedFilterField;
        if (this.filterOperatorTouched) {
            this.filterOperatorError = !this.selectedOperator;
        }
    }

    handleOperatorBlur() {
        this.filterOperatorTouched = true;
        this.filterOperatorError = !this.selectedOperator;
        if (!this.selectedFilterField) {
            this.filterFieldTouched = true;
            this.filterFieldError = true;
        }
        if (this.filterValueTouched) {
            this.filterValueError = !this.filterValue || !this.filterValue.trim();
        }
    }

    handleValueBlur() {
        this.filterValueTouched = true;
        if (this.selectedFilterField) {
            this.filterValueError = !this.filterValue || !this.filterValue.trim();
        } else {
            this.filterValueError = false;
        }
        if (!this.selectedFilterField) {
            this.filterFieldTouched = true;
            this.filterFieldError = true;
        }
        if (!this.selectedOperator && this.selectedFilterField) {
            this.filterOperatorTouched = true;
            this.filterOperatorError = true;
        }
    }

    handleFieldChange(event) {
        this.selectedFilterField = event.detail.value;
        this.filterFieldError = false;
        this.filterOperatorError = false;
        this.filterValueError = false;
        this.selectedOperator = '';
        this.filterValue = '';
        this.updateOperatorOptions();
    }

    handleOperatorChange(event) {
        this.selectedOperator = event.detail.value;
        this.filterOperatorError = false;
        this.filterValueError = false;
        this.filterValue = '';
    }

    handleValueChange(event) {
        this.filterValue = event.detail ? event.detail.value : event.target.value;
        if (this.filterValue && this.filterValue.trim()) {
            this.filterValueError = false;
        }
    }

    updateOperatorOptions() {
        if (this.selectedFilterField === 'createdDate') {
            this.operatorOptions = [
                { label: 'equals', value: 'equals' },
                { label: 'not equals', value: 'notEquals' },
                { label: 'greater than', value: 'greaterThan' },
                { label: 'less than', value: 'lessThan' }
            ];
        } else if (this.selectedFilterField === 'fileType') {
            this.operatorOptions = [
                { label: 'equals', value: 'equals' },
                { label: 'not equals', value: 'notEquals' }
            ];
        } else {
            this.operatorOptions = [
                { label: 'equals', value: 'equals' },
                { label: 'not equals', value: 'notEquals' },
                { label: 'contains', value: 'contains' },
                { label: 'starts with', value: 'startsWith' },
                { label: 'ends with', value: 'endsWith' }
            ];
        }
        this.selectedOperator = '';
        this.filterValue = '';
    }

    fileTypeOptions = [
        { label: 'PDF', value: 'pdf' },
        { label: 'PNG', value: 'png' },
        { label: 'JPG', value: 'jpg' },
        { label: 'JPEG', value: 'jpeg' },
        { label: 'DOCX', value: 'docx' },
        { label: 'DOC', value: 'doc' },
        { label: 'XLSX', value: 'xlsx' },
        { label: 'XLS', value: 'xls' },
        { label: 'PPT', value: 'ppt' },
        { label: 'PPTX', value: 'pptx' },
        { label: 'TXT', value: 'txt' },
        { label: 'CSV', value: 'csv' },
        { label: 'ZIP', value: 'zip' },
        { label: 'Other', value: 'other' }
    ];

    applyFilters() {
        let results = [...this.allFiles];

        // Apply search keyword filter
        if (this.searchKeyword && this.searchKeyword.trim()) {
            const keyword = this.searchKeyword.toLowerCase().trim();
            results = results.filter(file =>
                file.fileName && file.fileName.toLowerCase().includes(keyword)
            );
        }

        // Apply advanced filter if all fields are filled
        if (this.selectedFilterField && this.selectedOperator && this.filterValue) {
            results = this.applyAdvancedFilter(results);
            this.isFiltered = true;
        } else {
            this.isFiltered = false;
        }

        this.filteredFiles = results;
        this.files = this.isViewAll ? results : results.slice(0, 5);
    }

    applyAdvancedFilter(files) {
        return files.filter(file => {
            const fieldValue = this.getFieldValue(file, this.selectedFilterField);
            return this.compareValues(fieldValue, this.filterValue, this.selectedOperator);
        });
    }

    getFieldValue(file, fieldName) {
        switch (fieldName) {
            case 'createdDate':
                return file.createdDate;
            case 'fileType':
                return (file.fileName || '').split('.').pop().toLowerCase();
            default:
                return file[fieldName] || '';
        }
    }

    compareValues(fieldValue, filterValue, operator) {
        if (this.selectedFilterField === 'CreatedDate') {
            return this.compareDates(fieldValue, filterValue, operator);
        }
        return this.compareStrings(fieldValue, filterValue, operator);
    }

    compareStrings(fieldValue, filterValue, operator) {
        const field = (fieldValue || '').toString().toLowerCase();
        const filter = (filterValue || '').toString().toLowerCase();

        switch (operator) {
            case 'equals': return field === filter;
            case 'notEquals': return field !== filter;
            case 'contains': return field.includes(filter);
            case 'startsWith': return field.startsWith(filter);
            case 'endsWith': return field.endsWith(filter);
            default: return true;
        }
    }

    compareDates(fieldValue, filterValue, operator) {
        if (!fieldValue || !filterValue) return false;

        const fieldDate = new Date(fieldValue);
        const filterDate = new Date(filterValue);
        fieldDate.setHours(0, 0, 0, 0);
        filterDate.setHours(0, 0, 0, 0);

        switch (operator) {
            case 'equals': return fieldDate.getTime() === filterDate.getTime();
            case 'notEquals': return fieldDate.getTime() !== filterDate.getTime();
            case 'greaterThan': return fieldDate.getTime() > filterDate.getTime();
            case 'lessThan': return fieldDate.getTime() < filterDate.getTime();
            default: return true;
        }
    }

    handleFilterApply() {
        this.applyFilters();
        this.showToast('Filter Applied', `Found ${this.filteredFiles.length} matching files`, 'success');
    }

    handleFilterReset() {
        this.selectedFilterField = '';
        this.selectedOperator = '';
        this.filterValue = '';
        this.isFiltered = false;
        this.applyFilters();
        this.showToast('Filters Reset', 'All filters have been cleared', 'success');
    }

    // ─── View Toggle Methods ──────────────────────────────────────────────────

    handleViewToggle() {
        this.isViewAll = !this.isViewAll;
        this.files = this.isViewAll ?
            (this.isFiltered ? this.filteredFiles : this.allFiles) :
            (this.isFiltered ? this.filteredFiles.slice(0, 5) : this.allFiles.slice(0, 5));
    }

    // ─── File Selection Methods ───────────────────────────────────────────────

    handleFileSelection(event) {
        const fileId = event.target.dataset.id;
        const isChecked = event.target.checked;

        this.files = this.files.map(file => {
            if (file.Id === fileId) {
                return { ...file, selected: isChecked };
            }
            return file;
        });
    }

    toggleSelectAll(event) {
        const isChecked = event.target.checked;
        this.files = this.files.map(file => ({ ...file, selected: isChecked }));
    }

    // ─── File Action Methods ──────────────────────────────────────────────────

    handleFileMenuSelect(event) {
        const action = event.detail.value;
        const fileId = event.target.dataset.fileId;
        const file = this.allFiles.find(f => f.id === fileId);
        if (!file) return;
        switch (action) {
            case 'preview':
                this.openPreviewModal(file);
                break;
            case 'download':
                this.openDownloadModal(file);
                break;
            case 'delete':
                this.selectedFileForDeletion = file;
                this.showDeleteConfirmation = true;
                break;
            case 'copy':
                this.copyToClipboard(file.fileUrl);
                break;
        }
    }

    handleMenuSelect(event) {
        switch (event.detail.value) {
            case 'deleteAll':
                this.handleDeleteAll();
                break;
            case 'bulkDelete':
                this.handleBulkDelete();
                break;
        }
    }

    // ─── Bulk Actions ─────────────────────────────────────────────────────────

    handleBulkDelete() {
        const selectedFiles = this.files.filter(file => file.selected);
        if (selectedFiles.length === 0) {
            this.showToast('Warning', 'No files selected', 'warning');
            return;
        }

        this.isDeletingFile = true;
        Promise.all(selectedFiles.map(file => this.handleFileDeleteMethod(file)))
            .then(() => {
                this.loadFiles();
                this.showToast('Success', `${selectedFiles.length} files deleted`, 'success');
            })
            .catch(error => {
                this.showToast('Error', 'Error deleting files', 'error');
            })
            .finally(() => {
                this.isDeletingFile = false;
            });
    }

    // ─── File Delete Methods ──────────────────────────────────────────────────

    handleDeleteAll() {
        this.showDeleteAllConfirmation = true;
    }

    confirmDeleteAll() {
        this.isDeletingAll = true;
        Promise.all(this.allFiles.map(file => this.handleFileDeleteMethod(file)))
            .then(() => {
                this.loadFiles();
                this.showToast('Success', 'All files deleted', 'success');
                this.closeDeleteAllConfirmation();
            })
            .catch(error => {
                this.showToast('Error', 'Error deleting files', 'error');
            })
            .finally(() => {
                this.isDeletingAll = false;
            });
    }

    closeDeleteAllConfirmation() {
        this.showDeleteAllConfirmation = false;
    }

    confirmDeleteFile() {
        if (!this.selectedFileForDeletion) return;

        this.isDeletingFile = true;
        this.handleFileDeleteMethod(this.selectedFileForDeletion)
            .then(() => {
                this.loadFiles();
                this.showToast('Success', 'File deleted', 'success');
                this.closeDeleteConfirmation();
            })
            .catch(error => {
                this.showToast('Error', 'Error deleting file', 'error');
            })
            .finally(() => {
                this.isDeletingFile = false;
            });
    }

    closeDeleteConfirmation() {
        this.showDeleteConfirmation = false;
        this.selectedFileForDeletion = null;
    }

    handleFileDeleteMethod(file) {
        return new Promise((resolve, reject) => {
            const objectKey = file.objectKey ||
                this.generateObjectKey(file.fileName);
            if (objectKey) {
                this.s3.deleteObject({ Bucket: this.bucketname, Key: objectKey }, (err) => {
                    if (err && err.code !== 'NoSuchKey') {
                    }
                    this.deleteSalesforceRecord(file.id, resolve, reject);
                });
            } else {
                this.deleteSalesforceRecord(file.id, resolve, reject);
            }
        });
    }

    deleteSalesforceRecord(fileId, resolve, reject) {
        deleteFile({ fileId })
            .then(() => resolve())
            .catch(error => reject(error));
    }

    generateObjectKey(fileName) {
        if (!fileName || !this.objectApiName || !this.recordId) return null;
        return `${this.objectApiName}/${this.recordId}/${fileName.replace(/\s+/g, "_").toLowerCase()}`;
    }

    getObjectKeyFromFile(file) {
        if (file && file.objectKey) return file.objectKey;
        return null;
    }

    // ─── Upload Methods ───────────────────────────────────────────────────────

    handleUpload() {
        this.showUploadPopup = true;
        this.fileUploading = false;
    }

    closeUploadPopup() {
        this.showUploadPopup = false;
        this.draggedFiles = [];
        this.selectedFiles = [];
    }

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
        this.processSelectedFiles(Array.from(event.dataTransfer.files));
    }

    openFileDialog() {
        this.template.querySelector('.file-input-hidden').click();
    }

    handleFileInputChange(event) {
        this.processSelectedFiles(Array.from(event.target.files));
    }

    processSelectedFiles(files) {
        this.selectedFiles = files;
        this.draggedFiles = files.map(file => ({
            name: file.name,
            size: this.formatFileSize(file.size),
            file: file,
            progress: 0
        }));
        this.isUploadDisabled = files.length === 0;
    }

    removeFile(event) {
        const index = event.target.dataset.index;
        this.draggedFiles.splice(index, 1);
        this.selectedFiles.splice(index, 1);
        this.isUploadDisabled = this.draggedFiles.length === 0;
    }

    proceedWithUpload() {
        if (this.draggedFiles.length === 0) return;

        const duplicateFiles = this.selectedFiles.filter(file =>
            this.existingFileNamesList.includes(file.name)
        );

        if (duplicateFiles.length > 0) {
            const names = duplicateFiles.map(f => f.name).join(', ');
            this.showToast('Error', `Duplicate files detected: ${names}`, 'error');
            return;
        }

        this.isUploadDisabled = true;
        this.fileUploading = true;
        this.actualsize = this.draggedFiles.length;
        this.filecount = 0;

        this.draggedFiles.forEach((item, index) => {
            const file = item.file;

            this.uploadToAWS(file, index)
                .then(() => {
                    this.filecount++;
                    if (this.filecount === this.actualsize) {
                        this.showToast('Success', 'All files uploaded', 'success');
                        this.closeUploadPopup();
                    }
                })
                .catch(error => {
                });
        });
    }

    uploadToAWS(file, index) {
        return new Promise((resolve, reject) => {
            const objectKey = this.generateObjectKey(file.name);
            if (!objectKey) {
                reject('Invalid file name');
                return;
            }

            const presignedUrl = this.s3.getSignedUrl('putObject', {
                Key: objectKey,
                ContentType: file.type,
                Expires: 600
            });

            const xhr = new XMLHttpRequest();
            xhr.open('PUT', presignedUrl, true);

            xhr.upload.onprogress = (event) => {
                if (event.lengthComputable) {
                    const percent = Math.round((event.loaded / event.total) * 100);
                    this.draggedFiles[index].progress = percent;
                    this.draggedFiles[index].style = `width: ${percent}%;`;
                }
            };

            xhr.onload = () => {
                if (xhr.status === 200) {
                    this.trackSuccess(file, objectKey);
                    resolve();
                } else {
                    reject(`Upload failed with status ${xhr.status}`);
                }
            };

            xhr.onerror = () => reject('Upload failed');
            xhr.send(file);
        });
    }

    trackSuccess(file, objectKey) {
        const fileUrl = this.s3.getSignedUrl('getObject', {
            Bucket: this.bucketname,
            Key: objectKey,
            Expires: 604800
        });

        recordInsert({
            parentObjectApiName: this.objectApiName,
            parentRecordName: this.parentRecordName,
            parentId: this.recordId,
            fileName: file.name,
            fileURL: fileUrl,
            filetype: file.type,
            objKey: objectKey,
            filesize: file.size,
            folderId: null
        })
            .then(() => {
                this.existingFileNamesList.push(file.name);
                this.loadFiles();
            })
            .catch(error => {
            });
    }

    // ─── Download Methods ─────────────────────────────────────────────────────

    openDownloadModal(file) {
        this.selectedFile = file;
        this.formattedFileSize = this.formatFileSize(parseFloat(file.fileSize) || 0);
        this.showDownloadModal = true;
        this.downloadProgress = 0;
        this.downloadInProgress = false;
        this.downloadCompleted = false;
        this.downloadStatus = 'Ready to download';
        this.startDownload();
    }

    closeDownloadModal() {
        this.showDownloadModal = false;
    }

    startDownload() {
        this.downloadInProgress = true;
        this.downloadStatus = 'Downloading...';
        this.simulateDownloadProgress();
        this.isUploadDisabled = true;
    }

    simulateDownloadProgress() {
        let progress = 0;
        const interval = setInterval(() => {
            progress += Math.random() * 20;
            if (progress >= 100) {
                progress = 100;
                clearInterval(interval);
                this.downloadProgress = progress;
                this.downloadCompleted = true;
                this.downloadInProgress = false;
                this.downloadStatus = 'Completed';
                this.performDownload();
            } else {
                this.downloadProgress = Math.floor(progress);
            }
        }, 150);
    }

    async performDownload() {
        try {
            const objectKey = this.getObjectKeyFromFile(this.selectedFile) ||
                this.generateObjectKey(this.selectedFile.fileName);
            if (!objectKey) throw new Error('Could not determine file key');
            const downloadUrl = this.s3.getSignedUrl('getObject', {
                Bucket: this.bucketname,
                Key: objectKey,
                Expires: 300
            });
            const response = await fetch(downloadUrl);
            const blob = await response.blob();
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = this.selectedFile.fileName;
            document.body.appendChild(a);
            a.click();
            window.URL.revokeObjectURL(url);
            document.body.removeChild(a);

            setTimeout(() => this.closeDownloadModal(), 1000);
        } catch (error) {
            this.showToast('Error', 'Download failed', 'error');
            this.downloadStatus = 'Failed';
        }
    }

    // ─── Preview Methods ──────────────────────────────────────────────────────

    openPreviewModal(file) {
        this.selectedFileForPreview = file;
        this.showPreviewModal = true;
        this.previewError = false;
        this.previewLoading = true;
        this.generatePreviewUrl(file);
    }

    generatePreviewUrl(file) {
        try {
            const objectKey = this.getObjectKeyFromFile(file) ||
                this.generateObjectKey(file.fileName);

            if (!objectKey) throw new Error('Could not determine file key');

            this.previewUrl = this.s3.getSignedUrl('getObject', {
                Bucket: this.bucketname,
                Key: objectKey,
                Expires: 300
            });
            this.previewLoading = false;
        } catch (error) {
            this.previewError = true;
            this.previewLoading = false;
            this.showToast('Error', 'Preview failed', 'error');
        }
    }

    openFileInNewTab() {
        if (this.previewUrl) {
            window.open(this.previewUrl, '_blank');
        }
    }

    closePreviewModal() {
        this.showPreviewModal = false;
        this.selectedFileForPreview = null;
        this.previewUrl = '';
        this.previewError = false;
        this.previewLoading = true;
    }

    handleImageError() {
        this.previewError = true;
    }

    get isImageFile() {
        if (!this.selectedFileForPreview) return false;
        const fileName = this.selectedFileForPreview.fileName || '';
        const ext = fileName.split('.').pop().toLowerCase();
        return ['jpg', 'jpeg', 'png', 'gif', 'webp'].includes(ext);
    }

    get fileTypeIcon() {
        if (!this.selectedFileForPreview) return 'doctype:unknown';
        return this.selectedFileForPreview.fileIcon || 'doctype:unknown';
    }

    get fileExtension() {
        if (!this.selectedFileForPreview) return '';
        const fileName = this.selectedFileForPreview.fileName || '';
        return fileName.split('.').pop().toUpperCase();
    }

    // ─── Utility Methods ──────────────────────────────────────────────────────

    copyToClipboard(text) {
        if (!text) return;

        if (navigator.clipboard) {
            navigator.clipboard.writeText(text)
                .catch();
        } else {
            const textarea = document.createElement('textarea');
            textarea.value = text;
            document.body.appendChild(textarea);
            textarea.select();
            document.execCommand('copy');
            document.body.removeChild(textarea);
        }

        this.showToast('Success', 'Copied to clipboard', 'success');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }

    formatFileSize(bytes) {
        if (bytes === 0) return '0 Bytes';
        if (!bytes) return '';

        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }
}