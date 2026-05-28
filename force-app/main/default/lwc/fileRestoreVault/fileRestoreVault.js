import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getAllObjects from '@salesforce/apex/FileRecoveryVaultController.getAllObjects';
import getRecords from '@salesforce/apex/FileRecoveryVaultController.getRecords';
import getFilesForLogRecords from '@salesforce/apex/FileRecoveryVaultController.getFilesForLogRecords';
import startInstantRestoreApex from '@salesforce/apex/FileRecoveryVaultController.startInstantRestore';
import startScheduledRestoreApex from '@salesforce/apex/FileRecoveryVaultController.startScheduledRestore';
import getBackupJobStatus from '@salesforce/apex/FileRecoveryVaultController.getBackupJobStatusRestore';
import areAllJobsDone from '@salesforce/apex/FileRecoveryVaultController.areAllJobsDoneRestore';
import abortJob from '@salesforce/apex/FileRecoveryVaultController.abortJob';

export default class FileRestoreVault extends LightningElement {

    // ─── JOB POLLING ──────────────────────────────────────────────────────────
    @track isBackupInProgress = false;
    @track isJobTableVisible = false;
    @track isFetchingJobRows = false;   // true only during the initial fetch
    @track jobRows = [];
    _pollingInterval = null;
    _activeJobIds = [];

    // ─── STEP VISIBILITY ──────────────────────────────────────────────────────
    @track showRestoreOptions = true;
    @track showInstantRestorePage = false;
    @track showScheduleRestorePage = false;

    // ─── RESTORE TYPE ─────────────────────────────────────────────────────────
    @track selectedRestoreType = '';

    // ─── OBJECTS ──────────────────────────────────────────────────────────────
    @track rawObjectOptions = [];
    @track selectedObjects = [];

    @track isInstantRestoreObjectDropdownOpen = false;
    @track isScheduleRestoreObjectDropdownOpen = false;

    @track instantRestoreObjectSearchTerm = '';
    @track scheduleRestoreObjectSearchTerm = '';

    @track isSelectAllObjectsLoading = false;

    // ─── INSTANT RESTORE RECORDS ──────────────────────────────────────────────
    @track rawInstantRestoreRecordOptions = [];
    @track selectedInstantRestoreRecords = [];
    @track instantRestoreRecordSearchTerm = '';
    @track isInstantRestoreRecordDropdownOpen = false;
    @track isSelectAllInstantRestoreRecordsLoading = false;
    @track isLoadingInstantRestoreRecords = false;

    @track instantRestoreFileList = [];
    @track isLoadingInstantRestoreFiles = false;
    @track selectedInstantFileIds = [];

    // ─── SCHEDULE RESTORE RECORDS ─────────────────────────────────────────────
    @track rawScheduleRestoreRecordOptions = [];
    @track selectedScheduleRestoreRecords = [];
    @track scheduleRestoreRecordSearchTerm = '';
    @track isScheduleRestoreRecordDropdownOpen = false;
    @track isSelectAllScheduleRestoreRecordsLoading = false;
    @track isLoadingScheduleRestoreRecords = false;

    @track scheduleRestoreFileList = [];
    @track isLoadingScheduleRestoreFiles = false;
    @track selectedScheduleFileIds = [];

    // ─── COLUMNS ──────────────────────────────────────────────────────────────
fileColumns = [
    {
        label: 'File Name',
        fieldName: 'fileName',
        type: 'text',
        hideDefaultActions: true   
    },
    {
        label: 'Backup Time',
        fieldName: 'backupTime',
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        },
        hideDefaultActions: true
    }
];

jobColumns = [
    {
        label: 'Job ID',
        fieldName: 'jobId',
        type: 'text',
        hideDefaultActions: true
    },
    {
        label: 'Class',
        fieldName: 'className',
        type: 'text',
        hideDefaultActions: true
    },
    {
        label: 'Status',
        fieldName: 'status',
        type: 'text',
        hideDefaultActions: true
    },
    {
        label: 'User',
        fieldName: 'userName',
        type: 'text',
        hideDefaultActions: true
    },
    {
        label: 'Start Time',
        fieldName: 'startTime',
        type: 'text',
        hideDefaultActions: true
    },
    {
        label: 'Action',
        type: 'button',
        typeAttributes: {
            label: 'Cancel',
            name: 'cancel',
            variant: 'destructive',
            disabled: { fieldName: 'isNotRunning' }
        },
        hideDefaultActions: true
    }
];
    // ─── SCHEDULE ─────────────────────────────────────────────────────────────
    backupOptions = [
        { label: 'Daily', value: 'daily' },
        { label: 'Weekly', value: 'weekly' },
        { label: 'Monthly', value: 'monthly' }
    ];
    @track timeOptions = [];
    @track restoreFrequency = '';
    @track restoreTime = '';

    // =========================================================================
    // GETTERS — STEPS
    // =========================================================================

    get isRestoreNextDisabled() { return !this.selectedRestoreType; }
    get isInstantRestoreSelected() { return this.selectedRestoreType === 'instant'; }
    get isScheduleRestoreSelected() { return this.selectedRestoreType === 'schedule'; }
    get instantRestoreStartLabel() { return this.isBackupInProgress ? 'Backup Running...' : 'Start'; }
  get isInstantRestoreStartDisabled() {
    const fileTableVisible = this.showInstantRestoreFileTable;
    const noFiles = fileTableVisible && !this.isLoadingInstantRestoreFiles && !this.hasInstantRestoreFiles;
    return this.selectedObjects.length === 0 
        || this.isBackupInProgress 
        || noFiles;
}
get isScheduleRestoreStartDisabled() {
    const fileTableVisible = this.showScheduleRestoreFileTable;
    const noFiles = fileTableVisible 
        && !this.isLoadingScheduleRestoreFiles 
        && !this.hasScheduleRestoreFiles;

    if (this.isMultipleObjectsSelected) {
        return !this.restoreFrequency
            || !this.restoreTime
            || this.selectedObjects.length === 0
            || this.isBackupInProgress;
    }

    return !this.restoreFrequency
        || !this.restoreTime
        || this.selectedObjects.length === 0
        || this.isBackupInProgress
        || noFiles
        || this.noScheduleRestoreRecordsAvailable;
}
    get hasJobRows() { return this.jobRows.length > 0; }
    get isJobTableLoading() { return this.isFetchingJobRows && this.jobRows.length === 0; }
    get showJobSection() { return this.isJobTableLoading || this.hasJobRows; }
    get isMultipleObjectsSelected() { return this.selectedObjects.length > 1; }
    get hasSelectedObjects() { return this.selectedObjects.length > 0; }
    get selectedObjectsCount() { return this.selectedObjects.length; }

    get isAllObjectsSelected() {
        return this.rawObjectOptions.length > 0 &&
            this.selectedObjects.length === this.rawObjectOptions.length;
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
get selectedObjectLabels() {
    const labels = this.rawObjectOptions
        .filter(o => this.selectedObjects.includes(o.value))
        .map(o => o.label);

    if (labels.length === 0) return '';
    if (labels.length === 1) return labels[0];

    return `${labels[0]} +${labels.length - 1} more`;
}
    get instantRestoreObjectTriggerClass() { return 'ms-trigger' + (this.isInstantRestoreObjectDropdownOpen ? ' ms-trigger--open' : ''); }
    get scheduleRestoreObjectTriggerClass() { return 'ms-trigger' + (this.isScheduleRestoreObjectDropdownOpen ? ' ms-trigger--open' : ''); }

    get filteredInstantRestoreObjects() { return this._buildObjList(this.instantRestoreObjectSearchTerm); }
    get filteredScheduleRestoreObjects() { return this._buildObjList(this.scheduleRestoreObjectSearchTerm); }
    get hasFilteredInstantRestoreObjects() { return this.filteredInstantRestoreObjects.length > 0; }
    get hasFilteredScheduleRestoreObjects() { return this.filteredScheduleRestoreObjects.length > 0; }

    _buildObjList(searchTerm) {
        const term = (searchTerm || '').toLowerCase();
        return this.rawObjectOptions
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

    get hasSelectedInstantRestoreRecords() { return this.selectedInstantRestoreRecords.length > 0; }
    get selectedInstantRestoreRecordsCount() { return this.selectedInstantRestoreRecords.length; }

    get selectedInstantRestoreRecordLabels() {
        const labels = this.rawInstantRestoreRecordOptions
            .filter(r => this.selectedInstantRestoreRecords.includes(r.value))
            .map(r => r.label);
        if (labels.length === 0) return '';
        if (labels.length === 1) return labels[0];
        return `${labels[0]} +${labels.length - 1} more`;
    }
    get isAllInstantRestoreRecordsSelected() {
        return this.rawInstantRestoreRecordOptions.length > 0 &&
            this.selectedInstantRestoreRecords.length === this.rawInstantRestoreRecordOptions.length;
    }
    get isInstantRestoreRecordsIndeterminate() {
        return this.selectedInstantRestoreRecords.length > 0 && !this.isAllInstantRestoreRecordsSelected;
    }
    get selectAllInstantRestoreCheckboxClass() {
        let cls = 'ms-checkbox';
        if (this.isAllInstantRestoreRecordsSelected) cls += ' ms-checkbox--checked';
        else if (this.isInstantRestoreRecordsIndeterminate) cls += ' ms-checkbox--checked ms-checkbox--indeterminate';
        return cls;
    }
    get _restoreTriggerDisabled() { return !this.hasSelectedObjects || this.isMultipleObjectsSelected; }

    get instantRestoreRecordTriggerClass() {
        let cls = 'ms-trigger';
        if (this.isInstantRestoreRecordDropdownOpen) cls += ' ms-trigger--open';
        if (this._restoreTriggerDisabled || this.noInstantRestoreRecordsAvailable || !this.hasSelectedObjects) cls += ' ms-trigger--disabled';
        return cls;
    }
    get filteredInstantRestoreRecords() {
        return this._buildRecordList(
            this.rawInstantRestoreRecordOptions,
            this.selectedInstantRestoreRecords,
            this.instantRestoreRecordSearchTerm
        );
    }
    get hasFilteredInstantRestoreRecords() { return this.filteredInstantRestoreRecords.length > 0; }
    get showInstantRestoreFileTable() { return !this.isMultipleObjectsSelected && this.hasSelectedInstantRestoreRecords; }
    get hasInstantRestoreFiles() { return this.instantRestoreFileList.length > 0; }

    get hasSelectedScheduleRestoreRecords() { return this.selectedScheduleRestoreRecords.length > 0; }
    get selectedScheduleRestoreRecordsCount() { return this.selectedScheduleRestoreRecords.length; }

    get selectedScheduleRestoreRecordLabels() {
        const labels = this.rawScheduleRestoreRecordOptions
            .filter(r => this.selectedScheduleRestoreRecords.includes(r.value))
            .map(r => r.label);
        if (labels.length === 0) return '';
        if (labels.length === 1) return labels[0];
        return `${labels[0]} +${labels.length - 1} more`;
    }
    get isAllScheduleRestoreRecordsSelected() {
        return this.rawScheduleRestoreRecordOptions.length > 0 &&
            this.selectedScheduleRestoreRecords.length === this.rawScheduleRestoreRecordOptions.length;
    }
    get isScheduleRestoreRecordsIndeterminate() {
        return this.selectedScheduleRestoreRecords.length > 0 && !this.isAllScheduleRestoreRecordsSelected;
    }
    get selectAllScheduleRestoreCheckboxClass() {
        let cls = 'ms-checkbox';
        if (this.isAllScheduleRestoreRecordsSelected) cls += ' ms-checkbox--checked';
        else if (this.isScheduleRestoreRecordsIndeterminate) cls += ' ms-checkbox--checked ms-checkbox--indeterminate';
        return cls;
    }
    get scheduleRestoreRecordTriggerClass() {
        let cls = 'ms-trigger';
        if (this.isScheduleRestoreRecordDropdownOpen) cls += ' ms-trigger--open';
        if (this._restoreTriggerDisabled || this.noScheduleRestoreRecordsAvailable || !this.hasSelectedObjects) cls += ' ms-trigger--disabled';
        return cls;
    }
    get filteredScheduleRestoreRecords() {
        return this._buildRecordList(
            this.rawScheduleRestoreRecordOptions,
            this.selectedScheduleRestoreRecords,
            this.scheduleRestoreRecordSearchTerm
        );
    }
    get hasFilteredScheduleRestoreRecords() { return this.filteredScheduleRestoreRecords.length > 0; }
    get showScheduleRestoreFileTable() { return !this.isMultipleObjectsSelected && this.hasSelectedScheduleRestoreRecords; }
    get hasScheduleRestoreFiles() { return this.scheduleRestoreFileList.length > 0; }


    get noInstantRestoreRecordsAvailable() {
        return this.selectedObjects.length === 1 &&
            !this.isLoadingInstantRestoreRecords &&
            this.rawInstantRestoreRecordOptions.length === 0;
    }

    get noScheduleRestoreRecordsAvailable() {
        return this.selectedObjects.length === 1 &&
            !this.isLoadingScheduleRestoreRecords &&
            this.rawScheduleRestoreRecordOptions.length === 0;
    }

    _buildRecordList(rawPool, selectedArr, searchTerm) {
        const term = (searchTerm || '').toLowerCase();
        return rawPool
            .filter(r => !term || r.label.toLowerCase().includes(term))
            .map(r => {
                const checked = selectedArr.includes(r.value);
                return {
                    ...r, checked,
                    itemClass: 'ms-item' + (checked ? ' ms-item--selected' : ''),
                    checkboxClass: 'ms-checkbox' + (checked ? ' ms-checkbox--checked' : '')
                };
            });
    }

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
        if (!inside) this._closeAllDropdowns();
    }

    loadObjects() {
    getAllObjects()
        .then(result => {
            this.rawObjectOptions = result
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
    loadInstantRestoreRecords(objectName) {
        this.isLoadingInstantRestoreRecords = true;
        this.rawInstantRestoreRecordOptions = [];
        this.selectedInstantRestoreRecords = [];
        this.instantRestoreFileList = [];
        this.selectedInstantFileIds = [];

        getRecords({ objectName })
            .then(result => {
                this.rawInstantRestoreRecordOptions = result.map(rec => ({ label: rec.Name, value: rec.Id }));
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'Failed to load records.', variant: 'error' }));
            })
            .finally(() => { this.isLoadingInstantRestoreRecords = false; });
    }

    loadScheduleRestoreRecords(objectName) {
        this.isLoadingScheduleRestoreRecords = true;
        this.rawScheduleRestoreRecordOptions = [];
        this.selectedScheduleRestoreRecords = [];
        this.scheduleRestoreFileList = [];
        this.selectedScheduleFileIds = [];

        getRecords({ objectName })
            .then(result => {
                this.rawScheduleRestoreRecordOptions = result.map(rec => ({ label: rec.Name, value: rec.Id }));
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'Failed to load records.', variant: 'error' }));
            })
            .finally(() => { this.isLoadingScheduleRestoreRecords = false; });
    }

    fetchInstantRestoreFiles() {
        if (!this.selectedInstantRestoreRecords.length) {
            this.instantRestoreFileList = [];
            this.selectedInstantFileIds = [];
            return;
        }
        this.isLoadingInstantRestoreFiles = true;

        getFilesForLogRecords({
            selectedRecordIds: this.selectedInstantRestoreRecords,
            objectName: this.selectedObjects[0]
        })
            .then(result => {
                this.instantRestoreFileList = result;
                this.selectedInstantFileIds = [];
            })
            .catch(error => {
                this.instantRestoreFileList = [];
                this.selectedInstantFileIds = [];
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'Failed to load files.', variant: 'error' }));
            })
            .finally(() => { this.isLoadingInstantRestoreFiles = false; });
    }

    fetchScheduleRestoreFiles() {
        if (!this.selectedScheduleRestoreRecords.length) {
            this.scheduleRestoreFileList = [];
            this.selectedScheduleFileIds = [];
            return;
        }
        this.isLoadingScheduleRestoreFiles = true;

        getFilesForLogRecords({
            selectedRecordIds: this.selectedScheduleRestoreRecords,
            objectName: this.selectedObjects[0]
        })
            .then(result => {
                this.scheduleRestoreFileList = result;
                this.selectedScheduleFileIds = [];
            })
            .catch(error => {
                this.scheduleRestoreFileList = [];
                this.selectedScheduleFileIds = [];
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'Failed to load files.', variant: 'error' }));
            })
            .finally(() => { this.isLoadingScheduleRestoreFiles = false; });
    }

    handleInstantFileSelection(event) { this.selectedInstantFileIds = event.detail.selectedRows.map(row => row.Id); }
    handleScheduleFileSelection(event) { this.selectedScheduleFileIds = event.detail.selectedRows.map(row => row.Id); }
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

    _closeAllDropdowns() {
        this.isInstantRestoreObjectDropdownOpen = false;
        this.isScheduleRestoreObjectDropdownOpen = false;
        this.isInstantRestoreRecordDropdownOpen = false;
        this.isScheduleRestoreRecordDropdownOpen = false;
    }
    _openObjDropdown(flag) { this._closeAllDropdowns(); this[flag] = true; }

    handleRestoreType(event) { this.selectedRestoreType = event.target.value; }

    handleRestoreNext() {
        if (this.selectedRestoreType === 'instant') {
            this.showRestoreOptions = false;
            this.showInstantRestorePage = true;
        } else {
            this.showRestoreOptions = false;
            this.showScheduleRestorePage = true;
        }
    }

    handleBackToParent() {
        this._resetAll();
        this.dispatchEvent(new CustomEvent('back'));
    }

    handleInstantRestoreBack() {
        this.showInstantRestorePage = false;
        this.showRestoreOptions = true;
        this._resetMultiSelect();
    }

    handleScheduleRestoreBack() {
        this.showScheduleRestorePage = false;
        this.showRestoreOptions = true;
        this._resetMultiSelect();
    }

    toggleInstantRestoreObjectDropdown(event) {
        event.stopPropagation();
        if (this.isInstantRestoreObjectDropdownOpen) { this._closeAllDropdowns(); return; }
        this._openObjDropdown('isInstantRestoreObjectDropdownOpen');
    }
    toggleScheduleRestoreObjectDropdown(event) {
        event.stopPropagation();
        if (this.isScheduleRestoreObjectDropdownOpen) { this._closeAllDropdowns(); return; }
        this._openObjDropdown('isScheduleRestoreObjectDropdownOpen');
    }

    handleInstantRestoreObjectSearch(event) { this.instantRestoreObjectSearchTerm = event.target.value; }
    handleScheduleRestoreObjectSearch(event) { this.scheduleRestoreObjectSearchTerm = event.target.value; }

     handleObjectToggle(event) {
        event.stopPropagation();
        const val = event.currentTarget.dataset.value;
        const idx = this.selectedObjects.indexOf(val);
        const updated = [...this.selectedObjects];
        if (idx === -1) { updated.push(val); } else { updated.splice(idx, 1); }
        this.selectedObjects = updated;
        this._onObjectSelectionChanged(updated);
    }
_updateSelectedObjectLabels() {
    const labels = this.rawObjectOptions
        .filter(o => this.selectedObjects.includes(o.value))
        .map(o => o.label);
    if (labels.length === 0) this.selectedObjectLabels = '';
    else if (labels.length === 1) this.selectedObjectLabels = labels[0];
    else this.selectedObjectLabels = `${labels[0]} +${labels.length - 1} more`;
}

       toggleSelectAllObjects(event) {
        event.stopPropagation();
        this.isSelectAllObjectsLoading = true;
        setTimeout(() => {
            try {
                const all = this.isAllObjectsSelected ? [] : this.rawObjectOptions.map(o => o.value);
                this.selectedObjects = all;
                this._onObjectSelectionChanged(all);
            } finally { this.isSelectAllObjectsLoading = false; }
        }, 0);
    }

    _onObjectSelectionChanged(updated) {
        this.rawInstantRestoreRecordOptions = [];
        this.selectedInstantRestoreRecords = [];
        this.instantRestoreFileList = [];
        this.selectedInstantFileIds = [];
        this.rawScheduleRestoreRecordOptions = [];
        this.selectedScheduleRestoreRecords = [];
        this.scheduleRestoreFileList = [];
        this.selectedScheduleFileIds = [];

        this.isInstantRestoreRecordDropdownOpen = false;
        this.isScheduleRestoreRecordDropdownOpen = false;

        if (updated.length === 1) {
            const obj = updated[0];
            if (this.showInstantRestorePage) this.loadInstantRestoreRecords(obj);
            if (this.showScheduleRestorePage) this.loadScheduleRestoreRecords(obj);
        }
    }

    clearObjects(event) {
    event.stopPropagation();
    this.selectedObjects = [];
    this.selectedObjectLabels = '';
    this._onObjectSelectionChanged([]);
    this._closeAllDropdowns();
}

    toggleInstantRestoreRecordDropdown(event) {
        if (this._restoreTriggerDisabled || this.noInstantRestoreRecordsAvailable || !this.hasSelectedObjects) return;
        event.stopPropagation();
        if (this.isInstantRestoreRecordDropdownOpen) { this._closeAllDropdowns(); return; }
        this._closeAllDropdowns();
        this.isInstantRestoreRecordDropdownOpen = true;
        if (this.selectedObjects.length === 1 &&
            this.rawInstantRestoreRecordOptions.length === 0 &&
            !this.isLoadingInstantRestoreRecords) {
            this.loadInstantRestoreRecords(this.selectedObjects[0]);
        }
    }
    handleInstantRestoreRecordSearch(event) { this.instantRestoreRecordSearchTerm = event.target.value; }

    handleInstantRestoreRecordToggle(event) {
        event.stopPropagation();
        const val = event.currentTarget.dataset.value;
        const idx = this.selectedInstantRestoreRecords.indexOf(val);
        const updated = [...this.selectedInstantRestoreRecords];
        if (idx === -1) { updated.push(val); } else { updated.splice(idx, 1); }
        this.selectedInstantRestoreRecords = updated;
        this.fetchInstantRestoreFiles();
    }

    toggleSelectAllInstantRestoreRecords(event) {
        event.stopPropagation();
        this.isSelectAllInstantRestoreRecordsLoading = true;
        setTimeout(() => {
            try {
                if (this.isAllInstantRestoreRecordsSelected) {
                    this.selectedInstantRestoreRecords = [];
                    this.instantRestoreFileList = [];
                    this.selectedInstantFileIds = [];
                } else {
                    this.selectedInstantRestoreRecords = this.rawInstantRestoreRecordOptions.map(r => r.value);
                    this.fetchInstantRestoreFiles();
                }
            } finally { this.isSelectAllInstantRestoreRecordsLoading = false; }
        }, 0);
    }

    clearInstantRestoreRecords(event) {
        event.stopPropagation();
        this.selectedInstantRestoreRecords = [];
        this.instantRestoreFileList = [];
        this.selectedInstantFileIds = [];
        this._closeAllDropdowns();
    }
    toggleScheduleRestoreRecordDropdown(event) {
        if (this._restoreTriggerDisabled || this.noScheduleRestoreRecordsAvailable || !this.hasSelectedObjects) return; event.stopPropagation();
        if (this.isScheduleRestoreRecordDropdownOpen) { this._closeAllDropdowns(); return; }
        this._closeAllDropdowns();
        this.isScheduleRestoreRecordDropdownOpen = true;
        if (this.selectedObjects.length === 1 &&
            this.rawScheduleRestoreRecordOptions.length === 0 &&
            !this.isLoadingScheduleRestoreRecords) {
            this.loadScheduleRestoreRecords(this.selectedObjects[0]);
        }
    }
    handleScheduleRestoreRecordSearch(event) { this.scheduleRestoreRecordSearchTerm = event.target.value; }

    handleScheduleRestoreRecordToggle(event) {
        event.stopPropagation();
        const val = event.currentTarget.dataset.value;
        const idx = this.selectedScheduleRestoreRecords.indexOf(val);
        const updated = [...this.selectedScheduleRestoreRecords];
        if (idx === -1) { updated.push(val); } else { updated.splice(idx, 1); }
        this.selectedScheduleRestoreRecords = updated;
        this.fetchScheduleRestoreFiles();
    }

    toggleSelectAllScheduleRestoreRecords(event) {
        event.stopPropagation();
        this.isSelectAllScheduleRestoreRecordsLoading = true;
        setTimeout(() => {
            try {
                if (this.isAllScheduleRestoreRecordsSelected) {
                    this.selectedScheduleRestoreRecords = [];
                    this.scheduleRestoreFileList = [];
                    this.selectedScheduleFileIds = [];
                } else {
                    this.selectedScheduleRestoreRecords = this.rawScheduleRestoreRecordOptions.map(r => r.value);
                    this.fetchScheduleRestoreFiles();
                }
            } finally { this.isSelectAllScheduleRestoreRecordsLoading = false; }
        }, 0);
    }

    clearScheduleRestoreRecords(event) {
        event.stopPropagation();
        this.selectedScheduleRestoreRecords = [];
        this.scheduleRestoreFileList = [];
        this.selectedScheduleFileIds = [];
        this._closeAllDropdowns();
    }

    stopPropagation(event) { event.stopPropagation(); }
    handleRestoreFrequency(event) { this.restoreFrequency = event.detail.value; }
    handleRestoreTime(event) { this.restoreTime = event.detail.value; }
    _resetMultiSelect() {
        this.selectedObjects = [];
        this.rawInstantRestoreRecordOptions = [];
        this.selectedInstantRestoreRecords = [];
        this.instantRestoreFileList = [];
        this.selectedInstantFileIds = [];
        this.rawScheduleRestoreRecordOptions = [];
        this.selectedScheduleRestoreRecords = [];
        this.scheduleRestoreFileList = [];
        this.selectedScheduleFileIds = [];
        this.instantRestoreObjectSearchTerm = '';
        this.scheduleRestoreObjectSearchTerm = '';
        this.instantRestoreRecordSearchTerm = '';
        this.scheduleRestoreRecordSearchTerm = '';
        this.isSelectAllObjectsLoading = false;
        this.isSelectAllInstantRestoreRecordsLoading = false;
        this.isSelectAllScheduleRestoreRecordsLoading = false;
        this.restoreFrequency = '';
        this.restoreTime = '';
        this._closeAllDropdowns();
    }
    _resetAll() {
        this._stopPolling();
        this.isBackupInProgress = false;
        this.isFetchingJobRows = false;
        this.isJobTableVisible = false;
        this.jobRows = [];
        this._activeJobIds = [];
        this.selectedRestoreType = '';
        this._resetMultiSelect();
    }
startInstantRestore() {
    const fileIds = this.selectedInstantFileIds && this.selectedInstantFileIds.length > 0
        ? this.selectedInstantFileIds
        : this.instantRestoreFileList.map(f => f.Id); // if none selected, use all

    startInstantRestoreApex({
        selectedObjects: this.selectedObjects.join(','),
        selectedRecordIds: this.selectedInstantRestoreRecords,
        selectedFileIds: fileIds
    })
        .then(jobIds => {
            this._activeJobIds = Array.isArray(jobIds) ? jobIds : [jobIds];
            this.isBackupInProgress = true;
            this.jobRows = [];

            this.dispatchEvent(new ShowToastEvent({
                title: 'Restore Started',
                message: 'Instant restore job(s) queued successfully.',
                variant: 'success'
            }));

            this._resetMultiSelect();
            this._startPolling();
        })
        .catch(error => {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || 'Restore failed to start',
                variant: 'error'
            }));
        });
}
confirmScheduleRestore() {
    const fileIds = this.selectedScheduleFileIds && this.selectedScheduleFileIds.length > 0
        ? this.selectedScheduleFileIds
        : this.scheduleRestoreFileList.map(f => f.Id); // if none selected, use all

    startScheduledRestoreApex({
        selectedObjects: this.selectedObjects.join(','),
        selectedRecordIds: this.selectedScheduleRestoreRecords,
        selectedFileIds: fileIds,
        frequency: this.restoreFrequency,
        restoreTime: this.restoreTime
    })
        .then(() => {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Restore Scheduled',
                message: `${this.restoreFrequency} restore scheduled successfully.`,
                variant: 'success'
            }));
            this._resetMultiSelect();
        })
        .catch(error => {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || 'Schedule restore failed',
                variant: 'error'
            }));
        });
}

    _startPolling() {
        this._stopPolling();
        this.isJobTableVisible = true;
        this.isFetchingJobRows = true;   // show spinner until first fetch resolves
        this.jobRows = [];
        this._fetchJobRows().finally(() => { this.isFetchingJobRows = false; });
        this._pollingInterval = setInterval(() => this._checkJobStatus(), 5000);
    }

    _stopPolling() {
        if (this._pollingInterval) {
            clearInterval(this._pollingInterval);
            this._pollingInterval = null;
        }
    }

    _fetchJobRows() {
        return getBackupJobStatus({ jobIds: this._activeJobIds })
            .then(rows => {
                this.jobRows = (rows || []).map(r => {
                    const isRunning = ['Queued', 'Holding', 'Processing', 'Preparing'].includes(r.status);
                    return { ...r, disableCancel: !isRunning };
                });
            })
            .catch();
    }

    _checkJobStatus() {
        this._fetchJobRows();

        if (!this.jobRows.length) {
            this._stopPolling();
            this.isBackupInProgress = false;
            return;
        }

        areAllJobsDone({ jobIds: this._activeJobIds })
            .then(done => {
                if (done) {
                    this._stopPolling();
                    this.isBackupInProgress = false;
                    this._activeJobIds = [];
                    this.jobRows = [];

                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Restore Complete',
                        message: 'All files have been successfully restored.',
                        variant: 'success'
                    }));

                    this._resetMultiSelect();
                }
            })
            .catch();
    }

    handleRowAction(event) {
        const { action, row } = event.detail;
        if (action.name === 'cancel') this._abortJob(row.jobId);
    }

    _abortJob(jobId) {
        abortJob({ jobId })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Job Cancelled',
                    message: 'Restore job aborted successfully.',
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
}