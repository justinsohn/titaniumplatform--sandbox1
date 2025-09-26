@isTest(Seealldata=true)
public class LoginPolicyCondition_revisedTest {
     @isTest public static void testAccountExport()
    {
        System.Test.startTest();
        string x = 'Account';
        Map<string,string> datas = new Map<string, string>{'NumberOfRecords' => '60', 'EntityName' => 'Account'};
            
        TxnSecurity.Event test_class = new TxnSecurity.Event( 
            UserInfo.getOrganizationId(), /* organizationId */
            UserInfo.getUserId(), /* userId */
            'Account', /* entityName */
            'Login', /* action */
            'LoginHistory', /* resourceType */
            '01pR00000009D2H', /* entityId */
            Datetime.now(), /* timeStamp */
            datas); /* data - Map with info about this event. */
        
        LoginPolicyCondition_revised target = new LoginPolicyCondition_revised();
        target.evaluate(test_class);
        
        TxnSecurity.Event test_class2 = new TxnSecurity.Event( 
            UserInfo.getOrganizationId(), /* organizationId */
            UserInfo.getUserId(), /* userId */
            'Account', /* entityName */
            'Login', /* action */
            'LoginHistory', /* resourceType */
            '01pR00000009D2H', /* entityId */
            Datetime.newInstance(2019, 3, 22, 9, 18, 3), /* timeStamp */
            datas); /* data - Map with info about this event. */
        
        target.evaluate(test_class2);
        
        TxnSecurity.Event test_class3 = new TxnSecurity.Event( 
            UserInfo.getOrganizationId(), /* organizationId */
            UserInfo.getUserId(), /* userId */
            'Account', /* entityName */
            'Login', /* action */
            'LoginHistory', /* resourceType */
            '01pR00000009D2H', /* entityId */
            Datetime.newInstance(2019, 3, 22, 7, 51, 3), /* timeStamp */
            datas); /* data - Map with info about this event. */
        
        target.evaluate(test_class3);
        
        TxnSecurity.Event test_class4 = new TxnSecurity.Event( 
            UserInfo.getOrganizationId(), /* organizationId */
            UserInfo.getUserId(), /* userId */
            'Account', /* entityName */
            'Login', /* action */
            'LoginHistory', /* resourceType */
            '01pR00000009D2H', /* entityId */
             Datetime.newInstance(2019, 3, 21, 7, 51, 3), /* timeStamp */
            datas); /* data - Map with info about this event. */
        	//Datetime.now()
        target.evaluate(test_class4);
        
        System.Test.stopTest();
        
        
    }
}