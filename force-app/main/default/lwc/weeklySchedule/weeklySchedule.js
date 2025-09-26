import { LightningElement, api, wire, track } from 'lwc';
import getResourceAssignments from '@salesforce/apex/WeeklyScheduleController.getResourceAssignments';
import saveWeeklySchedules from '@salesforce/apex/WeeklyScheduleController.saveWeeklySchedules';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class WeeklySchedule extends LightningElement {
    @api recordId;
    @track resourceAssignments = [];
    @track weeks = [];
    @track weeklySchedules = new Map();
    @track tableData = [];
    @track columnTotals = [];
    @track columnTotalsCost = [];
    @track columnTotalsRevenue = [];
    
    // New properties for enhanced functionality
    @track actuals = {};
    @track currentWeekIndex = 0;
    @track visibleWeeksCount = 5; // Number of weeks to show at once
    @track totalResources = 0;
    @track totalHours = 0;
    @track totalCost = 0;
    @track totalRevenue = 0;

    // Default rates if not provided
    DEFAULT_COST_RATE = 100; // $100/hr default cost rate
    DEFAULT_BILL_RATE = 150; // $150/hr default bill rate

    @wire(getResourceAssignments, { recordId: '$recordId' })
    wiredResourceAssignments({ error, data }) {
        if (data) {
            console.log('Received data from Apex:', JSON.parse(JSON.stringify(data)));
            this.resourceAssignments = data.assignments;
            this.actuals = data.actualHours;
            this.totalResources = this.resourceAssignments.length;
            this.initializeWeeklySchedules();
            this.calculateWeeks();
            this.setInitialWeekView();
            this.prepareTableData();
            this.calculateAllTotals();
        } else if (error) {
            console.error('Error from Apex:', error);
            this.showToast('Error', error.body.message, 'error');
        } else {
            // Initialize empty data
            this.resourceAssignments = [];
            this.totalResources = 0;
            this.weeks = [];
            this.tableData = [];
        }
    }

    calculateWeeks() {
        if (!this.resourceAssignments || this.resourceAssignments.length === 0) {
            this.weeks = [];
            return;
        }

        let minStartDate = new Date('9999-12-31');
        let maxEndDate = new Date('1900-01-01');

        this.resourceAssignments.forEach(assignment => {
            let startDate = new Date(assignment.project_cloud__Calculated_Start__c);
            let endDate = new Date(assignment.project_cloud__Calculated_End__c);

            if (startDate < minStartDate) {
                minStartDate = startDate;
            }
            if (endDate > maxEndDate) {
                maxEndDate = endDate;
            }
        });

        this.weeks = [];
        let currentDate = new Date(minStartDate);
        currentDate.setDate(currentDate.getDate() - currentDate.getDay() - 1); // Start from the beginning of the week

        while (currentDate <= maxEndDate) {
            const endOfWeek = new Date(currentDate);
            endOfWeek.setDate(endOfWeek.getDate() + 6);
            
            this.weeks.push({
                startOfWeek: new Date(currentDate),
                startOfWeekISO: currentDate.toISOString().slice(0, 10),
                label: currentDate.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
                dateRange: `${currentDate.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })} - ${endOfWeek.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}`,
                key: currentDate.toISOString().slice(0, 10)
            });
            currentDate.setDate(currentDate.getDate() + 7);
        }
    }

    initializeWeeklySchedules() {
        this.weeklySchedules = new Map();
        if (!this.resourceAssignments) return;
        
        this.resourceAssignments.forEach(assignment => {
            if (assignment.Weekly_Schedules__r) {
                assignment.Weekly_Schedules__r.forEach(schedule => {
                    const key = `${assignment.Id}-${schedule.Week_Start_Date__c}`;
                    this.weeklySchedules.set(key, schedule);
                });
            }
        });
    }

    prepareTableData() {
        if (!this.resourceAssignments || this.resourceAssignments.length === 0) {
            this.tableData = [];
            return;
        }

        // Gets today's date to determine which cells represent past vs. future weeks.
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        this.tableData = this.resourceAssignments.map(assignment => {
            let rowTotalHours = 0;
            let rowTotalCost = 0;
            let rowTotalRevenue = 0;
            let totalAssignmentHours = this.calculateTotalAssignmentHours(assignment);
            
            // Get cost rate from user and calculate bill rate from task
            const costRate = assignment.project_cloud__User__r?.ccpe_r__Cost__c || this.DEFAULT_COST_RATE;
            
            // Calculate bill rate: Price_Rev_Sold__c / Estimated_Hours__c
            const priceRevSold = assignment.project_cloud__Resource_Summary__r?.project_cloud__Project_Task__r?.Price_Rev_Sold__c || 0;
            const estimatedHours = assignment.project_cloud__Resource_Summary__r?.project_cloud__Project_Task__r?.project_cloud__Estimated_Hours__c || 1;
            const billRate = estimatedHours > 0 ? (priceRevSold / estimatedHours) : this.DEFAULT_BILL_RATE;
            
            const weeklyData = this.weeks.map((week, weekIndex) => {
                // Determine if week is in the past.
                const endOfWeek = new Date(week.startOfWeek);
                endOfWeek.setDate(endOfWeek.getDate() + 6);
                const isPast = endOfWeek < today;

                // --- 1. LOOKUP ACTUAL HOURS ---
                // Get the User Id for the current assignment
                const userId = assignment.project_cloud__User__r.Id;
                // Construct the key to find the actual hours for this user and week
                const actualsKey = `${userId}-${week.startOfWeekISO}`;
                // --- DEBUGGING LOGS ---
                console.log('Looking for key:', actualsKey); 
                console.log('Available keys in this.actuals:', JSON.stringify(this.actuals, null, 2));
                // ----------------------
                // Get the value from the map, defaulting to 0 if not found
                const actualHours = this.actuals[actualsKey] || 0;

                // --- 2. GET PLANNED HOURS ---
                const key = `${assignment.Id}-${week.startOfWeekISO}`;
                const schedule = this.weeklySchedules.get(key);
                const plannedHours = schedule ? schedule.Planned_Hours__c : 0;
                
                // --- 3. DECIDE WHICH HOURS TO DISPLAY ---
                const displayHours = isPast ? actualHours : plannedHours;

                // --- 4. CALCULATE FINANCIALS BASED ON DISPLAY HOURS ---
                const plannedCost = displayHours * costRate;
                const plannedRevenue = displayHours * billRate;
                
                rowTotalHours += displayHours;
                rowTotalCost += plannedCost;
                rowTotalRevenue += plannedRevenue;
                
                return {
                    week: week,
                    plannedHours: displayHours,
                    plannedCost: plannedCost,
                    plannedRevenue: plannedRevenue,
                    plannedCostFormatted: this.formatCurrency(plannedCost),
                    plannedRevenueFormatted: this.formatCurrency(plannedRevenue),
                    assignmentId: assignment.Id,
                    weekStartDateISO: week.startOfWeekISO,
                    isPastWeek: isPast,
                    uniqueKey: `${assignment.Id}-${week.key}`,
                    costKey: `${assignment.Id}-${week.key}-cost`,
                    revenueKey: `${assignment.Id}-${week.key}-revenue`
                };
            });
            
            // Calculate allocation percentage
            const allocationPercentage = totalAssignmentHours > 0 
                ? Math.round((rowTotalHours / totalAssignmentHours) * 100) 
                : 0;
            
            // Determine allocation class for styling
            let allocationClass = '';
            if (allocationPercentage > 100) {
                allocationClass = 'danger';
            } else if (allocationPercentage > 80) {
                allocationClass = 'warning';
            }
            
            // Calculate remaining available hours
            const remainingHours = Math.max(0, totalAssignmentHours - rowTotalHours);
            
            return {
                id: assignment.Id,
                costRowKey: `${assignment.Id}-cost`,
                revenueRowKey: `${assignment.Id}-revenue`,
                taskAndResource: `${assignment.project_cloud__Resource_Summary__r.project_cloud__Project_Task__r.Name} - ${assignment.project_cloud__User__r.FirstName} ${assignment.project_cloud__User__r.LastName}`,
                weeklyData: weeklyData,
                rowTotalHours: rowTotalHours,
                rowTotalCost: rowTotalCost,
                rowTotalRevenue: rowTotalRevenue,
                totalAssignmentHours: totalAssignmentHours,
                remainingHours: remainingHours,
                allocationPercentage: allocationPercentage,
                allocationClass: allocationClass,
                allocationStyle: `width: ${Math.min(allocationPercentage, 100)}%`,
                costRate: costRate,
                billRate: billRate,
                costRateFormatted: this.formatCurrency(costRate),
                billRateFormatted: this.formatCurrency(billRate)
            };
        });
    }

    calculateTotalAssignmentHours(assignment) {
        // V2 CHANGE: Instead of setting this on a 40-hour per week standard, setting this based on hours sold times resource allocation %.
        const startDate = new Date(assignment.project_cloud__Calculated_Start__c);
        const endDate = new Date(assignment.project_cloud__Calculated_End__c);
        const weeks = Math.ceil((endDate - startDate) / (7 * 24 * 60 * 60 * 1000));
        const hoursSold = assignment.project_cloud__Resource_Summary__r?.project_cloud__Project_Task__r?.project_cloud__Estimated_Hours__c || 1;
        const assignmentCount = assignment.project_cloud__Resource_Summary__r?.project_cloud__Resource_Assignment_Count__c || 1;
        return hoursSold / assignmentCount;
    }

    calculateAllTotals() {
        this.calculateColumnTotals();
        this.calculateGrandTotals();
    }

    calculateColumnTotals() {
        this.columnTotals = [];
        this.columnTotalsCost = [];
        this.columnTotalsRevenue = [];
        
        this.weeks.forEach(week => {
            let totalHours = 0;
            let totalCost = 0;
            let totalRevenue = 0;
            
            this.tableData.forEach(row => {
                const cell = row.weeklyData.find(c => c.week.startOfWeekISO === week.startOfWeekISO);
                if (cell) {
                    totalHours += cell.plannedHours;
                    totalCost += cell.plannedCost;
                    totalRevenue += cell.plannedRevenue;
                }
            });
            
            this.columnTotals.push(totalHours);
            this.columnTotalsCost.push(totalCost);
            this.columnTotalsRevenue.push(totalRevenue);
        });
    }

    calculateGrandTotals() {
        this.totalHours = 0;
        this.totalCost = 0;
        this.totalRevenue = 0;
        
        this.tableData.forEach(row => {
            this.totalHours += row.rowTotalHours;
            this.totalCost += row.rowTotalCost;
            this.totalRevenue += row.rowTotalRevenue;
        });
    }

    setInitialWeekView() {
        // Do nothing if the weeks array hasn't been calculated yet
        if (!this.weeks || this.weeks.length === 0) {
            return;
        }

        const today = new Date();
        // Use findLastIndex() to get the index of the last week that has already started.
        // This correctly identifies the current week.
        let todayIndex = this.weeks.findLastIndex(week => week.startOfWeek <= today);

        // If the project starts in the future, findLastIndex returns -1. 
        // In that case, we'll just default to the beginning of the timeline.
        if (todayIndex === -1) {
            todayIndex = 0;
        }
        
        // Set the starting index for the view
        this.currentWeekIndex = todayIndex;
    }

    // Computed properties for the template
    get visibleWeeks() {
        if (!this.weeks || this.weeks.length === 0) return [];
        return this.weeks.slice(this.currentWeekIndex, this.currentWeekIndex + this.visibleWeeksCount);
    }

    get visibleTableData() {
        if (!this.tableData || this.tableData.length === 0) return [];
        
        return this.tableData.map(row => ({
            ...row,
            visibleWeeklyData: row.weeklyData.slice(this.currentWeekIndex, this.currentWeekIndex + this.visibleWeeksCount)
        }));
    }

    get visibleColumnTotals() {
        if (!this.weeks || this.weeks.length === 0) return [];
        
        const startIdx = this.currentWeekIndex;
        const endIdx = this.currentWeekIndex + this.visibleWeeksCount;
        
        return this.weeks.slice(startIdx, endIdx).map((week, idx) => ({
            key: week ? week.key : `week-${idx}`,
            hours: this.columnTotals[startIdx + idx] || 0,
            cost: this.columnTotalsCost[startIdx + idx] || 0,
            revenue: this.columnTotalsRevenue[startIdx + idx] || 0,
            costFormatted: this.formatCurrency(this.columnTotalsCost[startIdx + idx] || 0),
            revenueFormatted: this.formatCurrency(this.columnTotalsRevenue[startIdx + idx] || 0)
        }));
    }

    get currentWeekRangeLabel() {
        if (this.visibleWeeks.length > 0) {
            const firstWeek = this.visibleWeeks[0];
            const lastWeek = this.visibleWeeks[this.visibleWeeks.length - 1];

            // Define the range to include the year
            const dateOptions = { month: 'short', day: 'numeric', year: 'numeric' };
            const startDate = firstWeek.startOfWeek.toLocaleDateString('en-US', dateOptions);
            const endDate = lastWeek.startOfWeek.toLocaleDateString('en-US', dateOptions);

            return `${startDate} - ${endDate}`;
        }
        return '';
    }

    get isAtStart() {
        return this.currentWeekIndex === 0;
    }

    get isAtEnd() {
        return this.currentWeekIndex + this.visibleWeeksCount >= this.weeks.length;
    }

    get totalCostFormatted() {
        return this.formatCurrency(this.totalCost);
    }

    get totalRevenueFormatted() {
        return this.formatCurrency(this.totalRevenue);
    }

    get grandTotalHours() {
        return this.visibleColumnTotals.reduce((sum, col) => sum + col.hours, 0);
    }

    get grandTotalCostFormatted() {
        const total = this.visibleColumnTotals.reduce((sum, col) => sum + col.cost, 0);
        return this.formatCurrency(total);
    }

    get grandTotalRevenueFormatted() {
        const total = this.visibleColumnTotals.reduce((sum, col) => sum + col.revenue, 0);
        return this.formatCurrency(total);
    }

    // Event handlers
    handlePreviousWeeks() {
        if (this.currentWeekIndex > 0) {
            this.currentWeekIndex = Math.max(0, this.currentWeekIndex - this.visibleWeeksCount);
        }
    }

    handleNextWeeks() {
        if (this.currentWeekIndex + this.visibleWeeksCount < this.weeks.length) {
            this.currentWeekIndex = Math.min(
                this.weeks.length - this.visibleWeeksCount, 
                this.currentWeekIndex + this.visibleWeeksCount
            );
        }
    }

    handleHoursChange(event) {
        const assignmentId = event.target.dataset.assignmentId;
        const weekStartDateISO = event.target.dataset.weekStartDate;
        const hours = parseFloat(event.target.value) || 0;
        const key = `${assignmentId}-${weekStartDateISO}`;

        // Find the assignment to get rates
        const assignment = this.resourceAssignments.find(a => a.Id === assignmentId);
        const costRate = assignment?.project_cloud__User__r?.ccpe_r__Cost__c || this.DEFAULT_COST_RATE;
        
        // Calculate bill rate: Price_Rev_Sold__c / Estimated_Hours__c
        const priceRevSold = assignment?.project_cloud__Resource_Summary__r?.project_cloud__Project_Task__r?.Price_Rev_Sold__c || 0;
        const estimatedHours = assignment?.project_cloud__Resource_Summary__r?.project_cloud__Project_Task__r?.project_cloud__Estimated_Hours__c || 1;
        const billRate = estimatedHours > 0 ? (priceRevSold / estimatedHours) : this.DEFAULT_BILL_RATE;

        let schedule = this.weeklySchedules.get(key);
        if (!schedule) {
            schedule = {
                sobjectType: 'Weekly_Schedule__c',
                Resource_Assignment__c: assignmentId,
                Week_Start_Date__c: weekStartDateISO,
                Planned_Hours__c: 0,
                Planned_Cost__c: 0,
                Planned_Revenue__c: 0
            };
        }

        // Update hours and calculate cost/revenue
        schedule.Planned_Hours__c = hours;
        schedule.Planned_Cost__c = hours * costRate;
        schedule.Planned_Revenue__c = hours * billRate;
        
        this.weeklySchedules.set(key, schedule);

        // Re-calculate totals after a change
        this.prepareTableData();
        this.calculateAllTotals();
    }

    handleSave() {
        const schedulesToSave = Array.from(this.weeklySchedules.values());

        saveWeeklySchedules({ weeklySchedules: schedulesToSave })
            .then(() => {
                this.showToast('Success', 'Weekly schedules saved successfully', 'success');
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
            });
    }

    handleCancel() {
        // Navigate back to the record page
        window.location.href = `/${this.recordId}`;
    }

    // Utility methods
    formatCurrency(value) {
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        }).format(value);
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}