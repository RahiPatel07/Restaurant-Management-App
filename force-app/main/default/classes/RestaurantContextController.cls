public with sharing class RestaurantContextController {

    public class OptionDTO {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public OptionDTO(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    // Not cacheable: AdminSetup can create records and the UI needs fresh options immediately.
    @AuraEnabled
    public static List<OptionDTO> getRestaurants() {
        List<OptionDTO> out = new List<OptionDTO>();
        for (Restaurant__c r : [
            SELECT Id, Name
            FROM Restaurant__c
            WHERE Is_Active__c = true
            ORDER BY Name
        ]) {
            out.add(new OptionDTO(r.Name, (String)r.Id));
        }
        return out;
    }

    @AuraEnabled
    public static List<OptionDTO> getTablesForRestaurant(Id restaurantId) {
        if (restaurantId == null) return new List<OptionDTO>();
        List<OptionDTO> out = new List<OptionDTO>();
        for (Table__c t : [
            SELECT Id, Name, Seats__c, Status__c
            FROM Table__c
            WHERE Restaurant__c = :restaurantId
            ORDER BY Name
        ]) {
            out.add(new OptionDTO(t.Name + ' (' + t.Seats__c + ', ' + t.Status__c + ')', (String)t.Id));
        }
        return out;
    }

    @AuraEnabled
    public static List<OptionDTO> getOrdersForTable(Id restaurantId, Id tableId) {
        if (restaurantId == null || tableId == null) return new List<OptionDTO>();
        List<OptionDTO> out = new List<OptionDTO>();
        for (Order__c o : [
            SELECT Id, Name, Status__c, CreatedDate
            FROM Order__c
            WHERE Restaurant__c = :restaurantId
              AND Table__c = :tableId
            ORDER BY CreatedDate DESC
            LIMIT 25
        ]) {
            out.add(new OptionDTO(o.Name + ' (' + o.Status__c + ')', (String)o.Id));
        }
        return out;
    }

    @AuraEnabled
    public static Id getOpenOrderForTable(Id restaurantId, Id tableId) {
        if (restaurantId == null || tableId == null) return null;
        List<Order__c> ords = [
            SELECT Id
            FROM Order__c
            WHERE Restaurant__c = :restaurantId
              AND Table__c = :tableId
              AND Status__c = 'Open'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return ords.isEmpty() ? null : ords[0].Id;
    }
}

