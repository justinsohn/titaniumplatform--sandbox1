import { LightningElement, api, wire, track } from 'lwc';
import getRevenueRecData from '@salesforce/apex/ProjectRevenueRecController.getRevenueRecData';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Constants for phase/grouping logic
const PROFESSIONAL_SERVICES_PHASE = 'professional services'; // Project Task derived
const MAINTENANCE_PHASE = 'maintenance'; // Project Task derived
const MANAGED_SERVICES_PHASE = 'managed services'; // Project Task derived
const HARDWARE_PHASE_NAME = 'hardware'; // Opportunity Product derived
const ADVANCEMENT_FEE_REVENUE_GROUP = 'AC'; // Opportunity Product derived
const MILESTONE_REVENUE_MODEL = 'Milestone'; // Opportunity Product derived

// Constants for prefixes to filter Opportunity Products (for Project Task derived data)
const PS_PRODUCT_PREFIX = 'PS-'; 
const MS_PRODUCT_PREFIX = 'MS';
const MT_PRODUCT_PREFIX = 'MT-';
const PS_TE_PRODUCT_PREFIX = 'PS-TE-'; // Corrected constant for Time and Expenses products (starts with PS-TE-)


// Define the prefixes and their full names for sub-grouping within Aggregate POC items
const AGGREGATE_SUB_GROUPS_CONFIG = [
    { prefix: '3P-', name: '3P - 3rd Party Fees' },
    { prefix: 'AP-', name: 'AP - Applications' },
    { prefix: 'AE-', name: 'AE - App Enhancements' },
    { prefix: 'CP-', name: 'CP – Core Platform' },
    { prefix: 'CX-', name: 'CX – Core Platform Expansion' },
    { prefix: 'EM-', name: 'EM – Core Platform Enhancements' }
];

export default class ProjectRevenueRec extends LightningElement {
    @api recordId;

    // Tracked arrays for different sections
    @track professionalServicesPhases = []; // For Professional Services Project Tasks
    @track aggregatePOCPhases = []; // For Aggregate POC Opportunity Products
    @track maintenancePhases = []; // For Maintenance Project Tasks
    @track managedServicesPhases = []; // For Managed Services Project Tasks
    @track milestoneHardwareProducts = []; // For Hardware Opportunity Products
    @track milestoneAdvancementFeeProducts = []; // For Advancement Fee Opportunity Products
    @track milestoneProductFamilyGroups = []; // For Milestone Opportunity Products grouped by Product Family
    @track milestoneTimeAndExpensesProducts = []; // NEW: For Milestone Time and Expenses Products

    @track error;
    isLoading = true;

    projectStartDate = null;
    projectTerm = null;

    @wire(getRevenueRecData, { projectId: '$recordId' })
    wiredRevenueData({ error, data }) {
        this.isLoading = true;
        // Reset all data arrays
        this.professionalServicesPhases = [];
        this.aggregatePOCPhases = [];
        this.maintenancePhases = [];
        this.managedServicesPhases = [];
        this.milestoneHardwareProducts = [];
        this.milestoneAdvancementFeeProducts = [];
        this.milestoneProductFamilyGroups = [];
        this.milestoneTimeAndExpensesProducts = []; // Reset new TE array

        if (data) {
            console.log('projectRevenueRec - Data received:', JSON.parse(JSON.stringify(data)));
            this.projectStartDate = data.actualStartDate;
            this.projectTerm = data.termInMonths;

            let tempProfessionalServices = [];
            let tempAggregate = [];
            let tempMaintenance = [];
            let tempManagedServices = [];
            let tempMilestoneHardware = [];
            let tempMilestoneAdvancementFee = [];
            let tempMilestoneProducts = [];
            let tempMilestoneTimeAndExpenses = []; // NEW

            // Create a map of existing phases for easier lookup and population
            const existingPhasesMap = new Map();
            if (data.phases) {
                data.phases.forEach(phase => {
                    existingPhasesMap.set(phase.phaseId, { ...phase, tasks: [] });
                });
            }

            // 1. Process Project Tasks (Professional Services, Maintenance, Managed Services)
            if (data.phases) {
                data.phases.forEach(phase => {
                    let phaseNameLower = phase.phaseName ? phase.phaseName.toLowerCase().trim() : '';
                    
                    const projectTasksForPhase = phase.tasks;

                    if (projectTasksForPhase.length === 0 &&
                        phaseNameLower !== PROFESSIONAL_SERVICES_PHASE &&
                        phaseNameLower !== MAINTENANCE_PHASE &&
                        phaseNameLower !== MANAGED_SERVICES_PHASE) {
                        return;
                    }

                    const mappedTasks = projectTasksForPhase.map(task => ({ ...task }));

                    let totalRevenueBacklogForPhase = 0;
                    mappedTasks.forEach(task => {
                        totalRevenueBacklogForPhase += task.revenueBacklog || 0;
                    });

                    const commonPhaseData = {
                        ...phase,
                        tasks: mappedTasks,
                        hasAnyTasks: mappedTasks.length > 0,
                        totalRevenueBacklogForPhase: totalRevenueBacklogForPhase
                    };

                    if (phaseNameLower === PROFESSIONAL_SERVICES_PHASE) {
                        tempProfessionalServices.push({ ...commonPhaseData });
                    } else if (phaseNameLower === MAINTENANCE_PHASE) {
                        tempMaintenance.push({ ...commonPhaseData });
                    } else if (phaseNameLower === MANAGED_SERVICES_PHASE) {
                        tempManagedServices.push({ ...commonPhaseData });
                    }
                });
            }

            // 2. Process Opportunity Products from the flat list (Hardware, Advancement Fee, Aggregate POC, Milestone, Time & Expenses etc.)
            if (data.opportunityProducts) {
                let hardwarePhase = existingPhasesMap.has(HARDWARE_PHASE_NAME) ? existingPhasesMap.get(HARDWARE_PHASE_NAME) : { phaseId: 'hardware_product_group', phaseName: 'Hardware', tasks: [], hasAnyTasks: false };
                let aggregatePOCMasterPhase = null;
                for (let [id, phase] of existingPhasesMap) {
                    if (phase.useAggregate) {
                        aggregatePOCMasterPhase = phase;
                        break;
                    }
                }
                if (!aggregatePOCMasterPhase) {
                    aggregatePOCMasterPhase = { phaseId: 'aggregate_poc_product_group', phaseName: 'Aggregate POC', useAggregate: true, tasks: [], subGroups: [], hasAnyTasks: false };
                }

                if (!aggregatePOCMasterPhase.subGroupsMap) {
                    aggregatePOCMasterPhase.subGroupsMap = new Map();
                    AGGREGATE_SUB_GROUPS_CONFIG.forEach(g => {
                        aggregatePOCMasterPhase.subGroupsMap.set(g.prefix, { name: g.name, tasks: [], hasAnyTasks: false });
                    });
                    aggregatePOCMasterPhase.subGroupsMap.set('OTHER', { name: 'Other', tasks: [], hasAnyTasks: false });
                }


                data.opportunityProducts.forEach(product => {
                    const revGroup = product.opportunityProductRevenueGroupFormula ? product.opportunityProductRevenueGroupFormula.toUpperCase().trim() : '';
                    const revenueModel = product.revenueModel ? product.revenueModel.trim() : '';
                    // const productFamilyUpper = product.productFamily ? product.productFamily.toUpperCase().trim() : ''; // No longer needed for PS-TE filter

                    // Filter out products with blank Revenue Group Formula
                    if (!revGroup) {
                        return;
                    }

                    // Filter out products whose Revenue Group Formula starts with PS-, MS-, or MT-
                    // as these are handled by Project Tasks
                    if (revGroup.startsWith(PS_PRODUCT_PREFIX) || 
                        revGroup.startsWith(MS_PRODUCT_PREFIX) || 
                        revGroup.startsWith(MT_PRODUCT_PREFIX)) {
                        return; 
                    }

                    // NEW: Handle Time and Expenses products where Revenue Group Formula starts with PS-TE-
                    if (revGroup.startsWith(PS_TE_PRODUCT_PREFIX)) { // Now checking revGroup instead of productFamilyUpper
                        tempMilestoneTimeAndExpenses.push({ ...product });
                        return;
                    }

                    // Handle Milestone products separately
                    if (revenueModel === MILESTONE_REVENUE_MODEL) {
                        tempMilestoneProducts.push({ ...product });
                        return;
                    }

                    // Populate Advancement Fee Products
                    if (revGroup === ADVANCEMENT_FEE_REVENUE_GROUP.toUpperCase()) {
                        tempMilestoneAdvancementFee.push({ ...product });
                    }
                    // Populate Hardware Products
                    else if (revGroup === HARDWARE_PHASE_NAME.toUpperCase()) {
                        hardwarePhase.tasks.push(product);
                    }
                    // Populate Aggregate POC Products based on prefix in product name
                    else {
                        let groupFound = false;
                        for (const groupInfo of AGGREGATE_SUB_GROUPS_CONFIG) {
                            if (product.taskName && product.taskName.toUpperCase().startsWith(groupInfo.prefix.toUpperCase())) {
                                aggregatePOCMasterPhase.subGroupsMap.get(groupInfo.prefix).tasks.push(product);
                                groupFound = true;
                                break;
                            }
                        }
                        if (!groupFound && aggregatePOCMasterPhase.subGroupsMap) {
                            aggregatePOCMasterPhase.subGroupsMap.get('OTHER').tasks.push(product);
                        }
                    }
                });

                // Finalize Hardware Products phase
                if (hardwarePhase.tasks.length > 0) {
                    hardwarePhase.hasAnyTasks = true;
                    hardwarePhase.totalRevenueBacklogForPhase = hardwarePhase.tasks.reduce((sum, product) => sum + (product.revenueBacklog || 0), 0);
                    tempMilestoneHardware.push(hardwarePhase);
                }

                // Finalize Aggregate POC Products phase
                if (aggregatePOCMasterPhase.subGroupsMap) {
                    let subGroupsArray = [];
                    aggregatePOCMasterPhase.subGroupsMap.forEach((groupData, key) => {
                        if (groupData.tasks.length > 0) {
                            groupData.hasAnyTasks = true;
                            subGroupsArray.push(groupData);
                        }
                    });
                    if (subGroupsArray.length > 0) {
                        aggregatePOCMasterPhase.subGroups = subGroupsArray;
                        aggregatePOCMasterPhase.hasAnyTasks = true;
                        aggregatePOCMasterPhase.totalRevenueBacklogForPhase = subGroupsArray.reduce((phaseSum, group) =>
                            phaseSum + group.tasks.reduce((taskSum, product) => taskSum + (product.revenueBacklog || 0), 0), 0
                        );
                        tempAggregate.push(aggregatePOCMasterPhase);
                    }
                }

                // Process and group Milestone Products by Product Family
                if (tempMilestoneProducts.length > 0) {
                    let productFamilyMap = new Map();
                    tempMilestoneProducts.forEach(product => {
                        const family = product.productFamily || 'Uncategorized';
                        if (!productFamilyMap.has(family)) {
                            productFamilyMap.set(family, { name: family, products: [], totalRevenueBacklog: 0 });
                        }
                        productFamilyMap.get(family).products.push(product);
                        productFamilyMap.get(family).totalRevenueBacklog += (product.revenueBacklog || 0);
                    });
                    this.milestoneProductFamilyGroups = Array.from(productFamilyMap.values());
                }

                // Assign Time and Expenses products
                this.milestoneTimeAndExpensesProducts = tempMilestoneTimeAndExpenses;
            }
            
            // Assign processed data to tracked properties
            this.professionalServicesPhases = tempProfessionalServices;
            this.aggregatePOCPhases = tempAggregate;
            this.maintenancePhases = tempMaintenance;
            this.managedServicesPhases = tempManagedServices;
            this.milestoneHardwareProducts = tempMilestoneHardware;
            this.milestoneAdvancementFeeProducts = tempMilestoneAdvancementFee;
            
            this.error = undefined;
            this.isLoading = false;
            
            console.log('projectRevenueRec - Final Processed Data:', {
                professionalServices: this.professionalServicesPhases,
                aggregate: this.aggregatePOCPhases,
                maintenance: this.maintenancePhases,
                managedServices: this.managedServicesPhases,
                milestoneHardware: this.milestoneHardwareProducts,
                advancementFee: this.milestoneAdvancementFeeProducts,
                milestoneProductFamily: this.milestoneProductFamilyGroups,
                milestoneTimeAndExpenses: this.milestoneTimeAndExpensesProducts
            });

        } else if (error) {
            console.error('projectRevenueRec - Error fetching revenue data:', error);
            this.error = this.reduceErrors(error).join(', ');
            this.isLoading = false;
            this.showErrorToast('Error Loading Revenue Data', this.error, 'error');
        } else {
             this.isLoading = false;
        }
    }

    /**
     * Calculates the Percentage of Completion (POC) for time-based revenue recognition.
     * @param {string} startDateStr The start date string (e.g., 'YYYY-MM-DD').
     * @param {number} termMonths The total term in months.
     * @returns {number} The calculated POC as a percentage (0-100).
     */
    calculateTimeBasedPOC(startDateStr, termMonths) {
        try {
            const today = new Date();
            const startDate = new Date(startDateStr + 'T00:00:00Z'); 
            if (isNaN(startDate.getTime())) {
                 console.error('Invalid start date provided for time-based POC:', startDateStr);
                 return 0;
            }
            const endDate = new Date(startDate);
            endDate.setUTCMonth(startDate.getUTCMonth() + termMonths); 
             if (isNaN(endDate.getTime())) {
                 console.error('Could not calculate valid end date for time-based POC from start date and term.');
                 return 0;
            }

            if (today < startDate) { return 0; }
            if (today >= endDate) { return 100; }

            const elapsedMilliseconds = today.getTime() - startDate.getTime();
            const totalMilliseconds = endDate.getTime() - startDate.getTime();

            if (totalMilliseconds <= 0) { 
                return 0;
            }

            const poc = (elapsedMilliseconds / totalMilliseconds) * 100;
            return Math.max(0, Math.min(poc, 100));
        } catch (e) {
            console.error('projectRevenueRec - Error calculating time-based POC:', e);
            return 0;
        }
    }

    // Getter to check if Professional Services data exists
    get hasProfessionalServicesPhases() {
        return this.professionalServicesPhases && this.professionalServicesPhases.length > 0;
    }

    // Getter for Milestone Hardware Products (retaining original name for HTML compatibility)
    get hasMilestoneHardwarePhases() { 
        return this.milestoneHardwareProducts && this.milestoneHardwareProducts.length > 0;
    }
    
    // Getter for Milestone Advancement Fee Products (retaining original name for HTML compatibility)
    get hasMilestoneAdvancementFeeTasks() { 
        return this.milestoneAdvancementFeeProducts && this.milestoneAdvancementFeeProducts.length > 0;
    }

    // Getter for Maintenance Phases
    get hasMaintenancePhases() {
        return this.maintenancePhases && this.maintenancePhases.length > 0;
    }

    // Getter for Managed Services Phases
    get hasManagedServicesPhases() {
        return this.managedServicesPhases && this.managedServicesPhases.length > 0;
    }

    // Getter for Aggregate POC Phases
    get hasAggregatePOCPhases() {
        return this.aggregatePOCPhases && this.aggregatePOCPhases.length > 0;
    }

    // Getter to check if Milestone Product Family data exists
    get hasMilestoneProductFamilyGroups() {
        return this.milestoneProductFamilyGroups && this.milestoneProductFamilyGroups.length > 0;
    }

    // NEW: Getter to check if Milestone Time and Expenses data exists
    get hasMilestoneTimeAndExpensesProducts() {
        return this.milestoneTimeAndExpensesProducts && this.milestoneTimeAndExpensesProducts.length > 0;
    }

    // This getter checks if any data section has content for rendering
    get hasAnyData() {
        return this.hasMilestoneHardwarePhases || this.hasMilestoneAdvancementFeeTasks ||
               this.hasMaintenancePhases || this.hasManagedServicesPhases ||
               this.hasAggregatePOCPhases || this.hasProfessionalServicesPhases || 
               this.hasMilestoneProductFamilyGroups || this.hasMilestoneTimeAndExpensesProducts;
    }

    // Getter for error text display
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

    // Utility to show toast notifications
    showErrorToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'sticky'
        });
        this.dispatchEvent(event);
    }

    // Utility to reduce error messages for display
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