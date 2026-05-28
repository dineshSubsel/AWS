import { LightningElement } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';

import AWS_SDK from "@salesforce/resourceUrl/AWSSDK";
import jzZIP from "@salesforce/resourceUrl/jsZIP";
import jsSaver from "@salesforce/resourceUrl/jsSaver";

import fetchMetaListLwc from '@salesforce/apex/AWSFileUploadHandlingControllerForObject.fetchMetaListLwc';

import LightningConfirm from 'lightning/confirm';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AwsBucketBackup extends LightningElement {

    s3;
    bucketname;
    baseurl;

    awsS3MetadataConfMain = {};
    isAwsSdkInitialized = false;

    isSpinner = false;
    isprogress = false;
    iscompleted = false;

    progress = 0;
    totalfile = 0;
    countfile = 0;

    data = [];

    renderedCallback() {

        if (this.isAwsSdkInitialized) {
            return;
        }

        Promise.all([
            loadScript(this, AWS_SDK),
            loadScript(this, jzZIP),
            loadScript(this, jsSaver)
        ])
        .then(() => {
            return fetchMetaListLwc();
        })
        .then(result => {

            if (result) {

                this.awsS3MetadataConfMain = result;

                this.bucketname = result.s3BucketName;

                this.baseurl =
                    'https://' +
                    result.s3BucketName +
                    '.s3.' +
                    result.s3RegionName +
                    '.amazonaws.com/';

                this.initializeAwsSdk(result);
            }

        })
        .catch(error => {

            this.handleShowToastMsgMethod(
                'Error',
                error?.body?.message || error.message,
                'error'
            );
        });
    }

   initializeAwsSdk(confData) {
    const AWS = window.AWS;
    AWS.config.update({
        accessKeyId: confData.awsAccessKeyId,
        secretAccessKey: confData.awsSecretAccessKey
    });
    AWS.config.region = confData.s3RegionName;
    this.s3 = new AWS.S3({
        apiVersion: confData.apiVersion,        
        signatureVersion: confData.signatureVersion,
        params: {
            Bucket: confData.s3BucketName
        }
    });
    this.isAwsSdkInitialized = true;
}

    async genenreateZipfile() {

        try {

            this.data = [];
            this.progress = 0;
            this.countfile = 0;

            this.isSpinner = true;

            await this.listAllObjects();

            this.totalfile = this.data.length;

            if (!this.totalfile) {

                this.isSpinner = false;

                this.handleShowToastMsgMethod(
                    'Info',
                    'No files found in bucket',
                    'info'
                );

                return;
            }

            this.isSpinner = false;

            const result = await LightningConfirm.open({
                message: "Download process takes some time. Continue?",
                variant: "headerless",
                label: "Caution"
            });

            if (!result) {
                return;
            }

            this.isSpinner = true;
            this.isprogress = true;

            let zip = new JSZip();

            const fetchPromises = this.data.map(async file => {

                let key = file.Key['#text'];

                let keysplit = key.split('/');
                let name = keysplit[keysplit.length - 1];

                const presignedGETURL = this.s3.getSignedUrl('getObject', {
                    Bucket: this.bucketname,
                    Key: key,
                    Expires: 3600
                });

                let blob = await fetch(presignedGETURL)
                    .then(response => {

                        if (!response.ok) {
                            throw new Error('Network response was not ok');
                        }

                        return response.blob();
                    });

                if (keysplit.length > 1) {

                    let folders = zip;

                    keysplit.forEach(item => {

                        if (item === name) {

                            folders.file(name, blob);

                        } else {

                            folders = folders.folder(item);
                        }
                    });

                } else {

                    zip.file(name, blob);
                }

                this.countfile++;

                this.progress = (this.countfile / this.totalfile) * 100;

            });

            await Promise.all(fetchPromises);

            let content = await zip.generateAsync({ type: "blob" });

            saveAs(content, this.bucketname + ".zip");

            this.isSpinner = false;
            this.isprogress = false;
            this.iscompleted = true;

            this.handleShowToastMsgMethod(
                'Success',
                'Bucket Backup Downloaded Successfully!',
                'success'
            );

            setTimeout(() => {
                this.iscompleted = false;
            }, 3000);

        } catch (e) {

            this.isprogress = false;
            this.isSpinner = false;

            this.handleShowToastMsgMethod(
                'Error',
                'Problem during download: ' + e.message,
                'error'
            );
        }
    }

    async listAllObjects(ContinuationToken) {

        const s3 = new window.AWS.S3();

        let params = {
            Bucket: this.bucketname,
            MaxKeys: 1000
        };

        if (ContinuationToken) {
            params.ContinuationToken = ContinuationToken;
        }

        const presignedUrl = s3.getSignedUrl('listObjectsV2', params);

        const response = await fetch(presignedUrl);

        if (!response.ok) {
            throw new Error('Network response was not ok');
        }

        let data2;

        if (response.headers.get('content-type').includes('application/json')) {

            data2 = await response.json();

        } else {

            data2 = await response.text();
            data2 = this.parseXml(data2);

            if (Array.isArray(data2.Contents)) {

                this.data = this.data.concat(data2.Contents);

            } else {

                this.data.push(data2.Contents);
            }
        }

        if (JSON.parse(data2.IsTruncated['#text'])) {

            await this.listAllObjects(data2.NextContinuationToken['#text']);
        }
    }

    parseXml(xmlText) {

        const parser = new DOMParser();

        const xml = parser.parseFromString(xmlText, 'text/xml');

        const obj = this.xmlNodeToJson(xml.documentElement);

        return obj;
    }

    xmlNodeToJson(node) {

        let obj = {};

        if (node.nodeType === 1) {

            if (node.attributes.length > 0) {

                obj['@attributes'] = {};

                for (let j = 0; j < node.attributes.length; j++) {

                    const attribute = node.attributes.item(j);

                    obj['@attributes'][attribute.nodeName] = attribute.nodeValue;
                }
            }

        } else if (node.nodeType === 3) {

            obj = node.nodeValue;
        }

        if (node.hasChildNodes()) {

            for (let i = 0; i < node.childNodes.length; i++) {

                const item = node.childNodes.item(i);

                const nodeName = item.nodeName;

                if (typeof obj[nodeName] === 'undefined') {

                    obj[nodeName] = this.xmlNodeToJson(item);

                } else {

                    if (typeof obj[nodeName].push === 'undefined') {

                        const old = obj[nodeName];

                        obj[nodeName] = [];

                        obj[nodeName].push(old);
                    }

                    obj[nodeName].push(this.xmlNodeToJson(item));
                }
            }
        }

        return obj;
    }

    handleShowToastMsgMethod(titleStr, msgStr, variantStr) {

        this.dispatchEvent(
            new ShowToastEvent({
                title: titleStr,
                message: msgStr,
                variant: variantStr
            })
        );
    }
}