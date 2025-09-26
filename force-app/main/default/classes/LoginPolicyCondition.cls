global class LoginPolicyCondition implements TxnSecurity.PolicyCondition {
  public boolean evaluate(TxnSecurity.Event e) {
    AggregateResult[] results = [SELECT SourceIp
                                 FROM LoginHistory
                                 WHERE UserId = :e.userId
                                       AND LoginTime = LAST_N_DAYS:1
                                 GROUP BY SourceIp];
    if(!results.isEmpty() && results.size() > 1) {
      return true;
    }
    return false;
  }
}