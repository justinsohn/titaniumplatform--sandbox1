public class test_updatecontactrolecount
{
 public static testMethod void testcreateopptywithconditionandrole()
{
//Insert Opportunities 
try
{
    Opportunity Oppty = new Opportunity(Name='Oppty_test1',StageName='Stage 1 - Unqualified Prospect',Type ='New Business', CloseDate=System.Today());
    insert Oppty;
    
    // insert contact
    Contact[] cont = new Contact[]
    {
        new Contact(LastName = 'testcontact1'),
        new Contact(LastName = 'testcontact2')
    };    
    insert cont;    
    // insert contact role     
    OpportunityContactRole [] ocr = new OpportunityContactRole[]
    {
    new OpportunityContactRole(Role ='Business User',OpportunityId=Oppty.id ,Contactid = cont[0].id ,Isprimary = True),
    new OpportunityContactRole(Role ='Business User',OpportunityId=Oppty.id ,Contactid = cont[0].id ,Isprimary = False)
    };
    insert ocr;    
    Oppty.StageName = 'Stage 3 - Eval Request';    
    //Update opportunity
    
    Test.StartTest();
    update Oppty;
    Test.StopTest();
    
    Oppty =[SELECT Number_of_Contacts_Roles_Assigned__c,Primary_Contact_Assigned__c FROM Opportunity WHERE Id = :Oppty.Id];
    system.assert (Oppty.Number_of_Contacts_Roles_Assigned__c == 2);
    system.assert (Oppty.Primary_Contact_Assigned__c == True);
}
catch (System.DmlException e)
{
    System.assert(false);
}        
} 
}