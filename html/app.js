const InventoryContainer = Vue.createApp({
    data() {
        return this.getInitialState();
    },
    computed: {
        playerWeight() {
            const weight = Object.values(this.playerInventory).reduce((total, item) => {
                if (item && item.weight !== undefined && item.amount !== undefined) {
                    return total + item.weight * item.amount;
                }
                return total;
            }, 0);
            return isNaN(weight) ? 0 : weight;
        },
        otherInventoryWeight() {
            const weight = Object.values(this.otherInventory).reduce((total, item) => {
                if (item && item.weight !== undefined && item.amount !== undefined) {
                    return total + item.weight * item.amount;
                }
                return total;
            }, 0);
            return isNaN(weight) ? 0 : weight;
        },
        weightBarClass() {
            const weightPercentage = (this.playerWeight / this.maxWeight) * 100;
            if (weightPercentage < 50) {
                return "low";
            } else if (weightPercentage < 75) {
                return "medium";
            } else {
                return "high";
            }
        },
        otherWeightBarClass() {
            const weightPercentage = (this.otherInventoryWeight / this.otherInventoryMaxWeight) * 100;
            if (weightPercentage < 50) {
                return "low";
            } else if (weightPercentage < 75) {
                return "medium";
            } else {
                return "high";
            }
        },
        shouldCenterInventory() {
            return this.isOtherInventoryEmpty;
        },
    },
    watch: {
        popupTransferAmount(newVal) {
            if (this.itemToMove) { // Ensure we have an item context
                if (newVal === null || newVal === '') {
                    // Allow it to be empty momentarily for typing, or set to 1
                    // this.popupTransferAmount = ''; // Or handle as desired
                    return;
                }
                const val = parseInt(newVal, 10);
                if (isNaN(val) || val < 1) {
                    this.popupTransferAmount = 1;
                } else if (val > this.itemToMove.amount) {
                    this.popupTransferAmount = this.itemToMove.amount;
                } else {
                    this.popupTransferAmount = val; // Ensure it's the parsed number
                }
            } else if (newVal < 1 && newVal !== null) {
                this.popupTransferAmount = 1;
            }
        },
        showQuantityPopup(isShowing) {
            if (isShowing) {
                this.$nextTick(() => { // Wait for the DOM to update
                    if (this.$refs.quantityPopupInput) {
                        this.$refs.quantityPopupInput.focus();
                        this.$refs.quantityPopupInput.select();
                    }
                });
            }
        },
    },
    methods: {
        getInitialState() {
            return {
                // Config Options
                maxWeight: 0,
                totalSlots: 0,
                // Escape Key
                isInventoryOpen: false,
                // Single pane
                isOtherInventoryEmpty: true,
                // Error handling
                errorSlot: null,
                // Player Inventory
                playerInventory: {},
                inventoryLabel: "Inventory",
                totalWeight: 0,
                // Other inventory
                otherInventory: {},
                otherInventoryName: "",
                otherInventoryLabel: "Drop",
                otherInventoryMaxWeight: 1000000,
                otherInventorySlots: 100,
                isShopInventory: false,
                // Where item is coming from
                inventory: "",
                // Context Menu
                showContextMenu: false,
                contextMenuPosition: { top: "0px", left: "0px" },
                contextMenuItem: null,
                showSubmenu: false,
                // Hotbar
                showHotbar: false,
                hotbarItems: [],
                // Notification box
                showNotification: false,
                notificationText: "",
                notificationImage: "",
                notificationType: "added",
                notificationAmount: 1,
                // Required items box
                showRequiredItems: false,
                requiredItems: [],
                // Attachments
                selectedWeapon: null,
                showWeaponAttachments: false,
                selectedWeaponAttachments: [],
                // Dragging and dropping
                currentlyDraggingItem: null,
                currentlyDraggingSlot: null,
                dragStartX: 0,
                dragStartY: 0,
                ghostElement: null,
                dragStartInventoryType: "player",
                transferAmount: null,
                //added for item specific weight limits
                itemSpecificMaxWeights: {},
                //
                showQuantityPopup: false,
                itemToMove: null,         // To store the item being considered for moving
                popupTransferAmount: 1,
            };
        },
        openInventory(data) {
            console.log("app.js: openInventory() called with data:", JSON.parse(JSON.stringify(data))); // Log incoming data
            if (this.showHotbar) {
                this.toggleHotbar({ open: false, items: [] });
            }

            this.isInventoryOpen = true;
            this.maxWeight = data.maxweight;
            this.itemSpecificMaxWeights = data.itemSpecificMaxWeights || {};
            this.totalSlots = data.slots;
            
            this.playerInventory = {};
            this.otherInventory = {};

            // Default other inventory states before processing data.other
            this.otherInventoryName = "";
            this.otherInventoryLabel = "Drop"; // Default if not overridden
            this.otherInventoryMaxWeight = 0;
            this.otherInventorySlots = 0;
            this.isShopInventory = false;
            // this.isOtherInventoryEmpty = true; // We will set this based on data.other below

            // Process player inventory
            if (data.inventory) {
                const processPlayerItem = (item) => {
                    if (item && typeof item.slot !== 'undefined') {
                        this.playerInventory[item.slot] = { ...item, inventory: 'player' };
                    }
                };
                if (Array.isArray(data.inventory)) {
                    data.inventory.forEach(processPlayerItem);
                } else if (typeof data.inventory === "object" && data.inventory !== null) {
                    for (const key in data.inventory) {
                        processPlayerItem(data.inventory[key]);
                    }
                }
            }

            // Process other inventory
            if (data.other && typeof data.other === 'object' && data.other.name) { // A valid 'other' inventory context exists if data.other is an object with a name
                this.isOtherInventoryEmpty = false; // <<< KEY CHANGE: If data.other is valid, the panel should show

                this.otherInventoryName = data.other.name;
                this.otherInventoryLabel = data.other.label || "Drop"; // Use provided label or default
                this.otherInventoryMaxWeight = data.other.maxweight || Config.DropSize.maxweight; // Fallback to a generic drop size if specific not set
                this.otherInventorySlots = data.other.slots || Config.DropSize.slots;         // Fallback for slots
                this.isShopInventory = this.otherInventoryName.startsWith("shop-");

                // Now, populate this.otherInventory if items are present
                if (data.other.inventory && (Array.isArray(data.other.inventory) || (typeof data.other.inventory === "object" && data.other.inventory !== null))) {
                    const processOtherItem = (item) => {
                        if (item && typeof item.slot !== 'undefined') {
                            this.otherInventory[item.slot] = { ...item, inventory: 'other' };
                        }
                    };
                    if (Array.isArray(data.other.inventory)) {
                        data.other.inventory.forEach(processOtherItem);
                    } else { 
                        for (const key in data.other.inventory) {
                            processOtherItem(data.other.inventory[key]);
                        }
                    }
                }
                // Note: The visual emptiness (no items shown in the grid) is handled by the v-for in the template.
                // isOtherInventoryEmpty now strictly controls if the *panel itself* is rendered.
            } else {
                // No valid data.other was provided, so there is no "other" inventory panel to show.
                this.isOtherInventoryEmpty = true;
            }
            
            console.log(`app.js: isInventoryOpen set to ${this.isInventoryOpen}, isOtherInventoryEmpty set to ${this.isOtherInventoryEmpty}`);
            // console.log("Player Inv after open:", JSON.parse(JSON.stringify(this.playerInventory)));
            // console.log("Other Inv after open:", JSON.parse(JSON.stringify(this.otherInventory)));
        },
        updateInventory(data) { // This method also needs to add the 'inventory' property
            console.log("app.js: updateInventory() called with data:", data);
            this.playerInventory = {}; // Reset before update

            if (data.inventory) {
                const processPlayerItem = (item) => {
                    if (item && typeof item.slot !== 'undefined') {
                        this.playerInventory[item.slot] = { ...item, inventory: 'player' }; // Add 'inventory' property
                    }
                };
                if (Array.isArray(data.inventory)) {
                    data.inventory.forEach(processPlayerItem);
                } else if (typeof data.inventory === "object" && data.inventory !== null) {
                    for (const key in data.inventory) {
                        processPlayerItem(data.inventory[key]);
                    }
                }
            }
            // For debugging:
            // console.log("Player Inv after update (with .inventory):", JSON.parse(JSON.stringify(this.playerInventory)));
        },
        async closeInventory() {
            this.clearDragData();
            let inventoryName = this.otherInventoryName;
            Object.assign(this, this.getInitialState());
            try {
                await axios.post("https://qb-inventory/CloseInventory", { name: inventoryName });
            } catch (error) {
                console.error("Error closing inventory:", error);
            }
        },
        getCurrentItemTypeWeight(inventoryObject, itemName) {
            let currentTypeWeight = 0;
            if (!inventoryObject || typeof inventoryObject !== 'object' || !itemName) {
                return 0;
            }
            const itemLower = itemName.toLowerCase();
            for (const slot in inventoryObject) {
                const item = inventoryObject[slot];
                if (item && item.name && item.name.toLowerCase() === itemLower && typeof item.weight === 'number' && typeof item.amount === 'number') {
                    currentTypeWeight += item.weight * item.amount;
                }
            }
            return currentTypeWeight;
        },
        // --- NEW METHODS for Quantity Popup ---
        promptMoveQuantity(item) {
            if (!item || this.isOtherInventoryEmpty || this.otherInventoryName.startsWith("shop-")) {
                return; // Don't show popup if not applicable
            }
            this.itemToMove = item;
            this.popupTransferAmount = 1; // Default to 1 or Math.min(1, item.amount) if you prefer
            this.showQuantityPopup = true;
            this.showContextMenu = false; // Hide the main context menu
        },

        confirmMoveQuantity() {
            console.log("[confirmMoveQuantity] Item to move:", this.itemToMove ? JSON.parse(JSON.stringify(this.itemToMove)) : null, "Amount:", this.popupTransferAmount);
            if (this.itemToMove && this.popupTransferAmount > 0 && this.itemToMove.amount >= this.popupTransferAmount) {
                const sourceInventoryType = this.itemToMove.inventory; // This is where it needs the property

                if (!sourceInventoryType) { // This condition should no longer be met if openInventory is fixed
                    console.error("[confirmMoveQuantity] Error: itemToMove is missing 'inventory' property!");
                    this.cancelMoveQuantity(); // Or your method to close the popup
                    return;
                }
                this.moveItemBetweenInventories(this.itemToMove, sourceInventoryType, this.popupTransferAmount);
            } else {
                console.error("[confirmMoveQuantity] Condition not met, invalid amount, or no item to move.");
            }
            this.cancelMoveQuantity(); // Or your method to close the popup (e.g., closeQuantityPopup)
        },
        // Ensure you have one of these defined:
        cancelMoveQuantity() { // This is the likely correct name now
            this.showQuantityPopup = false;
            this.itemToMove = null;
            this.popupTransferAmount = 1;
        },
        // --- END NEW METHODS ---
        clearTransferAmount() {
            this.transferAmount = null;
        },
        getItemInSlot(slot, inventoryType) {
            if (inventoryType === "player") {
                return this.playerInventory[slot] || null;
            } else if (inventoryType === "other") {
                return this.otherInventory[slot] || null;
            }
            return null;
        },
        getHotbarItemInSlot(slot) {
            return this.hotbarItems[slot - 1] || null;
        },
        containerMouseDownAction(event) {
            if (event.button === 0 && this.showContextMenu) {
                this.showContextMenu = false;
            }
        },
        handleMouseDown(event, slot, inventory) {
            if (event.button === 1) return; // skip middle mouse
            event.preventDefault();
            const itemInSlot = this.getItemInSlot(slot, inventory);
            if (event.button === 0) {
                if (itemInSlot) {
                    this.startDrag(event, slot, inventory);
                }
            } else if (event.button === 2 && itemInSlot) {
                if (this.otherInventoryName.startsWith("shop-")) {
                    this.handlePurchase(slot, itemInSlot.slot, itemInSlot, 1);
                    return;
                }
                this.showContextMenuOptions(event, itemInSlot);
            }
        },
        moveItemBetweenInventories(item, sourceInventoryType, quantityToTransfer) {
    console.log(`[MOVING ITEM VIA MENU] START -----------`);
    console.log(`[MOVING ITEM VIA MENU] Item To Move (Original): ${item.name} (Slot ${item.slot}), Amount Attempting: ${quantityToTransfer}, From Source Type: ${sourceInventoryType}`);
    console.log(`[MOVING ITEM VIA MENU] Full Item Details:`, JSON.parse(JSON.stringify(item)));

    const sourceInventory = sourceInventoryType === "player" ? this.playerInventory : this.otherInventory;
    const targetInventory = sourceInventoryType === "player" ? this.otherInventory : this.playerInventory;
    const targetInventoryIsPlayer = targetInventory === this.playerInventory;

    console.log(`[MOVING ITEM VIA MENU] Source Inventory Is: ${sourceInventoryType}`);
    console.log(`[MOVING ITEM VIA MENU] Target Inventory Will Be: ${targetInventoryIsPlayer ? 'player' : 'other'}`);

    const currentWeightOfTargetInv = targetInventoryIsPlayer ? this.playerWeight : this.otherInventoryWeight;
    const maxWeightOfTargetInv = targetInventoryIsPlayer ? this.maxWeight : this.otherInventoryMaxWeight;
    const maxSlotsForTargetInv = targetInventoryIsPlayer ? this.totalSlots : this.otherInventorySlots;

    console.log(`[MOVING ITEM VIA MENU] Target Inv Current W: ${currentWeightOfTargetInv}, Target Inv Max W: ${maxWeightOfTargetInv}, Target Inv Max Slots: ${maxSlotsForTargetInv}`);
    console.log(`[MOVING ITEM VIA MENU] Player ItemSpecificLimits:`, JSON.parse(JSON.stringify(this.itemSpecificMaxWeights)));

    const amountToTransfer = quantityToTransfer; // Already validated by popup watcher and confirmMoveQuantity

    const sourceItem = sourceInventory[item.slot]; // Get the most current state of the source item

    if (!sourceItem) {
        console.error("[MOVING ITEM VIA MENU] Error: Source item not found in slot", item.slot, "of", sourceInventoryType, "inventory.");
        this.inventoryError(item.slot); // Highlight original slot if possible
        return;
    }
    if (sourceItem.amount < amountToTransfer) {
        console.error(`[MOVING ITEM VIA MENU] Error: Not enough items in source slot. Have: ${sourceItem.amount}, Need: ${amountToTransfer}`);
        this.inventoryError(item.slot);
        axios.post(`https://qb-inventory/notify`, { message: `Not enough ${sourceItem.label || sourceItem.name} to move.`, type: 'error' });
        return;
    }

    const itemBaseWeight = sourceItem.weight || 0;
    const weightOfItemsToTransfer = itemBaseWeight * amountToTransfer;
    console.log(`[MOVING ITEM VIA MENU] Calculated weight of items to transfer (${sourceItem.name} x${amountToTransfer}): ${weightOfItemsToTransfer}`);

    // 1. Overall Max Weight Check for the Target Inventory
    const proposedNewTotalWeight = (Number(currentWeightOfTargetInv) || 0) + weightOfItemsToTransfer;
    console.log(`[MOVING ITEM VIA MENU] Overall Weight Check for Target: Current=${currentWeightOfTargetInv}, Adding=${weightOfItemsToTransfer}, ProposedTotal=${proposedNewTotalWeight}, MaxAllowed=${maxWeightOfTargetInv}`);
    if (proposedNewTotalWeight > maxWeightOfTargetInv) {
        this.inventoryError(item.slot); // Highlight source slot
        console.error("[MOVING ITEM VIA MENU] Error: Overall max weight would be exceeded for target inventory.");
        axios.post(`https://qb-inventory/notify`, { message: 'Target inventory is too full (overall weight).', type: 'error' });
        return;
    }

    // 2. Item-Specific Max Weight Check (Only if target is player inventory)
    if (targetInventoryIsPlayer) {
        const itemNameToCheck = sourceItem.name.toLowerCase();
        const specificLimit = this.itemSpecificMaxWeights && this.itemSpecificMaxWeights[itemNameToCheck];
        console.log(`[MOVING ITEM VIA MENU] ItemSpecific Check for ${itemNameToCheck}. Limit for this item: ${specificLimit === undefined ? 'N/A' : specificLimit}`);

        if (typeof specificLimit === 'number') { // Check if a specific limit exists for this item
            const currentItemWeightInPlayerInv = this.getCurrentItemTypeWeight(this.playerInventory, sourceItem.name);
            // additionalWeightOfThisType is weightOfItemsToTransfer
            console.log(`[MOVING ITEM VIA MENU] ItemSpecific Details: CurrentInPlayer=${currentItemWeightInPlayerInv}, Adding=${weightOfItemsToTransfer}, ProposedSpecificTotal=${currentItemWeightInPlayerInv + weightOfItemsToTransfer}`);

            if (currentItemWeightInPlayerInv + weightOfItemsToTransfer > specificLimit) {
                console.error(`[MOVING ITEM VIA MENU] Error: Item-specific weight limit for ${itemNameToCheck} exceeded.`);
                this.inventoryError(item.slot); // Highlight source slot
                axios.post(`https://qb-inventory/notify`, { message: `You cannot carry any more ${sourceItem.label || sourceItem.name}.`, type: 'error' });
                return;
            }
        }
    }
    console.log("[MOVING ITEM VIA MENU] All client-side weight checks passed.");

    // --- Item Placement Logic (Stacking or New Slot) ---
    let targetSlot = null;
    const itemToPlace = { // Create a new object for the target to avoid reactivity issues if modifying sourceItem directly before removing
        ...sourceItem,
        amount: amountToTransfer,
        inventory: targetInventoryIsPlayer ? 'player' : 'other' // Set correct new inventory context
        // 'slot' will be set below
    };

    if (sourceItem.unique) {
        console.log(`[MOVING ITEM VIA MENU] Item ${sourceItem.name} is unique. Finding new slot.`);
        targetSlot = this.findNextAvailableSlot(targetInventory, maxSlotsForTargetInv);
        if (targetSlot === null) {
            this.inventoryError(item.slot);
            axios.post(`https://qb-inventory/notify`, { message: 'No empty slot available in target inventory for unique item.', type: 'error' });
            console.error("[MOVING ITEM VIA MENU] Error: No empty slot for unique item.");
            return;
        }
        console.log(`[MOVING ITEM VIA MENU] Unique item will be placed in new slot: ${targetSlot}`);
        itemToPlace.slot = targetSlot;
        targetInventory[targetSlot] = itemToPlace;
    } else { // Stackable item
        console.log(`[MOVING ITEM VIA MENU] Item ${sourceItem.name} is stackable. Checking for existing stack in target.`);
        let existingStackTargetSlot = null;
        for (const key in targetInventory) {
            const existingItem = targetInventory[key];
            if (existingItem && existingItem.name === sourceItem.name && !existingItem.unique) {
                existingStackTargetSlot = existingItem.slot; // Assuming item objects store their slot
                break;
            }
        }

        if (existingStackTargetSlot !== null) { // Found existing stack
            targetSlot = existingStackTargetSlot;
            console.log(`[MOVING ITEM VIA MENU] Found existing stack of ${sourceItem.name} in target slot: ${targetSlot}. Current amount: ${targetInventory[targetSlot].amount}`);
            targetInventory[targetSlot].amount += amountToTransfer;
            console.log(`[MOVING ITEM VIA MENU] New amount in target slot ${targetSlot}: ${targetInventory[targetSlot].amount}`);
        } else { // No existing stack, find new slot
            console.log(`[MOVING ITEM VIA MENU] No existing stack for ${sourceItem.name}. Finding new slot.`);
            targetSlot = this.findNextAvailableSlot(targetInventory, maxSlotsForTargetInv);
            if (targetSlot === null) {
                this.inventoryError(item.slot);
                axios.post(`https://qb-inventory/notify`, { message: 'No empty slot available in target inventory for new stack.', type: 'error' });
                console.error("[MOVING ITEM VIA MENU] Error: No empty slot for new stack.");
                return;
            }
            console.log(`[MOVING ITEM VIA MENU] New stack for ${sourceItem.name} will be placed in new slot: ${targetSlot}`);
            itemToPlace.slot = targetSlot;
            targetInventory[targetSlot] = itemToPlace;
        }
    }

    // Update source inventory
    console.log(`[MOVING ITEM VIA MENU] Updating source inventory. Original slot: ${item.slot}, Original amount: ${sourceInventory[item.slot] ? sourceInventory[item.slot].amount : 'N/A - already deleted?'}`);
    if (sourceInventory[item.slot]) { // Check if it still exists (it should)
        sourceInventory[item.slot].amount -= amountToTransfer;
        if (sourceInventory[item.slot].amount <= 0) {
            console.log(`[MOVING ITEM VIA MENU] Deleting item from source slot ${item.slot} as amount is now <= 0.`);
            delete sourceInventory[item.slot];
        } else {
            console.log(`[MOVING ITEM VIA MENU] New amount in source slot ${item.slot}: ${sourceInventory[item.slot].amount}`);
        }
    } else {
        console.warn(`[MOVING ITEM VIA MENU] Source item at slot ${item.slot} was unexpectedly missing before amount update.`);
    }
    
    const newAmountInSourceSlot = sourceInventory[item.slot] ? sourceInventory[item.slot].amount : 0;

    console.log(`[MOVING ITEM VIA MENU] Calling postInventoryData: FromInv=${sourceInventoryType}, ToInv=${targetInventoryIsPlayer ? 'player' : 'other'}, FromSlot=${item.slot}, ToSlot=${targetSlot}, NewSourceAmt=${newAmountInSourceSlot}, MovedAmt=${amountToTransfer}`);
    this.postInventoryData(
        sourceInventoryType, 
        targetInventoryIsPlayer ? 'player' : 'other', 
        item.slot,  // Original slot of the item in the source inventory
        targetSlot, // Slot where item ended up in target inventory
        newAmountInSourceSlot, 
        amountToTransfer
    );
    console.log(`[MOVING ITEM VIA MENU] SUCCESS: ${sourceItem.name} processed for move.`)
    console.log(`[MOVING ITEM VIA MENU] END -------------`);
},
        startDrag(event, slot, inventoryType) {
            event.preventDefault();
            const item = this.getItemInSlot(slot, inventoryType);
            if (!item) return;
            const slotElement = event.target.closest(".item-slot");
            if (!slotElement) return;
            const ghostElement = this.createGhostElement(slotElement);
            document.body.appendChild(ghostElement);
            const offsetX = ghostElement.offsetWidth / 2;
            const offsetY = ghostElement.offsetHeight / 2;
            ghostElement.style.left = `${event.clientX - offsetX}px`;
            ghostElement.style.top = `${event.clientY - offsetY}px`;
            this.ghostElement = ghostElement;
            this.currentlyDraggingItem = item;
            this.currentlyDraggingSlot = slot;
            this.dragStartX = event.clientX;
            this.dragStartY = event.clientY;
            this.dragStartInventoryType = inventoryType;
            this.showContextMenu = false;
        },
        createGhostElement(slotElement) {
            const ghostElement = slotElement.cloneNode(true);
            ghostElement.style.position = "absolute";
            ghostElement.style.pointerEvents = "none";
            ghostElement.style.opacity = "0.7";
            ghostElement.style.zIndex = "1000";
            ghostElement.style.width = getComputedStyle(slotElement).width;
            ghostElement.style.height = getComputedStyle(slotElement).height;
            ghostElement.style.boxSizing = "border-box";
            return ghostElement;
        },
        drag(event) {
            if (!this.currentlyDraggingItem) return;
            const centeredX = event.clientX - this.ghostElement.offsetWidth / 2;
            const centeredY = event.clientY - this.ghostElement.offsetHeight / 2;
            this.ghostElement.style.left = `${centeredX}px`;
            this.ghostElement.style.top = `${centeredY}px`;
        },
        endDrag(event) {
            if (!this.currentlyDraggingItem) {
                return;
            }

            const elementsUnderCursor = document.elementsFromPoint(event.clientX, event.clientY);

            const playerSlotElement = elementsUnderCursor.find((el) => el.classList.contains("item-slot") && el.closest(".player-inventory-section"));

            const otherSlotElement = elementsUnderCursor.find((el) => el.classList.contains("item-slot") && el.closest(".other-inventory-section"));

            if (playerSlotElement) {
                const targetSlot = Number(playerSlotElement.dataset.slot);
                if (targetSlot && !(targetSlot === this.currentlyDraggingSlot && this.dragStartInventoryType === "player")) {
                    this.handleDropOnPlayerSlot(targetSlot);
                }
            } else if (otherSlotElement) {
                const targetSlot = Number(otherSlotElement.dataset.slot);
                if (targetSlot && !(targetSlot === this.currentlyDraggingSlot && this.dragStartInventoryType === "other")) {
                    this.handleDropOnOtherSlot(targetSlot);
                }
            } else if (this.isOtherInventoryEmpty && this.dragStartInventoryType === "player") {
                const isOverInventoryGrid = elementsUnderCursor.some((el) => el.classList.contains("inventory-grid") || el.classList.contains("item-grid"));

                if (!isOverInventoryGrid) {
                    this.handleDropOnInventoryContainer();
                }
            }

            this.clearDragData();
        },
        handleDropOnPlayerSlot(targetSlot) {
            if (this.isShopInventory && this.dragStartInventoryType === "other") {
                const { currentlyDraggingSlot, currentlyDraggingItem, transferAmount } = this;
                const targetInventory = this.getInventoryByType("player");
                const targetItem = targetInventory[targetSlot];
                if ((targetItem && targetItem.name !== currentlyDraggingItem.name) || (targetItem && targetItem.name === currentlyDraggingItem.name && currentlyDraggingItem.unique)) {
                    this.inventoryError(currentlyDraggingSlot);
                    return;
                }
                this.handlePurchase(targetSlot, currentlyDraggingSlot, currentlyDraggingItem, transferAmount);
            } else {
                this.handleItemDrop("player", targetSlot);
            }
        },
        handleDropOnOtherSlot(targetSlot) {
            this.handleItemDrop("other", targetSlot);
        },
        async handleDropOnInventoryContainer() {
            if (this.isOtherInventoryEmpty && this.dragStartInventoryType === "player") {
                const newItem = {
                    ...this.currentlyDraggingItem,
                    amount: this.currentlyDraggingItem.amount,
                    slot: 1,
                    inventory: "other",
                };
                const draggingItem = this.currentlyDraggingItem;
                try {
                    if (response.data) {
                        this.otherInventory[1] = newItem;
                        const draggingItemKey = Object.keys(this.playerInventory).find((key) => this.playerInventory[key] === draggingItem);
                        if (draggingItemKey) {
                            delete this.playerInventory[draggingItemKey];
                        }
                        this.otherInventoryName = response.data;
                        this.otherInventoryLabel = response.data;
                        this.isOtherInventoryEmpty = false;
                        this.clearDragData();
                    }
                } catch (error) {
                    this.inventoryError(this.currentlyDraggingSlot);
                }
            }
            
            this.clearDragData();
        },
        clearDragData() {
            if (this.ghostElement) {
                document.body.removeChild(this.ghostElement);
                this.ghostElement = null;
            }
            this.currentlyDraggingItem = null;
            this.currentlyDraggingSlot = null;
        },
        getInventoryByType(inventoryType) {
            return inventoryType === "player" ? this.playerInventory : this.otherInventory;
        },
        handleItemDrop(targetInventoryType, droppedOnSlotNumberParam) {
    try {
        const droppedOnSlotNumber = parseInt(droppedOnSlotNumberParam, 10);

        if (this.dragStartInventoryType === targetInventoryType && this.currentlyDraggingSlot === droppedOnSlotNumber) {
            console.log("[handleItemDrop] Item dropped onto its own slot. No action.");
            this.clearDragData();
            return;
        }

        const isShop = this.otherInventoryName.indexOf("shop-") !== -1;
        if (this.dragStartInventoryType === "other" && targetInventoryType === "other" && isShop) {
            this.clearDragData();
            return;
        }

        if (isNaN(droppedOnSlotNumber)) {
            throw new Error("Invalid target slot number from drop event");
        }

        const sourceItem = this.currentlyDraggingItem;
        if (!sourceItem) {
            throw new Error("No item currently being dragged.");
        }

        // Use full stack for drag-and-drop unless transferAmount is explicitly set for drag by other means
        const amountToTransfer = (this.transferAmount !== null && this.transferAmount > 0) ? this.transferAmount : sourceItem.amount;
        
        const sourceInventoryObject = this.getInventoryByType(this.dragStartInventoryType);
        const actualSourceItemFromOriginalSlot = sourceInventoryObject[this.currentlyDraggingSlot];

        if (!actualSourceItemFromOriginalSlot || actualSourceItemFromOriginalSlot.name !== sourceItem.name) {
            throw new Error("Source item in slot has changed or is missing during drag.");
        }
        // Ensure we don't try to transfer more than what's actually in the slot
        const finalAmountToTransfer = Math.min(amountToTransfer, actualSourceItemFromOriginalSlot.amount);

        if (finalAmountToTransfer <= 0) {
            throw new Error("Final amount to transfer is zero or less.");
        }

        const targetInventoryObject = this.getInventoryByType(targetInventoryType);
        const maxSlotsForTarget = targetInventoryType === 'player' ? this.totalSlots : this.otherInventorySlots;

        // --- Weight and Item-Specific Weight Checks ---
        let canProceedAfterWeightChecks = true;
        // V V V THIS IS THE CORRECTED CONDITION V V V
        if (this.dragStartInventoryType !== targetInventoryType) { 
            // ONLY perform weight checks if moving BETWEEN player and other inventory
            const itemWeight = sourceItem.weight || 0;
            const weightOfItemsToTransfer = itemWeight * finalAmountToTransfer; // Use finalAmountToTransfer

            if (targetInventoryType === "player") { // Moving TO Player (from Other)
                const currentTargetWeight = this.playerWeight || 0;
                const maxTargetWeightLimit = this.maxWeight || 0;
                if ((Number(currentTargetWeight) || 0) + weightOfItemsToTransfer > maxTargetWeightLimit) {
                    axios.post(`https://qb-inventory/notify`, { message: 'Your inventory is too full (weight).', type: 'error' });
                    canProceedAfterWeightChecks = false;
                }

                if (canProceedAfterWeightChecks) { // Only if overall weight passed
                    const itemNameToCheck = sourceItem.name.toLowerCase();
                    const specificLimit = this.itemSpecificMaxWeights && this.itemSpecificMaxWeights[itemNameToCheck];
                    if (typeof specificLimit === 'number') {
                        // For items coming from 'other', this.playerInventory is the correct context for current weight
                        const currentItemWeightInPlayerInv = this.getCurrentItemTypeWeight(this.playerInventory, sourceItem.name);
                        if ((currentItemWeightInPlayerInv + weightOfItemsToTransfer) > specificLimit) {
                            axios.post(`https://qb-inventory/notify`, { message: `You cannot carry any more ${sourceItem.label || sourceItem.name}.`, type: 'error' });
                            canProceedAfterWeightChecks = false;
                        }
                    }
                }
            } else if (targetInventoryType === "other") { // Moving TO Other (from Player)
                const currentTargetWeight = this.otherInventoryWeight || 0;
                const maxTargetWeightLimit = this.otherInventoryMaxWeight || 0;
                if ((Number(currentTargetWeight) || 0) + weightOfItemsToTransfer > maxTargetWeightLimit) {
                    axios.post(`https://qb-inventory/notify`, { message: 'Target inventory is too full (weight).', type: 'error' });
                    canProceedAfterWeightChecks = false;
                }
                // Item-specific limits usually don't apply when moving *to* 'other' general inventories client-side.
            }
        } // <<< END OF INTER-INVENTORY WEIGHT CHECKS

        if (!canProceedAfterWeightChecks) {
            throw new Error("Weight check failed.");
        }
        // --- End Weight Checks ---

        const itemAtDroppedOnSlot = targetInventoryObject[droppedOnSlotNumber];
        let finalTargetSlot = droppedOnSlotNumber; 
        let actionTaken = null;

        if (sourceItem.unique) {
            if (!itemAtDroppedOnSlot) { 
                actionTaken = 'place_unique_target_slot';
            } else { 
                if (this.dragStartInventoryType === targetInventoryType && this.currentlyDraggingSlot !== droppedOnSlotNumber) { 
                    actionTaken = 'swap_items';
                } else { 
                    finalTargetSlot = this.findNextAvailableSlot(targetInventoryObject, maxSlotsForTarget); // Corrected call
                    actionTaken = 'place_unique_next_slot';
                }
            }
        } else { // Stackable Item
            let existingCompatibleStackSlot = null;
            if (itemAtDroppedOnSlot && itemAtDroppedOnSlot.name === sourceItem.name && !itemAtDroppedOnSlot.unique && 
                !(this.dragStartInventoryType === targetInventoryType && droppedOnSlotNumber === this.currentlyDraggingSlot) ) {
                 existingCompatibleStackSlot = droppedOnSlotNumber;
            } else {
                for (const slotKey in targetInventoryObject) {
                    const tItem = targetInventoryObject[slotKey];
                    if (this.dragStartInventoryType === targetInventoryType && parseInt(slotKey, 10) === this.currentlyDraggingSlot) {
                        continue; 
                    }
                    if (tItem && tItem.name === sourceItem.name && !tItem.unique) {
                        existingCompatibleStackSlot = parseInt(tItem.slot, 10);
                        break;
                    }
                }
            }

            if (existingCompatibleStackSlot !== null) {
                finalTargetSlot = existingCompatibleStackSlot;
                actionTaken = 'stack_existing';
            } else { 
                if (!itemAtDroppedOnSlot) { 
                    finalTargetSlot = droppedOnSlotNumber;
                    actionTaken = 'place_new_stack_target_slot';
                } else { 
                    if (this.dragStartInventoryType === targetInventoryType && this.currentlyDraggingSlot !== droppedOnSlotNumber) { 
                        actionTaken = 'swap_items';
                    } else { 
                        finalTargetSlot = this.findNextAvailableSlot(targetInventoryObject, maxSlotsForTarget); // Corrected call
                        actionTaken = 'place_new_stack_next_slot';
                    }
                }
            }
        }

        if (finalTargetSlot === null && actionTaken !== 'swap_items' && actionTaken !== 'stack_existing') {
             axios.post(`https://qb-inventory/notify`, { message: 'No available slot in target inventory.', type: 'error' });
            throw new Error("No available slot for new item placement.");
        }
        
        // --- Perform the inventory update ---
        if (actionTaken === 'swap_items') {
            // This implies dragStartInventoryType === targetInventoryType, 
            // itemAtDroppedOnSlot exists, is different, and currentlyDraggingSlot !== droppedOnSlotNumber.
            console.log(`[handleItemDrop] SWAP: Item from slot ${this.currentlyDraggingSlot} with item from slot ${droppedOnSlotNumber}`);
            
            const itemBeingSwappedOut = { ...itemAtDroppedOnSlot }; 
            const draggedItemStack = { ...actualSourceItemFromOriginalSlot }; // Original state of dragged item for properties

            // Update target slot with (part of) dragged item
            targetInventoryObject[droppedOnSlotNumber] = { ...draggedItemStack, amount: finalAmountToTransfer, slot: droppedOnSlotNumber, inventory: targetInventoryType };
            
            // Update source slot with item that was in target slot
            sourceInventoryObject[this.currentlyDraggingSlot] = { ...itemBeingSwappedOut, slot: this.currentlyDraggingSlot, inventory: this.dragStartInventoryType };

            // If only a partial stack was "swapped" from source, the remainder is now gone from the source slot
            if (finalAmountToTransfer < actualSourceItemFromOriginalSlot.amount) {
                console.warn("Swap initiated with partial stack drag. The remainder of the source stack is overwritten in this simple swap model.");
                // To handle this better, the source stack would need to be split, one part swapped, one part remaining.
                // For now, this logic means the entire original slot's content is replaced by the swapped item.
            }

            this.postInventoryData(
                this.dragStartInventoryType, targetInventoryType,
                this.currentlyDraggingSlot,  
                droppedOnSlotNumber,         
                itemBeingSwappedOut.amount, 
                finalAmountToTransfer        
            );
        } else if (actionTaken === 'stack_existing') {
            targetInventoryObject[finalTargetSlot].amount += finalAmountToTransfer;
            actualSourceItemFromOriginalSlot.amount -= finalAmountToTransfer;
            if (actualSourceItemFromOriginalSlot.amount <= 0) {
                delete sourceInventoryObject[this.currentlyDraggingSlot];
            }
            this.postInventoryData(this.dragStartInventoryType, targetInventoryType, this.currentlyDraggingSlot, finalTargetSlot, actualSourceItemFromOriginalSlot.amount, finalAmountToTransfer);
        } else { 
            // Handles place_unique_target_slot, place_unique_next_slot, 
            // place_new_stack_target_slot, place_new_stack_next_slot
            if(finalTargetSlot === null) { 
                throw new Error("Final target slot is null for placement action.");
            }
            targetInventoryObject[finalTargetSlot] = { 
                ...actualSourceItemFromOriginalSlot, 
                amount: finalAmountToTransfer, 
                slot: finalTargetSlot, 
                inventory: targetInventoryType 
            };
            actualSourceItemFromOriginalSlot.amount -= finalAmountToTransfer;
            if (actualSourceItemFromOriginalSlot.amount <= 0) {
                delete sourceInventoryObject[this.currentlyDraggingSlot];
            }
            this.postInventoryData(this.dragStartInventoryType, targetInventoryType, this.currentlyDraggingSlot, finalTargetSlot, actualSourceItemFromOriginalSlot.amount, finalAmountToTransfer);
        }
    } catch (error) {
        console.error("[handleItemDrop] Error:", error.message);
        this.inventoryError(this.currentlyDraggingSlot || 'drag-error');
    } finally {
        this.clearDragData();
    }
},
        async handlePurchase(targetSlot, sourceSlot, sourceItem, transferAmount) {
            try {
                const response = await axios.post("https://qb-inventory/AttemptPurchase", {
                    item: sourceItem,
                    amount: transferAmount || sourceItem.amount,
                    shop: this.otherInventoryName,
                });
                if (response.data) {
                    const sourceInventory = this.getInventoryByType("other");
                    const targetInventory = this.getInventoryByType("player");
                    const amountToTransfer = transferAmount !== null ? transferAmount : sourceItem.amount;
                    if (sourceItem.amount < amountToTransfer) {
                        this.inventoryError(sourceSlot);
                        return;
                    }
                    let targetItem = targetInventory[targetSlot];
                    if (!targetItem || targetItem.name !== sourceItem.name) {
                        let foundSlot = Object.keys(targetInventory).find((slot) => targetInventory[slot] && targetInventory[slot].name === sourceItem.name);
                        if (foundSlot) {
                            targetInventory[foundSlot].amount += amountToTransfer;
                        } else {
                            const targetInventoryKeys = Object.keys(targetInventory);
                            if (targetInventoryKeys.length < this.totalSlots) {
                                let freeSlot = Array.from({ length: this.totalSlots }, (_, i) => i + 1).find((i) => !(i in targetInventory));
                                targetInventory[freeSlot] = {
                                    ...sourceItem,
                                    amount: amountToTransfer,
                                };
                            } else {
                                this.inventoryError(sourceSlot);
                                return;
                            }
                        }
                    } else {
                        targetItem.amount += amountToTransfer;
                    }
                    sourceItem.amount -= amountToTransfer;
                    if (sourceItem.amount <= 0) {
                        delete sourceInventory[sourceSlot];
                    }
                } else {
                    this.inventoryError(sourceSlot);
                }
            } catch (error) {
                this.inventoryError(sourceSlot);
            }
        },
        async useItem(item) {
            if (!item || item.useable === false) {
                return;
            }
            const playerItemKey = Object.keys(this.playerInventory).find((key) => this.playerInventory[key] && this.playerInventory[key].slot === item.slot);
            if (playerItemKey) {
                try {
                    await axios.post("https://qb-inventory/UseItem", {
                        inventory: "player",
                        item: item,
                    });
                    if (item.shouldClose) {
                        this.closeInventory();
                    }
                } catch (error) {
                    console.error("Error using the item: ", error);
                }
            }
            this.showContextMenu = false;
        },
        showContextMenuOptions(event, item) {
            event.preventDefault();

            // If clicking the same item that already has the context menu open, toggle it off.
            if (this.showContextMenu && this.contextMenuItem && this.contextMenuItem.slot === item.slot && this.contextMenuItem.inventory === item.inventory) {
                this.showContextMenu = false;
                this.contextMenuItem = null;
                return; // Exit early
            }

            // --- REMOVE THE ENTIRE BLOCK THAT DID THE VISUAL TRANSFER ---
            // The old problematic block starting with "if (item.inventory === 'other')" should be deleted.
            // ---

            // Set position and item for the context menu
            const menuLeft = event.clientX;
            const menuTop = event.clientY;

            this.contextMenuPosition = {
                top: `${menuTop}px`,
                left: `${menuLeft}px`,
            };
            this.contextMenuItem = item; // Set the item that was right-clicked
            this.showContextMenu = true;   // Show the menu
            this.showSubmenu = false;      // Ensure submenu is reset if you have one
        },
        async giveItem(item, quantity) {
            if (item && item.name) {
                const selectedItem = item;
                const playerHasItem = Object.values(this.playerInventory).some((invItem) => invItem && invItem.name === selectedItem.name);

                if (playerHasItem) {
                    let amountToGive;
                    if (typeof quantity === "string") {
                        switch (quantity) {
                            case "half":
                                amountToGive = Math.ceil(selectedItem.amount / 2);
                                break;
                            case "all":
                                amountToGive = selectedItem.amount;
                                break;
                            default:
                                console.error("Invalid quantity specified.");
                                return;
                        }
                    } else {
                        amountToGive = quantity;
                    }

                    if (amountToGive > selectedItem.amount) {
                        console.error("Specified quantity exceeds available amount.");
                        return;
                    }

                    try {
                        const response = await axios.post("https://qb-inventory/GiveItem", {
                            item: selectedItem,
                            amount: amountToGive,
                            slot: selectedItem.slot,
                            info: selectedItem.info,
                        });
                        if (!response.data) return;

                        this.playerInventory[selectedItem.slot].amount -= amountToGive;
                        if (this.playerInventory[selectedItem.slot].amount === 0) {
                            delete this.playerInventory[selectedItem.slot];
                        }
                    } catch (error) {
                        console.error("An error occurred while giving the item:", error);
                    }
                } else {
                    console.error("Player does not have the item in their inventory. Item cannot be given.");
                }
            }
            this.showContextMenu = false;
        },
        findNextAvailableSlot(inventory, maxSlots) {
            if (!inventory || typeof maxSlots !== 'number' || maxSlots <= 0) {
                return null;
            }
            for (let slot = 1; slot <= maxSlots; slot++) {
                if (!inventory[slot]) {
                    return slot;
                }
            }
            return null;
        },
        splitAndPlaceItem(item, inventoryType) {
            const inventoryRef = inventoryType === "player" ? this.playerInventory : this.otherInventory;
            if (item && item.amount > 1) {
                const originalSlot = Object.keys(inventoryRef).find((key) => inventoryRef[key] === item);
                if (originalSlot !== undefined) {
                    const newItem = { ...item, amount: Math.ceil(item.amount / 2) };
                    const nextSlot = this.findNextAvailableSlot(inventoryRef);
                    if (nextSlot !== null) {
                        inventoryRef[nextSlot] = newItem;
                        inventoryRef[originalSlot] = { ...item, amount: Math.floor(item.amount / 2) };
                        this.postInventoryData(inventoryType, inventoryType, originalSlot, nextSlot, item.amount, newItem.amount);
                    }
                }
            }
            this.showContextMenu = false;
        },
        toggleHotbar(data) {
            if (data.open) {
                this.hotbarItems = data.items;
                this.showHotbar = true;
            } else {
                this.showHotbar = false;
                this.hotbarItems = [];
            }
        },
        showItemNotification(itemData) {
            this.notificationText = itemData.item.label;
            this.notificationImage = "images/" + itemData.item.image;
            this.notificationType = itemData.type === "add" ? "Received" : itemData.type === "use" ? "Used" : "Removed";
            this.notificationAmount = itemData.amount || 1;
            this.showNotification = true;
            setTimeout(() => {
                this.showNotification = false;
            }, 3000);
        },
        showRequiredItem(data) {
            if (data.toggle) {
                this.requiredItems = data.items;
                this.showRequiredItems = true;
            } else {
                setTimeout(() => {
                    this.showRequiredItems = false;
                    this.requiredItems = [];
                }, 100);
            }
        },
        inventoryError(slot) {
            const slotElement = document.getElementById(`slot-${slot}`);
            if (slotElement) {
                slotElement.style.backgroundColor = "red";
            }
            axios.post("https://qb-inventory/PlayDropFail", {}).catch((error) => {
                console.error("Error playing drop fail:", error);
            });
            setTimeout(() => {
                if (slotElement) {
                    slotElement.style.backgroundColor = "";
                }
            }, 1000);
        },
        copySerial() {
            if (!this.contextMenuItem) {
                return;
            }
            const item = this.contextMenuItem;
            if (item) {
                const el = document.createElement("textarea");
                el.value = item.info.serie;
                document.body.appendChild(el);
                el.select();
                document.execCommand("copy");
                document.body.removeChild(el);
            }
        },
        openWeaponAttachments() {
            if (!this.contextMenuItem) {
                return;
            }
            if (!this.showWeaponAttachments) {
                this.selectedWeapon = this.contextMenuItem;
                this.showWeaponAttachments = true;
                axios
                    .post("https://qb-inventory/GetWeaponData", JSON.stringify({ weapon: this.selectedWeapon.name, ItemData: this.selectedWeapon }))
                    .then((response) => {
                        const data = response.data;
                        if (data.AttachmentData !== null && data.AttachmentData !== undefined) {
                            if (data.AttachmentData.length > 0) {
                                this.selectedWeaponAttachments = data.AttachmentData;
                            }
                        }
                    })
                    .catch((error) => {
                        console.error(error);
                    });
            } else {
                this.showWeaponAttachments = false;
                this.selectedWeapon = null;
                this.selectedWeaponAttachments = [];
            }
        },
        removeAttachment(attachment) {
            if (!this.selectedWeapon) {
                return;
            }
            const index = this.selectedWeaponAttachments.indexOf(attachment);
            if (index !== -1) {
                this.selectedWeaponAttachments.splice(index, 1);
            }
            axios
                .post("https://qb-inventory/RemoveAttachment", JSON.stringify({ AttachmentData: attachment, WeaponData: this.selectedWeapon }))
                .then((response) => {
                    this.selectedWeapon = response.data.WeaponData;
                    if (response.data.Attachments) {
                        this.selectedWeaponAttachments = response.data.Attachments;
                    }
                    const nextSlot = this.findNextAvailableSlot(this.playerInventory);
                    if (nextSlot !== null) {
                        response.data.itemInfo.amount = 1;
                        this.playerInventory[nextSlot] = response.data.itemInfo;
                    }
                })
                .catch((error) => {
                    console.error(error);
                    this.selectedWeaponAttachments.splice(index, 0, attachment);
                });
        },
        generateTooltipContent(item) {
            if (!item) {
                return "";
            }
            let content = `<div class="custom-tooltip"><div class="tooltip-header">${item.label}</div><hr class="tooltip-divider">`;
            const description = item.info && item.info.description ? item.info.description.replace(/\n/g, "<br>") : item.description ? item.description.replace(/\n/g, "<br>") : "No description available.";
            if (item.info && Object.keys(item.info).length > 0 && item.info.display !== false) {
                for (const [key, value] of Object.entries(item.info)) {
                    if (key !== "description" && key !== "display") {
                        let valueStr = value;
                        if (key === "attachments") {
                            valueStr = Object.keys(value).length > 0 ? "true" : "false";
                        }
                        content += `<div class="tooltip-info"><span class="tooltip-info-key">${this.formatKey(key)}:</span> ${valueStr}</div>`;
                    }
                }
            }
            content += `<div class="tooltip-description">${description}</div>`;
            content += `<div class="tooltip-weight"><i class="fas fa-weight-hanging"></i> ${item.weight !== undefined && item.weight !== null ? (item.weight / 1000).toFixed(1) : "N/A"}kg</div>`;
            content += `</div>`;
            return content;
        },
        formatKey(key) {
            return key.replace(/_/g, " ").charAt(0).toUpperCase() + key.slice(1);
        },
        postInventoryData(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount) {
            let fromInventoryName = fromInventory === "other" ? this.otherInventoryName : fromInventory;
            let toInventoryName = toInventory === "other" ? this.otherInventoryName : toInventory;

            axios
                .post("https://qb-inventory/SetInventoryData", {
                    fromInventory: fromInventoryName,
                    toInventory: toInventoryName,
                    fromSlot,
                    toSlot,
                    fromAmount,
                    toAmount,
                })
                .then((response) => {
                    this.clearDragData();
                })
                .catch((error) => {
                    console.error("Error posting inventory data:", error);
                });
        },
    },
    mounted() {
        window.addEventListener("keydown", (event) => {
            const key = event.key;
            if (key === "Escape" || key === "Tab") {
                if (this.isInventoryOpen) {
                    this.closeInventory();
                }
            }
        });

        window.addEventListener("message", (event) => {
            // console.log("[NUI Message Received from LUA]:", JSON.stringify(event.data, null, 2));
            switch (event.data.action) {
                case "open":
                    this.openInventory(event.data);
                    break;
                case "close":
                    this.closeInventory();
                    break;
                case "update":
                    this.updateInventory(event.data);
                    break;
                case "toggleHotbar":
                    this.toggleHotbar(event.data);
                    break;
                case "itemBox":
                    this.showItemNotification(event.data);
                    break;
                case "requiredItem":
                    this.showRequiredItem(event.data);
                    break;
                default:
                    console.warn(`Unexpected action: ${event.data.action}`);
            }
        });
    },
    beforeUnmount() {
        window.removeEventListener("mousemove", () => {});
        window.removeEventListener("keydown", () => {});
        window.removeEventListener("message", () => {});
    },
});

InventoryContainer.use(FloatingVue);
InventoryContainer.mount("#app");
