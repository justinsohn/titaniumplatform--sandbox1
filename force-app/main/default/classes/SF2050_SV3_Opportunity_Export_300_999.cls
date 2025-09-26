public class SF2050_SV3_Opportunity_Export_300_999 implements TxnSecurity.PolicyCondition{
     public boolean evaluate(TxnSecurity.Event e) {
    
         Integer number_of_records = Integer.valueOf(e.data.get('NumberOfRecords'));
    
         String entityName = e.data.get('EntityName');
    
         if ('Opportunity'.equals(entityName) && number_of_records >= 300 && number_of_records <= 999) {
             
              //send_emails(e, number_of_records);
              return true;
         }
         return false;
     }
    
/*
    private void send_emails(TxnSecurity.Event e, Integer number_of_records)
    {
         
        Messaging.reserveSingleEmailCapacity(1); // reserves email to ensure we don't exceed our daily email limit
        
        User usr = [Select Name From User where Id = :e.userId ]; // gets the username from the userID for the email body 
			    String userName = usr.Name; 
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage(); //inits the email object

        String[] toAddresses = new String[] {'Secalarms-sf@netnumber.com'}; 
        
        mail.setToAddresses(toAddresses);
			
        mail.setSenderDisplayName('Transaction Security');
        
        mail.setSubject('Opportunity export limit SV3 50-999 exceeded by ' + userName); // apex doesn't have format strings :^( well common sytax atleast haven't actually checked documentation 
        
		mail.setBccSender(false);
		
        mail.setUseSignature(true);
        
        dateTime event_time_in_est; // in est because that is the timezone of the nncrm user this will change as that users timezone changes
        
        event_time_in_est = subtract_minutes(e.timeStamp, 0); // purpose of this is to convert GMT to timezone here. Timestamp is a "Unix Timestamp"
        
        mail.setPlainTextBody('The opportunity export limit SV3 50-999 was exceeded by ' + userName + '\n' + 'Number of records: ' + number_of_records + '\n' +'Time: ' + event_time_in_est );
        
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });

    }
     private dateTime subtract_minutes(dateTime start_time, Integer range_minutes) // subtracts minutes from the time passed
    {
        Integer new_minute;
        
        new_minute = start_time.minute() - range_minutes; // don't have to worry about a number being greater then 25 and causing negative minutes as datetime init handles negative minutes and sets the date to account for the negative minutes
                                                          //e.g newInstance(2019, 1, 1, 0, -25, 3) returns the date 12/31/2018 11:35 PM // does not work for 24 in this data structure 24 != 0 it equals one full day ahead of the current 
                                                          //That confused me so I made a note to help future people. 
                                                          
        start_time = Datetime.newInstance(start_time.year(), start_time.month(), start_time.day(), start_time.hour(), new_minute, start_time.second());
        return start_time;
    }
    
*/
}