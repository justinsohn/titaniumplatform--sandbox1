public class SF2090_SV1_Cases_Export_15000 implements TxnSecurity.PolicyCondition{
	public boolean evaluate(TxnSecurity.Event e) {
    	
          Integer numberOfRecords = Integer.valueOf(e.data.get('NumberOfRecords'));
   		
          String entityName = e.data.get('EntityName');
    	
          if ('Case'.equals(entityName) && numberOfRecords >= 15000) {
	     
              return true;
   		  }
    	  return false;
 	 }
}