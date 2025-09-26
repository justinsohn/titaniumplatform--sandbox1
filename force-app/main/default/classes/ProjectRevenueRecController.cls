public with sharing class ProjectRevenueRecController {

    // Wrapper class to hold the overall data structure returned to the LWC
    public class ProjectRevenueDataWrapper {
        @AuraEnabled public Date actualStartDate { get; set; }
        @AuraEnabled public Decimal termInMonths { get; set; }
        @AuraEnabled public List<PhaseWrapper> phases { get; set; } // For Project_Phase__c records
        @AuraEnabled public List<TaskWrapper> opportunityProducts { get; set; } // For OpportunityLineItem records

        public ProjectRevenueDataWrapper() {
            this.phases = new List<PhaseWrapper>();
            this.opportunityProducts = new List<TaskWrapper>();
        }
    }

    // Wrapper class to hold Phase information and its related Tasks
    public class PhaseWrapper {
        @AuraEnabled public Id phaseId { get; set; }
        @AuraEnabled public String phaseName { get; set; }
        @AuraEnabled public Boolean useAggregate { get; set; }
        @AuraEnabled public Decimal aggregatePOC { get; set; }
        @AuraEnabled public List<TaskWrapper> tasks { get; set; }
        // Properties for totals, calculated in JS (These will be populated in LWC)
        @AuraEnabled public Decimal totalBaselineHours { get; set; }
        @AuraEnabled public Decimal totalApprovedHours { get; set; }
        @AuraEnabled public Decimal totalPriceRevSold { get; set; }
        @AuraEnabled public Decimal totalRevRecActual { get; set; }
        @AuraEnabled public Decimal totalRevenueBacklog { get; set; }

        public PhaseWrapper() {
            this.tasks = new List<TaskWrapper>();
        }
    }

    // Wrapper class to hold Task/Product information (reused for both Project Tasks and Opportunity Products)
    public class TaskWrapper {
        @AuraEnabled public Id taskId { get; set; }
        @AuraEnabled public String taskName { get; set; }
        @AuraEnabled public Decimal additionalHours { get; set; }
        @AuraEnabled public Decimal contingencyHours { get; set; }
        @AuraEnabled public Decimal estimatedHours { get; set; } // Opp LOE MH (Sold)
        @AuraEnabled public Decimal taskPOC { get; set; } // This will be OpportunityLineItem.POC__c for products
        @AuraEnabled public Decimal approvedHours { get; set; }
        @AuraEnabled public Decimal baselineHours { get; set; }
        @AuraEnabled public Decimal priceRevSold { get; set; }
        @AuraEnabled public Decimal revRecActual { get; set; }
        @AuraEnabled public Decimal revenueBacklog { get; set; }
        @AuraEnabled public String opportunityProductRevenueGroupFormula { get; set; }
        @AuraEnabled public String recordSource { get; set; } // To distinguish between 'ProjectTask' and 'OpportunityProduct' in JS
        @AuraEnabled public String revenueModel { get; set; } // New: From OpportunityLineItem.Revenue_Model__c
        @AuraEnabled public String productFamily { get; set; } // New: From PricebookEntry.Product2.Family

    }

    /**
     * @description Fetches Project details, Phase, and related Task/Opportunity Product data for a given Project Id.
     * @param projectId The Id of the project_cloud__Project__c record.
     * @return ProjectRevenueDataWrapper A wrapper containing project dates/term and a list of phases with tasks/products.
     */
    @AuraEnabled(cacheable=true)
    public static ProjectRevenueDataWrapper getRevenueRecData(Id projectId) {
        ProjectRevenueDataWrapper resultWrapper = new ProjectRevenueDataWrapper();

        if (String.isBlank(projectId)) {
            return resultWrapper;
        }

        project_cloud__Project__c proj;
        try {
            proj = [
                SELECT Id, Name, Actual_MT_Start_Date__c, MS_Term__c, ccpe_ocp__Opportunity__c
                FROM project_cloud__Project__c
                WHERE Id = :projectId
                LIMIT 1
            ];
            resultWrapper.actualStartDate = proj.Actual_MT_Start_Date__c;
            resultWrapper.termInMonths = proj.MS_Term__c != null ? proj.MS_Term__c : 0;
        } catch (QueryException e) {
            System.debug('Error querying project ' + projectId + ' for projectRevenueRec LWC: ' + e.getMessage());
            return resultWrapper;
        }

        // 1. Query Project Phases related to the Project
        Map<Id, PhaseWrapper> phaseMap = new Map<Id, PhaseWrapper>();
        List<project_cloud__Project_Phase__c> projectPhases = [
            SELECT Id, Name, Use_Aggregate__c, Aggregate_POC__c
            FROM project_cloud__Project_Phase__c
            WHERE project_cloud__Project__c = :projectId
            ORDER BY Name
        ];

        for (project_cloud__Project_Phase__c phase : projectPhases) {
            PhaseWrapper pw = new PhaseWrapper();
            pw.phaseId = phase.Id;
            pw.phaseName = phase.Name;
            pw.useAggregate = phase.Use_Aggregate__c;
            pw.aggregatePOC = phase.Aggregate_POC__c != null ? phase.Aggregate_POC__c : 0;
            phaseMap.put(phase.Id, pw);
        }

        // Define phase names that should use Project Tasks as their data source
        Set<String> projectTaskPhaseNames = new Set<String>{
            'professional services',
            'maintenance',
            'managed services'
        };

        // 2. Query Project Tasks for Professional Services, Maintenance & Managed Services
        Set<Id> projectTaskPhaseIds = new Set<Id>();
        for(project_cloud__Project_Phase__c phase : projectPhases) {
            if(projectTaskPhaseNames.contains(phase.Name.toLowerCase().trim())) {
                projectTaskPhaseIds.add(phase.Id);
            }
        }

        if (!projectTaskPhaseIds.isEmpty()) {
            for (project_cloud__Project_Task__c task : [
                SELECT Id, Name, Additional_Hours__c, Contingency_Hours__c,
                       project_cloud__Estimated_Hours__c, POC__c, Approved_Hours__c,
                       Project_Baseline_Hours__c, price_rev_sold__c, Rev_Rec_Actual__c, revenue_backlog__c,
                       project_cloud__Project_Phase__c
                FROM project_cloud__Project_Task__c
                WHERE project_cloud__Project_Phase__c IN :projectTaskPhaseIds
                AND price_rev_sold__c != NULL AND price_rev_sold__c != 0 // Filter out tasks where Price/Rev (Sold) is 0 or empty
                ORDER BY Name
            ]) {
                if (phaseMap.containsKey(task.project_cloud__Project_Phase__c)) {
                    TaskWrapper tw = new TaskWrapper();
                    tw.taskId = task.Id;
                    tw.taskName = task.Name;
                    tw.additionalHours = task.Additional_Hours__c != null ? task.Additional_Hours__c : 0;
                    tw.contingencyHours = task.Contingency_Hours__c != null ? task.Contingency_Hours__c : 0;
                    tw.estimatedHours = task.project_cloud__Estimated_Hours__c != null ? task.project_cloud__Estimated_Hours__c : 0;
                    tw.taskPOC = task.POC__c != null ? task.POC__c : 0;
                    tw.approvedHours = task.Approved_Hours__c != null ? task.Approved_Hours__c : 0;
                    tw.baselineHours = task.Project_Baseline_Hours__c != null ? task.Project_Baseline_Hours__c : 0;
                    tw.priceRevSold = task.price_rev_sold__c != null ? task.price_rev_sold__c : 0;
                    tw.revRecActual = task.Rev_Rec_Actual__c != null ? task.Rev_Rec_Actual__c : 0;
                    tw.revenueBacklog = task.revenue_backlog__c != null ? task.revenue_backlog__c : 0;
                    tw.opportunityProductRevenueGroupFormula = null; // Not applicable for Project Tasks
                    tw.recordSource = 'ProjectTask';
                    tw.revenueModel = null; // Not applicable for Project Tasks
                    tw.productFamily = null; // Not applicable for Project Tasks
                    phaseMap.get(task.project_cloud__Project_Phase__c).tasks.add(tw);
                }
            }
        }

        // 3. Query Opportunity Products for all other revenue types
        Set<Id> opportunityIds = new Set<Id>();
        if (proj != null && proj.ccpe_ocp__Opportunity__c != null) {
            opportunityIds.add(proj.ccpe_ocp__Opportunity__c);
        }

        List<TaskWrapper> allOpportunityProducts = new List<TaskWrapper>();

        if (!opportunityIds.isEmpty()) {
            for (OpportunityLineItem oli : [
                SELECT Id, PricebookEntry.Product2.Name, TotalPrice, Quantity,
                       POC__c, Rev_Rec_Actual__c, Revenue_Backlog__c,
                       Revenue_Group_Formula__c, // Field is directly on OpportunityLineItem
                       Revenue_Model__c, // New: Revenue Model on OpportunityLineItem
                       PricebookEntry.Product2.Family // New: Product Family from Product2
                FROM OpportunityLineItem
                WHERE OpportunityId IN :opportunityIds
                ORDER BY PricebookEntry.Product2.Name
            ]) {
                TaskWrapper tw = new TaskWrapper();
                tw.taskId = oli.Id;
                tw.taskName = oli.PricebookEntry.Product2.Name;
                tw.priceRevSold = oli.TotalPrice != null ? oli.TotalPrice : 0;
                tw.taskPOC = oli.POC__c != null ? oli.POC__c : 0;
                tw.revRecActual = oli.Rev_Rec_Actual__c != null ? oli.Rev_Rec_Actual__c : 0;
                tw.revenueBacklog = oli.Revenue_Backlog__c != null ? oli.Revenue_Backlog__c : 0;
                tw.opportunityProductRevenueGroupFormula = oli.Revenue_Group_Formula__c;
                tw.recordSource = 'OpportunityProduct';
                tw.revenueModel = oli.Revenue_Model__c;
                tw.productFamily = oli.PricebookEntry.Product2.Family;

                tw.additionalHours = 0;
                tw.contingencyHours = 0;
                tw.estimatedHours = 0;
                tw.approvedHours = 0;
                tw.baselineHours = 0;

                allOpportunityProducts.add(tw);
            }
        }

        resultWrapper.phases.addAll(phaseMap.values());
        resultWrapper.opportunityProducts = allOpportunityProducts;

        return resultWrapper;
    }
}