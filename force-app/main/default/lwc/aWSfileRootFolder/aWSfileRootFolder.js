import { LightningElement, track, api, wire } from 'lwc';
import addFolderBelowParent from '@salesforce/apex/folderController.addFolder';
import getAWSFiles from '@salesforce/apex/AWSFileUploadHandlingController.getAWSFiles';//
import getTreeData from '@salesforce/apex/folderController.getfoldertree';


export default class AWSfileRootFolder extends LightningElement {
    showModal = false;
    @api folderId;
    folderData
    selectedLabel;
    inputFolder;
    parentname;
    @track items;
    customId;
    type;
    showFile = false;
    showComp = false;
    tempFolder='';
    primaryFolders=[];

    connectedCallback() {
        this.treebuild();
        this.showComp = true;
    }

    treebuild() {
        getTreeData({
            parentid:null,
            type:null
        })
            .then(result => {
                this.items = result;
                this.primaryFolders = result.map(folder => ({
    label: folder.label,
    name: folder.name,
    type: folder.type
}));

            })
            .catch(error => {
            });

    }
    handleRecordInserted() {
        this.componentVisibleFunction();
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
            .then((result) => {
                this.parentname = '';
                this.inputFolder = '';
                this.handleCloseModal();

            })
            .catch((error) => {
            });
    }
    valuegetting(event) {
        this.inputFolder = event.target.value;
    }



    handleOnselect(event) {
    
        this.folderId = event.detail.name;
        this.tempFolder= this.folderId;
        this.templeteVisibleFunction();
        this.selectedLabel = this.findLabelByName(this.items,  this.folderId);
    }

    findLabelByName(items, name) {
        for (const item of items) {
            if (item.name === name) {
                this.type=item.type;
                return item.label;
            } else if (item.items) {
                const nestedLabel = this.findLabelByName(item.items, name);
                if (nestedLabel) {
                    return nestedLabel;
                }
            }
        }
        return null;
    }


    getUploadedFiles() {

        this.dataTable = [];
        getAWSFiles({
            parentId: this.folderId
        })
            .then(data => {

                this.dataTable = data;
                let result = data;
            }
            )
            .catch((error) => {
                this.handleShowToastMsgMethod('Review the display Records', error.message, 'error');
            });

    }

    templeteVisibleFunction() {
        if (this.showFile === false) {
            this.showFile = true;
        } else {
            this.showFile = false;

            setTimeout(() => {
                this.showFile = true;

            }, 100);

        }
    }
    componentVisibleFunction() {
        if (this.showComp === false) {
            this.showComp = true;
        } else {
            this.showComp = false;
            setTimeout(() => {
                this.showComp = true;
            }, 100);

        }
    }
    
    handleChildEvent(event) {
        const folderParentId = event.detail.folderParentId;
        this.folderId = folderParentId;
        this.templeteVisibleFunction();
    }
    handelBackEvent(event)
    {
        const folderParentId = event.detail.folderParentId;
        const isPrimary =  this.primaryFolders.some(folder => folder.name === folderParentId);
        if(isPrimary){
            this.folderId = this.tempFolder;
        this.templeteVisibleFunction();
        }


    }

}