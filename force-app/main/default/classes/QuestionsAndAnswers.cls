public class QuestionsAndAnswers {
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getQuestionsAndAnswers(){
        Map<String, Object> questionsAndAnswers = new Map<String, Object>();
        
        try{
            List<Object> processTypes = new List<Object>();
            Schema.DescribeFieldResult fieldResult = Question__c.Process_Type__c.getDescribe();
            List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();            
            for( Schema.PicklistEntry f : ple){
                Map<String, String> processType = new Map<String, String>();
                processType.put('label', f.getLabel());
                processType.put('value', f.getValue());
                processTypes.add(processType);
            }
            questionsAndAnswers.put('processTypes', processTypes);
            
            Map<String, Question__c> question1Map = new Map<String, Question__c>([Select Id, Name, Process_Type__c, (Select Id, Name, Product_Code__c, Question__c, Question__r.Name From Answers__r Order By Sort_Order__c) From Question__c]);
            questionsAndAnswers.put('question1', question1Map);
            Map<String, Question_2__c> question2Map = new Map<String, Question_2__c>([Select Id, Name, Answer_1__c, (Select Id, Name, Product__c, Product__r.Name, Products__c, Question_2__c, Question_2__r.Name From Answer_2__r Order By Sort_Order__c) From Question_2__c]);
            questionsAndAnswers.put('question2', question2Map);
            Map<String, Question_3__c> question3Map = new Map<String, Question_3__c>([Select Id, Name, Answer_2__c, Product__c, Products__c, Required_Products__c, (Select Id, Name, Yes__c, Product__c, Product__r.Name, Products__c, Required_Products__c, Question_3__r.Name From Answer_3__r Order By Order__c) From Question_3__c Order By Order__c]);
            questionsAndAnswers.put('question3', question3Map);
            Map<String, Answer__c> answer1Map = new Map<String, Answer__c>([Select Id, Name, Product_Code__c, Question__c, (Select Id, Name, Answer_1__c From Question_2__r) From Answer__c Order By Sort_Order__c]);
            questionsAndAnswers.put('answer1', answer1Map);
            Map<String, Answer_2__c> answer2Map = new Map<String, Answer_2__c>([Select Id, Name, Product__c, Products__c, Question_2__c, (Select Id, Name, Answer_2__c, Product__c, Products__c, Required_Products__c From Question_3__r Order By Order__c) From Answer_2__c Order By Sort_Order__c]);
            questionsAndAnswers.put('answer2', answer2Map);
            Map<String, Answer_3__c> answer3Map = new Map<String, Answer_3__c>([Select Id, Name, Product__c, Products__c, Question_3__c, Required_Products__c From Answer_3__c]);
            questionsAndAnswers.put('answer3', answer3Map);
            
            questionsAndAnswers.put('isSuccess', true);
            questionsAndAnswers.put('message', '');
        } catch(Exception ex){
            questionsAndAnswers.put('isSuccess', false);
            questionsAndAnswers.put('message', ex.getMessage());
        }
        
        return questionsAndAnswers;
    }
    
    @AuraEnabled
    public static Map<String, Object> saveProductsToQuote(String quoteId, List<String> products){
        System.debug('Quote: ' + quoteId);
        System.debug('Products:' + products);
        Map<String, Object> response = new Map<String, Object>();
        List<String> productModels = new List<String>();
        
        try{
            if(String.isBlank(quoteid)){
                response.put('isSuccess', false);
                response.put('message', 'The Quote Id must be populated.');
                return response;
            }
            
            if(products.isEmpty()){
                response.put('isSuccess', false);
                response.put('message', 'The Product List must include at least one product.');
                return response;
            }
            
            SBQQ__Quote__c quote = [Select Id, SBQQ__PriceBook__c, CurrencyIsoCode From SBQQ__Quote__c Where Id = :quoteId];
            System.debug(quote);
            //the Id of the pricebook for the quote and product being added
            String pricebookId = quote.SBQQ__PriceBook__c;
            
            if(products[0].contains('-')){
                List<String> productNames = new List<String>();
                for(String product : products){
                    productNames.addAll(product.split(','));
                }
                products.clear();
                Map<String, String> productMap = new Map<String, String>();
                for(Product2 product : [Select Id, Name, ProductCode From Product2 Where ProductCode IN :productNames]){
                    productMap.put(product.ProductCode, product.Id);
                }
                for(String product : productNames){
                    products.add(productMap.get(product));
                }
            }
            
            //the currency code
            String currencyCode = quote.CurrencyIsoCode;
            
            //the JSON formatted String representing the quote model to add a product to
            String quoteModel = SBQQ.ServiceRouter.read('SBQQ.QuoteAPI.QuoteReader', quoteId);
            
            for(String s : products){
                System.debug(s);
                System.debug(pricebookId);
                System.debug(currencyCode);
                //the JSON formatted String representing the product to be added to the quote
                String productModel = SBQQ.ServiceRouter.load('SBQQ.ProductAPI.ProductLoader', s, '{"pricebookId" : "' + pricebookId + '", "currencyCode" : "' + currencyCode + '"}');
            	productModels.add(productModel);
            }
            //the JSON formatted String representing the quote with the product added to it
            String updatedQuoteModel = SBQQ.ServiceRouter.load('SBQQ.QuoteAPI.QuoteProductAdder', null, '{"quote" : ' + quoteModel + ', "products" : [' + String.join(productModels, ',') + '], "ignoreCalculate" : true}');
            
            //the JSON formatted String represeting the saved quote
            String savedQuoteModel = SBQQ.ServiceRouter.save('SBQQ.QuoteAPI.QuoteSaver', updatedQuoteModel);
            
            response.put('isSuccess', true);
            response.put('message', '');
        } catch(Exception ex){
            response.put('isSuccess', false);
            response.put('message', ex.getMessage() + '\n' + ex.getStackTraceString() + '\n' + ex.getLineNumber());
        }
        
        return response;
    }
    
}