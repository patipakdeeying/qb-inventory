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
            console.log("app.js: openInventory() called with data:", data);
            if (this.showHotbar) {
                // Assuming toggleHotbar expects an object like { open: false, items: [] }
                // Adjust if your toggleHotbar definition is different.
                this.toggleHotbar({ open: false, items: [] });
            }

            this.isInventoryOpen = true;
            this.maxWeight = data.maxweight; // Player's max weight
            this.itemSpecificMaxWeights = data.itemSpecificMaxWeights || {};
            this.totalSlots = data.slots;   // Player's total slots
            
            this.playerInventory = {};
            this.otherInventory = {};
            // Default other inventory states
            this.otherInventoryName = "";
            this.otherInventoryLabel = "Drop"; // Default label if none provided
            this.otherInventoryMaxWeight = 0; // Default if none provided
            this.otherInventorySlots = 0;     // Default if none provided
            this.isShopInventory = false;
            this.isOtherInventoryEmpty = true; // Assume other inventory is empty initially

            // Process player inventory
            if (data.inventory) {
                const processPlayerItem = (item) => {
                    if (item && typeof item.slot !== 'undefined') { // Check for slot existence
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

            // Process other inventory
            if (data.other && typeof data.other === 'object' && data.other !== null) {
                this.otherInventoryName = data.other.name || "";
                this.otherInventoryLabel = data.other.label || "Drop";
                this.otherInventoryMaxWeight = data.other.maxweight || 0;
                this.otherInventorySlots = data.other.slots || 0;
                this.isShopInventory = this.otherInventoryName.startsWith("shop-");

                if (data.other.inventory && (Array.isArray(data.other.inventory) || typeof data.other.inventory === "object" && data.other.inventory !== null)) {
                    let itemCountInOther = 0;
                    const processOtherItem = (item) => {
                        if (item && typeof item.slot !== 'undefined') {
                            this.otherInventory[item.slot] = { ...item, inventory: 'other' }; // Add 'inventory' property
                            itemCountInOther++;
                        }
                    };

                    if (Array.isArray(data.other.inventory)) {
                        data.other.inventory.forEach(processOtherItem);
                    } else { // Is an object
                        for (const key in data.other.inventory) {
                            processOtherItem(data.other.inventory[key]);
                        }
                    }
                    this.isOtherInventoryEmpty = itemCountInOther === 0;
                } else {
                    // data.other exists but data.other.inventory is empty or not provided
                    this.isOtherInventoryEmpty = true;
                }
            } else {
                // No data.other object at all
                this.isOtherInventoryEmpty = true;
            }
            
            console.log("app.js: isInventoryOpen set to true");
            // For debugging, you can log the inventories to check:
            // console.log("Player Inv (with .inventory):", JSON.parse(JSON.stringify(this.playerInventory)));
            // console.log("Other Inv (with .inventory):", JSON.parse(JSON.stringify(this.otherInventory)));
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
            console.log("[moveItemBetweenInventories] Attempting to move:", item, "From:", sourceInventoryType, "Qty:", quantityToTransfer); // Debug line

            const sourceInventory = sourceInventoryType === "player" ? this.playerInventory : this.otherInventory;
            const targetInventory = sourceInventoryType === "player" ? this.otherInventory : this.playerInventory;
            const currentTargetWeight = sourceInventoryType === "player" ? this.otherInventoryWeight : this.playerWeight; // This is the current weight of the whole target inventory
            const maxTargetWeight = sourceInventoryType === "player" ? this.otherInventoryMaxWeight : this.maxWeight;
            const amountToTransfer = quantityToTransfer;

            const sourceItem = sourceInventory[item.slot];

            if (!sourceItem || sourceItem.amount < amountToTransfer) {
                this.inventoryError(item.slot);
                console.error("[moveItemBetweenInventories] Error: Not enough items in source slot or sourceItem not found.");
                return;
            }

            const weightOfItemsToTransfer = sourceItem.weight * amountToTransfer;

            // 1. Overall Max Weight Check for the target inventory (already exists)
            if ((Number(currentTargetWeight) || 0) + weightOfItemsToTransfer > maxTargetWeight) {
                this.inventoryError(item.slot);
                console.error("[moveItemBetweenInventories] Error: Overall max weight exceeded for target inventory.");
                // Consider sending a NUI notification here for overall weight
                axios.post(`https://qb-inventory/notify`, { message: 'Target inventory is too full (weight).', type: 'error' });

                return;
            }

            // 2. Item-Specific Max Weight Check (NEW)
            // This check applies ONLY if items are being moved TO the PLAYER'S inventory.
            if (sourceInventoryType === 'other') { // Which means targetInventory is this.playerInventory
                const itemNameToCheck = sourceItem.name.toLowerCase();
                const specificLimit = this.itemSpecificMaxWeights && this.itemSpecificMaxWeights[itemNameToCheck];

                if (typeof specificLimit === 'number') { // Check if a specific limit exists for this item
                    const currentItemWeightInPlayerInv = this.getCurrentItemTypeWeight(this.playerInventory, sourceItem.name);
                    const additionalWeightOfThisType = sourceItem.weight * amountToTransfer;

                    console.log(`[moveItemBetweenInventories] Item-specific check for ${itemNameToCheck}: CurrentInPlayer=${currentItemWeightInPlayerInv}, Adding=${additionalWeightOfThisType}, Limit=${specificLimit}`);

                    if (currentItemWeightInPlayerInv + additionalWeightOfThisType > specificLimit) {
                        console.error(`[moveItemBetweenInventories] Error: Item-specific weight limit for ${itemNameToCheck} exceeded.`);
                        this.inventoryError(item.slot); // Highlight the source slot for now
                        
                        // Send a more specific notification
                        // You might need to ensure your NUI can receive and display these, or adapt.
                        // This uses a generic qbcore notify event, if your inventory uses a different system, adjust.
                        axios.post(`https://qb-inventory/notify`, { message: `You cannot carry any more ${sourceItem.label || sourceItem.name}.`, type: 'error' });
                        
                        return; // Prevent the move
                    }
                }
            }

            // If all checks pass, proceed with the move logic (your existing logic)
            let targetSlot = null;
            if (item.unique) {
                // ... (your existing unique item logic)
                targetSlot = this.findNextAvailableSlot(targetInventory);
                if (targetSlot === null) {
                    this.inventoryError(item.slot);
                    axios.post(`https://qb-inventory/notify`, { message: 'No slot available in target inventory.', type: 'error' });
                    return;
                }
                const newItem = {
                    ...sourceItem, // Use sourceItem to get full details
                    inventory: sourceInventoryType === "player" ? "other" : "player",
                    amount: amountToTransfer,
                    slot: targetSlot,
                };
                targetInventory[targetSlot] = newItem;
            } else {
                // ... (your existing stackable item logic)
                const targetItemKey = Object.keys(targetInventory).find((key) => targetInventory[key] && targetInventory[key].name === sourceItem.name && !targetInventory[key].unique);
                const targetItem = targetInventory[targetItemKey];

                if (!targetItem) { // No existing stack, find new slot
                    targetSlot = this.findNextAvailableSlot(targetInventory);
                    if (targetSlot === null) {
                        this.inventoryError(item.slot);
                        axios.post(`https://qb-inventory/notify`, { message: 'No slot available for new stack.', type: 'error' });
                        return;
                    }
                    const newItem = {
                        ...sourceItem,
                        inventory: sourceInventoryType === "player" ? "other" : "player",
                        amount: amountToTransfer,
                        slot: targetSlot,
                    };
                    targetInventory[targetSlot] = newItem;
                } else { // Stack with existing item
                    targetItem.amount += amountToTransfer;
                    targetSlot = targetItem.slot;
                }
            }

            sourceItem.amount -= amountToTransfer;
            if (sourceItem.amount <= 0) {
                delete sourceInventory[item.slot];
            }

            this.postInventoryData(sourceInventoryType, (sourceInventoryType === "player" ? "other" : "player"), item.slot, targetSlot, sourceItem.amount, amountToTransfer);
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
                const isShop = this.otherInventoryName.indexOf("shop-") !== -1;
                if (this.dragStartInventoryType === "other" && targetInventoryType === "other" && isShop) {
                    this.clearDragData();
                    return;
                }

                const droppedOnSlotNumber = parseInt(droppedOnSlotNumberParam, 10);
                if (isNaN(droppedOnSlotNumber)) {
                    throw new Error("Invalid target slot number from drop event");
                }

                const sourceItem = this.currentlyDraggingItem; // The item being dragged
                if (!sourceItem) {
                    throw new Error("No item currently being dragged.");
                }

                let amountToTransfer = (this.transferAmount !== null && this.transferAmount > 0) ? this.transferAmount : sourceItem.amount;
                const sourceInventoryObject = this.getInventoryByType(this.dragStartInventoryType);
                const actualSourceItemFromOriginalSlot = sourceInventoryObject[this.currentlyDraggingSlot];

                if (!actualSourceItemFromOriginalSlot || actualSourceItemFromOriginalSlot.name !== sourceItem.name) {
                    throw new Error("Source item in slot has changed or is missing.");
                }
                amountToTransfer = Math.min(amountToTransfer, actualSourceItemFromOriginalSlot.amount);
                if (amountToTransfer <= 0) {
                    throw new Error("Final amount to transfer is zero or less.");
                }

                const targetInventoryObject = this.getInventoryByType(targetInventoryType);
                const maxSlotsForTarget = targetInventoryType === 'player' ? this.totalSlots : this.otherInventorySlots;

                // --- Weight and Item-Specific Weight Checks ---
                const itemWeight = sourceItem.weight || 0;
                const weightOfItemsToTransfer = itemWeight * amountToTransfer;

                // Check only if moving to a different main inventory OR if it's an intra-inventory move
                // (The check `targetInventoryType !== this.dragStartInventoryType` handles inter-inventory. For intra, weight doesn't change overall for the inv.)
                // However, specific item weight limits for player inventory always apply if target is player.
                if (targetInventoryType === "player") { // Target is Player
                    if (this.dragStartInventoryType !== "player") { // Coming from Other to Player
                        const currentTargetWeight = this.playerWeight || 0;
                        const maxTargetWeight = this.maxWeight || 0;
                        if ((Number(currentTargetWeight) || 0) + weightOfItemsToTransfer > maxTargetWeight) {
                            axios.post(`https://qb-inventory/notify`, { message: 'Your inventory is too full (weight).', type: 'error' });
                            throw new Error("Insufficient overall weight capacity in player inventory.");
                        }
                    }
                    // Item-Specific Max Weight Check for Player Inventory (always if target is player)
                    const itemNameToCheck = sourceItem.name.toLowerCase();
                    const specificLimit = this.itemSpecificMaxWeights && this.itemSpecificMaxWeights[itemNameToCheck];
                    if (typeof specificLimit === 'number') {
                        const currentItemWeightInPlayerInv = this.getCurrentItemTypeWeight(this.playerInventory, sourceItem.name);
                        if ((currentItemWeightInPlayerInv + weightOfItemsToTransfer) > specificLimit) {
                            axios.post(`https://qb-inventory/notify`, { message: `You cannot carry any more ${sourceItem.label || sourceItem.name}.`, type: 'error' });
                            throw new Error(`Item-specific weight limit for ${itemNameToCheck} exceeded.`);
                        }
                    }
                } else if (targetInventoryType === "other" && this.dragStartInventoryType !== "other") { // Target is Other, Source is Player
                    const currentTargetWeight = this.otherInventoryWeight || 0;
                    const maxTargetWeight = this.otherInventoryMaxWeight || 0;
                    if ((Number(currentTargetWeight) || 0) + weightOfItemsToTransfer > maxTargetWeight) {
                        axios.post(`https://qb-inventory/notify`, { message: 'Target inventory is too full (weight).', type: 'error' });
                        throw new Error("Insufficient overall weight capacity in other inventory.");
                    }
                }
                // --- End Weight Checks ---

                let finalTargetSlot = null;
                let actionTaken = null; 
                const itemAtDroppedOnSlot = targetInventoryObject[droppedOnSlotNumber];

                if (sourceItem.unique) {
                    if (!itemAtDroppedOnSlot) { // Dropped on an empty slot
                        finalTargetSlot = droppedOnSlotNumber;
                        actionTaken = 'place_unique_target_slot';
                    } else { // Dropped on an occupied slot
                        if (this.dragStartInventoryType === targetInventoryType) { // Intra-inventory move
                            finalTargetSlot = droppedOnSlotNumber; // Prepare for potential swap
                            actionTaken = 'swap_items'; // Will swap unique with whatever is there
                        } else { // Inter-inventory move, find next available for unique
                            finalTargetSlot = this.findNextAvailableSlot(targetInventoryObject, maxSlotsForTarget);
                            actionTaken = 'place_unique_next_slot';
                        }
                    }
                } else { // Item is Stackable
                    let existingCompatibleStackSlot = null;
                    for (const slotKey in targetInventoryObject) {
                        const tItem = targetInventoryObject[slotKey];
                        if (tItem && tItem.name === sourceItem.name && !tItem.unique) {
                            existingCompatibleStackSlot = parseInt(tItem.slot, 10);
                            break;
                        }
                    }

                    if (existingCompatibleStackSlot !== null) { // Compatible stack exists
                        finalTargetSlot = existingCompatibleStackSlot;
                        actionTaken = 'stack_existing';
                    } else { // No compatible stack exists, so it's a new stack
                        if (!itemAtDroppedOnSlot) { // Dropped on an empty slot
                            finalTargetSlot = droppedOnSlotNumber;
                            actionTaken = 'place_new_stack_target_slot';
                        } else { // Dropped on an occupied slot (by a different item)
                            if (this.dragStartInventoryType === targetInventoryType) { // Intra-inventory move
                                finalTargetSlot = droppedOnSlotNumber; // Prepare for swap
                                actionTaken = 'swap_items';
                            } else { // Inter-inventory move, find next available for new stack
                                finalTargetSlot = this.findNextAvailableSlot(targetInventoryObject, maxSlotsForTarget);
                                actionTaken = 'place_new_stack_next_slot';
                            }
                        }
                    }
                }

                if (finalTargetSlot === null && actionTaken !== 'swap_items') { // If swap is the action, finalTargetSlot is the droppedOnSlotNumber
                    axios.post(`https://qb-inventory/notify`, { message: 'No available slot in target inventory.', type: 'error' });
                    throw new Error("No available slot in target inventory.");
                }
                
                // --- Perform the inventory update ---
                if (actionTaken === 'swap_items') {
                    if (this.dragStartInventoryType !== targetInventoryType || !itemAtDroppedOnSlot || this.currentlyDraggingSlot === droppedOnSlotNumber) {
                        // Swap only makes sense for intra-inventory different slots, and target must have an item.
                        // If conditions for swap not met, try to place in next available (or error if full)
                        finalTargetSlot = this.findNextAvailableSlot(targetInventoryObject, maxSlotsForTarget);
                        if (finalTargetSlot === null) {
                            axios.post(`https://qb-inventory/notify`, { message: 'Cannot swap, and no empty slot found.', type: 'error' });
                            throw new Error("Cannot swap, and no empty slot available.");
                        }
                        // Re-evaluate action based on finding an empty slot
                        actionTaken = sourceItem.unique ? 'place_unique_next_slot' : 'place_new_stack_next_slot';
                        // Fall through to the 'else' block below for placement
                    } else {
                        // Perform the swap
                        const itemBeingSwappedOut = { ...itemAtDroppedOnSlot }; // Copy of item B

                        // Place dragged item (item A) into the droppedOnSlotNumber
                        targetInventoryObject[droppedOnSlotNumber] = { ...actualSourceItemFromOriginalSlot, amount: amountToTransfer, slot: droppedOnSlotNumber, inventory: targetInventoryType };
                        
                        // Place the item that was in droppedOnSlotNumber (item B) into the original dragging slot
                        sourceInventoryObject[this.currentlyDraggingSlot] = { ...itemBeingSwappedOut, slot: this.currentlyDraggingSlot, inventory: this.dragStartInventoryType };

                        // If only a partial stack was "swapped" from source, the remainder is now gone from the source slot, replaced by item B.
                        // This logic assumes 'amountToTransfer' is the entirety of 'actualSourceItemFromOriginalSlot' for a clean swap.
                        // If amountToTransfer < actualSourceItemFromOriginalSlot.amount, then actualSourceItemFromOriginalSlot.amount -= amountToTransfer;
                        // and the remainder needs to be handled or is lost from its original slot in this simple swap.
                        // For simplicity with current structure, let's assume full amount of source is part of swap.
                        if (amountToTransfer < actualSourceItemFromOriginalSlot.amount) {
                            // This scenario is tricky: if you drag a partial stack to swap, what happens to the rest of the source stack?
                            // Current logic: the source slot is entirely replaced by the swapped item.
                            // To handle partial stack swaps correctly, the sourceItem would need to be split first.
                            // Let's assume for now drag-and-drop swap moves the entire source stack part of the swap.
                            console.warn("Partial stack swap attempted, full source stack involved in swap for simplicity.");
                        }


                        this.postInventoryData(
                            this.dragStartInventoryType,
                            targetInventoryType,
                            this.currentlyDraggingSlot,
                            droppedOnSlotNumber,
                            itemBeingSwappedOut.amount, // Amount of item B (now in original slot of A)
                            amountToTransfer            // Amount of item A (now in original slot of B)
                        );
                        this.clearDragData(); // Swapping is a final action.
                        return; // Exit after swap
                    }
                }


                // Handles stacking or placing in a new/empty slot
                if (actionTaken === 'stack_existing') {
                    targetInventoryObject[finalTargetSlot].amount += amountToTransfer;
                } else { // Handles place_unique_*, place_new_stack_*
                    targetInventoryObject[finalTargetSlot] = { 
                        ...actualSourceItemFromOriginalSlot, // Use the state from original slot
                        amount: amountToTransfer, 
                        slot: finalTargetSlot, 
                        inventory: targetInventoryType 
                    };
                }

                // Update source inventory
                actualSourceItemFromOriginalSlot.amount -= amountToTransfer;
                if (actualSourceItemFromOriginalSlot.amount <= 0) {
                    delete sourceInventoryObject[this.currentlyDraggingSlot];
                }

                this.postInventoryData(
                    this.dragStartInventoryType,
                    targetInventoryType,
                    this.currentlyDraggingSlot,
                    finalTargetSlot,
                    actualSourceItemFromOriginalSlot.amount, // New amount in source slot (can be 0)
                    amountToTransfer // Amount moved to target/added to stack
                );

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
        findNextAvailableSlot(inventory, maxSlots) { // Added maxSlots parameter
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
            console.log("[NUI Message Received from LUA]:", JSON.stringify(event.data, null, 2));
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
