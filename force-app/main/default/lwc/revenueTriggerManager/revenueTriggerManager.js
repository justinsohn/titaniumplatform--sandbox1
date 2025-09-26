import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getProject from '@salesforce/apex/RevenueTriggerController.getProject';
import saveProject from '@salesforce/apex/RevenueTriggerController.saveProject';
import { refreshApex } from '@salesforce/apex';

export default class RevenueTriggerManager extends LightningElement {
    @api recordId;
    @track project;
    @track projectToUpdate = {};
    @track isModalOpen = false;
    @track error;

    // Header Properties for Rich Text
    mtHeader;
    msHeader;
    hwHeader;
    hwMtHeader;
    pafHeader;
    teHeader;

    // Field Properties
    actualMtStartDate;
    mtTerm;
    actualMsStartDate;
    msTerm;
    actualHwDeliveryDate;
    actualHardwareMtDeliveryDate;
    hwMtTerm;
    actualAcDeliveryDate;
    actualTeCompletionDate;
    forecastedMtStartDate;
    forecastedMsStartDate;
    forecastedHwStartDate;
    forecastedHwMtStartDate;
    forecastedAcDeliveryDate;
    forecastedTeStartDate;
    
    // POC & Completion Properties
    mtPoc;
    mtPocDecimal;
    msPoc;
    msPocDecimal;
    hwMtPoc;
    hwMtPocDecimal;
    // --- NEW: Completion Properties ---
    hwCompletion;
    hwCompletionDecimal;
    pafCompletion;
    pafCompletionDecimal;
    teCompletion;
    teCompletionDecimal;


    // Field Disablement Properties
    isMtDisabled = false;
    isMsDisabled = false;
    isHwDisabled = false;
    isHwMtDisabled = false;
    isPafDisabled = false;
    isTeDisabled = false;

    @wire(getProject, { projectId: '$recordId' })
    wiredProject(result) {
        this.project = result;
        if (result.data) {
            this.initializeFields(result.data);
            this.disableFieldsIfSet(result.data);
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
        }
    }

    formatCurrency(value) {
        if (value === null || value === undefined) {
            return '$0.00';
        }
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
        }).format(value);
    }

    initializeFields(data) {
        this.projectToUpdate.Id = this.recordId;

        // Existing field initializations
        this.actualMtStartDate = data.Actual_MT_Start_Date__c;
        this.mtTerm = data.MT_Term__c;
        this.actualMsStartDate = data.Actual_MS_Start_Date__c;
        this.msTerm = data.MS_Term__c;
        this.actualHwDeliveryDate = data.Actual_HW_Delivery_Date__c;
        this.actualHardwareMtDeliveryDate = data.Actual_HW_MT_Start_Date__c;
        this.hwMtTerm = data.HW_MT_Term__c;
        this.actualAcDeliveryDate = data.Actual_AC_Delivery_Date__c;
        this.actualTeCompletionDate = data.Actual_TE_Completion_Date__c;
        this.forecastedMtStartDate = data.Forecasted_MT_Start_Date__c;
        this.forecastedMsStartDate = data.Forecasted_MS_Start_Date__c;
        this.forecastedHwStartDate = data.Forecasted_HW_Start_Date__c;
        this.forecastedHwMtStartDate = data.Forecasted_HW_MT_Start_Date__c;
        this.forecastedAcDeliveryDate = data.Forecasted_AC_Delivery_Date__c;
        this.forecastedTeStartDate = data.Forecasted_TE_Start_Date__c;

        // Percentage Calculations
        this.mtPoc = data.MT_POC__c || 0;
        this.msPoc = data.MS_POC__c || 0;
        this.hwMtPoc = data.HW_MT__c || 0;
        this.mtPocDecimal = (data.MT_POC__c || 0) / 100;
        this.msPocDecimal = (data.MS_POC__c || 0) / 100;
        this.hwMtPocDecimal = (data.HW_MT__c || 0) / 100;

        // --- NEW: Initialize Completion bars ---
        this.hwCompletion = data.Actual_HW_Delivery_Date__c ? 100 : 0;
        this.hwCompletionDecimal = this.hwCompletion / 100;

        this.pafCompletion = data.Actual_AC_Delivery_Date__c ? 100 : 0;
        this.pafCompletionDecimal = this.pafCompletion / 100;

        this.teCompletion = data.Actual_TE_Completion_Date__c ? 100 : 0;
        this.teCompletionDecimal = this.teCompletion / 100;
        
        // Header Initialization with Bold Amount
        const formattedMtRevenue = this.formatCurrency(data.MT_Revenue__c);
        this.mtHeader = `Product Maintenance (MT) Service (<strong>${formattedMtRevenue}</strong>)`;
        const formattedMsRevenue = this.formatCurrency(data.MS_Revenue__c);
        this.msHeader = `Managed Services (MS) (<strong>${formattedMsRevenue}</strong>)`;
        const formattedHwRevenue = this.formatCurrency(data.HW_Revenue__c);
        this.hwHeader = `Hardware (HW) (<strong>${formattedHwRevenue}</strong>)`;
        const formattedHwMtRevenue = this.formatCurrency(data.Hardware_MT_Revenue__c);
        this.hwMtHeader = `Hardware (MT) Service (<strong>${formattedHwMtRevenue}</strong>)`;
        const formattedPafRevenue = this.formatCurrency(data.PAF_AC_SKU_Revenue__c);
        this.pafHeader = `Product Advancement Fee (PAF) (<strong>${formattedPafRevenue}</strong>)`;
        const formattedTeRevenue = this.formatCurrency(data.TE_Revenue__c);
        this.teHeader = `Travel/Expense (<strong>${formattedTeRevenue}</strong>)`;
    }

    disableFieldsIfSet(data) {
        if (data.Actual_MT_Start_Date__c || data.MT_Term__c) this.isMtDisabled = true;
        if (data.Actual_MS_Start_Date__c || data.MS_Term__c) this.isMsDisabled = true;
        if (data.Actual_HW_Delivery_Date__c) this.isHwDisabled = true;
        if (data.Actual_HW_MT_Start_Date__c || data.HW_MT_Term__c) this.isHwMtDisabled = true;
        if (data.Actual_AC_Delivery_Date__c) this.isPafDisabled = true;
        if (data.Actual_TE_Completion_Date__c) this.isTeDisabled = true;
    }

    handleInputChange(event) {
        this.projectToUpdate[event.target.name] = event.target.value;
    }

    handleSaveClick() {
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
    }

    handleConfirmSave() {
        saveProject({ projectToUpdate: this.projectToUpdate })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Revenue triggers saved successfully.',
                        variant: 'success'
                    })
                );
                this.isModalOpen = false;
                return refreshApex(this.project);
            })
            .catch(error => {
                const message = error.body ? error.body.message : 'An unknown error occurred.';
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error Saving Record',
                        message: message,
                        variant: 'error'
                    })
                );
                this.isModalOpen = false;
            });
    }
}