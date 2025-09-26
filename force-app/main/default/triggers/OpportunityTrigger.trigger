trigger OpportunityTrigger on Opportunity (before delete, after delete, after update, after undelete) {
    zsfjira.ZTriggerFactory.createAndExecuteHandler(Opportunity.sObjectType);
}