import { LightningElement, api, wire, track } from "lwc";
import getResourceAssignments from "@salesforce/apex/WeeklyScheduleController.getResourceAssignments";
import getMonthlyActuals from "@salesforce/apex/WeeklyScheduleController.getMonthlyActuals";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class WeeklySchedule extends LightningElement {
  @api recordId;
  @track resourceAssignments = [];
  @track months = [];
  @track tableData = [];
  @track columnTotals = [];
  @track columnTotalsCost = [];
  @track columnTotalsRevenue = [];

  actuals = {};
  totalResources = 0;
  totalHours = 0;
  totalCost = 0;
  totalRevenue = 0;

  DEFAULT_COST_RATE = 100; // $100/hr default cost rate
  DEFAULT_BILL_RATE = 150; // $150/hr default bill rate

  _hasAssignmentsLoaded = false;
  _hasActualsLoaded = false;
  _probeLogged = false;

  @wire(getResourceAssignments, { recordId: "$recordId" })
  wiredResourceAssignments({ error, data }) {
    if (data) {
      this.resourceAssignments = data.assignments || [];
      this.totalResources = this.resourceAssignments.length;
      this._hasAssignmentsLoaded = true;
      this.initializeMonthlyData();
    } else if (error) {
      console.error("Error from Apex:", error);
      this.showToast(
        "Error",
        error.body?.message || "Unable to load resource assignments",
        "error"
      );
    } else {
      this.resourceAssignments = [];
      this.totalResources = 0;
    }
  }

  @wire(getMonthlyActuals, { recordId: "$recordId" })
  wiredMonthlyActuals({ error, data }) {
    if (data) {
      this.months = data.months || [];
      this.actuals = data.actuals || {};
      this._hasActualsLoaded = true;
      this.initializeMonthlyData();
    } else if (error) {
      console.error("Error loading monthly actuals:", error);
      this.showToast(
        "Error",
        error.body?.message || "Unable to load monthly actuals",
        "error"
      );
    } else {
      this.months = [];
      this.actuals = {};
    }
  }

  initializeMonthlyData() {
    if (!this._hasAssignmentsLoaded || !this._hasActualsLoaded) {
      return;
    }

    this._probeLogged = false;
    this.prepareTableData();
    this.calculateAllTotals();
  }

  prepareTableData() {
    if (!this.resourceAssignments || this.resourceAssignments.length === 0) {
      this.tableData = [];
      return;
    }

    this.tableData = this.resourceAssignments.map((assignment) => {
      const resourceId =
        assignment?.project_cloud__User__c ||
        assignment?.project_cloud__User__r?.Id ||
        "unknownResource";
      const taskId =
        assignment?.project_cloud__Resource_Summary__r
          ?.project_cloud__Project_Task__c ||
        assignment?.project_cloud__Resource_Summary__r
          ?.project_cloud__Project_Task__r?.Id ||
        "unknownTask";
      const key = `${resourceId}|${taskId}`;

      let rowTotalHours = 0;
      let rowTotalCost = 0;
      let rowTotalRevenue = 0;
      const totalAssignmentHours =
        this.calculateTotalAssignmentHours(assignment);

      const costRate =
        assignment?.project_cloud__User__r?.ccpe_r__Cost__c ||
        this.DEFAULT_COST_RATE;
      const priceRevSold =
        assignment?.project_cloud__Resource_Summary__r
          ?.project_cloud__Project_Task__r?.Price_Rev_Sold__c || 0;
      const estimatedHours =
        assignment?.project_cloud__Resource_Summary__r
          ?.project_cloud__Project_Task__r?.project_cloud__Estimated_Hours__c ||
        1;
      const billRate =
        estimatedHours > 0
          ? priceRevSold / estimatedHours
          : this.DEFAULT_BILL_RATE;

      const monthlyData = (this.months || []).map((month) => {
        const hours = this.actuals?.[key]?.[month] ?? 0;
        const cost = hours * costRate;
        const revenue = hours * billRate;

        rowTotalHours += hours;
        rowTotalCost += cost;
        rowTotalRevenue += revenue;

        return {
          month,
          key: `${key}-${month}`,
          hours,
          cost,
          revenue,
          costFormatted: this.formatCurrency(cost),
          revenueFormatted: this.formatCurrency(revenue),
          costKey: `${key}-${month}-cost`,
          revenueKey: `${key}-${month}-revenue`
        };
      });

      const allocationPercentage =
        totalAssignmentHours > 0
          ? Math.round((rowTotalHours / totalAssignmentHours) * 100)
          : 0;

      let allocationClass = "";
      if (allocationPercentage > 100) {
        allocationClass = "danger";
      } else if (allocationPercentage > 80) {
        allocationClass = "warning";
      }

      const remainingHours = Math.max(0, totalAssignmentHours - rowTotalHours);
      const taskName =
        assignment?.project_cloud__Resource_Summary__r
          ?.project_cloud__Project_Task__r?.Name || "Unknown Task";
      const firstName = assignment?.project_cloud__User__r?.FirstName || "";
      const lastName = assignment?.project_cloud__User__r?.LastName || "";
      const resourceName = [firstName, lastName]
        .filter((name) => !!name)
        .join(" ");
      const taskAndResource = resourceName
        ? `${taskName} - ${resourceName}`
        : taskName;

      return {
        id: assignment.Id,
        lookupKey: key,
        costRowKey: `${key}-cost`,
        revenueRowKey: `${key}-revenue`,
        taskAndResource,
        monthlyData,
        rowTotalHours,
        rowTotalCost,
        rowTotalRevenue,
        totalAssignmentHours,
        remainingHours,
        allocationPercentage,
        allocationClass,
        allocationStyle: `width: ${Math.min(allocationPercentage, 100)}%`,
        costRate,
        billRate,
        costRateFormatted: this.formatCurrency(costRate),
        billRateFormatted: this.formatCurrency(billRate)
      };
    });
  }

  calculateTotalAssignmentHours(assignment) {
    // V2 CHANGE: Instead of setting this on a 40-hour per week standard, setting this based on hours sold times resource allocation %.
    const hoursSold =
      assignment?.project_cloud__Resource_Summary__r
        ?.project_cloud__Project_Task__r?.project_cloud__Estimated_Hours__c ||
      0;
    const assignmentCount =
      assignment?.project_cloud__Resource_Summary__r
        ?.project_cloud__Resource_Assignment_Count__c || 1;
    return assignmentCount > 0 ? hoursSold / assignmentCount : 0;
  }

  calculateAllTotals() {
    this.calculateColumnTotals();
    this.calculateGrandTotals();
  }

  calculateColumnTotals() {
    this.columnTotals = [];
    this.columnTotalsCost = [];
    this.columnTotalsRevenue = [];

    (this.months || []).forEach((month) => {
      let totalHours = 0;
      let totalCost = 0;
      let totalRevenue = 0;

      this.tableData.forEach((row) => {
        const cell = row.monthlyData.find((c) => c.month === month);
        if (cell) {
          totalHours += cell.hours;
          totalCost += cell.cost;
          totalRevenue += cell.revenue;
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

    this.tableData.forEach((row) => {
      this.totalHours += row.rowTotalHours;
      this.totalCost += row.rowTotalCost;
      this.totalRevenue += row.rowTotalRevenue;
    });
  }

  get visibleMonths() {
    return this.months || [];
  }

  get visibleTableDataMonthly() {
    return this.tableData || [];
  }

  get visibleColumnTotalsMonthly() {
    return (this.months || []).map((month, index) => ({
      month,
      hours: this.columnTotals[index] || 0,
      cost: this.columnTotalsCost[index] || 0,
      revenue: this.columnTotalsRevenue[index] || 0,
      costFormatted: this.formatCurrency(this.columnTotalsCost[index] || 0),
      revenueFormatted: this.formatCurrency(
        this.columnTotalsRevenue[index] || 0
      )
    }));
  }

  get totalCostFormatted() {
    return this.formatCurrency(this.totalCost);
  }

  get totalRevenueFormatted() {
    return this.formatCurrency(this.totalRevenue);
  }

  get grandTotalHours() {
    return this.columnTotals.reduce((sum, col) => sum + col, 0);
  }

  get grandTotalCostFormatted() {
    const total = this.columnTotalsCost.reduce((sum, col) => sum + col, 0);
    return this.formatCurrency(total);
  }

  get grandTotalRevenueFormatted() {
    const total = this.columnTotalsRevenue.reduce((sum, col) => sum + col, 0);
    return this.formatCurrency(total);
  }

  renderedCallback() {
    if (this._probeLogged) {
      return;
    }

    const firstRow = this.tableData?.[0];
    const firstMonth = this.months?.[0];

    if (firstRow && firstMonth) {
      // eslint-disable-next-line no-console
      console.log(
        "Monthly actual probe:",
        this.actuals?.[firstRow.lookupKey]?.[firstMonth]
      );
      this._probeLogged = true;
    }
  }

  // Utility methods
  formatCurrency(value) {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD",
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(value || 0);
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
