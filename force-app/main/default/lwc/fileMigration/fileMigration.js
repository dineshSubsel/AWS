import { LightningElement, track } from 'lwc';
import getAllSObjects from '@salesforce/apex/FileMigrationHandlersync.getAllSObjects';
import startS3FileMigration from '@salesforce/apex/FileMigrationHandlersync.startS3FileMigration';
import abortS3FileMigration from '@salesforce/apex/FileMigrationHandlersync.abortS3FileMigration';
import scheduleS3FileMigration from '@salesforce/apex/FileMigrationHandlersync.scheduleS3FileMigration';
import previewSOQLRecords from '@salesforce/apex/FileMigrationHandlersync.previewSOQLRecords';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getBackupJobStatus from '@salesforce/apex/FileMigrationHandlersync.getBackupJobStatus';
import areAllJobsDone from '@salesforce/apex/FileMigrationHandlersync.areAllJobsDone';
import abortJob from '@salesforce/apex/FileMigrationHandlersync.abortJob';

export default class FileMigration extends LightningElement {

    // ─── Main form state ───────────────────────────────────────────────────────
    @track selectedFileObject = 'File';
    @track selectedObject = '';
    @track selectedFileFilter = 'All';
    @track soqlFilter = '';
    @track showSoqlError = false;
    @track deleteAfterMigration = true;
    @track objectOptions = [];

    // ─── Migration job state ───────────────────────────────────────────────────
    @track isAbortDisabled = true;
    @track startButtonLabel = 'Start Migration';
    @track isAborting = false;

    // ─── Schedule modal state ──────────────────────────────────────────────────
    @track showScheduleModal = false;
    @track scheduleFrequency = 'Once';
    @track scheduleTime = '12:00';
    @track selectedDays = [];
    @track selectedMonthlyType = 'day';
    @track dayOfMonth = '1';
    @track weekOfMonth = '1';
    @track monthlyDayOfWeek = 'Monday';

    // ─── Job polling ───────────────────────────────────────────────────────────
    @track isBackupInProgress = false;
    @track jobRows = [];
    _pollingInterval = null;
    _activeJobIds = [];

    // ─── Preview state ─────────────────────────────────────────────────────────
    @track previewRows = [];
    @track previewColumns = [];
    @track previewTotalCount = 0;
    @track isPreviewLoading = false;
    @track showPreviewTable = false;

    // ─── Static options ────────────────────────────────────────────────────────
    fileObjectOptions = [
        { label: 'Salesforce Files (File)', value: 'File' },
        { label: 'Attachments (Attachment)', value: 'Attachment' }
    ];

    fileFilterOptions = [
        { label: 'All', value: 'All' },
        { label: 'SOQL Filter', value: 'SOQL Filter' }
    ];

    frequencyOptions = [
        { label: 'Once', value: 'Once' },
        { label: 'Daily', value: 'Daily' },
        { label: 'Weekly', value: 'Weekly' },
        { label: 'Monthly', value: 'Monthly' }
    ];

    dayOfWeekOptions = [
        { label: 'Sunday', value: 'Sunday' },
        { label: 'Monday', value: 'Monday' },
        { label: 'Tuesday', value: 'Tuesday' },
        { label: 'Wednesday', value: 'Wednesday' },
        { label: 'Thursday', value: 'Thursday' },
        { label: 'Friday', value: 'Friday' },
        { label: 'Saturday', value: 'Saturday' }
    ];

    weekOptions = [
        { label: '1st', value: '1' },
        { label: '2nd', value: '2' },
        { label: '3rd', value: '3' },
        { label: '4th', value: '4' },
        { label: 'Last', value: 'last' }
    ];

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
            },
            hideDefaultActions: true
        }
    ];

    timeOptions = (() => {
        const options = [];
        for (let h = 0; h < 24; h++) {
            const hour12 = h === 0 ? 12 : h > 12 ? h - 12 : h;
            const ampm = h < 12 ? 'AM' : 'PM';
            options.push({ label: `${hour12}:00 ${ampm}`, value: String(h).padStart(2, '0') + ':00' });
        }
        return options;
    })();

    @track dayOptions = [];

    // ─── Lifecycle ─────────────────────────────────────────────────────────────
    connectedCallback() {
        this.dayOptions = Array.from({ length: 31 }, (_, i) => {
            const day = i + 1;
            const suffixes = { 1: 'st', 2: 'nd', 3: 'rd', 21: 'st', 22: 'nd', 23: 'rd', 31: 'st' };
            return { label: `${day}${suffixes[day] || 'th'}`, value: String(day) };
        });
        this.loadSObjects();
    }

    // ─── Getters ───────────────────────────────────────────────────────────────
    get isStartDisabled() {
        const objectSelected = !!this.selectedObject;
        const soqlValid = this.selectedFileFilter !== 'SOQL Filter' ||
                          (!!this.soqlFilter && !!this.soqlFilter.trim());
        return !objectSelected || !soqlValid || this.isAborting;
    }

    get isPreviewDisabled() {
        return !this.selectedObject || !this.soqlFilter || !this.soqlFilter.trim();
    }

    get showSOQLInput()     { return this.selectedFileFilter === 'SOQL Filter'; }
    get showDaysSelection() { return this.scheduleFrequency === 'Weekly'; }
    get showDateSelection() { return this.scheduleFrequency === 'Monthly'; }
    get isDayOfMonth()      { return this.selectedMonthlyType === 'day'; }
    get isWeekOfMonth()     { return this.selectedMonthlyType === 'week'; }
    get hasJobRows()        { return this.jobRows && this.jobRows.length > 0; }
    get hasPreviewRows()    { return this.previewRows && this.previewRows.length > 0; }

    get soqlContainerClass() {
        return this.showSoqlError
            ? 'slds-p-around_small slds-has-error'
            : 'slds-p-around_small';
    }

    // ─── Data loading ──────────────────────────────────────────────────────────
    loadSObjects() {
        getAllSObjects()
            .then(result => {
                this.objectOptions = result;
            })
            .catch(() => this.showToast('Error', 'Failed to load object list.', 'error'));
    }

    // ─── Form handlers ─────────────────────────────────────────────────────────
    handleFileObjectChange(event) { this.selectedFileObject = event.detail.value; }

    handleObjectChange(event) {
        this.selectedObject = event.detail.value;
        this._resetPreview();
    }

    handleFilterChange(event) {
        this.selectedFileFilter = event.detail.value;
        if (event.detail.value !== 'SOQL Filter') {
            this.soqlFilter = '';
            this.showSoqlError = false;
            this._resetPreview();
        }
    }

    handleDeleteChange(event)           { this.deleteAfterMigration = event.target.checked; }
    handleTimeChange(event)             { this.scheduleTime = event.detail.value; }
    handleFrequencyChange(event)        { this.scheduleFrequency = event.detail.value; }
    handleDaysChange(event)             { this.selectedDays = event.detail.value; }
    handleDayOfMonthChange(event)       { this.dayOfMonth = event.detail.value; }
    handleWeekOfMonthChange(event)      { this.weekOfMonth = event.detail.value; }
    handleMonthlyDayOfWeekChange(event) { this.monthlyDayOfWeek = event.detail.value; }
    handleMonthlyTypeRadioChange(event) { this.selectedMonthlyType = event.target.value; }

    handleSOQLInput(event) {
        this.soqlFilter = event.target.value;
        this.showSoqlError = !this.soqlFilter || !this.soqlFilter.trim();
        this._resetPreview();
    }

    // ─── Preview handler ───────────────────────────────────────────────────────
    handlePreviewRecords() {
        if (!this.selectedObject || !this.soqlFilter.trim()) return;

        this.isPreviewLoading = true;
        this.showPreviewTable = true;
        this.previewRows = [];
        this.previewColumns = [];
        this.previewTotalCount = 0;

        previewSOQLRecords({
            selectedObject: this.selectedObject,
            soqlCondition: this.soqlFilter
        })
            .then(result => {
                if (!result || result.length === 0) {
                    this.previewRows = [];
                    this.previewTotalCount = 0;
                    return;
                }

                // Fixed Id and Name columns only
                this.previewColumns = [
                    { label: 'ID', fieldName: 'Id', type: 'text', hideDefaultActions: true, wrapText: false },
                    { label: 'Name', fieldName: 'Name', type: 'text', hideDefaultActions: true, wrapText: false }
                ];

                this.previewRows = result.map((row, index) => ({
                    _rowIndex: index,
                    Id: row.Id || '—',
                    Name: row.Name || '—'
                }));

                this.previewTotalCount = result.length;
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || 'Failed to preview records.', 'error');
                this.showPreviewTable = false;
            })
            .finally(() => {
                this.isPreviewLoading = false;
            });
    }

    // ─── Validation ────────────────────────────────────────────────────────────
    validateMainForm() {
        if (!this.selectedObject || !this.selectedFileObject) {
            this.showToast('Error', 'Please select both File Object and Object.', 'error');
            return false;
        }
        if (this.selectedFileFilter === 'SOQL Filter') {
            if (!this.soqlFilter || !this.soqlFilter.trim()) {
                this.showSoqlError = true;
                this.showToast('Error', 'Please enter a valid SOQL filter condition.', 'error');
                return false;
            }
            this.showSoqlError = false;
        }
        return true;
    }

    validateScheduleForm() {
        if (this.scheduleFrequency === 'Weekly' && (!this.selectedDays || !this.selectedDays.length)) {
            this.showToast('Error', 'Please select at least one day for weekly schedule.', 'error');
            return false;
        }
        if (this.scheduleFrequency === 'Monthly') {
            if (this.selectedMonthlyType === 'day') {
                const day = parseInt(this.dayOfMonth, 10);
                if (isNaN(day) || day < 1 || day > 31) {
                    this.showToast('Error', 'Please select a valid day of the month (1–31).', 'error');
                    return false;
                }
            } else if (!this.weekOfMonth || !this.monthlyDayOfWeek) {
                this.showToast('Error', 'Please select both a week and a day for the monthly schedule.', 'error');
                return false;
            }
        }
        return true;
    }

    // ─── Migration actions ─────────────────────────────────────────────────────
    startMigration() {
        if (this.isAborting) { this.showToast('Info', 'Please wait until abort completes.', 'info'); return; }
        if (!this.validateMainForm()) return;

        this.isAbortDisabled = false;
        this.startButtonLabel = 'Starting Migration...';

        startS3FileMigration({
            selectedObject: this.selectedObject,
            mode: this.selectedFileObject,
            deleteAfterMigration: this.deleteAfterMigration,
            filterType: this.selectedFileFilter,
            soqlCondition: this.soqlFilter
        })
            .then(jobIds => {
                if (jobIds && jobIds.length > 0) {
                    this._activeJobIds = jobIds;
                    this.isBackupInProgress = true;
                    this.jobRows = [];
                    this._startPolling();
                }
                this._clearSOQLFilter();
                this.showToast('Success', 'Migration started successfully.', 'success');
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || 'Migration failed.', 'error');
                this.resetButtons();
            });
    }

    abortMigration() {
        if (!this._activeJobIds?.length) {
            this.showToast('Error', 'No active migration jobs to abort.', 'error');
            return;
        }

        this.isAborting = true;
        this.isAbortDisabled = true;
        this.startButtonLabel = 'Aborting...';

        abortS3FileMigration({ jobIds: this._activeJobIds })
            .then(() => {
                this.showToast('Success', 'Migration aborted successfully.', 'success');
                this._stopPolling();
                this.isBackupInProgress = false;
                this._activeJobIds = [];
                this.resetButtons();
            })
            .catch(error => this.showToast('Error', error.body?.message || 'Abort failed.', 'error'))
            .finally(() => { this.isAborting = false; });
    }

    // ─── Schedule actions ──────────────────────────────────────────────────────
    openScheduleModal()  { this.showScheduleModal = true; }

    closeScheduleModal() {
        this.showScheduleModal = false;
        this.scheduleFrequency = 'Once';
        this.scheduleTime = '12:00';
        this.selectedDays = [];
        this.selectedMonthlyType = 'day';
        this.dayOfMonth = '1';
        this.weekOfMonth = '1';
        this.monthlyDayOfWeek = 'Monday';
    }

    confirmSchedule() {
        if (this.isAborting) { this.showToast('Info', 'Please wait until abort completes.', 'info'); return; }
        if (!this.validateMainForm()) return;
        if (!this.validateScheduleForm()) return;

        scheduleS3FileMigration({
            selectedObject: this.selectedObject,
            mode: this.selectedFileObject,
            deleteAfterMigration: this.deleteAfterMigration,
            filterType: this.selectedFileFilter,
            soqlCondition: this.soqlFilter,
            frequency: this.scheduleFrequency,
            scheduledTime: this.scheduleTime,
            daysOfWeek: this.selectedDays.join(','),
            monthlyType: this.selectedMonthlyType,
            dayOfMonth: this.dayOfMonth,
            weekOfMonth: this.weekOfMonth,
            monthlyDayOfWeek: this.monthlyDayOfWeek
        })
            .then(() => {
                this._clearSOQLFilter();
                this.showToast('Success', 'Migration scheduled successfully.', 'success');
                this.closeScheduleModal();
            })
            .catch(error => this.showToast('Error', error.body?.message || 'Failed to schedule migration.', 'error'));
    }

    // ─── Helpers ───────────────────────────────────────────────────────────────
    resetButtons() {
        this.isAbortDisabled = true;
        this.startButtonLabel = 'Start Migration';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    _clearSOQLFilter() {
        this.soqlFilter = '';
        this.showSoqlError = false;
        this._resetPreview();
    }

    _resetPreview() {
        this.showPreviewTable = false;
        this.previewRows = [];
        this.previewColumns = [];
        this.previewTotalCount = 0;
    }

    // ─── Polling ───────────────────────────────────────────────────────────────
    _startPolling() {
        this._stopPolling();
        this._fetchJobRows();
        this._pollingInterval = setInterval(() => this._checkJobStatus(), 5000);
    }

    _stopPolling() {
        if (this._pollingInterval) {
            clearInterval(this._pollingInterval);
            this._pollingInterval = null;
        }
    }

    _fetchJobRows() {
        if (!this._activeJobIds?.length) return;
        getBackupJobStatus({ jobIds: this._activeJobIds })
            .then(rows => {
                if (!rows || !rows.length) { this.jobRows = []; return; }
                const latest = [...rows].sort((a, b) => new Date(b.startTime) - new Date(a.startTime))[0];
                const isRunning = ['Queued', 'Holding', 'Processing', 'Preparing'].includes(latest.status);
                this.jobRows = [{ ...latest, isNotRunning: !isRunning }];
            })
            .catch();
    }

    _checkJobStatus() {
        this._fetchJobRows();
        areAllJobsDone({ jobIds: this._activeJobIds })
            .then(done => {
                if (done) {
                    this._stopPolling();
                    this.isBackupInProgress = false;
                    this._activeJobIds = [];
                    this.showToast('Completed', 'All migration jobs finished.', 'success');
                    this.resetButtons();
                }
            })
            .catch();
    }

    // ─── Row actions ───────────────────────────────────────────────────────────
    handleRowAction(event) {
        if (event.detail.action.name === 'cancel') {
            this.abortJob(event.detail.row.jobId);
        }
    }

    abortJob(jobId) {
        abortJob({ jobId })
            .then(() => {
                this.showToast('Job Cancelled', 'The job has been aborted successfully.', 'success');
                this._fetchJobRows();
            })
            .catch(error => this.showToast('Error', error.body?.message || 'Failed to abort job', 'error'));
    }
}