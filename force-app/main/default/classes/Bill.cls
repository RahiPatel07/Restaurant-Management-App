public with sharing class Bill {

    public class BillItemDTO {
        @AuraEnabled public Id orderItemId;
        @AuraEnabled public String menuItemName;
        @AuraEnabled public Integer quantity;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal lineTotal;
        @AuraEnabled public String status;
    }

    public class BillDTO {
        @AuraEnabled public Id orderId;
        @AuraEnabled public String orderNumber;
        @AuraEnabled public String tableName;
        @AuraEnabled public Decimal subtotal;
        @AuraEnabled public Decimal tax;
        @AuraEnabled public Decimal tip;
        @AuraEnabled public Decimal grandTotal;
        @AuraEnabled public List<BillItemDTO> items;
        @AuraEnabled public Integer foodRating;
        @AuraEnabled public Integer serviceRating;
        @AuraEnabled public String comments;
    }

    /**
     * Loads the bill for a given order, including items and any existing feedback.
     */
    @AuraEnabled(cacheable=true)
    public static BillDTO getBill(Id orderId) {
        if (orderId == null) {
            throw new AuraHandledException('Order Id is required.');
        }

        Order__c ord = [
            SELECT Id, Name, Table__r.Name,
                   Total_Amount__c, Tax_Amount__c,
                   Tip_Amount__c, Grand_Total__c
            FROM Order__c
            WHERE Id = :orderId
            LIMIT 1
        ];

        List<Order_Item__c> lines = [
            SELECT Id, Menu_Item__r.Name,
                   Quantity__c, Unit_Price__c, Line_Total__c, Status__c
            FROM Order_Item__c
            WHERE Order__c = :orderId
            ORDER BY CreatedDate
        ];

        Feedback__c fb = null;
        List<Feedback__c> existingFb = [
            SELECT Id, Food_Rating__c, Service_Rating__c, Comments__c
            FROM Feedback__c
            WHERE Order__c = :orderId
            LIMIT 1
        ];
        if (!existingFb.isEmpty()) {
            fb = existingFb[0];
        }

        List<BillItemDTO> itemDtos = new List<BillItemDTO>();
        for (Order_Item__c line : lines) {
            BillItemDTO dto = new BillItemDTO();
            dto.orderItemId = line.Id;
            dto.menuItemName = line.Menu_Item__r.Name;
            dto.quantity = Integer.valueOf(line.Quantity__c);
            dto.unitPrice = line.Unit_Price__c;
            dto.lineTotal = line.Line_Total__c;
            dto.status = line.Status__c;
            itemDtos.add(dto);
        }

        BillDTO bill = new BillDTO();
        bill.orderId = ord.Id;
        bill.orderNumber = ord.Name;
        bill.tableName = ord.Table__r != null ? ord.Table__r.Name : null;
        bill.subtotal = ord.Total_Amount__c;
        bill.tax = ord.Tax_Amount__c;
        bill.tip = ord.Tip_Amount__c;
        bill.grandTotal = ord.Grand_Total__c;
        bill.items = itemDtos;
        if (fb != null) {
            bill.foodRating = fb.Food_Rating__c != null ? Integer.valueOf(fb.Food_Rating__c) : null;
            bill.serviceRating = fb.Service_Rating__c != null ? Integer.valueOf(fb.Service_Rating__c) : null;
            bill.comments = fb.Comments__c;
        }

        return bill;
    }

    /**
     * Saves tip/payment info and feedback for the order.
     * Returns the updated bill summary.
     */
    @AuraEnabled
    public static BillDTO savePaymentAndFeedback(
        Id orderId,
        Decimal tipAmount,
        Integer foodRating,
        Integer serviceRating,
        String comments
    ) {
        if (orderId == null) {
            throw new AuraHandledException('Order Id is required.');
        }

        // Record payment (this sets order to Paid).
        RestaurantOrderService.recordPayment(orderId, tipAmount);

        // Upsert feedback.
        Feedback__c fb;
        List<Feedback__c> existing = [
            SELECT Id
            FROM Feedback__c
            WHERE Order__c = :orderId
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            fb = existing[0];
        } else {
            fb = new Feedback__c(
                Order__c = orderId
            );
        }
        fb.Food_Rating__c = foodRating;
        fb.Service_Rating__c = serviceRating;
        fb.Comments__c = comments;

        upsert fb;

        // Return fresh bill summary.
        return getBill(orderId);
    }
}

