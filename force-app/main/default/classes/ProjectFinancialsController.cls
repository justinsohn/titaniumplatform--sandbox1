/**
 * @description Controller to fetch Project Phase and Task financial data for the projectFinancials LWC.
 * Excludes phases named '3rd Party Fees' or 'Software'.
 * Includes Price/Rev (Sold) and Rev/Rec Actual.
 */
public with sharing class ProjectFinancialsController {

    // Set of phase names to exclude from the results. Case-insensitive matching will be applied.
    private static final Set<String> EXCLUDED_PHASE_NAMES = new Set<String>{
        '3rd party fees', 'software'
    };

    // Wrapper class to hold Phase information and its related Tasks with financial data
    public class PhaseFinancialWrapper {
        @AuraEnabled public Id phaseId { get; set; }
        @AuraEnabled public String phaseName { get; set; }
        @AuraEnabled public List<TaskFinancialWrapper> tasks { get; set; }
        // Totals will be calculated in LWC JavaScript

        public PhaseFinancialWrapper() {
            this.tasks = new List<TaskFinancialWrapper>();
        }
    }

    // Wrapper class to hold Task financial information
    public class TaskFinancialWrapper {
        @AuraEnabled public Id taskId { get; set; }
        @AuraEnabled public String taskName { get; set; }
        @AuraEnabled public Decimal priceRevSold { get; set; }        // price_rev_sold__c
        @AuraEnabled public Decimal revRecActual { get; set; }        // Rev_Rec_Actual__c
        @AuraEnabled public Decimal loeEstimatedCostSold { get; set; }// LOE_Estimated_Cost_Sold__c
        @AuraEnabled public Decimal ratioSold { get; set; }           // Ratio_Sold__c
        @AuraEnabled public Decimal costsActual { get; set; }         // ccpe_r__Cost__c
        @AuraEnabled public Decimal ratioActual { get; set; }         // Ratio_Actual__c

        // Hour and Rate fields
        @AuraEnabled public Decimal mhSold { get; set; }              // project_cloud__Estimated_Hours__c
        @AuraEnabled public Decimal mhRateSold { get; set; }          // MH_Rate_Sold__c
        @AuraEnabled public Decimal mhActual { get; set; }            // Approved_Hours__c
        @AuraEnabled public Decimal mhRateActual { get; set; }        // MH_Rate_Actual__c
        @AuraEnabled public Decimal mhRateVar { get; set; }           // MH_Rate_Var__c
    }

    /**
     * @description Fetches Phase and related Task financial data for a given Project Id.
     * @param projectId The Id of the project_cloud__Project__c record.
     * @return List<PhaseFinancialWrapper> A list of phases with their associated tasks and financial data.
     */
    @AuraEnabled(cacheable=true)
    public static List<PhaseFinancialWrapper> getProjectFinancialsData(Id projectId) {
        if (String.isBlank(projectId)) {
            return new List<PhaseFinancialWrapper>();
        }

        Map<Id, PhaseFinancialWrapper> phaseMap = new Map<Id, PhaseFinancialWrapper>();

        List<project_cloud__Project_Phase__c> allPhases = [
            SELECT Id, Name
            FROM project_cloud__Project_Phase__c
            WHERE project_cloud__Project__c = :projectId
            ORDER BY Name
        ];

        for (project_cloud__Project_Phase__c phase : allPhases) {
            if (phase.Name != null && !EXCLUDED_PHASE_NAMES.contains(phase.Name.toLowerCase())) {
                PhaseFinancialWrapper pfw = new PhaseFinancialWrapper();
                pfw.phaseId = phase.Id;
                pfw.phaseName = phase.Name;
                phaseMap.put(phase.Id, pfw);
            }
        }

        if (phaseMap.isEmpty()) {
            System.debug('No eligible phases found for project: ' + projectId);
            return new List<PhaseFinancialWrapper>();
        }

        // Query Project Tasks related to the filtered Phases,
        // and filter by Opportunity_Product__r.Revenue_Group_Formula__c
        // Assuming Opportunity_Product__c on Project Task is a lookup to OpportunityLineItem
        for (project_cloud__Project_Task__c task : [
            SELECT Id, Name, project_cloud__Project_Phase__c,
                   price_rev_sold__c,
                   Rev_Rec_Actual__c,
                   LOE_Estimated_Cost_Sold__c,
                   Ratio_Sold__c,
                   ccpe_r__Cost__c,
                   Ratio_Actual__c,
                   project_cloud__Estimated_Hours__c, // MH (Sold)
                   MH_Rate_Sold__c,                   // MH Rate (Sold)
                   Approved_Hours__c,                 // MH (Actual)
                   MH_Rate_Actual__c,                 // MH Rate (Actual)
                   MH_Rate_Var__c,                    // MH Rate (Var)
                   Opportunity_Product__c             // Needed for the WHERE clause filter
            FROM project_cloud__Project_Task__c
            WHERE project_cloud__Project_Phase__c IN :phaseMap.keySet()
            AND Name != 'MT-ANA-PAF-CORE'
            ORDER BY price_rev_sold__c DESC
        ]) {
            if (phaseMap.containsKey(task.project_cloud__Project_Phase__c)) {
                TaskFinancialWrapper tfw = new TaskFinancialWrapper();
                tfw.taskId = task.Id;
                tfw.taskName = task.Name;
                tfw.priceRevSold = task.price_rev_sold__c != null ? task.price_rev_sold__c : 0;
                tfw.revRecActual = task.Rev_Rec_Actual__c != null ? task.Rev_Rec_Actual__c : 0;
                tfw.loeEstimatedCostSold = task.LOE_Estimated_Cost_Sold__c != null ? task.LOE_Estimated_Cost_Sold__c : 0;
                tfw.ratioSold = task.Ratio_Sold__c != null ? task.Ratio_Sold__c : 0;
                tfw.costsActual = task.ccpe_r__Cost__c != null ? task.ccpe_r__Cost__c : 0;
                tfw.ratioActual = task.Ratio_Actual__c != null ? task.Ratio_Actual__c : 0;

                tfw.mhSold = task.project_cloud__Estimated_Hours__c != null ? task.project_cloud__Estimated_Hours__c : 0;
                tfw.mhRateSold = task.MH_Rate_Sold__c != null ? task.MH_Rate_Sold__c : 0;
                tfw.mhActual = task.Approved_Hours__c != null ? task.Approved_Hours__c : 0;
                tfw.mhRateActual = task.MH_Rate_Actual__c != null ? task.MH_Rate_Actual__c : 0;
                tfw.mhRateVar = task.MH_Rate_Var__c != null ? task.MH_Rate_Var__c : 0;

                phaseMap.get(task.project_cloud__Project_Phase__c).tasks.add(tfw);
            }
        }
        return phaseMap.values();
    }
}