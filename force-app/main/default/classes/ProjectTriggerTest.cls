@isTest
private class ProjectTriggerTest {
    static testMethod void testTrigger() {
        //Create Record
        project_cloud__Project__c Project = new project_cloud__Project__c();
        //Fill fields
        Project.Name='Test Name';
        insert Project;

        Id ProjectId = Project.Id;

        try{
            //Update record
            Project.Name += '(Edited)';
            update Project;
            System.assert(Project!=null);

            //Delete record
            delete Project;
            System.assertEquals(0,[SELECT count() FROM project_cloud__Project__c WHERE Id =:ProjectId]);
        }catch(zsfjira.ZTriggerFactory.ZTriggerException exe){
            System.assert(false, 'Trigger could be defined incorrectly');
        }
    }
}