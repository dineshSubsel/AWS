import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getAllObjects from '@salesforce/apex/FileRecoveryVaultController.getAllObjects';
import getRecords from '@salesforce/apex/FileRecoveryVaultController.getRecords';
import getFilesForRecords from '@salesforce/apex/FileRecoveryVaultController.getFilesForRecords';
import startInstantBackup from '@salesforce/apex/FileRecoveryVaultController.startInstantBackup';
import startScheduledBackup from '@salesforce/apex/FileRecoveryVaultController.startScheduledBackup';
import getBackupJobStatus from '@salesforce/apex/FileRecoveryVaultController.getBackupJobStatus';
import areAllJobsDone from '@salesforce/apex/FileRecoveryVaultController.areAllJobsDone';
import abortJob from '@salesforce/apex/FileRecoveryVaultController.abortJob';

export default class FileRecoveryVault extends LightningElement {

    @track showRestorePage = false;

    // ─── JOB POLLING ──────────────────────────────────────────────────────────
    @track isBackupInProgress = false;
    @track jobRows = [];
    _pollingInterval = null;
    _activeJobIds = [];

    // ─── STEP VISIBILITY ──────────────────────────────────────────────────────
    @track showOptionSelection = true;
    @track showBackupOptions = false;
    @track showSearchPage = false;
    @track showSchedulePage = false;

    // ─── OPTION SELECTIONS ────────────────────────────────────────────────────
    selectedOption;
    selectedBackupType;

    // ─── OBJECTS ──────────────────────────────────────────────────────────────
    @track objectOptions = [];
    @track selectedObjects = [];
    @track instantObjectSearchTerm = '';
    @track scheduleObjectSearchTerm = '';
    @track isInstantObjectDropdownOpen = false;
    @track isScheduleObjectDropdownOpen = false;

    // ─── RECORDS ──────────────────────────────────────────────────────────────
    @track rawRecordOptions = [];
    @track selectedRecords = [];
    @track isLoadingRecords = false;
    @track instantSearchTerm = '';
    @track scheduleSearchTerm = '';
    @track isInstantDropdownOpen = false;
    @track isScheduleDropdownOpen = false;

    // ─── FILES ────────────────────────────────────────────────────────────────
    @track fileList = [];
    @track isLoadingFiles = false;

    // ─── SELECT ALL LOADING ───────────────────────────────────────────────────
    @track isSelectAllObjectsLoading = false;
    @track isSelectAllRecordsLoading = false;

    // ─── FILE SELECTION ───────────────────────────────────────────────────────
    @track selectedFileIds = [];

    handleFileSelection(event) {
        this.selectedFileIds = event.detail.selectedRows.map(r => r.Id);
    }

    // ─── FILE TABLE COLUMNS ───────────────────────────────────────────────────
    fileColumns = [
        {
            label: 'File Name', fieldName: 'Title', type: 'text', sortable: true,
            cellAttributes: { iconName: { fieldName: 'fileIcon' } }
        },
        { label: 'File Type', fieldName: 'FileType', type: 'text', sortable: true },
        {
            label: 'Created Date', fieldName: 'CreatedDate', type: 'date', sortable: true,
            typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' }
        }
    ];

    // ─── JOB TABLE COLUMNS ────────────────────────────────────────────────────
    jobColumns = [
        { label: 'Job ID', fieldName: 'jobId', type: 'text', hideDefaultActions: true },
        { label: 'Class', fieldName: 'className', type: 'text', hideDefaultActions: true },
        { label: 'Status', fieldName: 'status', type: 'text', hideDefaultActions: true },
        { label: 'User', fieldName: 'userName', type: 'text', hideDefaultActions: true },
        { label: 'Start Time', fieldName: 'startTime', type: 'text', hideDefaultActions: true },
        {
            label: 'Action',
            type: 'button',
            typeAttributes: {
                label: 'Cancel',
                name: 'cancel',
                variant: 'destructive',
                disabled: { fieldName: 'isNotRunning' }
            }, hideDefaultActions: true
        }
    ];

    // ─── SCHEDULE ─────────────────────────────────────────────────────────────
    backupOptions = [
        { label: 'Daily', value: 'daily' },
        { label: 'Weekly', value: 'weekly' },
        { label: 'Monthly', value: 'monthly' }
    ];

    @track timeOptions = [];
    @track backupFrequency = '';
    @track backupTime = '';
    get hasJobRows() { return this.jobRows.length > 0; }

     get noRecordsAvailable() {
    return this.selectedObjects.length === 1
        && !this.isLoadingRecords
        && this.rawRecordOptions.length === 0;
}

    get isNextDisabled() { return !this.selectedOption; }
    get isBackupNextDisabled() { return !this.selectedBackupType; }
    get isBackupSelected() { return this.selectedOption === 'backup'; }
    get isRestoreSelected() { return this.selectedOption === 'restore'; }
    get isInstantSelected() { return this.selectedBackupType === 'instant'; }
    get isScheduleSelected() { return this.selectedBackupType === 'schedule'; }

    get isInstantStartDisabled() {
        if (this.isBackupInProgress) return true;
        if (!this.hasSelectedObjects) return true;
        if (this.noRecordsAvailable) return true;
        if (!this.isRecordsDisabled && this.hasSelectedRecords && !this.hasFiles) return true;

        return false;
    }
    get isScheduleStartDisabled() {
        if (this.isBackupInProgress) return true;
        if (!this.backupFrequency || !this.backupTime) return true;
        if (!this.hasSelectedObjects) return true;
        if (this.noRecordsAvailable) return true;
        if (!this.isRecordsDisabled && this.hasSelectedRecords && !this.hasFiles) return true;

        return false;
    }

    get instantStartLabel() { return this.isBackupInProgress ? 'Backup Running...' : 'Start'; }
    get scheduleStartLabel() { return this.isBackupInProgress ? 'Backup Running...' : 'Start'; }

    get hasSelectedObjects() { return this.selectedObjects.length > 0; }
    get selectedObjectsCount() { return this.selectedObjects.length; }

    get selectedObjectLabels() {
        const labels = this.objectOptions
            .filter(o => this.selectedObjects.includes(o.value))
            .map(o => o.label);
        if (!labels.length) return '';
        if (labels.length === 1) return labels[0];
        return `${labels[0]} +${labels.length - 1} more`;
    }

    get isAllObjectsSelected() {
        return this.objectOptions.length > 0 &&
            this.selectedObjects.length === this.objectOptions.length;
    }
    get isObjectsIndeterminate() {
        return this.selectedObjects.length > 0 && !this.isAllObjectsSelected;
    }
    get selectAllObjectsCheckboxClass() {
        let cls = 'ms-checkbox';
        if (this.isAllObjectsSelected) cls += ' ms-checkbox--checked';
        else if (this.isObjectsIndeterminate) cls += ' ms-checkbox--checked ms-checkbox--indeterminate';
        return cls;
    }

    get isRecordsDisabled() {
        return this.selectedObjects.length > 1;
    }

    get instantObjectTriggerClass() {
        return 'ms-trigger' + (this.isInstantObjectDropdownOpen ? ' ms-trigger--open' : '');
    }
    get scheduleObjectTriggerClass() {
        return 'ms-trigger' + (this.isScheduleObjectDropdownOpen ? ' ms-trigger--open' : '');
    }

    get filteredInstantObjects() { return this._buildFilteredObjectList(this.instantObjectSearchTerm); }
    get filteredScheduleObjects() { return this._buildFilteredObjectList(this.scheduleObjectSearchTerm); }
    get hasFilteredInstantObjects() { return this.filteredInstantObjects.length > 0; }
    get hasFilteredScheduleObjects() { return this.filteredScheduleObjects.length > 0; }

    _buildFilteredObjectList(searchTerm) {
        const term = (searchTerm || '').toLowerCase();
        return this.objectOptions
            .filter(o => !term || o.label.toLowerCase().includes(term))
            .map(o => {
                const checked = this.selectedObjects.includes(o.value);
                return {
                    ...o, checked,
                    itemClass: 'ms-item' + (checked ? ' ms-item--selected' : ''),
                    checkboxClass: 'ms-checkbox' + (checked ? ' ms-checkbox--checked' : '')
                };
            });
    }

    get hasSelectedRecords() { return this.selectedRecords.length > 0; }
    get selectedRecordsCount() { return this.selectedRecords.length; }

    get selectedRecordLabels() {
        const labels = this.rawRecordOptions
            .filter(r => this.selectedRecords.includes(r.value))
            .map(r => r.label);
        if (!labels.length) return '';
        if (labels.length === 1) return labels[0];
        return `${labels[0]} +${labels.length - 1} more`;
    }

    get isAllRecordsSelected() {
        return this.rawRecordOptions.length > 0 &&
            this.selectedRecords.length === this.rawRecordOptions.length;
    }
    get isRecordsIndeterminate() {
        return this.selectedRecords.length > 0 && !this.isAllRecordsSelected;
    }
    get selectAllRecordsCheckboxClass() {
        let cls = 'ms-checkbox';
        if (this.isAllRecordsSelected) cls += ' ms-checkbox--checked';
        else if (this.isRecordsIndeterminate) cls += ' ms-checkbox--checked ms-checkbox--indeterminate';
        return cls;
    }

    get instantTriggerClass() {
        let cls = 'ms-trigger';
        if (this.isInstantDropdownOpen) cls += ' ms-trigger--open';
        if (this.isRecordsDisabled || this.noRecordsAvailable || this.isLoadingRecords || !this.hasSelectedObjects) cls += ' ms-trigger--disabled';
        return cls;
    }

    get scheduleTriggerClass() {
        let cls = 'ms-trigger';
        if (this.isScheduleDropdownOpen) cls += ' ms-trigger--open';
        if (this.isRecordsDisabled || this.noRecordsAvailable || this.isLoadingRecords || !this.hasSelectedObjects) cls += ' ms-trigger--disabled';
        return cls;
    }

    get filteredInstantRecords() { return this._buildFilteredRecordList(this.instantSearchTerm); }
    get filteredScheduleRecords() { return this._buildFilteredRecordList(this.scheduleSearchTerm); }
    get hasFilteredInstantRecords() { return this.filteredInstantRecords.length > 0; }
    get hasFilteredScheduleRecords() { return this.filteredScheduleRecords.length > 0; }

    _buildFilteredRecordList(searchTerm) {
        const term = (searchTerm || '').toLowerCase();
        return this.rawRecordOptions
            .filter(r => !term || r.label.toLowerCase().includes(term))
            .map(r => {
                const checked = this.selectedRecords.includes(r.value);
                return {
                    ...r, checked,
                    itemClass: 'ms-item' + (checked ? ' ms-item--selected' : ''),
                    checkboxClass: 'ms-checkbox' + (checked ? ' ms-checkbox--checked' : '')
                };
            });
    }

    get hasFiles() { return this.fileList.length > 0; }
    get showFileTable() { return !this.isRecordsDisabled && this.hasSelectedRecords; }

    connectedCallback() {
        this.generateTimeOptions();
        this.loadObjects();
        this._handleOutsideClick = this.handleOutsideClick.bind(this);
        document.addEventListener('click', this._handleOutsideClick);
    }

    disconnectedCallback() {
        document.removeEventListener('click', this._handleOutsideClick);
        this._stopPolling();
    }

    handleOutsideClick(event) {
        const wrappers = this.template.querySelectorAll('.multiselect-wrapper');
        let inside = false;
        wrappers.forEach(w => { if (w.contains(event.target)) inside = true; });
        if (!inside) {
            this.isInstantObjectDropdownOpen = false;
            this.isScheduleObjectDropdownOpen = false;
            this.isInstantDropdownOpen = false;
            this.isScheduleDropdownOpen = false;
        }
    }

 loadObjects() {
    getAllObjects()
        .then(result => {
            this.objectOptions = result
                .map(apiName => {
                    const label = apiName
                        .replace(/__c$/i, '')        
                        .replace(/__/g, ' ')          
                        .replace(/_/g, ' ')         
                        .replace(/\b\w/g, c => c.toUpperCase()); 
                    return { label: label, value: apiName };
                })
                .sort((a, b) => a.label.localeCompare(b.label)); 
        })
        .catch();
}

    loadRecords(objectName) {
        this.isLoadingRecords = true;
        this.rawRecordOptions = [];
        this.selectedRecords = [];
        this.fileList = [];

        getRecords({ objectName })
            .then(result => {
                this.rawRecordOptions = result.map(rec => ({ label: rec.Name, value: rec.Id }));
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to load records.',
                    variant: 'error'
                }));
            })
            .finally(() => { this.isLoadingRecords = false; });
    }

    fetchFiles() {
        if (!this.selectedRecords.length) { this.fileList = []; return; }
        this.isLoadingFiles = true;

        getFilesForRecords({ recordIds: this.selectedRecords })
            .then(result => { this.fileList = result; })
            .catch(error => {
                this.fileList = [];
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to load files.',
                    variant: 'error'
                }));
            })
            .finally(() => { this.isLoadingFiles = false; });
    }

    generateTimeOptions() {
        const options = [];
        for (let i = 0; i < 24; i++) {
            const hour = i % 12 || 12;
            const ampm = i < 12 ? 'AM' : 'PM';
            options.push({
                label: `${String(hour).padStart(2, '0')}:00 ${ampm}`,
                value: `${String(i).padStart(2, '0')}:00`
            });
        }
        this.timeOptions = options;
    }

    handleSelection(event) { this.selectedOption = event.target.value; }
    handleBackupType(event) { this.selectedBackupType = event.target.value; }
    handleBackupFrequency(e) { this.backupFrequency = e.detail.value; }
    handleBackupTime(e) { this.backupTime = e.detail.value; }

    handleNext() {
        if (this.selectedOption === 'backup') {
            this.showOptionSelection = false;
            this.showBackupOptions = true;
        } else if (this.selectedOption === 'restore') {
            this.showOptionSelection = false;
            this.showRestorePage = true;
        }
    }

    handleBack() {
        this.showBackupOptions = false;
        this.showOptionSelection = true;
        this._resetAll();
    }

    handleBackupNext() {
        if (this.selectedBackupType === 'instant') {
            this.showBackupOptions = false;
            this.showSearchPage = true;
        } else {
            this.showBackupOptions = false;
            this.showSchedulePage = true;
        }
    }

    handleSearchBack() {
        if (this.isBackupInProgress) return;
        this.showSearchPage = false;
        this.showBackupOptions = true;
        this._resetAll();
        this.selectedBackupType = 'instant';
    }

    handleScheduleBack() {
        if (this.isBackupInProgress) return;
        this.showSchedulePage = false;
        this.showBackupOptions = true;
        this._resetAll();
        this.selectedBackupType = 'schedule';
    }

    handleRestoreBack() {
        this.showRestorePage = false;
        this.showOptionSelection = true;
    }

    toggleInstantObjectDropdown(event) {
        event.stopPropagation();
        this.isInstantObjectDropdownOpen = !this.isInstantObjectDropdownOpen;
        this.isScheduleObjectDropdownOpen = false;
        this.isInstantDropdownOpen = false;
        this.isScheduleDropdownOpen = false;
    }

    toggleScheduleObjectDropdown(event) {
        event.stopPropagation();
        this.isScheduleObjectDropdownOpen = !this.isScheduleObjectDropdownOpen;
        this.isInstantObjectDropdownOpen = false;
        this.isInstantDropdownOpen = false;
        this.isScheduleDropdownOpen = false;
    }

    handleInstantObjectSearch(event) { this.instantObjectSearchTerm = event.target.value; }
    handleScheduleObjectSearch(event) { this.scheduleObjectSearchTerm = event.target.value; }

    handleObjectToggle(event) {
        event.stopPropagation();
        const val = event.currentTarget.dataset.value;
        const idx = this.selectedObjects.indexOf(val);
        this.selectedObjects = idx === -1
            ? [...this.selectedObjects, val]
            : this.selectedObjects.filter(v => v !== val);
        this._onObjectSelectionChanged();
    }

    toggleSelectAllObjects(event) {
        event.stopPropagation();
        this.isSelectAllObjectsLoading = true;
        setTimeout(() => {
            try {
                this.selectedObjects = this.isAllObjectsSelected ? [] : this.objectOptions.map(o => o.value);
                this._onObjectSelectionChanged();
            } finally { this.isSelectAllObjectsLoading = false; }
        }, 0);
    }

    _onObjectSelectionChanged() {
        if (this.selectedObjects.length === 1) {
            this.loadRecords(this.selectedObjects[0]);
        } else {
            this.isLoadingRecords = false;
            this.rawRecordOptions = [];
            this.selectedRecords = [];
            this.fileList = [];
            this.isInstantDropdownOpen = false;
            this.isScheduleDropdownOpen = false;
        }
    }

    clearObjects(event) {
        event.stopPropagation();
        this.selectedObjects = [];
        this.isLoadingRecords = false;
        this.rawRecordOptions = [];
        this.selectedRecords = [];
        this.fileList = [];
        this.isInstantObjectDropdownOpen = false;
        this.isScheduleObjectDropdownOpen = false;
        this.isInstantDropdownOpen = false;
        this.isScheduleDropdownOpen = false;
    }

    toggleInstantDropdown(event) {
        if (this.isRecordsDisabled || this.noRecordsAvailable || this.isLoadingRecords || !this.hasSelectedObjects) return;
        event.stopPropagation();
        this.isInstantDropdownOpen = !this.isInstantDropdownOpen;
        this.isScheduleDropdownOpen = false;
        this.isInstantObjectDropdownOpen = false;
        this.isScheduleObjectDropdownOpen = false;
    }

    toggleScheduleDropdown(event) {
        if (this.isRecordsDisabled || this.noRecordsAvailable || this.isLoadingRecords || !this.hasSelectedObjects) return;
        event.stopPropagation();
        this.isScheduleDropdownOpen = !this.isScheduleDropdownOpen;
        this.isInstantDropdownOpen = false;
        this.isInstantObjectDropdownOpen = false;
        this.isScheduleObjectDropdownOpen = false;
    }

    handleInstantRecordSearch(event) { this.instantSearchTerm = event.target.value; }
    handleScheduleRecordSearch(event) { this.scheduleSearchTerm = event.target.value; }

    handleRecordToggle(event) {
        event.stopPropagation();
        const val = event.currentTarget.dataset.value;
        const idx = this.selectedRecords.indexOf(val);
        this.selectedRecords = idx === -1
            ? [...this.selectedRecords, val]
            : this.selectedRecords.filter(v => v !== val);
        this.fetchFiles();
    }

    toggleSelectAllRecords(event) {
        event.stopPropagation();
        this.isSelectAllRecordsLoading = true;
        setTimeout(() => {
            try {
                if (this.isAllRecordsSelected) {
                    this.selectedRecords = [];
                    this.fileList = [];
                } else {
                    this.selectedRecords = this.rawRecordOptions.map(r => r.value);
                    this.fetchFiles();
                }
            } finally { this.isSelectAllRecordsLoading = false; }
        }, 0);
    }

    clearRecords(event) {
        event.stopPropagation();
        this.selectedRecords = [];
        this.fileList = [];
        this.isInstantDropdownOpen = false;
        this.isScheduleDropdownOpen = false;
    }

    stopPropagation(event) { event.stopPropagation(); }

    _resetMultiSelect() {
        this.selectedFileIds = [];
        this.selectedObjects = [];
        this.selectedRecords = [];
        this.rawRecordOptions = [];
        this.fileList = [];
        this.isLoadingRecords = false;
        this.instantObjectSearchTerm = '';
        this.scheduleObjectSearchTerm = '';
        this.instantSearchTerm = '';
        this.scheduleSearchTerm = '';
        this.isInstantObjectDropdownOpen = false;
        this.isScheduleObjectDropdownOpen = false;
        this.isInstantDropdownOpen = false;
        this.isScheduleDropdownOpen = false;
        this.isSelectAllObjectsLoading = false;
        this.isSelectAllRecordsLoading = false;
    }

    _resetAll() {
        this._stopPolling();
        this.isBackupInProgress = false;
        this.jobRows = [];
        this._activeJobIds = [];
        this.selectedBackupType = undefined;
        this.backupFrequency = '';
        this.backupTime = '';
        this._resetMultiSelect();
        this.showRestorePage = false;
    }

    startMigration() {
        const recordIds = this.isRecordsDisabled || !this.hasSelectedRecords ? [] : this.selectedRecords;

        startInstantBackup({ selectedObjects: this.selectedObjects.join(','), recordIds })
            .then(jobIds => {
                const msg = recordIds.length === 0
                    ? `All files in "${this.selectedObjectLabels}" have been backed up to S3 successfully!`
                    : `Files have been backed up to S3 successfully!`;

                this.dispatchEvent(new ShowToastEvent({
                    title: 'Backup Successful',
                    message: msg,
                    variant: 'success'
                }));

                this._activeJobIds = jobIds || [];
                this.isBackupInProgress = true;
                this._resetSelectionsOnly();
                this._startPolling();
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || 'Backup failed to start',
                    variant: 'error'
                }));
            });
    }
    confirmSchedule() {
        const recordIds = this.isRecordsDisabled || !this.hasSelectedRecords ? [] : this.selectedRecords;
        startScheduledBackup({
            selectedObjects: this.selectedObjects.join(','),
            recordIds,
            frequency: this.backupFrequency,
            backupTime: this.backupTime
        })
            .then(jobIds => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Schedule Created',
                    message: 'File backup has been scheduled successfully.',
                    variant: 'success'
                }));
                this.backupFrequency = '';
                this.backupTime = '';
                this._activeJobIds = jobIds || [];
                this.isBackupInProgress = false;
                this._resetSelectionsOnly();
                this._startPolling();
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error', message: error.body?.message || 'Schedule creation failed', variant: 'error'
                }));
            });
    }
    _startPolling() {
        this._stopPolling();
        this._fetchJobRows();
        this._pollingInterval = setInterval(() => { this._checkJobStatus(); }, 5000);
    }

    _stopPolling() {
        if (this._pollingInterval) {
            clearInterval(this._pollingInterval);
            this._pollingInterval = null;
        }
    }

    _fetchJobRows() {
        getBackupJobStatus({ jobIds: this._activeJobIds })
            .then(rows => {
                this.jobRows = (rows || []).map(r => {
                    const isRunning = ['Queued', 'Holding', 'Processing', 'Preparing'].includes(r.status);
                    return { ...r, isNotRunning: !isRunning };
                });
            })
            .catch();
    }

    _checkJobStatus() {
        if (!this._activeJobIds.length) {
            this._stopPolling();
            this.isBackupInProgress = false;
            return;
        }

        areAllJobsDone({ jobIds: this._activeJobIds })
            .then(done => {
                this._fetchJobRows();
                if (done) {
                    this._stopPolling();
                    this.isBackupInProgress = false;
                    this._activeJobIds = [];
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Backup Complete',
                        message: 'All files have been successfully backed up.',
                        variant: 'success'
                    }));
                    this._resetSelectionsOnly();
                }
            })
            .catch();
    }
    _resetSelectionsOnly() {
        this.selectedObjects = [];
        this.selectedRecords = [];
        this.rawRecordOptions = [];
        this.fileList = [];
        this.selectedFileIds = [];
        this.isLoadingRecords = false;
        this.instantObjectSearchTerm = '';
        this.scheduleObjectSearchTerm = '';
        this.instantSearchTerm = '';
        this.scheduleSearchTerm = '';
        this.isInstantObjectDropdownOpen = false;
        this.isScheduleObjectDropdownOpen = false;
        this.isInstantDropdownOpen = false;
        this.isScheduleDropdownOpen = false;
        this.isSelectAllObjectsLoading = false;
        this.isSelectAllRecordsLoading = false;
    }

    abortJob(jobId) {
        abortJob({ jobId })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Job Cancelled',
                    message: 'The job has been aborted successfully.',
                    variant: 'success'
                }));
                this._fetchJobRows();
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || 'Failed to abort job',
                    variant: 'error'
                }));
            });
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'cancel') {
            this.abortJob(row.jobId);
        }
    }
}