import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getProjectDetails from '@salesforce/apex/BillingMilestonesController.getProjectDetails';
import getOpportunityProductsByOrder from '@salesforce/apex/BillingMilestonesController.getOpportunityProductsByOrder';
import saveMilestoneAllocations from '@salesforce/apex/BillingMilestonesController.saveMilestoneAllocations';
import updateOrderMilestoneCount from '@salesforce/apex/BillingMilestonesController.updateOrderMilestoneCount';

// Configuration for the new grouping logic
const GROUP_CONFIG = {
    '3P': '3rd Party Fees (3P)',
    'AP': 'Software (AP, AE, CP, CX, EM)',
    'AE': 'Software (AP, AE, CP, CX, EM)',
    'CP': 'Software (AP, AE, CP, CX, EM)',
    'CX': 'Software (AP, AE, CP, CX, EM)',
    'EM': 'Software (AP, AE, CP, CX, EM)',
    'AC': 'Customized Software (AC)',
    'PS': 'Professional Services (PS, TR)',
    'TR': 'Professional Services (PS, TR)', // TR is now part of Professional Services
    'MS': 'Managed Services (MS)',
    'MT': 'Maintenance (MT)',
    'HW': 'Hardware (HW)',
    'TE': 'Travel/Expenses (TE)'
};

// Defines the display order of the new groups
const GROUP_ORDER = [
    '3rd Party Fees (3P)',
    'Software (AP, AE, CP, CX, EM)',
    'Customized Software (AC)',
    'Professional Services (PS, TR)',
    'Managed Services (MS)',
    'Maintenance (MT)',
    'Hardware (HW)',
    'Travel/Expenses (TE)',
    'Other' // Fallback for products that don't match a prefix
];


export default class BillingMilestones extends LightningElement {
    @api recordId; 
    
    @track projectDetails;
    @track orderData = [];
    @track error;
    @track isLoading = true;

    lockedColumnClass = 'slds-text-title_caps milestone-column column-locked';
    unlockedColumnClass = 'slds-text-title_caps milestone-column';
    lockedCellClass = 'milestone-data-cell column-locked'; 
    unlockedCellClass = 'milestone-data-cell'; 
    
    connectedCallback() {
        this.loadData();
    }
    
    loadData() {
        this.isLoading = true;
        this.error = null;
        
        getProjectDetails({ projectId: this.recordId })
            .then(result => {
                this.projectDetails = result;
                return getOpportunityProductsByOrder({ projectId: this.recordId });
            })
            .then(result => {
                this.processOrderData(result); 
                this.isLoading = false;
            })
            .catch(error => {
                this.error = 'Error loading data: ' + this.reduceErrors(error);
                this.isLoading = false;
            });
    }
    
    processOrderData(orderWrappersFromApex) {
        if (!orderWrappersFromApex || orderWrappersFromApex.length === 0) {
            this.orderData = [];
            return;
        }
        
        try {
            const processedOrderData = JSON.parse(JSON.stringify(orderWrappersFromApex)); 
            
            processedOrderData.forEach((orderWrapper) => {
                // --- Milestone header and lock state setup (remains the same) ---
                const currentNumberOfMilestones = parseInt(orderWrapper.order.Number_of_Milestones__c || 0, 10);
                orderWrapper.editableNumberOfMilestones = orderWrapper.editableNumberOfMilestones || (currentNumberOfMilestones > 0 ? currentNumberOfMilestones : 1);

                let isAnyMilestoneColumnEffectivelyLockedForOrder = false;
                if (orderWrapper.milestoneHeaders && orderWrapper.milestoneHeaders.length > 0) {
                    orderWrapper.milestoneHeaders.forEach(header => {
                        header.isEffectivelyLocked = header.columnReadyToInvoice; 
                        if (header.isEffectivelyLocked) isAnyMilestoneColumnEffectivelyLockedForOrder = true;
                        header.headerClass = header.isEffectivelyLocked ? this.lockedColumnClass : this.unlockedColumnClass;
                        header.cellClass = header.isEffectivelyLocked ? this.lockedCellClass : this.unlockedCellClass;
                        header.columnDescription = header.columnDescription === undefined ? '' : header.columnDescription;
                    });
                } else { 
                     orderWrapper.milestoneHeaders = [];
                     for (let i = 1; i <= currentNumberOfMilestones; i++) {
                        orderWrapper.milestoneHeaders.push({
                            index: i, label: `M${i}`, columnTargetDate: null, columnReadyToInvoice: false,
                            columnDescription: '', isEffectivelyLocked: false, 
                            headerClass: this.unlockedColumnClass, cellClass: this.unlockedCellClass
                        });
                    }
                }
                orderWrapper.isAnyMilestoneColumnLocked = isAnyMilestoneColumnEffectivelyLockedForOrder;
                
                orderWrapper.totalColumns = 2 + (orderWrapper.milestoneHeaders ? orderWrapper.milestoneHeaders.length : 0) + 2; 
                orderWrapper.milestoneTotals = this.initializeMilestoneTotals(orderWrapper.milestoneHeaders.length, orderWrapper.milestoneHeaders);
                
                // *** NEW GROUPING LOGIC STARTS HERE ***
                let allProducts = [];
                if (orderWrapper.productFamilies) {
                    orderWrapper.productFamilies.forEach(family => {
                        if(family.products) {
                            allProducts.push(...family.products);
                        }
                    });
                }

                let groupedProductsMap = new Map();
                allProducts.forEach(productWrapper => {
                    // Use Revenue_Group_Formula__c for grouping logic
                    let revGroupFormula = productWrapper.product.Revenue_Group_Formula__c || '';
                    let prefix = (revGroupFormula.split('-')[0] || '').toUpperCase();
                    let groupName = GROUP_CONFIG[prefix] || 'Other';

                    if (!groupedProductsMap.has(groupName)) {
                        groupedProductsMap.set(groupName, []);
                    }
                    groupedProductsMap.get(groupName).push(productWrapper);
                });

                let newProductGroups = [];
                groupedProductsMap.forEach((products, groupName) => {
                    newProductGroups.push({ groupName: groupName, products: products });
                });

                newProductGroups.sort((a, b) => {
                    let indexA = GROUP_ORDER.indexOf(a.groupName);
                    let indexB = GROUP_ORDER.indexOf(b.groupName);
                    if (indexA === -1) indexA = Infinity;
                    if (indexB === -1) indexB = Infinity;
                    return indexA - indexB;
                });

                orderWrapper.newProductGroups = newProductGroups;
                // *** NEW GROUPING LOGIC ENDS HERE ***

                let orderTotalAmount = 0;
                
                // Now iterate over the new structure to process the nested product data
                if (orderWrapper.newProductGroups && orderWrapper.newProductGroups.length > 0) {
                    orderWrapper.newProductGroups.forEach(group => {
                        if (group.products && group.products.length > 0) {
                            group.products.forEach(productW => {
                                orderTotalAmount += (productW.product && productW.product.TotalPrice) ? productW.product.TotalPrice : 0;
                                
                                productW.displayProductCode = productW.product && productW.product.ProductCode && productW.product.Product2 && productW.product.Product2.Name !== productW.product.ProductCode;

                                let productAllocatedPercentageTotal = 0;
                                if (productW.milestoneAllocations && productW.milestoneAllocations.length > 0) {
                                    productW.milestoneAllocations.forEach(allocation => {
                                        const headerForThisAlloc = orderWrapper.milestoneHeaders.find(h => h.index === allocation.milestoneNumber);
                                        
                                        allocation.isLocked = headerForThisAlloc ? headerForThisAlloc.isEffectivelyLocked : false;
                                        allocation.cellClass = allocation.isLocked ? this.lockedCellClass : this.unlockedCellClass;
                                        
                                        allocation.percentage = parseFloat(allocation.percentage) || 0;
                                        allocation.amount = parseFloat(allocation.amount) || 0; 

                                        if (allocation.milestoneNumber <= currentNumberOfMilestones) {
                                            productAllocatedPercentageTotal += allocation.percentage;
                                            const milestoneTotal = orderWrapper.milestoneTotals.find(mt => mt.milestone === allocation.milestoneNumber);
                                            if (milestoneTotal) {
                                                milestoneTotal.amount += allocation.amount || 0;
                                            }
                                        }
                                    });
                                }
                                productW.allocatedPercentage = productAllocatedPercentageTotal / 100;
                                productW.remainingPercentage = (100 - productAllocatedPercentageTotal) / 100;
                                productW.remainingStyling = this.getRemainingStylingClass(productAllocatedPercentageTotal);
                            });
                        }
                    });
                }
                
                orderWrapper.totalAmount = orderTotalAmount;
                orderWrapper.hasProducts = allProducts.length > 0;
            });
            
            this.orderData = processedOrderData;
        } catch (error) {
            console.error('LWC processOrderData Error:', JSON.stringify(error), error.message, error.stack);
            this.error = 'Error processing order data: ' + (error.message || 'Unknown error during data processing');
        }
    }

    handlePercentageChange(event) {
        const orderIndex = parseInt(event.target.dataset.orderIndex, 10);
        const groupName = event.target.dataset.groupName;
        const productIndex = parseInt(event.target.dataset.productIndex, 10);
        const milestone = parseInt(event.target.dataset.milestone, 10);
        const newValue = parseFloat(event.target.value) || 0; 
        
        this._updateIndividualMilestoneAllocation(orderIndex, groupName, productIndex, milestone, 'percentage', newValue);
    }

    _updateIndividualMilestoneAllocation(orderIndex, groupName, productIndexInGroup, milestoneNumber, fieldName, newValue) {
        if (isNaN(orderIndex) || isNaN(productIndexInGroup) || isNaN(milestoneNumber) || !groupName) return false;

        if (orderIndex >= 0 && orderIndex < this.orderData.length) {
            const updatedOrderData = JSON.parse(JSON.stringify(this.orderData)); 
            const orderWrapper = updatedOrderData[orderIndex]; 
            const group = orderWrapper.newProductGroups.find(g => g.groupName === groupName);

            if (group && productIndexInGroup >= 0 && productIndexInGroup < group.products.length) {
                const productWrapperInstance = group.products[productIndexInGroup]; 
                const allocation = productWrapperInstance.milestoneAllocations.find(a => a.milestoneNumber === milestoneNumber);
                
                const header = orderWrapper.milestoneHeaders.find(h => h.index === milestoneNumber);
                if (header && header.isEffectivelyLocked && fieldName === 'percentage') { 
                    this.dispatchEvent(new ShowToastEvent({title: 'Locked', message: `Milestone ${milestoneNumber} is locked for editing.`, variant: 'warning'}));
                    return false; 
                }

                if (allocation) {
                    allocation[fieldName] = newValue; 
                    if (fieldName === 'percentage') {
                        const basePrice = (productWrapperInstance.product && productWrapperInstance.product.TotalPrice) ? productWrapperInstance.product.TotalPrice : 0;
                        allocation.amount = (basePrice * newValue) / 100; 
                        this.updateProductPercentages(productWrapperInstance); 
                        this.updateOrderMilestoneTotals(orderWrapper);       
                    }
                    this.orderData = updatedOrderData; 
                    return true;
                }
            }
        }
        return false;
    }
    
    hasProductsInOrder(orderWrapper) {
        if (!orderWrapper.newProductGroups || orderWrapper.newProductGroups.length === 0) return false;
        return orderWrapper.newProductGroups.some(group => group.products && group.products.length > 0);
    }
    
    initializeMilestoneTotals(milestoneCount, headers) {
        const totals = [];
        if (!headers) return totals; 
        for (let i = 1; i <= milestoneCount; i++) {
            const header = headers.find(h => h.index === i);
            totals.push({ 
                milestone: i, 
                amount: 0,
                cellClass: header && header.isEffectivelyLocked ? this.lockedCellClass : this.unlockedCellClass 
            });
        }
        return totals;
    }

    handleColumnTargetDateChange(event) {
        const orderIndex = parseInt(event.target.dataset.orderIndex, 10);
        const milestoneNumberToUpdate = parseInt(event.target.dataset.milestoneHeaderIndex, 10); 
        const newDate = event.target.value; 

        if (isNaN(orderIndex) || isNaN(milestoneNumberToUpdate)) return;

        const updatedOrderData = JSON.parse(JSON.stringify(this.orderData));
        const orderWrapper = updatedOrderData[orderIndex];

        if (orderWrapper && orderWrapper.milestoneHeaders) {
            const header = orderWrapper.milestoneHeaders.find(h => h.index === milestoneNumberToUpdate);
            if (header && header.isEffectivelyLocked) {
                 this.dispatchEvent(new ShowToastEvent({title: 'Locked', message: `Milestone ${milestoneNumberToUpdate} is locked. Target Date cannot be changed.`, variant: 'warning'}));
                 event.target.value = header.columnTargetDate; 
                 return;
            }
            if (header) {
                header.columnTargetDate = newDate; 
            }
            this.orderData = updatedOrderData; 
        }
    }

    handleColumnReadyToInvoiceChange(event) {
        const orderIndex = parseInt(event.target.dataset.orderIndex, 10);
        const milestoneNumberToUpdate = parseInt(event.target.dataset.milestoneHeaderIndex, 10);
        const isChecked = event.target.checked; 

        if (isNaN(orderIndex) || isNaN(milestoneNumberToUpdate)) return;
        
        const orderWrapper = this.orderData[orderIndex];
        if (orderWrapper && orderWrapper.milestoneHeaders) {
            const header = orderWrapper.milestoneHeaders.find(h => h.index === milestoneNumberToUpdate);
            if (header) {
                header.columnReadyToInvoice = isChecked;
                header.isEffectivelyLocked = isChecked;
                header.headerClass = isChecked ? this.lockedColumnClass : this.unlockedColumnClass;
                header.cellClass = isChecked ? this.lockedCellClass : this.unlockedCellClass;

                const totalCell = orderWrapper.milestoneTotals.find(t => t.milestone === milestoneNumberToUpdate);
                if(totalCell) totalCell.cellClass = header.cellClass;

                if(orderWrapper.newProductGroups) {
                    orderWrapper.newProductGroups.forEach(group => {
                        group.products.forEach(productW => {
                            if(productW.milestoneAllocations) {
                                const alloc = productW.milestoneAllocations.find(a => a.milestoneNumber === milestoneNumberToUpdate);
                                if(alloc) {
                                    alloc.isLocked = isChecked;
                                    alloc.cellClass = header.cellClass;
                                }
                            }
                        });
                    });
                }
            }
            this.orderData = [...this.orderData];
        }
    }

    handleColumnDescriptionChange(event) {
        const orderIndex = parseInt(event.target.dataset.orderIndex, 10);
        const milestoneNumberToUpdate = parseInt(event.target.dataset.milestoneHeaderIndex, 10);
        const newDescription = event.target.value;

        if (isNaN(orderIndex) || isNaN(milestoneNumberToUpdate)) return;

        const updatedOrderData = JSON.parse(JSON.stringify(this.orderData));
        const orderWrapper = updatedOrderData[orderIndex];

        if (orderWrapper && orderWrapper.milestoneHeaders) {
            const header = orderWrapper.milestoneHeaders.find(h => h.index === milestoneNumberToUpdate);
            if (header && header.isEffectivelyLocked) {
                 this.dispatchEvent(new ShowToastEvent({title: 'Locked', message: `Milestone ${milestoneNumberToUpdate} is locked. Description cannot be changed.`, variant: 'warning'}));
                 event.target.value = header.columnDescription; 
                 return;
            }
            if (header) {
                header.columnDescription = newDescription; 
            }
            this.orderData = updatedOrderData;
        }
    }


    handleEditableMilestonesChange(event) {
        const orderIndex = parseInt(event.target.dataset.orderIndex, 10);
        const newCount = parseInt(event.target.value, 10);
        
        const updatedOrderData = JSON.parse(JSON.stringify(this.orderData));
        if (orderIndex >= 0 && orderIndex < updatedOrderData.length) {
            updatedOrderData[orderIndex].editableNumberOfMilestones = newCount;
            this.orderData = updatedOrderData; 
        }
    }

    handleUpdateMilestoneCountForOrder(event) {
        const orderIndex = parseInt(event.target.dataset.orderIndex, 10);
        if (isNaN(orderIndex) || orderIndex < 0 || orderIndex >= this.orderData.length) return;

        const orderWrapper = this.orderData[orderIndex];
        const orderId = orderWrapper.order.Id;
        const newMilestoneCount = orderWrapper.editableNumberOfMilestones;

        if (isNaN(newMilestoneCount) || newMilestoneCount < 1 || newMilestoneCount > 20) { 
            this.dispatchEvent(new ShowToastEvent({title: 'Validation Error', message: 'Number of milestones must be between 1 and 20.', variant: 'error'}));
            return;
        }

        this.isLoading = true;
        updateOrderMilestoneCount({ orderId: orderId, newCount: newMilestoneCount })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({title: 'Success', message: `Milestone count for order ${orderWrapper.order.OrderNumber} updated. Reloading data...`, variant: 'success'}));
                this.loadData(); 
            })
            .catch(error => {
                this.isLoading = false;
                this.dispatchEvent(new ShowToastEvent({title: 'Error Updating Milestone Count', message: this.reduceErrors(error), variant: 'error', mode: 'sticky'}));
            });
    }
    
    updateProductPercentages(productWrapperInstance) { 
        if (productWrapperInstance && productWrapperInstance.milestoneAllocations) {
            let totalPercentage = 0;
            const currentNumberOfMilestones = productWrapperInstance.milestoneAllocations.length; 
            
            productWrapperInstance.milestoneAllocations.forEach(allocation => {
                if (allocation.milestoneNumber <= currentNumberOfMilestones) { 
                     totalPercentage += parseFloat(allocation.percentage) || 0;
                }
            });
            
            productWrapperInstance.allocatedPercentage = totalPercentage / 100;
            productWrapperInstance.remainingPercentage = (100 - totalPercentage) / 100;
            productWrapperInstance.remainingStyling = this.getRemainingStylingClass(totalPercentage);
        }
    }
    
    updateOrderMilestoneTotals(orderWrapper) {
        if (orderWrapper && orderWrapper.milestoneHeaders) { 
            orderWrapper.milestoneTotals = orderWrapper.milestoneHeaders.map(h => ({ 
                milestone: h.index, 
                amount: 0,
                cellClass: h.isEffectivelyLocked ? this.lockedCellClass : this.unlockedCellClass 
            }));
            
            if (orderWrapper.newProductGroups) {
                orderWrapper.newProductGroups.forEach(group => {
                    if (group.products) {
                        group.products.forEach(productW => { 
                            if (productW.milestoneAllocations) {
                                productW.milestoneAllocations.forEach(allocation => {
                                    const headerExists = orderWrapper.milestoneHeaders.some(h => h.index === allocation.milestoneNumber);
                                    if (headerExists) { 
                                        const milestoneTotal = orderWrapper.milestoneTotals.find(mt => mt.milestone === allocation.milestoneNumber);
                                        if (milestoneTotal) {
                                            milestoneTotal.amount += allocation.amount || 0;
                                        }
                                    }
                                });
                            }
                        });
                    }
                });
            }
        }
    }
    
    handleSave() {
        this.isLoading = true;
        this.error = null;
        
        const allocationsToSave = [];
        this.orderData.forEach(orderWrapper => {
            const currentNumberOfMilestonesForOrder = orderWrapper.milestoneHeaders.length; 
            if (orderWrapper.newProductGroups) {
                orderWrapper.newProductGroups.forEach(group => {
                    if (group.products) {
                        group.products.forEach(productW => { 
                            if (productW.product && productW.product.Id && productW.milestoneAllocations) {
                                const productAllocationPayload = {
                                    productId: productW.product.Id, 
                                    allocations: productW.milestoneAllocations
                                        .filter(alloc => alloc.milestoneNumber <= currentNumberOfMilestonesForOrder) 
                                        .map(alloc => {
                                            const header = orderWrapper.milestoneHeaders.find(h => h.index === alloc.milestoneNumber);
                                            return {
                                                milestoneNumber: alloc.milestoneNumber,
                                                percentage: alloc.percentage, 
                                                amount: alloc.amount,         
                                                invoiceId: alloc.invoiceId,   
                                                targetDate: header ? header.columnTargetDate : null, 
                                                readyToInvoice: header ? header.columnReadyToInvoice : false, 
                                                description: header ? header.columnDescription : '' 
                                            };
                                    })
                                };
                                if (productAllocationPayload.allocations.length > 0) {
                                    allocationsToSave.push(productAllocationPayload);
                                }
                            } 
                        });
                    }
                });
            }
        });
        
        console.log('LWC handleSave: Data being sent to saveMilestoneAllocations:', JSON.parse(JSON.stringify(allocationsToSave)));
        
        if (allocationsToSave.length === 0 || allocationsToSave.every(p => p.allocations.length === 0)) {
            this.dispatchEvent(new ShowToastEvent({ title: 'No Changes', message: 'No milestone data to save.', variant: 'info' }));
            this.isLoading = false;
            return;
        }
        const allocationDataJSON = JSON.stringify(allocationsToSave);
        
        saveMilestoneAllocations({ 
            projectId: this.recordId,
            allocationData: allocationDataJSON 
        })
            .then(result => {
                this.isLoading = false;
                this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: result, variant: 'success' }));
                console.log('LWC handleSave: Save successful, calling loadData() to refresh.');
                this.loadData(); 
            })
            .catch(error => {
                const errorMessage = 'Error saving milestone allocations: ' + this.reduceErrors(error);
                this.error = errorMessage; 
                this.isLoading = false;
                this.dispatchEvent(new ShowToastEvent({ title: 'Error Saving Milestones', message: errorMessage, variant: 'error', mode: 'sticky' }));
            });
    }
    
    getRemainingStylingClass(allocatedPercentageTotal) { 
        const baseClass = 'slds-text-align_right ';
        if (allocatedPercentageTotal > 100.001) return baseClass + 'slds-text-color_error';
        if (Math.abs(allocatedPercentageTotal - 100) < 0.001) return baseClass + 'slds-text-color_success';
        return baseClass; 
    }
    
    get hasOrders() {
        return this.orderData && this.orderData.length > 0;
    }
    
    get isSaveDisabled() {
        if (this.isLoading) return true;
        return this.orderData.some(orderWrapper => 
            orderWrapper.newProductGroups && orderWrapper.newProductGroups.some(group =>
                group.products && group.products.some(product => product.allocatedPercentage > 1.0001) 
            )
        );
    }
    
    reduceErrors(errors) {
        if (!errors) return 'An unknown error occurred.';
        let errorMessages = [];
        if (!Array.isArray(errors)) errors = [errors];
    
        errors.forEach(error => {
            if (error) { 
                if (error.body && typeof error.body.message === 'string') { 
                    errorMessages.push(error.body.message);
                } else if (Array.isArray(error.body)) { 
                    error.body.forEach(err => { if (err && err.message) errorMessages.push(err.message); });
                } else if (typeof error.message === 'string') { 
                    errorMessages.push(error.message);
                } else if (typeof error === 'string') {
                     errorMessages.push(error);
                } else {
                    try {
                        if (typeof error === 'object' && error !== null) {
                            errorMessages.push(JSON.stringify(error));
                        }
                    } catch (e) { /* ignore */ }
                }
            }
        });
    
        if (errorMessages.length === 0) return 'An unknown error occurred (no specific message).';
        return errorMessages.join('; ');
    }
}