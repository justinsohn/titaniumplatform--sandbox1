import { LightningElement, api, wire, track } from 'lwc';
import getRevenueRecognitionGridData from '@salesforce/apex/RevenueRecognitionGridController.getRevenueRecognitionGridData';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class RevenueRecognitionGrid extends LightningElement {
    @api recordId;
    @track gridData;
    @track error;
    isLoading = true;

    @wire(getRevenueRecognitionGridData, { projectId: '$recordId' })
    wiredData({ error, data }) {
        this.isLoading = true;
        if (data) {
            console.log('Data received from Apex for Super Groups:', JSON.parse(JSON.stringify(data)));
            if (data.uniqueMonths && data.superGroups && data.monthlyGrandTotals) {
                this.processGridData(data);
            } else {
                this.gridData = { 
                    uniqueMonths: (data.uniqueMonths || []), 
                    flattenedData: [], 
                    monthlyGrandTotals: (data.monthlyGrandTotals || {}) 
                };
            }
            this.error = undefined;
            this.isLoading = false;
            console.log('Processed Grid Data for LWC:', JSON.parse(JSON.stringify(this.gridData)));
        } else if (error) {
            console.error('Error fetching revenue grid data:', error);
            this.error = this.reduceErrors(error).join(', ');
            this.gridData = { uniqueMonths: [], flattenedData: [], monthlyGrandTotals: {} };
            this.isLoading = false;
            this.showToast('Error Loading Data', this.error, 'error');
        }
    }

    processGridData(data) {
        const uniqueMonthsFromApex = data.uniqueMonths || [];
        const monthlyGrandTotalsFromApex = data.monthlyGrandTotals || {};
        const flattenedData = [];

        (data.superGroups || []).forEach(superGroup => {
            let hasContent = superGroup.productFamilies.some(pf => pf.productCodes && pf.productCodes.length > 0);
            if (!hasContent) return;

            flattenedData.push({
                id: `super-group-header_${superGroup.groupName}`,
                type: 'SUPER_GROUP_HEADER',
                name: superGroup.groupName,
                isSuperGroupHeader: true
            });

            (superGroup.productFamilies || []).forEach(family => {
                flattenedData.push({
                    id: `family-header_${superGroup.groupName}_${family.familyName}`,
                    type: 'FAMILY_HEADER',
                    name: family.familyName,
                    isFamilyHeader: true
                });

                (family.productCodes || []).forEach(code => {
                    flattenedData.push({
                        id: `product_${superGroup.groupName}_${family.familyName}_${code.productCode}`,
                        type: 'PRODUCT_CODE',
                        name: code.productCode,
                        soldPrice: code.soldPrice,
                        forecastTotal: code.forecastTotal, // NEW: Include forecastTotal
                        isProductCode: true,
                        monthlyData: uniqueMonthsFromApex.map(monthKey => ({
                            month: monthKey,
                            amount: code.monthlyAmounts[monthKey] || 0
                        }))
                    });
                });

                flattenedData.push({
                    id: `family-total_${superGroup.groupName}_${family.familyName}`,
                    type: 'FAMILY_TOTAL',
                    name: `${family.familyName} Totals:`,
                    isFamilyTotal: true,
                    monthlyData: uniqueMonthsFromApex.map(monthKey => ({
                        month: monthKey,
                        amount: family.monthlyFamilyTotals[monthKey] || 0
                    }))
                });
            });

            flattenedData.push({
                id: `super-group-total_${superGroup.groupName}`,
                type: 'SUPER_GROUP_TOTAL',
                name: `${superGroup.groupName} Totals:`,
                isSuperGroupTotal: true,
                monthlyData: uniqueMonthsFromApex.map(monthKey => ({
                    month: monthKey,
                    amount: superGroup.monthlySuperGroupTotals[monthKey] || 0
                }))
            });

            flattenedData.push({
                id: `spacer_${superGroup.groupName}`,
                type: 'SPACER',
                isSpacer: true
            });
        });

        if(flattenedData.length > 0 && flattenedData[flattenedData.length - 1].type === 'SPACER'){
            flattenedData.pop();
        }

        this.gridData = {
            uniqueMonths: uniqueMonthsFromApex,
            flattenedData: flattenedData,
            monthlyGrandTotals: monthlyGrandTotalsFromApex
        };
    }

    // --- Getters ---
    get hasData() {
        return this.gridData && this.gridData.flattenedData && this.gridData.flattenedData.length > 0;
    }
    get hasMonths() {
        return this.gridData && this.gridData.uniqueMonths && this.gridData.uniqueMonths.length > 0;
    }
    get monthHeaders() {
        if (!this.gridData || !this.gridData.uniqueMonths) return [];
        return this.gridData.uniqueMonths.map(month => {
            const [year, monthNumStr] = month.split('-');
            const date = new Date(parseInt(year), parseInt(monthNumStr, 10) - 1, 1);
            return date.toLocaleString('default', { month: 'short' }) + ' ' + year.substring(2);
        });
    }
    get colspanSize() {
        // Now spans 3 fixed columns + months
        return (this.gridData && this.gridData.uniqueMonths ? this.gridData.uniqueMonths.length : 0) + 3; 
    }
    get totalLabelColspanSize() {
        // Label now spans "Group/Family/Product", "Sold Price", and "Forecast Total"
        return 3; 
    }
    get grandTotalData() {
        if (!this.gridData || !this.gridData.uniqueMonths) return [];
        return this.gridData.uniqueMonths.map(monthKey => ({
            month: monthKey, 
            amount: this.gridData.monthlyGrandTotals[monthKey] || 0 
        }));
    }

    // --- Utility Methods ---
    reduceErrors(errors) {
        if (!Array.isArray(errors)) {
            errors = [errors];
        }
        return errors
            .filter(error => !!error)
            .map(error => {
                if (error.body) {
                    if (Array.isArray(error.body)) {
                        return error.body.map(e => e.message).join(', ');
                    } else if (typeof error.body.message === 'string') {
                        return error.body.message;
                    }
                }
                return error.message || error;
            });
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }
}