@isTest
private class OpportunityTriggerTest {
    static testMethod void testTrigger() {
        //Create Record
        Opportunity opp = new Opportunity();
        //Fill fields
        opp.Name='Test Name';
        opp.StageName = 'Qualification';
        opp.CloseDate = Date.today()+30;
        insert opp;

        Id oppId = opp.Id;

        try{
            //Update record
            opp.Name += '(Edited)';
            update opp;
            System.assert(opp!=null);

            //Delete record
            delete opp;
            System.assertEquals(0,[SELECT count() FROM Opportunity WHERE Id =:oppId]);
        }catch(zsfjira.ZTriggerFactory.ZTriggerException exe){
            System.assert(false, 'Trigger could be defined incorrectly');
        }
    }
}