trigger ProjectTrigger on project_cloud__Project__c (before delete, after delete, after update, after undelete) {
    zsfjira.ZTriggerFactory.createAndExecuteHandler(project_cloud__Project__c.sObjectType);
}