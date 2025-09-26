@isTest(Seealldata=true)
public class OpportunityExportPolicyConditionTest {
    @isTest public static void test_condition()
    {
        System.Test.startTest();
    
        Map<string,string> data = new Map<string, string>{'NumberOfRecords' => '60', 'EntityName' => 'Opportunity'};
    
        TxnSecurity.Event test_event = new TxnSecurity.Event(
            UserInfo.getOrganizationId(), /* OrganizationID*/
            UserInfo.getUserId(), /* UserID*/
            'Opportunity', /* entityName*/
            'string', /* Action*/
            'string', /* resourceType*/
            '0CiD00000004Cce', /* entityID*/
            Datetime.now(), /* timeStamp */
            data); /* data - Map */ 
    
        SF2050_SV3_Opportunity_Export_300_999 target = new SF2050_SV3_Opportunity_Export_300_999();
        target.evaluate(test_event);
        
        SF2040_SV2_Opportunity_Export_1000_1999 target2 = new SF2040_SV2_Opportunity_Export_1000_1999();
        target2.evaluate(test_event);
        
        SF2030_SV1_Opportunity_Export_2000 target3 = new SF2030_SV1_Opportunity_Export_2000();
        target3.evaluate(test_event);
    
        data = new Map<string, string>{'NumberOfRecords' => '250', 'EntityName' => 'Opportunity'};
        
        test_event = new TxnSecurity.Event(
            UserInfo.getOrganizationId(), /* OrganizationID*/
            UserInfo.getUserId(), /* UserID*/
            'Opportunity', /* entityName*/
            'string', /* Action*/
            'string', /* resourceType*/
            '0CiD00000004Cce', /* entityID*/
            Datetime.now(), /* timeStamp */
            data); /* data - Map */ 
        
        target.evaluate(test_event);
        target2.evaluate(test_event);
        target3.evaluate(test_event);
        
        data = new Map<string, string>{'NumberOfRecords' => '1100', 'EntityName' => 'Opportunity'};
        
        test_event = new TxnSecurity.Event(
            UserInfo.getOrganizationId(), /* OrganizationID*/
            UserInfo.getUserId(), /* UserID*/
            'Opportunity', /* entityName*/
            'string', /* Action*/
            'string', /* resourceType*/
            '0CiD00000004Cce', /* entityID*/
            Datetime.now(), /* timeStamp */
            data); /* data - Map */ 
        
        target.evaluate(test_event);
        target2.evaluate(test_event);
        target3.evaluate(test_event);
        
        data = new Map<string, string>{'NumberOfRecords' => '3000', 'EntityName' => 'Opportunity'};
        
        test_event = new TxnSecurity.Event(
            UserInfo.getOrganizationId(), /* OrganizationID*/
            UserInfo.getUserId(), /* UserID*/
            'Opportunity', /* entityName*/
            'string', /* Action*/
            'string', /* resourceType*/
            '0CiD00000004Cce', /* entityID*/
            Datetime.now(), /* timeStamp */
            data); /* data - Map */ 
        
        target.evaluate(test_event);
        target2.evaluate(test_event);
        target3.evaluate(test_event);
        
        System.Test.stopTest();
    }
}