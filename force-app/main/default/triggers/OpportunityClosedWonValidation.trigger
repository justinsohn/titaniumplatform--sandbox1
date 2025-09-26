trigger OpportunityClosedWonValidation on Opportunity (before update) {
    // Collect Opportunity Ids that are moving to Closed Won
    Set<Id> oppIdsToCheck = new Set<Id>();

    for (Opportunity opp : Trigger.new) {
        Opportunity oldOpp = Trigger.oldMap.get(opp.Id);

        // Only check when Stage is changing to Closed Won
        if (opp.StageName == 'Closed Won' && oldOpp.StageName != 'Closed Won') {
            oppIdsToCheck.add(opp.Id);
        }
    }

    if (!oppIdsToCheck.isEmpty()) {
        // Query all Opportunity Products for these Opps
        List<OpportunityLineItem> oliList = [
            SELECT Id, Revenue_Start_Date__c, Revenue_End_Date__c, OpportunityId
            FROM OpportunityLineItem
            WHERE OpportunityId IN :oppIdsToCheck
        ];

        // Map to track which Opps have errors
        Map<Id, Boolean> oppHasError = new Map<Id, Boolean>();

        for (OpportunityLineItem oli : oliList) {
            if (oli.Revenue_Start_Date__c == null || oli.Revenue_End_Date__c == null) {
                oppHasError.put(oli.OpportunityId, true);
            }
        }

        // Add errors back to the Opportunity record being saved
        for (Opportunity opp : Trigger.new) {
            if (oppIdsToCheck.contains(opp.Id) && oppHasError.containsKey(opp.Id)) {
                opp.addError('All Opportunity Products must have Revenue Start and Revenue End Dates before closing Won.');
            }
        }
    }
}