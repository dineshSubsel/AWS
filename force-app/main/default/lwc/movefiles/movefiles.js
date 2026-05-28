import { LightningElement, api, track, wire } from 'lwc';
import moveFilesToTargetObject from '@salesforce/apex/TargetObjectFileTransfer.moveFilesToTargetObject';
import getAllSObjects from '@salesforce/apex/FileMigrationHandler.getAllSObjects';
import searchRecords from '@salesforce/apex/TargetObjectFileTransfer.searchRecords';
import fetchFilesForRecord from '@salesforce/apex/TargetObjectFileTransfer.fetchFilesForRecord';
import checkObjectSupportsFiles from '@salesforce/apex/TargetObjectFileTransfer.checkObjectSupportsFiles';
import getRecordCountForObject from '@salesforce/apex/TargetObjectFileTransfer.getRecordCountForObject';
import getObjectManagerObjects from '@salesforce/apex/FileMigrationHandler.getObjectManagerObjects';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class MoveFilesComponent extends LightningElement {
    @api recordId;
    @track targetObjectApiName = '';
    @track targetRecordId = '';
    @track selectedFileIds = [];
    @track objectOptions = [];
    @track searchKey = '';
    @track searchResults = [];
    @track selectedRecordName = '';
    @track availableFiles = [];
    @track dropdownOpen = false;
    @track selectedFileId = '';
    @track hasNoFiles = false;
    @track noRecordsFound = false;
    @track isSearching = false;
    @track sourceFileError = '';
    @track targetObjectError = '';
    @track targetRecordError = '';

    objectCount = 0;
    _outsideClickHandler = null;

    @wire(getAllSObjects)
    wiredSObjects({ error, data }) {
        if (data) {
            this.objectOptions = data.map(obj => ({
                label: obj.label,
                value: obj.value
            }));
        } else if (error) {
            this.showToast('Error', 'Failed to load object list', 'error');
        }
    }

    @wire(getObjectManagerObjects)
    wiredObjectManagerObjects({ error, data }) {
        if (data) {
            this.objectOptions = data.objects;
            this.objectCount = data.count;
        } else if (error) {
            
        }
    }

    connectedCallback() {
        if (this.recordId) {
            fetchFilesForRecord({ recordId: this.recordId })
                .then(result => {
                    this.availableFiles = result.map(file => ({
                        id: file.ContentDocumentId,
                        name: file.Title + '.' + file.FileExtension
                    }));
                })
                .catch(error => {
                    this.showToast('Error', 'Failed to load source files: ' + error.body.message, 'error');
                });
        }

        this._outsideClickHandler = this.handleOutsideClick.bind(this);
        document.addEventListener('click', this._outsideClickHandler);
    }

    disconnectedCallback() {
        document.removeEventListener('click', this._outsideClickHandler);
    }

    get isSearchDisabled() {
        return this.hasNoFiles || this.noRecordsFound;
    }

    handleOutsideClick(event) {
        const dropdownBox = this.template.querySelector('.dropdown-box');
        const dropdownOptions = this.template.querySelector('.dropdown-options');

        if (
            this.dropdownOpen &&
            dropdownBox && !dropdownBox.contains(event.target) &&
            dropdownOptions && !dropdownOptions.contains(event.target)
        ) {
            this.dropdownOpen = false;
            if (this.targetObjectApiName && this.targetRecordId && this.selectedFileIds.length === 0) {
                this.sourceFileError = 'Select Atleast One File';
            }
        }
        const searchWrapper = this.template.querySelector('.search-results-wrapper');
        const searchInput = this.template.querySelector('lightning-input');
        if (
            this.searchResults.length > 0 &&
            searchWrapper &&
            !searchWrapper.contains(event.target) &&
            searchInput &&
            !searchInput.contains(event.target)
        ) {
            this.searchResults = [];
        }
    }

    handleTargetObjectChange(event) {

        this.targetObjectApiName = event.detail.value;


        this.sourceFileError = '';
        this.targetObjectError = '';
        this.targetRecordError = '';

        this.searchResults = [];
        this.searchKey = '';
        this.targetRecordId = '';
        this.selectedRecordName = '';
        this.hasNoFiles = false;
        this.noRecordsFound = false;

        if (this.targetObjectApiName) {
            checkObjectSupportsFiles({ objectApiName: this.targetObjectApiName })
                .then(result => {
                    this.hasNoFiles = !result;
                    if (this.hasNoFiles) {
                        this.dropdownOpen = false;
                        this.selectedFileIds = [];
                        return null;
                    }
                    return getRecordCountForObject({ objectApiName: this.targetObjectApiName });
                })
                .then(count => {
                    if (count !== null && count === 0) {
                        this.noRecordsFound = true;
                    }
                })
                .catch(() => {
                    this.hasNoFiles = true;
                    this.dropdownOpen = false;
                    this.selectedFileIds = [];
                });
        }
    }

    handleSearchKeyChange(event) {
        this.searchKey = event.detail.value;
        this.targetRecordError = '';

        if (this.hasNoFiles || this.noRecordsFound) {
            this.searchResults = [];
            return;
        }

        if (this.searchKey.length > 1 && this.targetObjectApiName) {
            this.isSearching = true;
            searchRecords({
                searchKey: this.searchKey,
                objectApiName: this.targetObjectApiName
            })
                .then(result => {
                    this.searchResults = result.map(item => ({
                        label: item.label,
                        value: item.Id,
                        isDisabled: item.Id === this.recordId,
                        itemClass: item.Id === this.recordId
                            ? 'search-result-item search-result-item--disabled'
                            : 'search-result-item'
                    }));
                })
                .catch(() => {
                    this.searchResults = [];
                })
                .finally(() => {
                    this.isSearching = false;
                });
        } else {
            this.isSearching = false;
            this.searchResults = [];
        }
    }

    handleSelectRecord(event) {
        const selectedId = event.currentTarget.dataset.id;
        const isDisabled = event.currentTarget.dataset.disabled === 'true';
        if (isDisabled || selectedId === this.recordId) {
            this.showToast('Warning', 'Cannot move files to the same record.', 'warning');
            return;
        }

        const selected = this.searchResults.find(item => item.value === selectedId);
        this.targetRecordId = selectedId;
        this.selectedRecordName = selected?.label || '';
        this.searchResults = [];
        this.searchKey = '';
        this.selectedFileIds = [];
        this.isSearching = false;
        this.sourceFileError = '';
        this.targetRecordError = '';

    }

    resetSelectedContact() {
        this.targetRecordId = '';
        this.selectedRecordName = '';
        this.searchKey = '';
        this.searchResults = [];
    }

    handleDropdownClick(event) {
        event.stopPropagation(); // ADD THIS — prevents outside click from firing immediately

        if (!this.targetObjectApiName) {
            this.targetObjectError = 'Select/Choose a Target Object';
            return;
        }

        if (!this.targetRecordId) {
            this.targetRecordError = 'Select/Choose a Record';
            return;
        }

        if (this.hasNoFiles || this.noRecordsFound) return;

        this.sourceFileError = '';
        this.dropdownOpen = !this.dropdownOpen;
    }







    handleOptionClick(event) {
        const fileId = event.currentTarget.dataset.id;
        if (this.selectedFileIds.includes(fileId)) {
            this.selectedFileIds = this.selectedFileIds.filter(id => id !== fileId);
        } else {
            this.selectedFileIds = [...this.selectedFileIds, fileId];
        }
        if (this.selectedFileIds.length === 1) {
            this.selectedFileId = this.selectedFileIds[0];
        } else {
            this.selectedFileId = '';
        }
        this.sourceFileError = '';
        this.dropdownOpen = false;
    }

    handleRemoveSingleFile(event) {
        const fileIdToRemove = event.currentTarget.dataset.id;
        this.selectedFileIds = this.selectedFileIds.filter(id => id !== fileIdToRemove);
    }

    handleSelectAll() {
        if (!this.isSelectAllActive) return;
        this.selectedFileIds = this.availableFiles.map(file => file.id);
        this.dropdownOpen = false;
        this.sourceFileError = ''; // ADD THIS
    }

    handleClearSelection() {
        if (!this.isClearActive) return;
        this.selectedFileIds = [];
        this.dropdownOpen = false;
    }

    handleMoveFiles() {
        if (this.isMoveDisabled) return;

        if (!this.recordId || !this.targetObjectApiName || !this.targetRecordId || this.selectedFileIds.length === 0) {
            this.showToast('Error', 'Please fill in all required fields.', 'error');
            return;
        }

        let hasError = false;
        if (!this.targetObjectApiName) {
            this.targetObjectError = 'Please First choose Target Object';
            hasError = true;
        } else {
            this.targetObjectError = '';
        }
        if (!this.targetRecordId) {
            this.targetRecordError = 'Please Choose Record First';
            hasError = true;
        } else {
            this.targetRecordError = '';
        }
        if (this.selectedFileIds.length === 0) {
            this.sourceFileError = 'Select Atleast One File';
            hasError = true;
        } else {
            this.sourceFileError = '';
        }

        if (hasError) return;

        this.sourceFileError = '';


        moveFilesToTargetObject({
            sourceRecordId: this.recordId,
            targetObjectApiName: this.targetObjectApiName,
            targetRecordId: this.targetRecordId,
            selectedContentDocumentIds: this.selectedFileIds
        })
            .then(result => {
                this.showToast('Success', result, 'success');
                return fetchFilesForRecord({ recordId: this.recordId });
            })
            .then(updatedFiles => {
                this.availableFiles = updatedFiles.map(file => ({
                    id: file.ContentDocumentId,
                    name: file.Title + '.' + file.FileExtension
                }));
                this.handleCancel();
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || error.message, 'error');
            });
    }

    handleCancel() {
        this.targetObjectApiName = '';
        this.targetRecordId = '';
        this.searchKey = '';
        this.selectedRecordName = '';
        this.searchResults = [];
        this.selectedFileIds = [];
        this.selectedFileId = '';
        this.dropdownOpen = false;
        this.hasNoFiles = false;
        this.noRecordsFound = false;
        this.isSearching = false;
        this.sourceFileError = '';
        this.targetObjectError = '';
        this.targetRecordError = '';
    }

    get fileDropdownOptions() {
        return this.availableFiles.map(file => ({
            value: file.id,
            label: file.name,
            selected: this.selectedFileIds.includes(file.id)
        }));
    }

    get selectedFileNames() {
        return this.availableFiles
            .filter(file => this.selectedFileIds.includes(file.id))
            .map(file => file.name)
            .join(', ');
    }

    get selectedFileNamesArray() {
        return this.availableFiles
            .filter(file => this.selectedFileIds.includes(file.id))
            .map(file => ({ id: file.id, name: file.name }));
    }

    get isSelectAllActive() {
        return (
            !!this.targetRecordId &&
            this.availableFiles.length > 0 &&
            this.selectedFileIds.length < this.availableFiles.length
        );
    }

    get isClearActive() {
        return this.selectedFileIds.length > 0;
    }

    get selectAllClass() {
        return this.isSelectAllActive ? 'action-link action-link--active' : 'action-link action-link--disabled';
    }

    get clearClass() {
        return this.isClearActive ? 'action-link action-link--active' : 'action-link action-link--disabled';
    }

    get isMoveDisabled() {
        return (
            !this.targetObjectApiName ||
            !this.targetRecordId ||
            this.selectedFileIds.length === 0 ||
            this.hasNoFiles ||
            this.noRecordsFound
        );
    }

    get sourceFilesWrapperClass() {
        return (this.hasNoFiles || this.noRecordsFound)
            ? 'custom-dropdown section-spacing source-files-disabled'
            : 'custom-dropdown section-spacing';
    }

    get sourceFilesLabelClass() {
        return (this.hasNoFiles || this.noRecordsFound)
            ? 'slds-form-element__label label-disabled'
            : 'slds-form-element__label';
    }

    get dropdownBoxClass() {
        let baseClass = 'dropdown-box';

        if (this.hasNoFiles || this.noRecordsFound) {
            baseClass += ' dropdown-box-disabled';
        }

        if (this.sourceFileError) {
            baseClass += ' dropdown-box-error';
        }

        return baseClass;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    get targetObjectClass() {
        let base = '';

        if (this.targetObjectError) {
            base = 'error-combobox';
        }

        return base;
    }

    get targetObjectWrapperClass() {
    return this.targetObjectError 
        ? 'error-combobox-wrapper' 
        : '';
}
get searchWrapperClass() {
    return this.targetRecordError ? 'error-search-wrapper' : 'normal-search-wrapper';
}

    get searchInputClass() {
        return this.targetRecordError && !this.searchKey ? 'input-error' : '';
    }


    handleTargetObjectBlur() {
        if (!this.targetObjectApiName) {
            this.targetObjectError = 'Select/Choose a Target Object';
        }
    }

    handleSearchBlur() {
        setTimeout(() => {
            if (!this.targetRecordId) {
                this.targetRecordError = 'Select/Choose a Record';
            } else {
                this.targetRecordError = '';
            }
        }, 100);
    }

    handleSourceFilesBlur() {
        setTimeout(() => {
            if (this.targetObjectApiName && this.targetRecordId && this.selectedFileIds.length === 0) {
                this.sourceFileError = 'Select Atleast One File';
            } else if (this.selectedFileIds.length > 0) {
                this.sourceFileError = '';
            }
        }, 100);
    }
}