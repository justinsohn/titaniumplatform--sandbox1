import { LightningElement, api, wire, track } from 'lwc';
import getProjectFinancialsData from '@salesforce/apex/ProjectFinancialsController.getProjectFinancialsData';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ProjectFinancials extends LightningElement {
    @api recordId; // Project Id

    @track phasesData = [];
    @track error;
    isLoading = true;

    // Properties for grand totals
    @track grandTotalPriceRevSold = 0;
    @track grandTotalRevRecActual = 0;
    @track grandTotalLoeEstimatedCostSold = 0;
    @track grandTotalCostsActual = 0;
    @track grandTotalRatioActual = 0;
    @track grandTotalRatioActualColorClass = 'slds-text-color_default';
    @track grandTotalRatioSold = 0;
    @track grandTotalRatioSoldColorClass = 'slds-text-color_default';
    @track grandTotalRatioDelta = 0;
    @track grandTotalRatioDeltaColorClass = 'slds-text-color_default';
    @track grandTotalMhSold = 0;
    @track grandTotalMhActual = 0;


    @wire(getProjectFinancialsData, { projectId: '$recordId' })
    wiredFinancialData({ error, data }) {
        this.isLoading = true;
        this.phasesData = []; // Clear previous data
        // Reset grand totals
        this.grandTotalPriceRevSold = 0;
        this.grandTotalRevRecActual = 0;
        this.grandTotalLoeEstimatedCostSold = 0;
        this.grandTotalCostsActual = 0;
        this.grandTotalRatioActual = 0;
        this.grandTotalRatioActualColorClass = 'slds-text-color_default';
        this.grandTotalRatioSold = 0;
        this.grandTotalRatioSoldColorClass = 'slds-text-color_default';
        this.grandTotalRatioDelta = 0;
        this.grandTotalRatioDeltaColorClass = 'slds-text-color_default';
        this.grandTotalMhSold = 0;
        this.grandTotalMhActual = 0;


        if (data) {
            console.log('ProjectFinancials - Original data received:', JSON.parse(JSON.stringify(data)));

            // 1. Filter out phases that are identified as "Hardware" phases by name
            const nonHardwarePhases = data.filter(phase => 
                !phase.phaseName || !phase.phaseName.toLowerCase().includes('hardware')
            );
            console.log('ProjectFinancials - Non-Hardware phases:', JSON.parse(JSON.stringify(nonHardwarePhases)));

            // 2. Sort the filtered phases according to the specified order
            const sortOrder = ['professional services', 'managed services', 'maintenance'];
            nonHardwarePhases.sort((a, b) => {
                const nameA = a.phaseName ? a.phaseName.toLowerCase() : '';
                const nameB = b.phaseName ? b.phaseName.toLowerCase() : '';

                let indexA = sortOrder.indexOf(nameA);
                let indexB = sortOrder.indexOf(nameB);

                // If a phase is not in the sortOrder list, place it at the end
                if (indexA === -1) indexA = Infinity;
                if (indexB === -1) indexB = Infinity;
                
                if (indexA !== indexB) {
                    // If one or both are in the sort list, sort by their index
                    return indexA - indexB;
                } else {
                    // If both are not in the sort list (or have the same name), sort alphabetically
                    return nameA.localeCompare(nameB);
                }
            });
            console.log('ProjectFinancials - Sorted phases:', JSON.parse(JSON.stringify(nonHardwarePhases)));


            let processedPhases = [];
            let tempGrandTotalPriceRevSold = 0;
            let tempGrandTotalRevRecActual = 0;
            let tempGrandTotalLoeEstimatedCostSold = 0;
            let tempGrandTotalCostsActual = 0;
            let tempGrandTotalMhSold = 0;
            let tempGrandTotalMhActual = 0;

            // 3. Process only the sorted non-Hardware phases
            nonHardwarePhases.forEach(phase => {
                let totalTaskPriceRevSold = 0;
                let totalTaskRevRecActual = 0;
                let totalTaskLoeEstimatedCostSold = 0;
                let totalTaskCostsActual = 0;
                let totalTaskMhSold = 0;
                let totalTaskMhActual = 0;
                
                const mappedTasks = phase.tasks.map(task => {
                    totalTaskPriceRevSold += task.priceRevSold || 0;
                    totalTaskRevRecActual += task.revRecActual || 0;
                    totalTaskLoeEstimatedCostSold += task.loeEstimatedCostSold || 0;
                    totalTaskCostsActual += task.costsActual || 0;
                    totalTaskMhSold += task.mhSold || 0;
                    totalTaskMhActual += task.mhActual || 0;

                    let ratioActualColorClass = 'slds-text-color_default';
                    if (task.ratioActual != null) {
                        if (task.ratioActual < 1.5) {
                            ratioActualColorClass = 'slds-text-color_error';
                        } else if (task.ratioActual >= 1.5 && task.ratioActual < 2) {
                            ratioActualColorClass = 'slds-text-color_warning';
                        } else if (task.ratioActual >= 2) {
                            ratioActualColorClass = 'slds-text-color_success';
                        }
                    }

                    const ratioSold = task.ratioSold || 0;
                    const ratioActual = task.ratioActual || 0;
                    const ratioDelta = ratioActual - ratioSold;

                    let ratioDeltaColorClass = 'slds-text-color_default';
                    if (ratioDelta > 0) {
                        ratioDeltaColorClass = 'slds-text-color_success';
                    } else if (ratioDelta < 0) {
                        ratioDeltaColorClass = 'slds-text-color_error';
                    }

                    return {
                        ...task,
                        ratioActualColorClass: ratioActualColorClass,
                        ratioDelta: ratioDelta,
                        ratioDeltaColorClass: ratioDeltaColorClass
                    };
                });

                tempGrandTotalPriceRevSold += totalTaskPriceRevSold;
                tempGrandTotalRevRecActual += totalTaskRevRecActual;
                tempGrandTotalLoeEstimatedCostSold += totalTaskLoeEstimatedCostSold;
                tempGrandTotalCostsActual += totalTaskCostsActual;
                tempGrandTotalMhSold += totalTaskMhSold;
                tempGrandTotalMhActual += totalTaskMhActual;

                let totalRatioActualForPhase = 0;
                if (totalTaskCostsActual !== 0) {
                    totalRatioActualForPhase = totalTaskRevRecActual / totalTaskCostsActual;
                }
                let totalRatioActualColorClassForPhase = this.getRatioColorClass(totalRatioActualForPhase, totalTaskCostsActual !== 0);

                let totalRatioSoldForPhase = 0;
                if (totalTaskLoeEstimatedCostSold !== 0) {
                    totalRatioSoldForPhase = totalTaskPriceRevSold / totalTaskLoeEstimatedCostSold;
                }
                let totalRatioSoldColorClassForPhase = this.getRatioColorClass(totalRatioSoldForPhase, totalTaskLoeEstimatedCostSold !== 0);

                const totalRatioDeltaForPhase = totalRatioActualForPhase - totalRatioSoldForPhase;
                let totalRatioDeltaColorClassForPhase = 'slds-text-color_default';
                if (totalRatioDeltaForPhase > 0) {
                    totalRatioDeltaColorClassForPhase = 'slds-text-color_success';
                } else if (totalRatioDeltaForPhase < 0) {
                    totalRatioDeltaColorClassForPhase = 'slds-text-color_error';
                }

                processedPhases.push({
                    ...phase,
                    tasks: mappedTasks,
                    hasAnyTasks: mappedTasks.length > 0,
                    totalPriceRevSold: totalTaskPriceRevSold,
                    totalRevRecActual: totalTaskRevRecActual,
                    totalLoeEstimatedCostSold: totalTaskLoeEstimatedCostSold,
                    totalCostsActual: totalTaskCostsActual,
                    totalMhSold: totalTaskMhSold,
                    totalMhActual: totalTaskMhActual,
                    totalRatioActual: totalRatioActualForPhase,
                    totalRatioActualColorClass: totalRatioActualColorClassForPhase,
                    totalRatioSold: totalRatioSoldForPhase,
                    totalRatioSoldColorClass: totalRatioSoldColorClassForPhase,
                    totalRatioDelta: totalRatioDeltaForPhase,
                    totalRatioDeltaColorClass: totalRatioDeltaColorClassForPhase
                });
            });

            this.phasesData = processedPhases;

            this.grandTotalPriceRevSold = tempGrandTotalPriceRevSold;
            this.grandTotalRevRecActual = tempGrandTotalRevRecActual;
            this.grandTotalLoeEstimatedCostSold = tempGrandTotalLoeEstimatedCostSold;
            this.grandTotalCostsActual = tempGrandTotalCostsActual;
            this.grandTotalMhSold = tempGrandTotalMhSold;
            this.grandTotalMhActual = tempGrandTotalMhActual;

            if (this.grandTotalCostsActual !== 0) {
                this.grandTotalRatioActual = this.grandTotalRevRecActual / this.grandTotalCostsActual;
                this.grandTotalRatioActualColorClass = this.getRatioColorClass(this.grandTotalRatioActual);
            } else {
                this.grandTotalRatioActual = 0;
                this.grandTotalRatioActualColorClass = 'slds-text-color_default';
            }

            if (this.grandTotalLoeEstimatedCostSold !== 0) {
                this.grandTotalRatioSold = this.grandTotalPriceRevSold / this.grandTotalLoeEstimatedCostSold;
                this.grandTotalRatioSoldColorClass = this.getRatioColorClass(this.grandTotalRatioSold);
            } else {
                this.grandTotalRatioSold = 0;
                this.grandTotalRatioSoldColorClass = 'slds-text-color_default';
            }

            this.grandTotalRatioDelta = this.grandTotalRatioActual - this.grandTotalRatioSold;
            if (this.grandTotalRatioDelta > 0) {
                this.grandTotalRatioDeltaColorClass = 'slds-text-color_success';
            } else if (this.grandTotalRatioDelta < 0) {
                this.grandTotalRatioDeltaColorClass = 'slds-text-color_error';
            } else {
                this.grandTotalRatioDeltaColorClass = 'slds-text-color_default';
            }

            this.error = undefined;
            this.isLoading = false;
            console.log('ProjectFinancials - Processed phasesData (Hardware phases excluded):', JSON.parse(JSON.stringify(this.phasesData)));

        } else if (error) {
            console.error('ProjectFinancials - Error fetching financial data:', error);
            this.error = this.reduceErrors(error).join(', ');
            this.isLoading = false;
            this.showErrorToast('Error Loading Financials', this.error, 'error');
        } else {
            this.isLoading = false;
        }
    }

    getRatioColorClass(ratio, isValidDenominator = true) {
        if (!isValidDenominator || ratio == null) return 'slds-text-color_default';
        if (ratio < 1.5) return 'slds-text-color_error';
        if (ratio >= 1.5 && ratio < 2) return 'slds-text-color_warning';
        if (ratio >= 2) return 's-text-color_success';
        return 'slds-text-color_default';
    }

    get hasData() {
        // This will be true if there are any non-hardware phases with tasks
        return this.phasesData && this.phasesData.some(phase => phase.hasAnyTasks);
    }

    get showSummaryTable() {
        return !this.isLoading && !this.error && this.hasData;
    }

    get errorText() {
        let message = 'Unknown error';
        if (this.error) {
            if (this.error.body && this.error.body.message) {
                message = this.error.body.message;
            } else if (typeof this.error === 'string') {
                message = this.error;
            } else {
                message = JSON.stringify(this.error);
            }
        }
        return message;
    }

    showErrorToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'sticky'
        });
        this.dispatchEvent(event);
    }

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
                return error.message || JSON.stringify(error);
            });
    }
}