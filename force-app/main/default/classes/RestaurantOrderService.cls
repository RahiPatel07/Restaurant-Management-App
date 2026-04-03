public with sharing class RestaurantOrderService {

    public class CartItem {
        @AuraEnabled public Id menuItemId;
        @AuraEnabled public Integer quantity;
    }

    /**
     * Creates or updates an open order (cart) for the given table and restaurant
     * and syncs the cart items as Pending Order_Item__c records.
     */
    @AuraEnabled
    public static Id upsertCart(Id restaurantId, Id tableId, List<CartItem> cartItems) {
        if (restaurantId == null || tableId == null) {
            throw new AuraHandledException('Restaurant and Table are required.');
        }
        if (cartItems == null) {
            cartItems = new List<CartItem>();
        }

        List<Order__c> openOrders = [
            SELECT Id
            FROM Order__c
            WHERE Restaurant__c = :restaurantId
              AND Table__c = :tableId
              AND Status__c = 'Open'
            LIMIT 1
        ];
        Order__c openOrder = openOrders.isEmpty() ? null : openOrders[0];

        if (openOrder == null) {
            openOrder = new Order__c(
                Restaurant__c = restaurantId,
                Table__c = tableId,
                Status__c = 'Open',
                Order_Start_Time__c = System.now()
            );
            insert openOrder;
        }

        Map<Id, Order_Item__c> existingByMenu = new Map<Id, Order_Item__c>();
        for (Order_Item__c oi : [
            SELECT Id, Menu_Item__c, Quantity__c, Unit_Price__c
            FROM Order_Item__c
            WHERE Order__c = :openOrder.Id
              AND Status__c = 'Pending'
        ]) {
            existingByMenu.put(oi.Menu_Item__c, oi);
        }

        List<Order_Item__c> toUpsert = new List<Order_Item__c>();
        Set<Id> menuIdsInCart = new Set<Id>();

        for (CartItem ci : cartItems) {
            if (ci == null || ci.menuItemId == null || ci.quantity == null || ci.quantity <= 0) {
                continue;
            }
            menuIdsInCart.add(ci.menuItemId);
        }

        Map<Id, Menu_Item__c> menuById = new Map<Id, Menu_Item__c>([
            SELECT Id, Price__c
            FROM Menu_Item__c
            WHERE Id IN :menuIdsInCart
        ]);

        for (CartItem ci : cartItems) {
            if (ci == null || ci.menuItemId == null || ci.quantity == null || ci.quantity <= 0) {
                continue;
            }
            Menu_Item__c menu = menuById.get(ci.menuItemId);
            if (menu == null) continue;

            Order_Item__c line = existingByMenu.get(ci.menuItemId);
            if (line == null) {
                line = new Order_Item__c(
                    Order__c = openOrder.Id,
                    Menu_Item__c = ci.menuItemId,
                    Quantity__c = ci.quantity,
                    Unit_Price__c = menu.Price__c,
                    Status__c = 'Pending'
                );
            } else {
                line.Quantity__c = ci.quantity;
            }
            line.Line_Total__c = line.Quantity__c * line.Unit_Price__c;
            toUpsert.add(line);
        }

        // Remove pending items that are no longer in the cart
        List<Order_Item__c> toDelete = new List<Order_Item__c>();
        for (Order_Item__c existing : existingByMenu.values()) {
            if (!menuIdsInCart.contains(existing.Menu_Item__c)) {
                toDelete.add(existing);
            }
        }

        if (!toUpsert.isEmpty()) {
            upsert toUpsert;
        }
        if (!toDelete.isEmpty()) {
            delete toDelete;
        }

        // Recalculate order totals for pending items
        recalculateTotals(openOrder.Id);

        return openOrder.Id;
    }

    /**
     * Moves all current Pending items in the cart into "placed" state.
     * For this backend we keep them as Pending but this is where additional
     * flags could be set for "confirmed" vs "in cart".
     */
    @AuraEnabled
    public static Id placeOrder(Id orderId) {
        if (orderId == null) {
            throw new AuraHandledException('Order Id is required.');
        }
        Order__c ord = [
            SELECT Id, Status__c
            FROM Order__c
            WHERE Id = :orderId
            FOR UPDATE
        ];
        if (ord.Status__c != 'Open') {
            throw new AuraHandledException('Only open orders can be placed.');
        }
        // Move current cart (Pending) to Confirmed (placed but editable until chef accepts).
        List<Order_Item__c> pending = [
            SELECT Id, Status__c
            FROM Order_Item__c
            WHERE Order__c = :orderId
              AND Status__c = 'Pending'
            FOR UPDATE
        ];
        for (Order_Item__c oi : pending) {
            oi.Status__c = 'Confirmed';
        }
        if (!pending.isEmpty()) {
            update pending;
        }

        // Ensure totals are current.
        recalculateTotals(orderId);
        return ord.Id;
    }

    /**
     * Chef accepts one or more order items, transitioning them from Pending to Preparing.
     * After this, the UI should prevent customer edits for these items.
     */
    @AuraEnabled
    public static void chefAcceptItems(List<Id> orderItemIds) {
        if (orderItemIds == null || orderItemIds.isEmpty()) return;

        List<Order_Item__c> items = [
            SELECT Id, Status__c
            FROM Order_Item__c
            WHERE Id IN :orderItemIds
            FOR UPDATE
        ];

        for (Order_Item__c oi : items) {
            if (oi.Status__c == 'Confirmed') {
                oi.Status__c = 'Preparing';
            }
        }
        if (!items.isEmpty()) {
            update items;
        }
    }

    /**
     * Allows updating quantity for Confirmed items (editable after placement
     * but before chef accepts). Only affects items currently in Confirmed status.
     */
    @AuraEnabled
    public static void updateConfirmedItems(List<Order_Item__c> updatedLines) {
        if (updatedLines == null || updatedLines.isEmpty()) return;

        List<Order_Item__c> existing = [
            SELECT Id, Order__c, Quantity__c, Unit_Price__c, Line_Total__c, Status__c
            FROM Order_Item__c
            WHERE Id IN :updatedLines
            FOR UPDATE
        ];
        Map<Id, Order_Item__c> inputById = new Map<Id, Order_Item__c>(updatedLines);

        List<Order_Item__c> toUpdate = new List<Order_Item__c>();
        Id orderId;
        for (Order_Item__c dbLine : existing) {
            if (dbLine.Status__c != 'Confirmed') {
                continue;
            }
            Order_Item__c inLine = inputById.get(dbLine.Id);
            if (inLine == null || inLine.Quantity__c == null || inLine.Quantity__c <= 0) {
                continue;
            }
            dbLine.Quantity__c = inLine.Quantity__c;
            dbLine.Line_Total__c = dbLine.Quantity__c * dbLine.Unit_Price__c;
            orderId = dbLine.Order__c;
            toUpdate.add(dbLine);
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
            if (orderId != null) {
                recalculateTotals(orderId);
            }
        }
    }

    /**
     * Chef marks items as Ready.
     */
    @AuraEnabled
    public static void chefMarkReady(List<Id> orderItemIds) {
        if (orderItemIds == null || orderItemIds.isEmpty()) return;
        List<Order_Item__c> items = [
            SELECT Id, Status__c
            FROM Order_Item__c
            WHERE Id IN :orderItemIds
            FOR UPDATE
        ];
        for (Order_Item__c oi : items) {
            if (oi.Status__c == 'Preparing') {
                oi.Status__c = 'Ready';
            }
        }
        if (!items.isEmpty()) {
            update items;
        }
    }

    /**
     * Waiter marks items as Delivered.
     */
    @AuraEnabled
    public static void waiterMarkDelivered(List<Id> orderItemIds) {
        if (orderItemIds == null || orderItemIds.isEmpty()) return;
        List<Order_Item__c> items = [
            SELECT Id, Status__c
            FROM Order_Item__c
            WHERE Id IN :orderItemIds
            FOR UPDATE
        ];
        for (Order_Item__c oi : items) {
            if (oi.Status__c == 'Ready') {
                oi.Status__c = 'Delivered';
            }
        }
        if (!items.isEmpty()) {
            update items;
        }
    }

    /**
     * Marks the order as Completed once all items are Delivered or Cancelled.
     */
    @AuraEnabled
    public static void completeOrderIfDelivered(Id orderId) {
        if (orderId == null) return;
        List<Order_Item__c> items = [
            SELECT Id, Status__c
            FROM Order_Item__c
            WHERE Order__c = :orderId
        ];
        Boolean allDone = true;
        for (Order_Item__c oi : items) {
            if (oi.Status__c != 'Delivered' && oi.Status__c != 'Cancelled') {
                allDone = false;
                break;
            }
        }
        if (allDone) {
            Order__c ord = [
                SELECT Id, Status__c
                FROM Order__c
                WHERE Id = :orderId
                FOR UPDATE
            ];
            if (ord.Status__c == 'Open') {
                ord.Status__c = 'Completed';
                ord.Order_End_Time__c = System.now();
                update ord;
            }
        }
    }

    /**
     * Records payment (including tip) and marks order as Paid.
     */
    @AuraEnabled
    public static void recordPayment(Id orderId, Decimal tipAmount) {
        if (orderId == null) {
            throw new AuraHandledException('Order Id is required.');
        }
        if (tipAmount == null) tipAmount = 0;

        Order__c ord = [
            SELECT Id, Status__c, Total_Amount__c, Tax_Amount__c, Tip_Amount__c, Grand_Total__c
            FROM Order__c
            WHERE Id = :orderId
            FOR UPDATE
        ];
        if (ord.Status__c != 'Completed' && ord.Status__c != 'Open') {
            throw new AuraHandledException('Only open or completed orders can be paid.');
        }

        ord.Tip_Amount__c = tipAmount;
        if (ord.Total_Amount__c == null) ord.Total_Amount__c = 0;
        if (ord.Tax_Amount__c == null) ord.Tax_Amount__c = 0;
        ord.Grand_Total__c = ord.Total_Amount__c + ord.Tax_Amount__c + ord.Tip_Amount__c;
        ord.Status__c = 'Paid';
        ord.Order_End_Time__c = System.now();

        update ord;
    }

    /**
     * Utility to recalculate totals based on order items.
     * For now, tax is a simple fixed rate (e.g. 10%) which can later
     * be externalized to configuration.
     */
    @AuraEnabled
    public static void recalculateTotals(Id orderId) {
        if (orderId == null) return;

        List<Order_Item__c> items = [
            SELECT Id, Line_Total__c
            FROM Order_Item__c
            WHERE Order__c = :orderId
        ];
        Decimal subtotal = 0;
        for (Order_Item__c oi : items) {
            if (oi.Line_Total__c != null) {
                subtotal += oi.Line_Total__c;
            }
        }

        Decimal taxRate = 0.10; // 10% tax for demo purposes
        Decimal tax = subtotal * taxRate;

        Order__c ord = new Order__c(
            Id = orderId,
            Total_Amount__c = subtotal,
            Tax_Amount__c = tax,
            Grand_Total__c = subtotal + tax
        );
        update ord;
    }
}

