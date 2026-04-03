public with sharing class WaiterListController {

    public class WaiterOrderItemDTO {
        @AuraEnabled public Id orderItemId;
        @AuraEnabled public Id orderId;
        @AuraEnabled public String orderNumber;
        @AuraEnabled public String tableName;
        @AuraEnabled public String menuItemName;
        @AuraEnabled public Integer quantity;
        @AuraEnabled public String status;
    }

    /**
     * Returns all items that are Ready to be picked up and delivered.
     */
    @AuraEnabled(cacheable=true)
    public static List<WaiterOrderItemDTO> getReadyItems(Id restaurantId) {
        if (restaurantId == null) return new List<WaiterOrderItemDTO>();

        List<Order_Item__c> items = [
            SELECT Id, Order__c, Order__r.Name, Order__r.Table__r.Name,
                   Menu_Item__r.Name, Quantity__c, Status__c, CreatedDate
            FROM Order_Item__c
            WHERE Order__r.Restaurant__c = :restaurantId
              AND Status__c = 'Ready'
            ORDER BY CreatedDate ASC
        ];

        List<WaiterOrderItemDTO> result = new List<WaiterOrderItemDTO>();
        for (Order_Item__c oi : items) {
            WaiterOrderItemDTO dto = new WaiterOrderItemDTO();
            dto.orderItemId = oi.Id;
            dto.orderId = oi.Order__c;
            dto.orderNumber = oi.Order__r.Name;
            dto.tableName = oi.Order__r.Table__r.Name;
            dto.menuItemName = oi.Menu_Item__r.Name;
            dto.quantity = Integer.valueOf(oi.Quantity__c);
            dto.status = oi.Status__c;
            result.add(dto);
        }
        return result;
    }

    /**
     * Marks items as Delivered using the shared order service.
     */
    @AuraEnabled
    public static void markItemsDelivered(List<Id> orderItemIds) {
        RestaurantOrderService.waiterMarkDelivered(orderItemIds);
    }

    /**
     * Attempts to complete an order (if all items are Delivered/Cancelled)
     * and, if successful, moves the related table into Cleaning.
     */
    @AuraEnabled
    public static void completeOrderAndStartCleaning(Id orderId) {
        if (orderId == null) return;

        RestaurantOrderService.completeOrderIfDelivered(orderId);

        Order__c ord = [
            SELECT Id, Status__c, Table__c
            FROM Order__c
            WHERE Id = :orderId
            LIMIT 1
        ];
        if (ord.Status__c == 'Completed' && ord.Table__c != null) {
            // Set table to Cleaning; TableController enforces transitions.
            TableController.setTableStatus(ord.Table__c, 'Cleaning');
        }
    }
}

