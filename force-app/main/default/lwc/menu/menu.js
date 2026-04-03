import { LightningElement, api, track } from 'lwc';
import getMenuItems from '@salesforce/apex/MenuItemListController.getMenuItems';
import getOrderSummary from '@salesforce/apex/MenuItemListController.getOrderSummary';
import updateConfirmedOrderItems from '@salesforce/apex/MenuItemListController.updateConfirmedOrderItems';
import saveCart from '@salesforce/apex/MenuItemListController.saveCart';
import placeOrder from '@salesforce/apex/MenuItemListController.placeOrder';
import getRestaurants from '@salesforce/apex/RestaurantContextController.getRestaurants';
import getTablesForRestaurant from '@salesforce/apex/RestaurantContextController.getTablesForRestaurant';

export default class Menu extends LightningElement {
    @api restaurantId;
    @api tableId;

    @track menuItems;
    @track cartItems = [];
    @track billedItems = [];

    @track subtotal = 0;
    @track tax = 0;
    @track grandTotal = 0;
    @track etaMinutes;

    selectedCategory = 'Appetizer';
    selectedFoodType = 'Vegetarian';
    orderId;

    quantityByMenuId = {};

    @track restaurantOptions = [];
    @track tableOptions = [];
    selectedRestaurantId;
    selectedTableId;
    @track message;

    get displayedMenuItems() {
        return (this.menuItems || []).map(item => ({
            ...item,
            selectedQty: this.quantityByMenuId[item.id] || 0
        }));
    }

    get hasCartItems() {
        return this.cartItems && this.cartItems.length > 0;
    }

    get hasBilledItems() {
        return this.billedItems && this.billedItems.length > 0;
    }

    connectedCallback() {
        this.loadRestaurants();
    }

    loadRestaurants() {
        getRestaurants()
            .then(opts => {
                this.restaurantOptions = opts || [];
                const preferredRestaurant = this.restaurantId || (this.restaurantOptions[0] && this.restaurantOptions[0].value);
                if (preferredRestaurant) {
                    this.selectedRestaurantId = preferredRestaurant;
                    this.restaurantId = preferredRestaurant;
                    this.loadTables();
                    this.loadMenu();
                }
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.error('Error loading restaurants', error);
                this.restaurantOptions = [];
            });
    }

    loadTables() {
        if (!this.restaurantId) return;
        getTablesForRestaurant({ restaurantId: this.restaurantId })
            .then(opts => {
                this.tableOptions = opts || [];
                const preferredTable = this.tableId || (this.tableOptions[0] && this.tableOptions[0].value);
                if (preferredTable) {
                    this.selectedTableId = preferredTable;
                    this.tableId = preferredTable;
                    this.loadOrderSummary(true);
                }
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.error('Error loading tables', error);
                this.tableOptions = [];
            });
    }

    handleRestaurantChange(event) {
        this.selectedRestaurantId = event.detail.value;
        this.restaurantId = this.selectedRestaurantId;
        this.selectedTableId = null;
        this.tableId = null;
        this.cartItems = [];
        this.billedItems = [];
        this.loadMenu();
        this.loadTables();
    }

    handleTableChange(event) {
        this.selectedTableId = event.detail.value;
        this.tableId = this.selectedTableId;
        this.quantityByMenuId = {};
        this.loadOrderSummary(true);
    }

    get appetizersTabClass() {
        return this.selectedCategory === 'Appetizer'
            ? 'slds-button slds-button_brand'
            : 'slds-button slds-button_neutral';
    }

    get entreesTabClass() {
        return this.selectedCategory === 'Entree'
            ? 'slds-button slds-button_brand'
            : 'slds-button slds-button_neutral';
    }

    get dessertsTabClass() {
        return this.selectedCategory === 'Dessert'
            ? 'slds-button slds-button_brand'
            : 'slds-button slds-button_neutral';
    }

    get vegVariant() {
        return this.selectedFoodType === 'Vegetarian' ? 'brand' : 'neutral';
    }

    get nonVegVariant() {
        return this.selectedFoodType
         === 'Non-Vegetarian' ? 'brand' : 'neutral';
    }

    get veganVariant() {
        return this.selectedFoodType === 'Vegan' ? 'brand' : 'neutral';
    }

    get disablePlaceOrder() {
        return !this.orderId || (!this.cartItems || this.cartItems.length === 0);
    }

    readIdFromEvent(event) {
        // lightning-base components sometimes don’t expose dataset on currentTarget in the same way.
        // Fallback to target.dataset for reliability.
        return event?.currentTarget?.dataset?.id || event?.target?.dataset?.id;
    }

    extractErrorMessage(error) {
        // Best-effort extraction for Apex/LWC wire errors.
        if (error && error.body && error.body.message) return error.body.message;
        if (error && error.message) return error.message;
        return 'Unknown error';
    }

    handleCategoryClick(event) {
        const category = event.currentTarget.dataset.category;
        this.selectedCategory = category;
        this.loadMenu();
    }

    handleFoodTypeClick(event) {
        const type = event.currentTarget.dataset.type;
        this.selectedFoodType = type;
        this.loadMenu();
    }

    loadMenu() {
        if (!this.restaurantId) {
            return;
        }
        getMenuItems({
            restaurantId: this.restaurantId,
            category: this.selectedCategory,
            foodType: this.selectedFoodType
        })
            .then(result => {
                this.menuItems = result;
            })
            .catch(error => {
                // In production you might surface this; for now just log.
                // eslint-disable-next-line no-console
                console.error('Error loading menu items', error);
            });
    }

    loadOrderSummary(createIfMissing) {
        if (!this.restaurantId || !this.tableId) {
            return;
        }
        this.message = null;
        getOrderSummary({
            restaurantId: this.restaurantId,
            tableId: this.tableId,
            createIfMissing: createIfMissing
        })
            .then(summary => {
                if (!summary) {
                    this.cartItems = [];
                    this.billedItems = [];
                    this.subtotal = 0;
                    this.tax = 0;
                    this.grandTotal = 0;
                    this.etaMinutes = null;
                    return;
                }
                this.orderId = summary.orderId;
                this.cartItems = summary.cartItems || [];
                this.billedItems = (summary.billedItems || []).map(line => ({
                    ...line,
                    isConfirmed: line.status === 'Confirmed'
                }));
                this.subtotal = summary.subtotal || 0;
                this.tax = summary.tax || 0;
                this.grandTotal = summary.grandTotal || 0;
                this.etaMinutes = summary.etaMinutes || null;
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.error('Error loading order summary', error);
                this.message = 'Failed to load cart/order summary: ' + this.extractErrorMessage(error);
            });
    }

    increaseQuantity(event) {
        const id = this.readIdFromEvent(event);
        if (!id) return;
        const current = this.quantityByMenuId[id] || 0;
        this.quantityByMenuId = {
            ...this.quantityByMenuId,
            [id]: current + 1
        };
    }

    decreaseQuantity(event) {
        const id = this.readIdFromEvent(event);
        if (!id) return;
        const current = this.quantityByMenuId[id] || 0;
        const next = current - 1;
        this.quantityByMenuId = {
            ...this.quantityByMenuId,
            [id]: next > 0 ? next : 0
        };
    }

    addToCart(event) {
        const id = this.readIdFromEvent(event);
        if (!id) {
            this.message = 'Could not detect menu item id (data-id missing).';
            return;
        }
        let qty = this.quantityByMenuId[id] || 0;

        // If user clicks “Add” without pressing +, we treat it as qty=1.
        if (qty <= 0) {
            qty = 1;
            this.quantityByMenuId = {
                ...this.quantityByMenuId,
                [id]: qty
            };
        }

        this.persistCart();
    }

    handleResetCart() {
        this.quantityByMenuId = {};
        // Send an empty cart to backend to clear pending items
        this.persistCart(true);
    }

    persistCart(clearCart = false) {
        if (!this.restaurantId || !this.tableId) {
            this.message = 'Select Restaurant and Table first.';
            return;
        }

        this.message = null;
        let cartItemsPayload = [];
        if (!clearCart) {
            Object.keys(this.quantityByMenuId).forEach(menuItemId => {
                const qty = this.quantityByMenuId[menuItemId];
                if (qty > 0) {
                    cartItemsPayload.push({
                        menuItemId: menuItemId,
                        quantity: qty
                    });
                }
            });
        }

        if (!clearCart && cartItemsPayload.length === 0) {
            this.message = 'Cart payload is empty. Click the + icon first, then Add.';
            return;
        }

        saveCart({
            restaurantId: this.restaurantId,
            tableId: this.tableId,
            cartItemsJson: JSON.stringify(cartItemsPayload)  // ✅ stringify here
        })
            .then(orderId => {
                this.orderId = orderId;
                this.loadOrderSummary(true);
                this.message = 'Cart updated.';
            })
            .catch(error => {
                console.error('Error saving cart', error);
                this.message = 'Failed to update cart: ' + this.extractErrorMessage(error);
            });
    }

    handlePlaceOrder() {
        if (!this.orderId) {
            this.message = 'No open order found for this table.';
            return;
        }
        this.message = null;
        placeOrder({ orderId: this.orderId })
            .then(() => {
                // After placing order, clear local cart quantities and refresh summary
                this.quantityByMenuId = {};
                this.loadOrderSummary(true);
                this.message = 'Order placed.';
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.error('Error placing order', error);
                this.message = 'Failed to place order. Check console logs for details.';
            });
    }

    // --- Editing confirmed billed items (simple inline quantity update) ---

    handleIncreaseConfirmed(event) {
        const id = this.readIdFromEvent(event);
        if (!id) return;
        this.updateConfirmedQuantity(id, 1);
    }

    handleDecreaseConfirmed(event) {
        const id = this.readIdFromEvent(event);
        if (!id) return;
        this.updateConfirmedQuantity(id, -1);
    }

    updateConfirmedQuantity(lineId, delta) {
        const idx = this.billedItems.findIndex(l => l.id === lineId);
        if (idx === -1) return;
        const line = this.billedItems[idx];
        if (line.status !== 'Confirmed') return;
        const newQty = (line.quantity || 0) + delta;
        if (newQty <= 0) return;

        updateConfirmedOrderItems({
            updatedLines: [{
                Id: line.id,
                Quantity__c: newQty
            }]
        })
            .then(() => {
                this.loadOrderSummary(false);
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.error('Error updating confirmed item', error);
            });
    }
}

