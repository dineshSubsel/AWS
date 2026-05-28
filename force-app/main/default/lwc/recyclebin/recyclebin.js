import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getDeletedRecordCounts from '@salesforce/apex/RecycleBinVaultController.getDeletedRecordCounts';
import getDeletedRecordsByType from '@salesforce/apex/RecycleBinVaultController.getDeletedRecordsByType';
import startInstantBackup from '@salesforce/apex/RecycleBinVaultController.startInstantBackup';
import startMultiObjectBackup from '@salesforce/apex/RecycleBinVaultController.startMultiObjectBackup';
import areAllJobsDone from '@salesforce/apex/RecycleBinVaultController.areAllJobsDone';
import getJobDetails from '@salesforce/apex/RecycleBinVaultController.getJobDetails';
import cancelJob from '@salesforce/apex/RecycleBinVaultController.cancelJob';
import scheduleBackup from '@salesforce/apex/RecycleBinVaultController.scheduleBackup';

export default class Recyclebin extends LightningElement {

    @track showRestorePage = false;
    @track showOptionSelection = true;
    @track showBackupOptions = false;
    @track showSearchPage = false;
    @track showSchedulePage = false;

    selectedOption = '';
    selectedBackupType = '';

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

    @track isBackingUp = false;
    @track backupJobIds = [];
    @track backupDone = false;
    @track jobRows = [];
    @track errorMessage = '';

    _allFetchedRecords = [];
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

    @track scheduleObjectTypeOptions = [];
    @track scheduleSelectedObjectTypeValues = [];
    @track scheduleObjectSearchTerm = '';
    @track isScheduleObjectDropdownOpen = false;

    @track scheduleRecordOptions = [];
    @track scheduleSelectedRecordValues = [];
    @track scheduleRecordSearchTerm = '';
    @track isScheduleRecordDropdownOpen = false;
    @track isScheduleLoadingRecords = false;

    @track scheduleFrequency = '';
    @track scheduleBackupTime = '';
    @track scheduleErrorMessage = '';
    @track isScheduling = false;

    _scheduleAllFetchedRecords = [];

    connectedCallback() {
        this._handleOutsideClick = this._onOutsideClick.bind(this);
        window.addEventListener('click', this._handleOutsideClick);
    }

    disconnectedCallback() {
        window.removeEventListener('click', this._handleOutsideClick);
        if (this._pollInterval) {
            clearInterval(this._pollInterval);
            this._pollInterval = null;
        }
    }

    _onOutsideClick(event) {
        if (!this.template.contains(event.target)) {
            this.isObjectDropdownOpen = false;
            this.isRecordDropdownOpen = false;
            this.isScheduleObjectDropdownOpen = false;
            this.isScheduleRecordDropdownOpen = false;
        }
    }

    handleSelection(event) {
        this.selectedOption = event.target.value;
    }

    handleNext() {
        this.showOptionSelection = false;
        if (this.selectedOption === 'backup') {
            this.showBackupOptions = true;
        } else {
            this.showRestorePage = true;
        }
    }

    handleRestoreBack() {
        this.showRestorePage = false;
        this.showOptionSelection = true;
    }

    handleBackupType(event) {
        this.selectedBackupType = event.target.value;
    }

    handleBack() {
        this.showBackupOptions = false;
        this.showOptionSelection = true;
        this.selectedBackupType = '';
    }

    handleBackupNext() {
        this.showBackupOptions = false;
        if (this.selectedBackupType === 'instant') {
            this._resetAll();
            this.showSearchPage = true;
            this._loadObjectTypes();
        } else {
            this._resetSchedule();
            this.showSchedulePage = true;
            this._loadScheduleObjectTypes();
        }
    }

    handleSearchBack() {
        this.showSearchPage = false;
        this.showBackupOptions = true;
        this.selectedBackupType = 'instant';
    }

    startMigration() {
        const objectTypes = this.selectedObjectTypeValues;
        const recordIds = this.selectedRecordValues;

        if (!objectTypes || objectTypes.length === 0) {
            this.errorMessage = 'Please select at least one object type.';
            return;
        }

        this.isBackingUp = true;
        this.errorMessage = '';
        this.backupDone = false;
        this.backupJobIds = [];
        this.jobRows = [];

        if (objectTypes.length === 1) {
            startInstantBackup({
                objectType: objectTypes[0],
                recordIdsJson: JSON.stringify(recordIds)
            })
                .then(jobId => {
                    if (jobId) {
                        this.backupJobIds = [jobId];
                        this._startPolling();
                    } else {
                        this._onBackupComplete();
                    }
                })
                .catch(error => {
                    this.errorMessage = 'Backup failed: ' + (error.body?.message ?? error.message);
                    this.isBackingUp = false;
                });

        } else {
            startMultiObjectBackup({ objectTypesJson: JSON.stringify(objectTypes) })
                .then(jobMapJson => {
                    const ids = Object.values(JSON.parse(jobMapJson))
                        .filter(v => v && !v.startsWith('ERROR'));
                    if (ids.length > 0) {
                        this.backupJobIds = ids;
                        this._startPolling();
                    } else {
                        this._onBackupComplete();
                    }
                })
                .catch(error => {
                    this.errorMessage = 'Backup failed: ' + (error.body?.message ?? error.message);
                    this.isBackingUp = false;
                });
        }
    }

    _startPolling() {
        if (this._pollInterval) {
            clearInterval(this._pollInterval);
            this._pollInterval = null;
        }

        this._fetchJobRows();

        this._pollInterval = setInterval(() => {
            this._fetchJobRows();
            this._checkAllDone();
        }, 4000);
    }

    _fetchJobRows() {
        if (!this.backupJobIds?.length) return;

        getJobDetails({ jobIdsJson: JSON.stringify(this.backupJobIds) })
            .then(rows => {
                if (!rows || rows.length === 0) {
                    this.jobRows = [];
                    return;
                }

                const sorted = [...rows].sort(
                    (a, b) => new Date(b.startTime) - new Date(a.startTime)
                );

                const latest = sorted[0];
                const isRunning = ['Queued', 'Holding', 'Processing', 'Preparing']
                    .includes(latest.status);

                this.jobRows = [{
                    ...latest,
                    isNotRunning: !isRunning
                }];
            })
            .catch();
    }

    _checkAllDone() {
        if (!this.backupJobIds?.length) return;

        areAllJobsDone({ jobIdsJson: JSON.stringify(this.backupJobIds) })
            .then(done => {
                if (done) {
                    clearInterval(this._pollInterval);
                    this._pollInterval = null;
                    getJobDetails({ jobIdsJson: JSON.stringify(this.backupJobIds) })
                        .then(rows => {
                            if (rows && rows.length > 0) {
                                const sorted = [...rows].sort(
                                    (a, b) => new Date(b.startTime) - new Date(a.startTime)
                                );
                                const latest = sorted[0];
                                const isRunning = ['Queued', 'Holding', 'Processing', 'Preparing']
                                    .includes(latest.status);

                                this.jobRows = [{
                                    ...latest,
                                    isNotRunning: !isRunning
                                }];
                                if (latest.status === 'Aborted') {
                                    this.dispatchEvent(new ShowToastEvent({
                                        title: 'Job Cancelled',
                                        message: 'Backup job has been cancelled.',
                                        variant: 'warning'
                                    }));
                                    setTimeout(() => {
                                        this.isBackingUp = false;
                                        this._resetAll();
                                    }, 5000);
                                    return;
                                }
                            }

                            this._onBackupComplete();
                        })
                        .catch(() => {
                            this._onBackupComplete();
                        });
                }
            })
            .catch();
    }

    _onBackupComplete() {
        this.backupDone = true;
        this.dispatchEvent(new ShowToastEvent({
            title: 'Backup Complete',
            message: 'Recycle Bin records have been backed up to S3 successfully.',
            variant: 'success'
        }));

        setTimeout(() => {
            this.isBackingUp = false;
            this._resetAll();
        }, 5000);
    }

    handleRowAction(event) {
        const jobId = event.detail.row.jobId;

        cancelJob({ jobId })
            .then(() => {
                // this.dispatchEvent(new ShowToastEvent({
                //     title: 'Job Cancelled',
                //     message: 'Backup job ' + jobId + ' has been cancelled.',
                //     variant: 'warning'
                // }));
                this._fetchJobRows();
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Cancel Failed',
                    message: error.body?.message ?? error.message,
                    variant: 'error'
                }));
            });
    }

    handleScheduleBack() {
        this.showSchedulePage = false;
        this.showBackupOptions = true;
        this.selectedBackupType = 'schedule';
    }

    handleFrequencyChange(event) {
        this.scheduleFrequency = event.detail.value;
    }

    handleBackupTimeChange(event) {
        this.scheduleBackupTime = event.detail.value;
    }

    confirmSchedule() {
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
        if (!this.scheduleBackupTime) {
            this.scheduleErrorMessage = 'Please select a backup time.';
            return;
        }

        this.isScheduling = true;
        this.scheduleErrorMessage = '';

        scheduleBackup({
            objectTypesJson: JSON.stringify(objectTypes),
            recordIdsJson: JSON.stringify(recordIds),
            frequency: this.scheduleFrequency,
            backupTime: this.scheduleBackupTime
        })
            .then(() => {
                this.isScheduling = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Schedule Created',
                    message: 'Recycle Bin backup has been scheduled successfully.',
                    variant: 'success'
                }));
                this._resetSchedule();
            })
            .catch(error => {
                this.isScheduling = false;
                this.scheduleErrorMessage = 'Schedule failed: ' + (error.body?.message ?? error.message);
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

                // ✅ Show ALL records, use Id as label fallback
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
            .finally(() => { this.isLoadingRecords = false; });
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
                    label: (rec.name && rec.name.trim()) ? rec.name : rec.id,
                    value: rec.id
                }));
                if (this.scheduleRecordOptions.length === 0) {
                    this.scheduleErrorMessage = `No deleted records found for "${objectType}".`;
                }
            })
            .catch(error => {
                this.scheduleErrorMessage = 'Error loading records: ' + (error.body?.message ?? error.message);
                this.scheduleRecordOptions = [];
            })
            .finally(() => { this.isScheduleLoadingRecords = false; });
    }

    toggleObjectDropdown(event) {
        event.stopPropagation();
        this.isObjectDropdownOpen = !this.isObjectDropdownOpen;
        this.isRecordDropdownOpen = false;
    }

    handleObjectSearch(event) {
        this.objectSearchTerm = event.detail.value;
    }

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
            ? []
            : this.objectTypeOptions.map(o => o.value);
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

    handleRecordSearch(event) {
        this.recordSearchTerm = event.detail.value;
    }

    handleRecordToggle(event) {
        event.stopPropagation();
        this.selectedRecordValues = this._toggle(
            this.selectedRecordValues, event.currentTarget.dataset.value
        );
    }

    toggleSelectAllRecords(event) {
        event.stopPropagation();
        this.selectedRecordValues = this.isAllRecordsSelected
            ? []
            : this.recordOptions.map(r => r.value);
    }

    clearRecords(event) {
        event.stopPropagation();
        this.selectedRecordValues = [];
        this.isRecordDropdownOpen = false;
    }

    toggleScheduleObjectDropdown(event) {
        event.stopPropagation();
        this.isScheduleObjectDropdownOpen = !this.isScheduleObjectDropdownOpen;
        this.isScheduleRecordDropdownOpen = false;
    }

    handleScheduleObjectSearch(event) {
        this.scheduleObjectSearchTerm = event.detail.value;
    }

    handleScheduleObjectTypeToggle(event) {
        event.stopPropagation();
        const val = event.currentTarget.dataset.value;
        this.scheduleSelectedObjectTypeValues = this._toggle(this.scheduleSelectedObjectTypeValues, val);
        this._resetScheduleRecords();
        if (this.scheduleSelectedObjectTypeValues.length === 1) {
            this._fetchScheduleDeletedRecords(this.scheduleSelectedObjectTypeValues[0]);
        }
    }

    toggleScheduleSelectAllObjectTypes(event) {
        event.stopPropagation();
        this.scheduleSelectedObjectTypeValues = this.isScheduleAllObjectTypesSelected
            ? []
            : this.scheduleObjectTypeOptions.map(o => o.value);
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

    handleScheduleRecordSearch(event) {
        this.scheduleRecordSearchTerm = event.detail.value;
    }

    handleScheduleRecordToggle(event) {
        event.stopPropagation();
        this.scheduleSelectedRecordValues = this._toggle(
            this.scheduleSelectedRecordValues, event.currentTarget.dataset.value
        );
    }

    toggleScheduleSelectAllRecords(event) {
        event.stopPropagation();
        this.scheduleSelectedRecordValues = this.isScheduleAllRecordsSelected
            ? []
            : this.scheduleRecordOptions.map(r => r.value);
    }

    clearScheduleRecords(event) {
        event.stopPropagation();
        this.scheduleSelectedRecordValues = [];
        this.isScheduleRecordDropdownOpen = false;
    }

    _toggle(arr, val) {
        return arr.includes(val) ? arr.filter(v => v !== val) : [...arr, val];
    }

    _resetRecords() {
        this.selectedRecordValues = [];
        this.recordOptions = [];
        this._allFetchedRecords = [];
        this.recordSearchTerm = '';
        this.isRecordDropdownOpen = false;
    }

    _resetAll() {
        this.selectedObjectTypeValues = [];
        this.objectSearchTerm = '';
        this.isObjectDropdownOpen = false;
        this.isLoadingObjectTypes = false;
        this.errorMessage = '';
        this.isBackingUp = false;
        this.backupDone = false;
        this.backupJobIds = [];
        this.jobRows = [];
        if (this._pollInterval) {
            clearInterval(this._pollInterval);
            this._pollInterval = null;
        }
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
        this.scheduleObjectSearchTerm = '';
        this.isScheduleObjectDropdownOpen = false;
        this.scheduleFrequency = '';
        this.scheduleBackupTime = '';
        this.scheduleErrorMessage = '';
        this.isScheduling = false;
        this._resetScheduleRecords();
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    get isBackupSelected() { return this.selectedOption === 'backup'; }
    get isRestoreSelected() { return this.selectedOption === 'restore'; }
    get isInstantSelected() { return this.selectedBackupType === 'instant'; }
    get isScheduleSelected() { return this.selectedBackupType === 'schedule'; }
    get isNextDisabled() { return !this.selectedOption; }
    get isBackupNextDisabled() { return !this.selectedBackupType; }
    get isBackupInProgress() { return this.isBackingUp; }
    get hasJobRows() { return this.jobRows && this.jobRows.length > 0; }

    get isStartBackupDisabled() {
        return this.selectedObjectTypeValues.length === 0 || this.isBackingUp;
    }

    get hasSelectedObjectTypes() { return this.selectedObjectTypeValues.length > 0; }
    get selectedObjectTypesCount() { return this.selectedObjectTypeValues.length; }

    get isScheduleMultipleObjectsSelected() {
        return this.scheduleSelectedObjectTypeValues.length > 1;
    }

    get isScheduleSingleObjectSelected() {
        return this.scheduleSelectedObjectTypeValues.length === 1;
    }

    get isScheduleNoObjectSelected() {
        return this.scheduleSelectedObjectTypeValues.length === 0;
    }

    get hasScheduleRecords() {
        return this.scheduleRecordOptions.length > 0;
    }

    get noScheduleRecordsAvailable() {
        return this.isScheduleSingleObjectSelected &&
            !this.hasScheduleRecords &&
            !this.isScheduleLoadingRecords;
    }

    get isMultipleObjectsSelected() {
        return this.selectedObjectTypeValues.length > 1;
    }

    get isSingleObjectSelected() {
        return this.selectedObjectTypeValues.length === 1;
    }

    get isNoObjectSelected() {
        return this.selectedObjectTypeValues.length === 0;
    }

    get hasRecords() {
        return this.recordOptions.length > 0;
    }

    get noRecordsAvailable() {
        return this.isSingleObjectSelected && !this.hasRecords && !this.isLoadingRecords;
    }

    get selectedObjectTypeLabels() {
        const labels = this.objectTypeOptions
            .filter(o => this.selectedObjectTypeValues.includes(o.value))
            .map(o => o.label);
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
            .filter(r => this.selectedRecordValues.includes(r.value))
            .map(r => r.label);
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
            this.isLoadingRecords ||
            this.recordOptions.length === 0;
    }

    get recordTriggerClass() {
        return this.isRecordDropdownDisabled ? 'ms-trigger ms-trigger--disabled' : 'ms-trigger';
    }

    get recordDropdownPlaceholder() {
        if (this.selectedObjectTypeValues.length === 0) return '-- Select Object Type first --';
        if (this.selectedObjectTypeValues.length > 1) return '-- Select a single Object Type --';
        if (this.recordOptions.length === 0) return '-- No records found --';
        return '-- Select Record --';
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

    get backupTimeOptions() {
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
            !this.scheduleBackupTime ||
            this.scheduleSelectedObjectTypeValues.length === 0 ||
            this.isScheduling;
    }

    get scheduleButtonLabel() {
        return this.isScheduling ? 'Scheduling...' : 'Schedule';
    }

    get hasScheduleSelectedObjectTypes() { return this.scheduleSelectedObjectTypeValues.length > 0; }
    get scheduleSelectedObjectTypesCount() { return this.scheduleSelectedObjectTypeValues.length; }

    get scheduleSelectedObjectTypeLabels() {
        const labels = this.scheduleObjectTypeOptions
            .filter(o => this.scheduleSelectedObjectTypeValues.includes(o.value))
            .map(o => o.label);
        if (labels.length === 0) return '';
        if (labels.length === 1) return labels[0];
        return `${labels[0]} +${labels.length - 1} more`;
    }

    get isScheduleAllObjectTypesSelected() {
        return this.scheduleObjectTypeOptions.length > 0 &&
            this.scheduleSelectedObjectTypeValues.length === this.scheduleObjectTypeOptions.length;
    }

    get scheduleSelectAllObjectTypesCheckboxClass() {
        return this.isScheduleAllObjectTypesSelected
            ? 'ms-checkbox ms-checkbox--checked'
            : 'ms-checkbox';
    }

    get scheduleObjectTriggerClass() {
        return this.scheduleObjectTypeOptions.length === 0
            ? 'ms-trigger ms-trigger--disabled'
            : 'ms-trigger';
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
            .filter(r => this.scheduleSelectedRecordValues.includes(r.value))
            .map(r => r.label);
        if (labels.length === 0) return '';
        if (labels.length === 1) return labels[0];
        return `${labels[0]} +${labels.length - 1} more`;
    }

    get isScheduleAllRecordsSelected() {
        return this.scheduleRecordOptions.length > 0 &&
            this.scheduleSelectedRecordValues.length === this.scheduleRecordOptions.length;
    }

    get scheduleSelectAllRecordsCheckboxClass() {
        return this.isScheduleAllRecordsSelected
            ? 'ms-checkbox ms-checkbox--checked'
            : 'ms-checkbox';
    }

    get isScheduleRecordDropdownDisabled() {
        return this.scheduleSelectedObjectTypeValues.length !== 1 ||
            this.isScheduleLoadingRecords ||
            this.scheduleRecordOptions.length === 0;
    }

    get scheduleRecordTriggerClass() {
        return this.isScheduleRecordDropdownDisabled
            ? 'ms-trigger ms-trigger--disabled'
            : 'ms-trigger';
    }

    get scheduleRecordDropdownPlaceholder() {
        if (this.scheduleSelectedObjectTypeValues.length === 0) return '-- Select Object Type first --';
        if (this.scheduleSelectedObjectTypeValues.length > 1) return '-- Select a single Object Type --';
        if (this.scheduleRecordOptions.length === 0) return '-- No records found --';
        return '-- Select Record --';
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
}