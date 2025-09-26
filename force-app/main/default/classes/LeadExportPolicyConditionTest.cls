@isTest(Seealldata=true)
public class LeadExportPolicyConditionTest {
    @isTest public static void testLeadExportPolicy()
    {
        System.Test.startTest();
        
        Map<String, String> eventData = new Map<String, String>();
        eventData.put('NumberOfRecords', '60');
            
        TxnSecurity.Event test_class = new TxnSecurity.Event( 
            UserInfo.getOrganizationId(), /* organizationId */
            UserInfo.getUserId(), /* userId */
            'Lead', /* entityName */
            'Login', /* action */
            'LoginHistory', /* resourceType */
            '01pR00000009D2H', /* entityId */
            Datetime.newInstance(2016, 2, 15), /* timeStamp */
            eventData); /* data - Map with info about this event. */
        
        LeadExportPolicyCondition target = new LeadExportPolicyCondition();
        target.evaluate(test_class);
        System.Test.stopTest();
           
    }
}