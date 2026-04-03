@IsTest
private class RestaurantOrderServiceTest {

    @IsTest
    static void testUpsertCartAndLifecycle() {
        Restaurant__c rest = new Restaurant__c(Name = 'Test Restaurant');
        insert rest;

        Table__c tableRec = new Table__c(
            Name = 'T1',
            Restaurant__c = rest.Id,
            Seats__c = 4,
            Status__c = 'Available'
        );
        insert tableRec;

        Menu_Item__c menu1 = new Menu_Item__c(
            Name = 'Pasta',
            Restaurant__c = rest.Id,
            Category__c = 'Entree',
            Food_Type__c = 'Vegetarian',
            Price__c = 10
        );
        insert menu1;

        // Build cart
        RestaurantOrderService.CartItem ci = new RestaurantOrderService.CartItem();
        ci.menuItemId = menu1.Id;
        ci.quantity = 2;

        Id orderId = RestaurantOrderService.upsertCart(rest.Id, tableRec.Id, new List<RestaurantOrderService.CartItem>{ ci });
        System.assertNotEquals(null, orderId, 'Order Id should be returned');

        Order__c ord = [
            SELECT Id, Status__c, Total_Amount__c, Tax_Amount__c, Grand_Total__c
            FROM Order__c
            WHERE Id = :orderId
        ];
        System.assertEquals('Open', ord.Status__c, 'Order should be open');
        System.assertEquals(20, ord.Total_Amount__c, 'Subtotal should be quantity * price');
        System.assertEquals(2, ord.Tax_Amount__c, 'Tax should be 10% of subtotal');
        System.assertEquals(22, ord.Grand_Total__c, 'Grand total should be subtotal + tax');

        Order_Item__c line = [
            SELECT Id, Status__c, Quantity__c, Unit_Price__c, Line_Total__c
            FROM Order_Item__c
            WHERE Order__c = :orderId
            LIMIT 1
        ];
        System.assertEquals('Pending', line.Status__c, 'Line should be pending');
        System.assertEquals(2, line.Quantity__c, 'Quantity should match cart');

        // Place order (moves pending to confirmed)
        Test.startTest();
        RestaurantOrderService.placeOrder(orderId);

        // Chef accepts
        RestaurantOrderService.chefAcceptItems(new List<Id>{ line.Id });

        line = [
            SELECT Id, Status__c
            FROM Order_Item__c
            WHERE Id = :line.Id
        ];
        System.assertEquals('Preparing', line.Status__c, 'Line should be preparing after accept');

        // Chef marks ready
        RestaurantOrderService.chefMarkReady(new List<Id>{ line.Id });
        line = [
            SELECT Id, Status__c
            FROM Order_Item__c
            WHERE Id = :line.Id
        ];
        System.assertEquals('Ready', line.Status__c, 'Line should be ready');

        // Waiter delivers
        RestaurantOrderService.waiterMarkDelivered(new List<Id>{ line.Id });
        line = [
            SELECT Id, Status__c
            FROM Order_Item__c
            WHERE Id = :line.Id
        ];
        System.assertEquals('Delivered', line.Status__c, 'Line should be delivered');

        // Complete order when everything is delivered
        RestaurantOrderService.completeOrderIfDelivered(orderId);
        ord = [
            SELECT Id, Status__c
            FROM Order__c
            WHERE Id = :orderId
        ];
        System.assertEquals('Completed', ord.Status__c, 'Order should be completed');

        // Record payment with tip
        RestaurantOrderService.recordPayment(orderId, 3);
        ord = [
            SELECT Id, Status__c, Tip_Amount__c, Grand_Total__c
            FROM Order__c
            WHERE Id = :orderId
        ];
        System.assertEquals('Paid', ord.Status__c, 'Order should be paid');
        System.assertEquals(3, ord.Tip_Amount__c, 'Tip should be stored');
        System.assertEquals(25, ord.Grand_Total__c, 'Grand total should include tip');
        Test.stopTest();
    }
}

