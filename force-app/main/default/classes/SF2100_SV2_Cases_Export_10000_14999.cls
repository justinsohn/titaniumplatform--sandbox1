public class SF2100_SV2_Cases_Export_10000_14999 implements TxnSecurity.PolicyCondition{
	public boolean evaluate(TxnSecurity.Event e) {
    	
          Integer numberOfRecords = Integer.valueOf(e.data.get('NumberOfRecords'));
   		
          String entityName = e.data.get('EntityName');
    	
          if ('Case'.equals(entityName) && numberOfRecords >= 10000 && numberOfRecords <= 14999) {
	     
              return true;
   		  }
    	  return false;
 	 }
}