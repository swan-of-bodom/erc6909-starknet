// SPDX-License-Identifier: MIT

/// # ERC6909 Component
///
/// The ERC6909 component provides an implementation of the Minimal Multi-Token standard authored by jtriley.eth
/// See https://eips.ethereum.org/EIPS/eip-6909.
#[starknet::component]
mod ERC6909 {
    use core::integer::BoundedInt;
    use core::num::traits::Zero;
    use erc6909::token::erc6909::interface;
    use openzeppelin::introspection::interface::ISRC5_ID;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    #[storage]
    struct Storage {
        ERC6909_name: LegacyMap<u256, ByteArray>,
        ERC6909_symbol: LegacyMap<u256, ByteArray>,
        ERC6909_balances: LegacyMap<(ContractAddress, u256), u256>,
        ERC6909_allowances: LegacyMap<(ContractAddress, ContractAddress, u256), u256>,
        ERC6909_operators: LegacyMap<(ContractAddress, ContractAddress), bool>,
        ERC6909_total_supply: LegacyMap<u256, u256>,
        ERC6909_contract_uri: ByteArray,
        ERC6909_token_uri: LegacyMap<u256, ByteArray>
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
        OperatorSet: OperatorSet
    }

    /// @notice The event emitted when a transfer occurs.
    /// @param caller The caller of the transfer.
    /// @param sender The address of the sender.
    /// @param receiver The address of the receiver.
    /// @param id The id of the token.
    /// @param amount The amount of the token.
    #[derive(Drop, PartialEq, starknet::Event)]
    struct Transfer {
        caller: ContractAddress,
        #[key]
        sender: ContractAddress,
        #[key]
        receiver: ContractAddress,
        #[key]
        id: u256,
        amount: u256,
    }

    /// @notice The event emitted when an approval occurs.
    /// @param owner The address of the owner.
    /// @param spender The address of the spender.
    /// @param id The id of the token.
    /// @param amount The amount of the token.
    #[derive(Drop, PartialEq, starknet::Event)]
    struct Approval {
        #[key]
        owner: ContractAddress,
        #[key]
        spender: ContractAddress,
        #[key]
        id: u256,
        amount: u256
    }

    /// @notice The event emitted when an operator is set.
    /// @param owner The address of the owner.
    /// @param spender The address of the spender.
    /// @param approved The approval status.
    #[derive(Drop, PartialEq, starknet::Event)]
    struct OperatorSet {
        #[key]
        owner: ContractAddress,
        #[key]
        spender: ContractAddress,
        approved: bool,
    }

    mod Errors {
        /// @dev Thrown when owner balance for id is insufficient.
        pub const INSUFFICIENT_BALANCE: felt252 = 'ERC6909: Insufficient Balance';
        /// @dev Thrown when spender allowance for id is insufficient.
        pub const INSUFFICIENT_PERMISION: felt252 = 'ERC6909: Insufficient Perms';
        /// @dev Thrown when transfering from the zero address
        pub const TRANSFER_FROM_ZERO: felt252 = 'ERC6909: Transfer From 0';
        /// @dev Thrown when transfering to the zero address
        pub const TRANSFER_TO_ZERO: felt252 = 'ERC6909: Transfer To 0';
        pub const MINT_TO_ZERO: felt252 = 'ERC6909: Mint to 0';
        pub const BURN_FROM_ZERO: felt252 = 'ERC6909: Burn from 0';
    }

    #[embeddable_as(ERC6909Impl)]
    impl ERC6909<
        TContractState, +HasComponent<TContractState>,
    > of interface::IERC6909<ComponentState<TContractState>> {
        /// @notice Owner balance of an id.
        fn balance_of(self: @ComponentState<TContractState>, owner: ContractAddress, id: u256) -> u256 {
            self.ERC6909_balances.read((owner, id))
        }

        /// @notice Spender allowance of an id.
        fn allowance(
            self: @ComponentState<TContractState>, owner: ContractAddress, spender: ContractAddress, id: u256
        ) -> u256 {
            self.ERC6909_allowances.read((owner, spender, id))
        }

        /// @notice Checks if a spender is approved by an owner as an operator.
        fn is_operator(
            self: @ComponentState<TContractState>, owner: ContractAddress, spender: ContractAddress
        ) -> bool {
            self.ERC6909_operators.read((owner, spender))
        }

        /// @notice Transfers an amount of an id from the caller to a receiver.
        /// @param receiver The address of the receiver.
        /// @param id The id of the token.
        /// @param amount The amount of the token.
        fn transfer(
            ref self: ComponentState<TContractState>, receiver: ContractAddress, id: u256, amount: u256
        ) -> bool {
            let caller = get_caller_address();
            self._transfer(caller, caller, receiver, id, amount);
            true
        }

        /// @notice Transfers an amount of an id from a sender to a receiver.
        /// @param sender The address of the sender.
        /// @param receiver The address of the receiver.
        /// @param id The id of the token.
        /// @param amount The amount of the token.
        fn transfer_from(
            ref self: ComponentState<TContractState>,
            sender: ContractAddress,
            receiver: ContractAddress,
            id: u256,
            amount: u256
        ) -> bool {
            let caller = get_caller_address();
            self._spend_allowance(sender, caller, id, amount);
            self._transfer(caller, sender, receiver, id, amount);
            true
        }

        /// @notice Approves an amount of an id to a spender.
        /// @param spender The address of the spender.
        /// @param id The id of the token.
        /// @param amount The amount of the token.
        fn approve(ref self: ComponentState<TContractState>, spender: ContractAddress, id: u256, amount: u256) -> bool {
            let owner = get_caller_address();
            self.ERC6909_allowances.write((owner, spender, id), amount);
            self.emit(Approval { owner, spender, id, amount });
            true
        }

        /// @notice Sets or unsets a spender as an operator for the caller.
        /// @param spender The address of the spender.
        /// @param approved The approval status.
        fn set_operator(ref self: ComponentState<TContractState>, spender: ContractAddress, approved: bool) -> bool {
            let owner = get_caller_address();
            self.ERC6909_operators.write((owner, spender), approved);
            self.emit(OperatorSet { owner, spender, approved });
            true
        }

        /// @notice Checks if a contract implements an interface.
        /// @param interfaceId The interface identifier, as specified in ERC-165.
        /// @return True if the contract implements `interfaceId` and `interfaceId` is not 0xffffffff, false otherwise.
        fn supports_interface(self: @ComponentState<TContractState>, interface_id: felt252) -> bool {
            interface_id == interface::IERC6909_ID || interface_id == ISRC5_ID
        }
    }

    #[embeddable_as(ERC6909MetadataImpl)]
    impl ERC6909Metadata<
        TContractState, +HasComponent<TContractState>
    > of interface::IERC6909Metadata<ComponentState<TContractState>> {
        /// @notice Name of a given token.
        /// @param id The id of the token.
        /// @return The name of the token.
        fn name(self: @ComponentState<TContractState>, id: u256) -> ByteArray {
            self.ERC6909_name.read(id)
        }

        /// @notice Symbol of a given token.
        /// @param id The id of the token.
        /// @return The symbol of the token.
        fn symbol(self: @ComponentState<TContractState>, id: u256) -> ByteArray {
            self.ERC6909_symbol.read(id)
        }

        /// @notice Decimals of a given token.
        /// @param id The id of the token.
        /// @return The decimals of the token.
        fn decimals(self: @ComponentState<TContractState>, id: u256) -> u8 {
            18
        }
    }

    #[embeddable_as(IERC6909TokenSupplyImpl)]
    impl ERC6909TokenSupply<
        TContractState, +HasComponent<TContractState>
    > of interface::IERC6909TokenSupply<ComponentState<TContractState>> {
        /// @notice Total supply of a token.
        fn total_supply(self: @ComponentState<TContractState>, id: u256) -> u256 {
            self.ERC6909_total_supply.read(id)
        }
    }

    #[embeddable_as(IERC6909ContentURIImpl)]
    impl IERC6909ContentURI<
        TContractState, +HasComponent<TContractState>
    > of interface::IERC6909ContentURI<ComponentState<TContractState>> {
        /// @notice The contract level URI.
        fn contract_uri(self: @ComponentState<TContractState>) -> ByteArray {
            self.ERC6909_contract_uri.read()
        }

        /// @notice The URI for each id.
        /// @return The URI of the token.
        fn token_uri(self: @ComponentState<TContractState>, id: u256) -> ByteArray {
            self.ERC6909_token_uri.read(id)
        }
    }

    #[embeddable_as(ERC6909CamelImpl)]
    impl ERC6909Camel<
        TContractState, +HasComponent<TContractState>,
    > of interface::IERC6909Camel<ComponentState<TContractState>> {
        /// @notice Owner balance of an id.
        fn balanceOf(self: @ComponentState<TContractState>, owner: ContractAddress, id: u256) -> u256 {
            ERC6909::balance_of(self, owner, id)
        }

        /// @notice Spender allowance of an id.
        fn allowance(
            self: @ComponentState<TContractState>, owner: ContractAddress, spender: ContractAddress, id: u256
        ) -> u256 {
            ERC6909::allowance(self, owner, spender, id)
        }

        /// @notice Checks if a spender is approved by an owner as an operator.
        fn isOperator(self: @ComponentState<TContractState>, owner: ContractAddress, spender: ContractAddress) -> bool {
            ERC6909::is_operator(self, owner, spender)
        }

        /// @notice Transfers an amount of an id from the caller to a receiver.
        /// @param receiver The address of the receiver.
        /// @param id The id of the token.
        /// @param amount The amount of the token.
        fn transfer(
            ref self: ComponentState<TContractState>, receiver: ContractAddress, id: u256, amount: u256
        ) -> bool {
            ERC6909::transfer(ref self, receiver, id, amount)
        }

        /// @notice Transfers an amount of an id from a sender to a receiver.
        /// @param sender The address of the sender.
        /// @param receiver The address of the receiver.
        /// @param id The id of the token.
        /// @param amount The amount of the token.
        fn transferFrom(
            ref self: ComponentState<TContractState>,
            sender: ContractAddress,
            receiver: ContractAddress,
            id: u256,
            amount: u256
        ) -> bool {
            ERC6909::transfer_from(ref self, sender, receiver, id, amount)
        }

        /// @notice Approves an amount of an id to a spender.
        /// @param spender The address of the spender.
        /// @param id The id of the token.
        /// @param amount The amount of the token.
        fn approve(ref self: ComponentState<TContractState>, spender: ContractAddress, id: u256, amount: u256) -> bool {
            ERC6909::approve(ref self, spender, id, amount)
        }

        /// @notice Sets or unsets a spender as an operator for the caller.
        /// @param spender The address of the spender.
        /// @param approved The approval status.
        fn setOperator(ref self: ComponentState<TContractState>, spender: ContractAddress, approved: bool) -> bool {
            ERC6909::set_operator(ref self, spender, approved)
        }

        /// @notice Checks if a contract implements an interface.
        /// @param interfaceId The interface identifier, as specified in ERC-165.
        /// @return True if the contract implements `interfaceId` and `interfaceId` is not 0xffffffff, false otherwise.
        fn supportsInterface(self: @ComponentState<TContractState>, interface_id: felt252) -> bool {
            ERC6909::supports_interface(self, interface_id)
        }
    }

    /// internal
    #[generate_trait]
    impl InternalImpl<TContractState, +HasComponent<TContractState>> of InternalTrait<TContractState> {
        /// Updates `owner`s allowance for `spender` based on spent `amount`.
        /// Does not update the allowance value in case of infinite allowance.
        fn _spend_allowance(
            ref self: ComponentState<TContractState>,
            owner: ContractAddress,
            spender: ContractAddress,
            id: u256,
            amount: u256
        ) {
            let is_operator = self.ERC6909_operators.read((owner, spender));
            if owner != spender && !is_operator {
                let current_allowance = self.ERC6909_allowances.read((owner, spender, id));
                if current_allowance != BoundedInt::max() {
                    assert(current_allowance >= amount, Errors::INSUFFICIENT_PERMISION);
                    self.ERC6909_allowances.write((owner, spender, id), current_allowance - amount);
                }
            }
        }

        /// Internal method that moves an `amount` of tokens from `from` to `to`.
        ///
        /// Requirements:
        ///
        /// - `sender` is not the zero address.
        /// - `sender` must have at least a balance of `amount`.
        /// - `receiver` is not the zero address.
        ///
        /// Emits a `Transfer` event.
        fn _transfer(
            ref self: ComponentState<TContractState>,
            caller: ContractAddress,
            sender: ContractAddress,
            receiver: ContractAddress,
            id: u256,
            amount: u256
        ) {
            assert(!sender.is_zero(), Errors::TRANSFER_FROM_ZERO);
            assert(!receiver.is_zero(), Errors::TRANSFER_TO_ZERO);
            self._update(caller, sender, receiver, id, amount);
        }

        /// Transfers an `amount` of tokens from `from` to `to`, or alternatively mints (or burns) if `from` (or `to`) is
        /// the zero address.
        ///
        /// NOTE: This function can be extended using the `ERC6909HooksTrait`, to add
        /// functionality before and/or after the transfer, mint, or burn.
        ///
        /// Emits a `Transfer` event.
        fn _update(
            ref self: ComponentState<TContractState>,
            caller: ContractAddress,
            from: ContractAddress,
            to: ContractAddress,
            id: u256,
            amount: u256
        ) {
            let zero_address = Zero::zero();

            if (from == zero_address) {
                let total_supply = self.ERC6909_total_supply.read(id);
                self.ERC6909_total_supply.write(id, total_supply + amount);
            } else {
                let from_balance = self.ERC6909_balances.read((from, id));
                assert(from_balance >= amount, Errors::INSUFFICIENT_BALANCE);
                self.ERC6909_balances.write((from, id), from_balance - amount);
            }

            if (to == zero_address) {
                let total_supply = self.ERC6909_total_supply.read(id);
                self.ERC6909_total_supply.write(id, total_supply - amount);
            } else {
                let to_balance = self.ERC6909_balances.read((to, id));
                self.ERC6909_balances.write((to, id), to_balance + amount);
            }

            self.emit(Transfer { caller, sender: from, receiver: to, id, amount });
        }

        /// Creates a `value` amount of tokens and assigns them to `account`.
        ///
        /// Requirements:
        ///
        /// - `receiver` is not the zero address.
        ///
        /// Emits a `Transfer` event with `from` set to the zero address.
        fn _mint(ref self: ComponentState<TContractState>, receiver: ContractAddress, id: u256, amount: u256) {
            assert(!receiver.is_zero(), Errors::MINT_TO_ZERO);
            self._update(get_caller_address(), Zero::zero(), receiver, id, amount);
        }

        /// Destroys `amount` of tokens from `account`.
        ///
        /// Requirements:
        ///
        /// - `account` is not the zero address.
        /// - `account` must have at least a balance of `amount`.
        ///
        /// Emits a `Transfer` event with `to` set to the zero address.
        fn _burn(ref self: ComponentState<TContractState>, account: ContractAddress, id: u256, amount: u256) {
            assert(!account.is_zero(), Errors::BURN_FROM_ZERO);
            self._update(get_caller_address(), account, Zero::zero(), id, amount);
        }
    }
}
