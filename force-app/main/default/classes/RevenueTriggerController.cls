public with sharing class RevenueTriggerController {

    @AuraEnabled(cacheable=true)
    public static project_cloud__Project__c getProject(Id projectId) {
        return [
            SELECT
                Id,
                Actual_AC_Delivery_Date__c,
                Forecasted_AC_Delivery_Date__c,
                Actual_HW_Delivery_Date__c,
                Forecasted_HW_Start_Date__c,
                Actual_MS_Start_Date__c,
                Forecasted_MS_Start_Date__c,
                Actual_TE_Completion_Date__c,
                Forecasted_TE_Start_Date__c,
                Actual_MT_Start_Date__c,
                Forecasted_MT_Start_Date__c,
                Actual_HW_MT_Start_Date__c,
                Forecasted_HW_MT_Start_Date__c,
                HW_MT_Term__c,
                MS_Term__c,
                MT_Term__c,
                MT_Revenue__c,
                MS_Revenue__c,
                Hardware_MT_Revenue__c,
                HW_Revenue__c,
                PAF_AC_SKU_Revenue__c,
                TE_Revenue__c,
                MT_POC__c,
                MS_POC__c,
                HW_MT__c
            FROM project_cloud__Project__c
            WHERE Id = :projectId
            LIMIT 1
        ];
    }

    @AuraEnabled
    public static project_cloud__Project__c saveProject(project_cloud__Project__c projectToUpdate) {
        try {
            update projectToUpdate;
            return projectToUpdate;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}