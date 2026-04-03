public with sharing class ChefListController {

    public class ChefOrderItemDTO {
        @AuraEnabled public Id orderItemId;
        @AuraEnabled public Id orderId;
        @AuraEnabled public String orderNumber;
        @AuraEnabled public String tableName;
        @AuraEnabled public String menuItemName;
        @AuraEnabled public Integer quantity;
        @AuraEnabled public String status;
        @AuraEnabled public Integer estimatedDeliveryMinutes;
    }

    @AuraEnabled(cacheable=true)
    public static Integer getActiveChefCount(Id restaurantId) {
        if (restaurantId == null) return 1;
        Restaurant__c rest = [
            SELECT Active_Chef_Count__c
            FROM Restaurant__c
            WHERE Id = :restaurantId
            LIMIT 1
        ];
        Integer count = rest.Active_Chef_Count__c == null ? 1 : Integer.valueOf(rest.Active_Chef_Count__c);
        return count <= 0 ? 1 : count;
    }

    @AuraEnabled
    public static void setActiveChefCount(Id restaurantId, Integer chefCount) {
        if (restaurantId == null) {
            throw new AuraHandledException('Restaurant Id is required.');
        }
        if (chefCount == null || chefCount <= 0) {
            throw new AuraHandledException('Chef count must be greater than zero.');
        }
        update new Restaurant__c(
            Id = restaurantId,
            Active_Chef_Count__c = chefCount
        );
    }

    @AuraEnabled(cacheable=true)
    public static List<ChefOrderItemDTO> getPendingAndPreparingItems(Id restaurantId) {
        if (restaurantId == null) return new List<ChefOrderItemDTO>();

        Integer chefCount = getActiveChefCount(restaurantId);
        List<Order_Item__c> items = [
            SELECT Id, Order__c, Order__r.Name, Order__r.Table__r.Name,
                   Menu_Item__r.Name, Quantity__c, Status__c, CreatedDate
            FROM Order_Item__c
            WHERE Order__r.Restaurant__c = :restaurantId
              AND (Status__c = 'Confirmed' OR Status__c = 'Preparing')
            ORDER BY CreatedDate ASC
        ];

        List<ChefOrderItemDTO> result = new List<ChefOrderItemDTO>();
        Integer position = 0;
        for (Order_Item__c oi : items) {
            position++;
            ChefOrderItemDTO dto = new ChefOrderItemDTO();
            dto.orderItemId = oi.Id;
            dto.orderId = oi.Order__c;
            dto.orderNumber = oi.Order__r.Name;
            dto.tableName = oi.Order__r.Table__r.Name;
            dto.menuItemName = oi.Menu_Item__r.Name;
            dto.quantity = Integer.valueOf(oi.Quantity__c);
            dto.status = oi.Status__c;
            dto.estimatedDeliveryMinutes = estimateEtaMinutes(position, chefCount);
            result.add(dto);
        }
        return result;
    }

    @AuraEnabled
    public static void acceptItems(List<Id> orderItemIds) {
        RestaurantOrderService.chefAcceptItems(orderItemIds);
    }

    @AuraEnabled
    public static void markItemsReady(List<Id> orderItemIds) {
        RestaurantOrderService.chefMarkReady(orderItemIds);
    }

    private static Integer estimateEtaMinutes(Integer queuePosition, Integer chefCount) {
        Integer baseMinutesPerItem = 12;
        Decimal parallelized = (Decimal.valueOf(queuePosition) / Decimal.valueOf(chefCount));
        Integer slots = Integer.valueOf(Math.ceil(parallelized));
        return slots * baseMinutesPerItem;
    }
}

