@isTest(Seealldata=true)
public class ReportsPolicyConditionTest {
    @isTest public static void test_condition()
    {
        System.Test.startTest();
    
        Map<string,string> data = new Map<string,string>();
        data.put('SessionLevel', 'STANDARD');
    
        TxnSecurity.Event test_event = new TxnSecurity.Event(
            UserInfo.getOrganizationId(), /* OrganizationID*/
            UserInfo.getUserId(), /* UserID*/
            'string', /* entityName*/
            'string', /* Action*/
            'string', /* resourceType*/
            'string', /* entityID*/
            Datetime.now(), /* timeStamp */
            data); /* data - Map */
    
        ReportsPolicyCondition target_test_class = new ReportsPolicyCondition();
        target_test_class.evaluate(test_event);
    
        System.Test.stopTest();
    }
    @isTest public static void test_condition_fail()
    {
        System.Test.startTest();
    
        Map<string,string> data = new Map<string,string>();
        data.put('SessionLevel', 'awdawdawd');
    
        TxnSecurity.Event test_event = new TxnSecurity.Event(
            UserInfo.getOrganizationId(), /* OrganizationID*/
            UserInfo.getUserId(), /* UserID*/
            'string', /* entityName*/
            'string', /* Action*/
            'string', /* resourceType*/
            'string', /* entityID*/
            Datetime.now(), /* timeStamp */
            data); /* data - Map */
    
        ReportsPolicyCondition target_test_class = new ReportsPolicyCondition();
        target_test_class.evaluate(test_event);
    
        System.Test.stopTest();
    }
}