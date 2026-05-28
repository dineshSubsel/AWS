import { LightningElement, track } from 'lwc';
import getDeletedRecordCounts from '@salesforce/apex/RecycleBinVaultRestore_Controller.getDeletedRecordCounts';
import getDeletedRecordsByType from '@salesforce/apex/RecycleBinVaultRestore_Controller.getDeletedRecordsByType';
import restoreDeletedRecords from '@salesforce/apex/RecycleBinVaultRestore_Controller.restoreDeletedRecords';
import startScheduledRecycleBinRestore from '@salesforce/apex/RecycleBinVaultRestore_Controller.startScheduledRecycleBinRestore';

import areAllJobsDone from '@salesforce/apex/RecycleBinVaultRestore_Controller.areAllJobsDone';
import getJobDetails from '@salesforce/apex/RecycleBinVaultRestore_Controller.getJobDetails';
import cancelJob from '@salesforce/apex/RecycleBinVaultRestore_Controller.cancelJob';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class RestoreRecycleBin extends LightningElement {

    @track showRestoreOptions = true;
    @track showInstantPage = false;
    @track showSchedulePage = false;
    selectedRestoreType = '';
    @track objectTypeOptions = [];
    @track selectedObjectTypeValues = [];
    @track objectSearchTerm = '';
    @track isObjectDropdownOpen = false;
    @track isLoadingObjectTypes = false;
    @track recordOptions = [];
    @track selectedRecordValues = [];
    @track recordSearchTerm = '';
    @track isRecordDropdownOpen = false;
    @track isLoadingRecords = false;
    @track isRestoring = false;
    @track errorMessage = '';
    @track successMessage = '';
    @track showRecordsTable = false;
    @track tableData = [];
    _allFetchedRecords = [];

    @track jobRows = [];
    @track showJobTable = false;

    @track restoreJobIds = [];
    _pollInterval = null;
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

    tableColumns = [
        { label: 'Name', fieldName: 'name', type: 'text', hideDefaultActions: true },
        { label: 'Object Type', fieldName: 'objectType', type: 'text', hideDefaultActions: true },
        {
            label: 'Deleted Date', fieldName: 'deletedDate', type: 'date', hideDefaultActions: true,
            typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' }
        },
        { label: 'Deleted By', fieldName: 'deletedBy', type: 'text', hideDefaultActions: true }
    ];

    @track scheduleObjectTypeOptions = [];
    @track scheduleSelectedObjectTypeValues = [];
    @track scheduleObjectSearchTerm = '';
    @track isScheduleObjectDropdownOpen = false;
    @track scheduleRecordOptions = [];
    @track scheduleSelectedRecordValues = [];
    @track scheduleRecordSearchTerm = '';
    @track isScheduleRecordDropdownOpen = false;
    @track isScheduleLoadingRecords = false;
    _scheduleAllFetchedRecords = [];

    @track scheduleFrequency = '';
    @track scheduleRestoreTime = '';
    @track scheduleErrorMessage = '';

    connectedCallback() {
        this._handleOutsideClick = this._onOutsideClick.bind(this);
        window.addEventListener('click', this._handleOutsideClick);
    }

    disconnectedCallback() {
        window.removeEventListener('click', this._handleOutsideClick);
        this._stopPolling();
    }

    _onOutsideClick(event) {
        if (!this.template.contains(event.target)) {
            this.isObjectDropdownOpen = false;
            this.isRecordDropdownOpen = false;
            this.isScheduleObjectDropdownOpen = false;
            this.isScheduleRecordDropdownOpen = false;
        }
    }

    handleRestoreType(event) {
        this.selectedRestoreType = event.target.value;
    }

    handleRestoreNext() {
        this.showRestoreOptions = false;
        if (this.selectedRestoreType === 'instant') {
            this._resetInstant();
            this.showInstantPage = true;
            this._loadObjectTypes();
        } else {
            this._resetSchedule();
            this.showSchedulePage = true;
            this._loadScheduleObjectTypes();
        }
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    handleInstantBack() {
        this._stopPolling();
        this.showInstantPage = false;
        this.showRestoreOptions = true;
        this.selectedRestoreType = '';
        this.restoreJobIds = [];
        this.jobRows = [];
        this.showJobTable = false;
        this.isRestoring = false;
        this.selectedRestoreType = 'instant';
    }

    handleScheduleBack() {
        this.showSchedulePage = false;
        this.showRestoreOptions = true;
        this.selectedRestoreType = '';
        this.selectedRestoreType = 'schedule';
    }

    handleStartRestore() {
        this.errorMessage = '';
        this.successMessage = '';
        this.jobRows = [];
        this.restoreJobIds = [];
        this.showJobTable = true;

        const selectedObjects = this.selectedObjectTypeValues.join(',');
        const selectedRecordIds = this.selectedRecordValues;

        restoreDeletedRecords({ selectedObjects, selectedRecordIds })
            .then(result => {
                if (result && result.startsWith('ERROR:')) {
                    this.errorMessage = result.substring(6);
                    this.jobRows = [{
                        jobId: 'N/A',
                        className: 'N/A',
                        status: 'Failed',
                        userName: 'N/A',
                        startTime: new Date().toLocaleString(),
                        isNotRunning: true
                    }];
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Restore Failed', message: this.errorMessage, variant: 'error'
                    }));
                    setTimeout(() => {
                        this.isRestoring = false;
                        this.jobRows = [];
                    }, 120000);
                } else {
                    this.restoreJobIds = [result];
                    getJobDetails({ jobIdsJson: JSON.stringify(this.restoreJobIds) })
                        .then(rows => {
                            this.jobRows = rows;
                            this.isRestoring = false;
                        });
                    this._startPolling();
                }
            })
            .catch(error => {
                this.errorMessage = error.body?.message ?? error.message;
                this.jobRows = [{
                    jobId: 'N/A',
                    className: 'N/A',
                    status: 'Failed',
                    userName: 'N/A',
                    startTime: new Date().toLocaleString(),
                    isNotRunning: true
                }];
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Unexpected Error', message: this.errorMessage, variant: 'error'
                }));
                setTimeout(() => {
                    this.isRestoring = false;
                    this.jobRows = [];
                }, 120000);
            });
    }

    _startPolling() {
        this._pollInterval = setInterval(() => {
            const jobIdsJson = JSON.stringify(this.restoreJobIds);

            getJobDetails({ jobIdsJson })
                .then(rows => {
                    this.jobRows = rows;
                })
                .catch();

            areAllJobsDone({ jobIdsJson })
                .then(done => {
                    if (done) {
                        this._stopPolling();
                        getJobDetails({ jobIdsJson })
                            .then(rows => {
                                this.jobRows = rows;
                            })
                            .finally(() => this._onRestoreComplete());
                    }
                })
                .catch();
        }, 4000);
    }

    _stopPolling() {
        if (this._pollInterval) {
            clearInterval(this._pollInterval);
            this._pollInterval = null;
        }
    }

    _onRestoreComplete() {
        this._stopPolling();
        this.isRestoring = false;
        this.showJobTable = false;
        this.restoreJobIds = [];
        this.jobRows = [];
        this.selectedObjectTypeValues = [];
        this.selectedRecordValues = [];
        this.recordOptions = [];
        this.dispatchEvent(new ShowToastEvent({
            title: 'Restore Complete',
            message: 'Recycle Bin records have been restored successfully.',
            variant: 'success'
        }));
    }

    handleRowAction(event) {
        const jobId = event.detail.row.jobId;
        cancelJob({ jobId })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Job Cancelled',
                    message: 'Restore job ' + jobId + ' has been cancelled.',
                    variant: 'warning'
                }));
                getJobDetails({ jobIdsJson: JSON.stringify(this.restoreJobIds) })
                    .then(rows => {
                        this.jobRows = rows;
                    });
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Cancel Failed',
                    message: error.body?.message ?? error.message,
                    variant: 'error'
                }));
            });
    }

    confirmScheduleRestore() {
        const objectTypes = this.scheduleSelectedObjectTypeValues;
        const recordIds = this.scheduleSelectedRecordValues;
        if (!objectTypes || objectTypes.length === 0) {
            this.scheduleErrorMessage = 'Please select at least one object type.';
            return;
        }
        if (!this.scheduleFrequency) {
            this.scheduleErrorMessage = 'Please select a frequency.';
            return;
        }
        if (!this.scheduleRestoreTime) {
            this.scheduleErrorMessage = 'Please select a restore time.';
            return;
        }

        this.scheduleErrorMessage = '';

        startScheduledRecycleBinRestore({
            selectedObjects: objectTypes.join(','),
            selectedRecordIds: recordIds,
            frequency: this.scheduleFrequency,
            restoreTime: this.scheduleRestoreTime
        })
            .then(jobName => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Schedule Created',
                    message: 'Recycle Bin restore has been scheduled successfully.',
                    variant: 'success'
                }));
                this.scheduleSelectedObjectTypeValues = [];
    this.scheduleFrequency = '';
    this.scheduleRestoreTime = '';
    this.scheduleErrorMessage = '';
    this._resetScheduleRecords();
    this.selectedRestoreType = '';
    // Reload object types so dropdown is populated again
    this._loadScheduleObjectTypes();
            })
            .catch(error => {
                this.scheduleErrorMessage = 'Schedule failed: ' +
                    (error.body?.message ?? error.message);
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Schedule Failed',
                    message: this.scheduleErrorMessage,
                    variant: 'error'
                }));
            });
    }

    _loadObjectTypes() {
        this.isLoadingObjectTypes = true;
        this.errorMessage = '';

        getDeletedRecordCounts()
            .then(data => {
                this.objectTypeOptions = data.map(opt => ({
                    label: opt.label.replace(/\s*\(\d+\)/, ''),
                    value: opt.value
                })).sort((a, b) => a.label.localeCompare(b.label));
                if (this.objectTypeOptions.length === 0) {
                    this.errorMessage = 'No deleted records found in the Recycle Bin.';
                }
            })
            .catch(error => {
                this.errorMessage = 'Error loading object types: ' +
                    (error.body?.message ?? error.message);
            })
            .finally(() => { this.isLoadingObjectTypes = false; });
    }

    _fetchDeletedRecords(objectType) {
        this.isLoadingRecords = true;
        this.errorMessage = '';

        getDeletedRecordsByType({ objectType })
            .then(records => {
                this._allFetchedRecords = records ?? [];
                this.recordOptions = this._allFetchedRecords.map(rec => ({
                    label: (rec.name && rec.name.trim()) ? rec.name : rec.id,
                    value: rec.id
                }));

                if (this.recordOptions.length === 0) {
                    this.errorMessage = `No deleted records found for "${objectType}".`;
                }
            })
            .catch(error => {
                this.errorMessage = 'Error loading records: ' +
                    (error.body?.message ?? error.message);
                this.recordOptions = [];
            })
            .finally(() => {
                this.isLoadingRecords = false;
            });
    }

    _loadScheduleObjectTypes() {
        this.isLoadingObjectTypes = true;
        this.scheduleErrorMessage = '';

        getDeletedRecordCounts()
            .then(data => {
                this.scheduleObjectTypeOptions = data.map(opt => ({
                    label: opt.label.replace(/\s*\(\d+\)/, ''),
                    value: opt.value
                })).sort((a, b) => a.label.localeCompare(b.label));
                if (this.scheduleObjectTypeOptions.length === 0) {
                    this.scheduleErrorMessage = 'No deleted records found in the Recycle Bin.';
                }
            })
            .catch(error => {
                this.scheduleErrorMessage = 'Error loading object types: ' +
                    (error.body?.message ?? error.message);
            })
            .finally(() => { this.isLoadingObjectTypes = false; });
    }

    _fetchScheduleDeletedRecords(objectType) {
        this.isScheduleLoadingRecords = true;
        this.scheduleErrorMessage = '';
        getDeletedRecordsByType({ objectType })
            .then(records => {
                this._scheduleAllFetchedRecords = records ?? [];
                this.scheduleRecordOptions = this._scheduleAllFetchedRecords.map(rec => ({
                    label: rec.name || rec.id,
                    value: rec.id
                }));
                if (this.scheduleRecordOptions.length === 0) {
                    this.scheduleErrorMessage = `No deleted records found for "${objectType}".`;
                }
            })
            .catch(error => {
                this.scheduleErrorMessage = 'Error loading records: ' +
                    (error.body?.message ?? error.message);
                this.scheduleRecordOptions = [];
            })
            .finally(() => { this.isScheduleLoadingRecords = false; });
    }

    toggleObjectDropdown(event) {
        event.stopPropagation();
        this.isObjectDropdownOpen = !this.isObjectDropdownOpen;
        this.isRecordDropdownOpen = false;
    }

    handleObjectSearch(event) { this.objectSearchTerm = event.detail.value; }

    handleObjectTypeToggle(event) {
        event.stopPropagation();
        const val = event.currentTarget.dataset.value;
        this.selectedObjectTypeValues = this._toggle(this.selectedObjectTypeValues, val);
        this._resetRecords();
        if (this.selectedObjectTypeValues.length === 1) {
            this._fetchDeletedRecords(this.selectedObjectTypeValues[0]);
        }
    }

    toggleSelectAllObjectTypes(event) {
        event.stopPropagation();
        this.selectedObjectTypeValues = this.isAllObjectTypesSelected
            ? [] : this.objectTypeOptions.map(o => o.value);
        this._resetRecords();
    }

    clearObjectTypes(event) {
        event.stopPropagation();
        this.selectedObjectTypeValues = [];
        this.isObjectDropdownOpen = false;
        this._resetRecords();
    }

    toggleRecordDropdown(event) {
        event.stopPropagation();
        if (this.isRecordDropdownDisabled) return;
        this.isRecordDropdownOpen = !this.isRecordDropdownOpen;
        this.isObjectDropdownOpen = false;
    }

    handleRecordSearch(event) { this.recordSearchTerm = event.detail.value; }

    handleRecordToggle(event) {
        event.stopPropagation();
        this.selectedRecordValues = this._toggle(
            this.selectedRecordValues, event.currentTarget.dataset.value
        );
        this._refreshTable();
    }

    toggleSelectAllRecords(event) {
        event.stopPropagation();
        this.selectedRecordValues = this.isAllRecordsSelected
            ? [] : this.recordOptions.map(r => r.value);
        this._refreshTable();
    }

    clearRecords(event) {
        event.stopPropagation();
        this.selectedRecordValues = [];
        this.showRecordsTable = false;
        this.tableData = [];
        this.isRecordDropdownOpen = false;
    }

    handleFrequencyChange(event) { this.scheduleFrequency = event.detail.value; }
    handleRestoreTimeChange(event) { this.scheduleRestoreTime = event.detail.value; }

    toggleScheduleObjectDropdown(event) {
        event.stopPropagation();
        this.isScheduleObjectDropdownOpen = !this.isScheduleObjectDropdownOpen;
        this.isScheduleRecordDropdownOpen = false;
    }

    handleScheduleObjectSearch(event) { this.scheduleObjectSearchTerm = event.detail.value; }

    handleScheduleObjectTypeToggle(event) {
        event.stopPropagation();
        const val = event.currentTarget.dataset.value;
        this.scheduleSelectedObjectTypeValues =
            this._toggle(this.scheduleSelectedObjectTypeValues, val);
        this._resetScheduleRecords();
        if (this.scheduleSelectedObjectTypeValues.length === 1) {
            this._fetchScheduleDeletedRecords(this.scheduleSelectedObjectTypeValues[0]);
        }
    }

    toggleScheduleSelectAllObjectTypes(event) {
        event.stopPropagation();
        this.scheduleSelectedObjectTypeValues = this.isScheduleAllObjectTypesSelected
            ? [] : this.scheduleObjectTypeOptions.map(o => o.value);
        this._resetScheduleRecords();
    }

    clearScheduleObjectTypes(event) {
        event.stopPropagation();
        this.scheduleSelectedObjectTypeValues = [];
        this.isScheduleObjectDropdownOpen = false;
        this._resetScheduleRecords();
    }

    toggleScheduleRecordDropdown(event) {
        event.stopPropagation();
        if (this.isScheduleRecordDropdownDisabled) return;
        this.isScheduleRecordDropdownOpen = !this.isScheduleRecordDropdownOpen;
        this.isScheduleObjectDropdownOpen = false;
    }

    handleScheduleRecordSearch(event) { this.scheduleRecordSearchTerm = event.detail.value; }

    handleScheduleRecordToggle(event) {
        event.stopPropagation();
        this.scheduleSelectedRecordValues =
            this._toggle(this.scheduleSelectedRecordValues, event.currentTarget.dataset.value);
    }

    toggleScheduleSelectAllRecords(event) {
        event.stopPropagation();
        this.scheduleSelectedRecordValues = this.isScheduleAllRecordsSelected
            ? [] : this.scheduleRecordOptions.map(r => r.value);
    }

    clearScheduleRecords(event) {
        event.stopPropagation();
        this.scheduleSelectedRecordValues = [];
        this.isScheduleRecordDropdownOpen = false;
    }

    stopPropagation(event) { event.stopPropagation(); }

    _toggle(arr, val) {
        return arr.includes(val) ? arr.filter(v => v !== val) : [...arr, val];
    }

    _refreshTable() {
        if (this.selectedRecordValues.length > 0) {
            this.tableData = this._allFetchedRecords
                .filter(r => this.selectedRecordValues.includes(r.id))
                .map(r => ({
                    id: r.id,
                    name: r.name,
                    objectType: r.objectType,
                    deletedDate: r.deletedDate,
                    deletedBy: r.deletedBy
                }));
            this.showRecordsTable = true;
        } else {
            this.tableData = [];
            this.showRecordsTable = false;
        }
    }

    _resetRecords() {
        this.selectedRecordValues = [];
        this.recordOptions = [];
        this._allFetchedRecords = [];
        this.tableData = [];
        this.showRecordsTable = false;
        this.recordSearchTerm = '';
        this.isRecordDropdownOpen = false;
    }

    _resetInstant() {
        this.selectedObjectTypeValues = [];
        this.objectSearchTerm = '';
        this.isObjectDropdownOpen = false;
        this.objectTypeOptions = [];
        this.isLoadingObjectTypes = false;
        this.errorMessage = '';
        this.successMessage = '';
        this.isRestoring = false;
        this.jobRows = [];
        this.restoreJobIds = [];
        this._stopPolling();
        this._resetRecords();
    }

    _resetScheduleRecords() {
        this.scheduleSelectedRecordValues = [];
        this.scheduleRecordOptions = [];
        this._scheduleAllFetchedRecords = [];
        this.scheduleRecordSearchTerm = '';
        this.isScheduleRecordDropdownOpen = false;
    }

    _resetSchedule() {
        this.scheduleSelectedObjectTypeValues = [];
        this.scheduleObjectTypeOptions = [];
        this.scheduleObjectSearchTerm = '';
        this.isScheduleObjectDropdownOpen = false;
        this.scheduleFrequency = '';
        this.scheduleRestoreTime = '';
        this.scheduleErrorMessage = '';
        this.isLoadingObjectTypes = false;
        this._resetScheduleRecords();
    }

    get isInstantSelected() { return this.selectedRestoreType === 'instant'; }
    get isScheduleSelected() { return this.selectedRestoreType === 'schedule'; }
    get isNextDisabled() { return !this.selectedRestoreType; }

    get isStartRestoreDisabled() {
        return this.selectedObjectTypeValues.length === 0 || this.isRestoring || this.showJobTable;
    }

    get isBackDisabled() {
        return this.isRestoring || this.showJobTable;
    }

    get isRestoreInProgress() {
        return this.showJobTable;
    }

    get hasJobRows() { return this.jobRows && this.jobRows.length > 0; }

    get hasSelectedObjectTypes() { return this.selectedObjectTypeValues.length > 0; }
    get selectedObjectTypesCount() { return this.selectedObjectTypeValues.length; }

    get selectedObjectTypeLabels() {
        const labels = this.objectTypeOptions
            .filter(o => this.selectedObjectTypeValues.includes(o.value)).map(o => o.label);
        if (labels.length === 0) return '';
        if (labels.length === 1) return labels[0];
        return `${labels[0]} +${labels.length - 1} more`;
    }

    get isAllObjectTypesSelected() {
        return this.objectTypeOptions.length > 0 &&
            this.selectedObjectTypeValues.length === this.objectTypeOptions.length;
    }

    get selectAllObjectTypesCheckboxClass() {
        return this.isAllObjectTypesSelected ? 'ms-checkbox ms-checkbox--checked' : 'ms-checkbox';
    }

    get objectTriggerClass() {
        return this.objectTypeOptions.length === 0 ? 'ms-trigger ms-trigger--disabled' : 'ms-trigger';
    }

    get filteredObjectTypes() {
        const term = this.objectSearchTerm.toLowerCase();
        return this.objectTypeOptions
            .filter(o => !term || o.label.toLowerCase().includes(term))
            .map(o => {
                const checked = this.selectedObjectTypeValues.includes(o.value);
                return {
                    ...o, checked,
                    itemClass: checked ? 'ms-item ms-item--selected' : 'ms-item',
                    checkboxClass: checked ? 'ms-checkbox ms-checkbox--checked' : 'ms-checkbox'
                };
            });
    }

    get hasFilteredObjectTypes() { return this.filteredObjectTypes.length > 0; }

    get hasSelectedRecords() { return this.selectedRecordValues.length > 0; }
    get selectedRecordsCount() { return this.selectedRecordValues.length; }

    get selectedRecordLabels() {
        const labels = this.recordOptions
            .filter(r => this.selectedRecordValues.includes(r.value)).map(r => r.label);
        if (labels.length === 0) return '';
        if (labels.length === 1) return labels[0];
        return `${labels[0]} +${labels.length - 1} more`;
    }

    get isAllRecordsSelected() {
        return this.recordOptions.length > 0 &&
            this.selectedRecordValues.length === this.recordOptions.length;
    }

    get selectAllRecordsCheckboxClass() {
        return this.isAllRecordsSelected ? 'ms-checkbox ms-checkbox--checked' : 'ms-checkbox';
    }

    get isRecordDropdownDisabled() {
        return this.selectedObjectTypeValues.length !== 1 ||
            this.isLoadingRecords || this.recordOptions.length === 0;
    }

    get recordTriggerClass() {
        return this.isRecordDropdownDisabled ? 'ms-trigger ms-trigger--disabled' : 'ms-trigger';
    }

    get recordDropdownPlaceholder() {
        if (this.selectedObjectTypeValues.length === 0) return 'Select an Object to Continue';
        if (this.selectedObjectTypeValues.length > 1) return 'Multiple objects selected';
        if (this.recordOptions.length === 0) return 'No records found';
        return 'Choose Records';
    }

    get filteredRecords() {
        const term = this.recordSearchTerm.toLowerCase();
        return this.recordOptions
            .filter(r => !term || r.label.toLowerCase().includes(term))
            .map(r => {
                const checked = this.selectedRecordValues.includes(r.value);
                return {
                    ...r, checked,
                    itemClass: checked ? 'ms-item ms-item--selected' : 'ms-item',
                    checkboxClass: checked ? 'ms-checkbox ms-checkbox--checked' : 'ms-checkbox'
                };
            });
    }

    get hasFilteredRecords() { return this.filteredRecords.length > 0; }

    get frequencyOptions() {
        return [
            { label: 'Daily', value: 'daily' },
            { label: 'Weekly', value: 'weekly' },
            { label: 'Monthly', value: 'monthly' }
        ];
    }

    get restoreTimeOptions() {
        const options = [];
        for (let h = 0; h < 24; h++) {
            const period = h < 12 ? 'AM' : 'PM';
            const hour = h === 0 ? 12 : h > 12 ? h - 12 : h;
            options.push({
                label: `${hour}:00 ${period}`,
                value: `${String(h).padStart(2, '0')}:00`
            });
        }
        return options;
    }

    get isScheduleDisabled() {
        return !this.scheduleFrequency ||
            !this.scheduleRestoreTime ||
            this.scheduleSelectedObjectTypeValues.length === 0;
    }

    get hasScheduleSelectedObjectTypes() { return this.scheduleSelectedObjectTypeValues.length > 0; }
    get scheduleSelectedObjectTypesCount() { return this.scheduleSelectedObjectTypeValues.length; }

    get scheduleSelectedObjectTypeLabels() {
        const labels = this.scheduleObjectTypeOptions
            .filter(o => this.scheduleSelectedObjectTypeValues.includes(o.value)).map(o => o.label);
        if (labels.length === 0) return '';
        if (labels.length === 1) return labels[0];
        return `${labels[0]} +${labels.length - 1} more`;
    }

    get isScheduleAllObjectTypesSelected() {
        return this.scheduleObjectTypeOptions.length > 0 &&
            this.scheduleSelectedObjectTypeValues.length === this.scheduleObjectTypeOptions.length;
    }

    get scheduleSelectAllObjectTypesCheckboxClass() {
        return this.isScheduleAllObjectTypesSelected ? 'ms-checkbox ms-checkbox--checked' : 'ms-checkbox';
    }

    get scheduleObjectTriggerClass() {
        return this.scheduleObjectTypeOptions.length === 0
            ? 'ms-trigger ms-trigger--disabled' : 'ms-trigger';
    }

    get filteredScheduleObjectTypes() {
        const term = this.scheduleObjectSearchTerm.toLowerCase();
        return this.scheduleObjectTypeOptions
            .filter(o => !term || o.label.toLowerCase().includes(term))
            .map(o => {
                const checked = this.scheduleSelectedObjectTypeValues.includes(o.value);
                return {
                    ...o, checked,
                    itemClass: checked ? 'ms-item ms-item--selected' : 'ms-item',
                    checkboxClass: checked ? 'ms-checkbox ms-checkbox--checked' : 'ms-checkbox'
                };
            });
    }

    get hasFilteredScheduleObjectTypes() { return this.filteredScheduleObjectTypes.length > 0; }

    get hasScheduleSelectedRecords() { return this.scheduleSelectedRecordValues.length > 0; }
    get scheduleSelectedRecordsCount() { return this.scheduleSelectedRecordValues.length; }

    get scheduleSelectedRecordLabels() {
        const labels = this.scheduleRecordOptions
            .filter(r => this.scheduleSelectedRecordValues.includes(r.value)).map(r => r.label);
        if (labels.length === 0) return '';
        if (labels.length === 1) return labels[0];
        return `${labels[0]} +${labels.length - 1} more`;
    }

    get isScheduleAllRecordsSelected() {
        return this.scheduleRecordOptions.length > 0 &&
            this.scheduleSelectedRecordValues.length === this.scheduleRecordOptions.length;
    }

    get scheduleSelectAllRecordsCheckboxClass() {
        return this.isScheduleAllRecordsSelected ? 'ms-checkbox ms-checkbox--checked' : 'ms-checkbox';
    }

    get isScheduleRecordDropdownDisabled() {
        return this.scheduleSelectedObjectTypeValues.length !== 1 ||
            this.isScheduleLoadingRecords || this.scheduleRecordOptions.length === 0;
    }

    get scheduleRecordTriggerClass() {
        return this.isScheduleRecordDropdownDisabled
            ? 'ms-trigger ms-trigger--disabled' : 'ms-trigger';
    }

    get scheduleRecordDropdownPlaceholder() {
        if (this.scheduleSelectedObjectTypeValues.length === 0) return 'Select an Object to Continue';
        if (this.scheduleSelectedObjectTypeValues.length > 1) return 'Multiple objects selected';
        if (this.scheduleRecordOptions.length === 0) return 'No records found';
        return 'Choose Records';
    }

    get filteredScheduleRecords() {
        const term = this.scheduleRecordSearchTerm.toLowerCase();
        return this.scheduleRecordOptions
            .filter(r => !term || r.label.toLowerCase().includes(term))
            .map(r => {
                const checked = this.scheduleSelectedRecordValues.includes(r.value);
                return {
                    ...r, checked,
                    itemClass: checked ? 'ms-item ms-item--selected' : 'ms-item',
                    checkboxClass: checked ? 'ms-checkbox ms-checkbox--checked' : 'ms-checkbox'
                };
            });
    }

    get hasFilteredScheduleRecords() { return this.filteredScheduleRecords.length > 0; }

    get isMultipleObjectsSelected() {
        return this.selectedObjectTypeValues.length > 1;
    }

    get noRecordsAvailable() {
        return !this.isLoadingRecords &&
            this.selectedObjectTypeValues.length === 1 &&
            this.recordOptions.length === 0;
    }

    get isScheduleMultipleObjectsSelected() {
        return this.scheduleSelectedObjectTypeValues.length > 1;
    }

    get scheduleNoRecordsAvailable() {
        return !this.isScheduleLoadingRecords &&
            this.scheduleSelectedObjectTypeValues.length === 1 &&
            this.scheduleRecordOptions.length === 0;
    }
}