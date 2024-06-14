// Starknet lib
use core::integer::BoundedInt;
use core::starknet::{ContractAddress, testing};

// ERC6909
use erc6909::tests::mocks::erc6909_mocks::DualCaseERC6909Mock;
use erc6909::token::erc6909::{
    ERC6909Component,
    ERC6909Component::{
        Approval, Transfer, InternalImpl, ERC6909Impl, ERC6909CamelImpl, ERC6909TokenSupplyImpl,
        ERC6909TokenSupplyCamelImpl
    }
};

// OpenZeppelin Utils
use openzeppelin::tests::{
    utils, utils::constants::{ZERO, OWNER, SPENDER, RECIPIENT, NAME, SYMBOL, DECIMALS, SUPPLY, VALUE}
};
use openzeppelin::utils::serde::SerializedAppend;

//
// Setup
//

const TOKEN_ID: u256 = 420;

type ComponentState = ERC6909Component::ComponentState<DualCaseERC6909Mock::ContractState>;

fn COMPONENT_STATE() -> ComponentState {
    ERC6909Component::component_state_for_testing()
}

fn setup() -> ComponentState {
    let mut state = COMPONENT_STATE();
    state.mint(OWNER(), TOKEN_ID, SUPPLY);
    utils::drop_event(ZERO());
    state
}

//
// Getters
//

#[test]
fn test_total_supply() {
    let mut state = COMPONENT_STATE();
    state.mint(OWNER(), TOKEN_ID, SUPPLY);
    assert_eq!(state.total_supply(TOKEN_ID), SUPPLY);
}

#[test]
fn test_totalSupply() {
    let mut state = COMPONENT_STATE();
    state.mint(OWNER(), TOKEN_ID, SUPPLY);
    assert_eq!(state.totalSupply(TOKEN_ID), SUPPLY);
}

#[test]
fn test_balance_of() {
    let mut state = COMPONENT_STATE();
    state.mint(OWNER(), TOKEN_ID, SUPPLY);
    assert_eq!(state.balance_of((OWNER()), TOKEN_ID), SUPPLY);
}

#[test]
fn test_balanceOf() {
    let mut state = COMPONENT_STATE();
    state.mint(OWNER(), TOKEN_ID, SUPPLY);
    assert_eq!(state.balanceOf((OWNER()), TOKEN_ID), SUPPLY);
}

#[test]
fn test_allowance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.approve(SPENDER(), TOKEN_ID, VALUE);
    let allowance = state.allowance(OWNER(), SPENDER(), TOKEN_ID);
    assert_eq!(allowance, VALUE);
}

//
// approve & _approve
//

#[test]
fn test_approve() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    assert!(state.approve(SPENDER(), TOKEN_ID, VALUE));
    assert_only_event_approval(ZERO(), OWNER(), SPENDER(), TOKEN_ID, VALUE);
    let allowance = state.allowance(OWNER(), SPENDER(), TOKEN_ID);
    assert_eq!(allowance, VALUE);
}

#[test]
#[should_panic(expected: ('ERC6909: approve from 0',))]
fn test_approve_from_zero() {
    let mut state = setup();
    state.approve(SPENDER(), TOKEN_ID, VALUE);
}

#[test]
#[should_panic(expected: ('ERC6909: approve to 0',))]
fn test_approve_to_zero() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.approve(ZERO(), TOKEN_ID, VALUE);
}

#[test]
fn test__approve() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state._approve(OWNER(), SPENDER(), TOKEN_ID, VALUE);
    assert_only_event_approval(ZERO(), OWNER(), SPENDER(), TOKEN_ID, VALUE);
    let allowance = state.allowance(OWNER(), SPENDER(), TOKEN_ID,);
    assert_eq!(allowance, VALUE);
}

#[test]
#[should_panic(expected: ('ERC6909: approve from 0',))]
fn test__approve_from_zero() {
    let mut state = setup();
    state._approve(ZERO(), SPENDER(), TOKEN_ID, VALUE);
}

#[test]
#[should_panic(expected: ('ERC6909: approve to 0',))]
fn test__approve_to_zero() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state._approve(OWNER(), ZERO(), TOKEN_ID, VALUE);
}

//
// transfer & _transfer
//

#[test]
fn test_transfer() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    assert!(state.transfer(RECIPIENT(), TOKEN_ID, VALUE));

    assert_only_event_transfer(ZERO(), OWNER(), OWNER(), RECIPIENT(), TOKEN_ID, VALUE);
    assert_eq!(state.balance_of(RECIPIENT(), TOKEN_ID), VALUE);
    assert_eq!(state.balance_of(OWNER(), TOKEN_ID), SUPPLY - VALUE);
    assert_eq!(state.total_supply(TOKEN_ID), SUPPLY);
}

#[test]
#[should_panic(expected: ('ERC6909: insufficient balance',))]
fn test_transfer_not_enough_balance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    let balance_plus_one = SUPPLY + 1;
    state.transfer(RECIPIENT(), TOKEN_ID, balance_plus_one);
}

#[test]
#[should_panic(expected: ('ERC6909: transfer from 0',))]
fn test_transfer_from_zero() {
    let mut state = setup();
    state.transfer(RECIPIENT(), TOKEN_ID, VALUE);
}

#[test]
#[should_panic(expected: ('ERC6909: transfer to 0',))]
fn test_transfer_to_zero() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.transfer(ZERO(), TOKEN_ID, VALUE);
}

#[test]
fn test__transfer() {
    let mut state = setup();
    state._transfer(OWNER(), OWNER(), RECIPIENT(), TOKEN_ID, VALUE);
    assert_only_event_transfer(ZERO(), OWNER(), OWNER(), RECIPIENT(), TOKEN_ID, VALUE);
    assert_eq!(state.balance_of(RECIPIENT(), TOKEN_ID), VALUE);
    assert_eq!(state.balance_of(OWNER(), TOKEN_ID), SUPPLY - VALUE);
    assert_eq!(state.total_supply(TOKEN_ID), SUPPLY);
}

#[test]
#[should_panic(expected: ('ERC6909: insufficient balance',))]
fn test__transfer_not_enough_balance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    let balance_plus_one = SUPPLY + 1;
    state._transfer(OWNER(), OWNER(), RECIPIENT(), TOKEN_ID, balance_plus_one);
}

#[test]
#[should_panic(expected: ('ERC6909: transfer from 0',))]
fn test__transfer_from_zero() {
    let mut state = setup();
    state._transfer(ZERO(), ZERO(), RECIPIENT(), TOKEN_ID, VALUE);
}

#[test]
#[should_panic(expected: ('ERC6909: transfer to 0',))]
fn test__transfer_to_zero() {
    let mut state = setup();
    state._transfer(OWNER(), OWNER(), ZERO(), TOKEN_ID, VALUE);
}

//
// transfer_from & transferFrom
//

#[test]
fn test_transfer_from() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.approve(SPENDER(), TOKEN_ID, VALUE);
    utils::drop_event(ZERO());

    testing::set_caller_address(SPENDER());
    assert!(state.transfer_from(OWNER(), RECIPIENT(), TOKEN_ID, VALUE));

    assert_event_approval(ZERO(), OWNER(), SPENDER(), TOKEN_ID, 0);
    assert_only_event_transfer(ZERO(), SPENDER(), OWNER(), RECIPIENT(), TOKEN_ID, VALUE);

    let allowance = state.allowance(OWNER(), SPENDER(), TOKEN_ID);
    assert_eq!(allowance, 0);

    assert_eq!(state.balance_of(RECIPIENT(), TOKEN_ID), VALUE);
    assert_eq!(state.balance_of(OWNER(), TOKEN_ID), SUPPLY - VALUE);
    assert_eq!(state.total_supply(TOKEN_ID), SUPPLY);
}

#[test]
fn test_transfer_from_doesnt_consume_infinite_allowance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.approve(SPENDER(), TOKEN_ID, BoundedInt::max());

    testing::set_caller_address(SPENDER());
    state.transfer_from(OWNER(), RECIPIENT(), TOKEN_ID, VALUE);

    let allowance = state.allowance(OWNER(), SPENDER(), TOKEN_ID);
    assert_eq!(allowance, BoundedInt::max());
}

#[test]
#[should_panic(expected: ('ERC6909: insufficient allowance',))]
fn test_transfer_from_greater_than_allowance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.approve(SPENDER(), TOKEN_ID, VALUE);

    testing::set_caller_address(SPENDER());
    let allowance_plus_one = VALUE + 1;
    state.transfer_from(OWNER(), RECIPIENT(), TOKEN_ID, allowance_plus_one);
}

#[test]
#[should_panic(expected: ('ERC6909: transfer to 0',))]
fn test_transfer_from_to_zero_address() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.approve(SPENDER(), TOKEN_ID, VALUE);

    testing::set_caller_address(SPENDER());
    state.transfer_from(OWNER(), ZERO(), TOKEN_ID, VALUE);
}

// This does not check `_spend_allowance` since the owner (the zero address) 
// is the sender, see `_spend_allowance` in erc6909.cairo
#[test]
#[should_panic(expected: ('ERC6909: transfer from 0',))]
fn test_transfer_from_from_zero_address() {
    let mut state = setup();
    state.transfer_from(ZERO(), RECIPIENT(), TOKEN_ID, VALUE);
}

#[test]
#[should_panic(expected: ('ERC6909: insufficient allowance',))]
fn test_transfer_no_allowance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.approve(SPENDER(), TOKEN_ID, VALUE);

    testing::set_caller_address(RECIPIENT());
    state.transfer_from(OWNER(), ZERO(), TOKEN_ID, VALUE);
}

#[test]
fn test_transferFrom() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.approve(SPENDER(), TOKEN_ID, VALUE);
    utils::drop_event(ZERO());

    testing::set_caller_address(SPENDER());
    assert!(state.transferFrom(OWNER(), RECIPIENT(), TOKEN_ID, VALUE));

    assert_event_approval(ZERO(), OWNER(), SPENDER(), TOKEN_ID, 0);
    assert_only_event_transfer(ZERO(), SPENDER(), OWNER(), RECIPIENT(), TOKEN_ID, VALUE);

    let allowance = state.allowance(OWNER(), SPENDER(), TOKEN_ID);
    assert_eq!(allowance, 0);

    assert_eq!(state.balance_of(RECIPIENT(), TOKEN_ID), VALUE);
    assert_eq!(state.balance_of(OWNER(), TOKEN_ID), SUPPLY - VALUE);
    assert_eq!(state.total_supply(TOKEN_ID), SUPPLY);
    assert_eq!(allowance, 0);
}

#[test]
fn test_transferFrom_doesnt_consume_infinite_allowance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.approve(SPENDER(), TOKEN_ID, BoundedInt::max());

    testing::set_caller_address(SPENDER());
    state.transferFrom(OWNER(), RECIPIENT(), TOKEN_ID, VALUE);

    let allowance = state.allowance(OWNER(), SPENDER(), TOKEN_ID);
    assert_eq!(allowance, BoundedInt::max());
}

#[test]
#[should_panic(expected: ('ERC6909: insufficient allowance',))]
fn test_transferFrom_greater_than_allowance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.approve(SPENDER(), TOKEN_ID, VALUE);

    testing::set_caller_address(SPENDER());
    let allowance_plus_one = VALUE + 1;
    state.transferFrom(OWNER(), RECIPIENT(), TOKEN_ID, allowance_plus_one);
}

#[test]
#[should_panic(expected: ('ERC6909: transfer to 0',))]
fn test_transferFrom_to_zero_address() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.approve(SPENDER(), TOKEN_ID, VALUE);

    testing::set_caller_address(SPENDER());
    state.transferFrom(OWNER(), ZERO(), TOKEN_ID, VALUE);
}

//
// _spend_allowance
//

#[test]
fn test__spend_allowance_not_unlimited() {
    let mut state = setup();

    state._approve(OWNER(), SPENDER(), TOKEN_ID, SUPPLY);
    utils::drop_event(ZERO());

    state._spend_allowance(OWNER(), SPENDER(), TOKEN_ID, VALUE);

    assert_only_event_approval(ZERO(), OWNER(), SPENDER(), TOKEN_ID, SUPPLY - VALUE);

    let allowance = state.allowance(OWNER(), SPENDER(), TOKEN_ID);
    assert_eq!(allowance, SUPPLY - VALUE);
}

#[test]
fn test__spend_allowance_unlimited() {
    let mut state = setup();
    state._approve(OWNER(), SPENDER(), TOKEN_ID, BoundedInt::max());

    let max_minus_one: u256 = BoundedInt::max() - 1;
    state._spend_allowance(OWNER(), SPENDER(), TOKEN_ID, max_minus_one);

    let allowance = state.allowance(OWNER(), SPENDER(), TOKEN_ID);
    assert_eq!(allowance, BoundedInt::max());
}

//
// _mint
//

#[test]
fn test__mint() {
    let mut state = COMPONENT_STATE();
    state.mint(OWNER(), TOKEN_ID, VALUE);

    assert_only_event_transfer(ZERO(), ZERO(), ZERO(), OWNER(), TOKEN_ID, VALUE);
    assert_eq!(state.balance_of(OWNER(), TOKEN_ID), VALUE);
    assert_eq!(state.total_supply(TOKEN_ID), VALUE);
}

#[test]
#[should_panic(expected: ('ERC6909: mint to 0',))]
fn test__mint_to_zero() {
    let mut state = COMPONENT_STATE();
    state.mint(ZERO(), TOKEN_ID, VALUE);
}

//
// _burn
//

#[test]
fn test__burn() {
    let mut state = setup();
    state.burn(OWNER(), TOKEN_ID, VALUE);

    assert_only_event_transfer(ZERO(), ZERO(), OWNER(), ZERO(), TOKEN_ID, VALUE);
    assert_eq!(state.balance_of(OWNER(), TOKEN_ID), SUPPLY - VALUE);
    assert_eq!(state.total_supply(TOKEN_ID), SUPPLY - VALUE);
}

#[test]
#[should_panic(expected: ('ERC6909: burn from 0',))]
fn test__burn_from_zero() {
    let mut state = setup();
    state.burn(ZERO(), TOKEN_ID, VALUE);
}


//
// Helpers
//

// Checks indexed keys
fn assert_event_approval(
    contract: ContractAddress, owner: ContractAddress, spender: ContractAddress, id: u256, amount: u256
) {
    let event = utils::pop_log::<ERC6909Component::Event>(contract).unwrap();
    let expected = ERC6909Component::Event::Approval(Approval { owner, spender, id, amount });
    assert!(event == expected);
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("Approval"));
    indexed_keys.append_serde(owner);
    indexed_keys.append_serde(spender);
    indexed_keys.append_serde(id);
    utils::assert_indexed_keys(event, indexed_keys.span())
}

fn assert_only_event_approval(
    contract: ContractAddress, owner: ContractAddress, spender: ContractAddress, id: u256, amount: u256
) {
    assert_event_approval(contract, owner, spender, id, amount);
    utils::assert_no_events_left(contract);
}

// Checks indexed keys
fn assert_event_transfer(
    contract: ContractAddress,
    caller: ContractAddress,
    sender: ContractAddress,
    receiver: ContractAddress,
    id: u256,
    amount: u256
) {
    let event = utils::pop_log::<ERC6909Component::Event>(contract).unwrap();
    let expected = ERC6909Component::Event::Transfer(Transfer { caller, sender, receiver, id, amount });
    assert!(event == expected);
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("Transfer"));
    indexed_keys.append_serde(sender);
    indexed_keys.append_serde(receiver);
    indexed_keys.append_serde(id);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

fn assert_only_event_transfer(
    contract: ContractAddress,
    caller: ContractAddress,
    sender: ContractAddress,
    receiver: ContractAddress,
    id: u256,
    amount: u256
) {
    assert_event_transfer(contract, caller, sender, receiver, id, amount);
    utils::assert_no_events_left(contract);
}
