use starknet::{ContractAddress, get_caller_address, get_block_timestamp};

#[dojo::model]
#[derive(Drop, Copy, Serde)]
pub struct Explosives {
    #[key]
    pub asset_id: u256,
    pub damage: u64,
    pub blast_radius: u64,
    pub detonation_time: u64, // Fuse time in seconds
    pub is_sticky: bool,
    // --- State fields ---
    pub is_armed: bool,
    pub armed_by: ContractAddress,
    pub armed_timestamp: u64,
}

#[generate_trait]
pub impl ExplosivesImpl of ExplosivesTrait {
    fn init(
        ref self: Explosives,
        asset_id: u256,
        damage: u64,
        blast_radius: u64,
        detonation_time: u64,
        is_sticky: bool,
    ) {
        self.asset_id = asset_id;
        self.damage = damage;
        self.blast_radius = blast_radius;
        self.detonation_time = detonation_time;
        self.is_sticky = is_sticky;

        // Initialize in a safe, disarmed state
        self.is_armed = false;
        self.armed_by = starknet::contract_address_const::<0>(); // Zero address
        self.armed_timestamp = 0;
    }

    fn arm(ref self: Explosives) -> bool {
        // Prevent re-arming an already armed explosive.
        if self.is_armed {
            return false;
        }

        // Set the state to armed.
        self.is_armed = true;
        self.armed_by = get_caller_address();
        self.armed_timestamp = get_block_timestamp();

        true
    }

    fn disarm(ref self: Explosives) -> bool {
        let caller = get_caller_address();

        // Only the person who armed it can disarm it.
        if !self.is_armed || self.armed_by != caller {
            return false;
        }

        // Reset the state to safe/disarmed.
        self.is_armed = false;
        self.armed_by = starknet::contract_address_const::<0>();
        self.armed_timestamp = 0;

        true
    }

    fn should_detonate(self: @Explosives) -> bool {
        if !*self.is_armed {
            return false;
        }

        let current_time = get_block_timestamp();
        // Guard against underflow and avoid overflow by comparing via subtraction
        if current_time < *self.armed_timestamp {
            return false;
        }
        current_time - *self.armed_timestamp >= *self.detonation_time
    }
}
