import { LightningElement, track, api, wire } from 'lwc';
import addFolderBelowParent from '@salesforce/apex/folderController.addFolder';
import getAWSFiles from '@salesforce/apex/AWSFileUploadHandlingController.getAWSFiles';
import getTreeData from '@salesforce/apex/folderController.getfoldertree';

export default class AWSfileRootFolder extends LightningElement {
    showModal = false;
    @api folderId;
    selectedLabel;
    inputFolder;
    parentname;
    @track items = [];
    type;
    showFile = false;
    showComp = false;
    primaryFolders = [];
    @track navStack = [];
    @track selectedItem = '';


    connectedCallback() {
        this.treebuild();
        this.showComp = true;
    }

    treebuild() {
    getTreeData({ parentid: null, type: null })
        .then(result => {

            const orderMap = {
                'Public Folder': 1,
                'Private Folder': 2,        
                'Shared with Me': 3
            };

            result.sort((a, b) => {
                return (orderMap[a.label] || 99) - (orderMap[b.label] || 99);
            });

            this.items = this.addIcons(result);

            this.primaryFolders = result.map(folder => ({
                label: folder.label,
                name: folder.name,
                type: folder.type
            }));
        })
        .catch(error => {
        });
}

    addIcons(nodes) {
    if (!Array.isArray(nodes)) return [];
    return nodes.map(node => ({
        ...node,
        label: `📂 ${node.label || ''}`,
        items: (node.items && node.items.length > 0) ? this.addIcons(node.items) : undefined
    }));
}


handleOnselect(event) {
    const selectedName = event.detail.name;
    this.selectedLabel = (this.findLabelByName(this.items, selectedName) || '').replace('📂 ', '').trim();
    this.type = this.findTypeByName(this.items, selectedName);
    this.navStack = [];
    this.folderId = selectedName;
    this.selectedItem = selectedName;

    this.showFile = false;
    setTimeout(() => {
        this.showFile = true;
        this.selectedItem = '';  
    }, 0);
}

    findAncestors(items, targetName, path) {
        for (const item of items) {
            if (item.name === targetName) {
                return path;
            }
            if (item.items && item.items.length > 0) {
                const result = this.findAncestors(
                    item.items,
                    targetName,
                    [...path, item.name]
                );
                if (result !== null) return result;
            }
        }
        return null;
    }

    findLabelByName(items, name) {
        for (const item of items) {
            if (item.name === name) return item.label;
            if (item.items) {
                const found = this.findLabelByName(item.items, name);
                if (found) return found;
            }
        }
        return null;
    }

    findTypeByName(items, name) {
        for (const item of items) {
            if (item.name === name) return item.type;
            if (item.items) {
                const found = this.findTypeByName(item.items, name);
                if (found) return found;
            }
        }
        return null;
    }

    handelBackEvent(event) {
        const backFolderId = event.detail.folderParentId;
        this.folderId = backFolderId;
        this.selectedLabel = this.findLabelByName(this.items, backFolderId);
        this.type = this.findTypeByName(this.items, backFolderId);

        if (this.navStack.length > 0) {
            this.navStack = this.navStack.slice(0, -1);
        }

    }

    handleChildEvent(event) {
        const folderParentId = event.detail.folderParentId;
        if (this.folderId) {
            this.navStack = [...this.navStack, this.folderId];
        }
        this.folderId = folderParentId;
        this.showFile = true;
    }
    handleCallParentMethod(event) {
        const detail = event.detail;
        if (detail && detail.refreshTree) {
            this.treebuild();
            const childComp = this.template.querySelector('c-subsel-s3-file-display');
            if (childComp) {
                childComp.refreshDisplay();
            }
        }
    }

    handleRecordInserted() {
        this.showComp = false;
        setTimeout(() => { this.showComp = true; }, 100);
    }

    valuegetting(event) {
        this.inputFolder = event.target.value;
    }

    handleButtonClick(event) {
        this.parentname = event.target.closest('lightning-accordion-section').name;
        this.showModal = true;
    }

    handleCloseModal() {
        this.showModal = false;
    }

    handleModalSubmit() {
        addFolderBelowParent({ parentName: this.parentname, folderName: this.inputFolder })
            .then(() => {
                this.parentname = '';
                this.inputFolder = '';
                this.handleCloseModal();
            })
            .catch();
    }
}