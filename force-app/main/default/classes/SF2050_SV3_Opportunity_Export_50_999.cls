public class SF2050_SV3_Opportunity_Export_50_999 implements TxnSecurity.PolicyCondition{
	 public boolean evaluate(TxnSecurity.Event e) {
    
         Integer numberOfRecords = Integer.valueOf(e.data.get('NumberOfRecords'));
    
         String entityName = e.data.get('EntityName');
    
         if ('Opportunity'.equals(entityName) && numberOfRecords >= 50 && numberOfRecords <= 999) {
             
          	  return true;
         }
         return false;
     }
}