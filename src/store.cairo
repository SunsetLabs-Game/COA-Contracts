use starknet::ContractAddress;
use dojo::model::ModelStorage;
use dojo::event::EventStorage;
use core::num::traits::Zero;

// ============================================================================
// STORE MODELS - Arquitectura ECS Modular
// ============================================================================

/// Configuración global del store con IDs constantes
#[dojo::model]
#[derive(Drop, Serde, Copy)]
pub struct StoreConfig {
    #[key]
    pub store_id: u32,
    pub name: felt252,
    pub owner: ContractAddress,
    pub is_active: bool,
    pub tax_rate: u16, // Porcentaje de impuesto (base 10000)
    pub max_items: u32,
    pub created_at: u64,
}

/// Items disponibles en el store
#[dojo::model]
#[derive(Drop, Serde, Copy)]
pub struct StoreItem {
    #[key]
    pub store_id: u32,
    #[key]
    pub item_id: u256,
    pub price: u256,
    pub stock: u32,
    pub max_stock: u32,
    pub is_available: bool,
    pub category: felt252,
    pub rarity: u8, // 1=Common, 2=Rare, 3=Epic, 4=Legendary
}

/// Inventario del store - separado para eficiencia
#[dojo::model]
#[derive(Drop, Serde, Copy)]
pub struct StoreInventory {
    #[key]
    pub store_id: u32,
    #[key]
    pub slot: u32,
    pub item_id: u256,
    pub reserved: u32, // Items reservados en transacciones pendientes
    pub last_restock: u64,
}

/// Transacciones del store para tracking
#[dojo::model]
#[derive(Drop, Serde, Copy)]
pub struct StoreTransaction {
    #[key]
    pub transaction_id: u256,
    pub store_id: u32,
    pub buyer: ContractAddress,
    pub item_id: u256,
    pub quantity: u32,
    pub total_price: u256,
    pub timestamp: u64,
    pub status: u8, // 0=Pending, 1=Completed, 2=Failed, 3=Refunded
}

/// Permisos del store
#[dojo::model]
#[derive(Drop, Serde, Copy)]
pub struct StorePermissions {
    #[key]
    pub store_id: u32,
    #[key]
    pub user: ContractAddress,
    pub role: u8, // 0=None, 1=Viewer, 2=Manager, 3=Admin, 4=Owner
    pub granted_by: ContractAddress,
    pub granted_at: u64,
}

// ============================================================================
// STORE EVENTS - Sistema de eventos para cambios importantes
// ============================================================================

#[derive(Drop, Serde)]
#[dojo::event]
pub struct StoreCreated {
    #[key]
    pub store_id: u32,
    pub owner: ContractAddress,
    pub name: felt252,
    pub timestamp: u64,
}

#[derive(Drop, Serde)]
#[dojo::event]
pub struct ItemPurchased {
    #[key]
    pub store_id: u32,
    #[key]
    pub buyer: ContractAddress,
    pub item_id: u256,
    pub quantity: u32,
    pub total_price: u256,
    pub timestamp: u64,
}

#[derive(Drop, Serde)]
#[dojo::event]
pub struct StoreRestocked {
    #[key]
    pub store_id: u32,
    pub item_id: u256,
    pub old_stock: u32,
    pub new_stock: u32,
    pub timestamp: u64,
}

#[derive(Drop, Serde)]
#[dojo::event]
pub struct StoreClosed {
    #[key]
    pub store_id: u32,
    pub reason: felt252,
    pub timestamp: u64,
}

// ============================================================================
// STORE TRAIT - Operaciones CRUD y lógica de negocio
// ============================================================================

#[generate_trait]
pub impl StoreImpl of StoreTrait {
    /// Crear un nuevo store - Operación CREATE
    fn create_store(
        ref world: dojo::world::WorldStorage,
        store_id: u32,
        name: felt252,
        owner: ContractAddress,
        max_items: u32,
        tax_rate: u16,
    ) -> StoreConfig {
        // Validaciones de negocio
        assert(tax_rate <= 10000, 'TAX_RATE_TOO_HIGH'); // Max 100%
        assert(max_items > 0, 'INVALID_MAX_ITEMS');
        assert(max_items <= 1000, 'TOO_MANY_ITEMS'); // Límite práctico

        let timestamp = starknet::get_block_timestamp();

        let store_config = StoreConfig {
            store_id, name, owner, is_active: true, tax_rate, max_items, created_at: timestamp,
        };

        // Persistir usando world.write_model()
        world.write_model(@store_config);

        // Configurar permisos del owner
        let owner_permissions = StorePermissions {
            store_id, user: owner, role: 4, // Owner
            granted_by: owner, granted_at: timestamp,
        };
        world.write_model(@owner_permissions);

        // Emitir evento
        world.emit_event(@StoreCreated { store_id, owner, name, timestamp });

        store_config
    }

    /// Leer configuración del store - Operación READ
    fn get_store_config(world: dojo::world::WorldStorage, store_id: u32) -> StoreConfig {
        world.read_model(store_id)
    }

    /// Verificar si un store existe y está activo
    fn is_store_active(world: dojo::world::WorldStorage, store_id: u32) -> bool {
        let config: StoreConfig = world.read_model(store_id);
        config.is_active && !config.owner.is_zero()
    }

    /// Agregar item al store - Operación CREATE/UPDATE
    fn add_item(
        ref world: dojo::world::WorldStorage,
        store_id: u32,
        item_id: u256,
        price: u256,
        stock: u32,
        category: felt252,
        rarity: u8,
    ) -> StoreItem {
        // Validar que el store existe
        let config: StoreConfig = world.read_model(store_id);
        assert(config.is_active, 'STORE_NOT_ACTIVE');

        // Validaciones de negocio
        assert(price > 0, 'INVALID_PRICE');
        assert(stock > 0, 'INVALID_STOCK');
        assert(rarity >= 1 && rarity <= 4, 'INVALID_RARITY');

        let store_item = StoreItem {
            store_id, item_id, price, stock, max_stock: stock, is_available: true, category, rarity,
        };

        // Persistir item
        world.write_model(@store_item);

        store_item
    }

    /// Comprar item del store - Operación UPDATE compleja
    fn purchase_item(
        ref world: dojo::world::WorldStorage,
        store_id: u32,
        item_id: u256,
        quantity: u32,
        buyer: ContractAddress,
    ) -> StoreTransaction {
        // Leer estado actual
        let config: StoreConfig = world.read_model(store_id);
        let mut item: StoreItem = world.read_model((store_id, item_id));

        // Validaciones de negocio
        assert(config.is_active, 'STORE_NOT_ACTIVE');
        assert(item.is_available, 'ITEM_NOT_AVAILABLE');
        assert(item.stock >= quantity, 'INSUFFICIENT_STOCK');
        assert(quantity > 0, 'INVALID_QUANTITY');

        // Calcular precios
        let base_price = item.price * quantity.into();
        let tax = (base_price * config.tax_rate.into()) / 10000;
        let total_price = base_price + tax;

        // Actualizar stock - Operación UPDATE
        item.stock -= quantity;
        if item.stock == 0 {
            item.is_available = false;
        }
        world.write_model(@item);

        // Crear transacción
        let transaction_id = generate_transaction_id(world, store_id, buyer);
        let timestamp = starknet::get_block_timestamp();

        let transaction = StoreTransaction {
            transaction_id,
            store_id,
            buyer,
            item_id,
            quantity,
            total_price,
            timestamp,
            status: 1 // Completed
        };

        world.write_model(@transaction);

        // Emitir evento
        world
            .emit_event(
                @ItemPurchased { store_id, buyer, item_id, quantity, total_price, timestamp },
            );

        transaction
    }

    /// Reabastecer stock - Operación UPDATE
    fn restock_item(
        ref world: dojo::world::WorldStorage, store_id: u32, item_id: u256, additional_stock: u32,
    ) {
        let mut item: StoreItem = world.read_model((store_id, item_id));

        assert(additional_stock > 0, 'INVALID_STOCK_AMOUNT');

        let old_stock = item.stock;
        item.stock += additional_stock;
        item.is_available = true;

        // Actualizar max_stock si es necesario
        if item.stock > item.max_stock {
            item.max_stock = item.stock;
        }

        world.write_model(@item);

        // Emitir evento
        let timestamp = starknet::get_block_timestamp();
        world
            .emit_event(
                @StoreRestocked { store_id, item_id, old_stock, new_stock: item.stock, timestamp },
            );
    }

    /// Obtener items por categoría - Operación READ compleja
    fn get_items_by_category(
        world: dojo::world::WorldStorage, store_id: u32, category: felt252,
    ) -> Array<StoreItem> {
        // En una implementación real, esto requeriría indexing o iteración
        // Por ahora retornamos array vacío como placeholder
        array![]
    }

    /// Verificar permisos - Sistema de permisos
    fn has_permission(
        world: dojo::world::WorldStorage, store_id: u32, user: ContractAddress, required_role: u8,
    ) -> bool {
        let permissions: StorePermissions = world.read_model((store_id, user));
        permissions.role >= required_role
    }

    /// Cerrar store - Operación UPDATE de estado
    fn close_store(ref world: dojo::world::WorldStorage, store_id: u32, reason: felt252) {
        let mut config: StoreConfig = world.read_model(store_id);

        assert(config.is_active, 'STORE_ALREADY_CLOSED');

        config.is_active = false;
        world.write_model(@config);

        // Emitir evento
        let timestamp = starknet::get_block_timestamp();
        world.emit_event(@StoreClosed { store_id, reason, timestamp });
    }

    /// Obtener historial de transacciones
    fn get_transaction_history(
        world: dojo::world::WorldStorage, store_id: u32, limit: u32,
    ) -> Array<StoreTransaction> {
        // Placeholder - en implementación real requiere indexing
        array![]
    }
}

// ============================================================================
// UTILITY FUNCTIONS - Funciones auxiliares
// ============================================================================

/// Generar ID único para transacciones
fn generate_transaction_id(
    world: dojo::world::WorldStorage, store_id: u32, buyer: ContractAddress,
) -> u256 {
    let timestamp = starknet::get_block_timestamp();
    let block_number = starknet::get_block_number();

    // Combinación simple para crear ID único
    // En implementación real, usar hash function
    (timestamp.into() * 1000000) + store_id.into() + (block_number % 1000000).into()
}

// ============================================================================
// CONSTANTS - Configuraciones del sistema
// ============================================================================

pub mod StoreConstants {
    // IDs constantes para settings globales
    pub const GLOBAL_STORE_ID: u32 = 0;
    pub const ADMIN_STORE_ID: u32 = 1;

    // Límites del sistema
    pub const MAX_STORES: u32 = 10000;
    pub const MAX_ITEMS_PER_STORE: u32 = 1000;
    pub const MAX_STOCK_PER_ITEM: u32 = 999999;

    // Roles de permisos
    pub const ROLE_NONE: u8 = 0;
    pub const ROLE_VIEWER: u8 = 1;
    pub const ROLE_MANAGER: u8 = 2;
    pub const ROLE_ADMIN: u8 = 3;
    pub const ROLE_OWNER: u8 = 4;

    // Estados de transacción
    pub const TX_PENDING: u8 = 0;
    pub const TX_COMPLETED: u8 = 1;
    pub const TX_FAILED: u8 = 2;
    pub const TX_REFUNDED: u8 = 3;

    // Categorías de items
    pub const CATEGORY_WEAPON: felt252 = 'WEAPON';
    pub const CATEGORY_ARMOR: felt252 = 'ARMOR';
    pub const CATEGORY_CONSUMABLE: felt252 = 'CONSUMABLE';
    pub const CATEGORY_MATERIAL: felt252 = 'MATERIAL';
    pub const CATEGORY_PET: felt252 = 'PET';
}

// ============================================================================
// ERROR CODES - Códigos de error estandarizados
// ============================================================================

pub mod StoreErrors {
    pub const STORE_NOT_FOUND: felt252 = 'STORE_NOT_FOUND';
    pub const STORE_NOT_ACTIVE: felt252 = 'STORE_NOT_ACTIVE';
    pub const ITEM_NOT_FOUND: felt252 = 'ITEM_NOT_FOUND';
    pub const ITEM_NOT_AVAILABLE: felt252 = 'ITEM_NOT_AVAILABLE';
    pub const INSUFFICIENT_STOCK: felt252 = 'INSUFFICIENT_STOCK';
    pub const INSUFFICIENT_FUNDS: felt252 = 'INSUFFICIENT_FUNDS';
    pub const UNAUTHORIZED: felt252 = 'UNAUTHORIZED';
    pub const INVALID_QUANTITY: felt252 = 'INVALID_QUANTITY';
    pub const INVALID_PRICE: felt252 = 'INVALID_PRICE';
    pub const STORE_FULL: felt252 = 'STORE_FULL';
    pub const TRANSACTION_FAILED: felt252 = 'TRANSACTION_FAILED';
}
