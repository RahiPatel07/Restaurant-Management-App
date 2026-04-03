@IsTest
private class MenuItemListControllerTest {

    @IsTest
    static void testGetMenuAndOrderSummary() {
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
            Name = 'Spring Rolls',
            Restaurant__c = rest.Id,
            Category__c = 'Appetizer',
            Food_Type__c = 'Vegetarian',
            Price__c = 5,
            Is_Top_Seller__c = true
        );
        insert menu1;

        Test.startTest();
        // Load menu
        List<MenuItemListController.MenuItemDTO> items =
            MenuItemListController.getMenuItems(rest.Id, 'Appetizer', 'Vegetarian');
        Test.stopTest();

        System.assertEquals(1, items.size(), 'One menu item should be returned');
        System.assertEquals(menu1.Id, items[0].id, 'Menu item should match');

        // Get or create order summary
        MenuItemListController.OrderSummaryDTO summary =
            MenuItemListController.getOrderSummary(rest.Id, tableRec.Id, true);
        System.assertNotEquals(null, summary, 'Summary should not be null');
        System.assertNotEquals(null, summary.orderId, 'Order should be created');
    }
}

