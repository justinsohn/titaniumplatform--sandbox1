@isTest
public class QuestionsAndAnswersTest{
    @testSetup
    public static void setup(){
        Question__c question = new Question__c(Name='What will be included on this Opportunity?');
        insert question;
        
        Answer__c answer = new Answer__c(Name='Data Feed/ Download', Question__c=question.Id);
        insert answer;
        
        Question_2__c question2 = new Question_2__c(Name='What will be included on this Data Feed/ Download Opportunity?', Answer_1__c=answer.Id);
        insert question2;
        
        Answer_2__c answer2 = new Answer_2__c(Name='Data', Question_2__c=question2.Id);
        insert answer2;
        
        Question_3__c question3 = new Question_3__c(Name='Is US query only included?', Answer_2__c=answer2.Id);
        insert question3;
        
        Answer_3__c answer3 = new Answer_3__c(Name='Yes', Question_3__c=question3.Id);
        insert answer3;
    }
    
    public static testmethod void testConstructor(){
        Map<String, Object> response = QuestionsAndAnswers.getQuestionsAndAnswers();
		System.debug(JSON.serialize(response));
    }
    
    public static testmethod void testSaveProductsToQuote(){
        System.debug(Test.getStandardPricebookId());
        SBQQ__Quote__c quote = new SBQQ__Quote__c(
        	SBQQ__PriceBook__c = Test.getStandardPricebookId(),
            SBQQ__PricebookId__c = Test.getStandardPricebookId(),
            CurrencyIsoCode = 'USD'
        );
        insert quote;
        
        List<String> products = new List<String>();
        Product2 product = new Product2(Name='Test-Product', ProductCode='Test-Product');
        insert product;
        
        products.add(product.ProductCode);
        
        PriceBookEntry pbEntry = new PriceBookEntry(
            UnitPrice = 195,
            PriceBook2Id = Test.getStandardPricebookId(),
            Product2Id = product.Id,
            IsActive = true);
        insert pbEntry;
        
        List<SBQQ__QuoteLine__c> qls = [Select Id From SBQQ__QuoteLine__c Where SBQQ__Quote__c = :quote.Id];
        System.assertEquals(0, qls.size(), 'There should not be a Quote Line!');
        
        Map<String, Object> response = QuestionsAndAnswers.saveProductsToQuote(quote.Id, products);
        System.assertEquals(true, Boolean.valueOf(response.get('isSuccess')), 'The request should succeed.');
        
        qls = [Select Id From SBQQ__QuoteLine__c Where SBQQ__Quote__c = :quote.Id];
        System.assertEquals(1, qls.size(), 'There should now be a Quote Line!');
    }
    
    public static testmethod void testSaveProductsToQuote_Errors(){
        Map<String, Object> response = QuestionsAndAnswers.saveProductsToQuote(null, null);
        
        System.assertEquals(false, Boolean.valueOf(response.get('isSuccess')), 'The request should fail due to a null Quote Id.');
        
        SBQQ__Quote__c quote = new SBQQ__Quote__c();
        insert quote;
        
        response = QuestionsAndAnswers.saveProductsToQuote(quote.Id, new List<String>());
        
        System.assertEquals(false, Boolean.valueOf(response.get('isSuccess')), 'The request should fail due to new Products in the list.');
    }
}