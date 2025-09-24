#[cfg(test)]
mod security_tests {
    use starknet::{ContractAddress, contract_address_const};
    use dojo::model::{ModelStorage, ModelValueStorage};
    use dojo::world::WorldStorageTrait;
    use coa::models::core::Contract;
    use coa::models::security::{SecurityConfig, RateLimit};
    use coa::helpers::security::{
        validate_admin_access, check_rate_limit, validate_session_duration, sanitize_input,
        validate_faction, COA_CONTRACTS, SECURITY_CONFIG_ID, CREATE_SESSION_OP,
    };

    #[test]
    fn test_validate_session_duration() {
        // Valid durations
        assert(validate_session_duration(3600), 'Should accept 1 hour');
        assert(validate_session_duration(86400), 'Should accept 24 hours');

        // Invalid durations
        assert(!validate_session_duration(3599), 'Should reject < 1 hour');
        assert(!validate_session_duration(86401), 'Should reject > 24 hours');
    }

    #[test]
    fn test_validate_faction() {
        // Valid factions
        assert(validate_faction('CHAOS_MERCENARIES'), 'Should accept CHAOS_MERCENARIES');
        assert(validate_faction('SUPREME_LAW'), 'Should accept SUPREME_LAW');
        assert!(validate_faction('REBEL_TECHNOMANCERS'), "Should accept REBEL_TECHNOMANCERS");

        // Invalid faction
        assert(!validate_faction('INVALID_FACTION'), 'Should reject invalid faction');
    }

    #[test]
    fn test_input_sanitization() {
        let input = 'test_input';
        let sanitized = sanitize_input(input);

        // Basic test - in a real implementation this would do more
        assert(sanitized == input, 'Input should be sanitized');
    }
}
