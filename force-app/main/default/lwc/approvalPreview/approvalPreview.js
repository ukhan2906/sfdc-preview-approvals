/*
import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import runPreview from '@salesforce/apex/ApprovalPreviewControllerLWC.runPreview';
import submitForApproval from '@salesforce/apex/ApprovalPreviewControllerLWC.submitForApproval';

export default class ApprovalPreview extends LightningElement {
    recordId;
    approvalProcess;
    errorMessage;
    stepsForComments;
    alreadySubmitted = false;
    isLoading = false;

    columns = [
        { label: 'Step Number', fieldName: 'stepNumber', type: 'number' },
        { label: 'Step Name', fieldName: 'stepName', type: 'text' },
        { label: 'Approver', fieldName: 'approver', type: 'text' }
    ];

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.recordId = currentPageReference.state.recordId;
        }
    }

    connectedCallback() {
        this.loadPreview();
    }

    loadPreview() {
        this.isLoading = true;
        runPreview({ objectId: this.recordId })
            .then(result => {
                if (result) {
                    this.approvalProcess = result.ap;
                    this.stepsForComments = result.stepsForComments;
                    // If alreadySubmitted is true, we disable the submit button.
                    this.alreadySubmitted = result.alreadySubmitted;
                    // Clear errorMessage if alreadySubmitted
                    if (this.alreadySubmitted) {
                        this.errorMessage = null;
                    } else {
                        this.errorMessage = result.apEmpty || result.pendingPI || null;
                    }
                }
            })
            .catch(error => {
                this.errorMessage = error.body.message;
                this.approvalProcess = null;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    get isSubmitDisabled() {
        // Disable submit button if there is no approval process or if already submitted
        return !this.approvalProcess || this.alreadySubmitted;
    }

    handleSubmit() {
        if (confirm('Once you submit this record for approval, you might not be able to edit it or recall it from the approval process depending on your settings. Continue?')) {
            this.isLoading = true;
            submitForApproval({ 
                objectId: this.recordId, 
                stepsForComments: JSON.stringify(this.stepsForComments) 
            })
                .then(result => {
                    if (result) {
                        window.location.href = `/${this.recordId}`;
                    }
                })
                .catch(error => {
                    this.errorMessage = error.body.message;
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }
    }

    handleGoBack() {
        window.location.href = `/${this.recordId}`;
    }
}
*/

import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import runPreview from '@salesforce/apex/ApprovalPreviewControllerLWC.runPreview';
import submitForApproval from '@salesforce/apex/ApprovalPreviewControllerLWC.submitForApproval';

export default class ApprovalPreview extends LightningElement {
    recordId;
    @track approvalProcess;
    errorMessage;
    stepsForComments;
    alreadySubmitted = false;
    isLoading = false;

    columnsWithoutStatus = [
        { label: 'Step Number', fieldName: 'stepNumber', type: 'number' },
        { label: 'Step Name', fieldName: 'stepName', type: 'text' },
        { label: 'Approver', fieldName: 'approver', type: 'text' }
    ];

    columnsWithStatus = [
        { label: 'Step Number', fieldName: 'stepNumber', type: 'number' },
        { label: 'Step Name', fieldName: 'stepName', type: 'text' },
        { 
            label: 'Status', 
            fieldName: 'status', 
            type: 'text',
            cellAttributes: {
                class: { fieldName: 'statusClass' }
            }
        },
        { label: 'Approver', fieldName: 'approver', type: 'text' }
    ];

    get columns() {
        return this.alreadySubmitted ? this.columnsWithStatus : this.columnsWithoutStatus;
    }

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.recordId = currentPageReference.state.recordId;
        }
    }

    connectedCallback() {
        this.loadPreview();
    }

    loadPreview() {
        this.isLoading = true;
        runPreview({ objectId: this.recordId })
            .then(result => {
                if (result && result.ap) {
                    this.approvalProcess = result.ap;
                    this.stepsForComments = result.stepsForComments;
                    this.alreadySubmitted = result.alreadySubmitted;
                    
                    if (this.alreadySubmitted && this.approvalProcess.approvalSteps) {
                        this.approvalProcess.approvalSteps = this.approvalProcess.approvalSteps.map(step => ({
                            ...step,
                            statusClass: this.getStatusClass(step.status)
                        }));
                    }
                     else {
                        this.errorMessage = result.apEmpty || result.pendingPI || null;
                    }
                }
            })
            .catch(error => {
                this.errorMessage = error.body.message;
                this.approvalProcess = null;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    getStatusClass(status) {
        switch(status) {
            case 'Approved':
                return 'slds-text-color_success';
            case 'Rejected':
                return 'slds-text-color_error';
            case 'Not Started':
                return 'slds-text-color_weak';
            case 'Pending':
                return 'slds-text-color_warning';
            default:
                return '';
        }
    }

    get isSubmitDisabled() {
        return !this.approvalProcess || this.alreadySubmitted;
    }

    handleSubmit() {
        if (confirm('Once you submit this record for approval, you might not be able to edit it or recall it from the approval process depending on your settings. Continue?')) {
            this.isLoading = true;
            submitForApproval({ 
                objectId: this.recordId, 
                stepsForComments: JSON.stringify(this.stepsForComments) 
            })
                .then(result => {
                    if (result) {
                        window.location.href = `/${this.recordId}`;
                    }
                })
                .catch(error => {
                    this.errorMessage = error.body.message;
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }
    }

    handleGoBack() {
        window.location.href = `/${this.recordId}`;
    }
}