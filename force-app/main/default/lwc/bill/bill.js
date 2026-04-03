import { LightningElement, api, track } from 'lwc';
import getBill from '@salesforce/apex/Bill.getBill';
import savePaymentAndFeedback from '@salesforce/apex/Bill.savePaymentAndFeedback';
import getRestaurants from '@salesforce/apex/RestaurantContextController.getRestaurants';
import getTablesForRestaurant from '@salesforce/apex/RestaurantContextController.getTablesForRestaurant';
import getOrdersForTable from '@salesforce/apex/RestaurantContextController.getOrdersForTable';

export default class Bill extends LightningElement {
    @api orderId;

    @track bill;
    @track restaurantOptions = [];
    @track tableOptions = [];
    @track orderOptions = [];
    selectedRestaurantId;
    selectedTableId;
    selectedOrderId;
    tip = 0;
    foodRating;
    serviceRating;
    comments;
    message;

    connectedCallback() {
        this.loadRestaurants();
    }

    loadRestaurants() {
        getRestaurants()
            .then(opts => {
                this.restaurantOptions = opts || [];
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.error('Error loading restaurants', error);
                this.restaurantOptions = [];
            });
    }

    handleRestaurantChange(event) {
        this.selectedRestaurantId = event.detail.value;
        this.selectedTableId = null;
        this.selectedOrderId = null;
        this.tableOptions = [];
        this.orderOptions = [];
        this.bill = null;
        getTablesForRestaurant({ restaurantId: this.selectedRestaurantId })
            .then(opts => {
                this.tableOptions = opts || [];
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.error('Error loading tables for bill', error);
                this.tableOptions = [];
            });
    }

    handleTableChange(event) {
        this.selectedTableId = event.detail.value;
        this.selectedOrderId = null;
        this.orderOptions = [];
        this.bill = null;
        getOrdersForTable({ restaurantId: this.selectedRestaurantId, tableId: this.selectedTableId })
            .then(opts => {
                this.orderOptions = opts || [];
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.error('Error loading orders for bill', error);
                this.orderOptions = [];
            });
    }

    handleOrderChange(event) {
        this.selectedOrderId = event.detail.value;
        this.orderId = this.selectedOrderId;
        this.loadBill();
    }

    loadBill() {
        if (!this.orderId) return;
        getBill({ orderId: this.orderId })
            .then(result => {
                this.bill = result;
                this.tip = result.tip || 0;
                this.foodRating = result.foodRating;
                this.serviceRating = result.serviceRating;
                this.comments = result.comments;
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.error('Error loading bill', error);
                this.bill = null;
            });
    }

    get calculatedTotal() {
        const base = (this.bill && this.bill.subtotal && this.bill.tax)
            ? this.bill.subtotal + this.bill.tax
            : 0;
        const tipVal = parseFloat(this.tip) || 0;
        return base + tipVal;
    }

    handleTipChange(event) {
        this.tip = event.target.value;
    }

    handleFoodRatingChange(event) {
        this.foodRating = event.target.value ? parseInt(event.target.value, 10) : null;
    }

    handleServiceRatingChange(event) {
        this.serviceRating = event.target.value ? parseInt(event.target.value, 10) : null;
    }

    handleCommentsChange(event) {
        this.comments = event.target.value;
    }

    handlePay() {
        if (!this.orderId) return;
        const tipVal = parseFloat(this.tip) || 0;
        savePaymentAndFeedback({
            orderId: this.orderId,
            tipAmount: tipVal,
            foodRating: this.foodRating,
            serviceRating: this.serviceRating,
            comments: this.comments
        })
            .then(updatedBill => {
                this.bill = updatedBill;
                this.message = 'Payment recorded and feedback saved. Thank you!';
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.error('Error saving payment/feedback', error);
                this.message = 'Failed to record payment or feedback.';
            });
    }

    handleBackToCart() {
        /**
         * For now, just fire a simple event so a parent page or app can
         * navigate back to the Menu/Cart screen.
         */
        this.dispatchEvent(new CustomEvent('backtocart', {
            detail: { orderId: this.orderId }
        }));
    }
}

