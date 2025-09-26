@isTest(Seealldata=true)
public class ConnectedAppsPolicyConditionTest {
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
            '0CiD00000004Cce', /* entityID*/
            Datetime.now(), /* timeStamp */
            data); /* data - Map */ 
    
        ConnectedAppsPolicyCondition target_test_class = new ConnectedAppsPolicyCondition();
        target_test_class.evaluate(test_event);
    
        System.Test.stopTest();
    }
    @isTest public static void test_condition_fail()
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
            '0wddawdawdad', /* entityID*/
            Datetime.now(), /* timeStamp */
            data); /* data - Map */ 
    
        ConnectedAppsPolicyCondition target_test_class = new ConnectedAppsPolicyCondition();
        target_test_class.evaluate(test_event);
    
        System.Test.stopTest();
    }
}