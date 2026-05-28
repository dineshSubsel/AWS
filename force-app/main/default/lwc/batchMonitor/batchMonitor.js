import { LightningElement, track } from 'lwc';
import getActiveBatchJobs from '@salesforce/apex/FileRecoveryVaultController.getActiveBatchJobs';

export default class BatchMonitor extends LightningElement {
    @track jobs = [];
    @track isLoading = false;
    @track activeTab = 'all';

    tabs = [
        { label: 'All',        value: 'all'        },
        { label: 'Processing', value: 'Processing'  },
        { label: 'Completed',  value: 'Completed'   },
        { label: 'Failed',     value: 'Failed'      },
    ];

    connectedCallback() {
        this.load();
        // Auto-refresh every 10 s while component is alive
        this._interval = setInterval(() => this.load(), 10000);
    }

    disconnectedCallback() {
        clearInterval(this._interval);
    }

    load() {
        this.isLoading = true;
        getActiveBatchJobs()
            .then(data => { this.jobs = data; })
            .catch(err  => console.error(err))
            .finally(() => { this.isLoading = false; });
    }

    get filteredJobs() {
        if (this.activeTab === 'all') return this.jobs;
        return this.jobs.filter(j => j.status === this.activeTab);
    }

    handleTab(e) { this.activeTab = e.currentTarget.dataset.value; }
}