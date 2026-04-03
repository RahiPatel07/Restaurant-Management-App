public with sharing class MenuItemListController {

    public class MenuItemDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String category;
        @AuraEnabled public String foodType;
        @AuraEnabled public Decimal price;
        @AuraEnabled public Boolean isTopSeller;
    }

    public class OrderItemDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public Id menuItemId;
        @AuraEnabled public String menuItemName;
        @AuraEnabled public Integer quantity;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal lineTotal;
        @AuraEnabled public String status;
    }

    public class OrderSummaryDTO {
        @AuraEnabled public Id orderId;
        @AuraEnabled public Decimal subtotal;
        @AuraEnabled public Decimal tax;
        @AuraEnabled public Decimal grandTotal;
        @AuraEnabled public List<OrderItemDTO> cartItems;
        @AuraEnabled public List<OrderItemDTO> billedItems;
        @AuraEnabled public Integer etaMinutes;
    }

    /**
     * Returns menu items for a restaurant filtered by category and food type.
     */
    @AuraEnabled(cacheable=true)
    public static List<MenuItemDTO> getMenuItems(Id restaurantId, String category, String foodType) {
        String effectiveCategory = category;
        String effectiveFoodType = foodType;

        String soql = 'SELECT Id, Name, Category__c, Food_Type__c, Price__c, Is_Top_Seller__c ' +
                      'FROM Menu_Item__c WHERE Id != null';
        if (restaurantId != null) {
            soql += ' AND Restaurant__c = :restaurantId';
        }
        if (String.isNotBlank(effectiveCategory)) {
            soql += ' AND Category__c = :effectiveCategory';
        }
        if (String.isNotBlank(effectiveFoodType)) {
            soql += ' AND Food_Type__c = :effectiveFoodType';
        }
        soql += ' ORDER BY Name';

        List<Menu_Item__c> items = Database.query(soql);
        List<MenuItemDTO> result = new List<MenuItemDTO>();
        for (Menu_Item__c mi : items) {
            MenuItemDTO dto = new MenuItemDTO();
            dto.id = mi.Id;
            dto.name = mi.Name;
            dto.category = mi.Category__c;
            dto.foodType = mi.Food_Type__c;
            dto.price = mi.Price__c;
            dto.isTopSeller = mi.Is_Top_Seller__c;
            result.add(dto);
        }
        return result;
    }

    /**
     * Returns the current order summary (cart + billed items) for a given table.
     * If no open order exists and createIfMissing is true, a new order will be created.
     */
    @AuraEnabled
    public static OrderSummaryDTO getOrderSummary(Id restaurantId, Id tableId, Boolean createIfMissing) {
        if (restaurantId == null || tableId == null) {
            throw new AuraHandledException('Restaurant and Table are required.');
        }

        Order__c ord;
        List<Order__c> existing = [
            SELECT Id, Status__c, Total_Amount__c, Tax_Amount__c, Grand_Total__c
            FROM Order__c
            WHERE Restaurant__c = :restaurantId
              AND Table__c = :tableId
              AND Status__c = 'Open'
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            ord = existing[0];
        } else if (Boolean.valueOf(createIfMissing)) {
            ord = new Order__c(
                Restaurant__c = restaurantId,
                Table__c = tableId,
                Status__c = 'Open',
                Order_Start_Time__c = System.now()
            );
            insert ord;
        } else {
            return null;
        }

        List<Order_Item__c> lines = [
            SELECT Id, Menu_Item__c, Menu_Item__r.Name,
                   Quantity__c, Unit_Price__c, Line_Total__c, Status__c
            FROM Order_Item__c
            WHERE Order__c = :ord.Id
            ORDER BY CreatedDate
        ];

        List<OrderItemDTO> cartItems = new List<OrderItemDTO>();
        List<OrderItemDTO> billedItems = new List<OrderItemDTO>();

        for (Order_Item__c line : lines) {
            OrderItemDTO dto = new OrderItemDTO();
            dto.id = line.Id;
            dto.menuItemId = line.Menu_Item__c;
            dto.menuItemName = line.Menu_Item__r.Name;
            dto.quantity = Integer.valueOf(line.Quantity__c);
            dto.unitPrice = line.Unit_Price__c;
            dto.lineTotal = line.Line_Total__c;
            dto.status = line.Status__c;

            if (line.Status__c == 'Pending') {
                cartItems.add(dto);
            } else {
                billedItems.add(dto);
            }
        }

        OrderSummaryDTO summary = new OrderSummaryDTO();
        summary.orderId = ord.Id;
        summary.subtotal = ord.Total_Amount__c;
        summary.tax = ord.Tax_Amount__c;
        summary.grandTotal = ord.Grand_Total__c;
        summary.cartItems = cartItems;
        summary.billedItems = billedItems;

        // Simple ETA for the first item in this order using chef count.
        summary.etaMinutes = getEstimatedMinutesForOrder(ord.Id);

        return summary;
    }

    /**
     * Persists the given cart items as Pending order items using RestaurantOrderService.
     */
    @AuraEnabled
    public static Id saveCart(Id restaurantId, Id tableId, String cartItemsJson) {
        List<RestaurantOrderService.CartItem> cartItems = 
            (List<RestaurantOrderService.CartItem>) JSON.deserialize(
                cartItemsJson, 
                List<RestaurantOrderService.CartItem>.class
            );
        return RestaurantOrderService.upsertCart(restaurantId, tableId, cartItems);
    }


    /**
     * Places the order (locks in current cart as billed items).
     */
    @AuraEnabled
    public static Id placeOrder(Id orderId) {
        return RestaurantOrderService.placeOrder(orderId);
    }

    /**
     * Updates Confirmed order items (editable billed items before chef accepts).
     */
    @AuraEnabled
    public static void updateConfirmedOrderItems(List<Order_Item__c> updatedLines) {
        RestaurantOrderService.updateConfirmedItems(updatedLines);
    }

    /**
     * Estimate minutes for first item in an order, based on active chefs.
     */
    @AuraEnabled(cacheable=true)
    public static Integer getEstimatedMinutesForOrder(Id orderId) {
        if (orderId == null) return null;
        Order__c ord = [
            SELECT Id, Restaurant__c
            FROM Order__c
            WHERE Id = :orderId
            LIMIT 1
        ];
        Integer chefCount = ChefListController.getActiveChefCount(ord.Restaurant__c);
        List<Order_Item__c> items = [
            SELECT Id
            FROM Order_Item__c
            WHERE Order__c = :orderId
              AND (Status__c = 'Pending' OR Status__c = 'Confirmed' OR Status__c = 'Preparing')
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        if (items.isEmpty()) return null;
        // First item in queue => position 1
        return  ChefListController.getActiveChefCount(ord.Restaurant__c) > 0
            ? 12
            : null;
    }
}

