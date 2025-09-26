@isTest(Seealldata=true)
public class ContactExportPolicyConditionTest {
     @isTest public static void test_condition()
    {
        System.Test.startTest();
        string x = 'Account';
        Map<string,string> datas = new Map<string, string>{'NumberOfRecords' => '1000', 'EntityName' => 'Contact', 'Application' => 'Salesforce for iOS'};
            
        TxnSecurity.Event test_class = new TxnSecurity.Event( 
            UserInfo.getOrganizationId(), /* organizationId */
            UserInfo.getUserId(), /* userId */
            'Contact', /* entityName */
            'Login', /* action */
            'LoginHistory', /* resourceType */
            '01pR00000009D2H', /* entityId */
            Datetime.newInstance(2016, 2, 15), /* timeStamp */
            datas); /* data - Map with info about this event. */
        
        //datas.put('NumberOfRecords', '60');
        //datas.put('EntityName', 'Account');
        //test_class.Event(x, x, x, x, x, x, datentime, data);
        
        SF2020_SV3_Contact_Export_500_2999 target = new SF2020_SV3_Contact_Export_500_2999();
        target.evaluate(test_class);
        
        SF2010_SV2_Contact_Export_3000_6499 target2 = new SF2010_SV2_Contact_Export_3000_6499();
        target2.evaluate(test_class);
        
        SF2000_SV1_Contact_Export_6500_Or_More target3 = new SF2000_SV1_Contact_Export_6500_Or_More();
        target3.evaluate(test_class);
        
        
        datas = new Map<string, string>{'NumberOfRecords' => '400', 'EntityName' => 'Contact'};
            
        test_class = new TxnSecurity.Event( 
            UserInfo.getOrganizationId(), /* organizationId */
            UserInfo.getUserId(), /* userId */
            'Contact', /* entityName */
            'Login', /* action */
            'LoginHistory', /* resourceType */
            '01pR00000009D2H', /* entityId */
            Datetime.newInstance(2016, 2, 15), /* timeStamp */
            datas); /* data - Map with info about this event. */
        
       target.evaluate(test_class);
       target2.evaluate(test_class);
       target3.evaluate(test_class);
        
        datas = new Map<string, string>{'NumberOfRecords' => '600', 'EntityName' => 'Contact', 'Application' => 'Salesforce for iOS'};
            
        test_class = new TxnSecurity.Event( 
            UserInfo.getOrganizationId(), /* organizationId */
            UserInfo.getUserId(), /* userId */
            'Contact', /* entityName */
            'Login', /* action */
            'LoginHistory', /* resourceType */
            '01pR00000009D2H', /* entityId */
            Datetime.newInstance(2016, 2, 15), /* timeStamp */
            datas); /* data - Map with info about this event. */
        
       target.evaluate(test_class);
       target2.evaluate(test_class);
       target3.evaluate(test_class);
        
       datas = new Map<string, string>{'NumberOfRecords' => '5000', 'EntityName' => 'Contact'};
            
        test_class = new TxnSecurity.Event( 
            UserInfo.getOrganizationId(), /* organizationId */
            UserInfo.getUserId(), /* userId */
            'Contact', /* entityName */
            'Login', /* action */
            'LoginHistory', /* resourceType */
            '01pR00000009D2H', /* entityId */
            Datetime.newInstance(2016, 2, 15), /* timeStamp */
            datas); /* data - Map with info about this event. */
        
       target.evaluate(test_class);
       target2.evaluate(test_class);
       target3.evaluate(test_class);        
      
       datas = new Map<string, string>{'NumberOfRecords' => '7000', 'EntityName' => 'Contact', 'Application' => 'Salesforce for iOS'};
            
        test_class = new TxnSecurity.Event( 
            UserInfo.getOrganizationId(), /* organizationId */
            UserInfo.getUserId(), /* userId */
            'Contact', /* entityName */
            'Login', /* action */
            'LoginHistory', /* resourceType */
            '01pR00000009D2H', /* entityId */
            Datetime.newInstance(2016, 2, 15), /* timeStamp */
            datas); /* data - Map with info about this event. */
        
       target.evaluate(test_class);
       target2.evaluate(test_class);
       target3.evaluate(test_class);
        
        System.Test.stopTest();
        
    }
}