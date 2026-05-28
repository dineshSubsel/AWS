import { LightningElement, api } from 'lwc';
import getFilesForAccount from '@salesforce/apex/FiletransferSFtoAWS.getFiles';
import uploadSingleFile from '@salesforce/apex/FiletransferSFtoAWS.uploadSingleFile';
import getObjectType from '@salesforce/apex/FiletransferSFtoAWS.getObjectType';
import deleteSingleFile from '@salesforce/apex/FiletransferSFtoAWS.deleteSingleFile';

const COLUMNS = [
    { 
        label: 'Name', 
        fieldName: 'name', 
        type: 'text',
        hideDefaultActions: true   
    },
    { 
        label: 'Size', 
        fieldName: 'size', 
        type: 'text', 
        fixedWidth: 100,
        hideDefaultActions: true
    },
    {
        label: 'Status',
        fieldName: 'status',
        type: 'text',
        fixedWidth: 110,
        cellAttributes: { class: { fieldName: 'statusClass' } },
        hideDefaultActions: true
    },
    { 
        label: 'Progress', 
        fieldName: 'progressLabel', 
        type: 'text', 
        fixedWidth: 100,
        hideDefaultActions: true
    },
    {
        label: 'Action',
        type: 'action',
        fixedWidth: 60,
        typeAttributes: {
            rowActions: { fieldName: 'rowActions' },
            menuAlignment: 'auto'
        },
        hideDefaultActions: true
    }
];

export default class UploadSalesforceFiles extends LightningElement {

    @api recordId;

    files = [];
    columns = COLUMNS;

    showUploadSection = false;
    isUploading = false;
    hasFilesInRecord = false; // ✅ NEW

    objectType;
    error;

    skipAll = false;
    skipIndexSet = new Set();
    abortUpload = false;

    /* --------------------------
       connectedCallback - files count check
    -------------------------- */

    async connectedCallback() {
        try {
            const result = await getFilesForAccount({ accountId: this.recordId });
            this.hasFilesInRecord = result && result.length > 0; // ✅ files இருந்தா true
        } catch (err) {
            this.hasFilesInRecord = false;
        }
    }

    /* --------------------------
       Load / Toggle Files
    -------------------------- */

    async handleLoadFiles() {
        this.showUploadSection = !this.showUploadSection;

        if (!this.showUploadSection) return;

        try {
            this.objectType = await getObjectType({ recordId: this.recordId });
            const result = await getFilesForAccount({ accountId: this.recordId });

            this.files = result.map((file, index) => ({
                ...file,
                index,
                progress: 0,
                progressLabel: '—',
                status: 'Pending',
                statusClass: 'slds-text-color_weak',
                rowActions: this.getRowActions('Pending')
            }));

            this.error = null;

        } catch (err) {
            this.error = err.body?.message || 'Error loading files';
        }
    }

    get uploadButtonLabel() {
        return this.showUploadSection ? 'Close Files' : 'Upload Files';
    }

    /* --------------------------
       Row Actions
    -------------------------- */

   getRowActions(status) {
    return [
        {
            label: 'Upload',
            name: 'upload',
            iconName: 'utility:upload',
            disabled: status === 'Uploading' || status === 'Completed'
        },
        {
            label: 'Skip',
            name: 'skip',
            iconName: 'utility:skip',
            disabled: status === 'Completed' || status === 'Skipped'
        },
        {
            label: 'Delete',      
            name: 'delete',
            iconName: 'utility:delete',
            disabled: status === 'Uploading'
        }
    ];
}
 async handleRowAction(event) {
    const action = event.detail.action.name;
    const index = event.detail.row.index;

    if (action === 'upload') {
        this.skipIndexSet.delete(index);
        this.skipAll = false;
        this.abortUpload = false;
        this.uploadFileAtIndex(index);
    }

    if (action === 'skip') {
        this.skipIndexSet.add(index);
        this.updateFile(index, 'Skipped');
    }

   if (action === 'delete') {
    const file = this.files[index];

    try {
        await deleteSingleFile({
            recordId: this.recordId,
            fileName: file.name
        });
        this.files = this.files
            .filter(f => f.index !== index)
            .map((f, i) => ({ ...f, index: i }));

    } catch (e) {
        this.error = e.body?.message || 'Failed to delete file';
    }
}
}

    /* --------------------------
       Upload Single File
    -------------------------- */

    async uploadFileAtIndex(index) {

        const file = this.files[index];
        if (['Uploading', 'Completed'].includes(file.status)) return;

        this.updateFile(index, 'Uploading', 0);

        const reason = await this.animateProgress(index);

        if (reason === 'aborted') {
            this.updateFile(index, 'Aborted');
            return;
        }

        if (reason === 'skipped') {
            this.updateFile(index, 'Skipped');
            return;
        }

        try {
            await uploadSingleFile({
                objectType: this.objectType,
                recordId: this.recordId,
                fileName: file.name
            });

            this.updateFile(index, 'Completed', 100);

        } catch (e) {
            this.updateFile(index, 'Failed');
        }
    }

 

    async handleUploadAll() {

        if (this.isUploading) return;

        this.isUploading = true;
        this.abortUpload = false;
        this.skipAll = false;
        this.skipIndexSet.clear();

        for (let i = 0; i < this.files.length; i++) {

            if (this.abortUpload) break;

            if (this.files[i].status === 'Completed') continue;

            await this.uploadFileAtIndex(i);

            if (this.abortUpload) break;
        }

        this.isUploading = false;
    }

    handleSkipAll() {

        this.skipAll = true;

        this.files = this.files.map((f, i) => {
            if (f.status === 'Completed') return f;

            this.skipIndexSet.add(i);

            return {
                ...f,
                status: 'Skipped',
                progress: 0,
                progressLabel: '—',
                statusClass: 'slds-text-color_weak',
                rowActions: this.getRowActions('Skipped')
            };
        });
    }

    handleAbort() {
        this.abortUpload = true;

        this.files = this.files.map(f => {
            if (f.status === 'Completed') return f;

            return {
                ...f,
                status: 'Aborted',
                progress: 0,
                progressLabel: '—',
                statusClass: 'slds-text-color_error',
                rowActions: this.getRowActions('Aborted')
            };
        });

        this.isUploading = false;
    }

    animateProgress(index) {
        return new Promise(resolve => {
            let progress = 0;

            const interval = setInterval(() => {
                if (this.abortUpload) {
                    clearInterval(interval);
                    resolve('aborted');
                    return;
                }

                if (this.skipAll || this.skipIndexSet.has(index)) {
                    clearInterval(interval);
                    resolve('skipped');
                    return;
                }

                if (progress >= 90) {
                    clearInterval(interval);
                    resolve('done');
                    return;
                }

                progress += 5;
                const file = this.files[index];
                file.progress = progress;
                file.progressLabel = `${progress}%`;
                this.files = [...this.files];

            }, 80);
        });
    }

    updateFile(index, status, progress = null) {

        const file = this.files[index];
        file.status = status;

        if (progress !== null) {
            file.progress = progress;
            file.progressLabel = `${progress}%`;
        } else {
            file.progress = 0;
            file.progressLabel = '—';
        }

        file.statusClass = this.getStatusClass(status);
        file.rowActions = this.getRowActions(status);

        this.files = [...this.files];
    }

    getStatusClass(status) {
        if (status === 'Completed') return 'slds-text-color_success';
        if (status === 'Failed')    return 'slds-text-color_error';
        if (status === 'Uploading') return 'slds-text-color_default';
        if (status === 'Aborted')   return 'slds-text-color_error';
        return 'slds-text-color_weak';
    }

   

    handleMenuSelect(event) {
        if (event.detail.value === 'deleteAll') {
            this.files = [];
        }
    }

   

    get hasFiles() {
        return this.files.length > 0;
    }

    get isUploadButtonDisabled() {
        return !this.hasFilesInRecord;
    }

    get isUploadDisabled() {
        if (!this.hasFiles) return true;
        if (this.isUploading) return true;
        return !this.files.some(f =>
            ['Pending', 'Failed', 'Aborted', 'Skipped'].includes(f.status)
        );
    }

    get isSkipDisabled() {
        if (!this.hasFiles) return true;
        return !this.isUploading;
    }

    get isAbortDisabled() {
        if (!this.hasFiles) return true;
        return !this.isUploading;
    }

    get isDeleteAllDisabled() {
        return !this.showUploadSection || !this.hasFiles;
    }
}