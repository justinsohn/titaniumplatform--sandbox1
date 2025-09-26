trigger OrderValidation on Opportunity (before insert, before update) {

    // --- IMPORTANT: Replace these with your actual values ---
    String recurringRecordTypeDeveloperName = 'recurring'; 
    String nonDistinctRevenueImpactValue = 'Non-Distinct'; 

    Set<Id> oppIdsToCheck = new Set<Id>();
    Map<Id, Opportunity> oppsMeetingInitialCriteria = new Map<Id, Opportunity>();


    Map<Id, String> recordTypeIdToDeveloperNameMap = new Map<Id, String>();
    Id specificRecurringRtId = null;
    for(RecordType rt : [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType = 'Opportunity']) {
        recordTypeIdToDeveloperNameMap.put(rt.Id, rt.DeveloperName);
        if (rt.DeveloperName == recurringRecordTypeDeveloperName) {
            specificRecurringRtId = rt.Id;
        }
    }

    for (Opportunity opp : Trigger.new) {
        boolean isRecurringType = (opp.RecordTypeId != null && opp.RecordTypeId == specificRecurringRtId);
        
        boolean isNonDistinctRevenue = (opp.revenue_impact__c == nonDistinctRevenueImpactValue);

        if (isRecurringType || isNonDistinctRevenue) {
            if (Trigger.isUpdate) { 
                oppIdsToCheck.add(opp.Id);
            }
            oppsMeetingInitialCriteria.put(opp.Id, opp); 
        }
    }

    Map<Id, Integer> oppOrderCounts = new Map<Id, Integer>();
    if (!oppIdsToCheck.isEmpty()) {
        for (AggregateResult ar : [SELECT OpportunityId, COUNT(Id) orderCount
                                   FROM Order
                                   WHERE OpportunityId IN :oppIdsToCheck
                                   GROUP BY OpportunityId]) {
            oppOrderCounts.put((Id)ar.get('OpportunityId'), (Integer)ar.get('orderCount'));
        }
    }

    for (Opportunity opp : Trigger.new) {
        
        if (oppsMeetingInitialCriteria.containsKey(opp.Id)) {
            boolean hasNoOrders = false;
            if (Trigger.isInsert) {
                
                hasNoOrders = true;
            } else if (Trigger.isUpdate) {
                Integer orderCount = oppOrderCounts.get(opp.Id);
                if (orderCount == null || orderCount == 0) {
                    hasNoOrders = true;
                }
            }

            if (hasNoOrders) {
                String recordTypeNameForError = opp.RecordTypeId != null && recordTypeIdToDeveloperNameMap.containsKey(opp.RecordTypeId) ? recordTypeIdToDeveloperNameMap.get(opp.RecordTypeId) : 'the specified type';
                opp.addError('This Opportunity (' + opp.Name + ') cannot be saved. If the Record Type is Recurring or Revenue Impact is \'' + nonDistinctRevenueImpactValue +
                             '\', it must have at least one related Order record.');
            }
        }
    }
}