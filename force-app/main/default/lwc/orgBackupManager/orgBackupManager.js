import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getAllObjects from '@salesforce/apex/OrgBackupManagerController.getAllObjects';
import getRecords from '@salesforce/apex/OrgBackupManagerController.getRecords';
import getApexClasses from '@salesforce/apex/OrgBackupManagerController.getApexClasses';
import getLightningComponents from '@salesforce/apex/OrgBackupManagerController.getLightningComponents';
import getEmailTemplates from '@salesforce/apex/OrgBackupManagerController.getEmailTemplates';
import getFlows from '@salesforce/apex/OrgBackupManagerController.getFlows';
import getCustomMetadata from '@salesforce/apex/OrgBackupManagerController.getCustomMetadata';
import getCustomSettings from '@salesforce/apex/OrgBackupManagerController.getCustomSettings';
import getNamedCredentials from '@salesforce/apex/OrgBackupManagerController.getNamedCredentials';
import getRemoteSiteSettings from '@salesforce/apex/OrgBackupManagerController.getRemoteSiteSettings';
import getOrgWideEmailAddresses from '@salesforce/apex/OrgBackupManagerController.getOrgWideEmailAddresses';
import getProfiles from '@salesforce/apex/OrgBackupManagerController.getProfiles';
import getPermissionSets from '@salesforce/apex/OrgBackupManagerController.getPermissionSets';
import getUsers from '@salesforce/apex/OrgBackupManagerController.getUsers';
import getReports from '@salesforce/apex/OrgBackupManagerController.getReports';
import getDashboards from '@salesforce/apex/OrgBackupManagerController.getDashboards';
import getAllRecordTypes from '@salesforce/apex/OrgBackupManagerController.getAllRecordTypes';
import fetchAllMetadata from '@salesforce/apex/OrgBackupManagerController.fetchAllMetadata';
import getAllTriggers from '@salesforce/apex/OrgBackupManagerController.getAllTriggers';
import getBackupJobStatus from '@salesforce/apex/OrgBackupManagerController.getBackupJobStatus';
import areAllJobsDone from '@salesforce/apex/OrgBackupManagerController.areAllJobsDone';
import abortJob from '@salesforce/apex/OrgBackupManagerController.abortJob';
import startDataBackupApex from '@salesforce/apex/OrgBackupManagerController.startDataBackup';
import startMetadataBackupApex from '@salesforce/apex/OrgBackupManagerController.startMetadataBackup';
import startConfigBackupApex from '@salesforce/apex/OrgBackupManagerController.startConfigBackup';
import startOrgFullBackupApex from '@salesforce/apex/OrgBackupManagerController.startOrgFullBackup';
import startGroupRestoreApex from '@salesforce/apex/DataRestoreController.startGroupRestore';

// ─── Static definitions ───────────────────────────────────────────────────────

const METADATA_DEF = [
    {
        key: 'objectStructure', label: 'Object Structure', icon: 'standard:record',
        subs: [
            {
                key: 'objects', label: 'Objects', loaderKey: null,
                staticItems: ['Standard Objects', 'Custom Objects'],
                childSubs: [
                    { key: 'fields', label: 'Fields', loaderKey: 'fields', staticItems: ['Standard Fields', 'Custom Fields'] },
                    { key: 'formulaFields', label: 'Formula Fields', loaderKey: 'formulaFields', staticItems: [] },
                    { key: 'validationRules', label: 'Validation Rules', loaderKey: 'validationRules', staticItems: [] },
                    { key: 'recordTypes', label: 'Record Types', loaderKey: 'recordTypes', staticItems: [] },
                    { key: 'pageLayouts', label: 'Page Layouts', loaderKey: 'pageLayouts', staticItems: [] }
                ]
            }
        ]
    },
    {
        key: 'automation', label: 'Automation', icon: 'standard:flow',
        subs: [
            { key: 'flows', label: 'Flows', loaderKey: 'flows', staticItems: [] },
            { key: 'workflowRules', label: 'Workflow Rules', loaderKey: 'workflowRules', staticItems: [] }
        ]
    },
    {
        key: 'security', label: 'Security', icon: 'standard:groups',
        subs: [
            { key: 'profiles', label: 'Profiles', loaderKey: 'profiles', staticItems: [] },
            { key: 'permissionSets', label: 'Permission Sets', loaderKey: 'permissionSets', staticItems: [] },
            { key: 'users', label: 'Users', loaderKey: 'users', staticItems: [] }
        ]
    },
    {
        key: 'analytics', label: 'Analytics', icon: 'standard:report',
        subs: [
            { key: 'reports', label: 'Reports', loaderKey: 'reports', staticItems: [] },
            { key: 'dashboards', label: 'Dashboards', loaderKey: 'dashboards', staticItems: [] }
        ]
    },
    {
        key: 'code', label: 'Code (Advanced)', icon: 'standard:apex',
        subs: [
            { key: 'apexClasses', label: 'Apex Classes', loaderKey: 'apex', staticItems: [] },
            { key: 'triggers', label: 'Triggers', loaderKey: 'triggers', staticItems: [] },
            { key: 'lwc', label: 'Lightning Components', loaderKey: 'lwc', staticItems: [] },
            { key: 'lightningPages', label: 'Lightning Pages', loaderKey: 'lightningPages', staticItems: [] }
        ]
    }
];

const CONFIG_DEF = [
    {
        key: 'customMetadata', label: 'Custom Metadata', icon: 'standard:custom_notification',
        subs: [{ key: 'cmdt', label: 'Custom Metadata Types', loaderKey: 'customMetadata', staticItems: [] }]
    },
    {
        key: 'customSettings', label: 'Custom Settings', icon: 'standard:settings',
        subs: [{ key: 'cset', label: 'Custom Settings', loaderKey: 'customSettings', staticItems: [] }]
    },
    {
        key: 'integrationSettings', label: 'Integration Settings', icon: 'standard:connected_apps',
        subs: [
            { key: 'namedCredentials', label: 'Named Credentials', loaderKey: 'namedCredentials', staticItems: [] },
            { key: 'remoteSites', label: 'Remote Sites', loaderKey: 'remoteSites', staticItems: [] }
        ]
    },
    {
        key: 'businessConfigData', label: 'Business Config Data', icon: 'standard:picklist_type',
        subs: [
            { key: 'emailTemplates', label: 'Email Templates', loaderKey: 'emailTemplates', staticItems: [] },
            { key: 'orgWideEmail', label: 'Org Wide Email', loaderKey: 'orgWideEmail', staticItems: [] }
        ]
    }
];

const DATA_GROUP_DEF = {
    key: 'data', label: 'Data (Objects & Records)', icon: 'standard:record',
    subs: [{ key: 'dataObjects', label: 'Objects & Records', loaderKey: 'objects', staticItems: [] }]
};

const ORGFULL_DEF = [DATA_GROUP_DEF, ...METADATA_DEF, ...CONFIG_DEF];

const ACTIVE_JOB_STATUSES = new Set(['Queued', 'On Holding', 'Preparing', 'Processing']);

// ─── State factory ────────────────────────────────────────────────────────────

function buildState(def) {
    return def.map(g => ({
        ...g,
        subs: g.subs.map(s => ({
            ...s,
            expanded: false,
            pool: s.staticItems.map(i => ({ label: i, value: i })),
            selected: [],
            loaded: s.staticItems.length > 0,
            loading: false,
            checkboxClicked: false,
            pendingSelect: false,
            childSubs: (s.childSubs || []).map(cs => ({
                ...cs,
                pool: cs.staticItems.map(i => ({ label: i, value: i })),
                selected: [],
                loaded: cs.staticItems.length > 0,
                loading: false,
                checkboxClicked: false,
                pendingSelect: false,
                visible: false
            }))
        }))
    }));
}

export default class OrgBackupManager extends LightningElement {

    @track isBackupInProgress = false;
    @track isRestoreInProgress = false;
    @track jobRows = [];
    @track isJobLoading = false;

    _pollingInterval = null;
    _activeJobIds = [];

    get hasJobRows() { return this.jobRows && this.jobRows.length > 0; }
    @track showOptionSelection = true;
    @track showBackupModeSelection = false;
    @track showRestoreModeSelection = false;
    @track showBackupTypeSelection = false;
    @track showRestoreTypeSelection = false;
    @track showDataBackup = false;
    @track showMetadataBackup = false;
    @track showConfigBackup = false;
    @track showOrgFullBackup = false;
    @track showRestoreData = false;
    @track showRestorePanel = false;

    @track scheduleMonthDayError = false;
    @track restoreScheduleMonthDayError = false;

    @track selectedAction = '';
    @track selectedBackupMode = '';
    @track selectedRestoreMode = '';
    @track selectedBackupType = '';
    @track selectedRestoreType = '';
    @track rawObjectOptions = [];

    // ── Data backup state ─────────────────────────────────────────────────────
    @track dataSelectedObjects = [];
    @track dataObjectSearchTerm = '';
    @track isDataObjectDropdownOpen = false;
    @track isSelectAllDataObjectsLoading = false;
    @track dataRawRecordOptions = [];
    @track dataSelectedRecords = [];
    @track dataRecordSearchTerm = '';
    @track isDataRecordDropdownOpen = false;
    @track isSelectAllDataRecordsLoading = false;
    @track isLoadingDataRecords = false;
    @track dataRecordsFetched = false;
    @track restoreDataRecordsFetched = false;
    @track isRestoreSubmitting = false;

    // ── Backup schedule state ─────────────────────────────────────────────────
    @track scheduleMode = 'daily';
    @track scheduleTime = '00:00';
    @track scheduleWeekday = 'MON';
    @track scheduleMonthDay = 1;

    // ── Restore schedule state ────────────────────────────────────────────────
    @track restoreScheduleMode = 'daily';
    @track restoreScheduleTime = '00:00';
    @track restoreScheduleWeekday = 'MON';
    @track restoreScheduleMonthDay = 1;

    // ── Split-panel state ─────────────────────────────────────────────────────
    @track metadataState = buildState(METADATA_DEF);
    @track activeMetadataGKey = '';
    @track activeMetadataSKey = '';
    @track activeMetadataCSKey = '';

    @track configState = buildState(CONFIG_DEF);
    @track activeConfigGKey = '';
    @track activeConfigSKey = '';

    @track orgFullState = buildState(ORGFULL_DEF);
    @track activeOrgFullGKey = '';
    @track activeOrgFullSKey = '';
    @track activeOrgFullCSKey = '';

    @track restoreState = [];
    @track activeRestoreGKey = '';
    @track activeRestoreSKey = '';
    @track activeRestoreCSKey = '';

    // ── Restore data state ────────────────────────────────────────────────────
    @track restoreDataSelectedObjects = [];
    @track restoreDataObjectSearchTerm = '';
    @track isRestoreDataObjectDropdownOpen = false;
    @track restoreDataRawRecordOptions = [];
    @track restoreDataSelectedRecords = [];
    @track restoreDataRecordSearchTerm = '';
    @track isRestoreDataRecordDropdownOpen = false;
    @track isSelectAllRestoreDataRecordsLoading = false;
    @track restoreFileList = [];
    @track restoreSelectedFileIds = [];
    @track isLoadingRestoreDataRecords = false;

    @track panelSearchTerm = '';

    @track metadataPanelEnabled = false;
    @track configPanelEnabled = false;
    @track orgFullPanelEnabled = false;
    @track restorePanelEnabled = false;

    _allMetadataCache = null;
    _loaderCache = {};

    // ── OrgFull panel data state ──────────────────────────────────────────────────
    @track orgFullPanelSelectedObjects = [];
    @track orgFullPanelObjectSearchTerm = '';
    @track isOrgFullPanelObjectDropdownOpen = false;
    @track orgFullPanelRawRecordOptions = [];
    @track orgFullPanelSelectedRecords = [];
    @track orgFullPanelRecordSearchTerm = '';
    @track isOrgFullPanelRecordDropdownOpen = false;
    @track isLoadingOrgFullPanelRecords = false;
    @track orgFullPanelRecordsFetched = false;

    // ── Restore panel data state ──────────────────────────────────────────────────
    @track restorePanelSelectedObjects = [];
    @track restorePanelObjectSearchTerm = '';
    @track isRestorePanelObjectDropdownOpen = false;
    @track restorePanelRawRecordOptions = [];
    @track restorePanelSelectedRecords = [];
    @track restorePanelRecordSearchTerm = '';
    @track isRestorePanelRecordDropdownOpen = false;
    @track isLoadingRestorePanelRecords = false;
    @track restorePanelRecordsFetched = false;
    @track isSelectAllOrgFullPanelObjectsLoading = false;
    @track isSelectAllRestorePanelObjectsLoading = false;

    // ── Column definitions ────────────────────────────────────────────────────

    jobColumns = [
        { label: 'Job ID', fieldName: 'jobId', type: 'text' },
        { label: 'Class', fieldName: 'className', type: 'text' },
        { label: 'Status', fieldName: 'status', type: 'text' },
        { label: 'User', fieldName: 'userName', type: 'text' },
        { label: 'Start Time', fieldName: 'startTime', type: 'text' },
        {
            label: 'Action',
            type: 'button',
            typeAttributes: {
                label: 'Cancel',
                name: 'cancel',
                variant: 'destructive',
                disabled: { fieldName: 'disableCancel' }
            }
        }
    ];

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    connectedCallback() {
        this._handleOutsideClick = this.handleOutsideClick.bind(this);
        document.addEventListener('click', this._handleOutsideClick);

        getAllObjects()
            .then(r => {
                this.rawObjectOptions = r.map(o => ({ label: o, value: o }));
            })
    }

    disconnectedCallback() {
        document.removeEventListener('click', this._handleOutsideClick);
        this._stopPolling();
    }

    _loadAllStateUpfront() {
        const loaderKeys = [
            'apex', 'lwc', 'customMetadata', 'customSettings',
            'namedCredentials', 'flows', 'recordTypes', 'reports',
            'dashboards', 'emailTemplates', 'orgWideEmail', 'profiles',
            'permissionSets', 'users', 'remoteSites', 'triggers',
            'workflowRules', 'validationRules', 'pageLayouts',
            'lightningPages', 'fields', 'formulaFields'
        ];

        Promise.all(
            loaderKeys.map(key =>
                this._loaderFor(key)
                    .then(result => ({ key, result }))
                    .catch(() => ({ key, result: [] }))
            )
        ).then(results => {
            const poolMap = {};
            results.forEach(({ key, result }) => {
                poolMap[key] = (result || []).map(r =>
                    typeof r === 'string' ? { label: r, value: r } : r
                );
            });

            const applyPools = (stateArr) => stateArr.map(g => ({
                ...g,
                subs: g.subs.map(s => ({
                    ...s,
                    pool: s.loaderKey && poolMap[s.loaderKey] ? poolMap[s.loaderKey] : s.pool,
                    loaded: s.loaderKey ? true : s.loaded,
                    loading: false,
                    childSubs: s.childSubs ? s.childSubs.map(cs => ({
                        ...cs,
                        pool: cs.loaderKey && poolMap[cs.loaderKey] ? poolMap[cs.loaderKey] : cs.pool,
                        loaded: cs.loaderKey && poolMap[cs.loaderKey] ? true : cs.loaded,
                        loading: false
                    })) : s.childSubs
                }))
            }));

            this.metadataState = applyPools(buildState(METADATA_DEF));
            this.configState = applyPools(buildState(CONFIG_DEF));
            this.orgFullState = applyPools(buildState(ORGFULL_DEF));
        });
    }

    handleOutsideClick(event) {
        const wrappers = this.template.querySelectorAll('.multiselect-wrapper');
        let inside = false;
        wrappers.forEach(w => { if (w.contains(event.target)) inside = true; });
        if (!inside) this._closeAllDropdowns();
    }

    // ── Data loading ──────────────────────────────────────────────────────────

    connectedCallback() {
        this._handleOutsideClick = this.handleOutsideClick.bind(this);
        document.addEventListener('click', this._handleOutsideClick);

        getAllObjects()
            .then(r => {
                this.rawObjectOptions = r
                    .map(apiName => ({
                        value: apiName,
                        label: apiName
                            .replace(/__c$/i, '')
                            .replace(/__/g, ' ')
                            .replace(/_/g, ' ')
                            .replace(/\b\w/g, c => c.toUpperCase())
                    }))
                    .sort((a, b) => a.label.localeCompare(b.label));
            })
    }

    loadDataRecords(objectName) {
        this.isLoadingDataRecords = true;
        this.dataRawRecordOptions = [];
        this.dataSelectedRecords = [];
        this.dataRecordsFetched = false;

        const cacheKey = `records_${objectName}`;
        const cached = this._loaderCache[cacheKey];
        const promise = cached instanceof Array
            ? Promise.resolve(cached)
            : getRecords({ objectName }).then(r => {
                const mapped = r.map(rec => ({ label: rec.Name, value: rec.Id }));
                this._loaderCache[cacheKey] = mapped;
                return mapped;
            });

        promise
            .then(mapped => { this.dataRawRecordOptions = mapped; })
            .catch()
            .finally(() => { this.isLoadingDataRecords = false; this.dataRecordsFetched = true; });
    }

    loadRestoreDataRecords(objectName) {
        this.isLoadingRestoreDataRecords = true;
        this.restoreDataRawRecordOptions = [];
        this.restoreDataSelectedRecords = [];
        this.restoreDataRecordsFetched = false;

        const cacheKey = `records_${objectName}`;
        const cached = this._loaderCache[cacheKey];
        const promise = cached instanceof Array
            ? Promise.resolve(cached)
            : getRecords({ objectName }).then(r => {
                const mapped = r.map(rec => ({ label: rec.Name, value: rec.Id }));
                this._loaderCache[cacheKey] = mapped;
                return mapped;
            });

        promise
            .then(mapped => { this.restoreDataRawRecordOptions = mapped; })
            .catch()
            .finally(() => { this.isLoadingRestoreDataRecords = false; this.restoreDataRecordsFetched = true; });
    }

    // ── Loader map ────────────────────────────────────────────────────────────

    _loaderFor(loaderKey) {
        const cacheKey = `loader_${loaderKey}`;
        if (this._loaderCache[cacheKey] instanceof Array) {
            return Promise.resolve(this._loaderCache[cacheKey]);
        }

        const fromStringList = apexFn =>
            apexFn().then(r => (r || []).map(s => ({ label: s, value: s })));

        const fromPairs = (apexFn, labelFn) =>
            apexFn().then(r => (r || []).map(i => ({
                label: labelFn ? labelFn(i) : i.name,
                value: i.id
            })));

        const map = {
            apex: () => fromStringList(getApexClasses),
            lwc: () => fromStringList(getLightningComponents),
            customMetadata: () => fromStringList(getCustomMetadata),
            customSettings: () => fromStringList(getCustomSettings),
            namedCredentials: () => fromStringList(getNamedCredentials),
            flows: () => fromPairs(getFlows),
            recordTypes: () => fromPairs(getAllRecordTypes),
            reports: () => fromPairs(getReports),
            dashboards: () => fromPairs(getDashboards),
            emailTemplates: () => fromPairs(getEmailTemplates),
            orgWideEmail: () => fromPairs(getOrgWideEmailAddresses),
            profiles: () => fromPairs(getProfiles),
            permissionSets: () => fromPairs(getPermissionSets),
            users: () => fromPairs(getUsers),
            remoteSites: () => fromPairs(getRemoteSiteSettings, i => i.name + (i.url ? ` (${i.url})` : '')),
            triggers: () => getAllTriggers().then(r => (r || []).map(i => ({
                label: i.name + (i.tableName ? ` (${i.tableName})` : ''),
                value: i.id,
                active: i.isActive
            }))),
            workflowRules: () => this._fetchMetadataByType('WorkflowRule'),
            validationRules: () => this._fetchMetadataByType('ValidationRule'),
            pageLayouts: () => this._fetchMetadataByType('PageLayout'),
            lightningPages: () => this._fetchMetadataByType('LightningPage'),
            fields: () => Promise.resolve([
                { label: 'Standard Fields', value: 'Standard Fields' },
                { label: 'Custom Fields', value: 'Custom Fields' }
            ]),
            formulaFields: () => this._fetchMetadataByType('FormulaField'),
            objects: () => Promise.resolve(this.rawObjectOptions || [])
        };

        if (!map[loaderKey]) {
            return Promise.resolve([]);
        }

        return map[loaderKey]().then(result => {
            this._loaderCache[cacheKey] = result;
            return result;
        });
    }

    _fetchMetadataByType(type) {
        const cacheKey = `loader_fetchAllMetadata`;

        const getOrFetch = () => {
            if (this._allMetadataCache instanceof Array) {
                return Promise.resolve(this._allMetadataCache);
            }
            if (this._loaderCache[cacheKey] instanceof Array) {
                this._allMetadataCache = this._loaderCache[cacheKey];
                return Promise.resolve(this._allMetadataCache);
            }
            return fetchAllMetadata()
                .then(items => {
                    this._allMetadataCache = items || [];
                    this._loaderCache[cacheKey] = this._allMetadataCache;
                    return this._allMetadataCache;
                });
        };

        return getOrFetch().then(allItems => {
            return allItems
                .filter(i => i.type === type)
                .map(i => ({ label: i.name, value: i.id || i.name }));
        });
    }

    _latestStateFor(page, fallback) {
        if (page === 'metadata') return this.metadataState;
        if (page === 'config') return this.configState;
        if (page === 'orgfull') return this.orgFullState;
        if (page === 'restore') return this.restoreState;
        return fallback;
    }

    _loadSubItem(stateArr, gKey, sKey, setFn, page) {
        const resolvedPage = page || this._activePage;
        const latest = this._latestStateFor(resolvedPage, stateArr);
        const gIdx = latest.findIndex(g => g.key === gKey);
        if (gIdx === -1) return;
        const sIdx = latest[gIdx].subs.findIndex(s => s.key === sKey);
        if (sIdx === -1) return;
        const sub = latest[gIdx].subs[sIdx];
        if (sub.loading) return;
        if (sub.loaderKey !== 'objects' && sub.loaded && sub.pool.length <= 400) return;
        if (sub.loaderKey !== 'objects' && sub.loaded && sub.pool.length > 400) {
            setFn(latest.map((g, gi) => gi !== gIdx ? g : {
                ...g,
                subs: g.subs.map((s, si) => si !== sIdx ? s : { ...s, loading: true })
            }));
            setTimeout(() => {
                const afterLoad = this._latestStateFor(resolvedPage, stateArr);
                setFn(afterLoad.map(g => g.key !== gKey ? g : {
                    ...g,
                    subs: g.subs.map(s => s.key !== sKey ? s : {
                        ...s,
                        loading: false,
                        loaded: true
                    })
                }));
            }, 50);
            return;
        }
        setFn(latest.map((g, gi) => gi !== gIdx ? g : {
            ...g,
            subs: g.subs.map((s, si) => si !== sIdx ? s : { ...s, loading: true })
        }));

        this._loaderFor(sub.loaderKey)
            .then(result => {
                const pool = result.map(r =>
                    typeof r === 'string' ? { label: r, value: r } : r
                );
                const afterLoad = this._latestStateFor(resolvedPage, stateArr);
                const latestSub = (afterLoad.find(g => g.key === gKey)?.subs || [])
                    .find(s => s.key === sKey);

                const shouldSelectAll = latestSub?.pendingSelect ?? false;
                const wasCheckboxClicked = latestSub?.checkboxClicked ?? false;

                setFn(afterLoad.map(g => g.key !== gKey ? g : {
                    ...g,
                    subs: g.subs.map(s => s.key !== sKey ? s : {
                        ...s,
                        pool,
                        loading: false,
                        loaded: true,
                        pendingSelect: false,
                        checkboxClicked: wasCheckboxClicked,
                        selected: shouldSelectAll
                            ? pool.map(i => i.value)
                            : s.selected
                    })
                }));
            })
            .catch(e => {
                const afterLoad = this._latestStateFor(resolvedPage, stateArr);
                const latestSub = (afterLoad.find(g => g.key === gKey)?.subs || [])
                    .find(s => s.key === sKey);
                setFn(afterLoad.map(g => g.key !== gKey ? g : {
                    ...g,
                    subs: g.subs.map(s => s.key !== sKey ? s : {
                        ...s,
                        loading: false,
                        checkboxClicked: latestSub?.checkboxClicked ?? s.checkboxClicked
                    })
                }));
            });
    }

    _loadChildSubItem(stateArr, gKey, parentSKey, csKey, setFn, page) {
        const resolvedPage = page || this._activePage;
        const latest = this._latestStateFor(resolvedPage, stateArr);

        const gIdx = latest.findIndex(g => g.key === gKey);
        if (gIdx === -1) return;
        const sIdx = latest[gIdx].subs.findIndex(s => s.key === parentSKey);
        if (sIdx === -1) return;
        const parentSub = latest[gIdx].subs[sIdx];
        if (!parentSub.childSubs) return;
        const csIdx = parentSub.childSubs.findIndex(cs => cs.key === csKey);
        if (csIdx === -1) return;
        const cs = parentSub.childSubs[csIdx];
        if ((cs.loaded && cs.pool.length > 0) || cs.loading) return;

        setFn(latest.map((g, gi) => gi !== gIdx ? g : {
            ...g,
            subs: g.subs.map((s, si) => si !== sIdx ? s : {
                ...s,
                childSubs: s.childSubs.map((c, ci) => ci !== csIdx ? c : { ...c, loading: true })
            })
        }));

        this._loaderFor(cs.loaderKey)
            .then(result => {
                const pool = result.map(r =>
                    typeof r === 'string' ? { label: r, value: r } : r
                );
                const afterLoad = this._latestStateFor(resolvedPage, stateArr);
                const latestCs = afterLoad.find(g => g.key === gKey)
                    ?.subs.find(s => s.key === parentSKey)
                    ?.childSubs?.find(c => c.key === csKey);

                const shouldSelectAll = latestCs?.pendingSelect ?? false;
                const wasCheckboxClicked = latestCs?.checkboxClicked ?? false;

                setFn(afterLoad.map(g => g.key !== gKey ? g : {
                    ...g,
                    subs: g.subs.map(s => s.key !== parentSKey || !s.childSubs ? s : {
                        ...s,
                        childSubs: s.childSubs.map(c => c.key !== csKey ? c : {
                            ...c,
                            pool,
                            loading: false,
                            loaded: true,
                            pendingSelect: false,
                            checkboxClicked: wasCheckboxClicked,
                            selected: shouldSelectAll
                                ? pool.map(i => i.value)
                                : c.selected
                        })
                    })
                }));
            })
            .catch(e => {
                const afterLoad = this._latestStateFor(resolvedPage, stateArr);
                const latestCs = afterLoad.find(g => g.key === gKey)
                    ?.subs.find(s => s.key === parentSKey)
                    ?.childSubs?.find(c => c.key === csKey);
                setFn(afterLoad.map(g => g.key !== gKey ? g : {
                    ...g,
                    subs: g.subs.map(s => s.key !== parentSKey || !s.childSubs ? s : {
                        ...s,
                        childSubs: s.childSubs.map(c => c.key !== csKey ? c : {
                            ...c,
                            loading: false,
                            checkboxClicked: latestCs?.checkboxClicked ?? c.checkboxClicked
                        })
                    })
                }));
            });
    }

   _buildNavTree(stateArr, activeGKey, activeSKey, activeCSKey) {
    if (!stateArr || !stateArr.length) return [];

    return stateArr.map(g => {
        const totalSelected = g.subs.reduce((sum, s) => {
            let t = s.selected ? s.selected.length : 0;
            if (s.childSubs) t += s.childSubs.reduce((acc, c) => acc + (c.selected ? c.selected.length : 0), 0);
            return sum + t;
        }, 0);

    
        const totalPool = g.subs.reduce((sum, s) => {
            let t = 0;
            if (s.loaded && s.pool) {
                t = s.pool.length;
            } else if (s.loaderKey) {
                t = 1; 
            }
            if (s.childSubs) {
                t += s.childSubs.reduce((acc, c) => {
                    if (c.loaded && c.pool) {
                        return acc + c.pool.length;
                    } else if (c.loaderKey) {
                        return acc + 1; 
                    }
                    return acc;
                }, 0);
            }
            return sum + t;
        }, 0);

        const allChecked = totalPool > 0 && totalSelected === totalPool;
        const someChecked = totalSelected > 0 && !allChecked;

        let groupCheckboxClass = 'group-checkbox';
        if (allChecked) groupCheckboxClass += ' group-checkbox--checked';
        else if (someChecked) groupCheckboxClass += ' group-checkbox--indeterminate';

        const subItems = [];

        g.subs.forEach(s => {
            const isActive = g.key === activeGKey && s.key === activeSKey && !activeCSKey;
            const hasChildren = !!(s.childSubs && s.childSubs.length > 0);
            const isAllSelected = s.loaded && s.pool.length > 0 && s.selected.length === s.pool.length;
            const isSomeSelected = s.selected.length > 0 && !isAllSelected;

            subItems.push({
                key: s.key,
                label: s.label,
                count: s.selected ? s.selected.length : 0,
                checked: !!(s.selected && s.selected.length > 0),
                subRowClass: 'nav-sub-row' + (isActive ? ' nav-sub-row--active' : ''),
                subCheckboxClass: 'sub-checkbox' +
                    (isAllSelected ? ' sub-checkbox--checked' : '') +
                    (isSomeSelected ? ' sub-checkbox--indeterminate' : ''),
                subBadgeClass: this._subBadgeClass(s),
                isChildSub: false,
                parentSKey: null,
                isLoading: s.loading || false,
                hasChildren,
                chevronClass: 'nav-sub-chevron' +
                    (s.expanded ? ' nav-sub-chevron--open' : '') +
                    (s.selected && s.selected.length > 0 ? ' nav-sub-chevron--enabled' : '')
            });

            if (hasChildren && s.expanded) {
                s.childSubs.forEach(cs => {
                    const csIsActive = g.key === activeGKey && cs.key === activeCSKey;
                    const csIsAll = cs.loaded && cs.pool.length > 0 && cs.selected.length === cs.pool.length;
                    const csIsSome = cs.selected.length > 0 && !csIsAll;
                    subItems.push({
                        key: cs.key,
                        label: cs.label,
                        count: cs.selected ? cs.selected.length : 0,
                        checked: !!(cs.selected && cs.selected.length > 0),
                        subRowClass: 'nav-sub-row nav-child-sub-row' + (csIsActive ? ' nav-sub-row--active' : ''),
                        subCheckboxClass: 'sub-checkbox' +
                            (csIsAll ? ' sub-checkbox--checked' : '') +
                            (csIsSome ? ' sub-checkbox--indeterminate' : ''),
                        subBadgeClass: this._subBadgeClass(cs),
                        isChildSub: true,
                        parentSKey: s.key,
                        isLoading: cs.loading || false,
                        hasChildren: false,
                        chevronClass: ''
                    });
                });
            }
        });

        return {
            key: g.key,
            label: g.label,
            icon: g.icon,
            selectedCount: totalSelected,
            allChecked,
            groupRowClass: 'nav-group-row',
            groupCheckboxClass,
            groupBadgeClass: totalSelected > 0 ? 'nav-badge' : 'nav-badge nav-badge--hidden',
            subItems
        };
    });
}

    _subBadgeClass(sub) {
        if (!sub.checkboxClicked) return 'nav-sub-badge nav-sub-badge--hidden';
        if (sub.loaded && sub.selected.length > 0) return 'nav-sub-badge';
        return 'nav-sub-badge nav-sub-badge--hidden';
    }

    get metadataNavTree() { return this._buildNavTree(this.metadataState, this.activeMetadataGKey, this.activeMetadataSKey, this.activeMetadataCSKey); }
    get configNavTree() { return this._buildNavTree(this.configState, this.activeConfigGKey, this.activeConfigSKey, ''); }
    get orgFullNavTree() { return this._buildNavTree(this.orgFullState, this.activeOrgFullGKey, this.activeOrgFullSKey, this.activeOrgFullCSKey); }
    get restoreNavTree() { return this._buildNavTree(this.restoreState, this.activeRestoreGKey, this.activeRestoreSKey, this.activeRestoreCSKey); }

    _navigateToBackupType() {
        this.showDataBackup = false;
        this.showMetadataBackup = false;
        this.showConfigBackup = false;
        this.showOrgFullBackup = false;
        this.showBackupTypeSelection = true;
        this.selectedBackupType = '';
    }

    _getActiveSub(stateArr, gKey, sKey, csKey) {
        const g = stateArr.find(gr => gr.key === gKey);
        if (!g) return null;
        if (csKey) {
            for (const s of g.subs) {
                const cs = s.childSubs?.find(c => c.key === csKey);
                if (cs) return cs;
            }
            return null;
        }
        return g.subs.find(s => s.key === sKey) || null;
    }

    get _activePage() {
        if (this.showDataBackup) return 'data';
        if (this.showMetadataBackup) return 'metadata';
        if (this.showConfigBackup) return 'config';
        if (this.showOrgFullBackup) return 'orgfull';
        if (this.showRestorePanel) return 'restore';
        if (this.showRestoreData) return 'restoreData';
        return '';
    }

    get _currentSub() {
        const p = this._activePage;
        if (p === 'metadata') return this._getActiveSub(this.metadataState, this.activeMetadataGKey, this.activeMetadataSKey, this.activeMetadataCSKey);
        if (p === 'config') return this._getActiveSub(this.configState, this.activeConfigGKey, this.activeConfigSKey, '');
        if (p === 'orgfull') return this._getActiveSub(this.orgFullState, this.activeOrgFullGKey, this.activeOrgFullSKey, this.activeOrgFullCSKey);
        if (p === 'restore') return this._getActiveSub(this.restoreState, this.activeRestoreGKey, this.activeRestoreSKey, this.activeRestoreCSKey);
        return null;
    }

    get hasActiveMetadataSubItem() { return this.metadataPanelEnabled && !!this._getActiveSub(this.metadataState, this.activeMetadataGKey, this.activeMetadataSKey, this.activeMetadataCSKey); }
    get hasActiveConfigSubItem() { return this.configPanelEnabled && !!this._getActiveSub(this.configState, this.activeConfigGKey, this.activeConfigSKey, ''); }
    get hasActiveOrgFullSubItem() { return this.orgFullPanelEnabled && !!this._getActiveSub(this.orgFullState, this.activeOrgFullGKey, this.activeOrgFullSKey, this.activeOrgFullCSKey); }
    get hasActiveRestoreSubItem() { return this.restorePanelEnabled && !!this._getActiveSub(this.restoreState, this.activeRestoreGKey, this.activeRestoreSKey, this.activeRestoreCSKey); }

    get activeMetadataSubItem() { return this._getActiveSub(this.metadataState, this.activeMetadataGKey, this.activeMetadataSKey, this.activeMetadataCSKey); }
    get activeConfigSubItem() { return this._getActiveSub(this.configState, this.activeConfigGKey, this.activeConfigSKey, ''); }
    get activeOrgFullSubItem() { return this._getActiveSub(this.orgFullState, this.activeOrgFullGKey, this.activeOrgFullSKey, this.activeOrgFullCSKey); }
    get activeRestoreSubItem() { return this._getActiveSub(this.restoreState, this.activeRestoreGKey, this.activeRestoreSKey, this.activeRestoreCSKey); }

    // ── Panel getters ─────────────────────────────────────────────────────────

    get isLoadingActivePanel() { return this._currentSub?.loading ?? false; }

    get showPanelSearchBar() {
        const p = this._activePage;
        const noSearch = (sKey, csKey) => sKey === 'objects' && !csKey;
        if (p === 'metadata') return !noSearch(this.activeMetadataSKey, this.activeMetadataCSKey) && !this.activeMetadataCSKey;
        if (p === 'orgfull') return !noSearch(this.activeOrgFullSKey, this.activeOrgFullCSKey) && !this.activeOrgFullCSKey;
        if (p === 'restore') return !noSearch(this.activeRestoreSKey, this.activeRestoreCSKey) && !this.activeRestoreCSKey;
        return true;
    }

    get activePanelItems() {
        const sub = this._currentSub;
        if (!sub) return [];
        const term = this.showPanelSearchBar ? (this.panelSearchTerm || '').toLowerCase() : '';
        return sub.pool
            .filter(i => !term || i.label.toLowerCase().includes(term))
            .map(i => {
                const checked = sub.selected.includes(i.value);
                return {
                    ...i, checked,
                    rowClass: 'panel-item' + (checked ? ' panel-item--selected' : ''),
                    checkboxClass: 'ms-checkbox' + (checked ? ' ms-checkbox--checked' : '')
                };
            });
    }

    get hasActivePanelItems() { return this.activePanelItems.length > 0; }
    get activePanelTotal() { return this._currentSub?.pool.length ?? 0; }
    get isActivePanelAllSelected() {
        const sub = this._currentSub;
        return sub && sub.pool.length > 0 && sub.selected.length === sub.pool.length;
    }

    get isMetadataBackupDisabled() {
        return !this.metadataState.some(g => g.subs.some(s =>
            s.selected.length > 0 || s.childSubs?.some(cs => cs.selected.length > 0)
        )) || this.isScheduleInvalid || this.isJobRunning;
    }
    get isConfigBackupDisabled() {
        return !this.configState.some(g => g.subs.some(s => s.selected.length > 0))
            || this.isScheduleInvalid || this.isJobRunning;
    }
    get isOrgFullBackupDisabled() {
        return !this.orgFullState.some(g => g.subs.some(s =>
            s.selected.length > 0 || s.childSubs?.some(cs => cs.selected.length > 0)
        )) || this.isScheduleInvalid || this.isJobRunning;
    }
    get isRestorePanelDisabled() {
        return !this.restoreState.some(g => g.subs.some(s =>
            s.selected.length > 0 || s.childSubs?.some(cs => cs.selected.length > 0)
        )) || this.isRestoreSubmitting || this.isRestoreScheduleInvalid || this.isJobRunning;
    }

    get noDataRecordsAvailable() {
        return this.dataSelectedObjects.length === 1
            && !this.isLoadingDataRecords
            && this.dataRecordsFetched
            && this.dataRawRecordOptions.length === 0;
    }

    get noRestoreDataRecordsAvailable() {
        return this.restoreDataSelectedObjects.length === 1
            && !this.isLoadingRestoreDataRecords
            && this.restoreDataRecordsFetched
            && this.restoreDataRawRecordOptions.length === 0;
    }

    get restorePageTitle() {
        return { metadata: 'Metadata Restore', config: 'Config Restore', orgfull: 'Org Full Restore' }[this.selectedRestoreType] || 'Restore';
    }
    get restorePageIcon() {
        return { metadata: 'standard:apex', config: 'standard:settings', orgfull: 'standard:all' }[this.selectedRestoreType] || 'standard:record';
    }

    get isScheduleMode() { return this.selectedBackupMode === 'schedule'; }
    get isRestoreScheduleMode() { return this.selectedRestoreMode === 'schedule'; }

    get scheduleDailyClass() { return this._schedClass('daily'); }
    get scheduleWeeklyClass() { return this._schedClass('weekly'); }
    get scheduleMonthlyClass() { return this._schedClass('monthly'); }

    _schedClass(mode) {
        return 'schedule-option' + (this.scheduleMode === mode ? ' schedule-option--selected' : '');
    }

    get showScheduleTimeField() { return true; }
    get showScheduleWeekday() { return this.scheduleMode === 'weekly'; }
    get showScheduleMonthDay() { return this.scheduleMode === 'monthly'; }

    get weekdayOptions() {
        return [
            { label: 'Monday', value: 'MON' },
            { label: 'Tuesday', value: 'TUE' },
            { label: 'Wednesday', value: 'WED' },
            { label: 'Thursday', value: 'THU' },
            { label: 'Friday', value: 'FRI' },
            { label: 'Saturday', value: 'SAT' },
            { label: 'Sunday', value: 'SUN' }
        ];
    }

    get restoreScheduleDailyClass() { return this._restoreSchedClass('daily'); }
    get restoreScheduleWeeklyClass() { return this._restoreSchedClass('weekly'); }
    get restoreScheduleMonthlyClass() { return this._restoreSchedClass('monthly'); }

    _restoreSchedClass(mode) {
        return 'schedule-option' + (this.restoreScheduleMode === mode ? ' schedule-option--selected' : '');
    }

    get showRestoreScheduleTimeField() { return true; }
    get showRestoreScheduleWeekday() { return this.restoreScheduleMode === 'weekly'; }
    get showRestoreScheduleMonthDay() { return this.restoreScheduleMode === 'monthly'; }

    get isOrgFullDataObjectsPanel() {
        return this.activeOrgFullSKey === 'dataObjects' && this.orgFullPanelEnabled;
    }
    get hasOrgFullPanelSelectedObjects() { return this.orgFullPanelSelectedObjects.length > 0; }
    get orgFullPanelSelectedObjectsCount() { return this.orgFullPanelSelectedObjects.length; }
    get isOrgFullPanelMultipleObjects() { return this.orgFullPanelSelectedObjects.length > 1; }
    get orgFullPanelSelectedObjectLabels() { return this._labels(this.rawObjectOptions, this.orgFullPanelSelectedObjects); }
    get isAllOrgFullPanelObjectsSelected() { return this.rawObjectOptions.length > 0 && this.orgFullPanelSelectedObjects.length === this.rawObjectOptions.length; }
    get isOrgFullPanelObjectsIndeterminate() { return this.orgFullPanelSelectedObjects.length > 0 && !this.isAllOrgFullPanelObjectsSelected; }
    get filteredOrgFullPanelObjects() { return this._buildMsList(this.rawObjectOptions, this.orgFullPanelSelectedObjects, this.orgFullPanelObjectSearchTerm); }
    get hasFilteredOrgFullPanelObjects() { return this.filteredOrgFullPanelObjects.length > 0; }
    get orgFullPanelObjectTriggerClass() { return 'ms-trigger' + (this.isOrgFullPanelObjectDropdownOpen ? ' ms-trigger--open' : ''); }
    get selectAllOrgFullPanelObjectsCheckboxClass() {
        let c = 'ms-checkbox';
        if (this.isAllOrgFullPanelObjectsSelected) c += ' ms-checkbox--checked';
        else if (this.isOrgFullPanelObjectsIndeterminate) c += ' ms-checkbox--checked ms-checkbox--indeterminate';
        return c;
    }

    get hasOrgFullPanelSelectedRecords() { return this.orgFullPanelSelectedRecords.length > 0; }
    get orgFullPanelSelectedRecordsCount() { return this.orgFullPanelSelectedRecords.length; }
    get orgFullPanelSelectedRecordLabels() { return this._labels(this.orgFullPanelRawRecordOptions, this.orgFullPanelSelectedRecords); }
    get isAllOrgFullPanelRecordsSelected() { return this.orgFullPanelRawRecordOptions.length > 0 && this.orgFullPanelSelectedRecords.length === this.orgFullPanelRawRecordOptions.length; }
    get filteredOrgFullPanelRecords() { return this._buildMsList(this.orgFullPanelRawRecordOptions, this.orgFullPanelSelectedRecords, this.orgFullPanelRecordSearchTerm); }
    get hasFilteredOrgFullPanelRecords() { return this.filteredOrgFullPanelRecords.length > 0; }
    get orgFullPanelRecordTriggerClass() {
        let c = 'ms-trigger';
        if (this.isOrgFullPanelRecordDropdownOpen) c += ' ms-trigger--open';
        if (this.isOrgFullPanelMultipleObjects || this.isLoadingOrgFullPanelRecords || !this.hasOrgFullPanelSelectedObjects) c += ' ms-trigger--disabled';
        return c;
    }
    get noOrgFullPanelRecordsAvailable() {
        return this.orgFullPanelSelectedObjects.length === 1
            && !this.isLoadingOrgFullPanelRecords
            && this.orgFullPanelRecordsFetched
            && this.orgFullPanelRawRecordOptions.length === 0;
    }
    get computedOrgFullPanelRecordClass() {
        let base = this.orgFullPanelRecordTriggerClass;
        if (this.noOrgFullPanelRecordsAvailable) base += ' disabled-field';
        return base;
    }

    get isRestoreDataObjectsPanel() {
        return this.activeRestoreSKey === 'dataObjects' && this.restorePanelEnabled;
    }
    get selectAllOrgFullPanelRecordsCheckboxClass() {
        let c = 'ms-checkbox';
        if (this.isAllOrgFullPanelRecordsSelected) c += ' ms-checkbox--checked';
        else if (this.orgFullPanelSelectedRecords.length > 0) c += ' ms-checkbox--checked ms-checkbox--indeterminate';
        return c;
    }

    get selectAllRestorePanelRecordsCheckboxClass() {
        let c = 'ms-checkbox';
        if (this.isAllRestorePanelRecordsSelected) c += ' ms-checkbox--checked';
        else if (this.restorePanelSelectedRecords.length > 0) c += ' ms-checkbox--checked ms-checkbox--indeterminate';
        return c;
    }

    get hasRestorePanelSelectedObjects() { return this.restorePanelSelectedObjects.length > 0; }
    get restorePanelSelectedObjectsCount() { return this.restorePanelSelectedObjects.length; }
    get isRestorePanelMultipleObjects() { return this.restorePanelSelectedObjects.length > 1; }
    get restorePanelSelectedObjectLabels() { return this._labels(this.rawObjectOptions, this.restorePanelSelectedObjects); }
    get isAllRestorePanelObjectsSelected() { return this.rawObjectOptions.length > 0 && this.restorePanelSelectedObjects.length === this.rawObjectOptions.length; }
    get isRestorePanelObjectsIndeterminate() { return this.restorePanelSelectedObjects.length > 0 && !this.isAllRestorePanelObjectsSelected; }
    get filteredRestorePanelObjects() { return this._buildMsList(this.rawObjectOptions, this.restorePanelSelectedObjects, this.restorePanelObjectSearchTerm); }
    get hasFilteredRestorePanelObjects() { return this.filteredRestorePanelObjects.length > 0; }
    get restorePanelObjectTriggerClass() { return 'ms-trigger' + (this.isRestorePanelObjectDropdownOpen ? ' ms-trigger--open' : ''); }
    get selectAllRestorePanelObjectsCheckboxClass() {
        let c = 'ms-checkbox';
        if (this.isAllRestorePanelObjectsSelected) c += ' ms-checkbox--checked';
        else if (this.isRestorePanelObjectsIndeterminate) c += ' ms-checkbox--checked ms-checkbox--indeterminate';
        return c;
    }

    get hasRestorePanelSelectedRecords() { return this.restorePanelSelectedRecords.length > 0; }
    get restorePanelSelectedRecordsCount() { return this.restorePanelSelectedRecords.length; }
    get restorePanelSelectedRecordLabels() { return this._labels(this.restorePanelRawRecordOptions, this.restorePanelSelectedRecords); }
    get isAllRestorePanelRecordsSelected() { return this.restorePanelRawRecordOptions.length > 0 && this.restorePanelSelectedRecords.length === this.restorePanelRawRecordOptions.length; }
    get filteredRestorePanelRecords() { return this._buildMsList(this.restorePanelRawRecordOptions, this.restorePanelSelectedRecords, this.restorePanelRecordSearchTerm); }
    get hasFilteredRestorePanelRecords() { return this.filteredRestorePanelRecords.length > 0; }
    get restorePanelRecordTriggerClass() {
        let c = 'ms-trigger';
        if (this.isRestorePanelRecordDropdownOpen) c += ' ms-trigger--open';
        if (this.isRestorePanelMultipleObjects || this.isLoadingRestorePanelRecords || !this.hasRestorePanelSelectedObjects) c += ' ms-trigger--disabled';
        return c;
    }
    get noRestorePanelRecordsAvailable() {
        return this.restorePanelSelectedObjects.length === 1
            && !this.isLoadingRestorePanelRecords
            && this.restorePanelRecordsFetched
            && this.restorePanelRawRecordOptions.length === 0;
    }
    get computedRestorePanelRecordClass() {
        let base = this.restorePanelRecordTriggerClass;
        if (this.noRestorePanelRecordsAvailable) base += ' disabled-field';
        return base;
    }

    handleScheduleSelect(event) { this.scheduleMode = event.currentTarget.dataset.freq; }
    handleScheduleTimeChange(event) {
        let fullTime = event.target.value;
        let timeParts = fullTime.split(':');
        this.scheduleTime = timeParts[0] + ':' + timeParts[1];
    }
    handleWeekdayChange(event) { this.scheduleWeekday = event.target.value; }
    handleMonthDayChange(event) {
        const raw = event.target.value;
        const val = parseInt(raw, 10);

        if (raw === '' || raw === null || raw === undefined) {
            event.target.setCustomValidity('Date of Month is required.');
            event.target.reportValidity();
            this.scheduleMonthDayError = true;
        } else if (isNaN(val) || val < 1 || val > 31) {
            event.target.setCustomValidity('Date must be between 1 and 31.');
            event.target.reportValidity();
            this.scheduleMonthDayError = true;
        } else {
            event.target.setCustomValidity('');
            event.target.reportValidity();
            this.scheduleMonthDayError = false;
            this.scheduleMonthDay = val;
        }
    }

    get isScheduleInvalid() {
        return this.showScheduleMonthDay && this.scheduleMonthDayError;
    }

    get isRestoreScheduleInvalid() {
        return this.showRestoreScheduleMonthDay && this.restoreScheduleMonthDayError;
    }

    handleRestoreScheduleSelect(event) { this.restoreScheduleMode = event.currentTarget.dataset.freq; }
    handleRestoreScheduleTimeChange(event) {
        let fullTime = event.target.value;
        let timeParts = fullTime.split(':');
        this.restoreScheduleTime = timeParts[0] + ':' + timeParts[1];
    } handleRestoreWeekdayChange(event) { this.restoreScheduleWeekday = event.target.value; }
    handleRestoreMonthDayChange(event) {
        const raw = event.target.value;
        const val = parseInt(raw, 10);

        if (raw === '' || raw === null || raw === undefined) {
            event.target.setCustomValidity('Date of Month is required.');
            event.target.reportValidity();
            this.restoreScheduleMonthDayError = true;
        } else if (isNaN(val) || val < 1 || val > 31) {
            event.target.setCustomValidity('Date must be between 1 and 31.');
            event.target.reportValidity();
            this.restoreScheduleMonthDayError = true;
        } else {
            event.target.setCustomValidity('');
            event.target.reportValidity();
            this.restoreScheduleMonthDayError = false;
            this.restoreScheduleMonthDay = val;
        }
    }
    handleSubChevronClick(event) {
        event.stopPropagation();
        if (!event.currentTarget.classList.contains('nav-sub-chevron--enabled')) return;

        const gKey = event.currentTarget.dataset.gkey;
        const sKey = event.currentTarget.dataset.skey;
        const page = this._activePage;

        let stateArr, setFn, setActiveGKey, setActiveSKey, setActiveCSKey;

        if (page === 'metadata' || this.showMetadataBackup) {
            stateArr = this.metadataState;
            setFn = v => { this.metadataState = v; };
            setActiveGKey = v => { this.activeMetadataGKey = v; };
            setActiveSKey = v => { this.activeMetadataSKey = v; };
            setActiveCSKey = v => { this.activeMetadataCSKey = v; };
        } else if (page === 'config' || this.showConfigBackup) {
            stateArr = this.configState;
            setFn = v => { this.configState = v; };
            setActiveGKey = v => { this.activeConfigGKey = v; };
            setActiveSKey = v => { this.activeConfigSKey = v; };
            setActiveCSKey = () => { };
        } else if (page === 'orgfull' || this.showOrgFullBackup) {
            stateArr = this.orgFullState;
            setFn = v => { this.orgFullState = v; };
            setActiveGKey = v => { this.activeOrgFullGKey = v; };
            setActiveSKey = v => { this.activeOrgFullSKey = v; };
            setActiveCSKey = v => { this.activeOrgFullCSKey = v; };
        } else if (page === 'restore' || this.showRestorePanel) {
            stateArr = this.restoreState;
            setFn = v => { this.restoreState = v; };
            setActiveGKey = v => { this.activeRestoreGKey = v; };
            setActiveSKey = v => { this.activeRestoreSKey = v; };
            setActiveCSKey = v => { this.activeRestoreCSKey = v; };
        } else {
            return;
        }

        const gIdx = stateArr.findIndex(g => g.key === gKey);
        if (gIdx === -1) return;
        const sIdx = stateArr[gIdx].subs.findIndex(s => s.key === sKey);
        if (sIdx === -1) return;

        const wasExpanded = stateArr[gIdx].subs[sIdx].expanded;
        const updatedState = stateArr.map((g, gi) => gi !== gIdx ? g : {
            ...g,
            subs: g.subs.map((s, si) => si !== sIdx ? s : { ...s, expanded: !s.expanded })
        });
        setFn(updatedState);

        if (!wasExpanded) {
            setActiveGKey(gKey); setActiveSKey(sKey); setActiveCSKey('');
            this.panelSearchTerm = '';
            if (page === 'metadata') this.metadataPanelEnabled = true;
            else if (page === 'config') this.configPanelEnabled = true;
            else if (page === 'orgfull') this.orgFullPanelEnabled = true;
            else if (page === 'restore') this.restorePanelEnabled = true;
        } else {
            setActiveGKey(''); setActiveSKey(''); setActiveCSKey('');
            if (page === 'metadata') this.metadataPanelEnabled = false;
            else if (page === 'config') this.configPanelEnabled = false;
            else if (page === 'orgfull') this.orgFullPanelEnabled = false;
            else if (page === 'restore') this.restorePanelEnabled = false;
        }
    }

    _resetSchedule() {
        this.scheduleMode = 'daily';
        this.scheduleTime = '00:00';
        this.scheduleWeekday = 'MON';
        this.scheduleMonthDay = 1;
        this.scheduleMonthDayError = false; // add this
    }

    _resetRestoreSchedule() {
        this.restoreScheduleMode = 'daily';
        this.restoreScheduleTime = '00:00';
        this.restoreScheduleWeekday = 'MON';
        this.restoreScheduleMonthDay = 1;
        this.restoreScheduleMonthDayError = false; // add this
    }

    _buildSchedulePayload() {
        if (this.selectedBackupMode === 'instant') return { frequency: 'once' };
        const p = { frequency: this.scheduleMode, time: this.scheduleTime };
        if (this.scheduleMode === 'weekly') p.weekday = this.scheduleWeekday;
        if (this.scheduleMode === 'monthly') p.monthDay = this.scheduleMonthDay;
        return p;
    }

    _buildRestoreSchedulePayload() {
        if (this.selectedRestoreMode === 'instant') return { frequency: 'once' };
        const p = { frequency: this.restoreScheduleMode, time: this.restoreScheduleTime };
        if (this.restoreScheduleMode === 'weekly') p.weekday = this.restoreScheduleWeekday;
        if (this.restoreScheduleMode === 'monthly') p.monthDay = this.restoreScheduleMonthDay;
        return p;
    }

    get isJobRunning() { return this.isBackupInProgress || this.isRestoreInProgress; }
    get isNextDisabled() { return !this.selectedAction; }
    get isBackupModeNextDisabled() { return !this.selectedBackupMode; }
    get isRestoreModeNextDisabled() { return !this.selectedRestoreMode; }
    get isBackupTypeNextDisabled() { return !this.selectedBackupType; }
    get isRestoreTypeNextDisabled() { return !this.selectedRestoreType; }

    get isBackupSelected() { return this.selectedAction === 'backup'; }
    get isRestoreSelected() { return this.selectedAction === 'restore'; }
    get isInstantModeSelected() { return this.selectedBackupMode === 'instant'; }
    get isScheduleModeSelected() { return this.selectedBackupMode === 'schedule'; }
    get isInstantRestoreModeSelected() { return this.selectedRestoreMode === 'instant'; }
    get isScheduleRestoreModeSelected() { return this.selectedRestoreMode === 'schedule'; }

    get backupTypeDataClass() { return 'type-card' + (this.selectedBackupType === 'data' ? ' type-card--selected' : ''); }
    get backupTypeMetadataClass() { return 'type-card' + (this.selectedBackupType === 'metadata' ? ' type-card--selected' : ''); }
    get backupTypeConfigClass() { return 'type-card' + (this.selectedBackupType === 'config' ? ' type-card--selected' : ''); }
    get backupTypeOrgfullClass() { return 'type-card' + (this.selectedBackupType === 'orgfull' ? ' type-card--selected' : ''); }

    get restoreTypeDataClass() { return 'type-card' + (this.selectedRestoreType === 'data' ? ' type-card--selected' : ''); }
    get restoreTypeMetadataClass() { return 'type-card' + (this.selectedRestoreType === 'metadata' ? ' type-card--selected' : ''); }
    get restoreTypeConfigClass() { return 'type-card' + (this.selectedRestoreType === 'config' ? ' type-card--selected' : ''); }
    get restoreTypeOrgfullClass() { return 'type-card' + (this.selectedRestoreType === 'orgfull' ? ' type-card--selected' : ''); }

    get isLoadingOrgFullDataPanel() {
        if (this.activeOrgFullSKey !== 'dataObjects') return false;
        const group = this.orgFullState.find(g => g.key === this.activeOrgFullGKey);
        if (!group) return false;
        const sub = group.subs.find(s => s.key === 'dataObjects');
        return sub?.loading ?? false;
    }

    get isLoadingRestoreDataPanel() {
        if (this.activeRestoreSKey !== 'dataObjects') return false;
        const group = this.restoreState.find(g => g.key === this.activeRestoreGKey);
        if (!group) return false;
        const sub = group.subs.find(s => s.key === 'dataObjects');
        return sub?.loading ?? false;
    }

    handleSelection(event) { this.selectedAction = event.target.value; }
    handleBackupModeSelection(event) { this.selectedBackupMode = event.target.value; }
    handleRestoreModeSelection(event) { this.selectedRestoreMode = event.target.value; }
    handleBackupTypeSelect(event) { this.selectedBackupType = event.currentTarget.dataset.type; }
    handleRestoreTypeSelect(event) { this.selectedRestoreType = event.currentTarget.dataset.type; }

    handleNext() {
        this.showOptionSelection = false;
        if (this.selectedAction === 'backup') {
            this.showBackupModeSelection = true;
        } else {
            this.showRestoreModeSelection = true;
        }
    }

    handleBackupModeBack() {
        this.showBackupModeSelection = false;
        this.showOptionSelection = true;
        this.selectedBackupMode = '';
    }

    handleBackupModeNext() {
        this.showBackupModeSelection = false;
        this.showBackupTypeSelection = true;
    }

    handleRestoreModeBack() {
        this.showRestoreModeSelection = false;
        this.showOptionSelection = true;
        this.selectedRestoreMode = '';
    }

    handleRestoreModeNext() {
        this.showRestoreModeSelection = false;
        this.showRestoreTypeSelection = true;
    }

    handleBackupTypeBack() {
        this.showBackupTypeSelection = false;
        this.showBackupModeSelection = true;
        this.selectedBackupType = '';
    }

    handleBackupTypeNext() {
        this.showBackupTypeSelection = false;
        this._resetSchedule();
        const t = this.selectedBackupType;
        if (t === 'data') {
            this.showDataBackup = true;
        } else if (t === 'metadata') {
            this.metadataState = this._applyUpfrontPools(buildState(METADATA_DEF));
            this.activeMetadataGKey = '';
            this.activeMetadataSKey = '';
            this.activeMetadataCSKey = '';
            this.panelSearchTerm = '';
            this.showMetadataBackup = true;
        } else if (t === 'config') {
            this.configState = this._applyUpfrontPools(buildState(CONFIG_DEF));
            this.activeConfigGKey = '';
            this.activeConfigSKey = '';
            this.panelSearchTerm = '';
            this.showConfigBackup = true;
        } else if (t === 'orgfull') {
            this.orgFullState = this._applyUpfrontPools(buildState(ORGFULL_DEF));
            this.activeOrgFullGKey = '';
            this.activeOrgFullSKey = '';
            this.activeOrgFullCSKey = '';
            this.panelSearchTerm = '';
            this.showOrgFullBackup = true;
        }
    }

    handleDataBack() {
        this.showDataBackup = false;
        this.showBackupTypeSelection = true;
        this._resetDataBackup();
        this._resetSchedule();
    }

    handleMetadataBack() {
        this.showMetadataBackup = false;
        this.showBackupTypeSelection = true;
        this.metadataState = buildState(METADATA_DEF);
        this.metadataPanelEnabled = false;
        this._resetSchedule();
    }

    handleConfigBack() {
        this.showConfigBackup = false;
        this.showBackupTypeSelection = true;
        this.configState = buildState(CONFIG_DEF);
        this.configPanelEnabled = false;
        this._resetSchedule();
    }

    handleOrgFullBack() {
        this.showOrgFullBackup = false;
        this.showBackupTypeSelection = true;
        this.orgFullState = buildState(ORGFULL_DEF);
        this.orgFullPanelEnabled = false;
        this._resetSchedule();
        this._resetOrgFullPanelData();
    }

    handleRestoreTypeBack() {
        this.showRestoreTypeSelection = false;
        this.showRestoreModeSelection = true;
        this.selectedRestoreType = '';
    }

    handleRestoreTypeNext() {
        this.showRestoreTypeSelection = false;
        this._resetRestoreSchedule();
        // this.isRestoreSubmitting = false;
        if (this.selectedRestoreType === 'data') {
            this.showRestoreData = true;
        } else {
            const def = this.selectedRestoreType === 'metadata' ? METADATA_DEF
                : this.selectedRestoreType === 'config' ? CONFIG_DEF
                    : ORGFULL_DEF;
            this.restoreState = this._applyUpfrontPools(buildState(def));
            this.activeRestoreGKey = '';
            this.activeRestoreSKey = '';
            this.activeRestoreCSKey = '';
            this.panelSearchTerm = '';
            this.showRestorePanel = true;
        }
    }

    handleRestoreBack() {
        this.showRestoreData = false;
        this.showRestorePanel = false;
        this.showRestoreTypeSelection = true;
        this._resetRestorePage();
        this._resetRestoreSchedule();
        // this.isRestoreSubmitting = false; 
    }

    _applyUpfrontPools(stateArr) {
        return stateArr.map(g => ({
            ...g,
            subs: g.subs.map(s => {
                if (s.loaderKey === 'objects') return { ...s, loaded: false, loading: false };

                const cached = this._loaderCache[`loader_${s.loaderKey}`];
                return {
                    ...s,
                    pool: cached instanceof Array ? cached : s.pool,
                    loaded: cached instanceof Array ? true : s.loaded,
                    loading: false,
                    childSubs: s.childSubs ? s.childSubs.map(cs => {
                        const csCached = this._loaderCache[`loader_${cs.loaderKey}`];
                        return {
                            ...cs,
                            pool: csCached instanceof Array ? csCached : cs.pool,
                            loaded: csCached instanceof Array ? true : cs.loaded,
                            loading: false
                        };
                    }) : s.childSubs
                };
            })
        }));
    }

    _handleSubItemClick(event, page, stateArr, setFn, setActiveGKey, setActiveSKey, setActiveCSKey, isCheckboxOnly = false) {
        const gKey = event.currentTarget.dataset.gkey;
        const sKey = event.currentTarget.dataset.skey;
        const isChild = event.currentTarget.dataset.ischildsub === 'true';
        const parentSKey = event.currentTarget.dataset.parentskey || '';

        const setPanelEnabled = enabled => {
            if (page === 'metadata') this.metadataPanelEnabled = enabled;
            else if (page === 'config') this.configPanelEnabled = enabled;
            else if (page === 'orgfull') this.orgFullPanelEnabled = enabled;
            else if (page === 'restore') this.restorePanelEnabled = enabled;
        };

        if (isChild) {
            setActiveGKey(gKey); setActiveSKey(parentSKey); setActiveCSKey(sKey);
            this.panelSearchTerm = '';
            setPanelEnabled(true);

            const gIdx = stateArr.findIndex(g => g.key === gKey);
            if (gIdx === -1) return;
            const sIdx = stateArr[gIdx].subs.findIndex(s => s.key === parentSKey);
            if (sIdx === -1) return;
            const csIdx = stateArr[gIdx].subs[sIdx].childSubs?.findIndex(cs => cs.key === sKey) ?? -1;
            if (csIdx === -1) return;
            const cs = stateArr[gIdx].subs[sIdx].childSubs[csIdx];

            if (!cs.loaded && !cs.loading) this._loadChildSubItem(stateArr, gKey, parentSKey, sKey, setFn);

            if (isCheckboxOnly) {
                const isChecked = cs.pool.length > 0 && cs.selected.length === cs.pool.length;
                setFn(stateArr.map((g, gi) => gi !== gIdx ? g : {
                    ...g, subs: g.subs.map((s, si) => si !== sIdx ? s : {
                        ...s, childSubs: s.childSubs.map((c, ci) => ci !== csIdx ? c : {
                            ...c,
                            checkboxClicked: true,
                            selected: cs.loaded && cs.pool.length > 0
                                ? (isChecked ? [] : cs.pool.map(i => i.value))
                                : c.selected,
                            pendingSelect: !cs.loaded
                        })
                    })
                }));
            } else {
                setFn(stateArr.map((g, gi) => gi !== gIdx ? g : {
                    ...g, subs: g.subs.map((s, si) => si !== sIdx ? s : {
                        ...s, childSubs: s.childSubs.map((c, ci) => ci !== csIdx ? c : {
                            ...c,
                            checkboxClicked: true
                        })
                    })
                }));
            }
            return;
        }

        const gIdx = stateArr.findIndex(g => g.key === gKey);
        const sub = gIdx !== -1 ? stateArr[gIdx].subs.find(s => s.key === sKey) : null;
        const hasChildren = !!(sub?.childSubs?.length > 0);

        if (isCheckboxOnly) {
            const isChecked = sub && sub.pool.length > 0 && sub.selected.length === sub.pool.length;
            const willDeselect = isChecked;

            if (sub && !sub.loaded && !sub.loading) this._loadSubItem(stateArr, gKey, sKey, setFn);

            sub?.childSubs?.forEach(cs => {
                if (!cs.loaded && !cs.loading) this._loadChildSubItem(stateArr, gKey, sKey, cs.key, setFn);
            });

            setFn(stateArr.map(g => g.key !== gKey ? g : {
                ...g, subs: g.subs.map(s => s.key !== sKey ? s : {
                    ...s,
                    checkboxClicked: true,
                    expanded: willDeselect ? false : s.expanded,
                    selected: sub.loaded && sub.pool.length > 0
                        ? (isChecked ? [] : sub.pool.map(i => i.value))
                        : s.selected,
                    pendingSelect: !sub.loaded
                })
            }));

            if (willDeselect) {
                setActiveGKey(''); setActiveSKey(''); setActiveCSKey('');
                setPanelEnabled(false);
            } else {
                setActiveGKey(gKey); setActiveSKey(sKey); setActiveCSKey('');
                this.panelSearchTerm = '';
                setPanelEnabled(true);
            }
            return;
        }

        setFn(stateArr.map(g => g.key !== gKey ? g : {
            ...g, subs: g.subs.map(s => s.key !== sKey ? s : {
                ...s,
                checkboxClicked: true
            })
        }));

        setActiveGKey(gKey); setActiveSKey(sKey); setActiveCSKey('');
        this.panelSearchTerm = '';
        setPanelEnabled(true);
        if (sub && !sub.loaded && !sub.loading) this._loadSubItem(stateArr, gKey, sKey, setFn);
    }

    handleMetadataSubItemClick(event) {
        this._handleSubItemClick(event, 'metadata', this.metadataState,
            v => { this.metadataState = v; }, v => { this.activeMetadataGKey = v; },
            v => { this.activeMetadataSKey = v; }, v => { this.activeMetadataCSKey = v; });
    }
    handleConfigSubItemClick(event) {
        this._handleSubItemClick(event, 'config', this.configState,
            v => { this.configState = v; }, v => { this.activeConfigGKey = v; },
            v => { this.activeConfigSKey = v; }, () => { });
    }
    handleOrgFullSubItemClick(event) {
        const sKey = event.currentTarget.dataset.skey;
        const gKey = event.currentTarget.dataset.gkey;

        if (sKey === 'dataObjects') {
            this.activeOrgFullGKey = gKey;
            this.activeOrgFullSKey = sKey;
            this.activeOrgFullCSKey = '';
            this.panelSearchTerm = '';
            this.orgFullPanelEnabled = true;

            this.orgFullState = this.orgFullState.map(g => g.key !== gKey ? g : {
                ...g,
                subs: g.subs.map(s => s.key !== 'dataObjects' ? s : {
                    ...s,
                    loading: true,
                    loaded: false,
                    checkboxClicked: true,
                    pool: []
                })
            });

            setTimeout(() => {
                const pool = this.rawObjectOptions || [];
                this.orgFullState = this.orgFullState.map(g => g.key !== gKey ? g : {
                    ...g,
                    subs: g.subs.map(s => s.key !== 'dataObjects' ? s : {
                        ...s,
                        pool,
                        loading: false,
                        loaded: true,
                        checkboxClicked: true
                    })
                });
            }, 50);
            return;
        }

        this._handleSubItemClick(event, 'orgfull', this.orgFullState,
            v => { this.orgFullState = v; },
            v => { this.activeOrgFullGKey = v; },
            v => { this.activeOrgFullSKey = v; },
            v => { this.activeOrgFullCSKey = v; });
    }
    handleRestoreSubItemClick(event) {
        const sKey = event.currentTarget.dataset.skey;
        const gKey = event.currentTarget.dataset.gkey;

        if (sKey === 'dataObjects') {
            const currentSub = this.restoreState
                .find(g => g.key === gKey)?.subs
                .find(s => s.key === 'dataObjects');

            this.restoreState = this.restoreState.map(g => g.key !== gKey ? g : {
                ...g,
                subs: g.subs.map(s => s.key !== 'dataObjects' ? s : {
                    ...s,
                    loading: true,
                    loaded: false,
                    checkboxClicked: true,
                    pool: currentSub?.pool?.length ? currentSub.pool : []
                })
            });

            this.activeRestoreGKey = gKey;
            this.activeRestoreSKey = sKey;
            this.activeRestoreCSKey = '';
            this.panelSearchTerm = '';
            this.restorePanelEnabled = true;

            setTimeout(() => {
                const pool = this.rawObjectOptions || [];
                this.restoreState = this.restoreState.map(g => g.key !== gKey ? g : {
                    ...g,
                    subs: g.subs.map(s => s.key !== 'dataObjects' ? s : {
                        ...s,
                        pool,
                        loading: false,
                        loaded: true
                    })
                });
            }, 50);
            return;
        }

        this._handleSubItemClick(event, 'restore', this.restoreState,
            v => { this.restoreState = v; }, v => { this.activeRestoreGKey = v; },
            v => { this.activeRestoreSKey = v; }, v => { this.activeRestoreCSKey = v; });
    }

    _handleSubCheckbox(event, page, stateArr, setFn, setActiveGKey, setActiveSKey, setActiveCSKey) {
        event.stopPropagation();
        this._handleSubItemClick(event, page, stateArr, setFn, setActiveGKey, setActiveSKey, setActiveCSKey, true);
    }

    handleMetadataSubCheckbox(event) {
        this._handleSubCheckbox(event, 'metadata', this.metadataState,
            v => { this.metadataState = v; }, v => { this.activeMetadataGKey = v; },
            v => { this.activeMetadataSKey = v; }, v => { this.activeMetadataCSKey = v; });
    }
    handleConfigSubCheckbox(event) {
        this._handleSubCheckbox(event, 'config', this.configState,
            v => { this.configState = v; }, v => { this.activeConfigGKey = v; },
            v => { this.activeConfigSKey = v; }, () => { });
    }
    handleOrgFullSubCheckbox(event) {
        event.stopPropagation();
        const sKey = event.currentTarget.dataset.skey;
        const gKey = event.currentTarget.dataset.gkey;

        if (sKey === 'dataObjects') {
            const currentSub = this.orgFullState
                .find(g => g.key === gKey)?.subs
                .find(s => s.key === 'dataObjects');

            const isCurrentlyChecked = currentSub?.selected?.length > 0;

            if (!isCurrentlyChecked) {
                this.activeOrgFullGKey = gKey;
                this.activeOrgFullSKey = 'dataObjects';
                this.activeOrgFullCSKey = '';
                this.orgFullPanelEnabled = true;
                this.isOrgFullPanelObjectDropdownOpen = false;
                this.isOrgFullPanelRecordDropdownOpen = false;
                this.isSelectAllOrgFullPanelObjectsLoading = false;
                this.orgFullState = this.orgFullState.map(g => g.key !== gKey ? g : {
                    ...g,
                    subs: g.subs.map(s => s.key !== 'dataObjects' ? s : {
                        ...s,
                        loading: true,
                        loaded: false,
                        checkboxClicked: true,
                        pendingSelect: false,
                        selected: [],
                        pool: []
                    })
                });

                setTimeout(() => {
                    const pool = this.rawObjectOptions || [];
                    this.orgFullPanelSelectedObjects = pool.map(i => i.value);

                    this.orgFullState = this.orgFullState.map(g => g.key !== gKey ? g : {
                        ...g,
                        subs: g.subs.map(s => s.key !== 'dataObjects' ? s : {
                            ...s,
                            pool,
                            loading: false,
                            loaded: true,
                            checkboxClicked: true,
                            pendingSelect: false,
                            selected: pool.map(i => i.value)
                        })
                    });
                }, 500);
                return;
            }

            this.orgFullPanelSelectedObjects = [];
            this.orgFullPanelRawRecordOptions = [];
            this.orgFullPanelSelectedRecords = [];
            this.orgFullPanelRecordsFetched = false;
            this.activeOrgFullGKey = '';
            this.activeOrgFullSKey = '';
            this.activeOrgFullCSKey = '';
            this.orgFullPanelEnabled = false;
            this.isOrgFullPanelObjectDropdownOpen = false;
            this.isOrgFullPanelRecordDropdownOpen = false;

            this.orgFullState = this.orgFullState.map(g => g.key !== gKey ? g : {
                ...g,
                subs: g.subs.map(s => s.key !== 'dataObjects' ? s : {
                    ...s,
                    pool: [],
                    loading: false,
                    loaded: false,
                    checkboxClicked: false,
                    pendingSelect: false,
                    selected: []
                })
            });
            return;
        }

        this._handleSubCheckbox(event, 'orgfull', this.orgFullState,
            v => { this.orgFullState = v; }, v => { this.activeOrgFullGKey = v; },
            v => { this.activeOrgFullSKey = v; }, v => { this.activeOrgFullCSKey = v; });
    }

    handleRestoreSubCheckbox(event) {
        event.stopPropagation();
        const sKey = event.currentTarget.dataset.skey;
        const gKey = event.currentTarget.dataset.gkey;

        if (sKey === 'dataObjects') {
            const currentSub = this.restoreState
                .find(g => g.key === gKey)?.subs
                .find(s => s.key === 'dataObjects');

            const isCurrentlyChecked = currentSub?.selected?.length > 0;

            if (!isCurrentlyChecked) {
                this.activeRestoreGKey = gKey;
                this.activeRestoreSKey = 'dataObjects';
                this.activeRestoreCSKey = '';
                this.restorePanelEnabled = true;
                this.isRestorePanelObjectDropdownOpen = false;
                this.isRestorePanelRecordDropdownOpen = false;
                this.isSelectAllRestorePanelObjectsLoading = false;
                this.restoreState = this.restoreState.map(g => g.key !== gKey ? g : {
                    ...g,
                    subs: g.subs.map(s => s.key !== 'dataObjects' ? s : {
                        ...s,
                        loading: true,
                        loaded: false,
                        checkboxClicked: true,
                        pendingSelect: false,
                        selected: [],
                        pool: []
                    })
                });
                setTimeout(() => {
                    const pool = this.rawObjectOptions || [];
                    this.restorePanelSelectedObjects = pool.map(i => i.value);

                    this.restoreState = this.restoreState.map(g => g.key !== gKey ? g : {
                        ...g,
                        subs: g.subs.map(s => s.key !== 'dataObjects' ? s : {
                            ...s,
                            pool,
                            loading: false,
                            loaded: true,
                            checkboxClicked: true,
                            pendingSelect: false,
                            selected: pool.map(i => i.value)
                        })
                    });
                }, 500);
                return;
            }

            this.restorePanelSelectedObjects = [];
            this.restorePanelRawRecordOptions = [];
            this.restorePanelSelectedRecords = [];
            this.restorePanelRecordsFetched = false;
            this.activeRestoreGKey = '';
            this.activeRestoreSKey = '';
            this.activeRestoreCSKey = '';
            this.restorePanelEnabled = false;
            this.isRestorePanelObjectDropdownOpen = false;
            this.isRestorePanelRecordDropdownOpen = false;

            this.restoreState = this.restoreState.map(g => g.key !== gKey ? g : {
                ...g,
                subs: g.subs.map(s => s.key !== 'dataObjects' ? s : {
                    ...s,
                    pool: [],
                    loading: false,
                    loaded: false,
                    checkboxClicked: false,
                    pendingSelect: false,
                    selected: []
                })
            });
            return;
        }

        this._handleSubCheckbox(event, 'restore', this.restoreState,
            v => { this.restoreState = v; }, v => { this.activeRestoreGKey = v; },
            v => { this.activeRestoreSKey = v; }, v => { this.activeRestoreCSKey = v; });
    }

    _handleGroupCheckbox(event, page, stateArr, setFn, setActiveGKey, setActiveSKey, setActiveCSKey) {
        event.stopPropagation();
        const gKey = event.currentTarget.dataset.gkey;
        const group = stateArr.find(g => g.key === gKey);
        if (!group) return;

        const totalSelected = group.subs.reduce((sum, s) => {
            let t = s.selected.length;
            if (s.childSubs) t += s.childSubs.reduce((acc, c) => acc + c.selected.length, 0);
            return sum + t;
        }, 0);
        const deselect = totalSelected > 0;

        const setPanelEnabled = enabled => {
            if (page === 'metadata') this.metadataPanelEnabled = enabled;
            else if (page === 'config') this.configPanelEnabled = enabled;
            else if (page === 'orgfull') this.orgFullPanelEnabled = enabled;
            else if (page === 'restore') this.restorePanelEnabled = enabled;
        };
        const latestState = this._latestStateFor(page, stateArr);
        const updated = latestState.map(g => {
            if (g.key !== gKey) return g;
            return {
                ...g,
                subs: g.subs.map(s => ({
                    ...s,
                    checkboxClicked: !deselect,
                    expanded: !deselect,
                    pendingSelect: false,
                    loading: false,
                    selected: deselect
                        ? []
                        : s.loaded && s.pool.length > 0
                            ? s.pool.map(i => i.value)
                            : s.selected,
                    childSubs: s.childSubs?.map(cs => ({
                        ...cs,
                        checkboxClicked: !deselect,
                        pendingSelect: false,
                        loading: false,
                        selected: deselect
                            ? []
                            : cs.loaded && cs.pool.length > 0
                                ? cs.pool.map(i => i.value)
                                : cs.selected
                    }))
                }))
            };
        });
        setFn(updated);

        if (deselect) {
            setActiveGKey(''); setActiveSKey('');
            if (setActiveCSKey) setActiveCSKey('');
            setPanelEnabled(false);
            return;
        }

        group.subs.forEach(s => {
            if (!s.loaded) this._loadSubItem(updated, gKey, s.key, setFn);
            s.childSubs?.forEach(cs => {
                if (!cs.loaded) this._loadChildSubItem(updated, gKey, s.key, cs.key, setFn);
            });
        });

        const firstSub = group.subs[0];
        if (firstSub) {
            setActiveGKey(gKey); setActiveSKey(firstSub.key);
            if (setActiveCSKey) setActiveCSKey('');
            this.panelSearchTerm = '';
            setPanelEnabled(true);
            if (!firstSub.loaded && !firstSub.loading) this._loadSubItem(updated, gKey, firstSub.key, setFn);
        }
    }

    handleMetadataGroupCheckbox(event) {
        this._handleGroupCheckbox(event, 'metadata', this.metadataState,
            v => { this.metadataState = v; }, v => { this.activeMetadataGKey = v; },
            v => { this.activeMetadataSKey = v; }, v => { this.activeMetadataCSKey = v; });
    }
    handleConfigGroupCheckbox(event) {
        this._handleGroupCheckbox(event, 'config', this.configState,
            v => { this.configState = v; }, v => { this.activeConfigGKey = v; },
            v => { this.activeConfigSKey = v; }, () => { });
    }
    handleOrgFullGroupCheckbox(event) {
        const gKey = event.currentTarget.dataset.gkey;

        if (gKey === 'data') {
            const group = this.orgFullState.find(g => g.key === 'data');
            const totalSelected = group?.subs.reduce((sum, s) => sum + (s.selected?.length || 0), 0) || 0;
            const isCurrentlyChecked = totalSelected > 0;

            if (!isCurrentlyChecked) {
                this.activeOrgFullGKey = 'data';
                this.activeOrgFullSKey = 'dataObjects';
                this.activeOrgFullCSKey = '';
                this.orgFullPanelEnabled = true;
                this.isOrgFullPanelObjectDropdownOpen = false;
                this.isOrgFullPanelRecordDropdownOpen = false;
                this.isSelectAllOrgFullPanelObjectsLoading = false;
                this.isLoadingOrgFullPanelRecords = false;

                this.orgFullState = this.orgFullState.map(g => g.key !== 'data' ? g : {
                    ...g,
                    subs: g.subs.map(s => s.key !== 'dataObjects' ? s : {
                        ...s,
                        loading: true,
                        loaded: false,
                        checkboxClicked: true,
                        pendingSelect: false,
                        selected: [],
                        pool: []
                    })
                });

                setTimeout(() => {
                    const pool = this.rawObjectOptions || [];
                    this.orgFullPanelSelectedObjects = pool.map(i => i.value);

                    this.orgFullState = this.orgFullState.map(g => g.key !== 'data' ? g : {
                        ...g,
                        subs: g.subs.map(s => s.key !== 'dataObjects' ? s : {
                            ...s,
                            pool,
                            loading: false,
                            loaded: true,
                            checkboxClicked: true,
                            pendingSelect: false,
                            selected: pool.map(i => i.value)
                        })
                    });
                }, 500);
                return;
            }

            this.orgFullPanelSelectedObjects = [];
            this.orgFullPanelRawRecordOptions = [];
            this.orgFullPanelSelectedRecords = [];
            this.orgFullPanelRecordsFetched = false;
            this.activeOrgFullGKey = '';
            this.activeOrgFullSKey = '';
            this.activeOrgFullCSKey = '';
            this.orgFullPanelEnabled = false;
            this.isOrgFullPanelObjectDropdownOpen = false;
            this.isOrgFullPanelRecordDropdownOpen = false;

            this.orgFullState = this.orgFullState.map(g => g.key !== 'data' ? g : {
                ...g,
                subs: g.subs.map(s => s.key !== 'dataObjects' ? s : {
                    ...s,
                    pool: [],
                    loading: false,
                    loaded: false,
                    checkboxClicked: false,
                    pendingSelect: false,
                    selected: []
                })
            });
            return;
        }

        this._handleGroupCheckbox(event, 'orgfull', this.orgFullState,
            v => { this.orgFullState = v; }, v => { this.activeOrgFullGKey = v; },
            v => { this.activeOrgFullSKey = v; }, v => { this.activeOrgFullCSKey = v; });
    }
    handleRestoreGroupCheckbox(event) {
        const gKey = event.currentTarget.dataset.gkey;

        if (gKey === 'data') {
            const group = this.restoreState.find(g => g.key === 'data');
            const totalSelected = group?.subs.reduce((sum, s) => sum + (s.selected?.length || 0), 0) || 0;
            const isCurrentlyChecked = totalSelected > 0;

            if (!isCurrentlyChecked) {
                this.activeRestoreGKey = 'data';
                this.activeRestoreSKey = 'dataObjects';
                this.activeRestoreCSKey = '';
                this.restorePanelEnabled = true;
                this.isRestorePanelObjectDropdownOpen = false;
                this.isRestorePanelRecordDropdownOpen = false;
                this.isSelectAllRestorePanelObjectsLoading = false;
                this.isLoadingRestorePanelRecords = false;

                this.restoreState = this.restoreState.map(g => g.key !== 'data' ? g : {
                    ...g,
                    subs: g.subs.map(s => s.key !== 'dataObjects' ? s : {
                        ...s,
                        loading: true,
                        loaded: false,
                        checkboxClicked: true,
                        pendingSelect: false,
                        selected: [],
                        pool: []
                    })
                });

                setTimeout(() => {
                    const pool = this.rawObjectOptions || [];
                    this.restorePanelSelectedObjects = pool.map(i => i.value);

                    this.restoreState = this.restoreState.map(g => g.key !== 'data' ? g : {
                        ...g,
                        subs: g.subs.map(s => s.key !== 'dataObjects' ? s : {
                            ...s,
                            pool,
                            loading: false,
                            loaded: true,
                            checkboxClicked: true,
                            pendingSelect: false,
                            selected: pool.map(i => i.value)
                        })
                    });
                }, 500);
                return;
            }

            this.restorePanelSelectedObjects = [];
            this.restorePanelRawRecordOptions = [];
            this.restorePanelSelectedRecords = [];
            this.restorePanelRecordsFetched = false;
            this.activeRestoreGKey = '';
            this.activeRestoreSKey = '';
            this.activeRestoreCSKey = '';
            this.restorePanelEnabled = false;
            this.isRestorePanelObjectDropdownOpen = false;
            this.isRestorePanelRecordDropdownOpen = false;

            this.restoreState = this.restoreState.map(g => g.key !== 'data' ? g : {
                ...g,
                subs: g.subs.map(s => s.key !== 'dataObjects' ? s : {
                    ...s,
                    pool: [],
                    loading: false,
                    loaded: false,
                    checkboxClicked: false,
                    pendingSelect: false,
                    selected: []
                })
            });
            return;
        }

        this._handleGroupCheckbox(event, 'restore', this.restoreState,
            v => { this.restoreState = v; }, v => { this.activeRestoreGKey = v; },
            v => { this.activeRestoreSKey = v; }, v => { this.activeRestoreCSKey = v; });
    }

    _toggleAllActivePanel(stateArr, gKey, sKey, csKey, setFn) {
        if (csKey) {
            setFn(stateArr.map(g => g.key !== gKey ? g : {
                ...g, subs: g.subs.map(s => s.key !== sKey || !s.childSubs ? s : {
                    ...s, childSubs: s.childSubs.map(cs => cs.key !== csKey ? cs : {
                        ...cs,
                        checkboxClicked: true,
                        selected: cs.selected.length === cs.pool.length ? [] : cs.pool.map(i => i.value)
                    })
                })
            }));
            return;
        }
        setFn(stateArr.map(g => g.key !== gKey ? g : {
            ...g, subs: g.subs.map(s => s.key !== sKey ? s : {
                ...s,
                checkboxClicked: true,
                selected: s.selected.length === s.pool.length ? [] : s.pool.map(i => i.value)
            })
        }));
    }

    toggleAllActiveMetadataPanel(event) { event.stopPropagation(); this._toggleAllActivePanel(this.metadataState, this.activeMetadataGKey, this.activeMetadataSKey, this.activeMetadataCSKey, v => { this.metadataState = v; }); }
    toggleAllActiveConfigPanel(event) { event.stopPropagation(); this._toggleAllActivePanel(this.configState, this.activeConfigGKey, this.activeConfigSKey, '', v => { this.configState = v; }); }
    toggleAllActiveOrgFullPanel(event) { event.stopPropagation(); this._toggleAllActivePanel(this.orgFullState, this.activeOrgFullGKey, this.activeOrgFullSKey, this.activeOrgFullCSKey, v => { this.orgFullState = v; }); }
    toggleAllActiveRestorePanel(event) { event.stopPropagation(); this._toggleAllActivePanel(this.restoreState, this.activeRestoreGKey, this.activeRestoreSKey, this.activeRestoreCSKey, v => { this.restoreState = v; }); }

    _togglePanelItem(stateArr, gKey, sKey, csKey, val, setFn) {
        if (csKey) {
            setFn(stateArr.map(g => g.key !== gKey ? g : {
                ...g, subs: g.subs.map(s => s.key !== sKey || !s.childSubs ? s : {
                    ...s, childSubs: s.childSubs.map(cs => cs.key !== csKey ? cs : {
                        ...cs, selected: this._toggle(cs.selected, val), checkboxClicked: true
                    })
                })
            }));
            return;
        }
        setFn(stateArr.map(g => g.key !== gKey ? g : {
            ...g, subs: g.subs.map(s => s.key !== sKey ? s : {
                ...s, selected: this._toggle(s.selected, val), checkboxClicked: true
            })
        }));
    }

    handlePanelItemToggle(event) {
        event.stopPropagation();
        const val = event.currentTarget.dataset.value;
        const page = this._activePage;
        if (page === 'metadata') this._togglePanelItem(this.metadataState, this.activeMetadataGKey, this.activeMetadataSKey, this.activeMetadataCSKey, val, v => { this.metadataState = v; });
        if (page === 'config') this._togglePanelItem(this.configState, this.activeConfigGKey, this.activeConfigSKey, '', val, v => { this.configState = v; });
        if (page === 'orgfull') this._togglePanelItem(this.orgFullState, this.activeOrgFullGKey, this.activeOrgFullSKey, this.activeOrgFullCSKey, val, v => { this.orgFullState = v; });
        if (page === 'restore') this._togglePanelItem(this.restoreState, this.activeRestoreGKey, this.activeRestoreSKey, this.activeRestoreCSKey, val, v => { this.restoreState = v; });
    }

    handlePanelSearch(event) { this.panelSearchTerm = event.target.value; }

    get hasDataSelectedObjects() { return this.dataSelectedObjects.length > 0; }
    get dataSelectedObjectsCount() { return this.dataSelectedObjects.length; }
    get isDataMultipleObjects() { return this.dataSelectedObjects.length > 1; }
    get dataSelectedObjectLabels() { return this._labels(this.rawObjectOptions, this.dataSelectedObjects); }
    get isAllDataObjectsSelected() { return this.rawObjectOptions.length > 0 && this.dataSelectedObjects.length === this.rawObjectOptions.length; }
    get isDataObjectsIndeterminate() { return this.dataSelectedObjects.length > 0 && !this.isAllDataObjectsSelected; }
    get dataObjectTriggerClass() { return 'ms-trigger' + (this.isDataObjectDropdownOpen ? ' ms-trigger--open' : ''); }
    get filteredDataObjects() { return this._buildMsList(this.rawObjectOptions, this.dataSelectedObjects, this.dataObjectSearchTerm); }
    get hasFilteredDataObjects() { return this.filteredDataObjects.length > 0; }

    get selectAllDataObjectsCheckboxClass() {
        let c = 'ms-checkbox';
        if (this.isAllDataObjectsSelected) c += ' ms-checkbox--checked';
        else if (this.isDataObjectsIndeterminate) c += ' ms-checkbox--checked ms-checkbox--indeterminate';
        return c;
    }

    get hasDataSelectedRecords() { return this.dataSelectedRecords.length > 0; }
    get dataSelectedRecordsCount() { return this.dataSelectedRecords.length; }
    get dataSelectedRecordLabels() { return this._labels(this.dataRawRecordOptions, this.dataSelectedRecords); }
    get isAllDataRecordsSelected() { return this.dataRawRecordOptions.length > 0 && this.dataSelectedRecords.length === this.dataRawRecordOptions.length; }
    get isDataRecordsIndeterminate() { return this.dataSelectedRecords.length > 0 && !this.isAllDataRecordsSelected; }
    get filteredDataRecords() { return this._buildMsList(this.dataRawRecordOptions, this.dataSelectedRecords, this.dataRecordSearchTerm); }
    get hasFilteredDataRecords() { return this.filteredDataRecords.length > 0; }
    get isDataBackupDisabled() {
        return this.noDataRecordsAvailable || !this.hasDataSelectedObjects || this.isScheduleInvalid || this.isJobRunning;
    }

    get dataRecordTriggerClass() {
        let c = 'ms-trigger';
        if (this.isDataRecordDropdownOpen) c += ' ms-trigger--open';
        if (this.isDataMultipleObjects || this.isLoadingDataRecords || !this.hasDataSelectedObjects) c += ' ms-trigger--disabled';
        return c;
    }

    get selectAllDataRecordsCheckboxClass() {
        let c = 'ms-checkbox';
        if (this.isAllDataRecordsSelected) c += ' ms-checkbox--checked';
        else if (this.isDataRecordsIndeterminate) c += ' ms-checkbox--checked ms-checkbox--indeterminate';
        return c;
    }

    get hasRestoreDataSelectedObjects() { return this.restoreDataSelectedObjects.length > 0; }
    get restoreDataSelectedObjectsCount() { return this.restoreDataSelectedObjects.length; }
    get restoreDataSelectedObjectLabels() { return this._labels(this.rawObjectOptions, this.restoreDataSelectedObjects); }
    get isAllRestoreDataObjectsSelected() { return this.rawObjectOptions.length > 0 && this.restoreDataSelectedObjects.length === this.rawObjectOptions.length; }
    get selectAllRestoreDataObjectsCheckboxClass() { return 'ms-checkbox' + (this.isAllRestoreDataObjectsSelected ? ' ms-checkbox--checked' : ''); }
    get restoreDataObjectTriggerClass() { return 'ms-trigger' + (this.isRestoreDataObjectDropdownOpen ? ' ms-trigger--open' : ''); }
    get filteredRestoreDataObjects() { return this._buildMsList(this.rawObjectOptions, this.restoreDataSelectedObjects, this.restoreDataObjectSearchTerm); }
    get hasFilteredRestoreDataObjects() { return this.filteredRestoreDataObjects.length > 0; }
    get isRestoreDataMultipleObjects() { return this.restoreDataSelectedObjects.length > 1; }
    get hasRestoreDataSelectedRecords() { return this.restoreDataSelectedRecords.length > 0; }
    get restoreDataSelectedRecordsCount() { return this.restoreDataSelectedRecords.length; }
    get restoreDataSelectedRecordLabels() { return this._labels(this.restoreDataRawRecordOptions, this.restoreDataSelectedRecords); }
    get isAllRestoreDataRecordsSelected() { return this.restoreDataRawRecordOptions.length > 0 && this.restoreDataSelectedRecords.length === this.restoreDataRawRecordOptions.length; }
    get selectAllRestoreDataRecordsCheckboxClass() { return 'ms-checkbox' + (this.isAllRestoreDataRecordsSelected ? ' ms-checkbox--checked' : ''); }
    get filteredRestoreDataRecords() { return this._buildMsList(this.restoreDataRawRecordOptions, this.restoreDataSelectedRecords, this.restoreDataRecordSearchTerm); }
    get hasFilteredRestoreDataRecords() { return this.filteredRestoreDataRecords.length > 0; }
    get isRestoreDataDisabled() {
        return !this.hasRestoreDataSelectedObjects
            || this.isRestoreSubmitting
            || this.isRestoreScheduleInvalid
            || this.isJobRunning;
    }

    get restoreDataRecordTriggerClass() {
        let c = 'ms-trigger';
        if (this.isRestoreDataRecordDropdownOpen) c += ' ms-trigger--open';
        if (this.isRestoreDataMultipleObjects || this.isLoadingRestoreDataRecords || !this.hasRestoreDataSelectedObjects) c += ' ms-trigger--disabled';
        return c;
    }

    toggleDataObjectDropdown(event) {
        event.stopPropagation();
        this.isDataObjectDropdownOpen = !this.isDataObjectDropdownOpen;
        this.isDataRecordDropdownOpen = false;
    }
    handleDataObjectSearch(event) { this.dataObjectSearchTerm = event.target.value; }

    handleDataObjectToggle(event) {
        event.stopPropagation();
        const updated = this._toggle(this.dataSelectedObjects, event.currentTarget.dataset.value);
        this.dataSelectedObjects = updated;
        this.dataRawRecordOptions = [];
        this.dataSelectedRecords = [];
        this.isDataRecordDropdownOpen = false;
        if (updated.length === 1) this.loadDataRecords(updated[0]);
    }

    toggleSelectAllDataObjects(event) {
        event.stopPropagation();
        this.isSelectAllDataObjectsLoading = true;
        setTimeout(() => {
            try {
                this.dataSelectedObjects = this.isAllDataObjectsSelected ? [] : this.rawObjectOptions.map(o => o.value);
                this.dataRawRecordOptions = [];
                this.dataSelectedRecords = [];
            } finally { this.isSelectAllDataObjectsLoading = false; }
        }, 0);
    }

    clearDataObjects(event) {
        event.stopPropagation();
        this.dataSelectedObjects = [];
        this.dataRawRecordOptions = [];
        this.dataSelectedRecords = [];
        this._closeAllDropdowns();
        this.dataRecordsFetched = false;
    }

    toggleDataRecordDropdown(event) {
        if (this.isDataMultipleObjects || this.isLoadingDataRecords || !this.hasDataSelectedObjects) return;
        event.stopPropagation();
        this.isDataRecordDropdownOpen = !this.isDataRecordDropdownOpen;
        this.isDataObjectDropdownOpen = false;
    }
    handleDataRecordSearch(event) { this.dataRecordSearchTerm = event.target.value; }

    handleDataRecordToggle(event) {
        event.stopPropagation();
        this.dataSelectedRecords = this._toggle(this.dataSelectedRecords, event.currentTarget.dataset.value);
    }

    toggleSelectAllDataRecords(event) {
        event.stopPropagation();
        this.isSelectAllDataRecordsLoading = true;
        setTimeout(() => {
            try {
                this.dataSelectedRecords = this.isAllDataRecordsSelected ? [] : this.dataRawRecordOptions.map(r => r.value);
            } finally { this.isSelectAllDataRecordsLoading = false; }
        }, 0);
    }

    clearDataRecords(event) {
        event.stopPropagation();
        this.dataSelectedRecords = [];
        this._closeAllDropdowns();
    }

    toggleRestoreDataObjectDropdown(event) {
        event.stopPropagation();
        this.isRestoreDataObjectDropdownOpen = !this.isRestoreDataObjectDropdownOpen;
        this.isRestoreDataRecordDropdownOpen = false;
    }
    handleRestoreDataObjectSearch(event) { this.restoreDataObjectSearchTerm = event.target.value; }

    handleRestoreDataObjectToggle(event) {
        event.stopPropagation();
        const updated = this._toggle(this.restoreDataSelectedObjects, event.currentTarget.dataset.value);
        this.restoreDataSelectedObjects = updated;
        this.restoreDataRawRecordOptions = [];
        this.restoreDataSelectedRecords = [];
        this.restoreFileList = [];
        this.restoreSelectedFileIds = [];
        this.isRestoreDataRecordDropdownOpen = false;
        if (updated.length === 1) this.loadRestoreDataRecords(updated[0]);
    }

    toggleSelectAllRestoreDataObjects(event) {
        event.stopPropagation();
        this.restoreDataSelectedObjects = this.isAllRestoreDataObjectsSelected ? [] : this.rawObjectOptions.map(o => o.value);
        this.restoreDataRawRecordOptions = [];
        this.restoreDataSelectedRecords = [];
        this.restoreFileList = [];
        this.restoreSelectedFileIds = [];
    }

    clearRestoreDataObjects(event) {
        event.stopPropagation();
        this.restoreDataSelectedObjects = [];
        this.restoreDataRawRecordOptions = [];
        this.restoreDataSelectedRecords = [];
        this.restoreFileList = [];
        this.restoreSelectedFileIds = [];
        this._closeAllDropdowns();
        this.restoreDataRecordsFetched = false;
    }

    toggleRestoreDataRecordDropdown(event) {
        if (this.isRestoreDataMultipleObjects || this.isLoadingRestoreDataRecords || !this.hasRestoreDataSelectedObjects) return;
        event.stopPropagation();
        this.isRestoreDataRecordDropdownOpen = !this.isRestoreDataRecordDropdownOpen;
        this.isRestoreDataObjectDropdownOpen = false;
    }
    handleRestoreDataRecordSearch(event) { this.restoreDataRecordSearchTerm = event.target.value; }

    handleRestoreDataRecordToggle(event) {
        event.stopPropagation();
        this.restoreDataSelectedRecords = this._toggle(this.restoreDataSelectedRecords, event.currentTarget.dataset.value);
    }

    toggleSelectAllRestoreDataRecords(event) {
        event.stopPropagation();
        this.isSelectAllRestoreDataRecordsLoading = true;
        setTimeout(() => {
            try {
                this.restoreDataSelectedRecords = this.isAllRestoreDataRecordsSelected ? [] : this.restoreDataRawRecordOptions.map(r => r.value);
            } finally { this.isSelectAllRestoreDataRecordsLoading = false; }
        }, 0);
    }

    clearRestoreDataRecords(event) {
        event.stopPropagation();
        this.restoreDataSelectedRecords = [];
        this.restoreFileList = [];
        this.restoreSelectedFileIds = [];
        this._closeAllDropdowns();
    }

    stopPropagation(event) { event.stopPropagation(); }

    _closeAllDropdowns() {
        this.isDataObjectDropdownOpen = false;
        this.isDataRecordDropdownOpen = false;
        this.isRestoreDataObjectDropdownOpen = false;
        this.isRestoreDataRecordDropdownOpen = false;
        this.isOrgFullPanelObjectDropdownOpen = false;
        this.isOrgFullPanelRecordDropdownOpen = false;
        this.isRestorePanelObjectDropdownOpen = false;
        this.isRestorePanelRecordDropdownOpen = false;
    }

    _toggle(arr, val) {
        const idx = arr.indexOf(val);
        const u = [...arr];
        idx === -1 ? u.push(val) : u.splice(idx, 1);
        return u;
    }

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
                    itemClass: 'ms-item' + (checked ? ' ms-item--selected' : ''),
                    checkboxClass: 'ms-checkbox' + (checked ? ' ms-checkbox--checked' : '')
                };
            });
    }

    _toast(variant, title, message) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    // ── Reset helpers ─────────────────────────────────────────────────────────

    _resetDataBackup() {
        this.dataSelectedObjects = [];
        this.dataRawRecordOptions = [];
        this.dataSelectedRecords = [];
        this.dataObjectSearchTerm = '';
        this.dataRecordSearchTerm = '';
        this._closeAllDropdowns();
        this.dataRecordsFetched = false;
    }

    /** Resets the metadata backup panel selections and active keys */
    _resetMetadataBackup() {
        this.metadataState = this._applyUpfrontPools(buildState(METADATA_DEF));
        this.activeMetadataGKey = '';
        this.activeMetadataSKey = '';
        this.activeMetadataCSKey = '';
        this.metadataPanelEnabled = false;
        this.panelSearchTerm = '';
    }

    /** Resets the config backup panel selections and active keys */
    _resetConfigBackup() {
        this.configState = this._applyUpfrontPools(buildState(CONFIG_DEF));
        this.activeConfigGKey = '';
        this.activeConfigSKey = '';
        this.configPanelEnabled = false;
        this.panelSearchTerm = '';
    }

    /** Resets the orgfull panel data dropdowns */
    _resetOrgFullPanelData() {
        this.orgFullPanelSelectedObjects = [];
        this.orgFullPanelObjectSearchTerm = '';
        this.orgFullPanelRawRecordOptions = [];
        this.orgFullPanelSelectedRecords = [];
        this.orgFullPanelRecordSearchTerm = '';
        this.orgFullPanelRecordsFetched = false;
        this.isOrgFullPanelObjectDropdownOpen = false;
        this.isOrgFullPanelRecordDropdownOpen = false;
        this.isSelectAllOrgFullPanelObjectsLoading = false;
        this.isLoadingOrgFullPanelRecords = false;
    }

    /** Resets the orgfull backup panel selections, active keys, and data dropdowns */
    _resetOrgFullBackup() {
        this.orgFullState = this._applyUpfrontPools(buildState(ORGFULL_DEF));
        this.activeOrgFullGKey = '';
        this.activeOrgFullSKey = '';
        this.activeOrgFullCSKey = '';
        this.orgFullPanelEnabled = false;
        this.panelSearchTerm = '';
        this._resetOrgFullPanelData();
    }

    /** Resets the restore panel data dropdowns */
    _resetRestorePanelData() {
        this.restorePanelSelectedObjects = [];
        this.restorePanelObjectSearchTerm = '';
        this.restorePanelRawRecordOptions = [];
        this.restorePanelSelectedRecords = [];
        this.restorePanelRecordSearchTerm = '';
        this.restorePanelRecordsFetched = false;
        this.isRestorePanelObjectDropdownOpen = false;
        this.isRestorePanelRecordDropdownOpen = false;
        this.isSelectAllRestorePanelObjectsLoading = false;
        this.isLoadingRestorePanelRecords = false;
    }

    _resetRestorePage() {
        this.restoreDataSelectedObjects = [];
        this.restoreDataObjectSearchTerm = '';
        this.restoreDataRawRecordOptions = [];
        this.restoreDataSelectedRecords = [];
        this.restoreDataRecordSearchTerm = '';
        this.restoreFileList = [];
        this.restoreSelectedFileIds = [];
        this.restoreState = [];
        this.activeRestoreGKey = '';
        this.activeRestoreSKey = '';
        this.activeRestoreCSKey = '';
        this.restorePanelEnabled = false;
        this.panelSearchTerm = '';
        this._closeAllDropdowns();
        this.restoreDataRecordsFetched = false;
        this._resetRestorePanelData();
        //   this.isRestoreSubmitting = false;
    }

    _onBackupStarted(jobId, label, mode, scheduleMode) {
        if (mode === 'instant' && jobId) {
            this._activeJobIds = [jobId];
            this.isBackupInProgress = true;
            this.jobRows = [];
            this._startPolling();
            this._toast('success', 'Backup Started', `${label} has been started successfully.`);

        } else if (mode === 'schedule') {
            const freqMap = { daily: 'Daily', weekly: 'Weekly', monthly: 'Monthly' };
            const freq = freqMap[scheduleMode] || scheduleMode;
            this._toast('success', 'Backup Scheduled',
                `${label} scheduled (${freq}). Backup will run at your configured time.`);
        }
    }
    // ── START BACKUP actions (all reset their own page on success) ────────────

    startDataBackup() {
        const schedulePayload = JSON.stringify(this._buildSchedulePayload());
        const recordIds = this.isDataMultipleObjects ? [] : this.dataSelectedRecords;

        startDataBackupApex({
            selectedObjects: this.dataSelectedObjects.join(','),
            recordIds: recordIds,
            schedulePayload
        })
            .then(jobId => {
                this._resetDataBackup();
                this._resetSchedule();
                this._onBackupStarted(jobId, 'Data Backup', this.selectedBackupMode, this.scheduleMode);
            })
            .catch(e => this._toast('error', 'Error', e?.body?.message || 'An error occurred'));
    }

    startMetadataBackup() {
        const payload = {};
        this.metadataState.forEach(g => g.subs.forEach(s => {
            if (s.selected.length) payload[`${g.key}_${s.key}`] = s.selected;
            s.childSubs?.forEach(cs => {
                if (cs.selected.length) payload[`${g.key}_${cs.key}`] = cs.selected;
            });
        }));

        startMetadataBackupApex({
            groupPayload: JSON.stringify(payload),
            schedulePayload: JSON.stringify(this._buildSchedulePayload())
        })
            .then(jobId => {
                this._resetMetadataBackup();
                this._resetSchedule();
                this._onBackupStarted(jobId, 'Metadata Backup', this.selectedBackupMode, this.scheduleMode);
            })
            .catch(e => this._toast('error', 'Error', e?.body?.message || 'An error occurred'));
    }

    startConfigBackup() {
        const payload = {};
        this.configState.forEach(g => g.subs.forEach(s => {
            if (s.selected.length) payload[`${g.key}_${s.key}`] = s.selected;
        }));

        startConfigBackupApex({
            groupPayload: JSON.stringify(payload),
            schedulePayload: JSON.stringify(this._buildSchedulePayload())
        })
            .then(jobId => {
                this._resetConfigBackup();
                this._resetSchedule();
                this._onBackupStarted(jobId, 'Config Backup', this.selectedBackupMode, this.scheduleMode);
            })
            .catch(e => this._toast('error', 'Error', e?.body?.message || 'An error occurred'));
    }

    startOrgFullBackup() {
        const meta = {}, cfg = {};
        this.orgFullState.forEach(g => {
            const inMeta = METADATA_DEF.find(m => m.key === g.key);
            const inCfg = CONFIG_DEF.find(c => c.key === g.key);
            g.subs.forEach(s => {
                if (s.selected.length) {
                    if (inMeta) meta[`${g.key}_${s.key}`] = s.selected;
                    else if (inCfg) cfg[`${g.key}_${s.key}`] = s.selected;
                }
                s.childSubs?.forEach(cs => {
                    if (cs.selected.length) {
                        if (inMeta) meta[`${g.key}_${cs.key}`] = cs.selected;
                        else if (inCfg) cfg[`${g.key}_${cs.key}`] = cs.selected;
                    }
                });
            });
        });

        const dataGroup = this.orgFullState.find(g => g.key === 'data');
        const objSel = this.orgFullPanelSelectedObjects.length > 0
            ? this.orgFullPanelSelectedObjects
            : (dataGroup?.subs[0]?.selected ?? []);

        startOrgFullBackupApex({
            selectedObjects: objSel.join(','),
            metadataPayload: JSON.stringify(meta),
            configPayload: JSON.stringify(cfg),
            schedulePayload: JSON.stringify(this._buildSchedulePayload())
        })
            .then(jobId => {
                this._resetOrgFullBackup();
                this._resetSchedule();
                this._onBackupStarted(jobId, 'Org Full Backup', this.selectedBackupMode, this.scheduleMode);
            })
            .catch(e => this._toast('error', 'Error', e?.body?.message || 'An error occurred'));
    }

    // ── START RESTORE ─────────────────────────────────────────────────────────

    startRestore() {
        this.isRestoreSubmitting = true;

        const type = this.selectedRestoreType;
        const schedulePayload = JSON.stringify(this._buildRestoreSchedulePayload());
        const isScheduled = this.selectedRestoreMode === 'schedule';

        const savedObjects = type === 'data'
            ? [...this.restoreDataSelectedObjects]
            : [...this.restorePanelSelectedObjects];
        const savedRecords = type === 'data'
            ? [...this.restoreDataSelectedRecords]
            : [...this.restorePanelSelectedRecords];
        const savedFileIds = [...(this.restoreSelectedFileIds || [])];

        // ── Build human-readable object label for filename ──────────────────
        const savedObjectLabels = savedObjects.map(val => {
            const match = this.rawObjectOptions.find(o => o.value === val);
            return match ? match.label : val;
        });
        const objectLabel = savedObjectLabels.length === 0
            ? 'Unknown'
            : savedObjectLabels.length === 1
                ? savedObjectLabels[0]
                : savedObjectLabels.length <= 3
                    ? 'Multiple Objects'
                    : 'Multiple Objects';
        console.log('groupPayload:', JSON.stringify({
            objects: savedObjects,
            objectLabel: objectLabel,
            recordIds: savedRecords,
            fileIds: savedFileIds
        }));

        // Pre-clear UI
        if (type === 'data') {
            this.restoreDataSelectedObjects = [];
            this.restoreDataRawRecordOptions = [];
            this.restoreDataSelectedRecords = [];
            this.restoreFileList = [];
            this.restoreSelectedFileIds = [];
            this.restoreDataRecordsFetched = false;
            this._closeAllDropdowns();
        } else {
            this.restorePanelSelectedObjects = [];
            this.restorePanelRawRecordOptions = [];
            this.restorePanelSelectedRecords = [];
            this.restorePanelRecordsFetched = false;
            this._closeAllDropdowns();
        }

        const onSuccess = result => {
            this.isRestoreSubmitting = false;

            if (isScheduled) {
                const freqMap = { daily: 'Daily', weekly: 'Weekly', monthly: 'Monthly' };
                const freq = freqMap[this.restoreScheduleMode] || this.restoreScheduleMode;
                this._toast('success', 'Restore Scheduled',
                    `Restore has been scheduled successfully (${freq}). It will run at your configured time.`);
                return;
            }

            const { msg, jobId } = this._parseRestoreResult(result);
            if (!msg) return;

            this._toast('success', 'Restore Started',
                'Restore has been started successfully.');

            if (jobId) {
                this._activeJobIds = [jobId];
                this.isRestoreInProgress = true;
                this.jobRows = [];
                this._startPolling();
            }
        };

        const onError = e => {
            this.isRestoreSubmitting = false;
            if (type === 'data') {
                this.restoreDataSelectedObjects = savedObjects;
                this.restoreDataSelectedRecords = savedRecords;
                this.restoreSelectedFileIds = savedFileIds;
            } else {
                this.restorePanelSelectedObjects = savedObjects;
                this.restorePanelSelectedRecords = savedRecords;
            }
            this._toast('error', 'Error', e?.body?.message || 'An error occurred');
        };

        if (type === 'data') {
            if (!savedObjects.length) {
                this.isRestoreSubmitting = false;
                this._toast('error', 'Validation', 'Select at least one object.');
                return;
            }
            startGroupRestoreApex({
                restoreType: type,
                groupPayload: JSON.stringify({
                    objects: savedObjects,
                    objectLabel: objectLabel,   // ← single object name OR "Multiple Objects"
                    recordIds: savedRecords,
                    fileIds: savedFileIds
                }),
                schedulePayload
            }).then(onSuccess).catch(onError);
        } else {
            const payload = {};
            this.restoreState.forEach(g => g.subs.forEach(s => {
                if (s.selected.length) payload[`${g.key}_${s.key}`] = s.selected;
                s.childSubs?.forEach(cs => {
                    if (cs.selected.length) payload[`${g.key}_${cs.key}`] = cs.selected;
                });
            }));
            if (savedObjects.length > 0) {
                payload['data_dataObjects'] = savedObjects;
                payload['data_objectLabel'] = objectLabel; 
            }
            if (!Object.keys(payload).length) {
                this.isRestoreSubmitting = false;
                this._toast('error', 'Validation', 'Select at least one component to restore.');
                return;
            }
            startGroupRestoreApex({
                restoreType: type,
                groupPayload: JSON.stringify(payload),
                schedulePayload
            }).then(onSuccess).catch(onError);
        }
    }
    _parseRestoreResult(raw) {
        if (!raw) {
            this.isRestoreSubmitting = false;
            this._toast('error', 'Restore Failed', 'No response received from server.');
            return { msg: null, jobId: null };
        }

        try {
            const parsed = JSON.parse(raw);
            if (parsed?.msg) {
                if (parsed.msg.startsWith('ERROR:')) {
                    this.isRestoreSubmitting = false;
                    this._toast('error', 'Restore Failed', parsed.msg.replace('ERROR:', '').trim());
                    return { msg: null, jobId: null };
                }
                return { msg: parsed.msg, jobId: parsed.jobId || null };
            }
        } catch (_) { }

        if (raw.startsWith('ERROR:')) {
            this.isRestoreSubmitting = false;
            this._toast('error', 'Restore Failed', raw.replace('ERROR:', '').trim());
            return { msg: null, jobId: null };
        }

        if (!raw.toLowerCase().includes('restore initiated') &&
            !raw.toLowerCase().includes('restore started') &&
            !raw.toLowerCase().includes('file(s)')) {
            this.isRestoreSubmitting = false;
            this._toast('error', 'Restore Failed', raw || 'An unexpected error occurred.');
            return { msg: null, jobId: null };
        }

        return { msg: raw, jobId: null };
    }
    _startPolling() {
        this._stopPolling();
        this._fetchJobRows();
        this._pollingInterval = setInterval(() => { this._checkJobStatus(); }, 3000);
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
                if (!rows || rows.length === 0) return;
                this.jobRows = rows.map(r => ({
                    ...r,
                    disableCancel: !ACTIVE_JOB_STATUSES.has(r.status)
                }));
            })
            .catch();
    }

    _checkJobStatus() {
        areAllJobsDone({ jobIds: this._activeJobIds })
            .then(done => {
                if (done) {
                    return getBackupJobStatus({ jobIds: this._activeJobIds })
                        .then(rows => {
                            this._stopPolling();

                            if (rows && rows.length > 0) {
                                this.jobRows = rows.map(r => ({
                                    ...r,
                                    disableCancel: !ACTIVE_JOB_STATUSES.has(r.status)
                                }));
                            }

                            const hasFailed = this.jobRows.some(
                                r => r.status === 'Failed' || r.status === 'Aborted'
                            );

                            this.isBackupInProgress = false;
                            this.isRestoreInProgress = false;
                            this._activeJobIds = [];

                            if (hasFailed) {
                                this._toast('error', 'Job Failed',
                                    'One or more jobs completed with errors.');
                            } else {
                                this._toast('success', 'Backup Complete',
                                    'All backup jobs finished successfully.');
                            }
                        });
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
                this._toast('success', 'Job Cancelled', 'Backup job aborted successfully.');
                this._fetchJobRows();
            })
            .catch(error => {
                this._toast('error', 'Error', error.body?.message || 'Failed to abort job');
            });
    }

    get computedDataRecordClass() {
        let base = 'ms-trigger';
        if (this.isDataRecordDropdownOpen) base += ' ms-trigger--open';
        if (this.isDataMultipleObjects || !this.hasDataSelectedObjects) {
            base += ' ms-trigger--disabled';
        }
        if (this.noDataRecordsAvailable) {
            base += ' ms-trigger--disabled disabled-field';
        }
        return base;
    }

    handleRecordClick(event) {
        if (this.noDataRecordsAvailable || !this.hasDataSelectedObjects) {
            event.stopPropagation();
            return;
        }
        this.toggleDataRecordDropdown(event);
    }

    get computedRestoreRecordClass() {
        let base = this.restoreDataRecordTriggerClass;
        if (this.noRestoreDataRecordsAvailable) {
            base += ' disabled-field';
        }
        return base;
    }

    handleRestoreRecordClick(event) {
        if (this.noRestoreDataRecordsAvailable) {
            event.stopPropagation();
            return;
        }
        this.toggleRestoreDataRecordDropdown(event);
    }

    loadOrgFullPanelRecords(objectName) {
        this.isLoadingOrgFullPanelRecords = true;
        this.orgFullPanelRawRecordOptions = [];
        this.orgFullPanelSelectedRecords = [];
        this.orgFullPanelRecordsFetched = false;
        const cacheKey = `records_${objectName}`;
        const cached = this._loaderCache[cacheKey];
        const promise = cached instanceof Array
            ? Promise.resolve(cached)
            : getRecords({ objectName }).then(r => {
                const mapped = r.map(rec => ({ label: rec.Name, value: rec.Id }));
                this._loaderCache[cacheKey] = mapped;
                return mapped;
            });
        promise
            .then(mapped => { this.orgFullPanelRawRecordOptions = mapped; })
            .catch()
            .finally(() => { this.isLoadingOrgFullPanelRecords = false; this.orgFullPanelRecordsFetched = true; });
    }

    toggleOrgFullPanelObjectDropdown(event) {
        event.stopPropagation();
        this.isOrgFullPanelObjectDropdownOpen = !this.isOrgFullPanelObjectDropdownOpen;
        this.isOrgFullPanelRecordDropdownOpen = false;
    }
    handleOrgFullPanelObjectSearch(event) { this.orgFullPanelObjectSearchTerm = event.target.value; }
    handleOrgFullPanelObjectToggle(event) {
        event.stopPropagation();
        const updated = this._toggle(this.orgFullPanelSelectedObjects, event.currentTarget.dataset.value);
        this.orgFullPanelSelectedObjects = updated;
        this.orgFullPanelRawRecordOptions = [];
        this.orgFullPanelSelectedRecords = [];
        this.isOrgFullPanelRecordDropdownOpen = false;
        this.orgFullPanelRecordsFetched = false;
        if (updated.length === 1) this.loadOrgFullPanelRecords(updated[0]);
        this._syncOrgFullDataObjects(updated);
    }
    toggleSelectAllOrgFullPanelObjects(event) {
        event.stopPropagation();
        this.isSelectAllOrgFullPanelObjectsLoading = true;

        requestAnimationFrame(() => {
            requestAnimationFrame(() => {
                const updated = this.isAllOrgFullPanelObjectsSelected
                    ? []
                    : this.rawObjectOptions.map(o => o.value);

                this.orgFullPanelSelectedObjects = updated;
                this.orgFullPanelRawRecordOptions = [];
                this.orgFullPanelSelectedRecords = [];
                this.orgFullPanelRecordsFetched = false;

                const gIdx = this.orgFullState.findIndex(g => g.key === 'data');
                if (gIdx !== -1) {
                    const newState = [...this.orgFullState];
                    const g = { ...newState[gIdx] };
                    g.subs = g.subs.map(s =>
                        s.key !== 'dataObjects' ? s : { ...s, selected: updated, checkboxClicked: true }
                    );
                    newState[gIdx] = g;
                    this.orgFullState = newState;
                }

                this.isSelectAllOrgFullPanelObjectsLoading = false;
            });
        });
    }
    clearOrgFullPanelObjects(event) {
        event.stopPropagation();
        this.orgFullPanelSelectedObjects = [];
        this.orgFullPanelRawRecordOptions = [];
        this.orgFullPanelSelectedRecords = [];
        this.orgFullPanelRecordsFetched = false;
        this._syncOrgFullDataObjects([]);
        this._closeAllDropdowns();
    }
    _syncOrgFullDataObjects(selected) {
        this.orgFullState = this.orgFullState.map(g => g.key !== 'data' ? g : {
            ...g,
            subs: g.subs.map(s => s.key !== 'dataObjects' ? s : { ...s, selected, checkboxClicked: true })
        });
    }

    handleOrgFullPanelRecordClick(event) {
        if (this.noOrgFullPanelRecordsAvailable) { event.stopPropagation(); return; }
        this.toggleOrgFullPanelRecordDropdown(event);
    }
    toggleOrgFullPanelRecordDropdown(event) {
        if (this.isOrgFullPanelMultipleObjects || this.isLoadingOrgFullPanelRecords || !this.hasOrgFullPanelSelectedObjects) return;
        event.stopPropagation();
        this.isOrgFullPanelRecordDropdownOpen = !this.isOrgFullPanelRecordDropdownOpen;
        this.isOrgFullPanelObjectDropdownOpen = false;
    }
    handleOrgFullPanelRecordSearch(event) { this.orgFullPanelRecordSearchTerm = event.target.value; }
    handleOrgFullPanelRecordToggle(event) {
        event.stopPropagation();
        this.orgFullPanelSelectedRecords = this._toggle(this.orgFullPanelSelectedRecords, event.currentTarget.dataset.value);
    }
    toggleSelectAllOrgFullPanelRecords(event) {
        event.stopPropagation();
        this.orgFullPanelSelectedRecords = this.isAllOrgFullPanelRecordsSelected ? [] : this.orgFullPanelRawRecordOptions.map(r => r.value);
    }
    clearOrgFullPanelRecords(event) {
        event.stopPropagation();
        this.orgFullPanelSelectedRecords = [];
        this._closeAllDropdowns();
    }

    loadRestorePanelRecords(objectName) {
        this.isLoadingRestorePanelRecords = true;
        this.restorePanelRawRecordOptions = [];
        this.restorePanelSelectedRecords = [];
        this.restorePanelRecordsFetched = false;
        const cacheKey = `records_${objectName}`;
        const cached = this._loaderCache[cacheKey];
        const promise = cached instanceof Array
            ? Promise.resolve(cached)
            : getRecords({ objectName }).then(r => {
                const mapped = r.map(rec => ({ label: rec.Name, value: rec.Id }));
                this._loaderCache[cacheKey] = mapped;
                return mapped;
            });
        promise
            .then(mapped => { this.restorePanelRawRecordOptions = mapped; })
            .catch()
            .finally(() => { this.isLoadingRestorePanelRecords = false; this.restorePanelRecordsFetched = true; });
    }

    toggleRestorePanelObjectDropdown(event) {
        event.stopPropagation();
        this.isRestorePanelObjectDropdownOpen = !this.isRestorePanelObjectDropdownOpen;
        this.isRestorePanelRecordDropdownOpen = false;
    }
    handleRestorePanelObjectSearch(event) { this.restorePanelObjectSearchTerm = event.target.value; }
    handleRestorePanelObjectToggle(event) {
        event.stopPropagation();
        const updated = this._toggle(this.restorePanelSelectedObjects, event.currentTarget.dataset.value);
        this.restorePanelSelectedObjects = updated;
        this.restorePanelRawRecordOptions = [];
        this.restorePanelSelectedRecords = [];
        this.isRestorePanelRecordDropdownOpen = false;
        this.restorePanelRecordsFetched = false;
        if (updated.length === 1) this.loadRestorePanelRecords(updated[0]);
        this._syncRestoreDataObjects(updated);
    }
    toggleSelectAllRestorePanelObjects(event) {
        event.stopPropagation();
        this.isSelectAllRestorePanelObjectsLoading = true;

        requestAnimationFrame(() => {
            requestAnimationFrame(() => {
                const updated = this.isAllRestorePanelObjectsSelected
                    ? []
                    : this.rawObjectOptions.map(o => o.value);

                this.restorePanelSelectedObjects = updated;
                this.restorePanelRawRecordOptions = [];
                this.restorePanelSelectedRecords = [];
                this.restorePanelRecordsFetched = false;

                const gIdx = this.restoreState.findIndex(g => g.key === 'data');
                if (gIdx !== -1) {
                    const newState = [...this.restoreState];
                    const g = { ...newState[gIdx] };
                    g.subs = g.subs.map(s =>
                        s.key !== 'dataObjects' ? s : { ...s, selected: updated, checkboxClicked: true }
                    );
                    newState[gIdx] = g;
                    this.restoreState = newState;
                }

                this.isSelectAllRestorePanelObjectsLoading = false;
            });
        });
    }
    clearRestorePanelObjects(event) {
        event.stopPropagation();
        this.restorePanelSelectedObjects = [];
        this.restorePanelRawRecordOptions = [];
        this.restorePanelSelectedRecords = [];
        this.restorePanelRecordsFetched = false;
        this._syncRestoreDataObjects([]);
        this._closeAllDropdowns();
    }
    _syncRestoreDataObjects(selected) {
        this.restoreState = this.restoreState.map(g => g.key !== 'data' ? g : {
            ...g,
            subs: g.subs.map(s => s.key !== 'dataObjects' ? s : { ...s, selected, checkboxClicked: true })
        });
    }

    handleRestorePanelRecordClick(event) {
        if (this.noRestorePanelRecordsAvailable) { event.stopPropagation(); return; }
        this.toggleRestorePanelRecordDropdown(event);
    }
    toggleRestorePanelRecordDropdown(event) {
        if (this.isRestorePanelMultipleObjects || this.isLoadingRestorePanelRecords || !this.hasRestorePanelSelectedObjects) return;
        event.stopPropagation();
        this.isRestorePanelRecordDropdownOpen = !this.isRestorePanelRecordDropdownOpen;
        this.isRestorePanelObjectDropdownOpen = false;
    }
    handleRestorePanelRecordSearch(event) { this.restorePanelRecordSearchTerm = event.target.value; }
    handleRestorePanelRecordToggle(event) {
        event.stopPropagation();
        this.restorePanelSelectedRecords = this._toggle(this.restorePanelSelectedRecords, event.currentTarget.dataset.value);
    }
    toggleSelectAllRestorePanelRecords(event) {
        event.stopPropagation();
        this.restorePanelSelectedRecords = this.isAllRestorePanelRecordsSelected ? [] : this.restorePanelRawRecordOptions.map(r => r.value);
    }
    clearRestorePanelRecords(event) {
        event.stopPropagation();
        this.restorePanelSelectedRecords = [];
        this._closeAllDropdowns();
    }
}