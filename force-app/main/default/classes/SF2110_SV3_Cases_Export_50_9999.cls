public class SF2110_SV3_Cases_Export_50_9999 implements TxnSecurity.PolicyCondition{
	  public boolean evaluate(TxnSecurity.Event e) {
    	
          Integer numberOfRecords = Integer.valueOf(e.data.get('NumberOfRecords'));
   		
          String entityName = e.data.get('EntityName');
    	
          if ('Case'.equals(entityName) && numberOfRecords >= 50 && numberOfRecords <= 9999) {
	     
              return true;
   		  }
    	  return false;
 	 }
}