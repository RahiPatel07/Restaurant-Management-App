@IsTest
private class BillTest {

    @IsTest
    static void testBillLoadAndPaymentFeedback() {
        Restaurant__c rest = new Restaurant__c(Name = 'Bill Test Restaurant');
        insert rest;

        Table__c tableRec = new Table__c(
            Name = 'Bill-T1',
            Restaurant__c = rest.Id,
            Seats__c = 4,
            Status__c = 'Occupied'
        );
        insert tableRec;

        Menu_Item__c menu1 = new Menu_Item__c(
            Name = 'Pizza',
            Restaurant__c = rest.Id,
            Category__c = 'Entree',
            Food_Type__c = 'Vegetarian',
            Price__c = 15
        );
        insert menu1;

        Order__c ord = new Order__c(
            Restaurant__c = rest.Id,
            Table__c = tableRec.Id,
            Status__c = 'Open',
            Order_Start_Time__c = System.now()
        );
        insert ord;

        Order_Item__c line = new Order_Item__c(
            Order__c = ord.Id,
            Menu_Item__c = menu1.Id,
            Quantity__c = 2,
            Unit_Price__c = 15,
            Line_Total__c = 30,
            Status__c = 'Delivered'
        );
        insert line;

        // Set totals to match the line (simulate previous calc)
        ord.Total_Amount__c = 30;
        ord.Tax_Amount__c = 3;
        ord.Grand_Total__c = 33;
        update ord;

        Test.startTest();
        Bill.BillDTO dto = Bill.getBill(ord.Id);
        System.assertEquals(ord.Id, dto.orderId, 'Bill should reference the order');
        System.assertEquals(1, dto.items.size(), 'Should have one line item');

        Decimal tip = 5;
        Integer foodRating = 4;
        Integer serviceRating = 5;
        String comments = 'Great food and service.';

        Bill.BillDTO updated = Bill.savePaymentAndFeedback(
            ord.Id,
            tip,
            foodRating,
            serviceRating,
            comments
        );
        Test.stopTest();

        Order__c ordAfter = [
            SELECT Id, Status__c, Tip_Amount__c, Grand_Total__c
            FROM Order__c
            WHERE Id = :ord.Id
        ];
        System.assertEquals('Paid', ordAfter.Status__c, 'Order should be marked as paid');
        System.assertEquals(tip, ordAfter.Tip_Amount__c, 'Tip should be stored on order');

        Feedback__c fb = [
            SELECT Id, Food_Rating__c, Service_Rating__c, Comments__c
            FROM Feedback__c
            WHERE Order__c = :ord.Id
            LIMIT 1
        ];
        System.assertEquals(foodRating, fb.Food_Rating__c, 'Food rating should be stored');
        System.assertEquals(serviceRating, fb.Service_Rating__c, 'Service rating should be stored');
        System.assertEquals(comments, fb.Comments__c, 'Comments should be stored');

        System.assertNotEquals(null, updated, 'Updated bill DTO should be returned');
    }
}

