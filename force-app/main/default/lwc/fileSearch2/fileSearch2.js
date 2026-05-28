import { LightningElement, track } from 'lwc';
import getRecentFiles from '@salesforce/apex/fileSearchController.getRecentlyUploadedfile';
import getSearchedFiles from '@salesforce/apex/fileSearchController.getSearchedFile';
import getFilteredFiles from '@salesforce/apex/fileSearchController.filterfile';
import getParentNames from '@salesforce/apex/fileSearchController.getParentNameOptions';
import getFilterFields from '@salesforce/apex/fileSearchController.getFilterFields';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// ── Constants ────────────────────────────────────────────────────────────────
const PAGE_SIZE = 10;

const FILTER_TYPE = {
    OBJECT_NAME: 'objectName',
    FILE_TYPE: 'fileType',
    CREATED_DATE: 'createdDate',
};

const FILE_TYPE_MAP = {
    'image/jpeg': ['JPEG', 'file-type-jpeg'],
    'image/jpg': ['JPEG', 'file-type-jpeg'],
    'image/png': ['PNG', 'file-type-png'],
    'image/gif': ['GIF', 'file-type-gif'],
    'image/webp': ['WEBP', 'file-type-gif'],
    'image/svg+xml': ['SVG', 'file-type-gif'],
    'image/bmp': ['BMP', 'file-type-gif'],
    'application/pdf': ['PDF', 'file-type-pdf'],
    'text/plain': ['TXT', 'file-type-txt'],
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': ['XLSX', 'file-type-xlsx'],
    'text/csv': ['CSV', 'file-type-xlsx'],
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document': ['DOCX', 'file-type-word'],
    'application/msword': ['DOC', 'file-type-word'],
    'application/x-zip-compressed': ['ZIP', 'file-type-zip'],
    'application/zip': ['ZIP', 'file-type-zip'],
    'application/vnd.ms-powerpoint': ['PPT', 'file-type-ppt'],
    'application/vnd.openxmlformats-officedocument.presentationml.presentation': ['PPTX', 'file-type-ppt'],
};

const FILE_EXT_MAP = {
    'jpg': ['JPEG', 'file-type-jpeg'],
    'jpeg': ['JPEG', 'file-type-jpeg'],
    'png': ['PNG', 'file-type-png'],
    'gif': ['GIF', 'file-type-gif'],
    'webp': ['WEBP', 'file-type-gif'],
    'svg': ['SVG', 'file-type-gif'],
    'bmp': ['BMP', 'file-type-gif'],
    'pdf': ['PDF', 'file-type-pdf'],
    'txt': ['TXT', 'file-type-txt'],
    'xlsx': ['XLSX', 'file-type-xlsx'],
    'xls': ['XLS', 'file-type-xlsx'],
    'csv': ['CSV', 'file-type-xlsx'],
    'docx': ['DOCX', 'file-type-word'],
    'doc': ['DOC', 'file-type-word'],
    'zip': ['ZIP', 'file-type-zip'],
    'pptx': ['PPTX', 'file-type-ppt'],
    'ppt': ['PPT', 'file-type-ppt'],
};

// ── Component ─────────────────────────────────────────────────────────────────
export default class FileSearch extends LightningElement {

    // ── Pagination ────────────────────────────────────────────────────────────
    pageSize = PAGE_SIZE;
    pageNumber = 1;
    totalPages = 0;
    totalRecords = 0;
    recordStart = 0;
    recordEnd = 0;
    isPrev = true;
    isNext = true;

    // ── Search & Filter State ─────────────────────────────────────────────────
    searchTerm = '';
    selectedFilterKey = '';
    operator = '';
    filterValue = '';
    filterKey = 0;
    showfilter = false;
    @track hasValidationError = false;

    // ── UI State ──────────────────────────────────────────────────────────────
    spinner = false;
    isdataTable = false;
    showModal = false;
    downloadPopup = false;
    dataTable = [];
    selectedfile = null;
    url = null;
    urlerror = '';
    fileName = '';
    fileSize = '';
    progress = 0;

    // ── Lookup Data ───────────────────────────────────────────────────────────
    parentNameOptions = [];
    _parentLabelMap = {};
    _filterFieldsMeta = [];

    // ═══════════════════════════════════════════════════════════════════════════
    // Lifecycle
    // ═══════════════════════════════════════════════════════════════════════════

    connectedCallback() {
        this.getRecent();
        this.loadParentNameOptions();
        this.loadFilterFields();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Getters — Button Visibility
    // ═══════════════════════════════════════════════════════════════════════════

    get showFilterBtn() {
        return !this.showfilter;
    }

    get showRemoveBtn() {
        return this.showfilter;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Getters — Filter Type Detection
    // ═══════════════════════════════════════════════════════════════════════════

    get isObjectName() { return this.selectedFilterKey === FILTER_TYPE.OBJECT_NAME; }
    get isFileType() { return this.selectedFilterKey === FILTER_TYPE.FILE_TYPE; }
    get isCreatedDate() { return this.selectedFilterKey === FILTER_TYPE.CREATED_DATE; }

    // ═══════════════════════════════════════════════════════════════════════════
    // Getters — Dropdown Options
    // ═══════════════════════════════════════════════════════════════════════════

    get filterNameOptions() {
        return [
            { label: 'Object Name', value: FILTER_TYPE.OBJECT_NAME },
            { label: 'File Type', value: FILTER_TYPE.FILE_TYPE },
            { label: 'Created Date', value: FILTER_TYPE.CREATED_DATE },
        ];
    }

    get operatorOptions() {
        return [
            { label: 'Equals', value: 'equal' },
            { label: 'Not Equals', value: 'notequal' },
        ];
    }

    get typeOptions() {
        return [
            { label: 'Image', value: 'IMAGE_GROUP' },  // ← changed
            { label: 'Text', value: 'text/plain' },
            { label: 'PDF', value: 'application/pdf' },
            { label: 'Document', value: 'application/msword' },
            { label: 'XLSheet', value: 'text/csv' },
            { label: 'PowerPoint', value: 'application/vnd.ms-powerpoint' },
            { label: 'Zip', value: 'application/x-zip-compressed' },
        ];
    }

    /** Disable Clear only when no filter is selected */
    get isClearDisabled() {
        return !this.selectedFilterKey;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Data Loading
    // ═══════════════════════════════════════════════════════════════════════════

    loadParentNameOptions() {
        getParentNames()
            .then(result => {
                const raw = typeof result === 'string' ? JSON.parse(result) : result;
                this.parentNameOptions = raw.map(f => ({ label: f.label, value: f.value }));
                this._parentLabelMap = this.parentNameOptions.reduce((acc, opt) => {
                    acc[opt.value] = opt.label;
                    return acc;
                }, {});
                this._relabelDataTable();
            })
            .catch(() => { });
    }

    loadFilterFields() {
        getFilterFields()
            .then(result => {
                this._filterFieldsMeta = typeof result === 'string' ? JSON.parse(result) : result;
            })
            .catch(() => { });
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Search Handlers
    // ═══════════════════════════════════════════════════════════════════════════

    searchval(event) {
        this.searchTerm = event.detail.value;
        this.pageNumber = 1;
        this.spinner = true;
        this.isdataTable = false;

        if (!this.searchTerm) {
            this.getRecent();
        } else {
            this.searchFile(this.searchTerm);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Filter Panel Handlers
    // ═══════════════════════════════════════════════════════════════════════════

    addfilter() {
        if (this.showfilter) {
            this.showfilter = false;
            this.resetFilter();
            this.reloadCurrentData();
        } else {
            if (!this.searchTerm) {
                this.showToast('Error', 'Please Enter a File Name First', 'error');
                return;
            }
            this.showfilter = true;
        }
    }

    handleChangefilter(event) {
        this.selectedFilterKey = event.detail.value;
        this.operator = '';
        this.filterValue = '';
    }

    handleChangeoperator(event) {
        this.operator = event.detail.value;
    }

    get todayDate() {
        return new Date().toISOString().split('T')[0];
    }

    get isApplyDisabled() {
        return this.hasValidationError
            || !this.selectedFilterKey
            || !this.operator
            || !this.filterValue;
    }

    valuechange(event) {
        const input = event.target;
        const val = event.detail.value || input.value || '';

        if (this.isCreatedDate && val && val > this.todayDate) {
            input.setCustomValidity('Future dates are not allowed');
            input.reportValidity();
            this.filterValue = '';
            this.hasValidationError = true;
            return;
        }

        input.setCustomValidity('');
        input.reportValidity();
        this.hasValidationError = false;
        this.filterValue = val;
    }

    handlefilterClick() {
        if (this.hasValidationError) return;

        this.pageNumber = 1;
        this.spinner = true;
        this.isdataTable = false;
        this.fetchFiltered(
            this.searchTerm,
            this.selectedFilterKey,
            this.operator,
            this.filterValue
        );
    }

    handleClearClick() {
        this.resetFilter();
        this.pageNumber = 1;
        this.showfilter = false;
        setTimeout(() => { this.showfilter = true; }, 0);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Pagination Handlers
    // ═══════════════════════════════════════════════════════════════════════════

    handlePagePrevAction() {
        if (this.pageNumber > 1) {
            this.pageNumber--;
            this.loadPage();
        }
    }

    handlePageNextAction() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber++;
            this.loadPage();
        }
    }

    loadPage() {
        this.spinner = true;
        if (this.isFilterActive()) {
            this.fetchFiltered(
                this.searchTerm,
                this.selectedFilterKey,
                this.operator,
                this.filterValue
            );
        } else if (this.searchTerm) {
            this.searchFile(this.searchTerm);
        } else {
            this.getRecent();
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Modal Handlers
    // ═══════════════════════════════════════════════════════════════════════════

    handleRowClick(event) {
        const fileId = event.currentTarget.dataset.id;
        this.selectedfile = this.dataTable.find(f => f.id === fileId);
        if (this.selectedfile) {
            this.url = this.selectedfile.fileUrl || null;
            this.urlerror = this.url ? '' : 'Preview not available for this file type.';
            this.showModal = true;
        }
    }

    handleCloseModal() {
        this.showModal = false;
        this.selectedfile = null;
        this.url = null;
    }

    handleDownloadClick() {
        if (!this.selectedfile) return;
        this.fileName = this.selectedfile.fileName;
        this.fileSize = this.selectedfile.formattedSize;
        this.progress = 0;
        this.downloadPopup = true;
        this._simulateDownload();
    }

    _simulateDownload() {
        const interval = setInterval(() => {
            this.progress += 10;
            if (this.progress >= 100) {
                clearInterval(interval);
                setTimeout(() => { this.downloadPopup = false; }, 800);
            }
        }, 200);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Apex Calls
    // ═══════════════════════════════════════════════════════════════════════════

    getRecent() {
        this.spinner = true;
        this.isdataTable = false;
        getRecentFiles({ pageSize: this.pageSize, pageNumber: this.pageNumber })
            .then(r => this.processResult(r))
            .catch(() => { this.spinner = false; });
    }

    searchFile(searchTerm) {
        const t = (searchTerm || '').trim();
        if (!t) { this.getRecent(); return; }
        getSearchedFiles({ searchName: t, pageSize: this.pageSize, pageNumber: this.pageNumber })
            .then(r => this.processResult(r))
            .catch(() => { this.spinner = false; });
    }

    fetchFiltered(searchTerm, filterKey, operator, value) {
        getFilteredFiles({
            searchname: searchTerm,
            filter: filterKey,
            operator: operator,
            value: value,
            pageSize: this.pageSize,
            pageNumber: this.pageNumber,
        })
            .then(r => this.processResult(r))
            .catch(() => { this.spinner = false; });
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Result Processing
    // ═══════════════════════════════════════════════════════════════════════════

    processResult(result) {
        const d = JSON.parse(result);

        this.totalRecords = d.totalRecords;
        this.recordStart = d.recordStart;
        this.recordEnd = d.recordEnd;
        this.pageNumber = d.pageNumber;
        this.totalPages = Math.max(Math.ceil(this.totalRecords / this.pageSize), 1);
        this.isPrev = this.pageNumber <= 1;
        this.isNext = this.pageNumber >= this.totalPages;

        const records = d.uploadedfile || [];
        this.dataTable = records.map(rec => {
            const { label: fileTypeLabel, cssClass: fileTypeBoxClass } =
                this._resolveFileType(rec.fileType, rec.name);
            return {
                id: rec.id,
                fileName: rec.name,
                fileTypeLabel,
                fileTypeBoxClass,
                formattedDate: this._formatDate(rec.createdDate),
                formattedSize: this._formatFileSize(rec.fileSize),
                uploadedBy: rec.uploadedBy,
                parentObjectLabel: this._resolveParentLabel(rec.parentName),
                _parentRawName: rec.parentName,
                parentRecordId: rec.parentRecordId,
                fileUrl: rec.fileURL,
            };
        });

        this.isdataTable = records.length > 0;
        this.spinner = false;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Helpers
    // ═══════════════════════════════════════════════════════════════════════════

    isFilterActive() {
        return !!(this.selectedFilterKey && this.operator && this.filterValue);
    }

    reloadCurrentData() {
        this.pageNumber = 1;
        this.spinner = true;
        if (this.searchTerm) {
            this.searchFile(this.searchTerm);
        } else {
            this.getRecent();
        }
    }

    resetFilter() {
        this.selectedFilterKey = '';
        this.operator = '';
        this.filterValue = '';
        this.filterKey++;
    }

    _resolveFileType(mimeType, fileName) {
        if (mimeType && FILE_TYPE_MAP[mimeType]) {
            const [label, cls] = FILE_TYPE_MAP[mimeType];
            return { label, cssClass: `file-type-box ${cls}` };
        }

        if (fileName) {
            const ext = fileName.split('.').pop().toLowerCase();
            if (ext && FILE_EXT_MAP[ext]) {
                const [label, cls] = FILE_EXT_MAP[ext];
                return { label, cssClass: `file-type-box ${cls}` };
            }
            if (ext && ext.length <= 5) {
                return { label: ext.toUpperCase(), cssClass: 'file-type-box file-type-dll' };
            }
        }

        if (mimeType && mimeType.startsWith('image/')) {
            const ext = mimeType.split('/').pop().toUpperCase();
            return { label: ext, cssClass: 'file-type-box file-type-jpeg' };
        }

        return { label: 'FILE', cssClass: 'file-type-box file-type-dll' };
    }

    _formatFileSize(bytes) {
        const n = parseInt(bytes, 10) || 0;
        if (n < 1024) return `${n} B`;
        if (n < 1_048_576) return `${(n / 1024).toFixed(2)} KB`;
        if (n < 1_073_741_824) return `${(n / 1_048_576).toFixed(2)} MB`;
        return `${(n / 1_073_741_824).toFixed(2)} GB`;
    }

    _formatDate(rawDate) {
        return rawDate ? new Date(rawDate).toLocaleDateString() : '';
    }

    _resolveParentLabel(apiName) {
        if (!apiName) return '-';
        return this._parentLabelMap[apiName] || apiName;
    }

    _relabelDataTable() {
        if (!this.dataTable?.length) return;
        this.dataTable = this.dataTable.map(row => ({
            ...row,
            parentObjectLabel: this._resolveParentLabel(row._parentRawName),
        }));
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}