import { LightningElement, api } from 'lwc';

// ─── Pure UI component — no Apex imports, no @track state, no business logic ──
// All data comes in as @api props from orgBackupManager.
// All user interactions fire custom events upward to orgBackupManager.
// c-org-backup-split-panel is fully inlined — no child component needed.
// ─────────────────────────────────────────────────────────────────────────────

export default class OrgBackupPanel extends LightningElement {

    // ── Navigation flags ──────────────────────────────────────────────────────
    @api showOptionSelection;
    @api showBackupModeSelection;
    @api showRestoreModeSelection;
    @api showBackupTypeSelection;
    @api showRestoreTypeSelection;
    @api showDataBackup;
    @api showMetadataBackup;
    @api showConfigBackup;
    @api showOrgFullBackup;
    @api showRestoreData;
    @api showRestorePanel;

    // ── Selection state ───────────────────────────────────────────────────────
    @api selectedAction;
    @api selectedBackupMode;
    @api selectedRestoreMode;
    @api selectedBackupType;
    @api selectedRestoreType;

    // ── Object/record options ─────────────────────────────────────────────────
    @api rawObjectOptions = [];

    // ── Backup object/record state (renamed from data* → backup*) ─────────────
    @api backupSelectedObjects = [];
    @api backupObjectSearchTerm;
    @api isBackupObjectDropdownOpen;
    @api isSelectAllBackupObjectsLoading;
    @api backupRawRecordOptions = [];
    @api backupSelectedRecords = [];
    @api backupRecordSearchTerm;
    @api isBackupRecordDropdownOpen;
    @api isLoadingBackupRecords;
    @api backupRecordsFetched;

    // ── Restore data state ────────────────────────────────────────────────────
    @api restoreDataSelectedObjects = [];
    @api restoreDataObjectSearchTerm;
    @api isRestoreDataObjectDropdownOpen;
    @api restoreDataRawRecordOptions = [];
    @api restoreDataSelectedRecords = [];
    @api restoreDataRecordSearchTerm;
    @api isRestoreDataRecordDropdownOpen;
    @api isLoadingRestoreDataRecords;
    @api restoreDataRecordsFetched;

    // ── Nav trees ─────────────────────────────────────────────────────────────
    @api metadataNavTree = [];
    @api configNavTree = [];
    @api orgFullNavTree = [];
    @api restoreNavTree = [];

    // ── Panel state ───────────────────────────────────────────────────────────
    @api activePanelItems = [];
    @api hasActivePanelItems;
    @api activePanelTotal;
    @api isActivePanelAllSelected;
    @api isLoadingActivePanel;
    @api showPanelSearchBar;
    @api panelSearchTerm;

    // ── Schedule state ────────────────────────────────────────────────────────
    @api isScheduleMode;
    @api isRestoreScheduleMode;
    @api scheduleMode;
    @api scheduleTime;
    @api scheduleWeekday;
    @api scheduleMonthDay;
    @api restoreScheduleMode;
    @api restoreScheduleTime;
    @api restoreScheduleWeekday;
    @api restoreScheduleMonthDay;
    @api weekdayOptions = [];

    // ── Disabled / validation flags ───────────────────────────────────────────
    @api isMetadataBackupDisabled;
    @api isConfigBackupDisabled;
    @api isOrgFullBackupDisabled;
    @api isRestorePanelDisabled;
    @api isDataBackupDisabled;
    @api isRestoreDataDisabled;
    @api noDataRecordsAvailable;
    @api noRestoreDataRecordsAvailable;

    // ── Restore page labels ───────────────────────────────────────────────────
    @api restorePageTitle;
    @api restorePageIcon;

    // ═════════════════════════════════════════════════════════════════════════
    // Computed getters
    // ═════════════════════════════════════════════════════════════════════════

    get isNextDisabled()            { return !this.selectedAction; }
    get isBackupModeNextDisabled()  { return !this.selectedBackupMode; }
    get isRestoreModeNextDisabled() { return !this.selectedRestoreMode; }
    get isBackupTypeNextDisabled()  { return !this.selectedBackupType; }
    get isRestoreTypeNextDisabled() { return !this.selectedRestoreType; }

    get isBackupSelected()              { return this.selectedAction === 'backup'; }
    get isRestoreSelected()             { return this.selectedAction === 'restore'; }
    get isInstantModeSelected()         { return this.selectedBackupMode === 'instant'; }
    get isScheduleModeSelected()        { return this.selectedBackupMode === 'schedule'; }
    get isInstantRestoreModeSelected()  { return this.selectedRestoreMode === 'instant'; }
    get isScheduleRestoreModeSelected() { return this.selectedRestoreMode === 'schedule'; }

    // Type card CSS
    get backupTypeDataClass()     { return 'type-card' + (this.selectedBackupType === 'data'     ? ' type-card--selected' : ''); }
    get backupTypeMetadataClass() { return 'type-card' + (this.selectedBackupType === 'metadata' ? ' type-card--selected' : ''); }
    get backupTypeConfigClass()   { return 'type-card' + (this.selectedBackupType === 'config'   ? ' type-card--selected' : ''); }
    get backupTypeOrgfullClass()  { return 'type-card' + (this.selectedBackupType === 'orgfull'  ? ' type-card--selected' : ''); }
    get restoreTypeDataClass()    { return 'type-card' + (this.selectedRestoreType === 'data'     ? ' type-card--selected' : ''); }
    get restoreTypeMetadataClass(){ return 'type-card' + (this.selectedRestoreType === 'metadata' ? ' type-card--selected' : ''); }
    get restoreTypeConfigClass()  { return 'type-card' + (this.selectedRestoreType === 'config'   ? ' type-card--selected' : ''); }
    get restoreTypeOrgfullClass() { return 'type-card' + (this.selectedRestoreType === 'orgfull'  ? ' type-card--selected' : ''); }

    // Backup schedule CSS
    get scheduleDailyClass()   { return 'schedule-option' + (this.scheduleMode === 'daily'   ? ' schedule-option--selected' : ''); }
    get scheduleWeeklyClass()  { return 'schedule-option' + (this.scheduleMode === 'weekly'  ? ' schedule-option--selected' : ''); }
    get scheduleMonthlyClass() { return 'schedule-option' + (this.scheduleMode === 'monthly' ? ' schedule-option--selected' : ''); }
    get showScheduleTimeField()  { return true; }
    get showScheduleWeekday()    { return this.scheduleMode === 'weekly'; }
    get showScheduleMonthDay()   { return this.scheduleMode === 'monthly'; }

    // Restore schedule CSS
    get restoreScheduleDailyClass()   { return 'schedule-option' + (this.restoreScheduleMode === 'daily'   ? ' schedule-option--selected' : ''); }
    get restoreScheduleWeeklyClass()  { return 'schedule-option' + (this.restoreScheduleMode === 'weekly'  ? ' schedule-option--selected' : ''); }
    get restoreScheduleMonthlyClass() { return 'schedule-option' + (this.restoreScheduleMode === 'monthly' ? ' schedule-option--selected' : ''); }
    get showRestoreScheduleTimeField()  { return true; }
    get showRestoreScheduleWeekday()    { return this.restoreScheduleMode === 'weekly'; }
    get showRestoreScheduleMonthDay()   { return this.restoreScheduleMode === 'monthly'; }

    // Split-panel select-all checkbox
    get selectAllPanelCheckboxClass() {
        return 'ms-checkbox' + (this.isActivePanelAllSelected ? ' ms-checkbox--checked' : '');
    }

    // ── Backup object getters ─────────────────────────────────────────────────
    get rawObjectOptionsCount()   { return (this.rawObjectOptions || []).length; }
    get hasBackupSelectedObjects()   { return (this.backupSelectedObjects || []).length > 0; }
    get backupSelectedObjectsCount() { return (this.backupSelectedObjects || []).length; }
    get isBackupMultipleObjects()    { return (this.backupSelectedObjects || []).length > 1; }
    get isAllBackupObjectsSelected() {
        return (this.rawObjectOptions || []).length > 0 &&
               (this.backupSelectedObjects || []).length === (this.rawObjectOptions || []).length;
    }
    get isBackupObjectsIndeterminate() {
        return (this.backupSelectedObjects || []).length > 0 && !this.isAllBackupObjectsSelected;
    }
    get backupObjectTriggerClass() {
        return 'ms-trigger' + (this.isBackupObjectDropdownOpen ? ' ms-trigger--open' : '');
    }
    get backupSelectedObjectLabels() {
        return this._labels(this.rawObjectOptions || [], this.backupSelectedObjects || []);
    }
    get selectAllBackupObjectsCheckboxClass() {
        let c = 'ms-checkbox';
        if (this.isAllBackupObjectsSelected)        c += ' ms-checkbox--checked';
        else if (this.isBackupObjectsIndeterminate) c += ' ms-checkbox--checked ms-checkbox--indeterminate';
        return c;
    }
    get filteredBackupObjects() {
        return this._buildMsList(this.rawObjectOptions || [], this.backupSelectedObjects || [], this.backupObjectSearchTerm || '');
    }
    get hasFilteredBackupObjects() { return this.filteredBackupObjects.length > 0; }

    // ── Backup record getters ─────────────────────────────────────────────────
    get hasBackupSelectedRecords()   { return (this.backupSelectedRecords || []).length > 0; }
    get backupSelectedRecordsCount() { return (this.backupSelectedRecords || []).length; }
    get backupSelectedRecordLabels() {
        return this._labels(this.backupRawRecordOptions || [], this.backupSelectedRecords || []);
    }
    get isAllBackupRecordsSelected() {
        return (this.backupRawRecordOptions || []).length > 0 &&
               (this.backupSelectedRecords || []).length === (this.backupRawRecordOptions || []).length;
    }
    get isBackupRecordsIndeterminate() {
        return (this.backupSelectedRecords || []).length > 0 && !this.isAllBackupRecordsSelected;
    }
    get selectAllBackupRecordsCheckboxClass() {
        let c = 'ms-checkbox';
        if (this.isAllBackupRecordsSelected)        c += ' ms-checkbox--checked';
        else if (this.isBackupRecordsIndeterminate) c += ' ms-checkbox--checked ms-checkbox--indeterminate';
        return c;
    }
    get filteredBackupRecords() {
        return this._buildMsList(this.backupRawRecordOptions || [], this.backupSelectedRecords || [], this.backupRecordSearchTerm || '');
    }
    get hasFilteredBackupRecords() { return this.filteredBackupRecords.length > 0; }
    get backupRecordTriggerClass() {
        let c = 'ms-trigger';
        if (this.isBackupRecordDropdownOpen) c += ' ms-trigger--open';
        if (this.isBackupMultipleObjects || this.isLoadingBackupRecords || !this.hasBackupSelectedObjects) c += ' ms-trigger--disabled';
        return c;
    }
    get computedBackupRecordClass() {
        return this.backupRecordTriggerClass + (this.noDataRecordsAvailable ? ' disabled-field' : '');
    }

    // ── Restore object getters ────────────────────────────────────────────────
    get hasRestoreDataSelectedObjects()   { return (this.restoreDataSelectedObjects || []).length > 0; }
    get restoreDataSelectedObjectsCount() { return (this.restoreDataSelectedObjects || []).length; }
    get restoreDataSelectedObjectLabels() {
        return this._labels(this.rawObjectOptions || [], this.restoreDataSelectedObjects || []);
    }
    get isAllRestoreDataObjectsSelected() {
        return (this.rawObjectOptions || []).length > 0 &&
               (this.restoreDataSelectedObjects || []).length === (this.rawObjectOptions || []).length;
    }
    get selectAllRestoreDataObjectsCheckboxClass() {
        return 'ms-checkbox' + (this.isAllRestoreDataObjectsSelected ? ' ms-checkbox--checked' : '');
    }
    get restoreDataObjectTriggerClass() {
        return 'ms-trigger' + (this.isRestoreDataObjectDropdownOpen ? ' ms-trigger--open' : '');
    }
    get filteredRestoreDataObjects() {
        return this._buildMsList(this.rawObjectOptions || [], this.restoreDataSelectedObjects || [], this.restoreDataObjectSearchTerm || '');
    }
    get hasFilteredRestoreDataObjects() { return this.filteredRestoreDataObjects.length > 0; }
    get isRestoreDataMultipleObjects()  { return (this.restoreDataSelectedObjects || []).length > 1; }

    // ── Restore record getters ────────────────────────────────────────────────
    get hasRestoreDataSelectedRecords()   { return (this.restoreDataSelectedRecords || []).length > 0; }
    get restoreDataSelectedRecordsCount() { return (this.restoreDataSelectedRecords || []).length; }
    get restoreDataSelectedRecordLabels() {
        return this._labels(this.restoreDataRawRecordOptions || [], this.restoreDataSelectedRecords || []);
    }
    get isAllRestoreDataRecordsSelected() {
        return (this.restoreDataRawRecordOptions || []).length > 0 &&
               (this.restoreDataSelectedRecords || []).length === (this.restoreDataRawRecordOptions || []).length;
    }
    get selectAllRestoreDataRecordsCheckboxClass() {
        return 'ms-checkbox' + (this.isAllRestoreDataRecordsSelected ? ' ms-checkbox--checked' : '');
    }
    get filteredRestoreDataRecords() {
        return this._buildMsList(this.restoreDataRawRecordOptions || [], this.restoreDataSelectedRecords || [], this.restoreDataRecordSearchTerm || '');
    }
    get hasFilteredRestoreDataRecords()    { return this.filteredRestoreDataRecords.length > 0; }
    get restoreDataRawRecordOptionsCount() { return (this.restoreDataRawRecordOptions || []).length; }
    get restoreDataRecordTriggerClass() {
        let c = 'ms-trigger';
        if (this.isRestoreDataRecordDropdownOpen) c += ' ms-trigger--open';
        if (this.isRestoreDataMultipleObjects || this.isLoadingRestoreDataRecords || !this.hasRestoreDataSelectedObjects) c += ' ms-trigger--disabled';
        return c;
    }
    get computedRestoreRecordClass() {
        return this.restoreDataRecordTriggerClass + (this.noRestoreDataRecordsAvailable ? ' disabled-field' : '');
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Event firers
    // ═════════════════════════════════════════════════════════════════════════

    _fire(name, detail = {}) {
        this.dispatchEvent(new CustomEvent(name, { detail, bubbles: false }));
    }

    stopProp(event) { event.stopPropagation(); }

    // ── Navigation ────────────────────────────────────────────────────────────
    handleSelection(event)        { this._fire('selection',              { value: event.target.value }); }
    handleBackupModeChange(event) { this._fire('backupmodeselectchange', { value: event.target.value }); }
    handleRestoreModeChange(event){ this._fire('restoremodeselectchange',{ value: event.target.value }); }
    handleBackupTypeSelect(event) { this._fire('backuptypeselect',       { type: event.currentTarget.dataset.type }); }
    handleRestoreTypeSelect(event){ this._fire('restoretypeselect',      { type: event.currentTarget.dataset.type }); }

    handleNext()            { this._fire('next'); }
    handleBackupModeBack()  { this._fire('backupmodeback'); }
    handleBackupModeNext()  { this._fire('backupmodenext'); }
    handleRestoreModeBack() { this._fire('restoremodeback'); }
    handleRestoreModeNext() { this._fire('restoremodenext'); }
    handleBackupTypeBack()  { this._fire('backuptypeback'); }
    handleBackupTypeNext()  { this._fire('backuptypenext'); }
    handleDataBack()        { this._fire('databack'); }
    handleMetadataBack()    { this._fire('metadataback'); }
    handleConfigBack()      { this._fire('configback'); }
    handleOrgFullBack()     { this._fire('orgfullback'); }
    handleRestoreTypeBack() { this._fire('restoretypeback'); }
    handleRestoreTypeNext() { this._fire('restoretypenext'); }
    handleRestoreBack()     { this._fire('restoreback'); }

    // ── Start backup / restore ────────────────────────────────────────────────
    fireStartDataBackup()    { this._fire('startdatabackup'); }
    fireStartMetadataBackup(){ this._fire('startmetadatabackup'); }
    fireStartConfigBackup()  { this._fire('startconfigbackup'); }
    fireStartOrgFullBackup() { this._fire('startorgfullbackup'); }
    fireStartRestore()       { this._fire('startrestore'); }

    // ── Backup object dropdown ────────────────────────────────────────────────
    fireToggleBackupObjectDropdown(event) { event.stopPropagation(); this._fire('togglebackupobjectdropdown'); }
    fireBackupObjectSearch(event)         { this._fire('backupobjectsearch',  { value: event.target.value }); }
    fireBackupObjectToggle(event)         { event.stopPropagation(); this._fire('backupobjecttoggle', { value: event.currentTarget.dataset.value }); }
    fireSelectAllBackupObjects(event)     { event.stopPropagation(); this._fire('selectallbackupobjects'); }
    fireClearBackupObjects(event)         { event.stopPropagation(); this._fire('clearbackupobjects'); }

    // ── Backup record dropdown ────────────────────────────────────────────────
    fireBackupRecordClick()           { this._fire('backuprecordclick'); }
    fireBackupRecordSearch(event)     { this._fire('backuprecordsearch',  { value: event.target.value }); }
    fireBackupRecordToggle(event)     { event.stopPropagation(); this._fire('backuprecordtoggle', { value: event.currentTarget.dataset.value }); }
    fireSelectAllBackupRecords(event) { event.stopPropagation(); this._fire('selectallbackuprecords'); }
    fireClearBackupRecords(event)     { event.stopPropagation(); this._fire('clearbackuprecords'); }

    // ── Restore object dropdown ───────────────────────────────────────────────
    fireToggleRestoreDataObjectDropdown(event) { event.stopPropagation(); this._fire('togglerestoredataobjectdropdown'); }
    fireRestoreDataObjectSearch(event)         { this._fire('restoredataobjectsearch',  { value: event.target.value }); }
    fireRestoreDataObjectToggle(event)         { event.stopPropagation(); this._fire('restoredataobjecttoggle', { value: event.currentTarget.dataset.value }); }
    fireSelectAllRestoreDataObjects(event)     { event.stopPropagation(); this._fire('selectallrestoredataobjects'); }
    fireClearRestoreDataObjects(event)         { event.stopPropagation(); this._fire('clearrestoredataobjects'); }

    // ── Restore record dropdown ───────────────────────────────────────────────
    fireRestoreRecordClick()               { this._fire('restorerecordclick'); }
    fireRestoreDataRecordSearch(event)     { this._fire('restoredatarecordsearch',  { value: event.target.value }); }
    fireRestoreDataRecordToggle(event)     { event.stopPropagation(); this._fire('restoredatarecordtoggle', { value: event.currentTarget.dataset.value }); }
    fireSelectAllRestoreDataRecords(event) { event.stopPropagation(); this._fire('selectallrestoredatarecords'); }
    fireClearRestoreDataRecords(event)     { event.stopPropagation(); this._fire('clearrestoredatarecords'); }

    // ── Inlined split-panel nav clicks ────────────────────────────────────────
    handleMetadataNavClick(event) {
        event.stopPropagation();
        this._fire('metadatasubitemclick', { key: event.currentTarget.dataset.key });
    }
    handleConfigNavClick(event) {
        event.stopPropagation();
        this._fire('configsubitemclick', { key: event.currentTarget.dataset.key });
    }
    handleOrgFullNavClick(event) {
        event.stopPropagation();
        this._fire('orgfullsubitemclick', { key: event.currentTarget.dataset.key });
    }
    handleRestoreNavClick(event) {
        event.stopPropagation();
        this._fire('restoresubitemclick', { key: event.currentTarget.dataset.key });
    }

    // ── Inlined split-panel group checkboxes ──────────────────────────────────
    fireMetadataGroupCheckbox(event) { event.stopPropagation(); this._fire('metadatagroupcheckbox', { key: event.currentTarget.dataset.key }); }
    fireConfigGroupCheckbox(event)   { event.stopPropagation(); this._fire('configgroupcheckbox',   { key: event.currentTarget.dataset.key }); }
    fireOrgFullGroupCheckbox(event)  { event.stopPropagation(); this._fire('orgfullgroupcheckbox',  { key: event.currentTarget.dataset.key }); }
    fireRestoreGroupCheckbox(event)  { event.stopPropagation(); this._fire('restoregroupcheckbox',  { key: event.currentTarget.dataset.key }); }

    // ── Inlined split-panel toggle-all ────────────────────────────────────────
    fireToglleAllMetadataPanel() { this._fire('toggleallmetadatapanel'); }
    fireToggleAllConfigPanel()   { this._fire('toggleallconfigpanel'); }
    fireToggleAllOrgFullPanel()  { this._fire('toggleallorgfullpanel'); }
    fireToggleAllRestorePanel()  { this._fire('toggleallrestorepanel'); }

    // ── Inlined split-panel item toggle & search ──────────────────────────────
    firePanelItemToggle(event) { this._fire('panelitemtoggle', { value: event.currentTarget.dataset.value }); }
    firePanelSearch(event)     { this._fire('panelsearch',     { value: event.target.value }); }

    // ── Schedule ──────────────────────────────────────────────────────────────
    fireScheduleSelect(event)     { this._fire('scheduleselect',     { freq: event.currentTarget.dataset.freq }); }
    fireScheduleTimeChange(event) { this._fire('scheduletimechange', { value: event.target.value }); }
    fireWeekdayChange(event)      { this._fire('weekdaychange',      { value: event.target.value }); }
    fireMonthDayChange(event)     { this._fire('monthdaychange',     { value: event.target.value }); }

    fireRestoreScheduleSelect(event)     { this._fire('restorescheduleselect',     { freq: event.currentTarget.dataset.freq }); }
    fireRestoreScheduleTimeChange(event) { this._fire('restorescheduletimechange', { value: event.target.value }); }
    fireRestoreWeekdayChange(event)      { this._fire('restoreweekdaychange',      { value: event.target.value }); }
    fireRestoreMonthDayChange(event)     { this._fire('restoremonthdaychange',     { value: event.target.value }); }

    // ═════════════════════════════════════════════════════════════════════════
    // Local utilities
    // ═════════════════════════════════════════════════════════════════════════

    _labels(pool, selected) {
        const labels = pool.filter(o => selected.includes(o.value)).map(o => o.label);
        if (!labels.length) return '';
        if (labels.length === 1) return labels[0];
        return `${labels[0]} +${labels.length - 1} more`;
    }

    _buildMsList(rawPool, selectedArr, searchTerm) {
        const term = (searchTerm || '').toLowerCase();
        return rawPool
            .filter(o => !term || o.label.toLowerCase().includes(term))
            .map(o => {
                const checked = selectedArr.includes(o.value);
                return {
                    ...o, checked,
                    itemClass:     'ms-item'     + (checked ? ' ms-item--selected'    : ''),
                    checkboxClass: 'ms-checkbox' + (checked ? ' ms-checkbox--checked' : '')
                };
            });
    }
}