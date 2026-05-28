trigger OpportunityPromotion on Opportunity (before insert, before update) {
    for (Opportunity opp : Trigger.new) opp.Description = 'Promotion Applied';
}