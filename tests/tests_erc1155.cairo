use array::ArrayTrait;
use array::SpanTrait;
use debug::PrintTrait;

use erc1155::preset::ERC1155;

use traits::Into;
use option::OptionTrait;
use box::BoxTrait;
use clone::Clone;
use array::ArrayTCloneImpl;

use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing::set_caller_address;

use integer::u256_from_felt252;

//
// Helper functions
//

fn setup() -> ContractAddress {
    let account: ContractAddress = contract_address_const::<1>();
    set_caller_address(account);

    let mut uri = ArrayTrait::<felt252>::new();
    uri.append('ipfs://bafybeigdyrzt5sfp7udm7hu');
    uri.append('6nf3efuylqabf3oclgtqy55fbzdi');

    ERC1155::constructor(account, uri);
    account
}

fn set_caller_as_zero() {
    set_caller_address(contract_address_const::<0>());
}

fn generate_array_u256(len: u32, val: u256, step: u256) -> Array<u256> {
    let mut arr = ArrayTrait::<u256>::new();
    let mut _val = val;
    let mut i = 0_u32;
    loop {
        match gas::withdraw_gas_all(get_builtin_costs()) {
            Option::Some(_) => {},
            Option::None(_) => {
                let mut data = ArrayTrait::new();
                data.append('Out of gas');
                panic(data);
            },
        }
        if i == len {
            break ();
        }
        arr.append(_val);
        let j = i + 1_u32;
        i = j;

        let prev = _val + step;
        _val = prev;
    };
    arr
}

//
// Tests
//

#[test]
#[available_gas(2000000)]
fn test_constructor() {
    let account: ContractAddress = contract_address_const::<1>();
    set_caller_address(account);

    let mut uri = ArrayTrait::<felt252>::new();
    uri.append('ipfs://bafybeigdyrzt5sfp7udm7hu');
    uri.append('6nf3efuylqabf3oclgtqy55fbzdi');

    ERC1155::constructor(account, uri.clone());

    let owner = ERC1155::owner();
    assert(owner == account, 'Owner is not account');

    let mut _uri = ERC1155::uri(1.into());
    assert(_uri.len() == 2, 'URI length is not 2');
    assert(_uri.pop_front().unwrap() == uri.pop_front().unwrap(), 'URI is not correct');
    assert(_uri.pop_front().unwrap() == uri.pop_front().unwrap(), 'URI is not correct');
}

#[test]
#[available_gas(2000000)]
fn test_set_approval_for_all() {
    let owner = setup();
    let operator = contract_address_const::<2>();

    let success = ERC1155::set_approval_for_all(operator, true);
    assert(success, 'Should return true');
    assert(ERC1155::is_approved_for_all(owner, operator), 'operator not approved');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('caller cannot be 0 address', ))]
fn test_set_approval_for_all_from_0() {
    set_caller_as_zero();
    let operator = contract_address_const::<2>();
    ERC1155::set_approval_for_all(operator, true);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('operator cannot be 0 address', ))]
fn test_set_approval_for_all_operator_0() {
    let owner = setup();
    let operator = contract_address_const::<0>();
    ERC1155::set_approval_for_all(operator, true);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('cannot set for self', ))]
fn test_set_approval_for_all_operator_self() {
    let owner = setup();
    ERC1155::set_approval_for_all(owner, true);
}

#[test]
#[available_gas(2000000)]
fn test_mint() {
    let owner = setup();

    let success = ERC1155::mint(owner, 1.into(), 10.into());
    assert(success, 'Error while minting');

    let balance = ERC1155::balance_of(owner, 1.into());
    assert(balance == 10.into(), 'Balance is not 10');
}

#[test]
#[available_gas(2000000)]
fn test_mint_batch() {
    let owner = setup();
    let mut ids = generate_array_u256(2_u32, 1.into(), 1.into());
    let mut values = generate_array_u256(2_u32, 10.into(), 10.into());

    let success = ERC1155::mint_batch(owner, ids.clone(), values);
    assert(success, 'Error while minting');

    let mut owners = ArrayTrait::<ContractAddress>::new();
    owners.append(owner);
    owners.append(owner);

    let mut balances = ERC1155::balance_of_batch(owners, ids);
    assert(balances.pop_front().unwrap() == 10.into(), 'Balance of 1 is not 10');
    assert(balances.pop_front().unwrap() == 20.into(), 'Balance of 2 is not 20');
}



#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('mint to the zero address', ))]
fn test_mint_to_0() {
    let owner = setup();
    ERC1155::mint(contract_address_const::<0>(), 1.into(), 10.into());
}

#[test]
#[available_gas(9000000)]
#[should_panic(expected: ('only owner can mint', ))]
fn test_mint_not_owner() {
    set_caller_address(contract_address_const::<3>());
    ERC1155::mint(contract_address_const::<3>(), 1.into(), 10.into());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('only owner can mint', ))]
fn test_mint_batch_not_owner() {
    let mut ids = generate_array_u256(2_u32, 1.into(), 1.into());
    let mut values = generate_array_u256(2_u32, 10.into(), 10.into());

    set_caller_address(contract_address_const::<3>());
    ERC1155::mint_batch(contract_address_const::<3>(), ids, values);
}

#[test]
#[available_gas(2000000)]
fn test_safe_transfer_from() {
    let owner = setup();
    let success = ERC1155::mint(owner, 1.into(), 10.into());
    assert(success, 'Error while minting');

    let balance = ERC1155::balance_of(owner, 1.into());
    assert(balance == 10.into(), 'Balance is not 10');

    ERC1155::safe_transfer_from(owner, contract_address_const::<2>(), 1.into(), 3.into());

    let balance_1 = ERC1155::balance_of(owner, 1.into());
    assert(balance_1 == 7.into(), 'Balance is not 7');

    let balance_2 = ERC1155::balance_of(contract_address_const::<2>(), 1.into());
    assert(balance_2 == 3.into(), 'Balance is not 3');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('transfer to the zero address', ))]
fn test_safe_transfer_from_to_0() {
    let owner = setup();
    let success = ERC1155::mint(owner, 1.into(), 10.into());
    assert(success, 'Error while minting');

    ERC1155::safe_transfer_from(owner, contract_address_const::<0>(), 1.into(), 3.into());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('insufficient balance', ))]
fn test_safe_transfer_from_insufficient_balance() {
    let owner = setup();
    let success = ERC1155::mint(owner, 1.into(), 10.into());
    assert(success, 'Error while minting');

    ERC1155::safe_transfer_from(owner, contract_address_const::<2>(), 1.into(), 15.into());
}

#[test]
#[available_gas(9000000)]
#[should_panic(expected: ('caller not owner or approved', ))]
fn test_safe_transfer_from_not_approved() {
    let owner = setup();
    let success = ERC1155::mint(owner, 1.into(), 10.into());
    assert(success, 'Error while minting');

    set_caller_address(contract_address_const::<3>());
    ERC1155::safe_transfer_from(owner, contract_address_const::<2>(), 1.into(), 15.into());
}


#[test]
#[available_gas(9000000)]
fn test_safe_batch_transfer_from() {
    let owner = setup();
    let mut ids = generate_array_u256(2_u32, 1.into(), 1.into());
    let mut values = generate_array_u256(2_u32, 10.into(), 10.into());

    let success = ERC1155::mint_batch(owner, ids.clone(), values.clone());
    assert(success, 'Error while minting');

    let mut owners = ArrayTrait::<ContractAddress>::new();
    owners.append(owner);
    owners.append(owner);

    let mut balances = ERC1155::balance_of_batch(owners.clone(), ids.clone());
    assert(balances.pop_front().unwrap() == 10.into(), 'Balance is not 10');
    assert(balances.pop_front().unwrap() == 20.into(), 'Balance is not 10');

    let mut transfered_val = generate_array_u256(2_u32, 3.into(), 2.into());
    let success = ERC1155::safe_batch_transfer_from(owner, contract_address_const::<2>(), ids.clone(), transfered_val);
    assert(success, 'Error while batch transfer');

    let mut balances_owner = ERC1155::balance_of_batch(owners.clone(), ids.clone());
    assert(balances_owner.pop_front().unwrap() == 7.into(), 'Balance is not 7');
    assert(balances_owner.pop_front().unwrap() == 15.into(), 'Balance is not 15');

    let mut users = ArrayTrait::<ContractAddress>::new();
    users.append(contract_address_const::<2>());
    users.append(contract_address_const::<2>());

    let mut balances_user = ERC1155::balance_of_batch(users, ids.clone());
    assert(balances_user.pop_front().unwrap() == 3.into(), 'Balance is not 3');
    assert(balances_user.pop_front().unwrap() == 5.into(), 'Balance is not 5');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('cannot call transfer from 0', ))]
fn test_safe_batch_transfer_from_operator_0() {
    let mut ids = generate_array_u256(2_u32, 1.into(), 1.into());
    let mut values = generate_array_u256(2_u32, 10.into(), 10.into());
    set_caller_as_zero();
    ERC1155::safe_batch_transfer_from(contract_address_const::<1>(), contract_address_const::<2>(), ids.clone(), values);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('transfer to the 0 address', ))]
fn test_safe_batch_transfer_from_to_0() {
    let owner = setup();
    let mut ids = generate_array_u256(2_u32, 1.into(), 1.into());
    let mut values = generate_array_u256(2_u32, 10.into(), 10.into());
    ERC1155::safe_batch_transfer_from(owner, contract_address_const::<0>(), ids, values);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ids and values len mismatch', ))]
fn test_safe_batch_transfer_from_len_mismatch() {
    let owner = setup();
    let mut ids = generate_array_u256(2_u32, 1.into(), 1.into());
    let mut values = generate_array_u256(1_u32, 10.into(), 10.into());
    ERC1155::safe_batch_transfer_from(owner, contract_address_const::<2>(), ids, values);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('caller not owner or approved', ))]
fn test_safe_batch_transfer_from_not_approved() {
    let owner = setup();
    let mut ids = generate_array_u256(2_u32, 1.into(), 1.into());
    let mut values = generate_array_u256(2_u32, 10.into(), 10.into());
    set_caller_address(contract_address_const::<3>());
    ERC1155::safe_batch_transfer_from(owner, contract_address_const::<0>(), ids, values);
}

#[test]
#[available_gas(2000000)]
fn test_burn() {
    let owner = setup();

    ERC1155::mint(owner, 1.into(), 10.into());

    let success = ERC1155::burn(owner, 1.into(), 3.into());
    assert(success, 'Error while burning');

    let balance = ERC1155::balance_of(owner, 1.into());
    assert(balance == 7.into(), 'Balance is not 7');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('burn from 0 address', ))]
fn test_burn_from_0() {
    let owner = setup();
    ERC1155::mint(owner, 1.into(), 10.into());
    ERC1155::burn(contract_address_const::<0>(), 1.into(), 3.into());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('caller not owner or approved', ))]
fn test_burn_not_approved() {
    let owner = setup();
    ERC1155::mint(owner, 1.into(), 10.into());
    set_caller_address(contract_address_const::<3>());
    ERC1155::burn(owner, 1.into(), 3.into());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('insufficient balance', ))]
fn test_burn_insufficient_balance() {
    let owner = setup();
    ERC1155::mint(owner, 1.into(), 10.into());
    ERC1155::burn(owner, 1.into(), 20.into());
}


#[test]
#[available_gas(9000000)]
fn test_burn_batch() {
    let owner = setup();
    let mut ids = generate_array_u256(2_u32, 1.into(), 1.into());
    let mut values = generate_array_u256(2_u32, 10.into(), 10.into());

    let success = ERC1155::mint_batch(owner, ids.clone(), values.clone());
    assert(success, 'Error while minting');

    let mut owners = ArrayTrait::<ContractAddress>::new();
    owners.append(owner);
    owners.append(owner);

    let mut burn_values = generate_array_u256(2_u32, 3.into(), 2.into());

    let success = ERC1155::burn_batch(owner, ids.clone(), burn_values.clone());
    assert(success, 'Error while batch burning');
 
    let mut balances = ERC1155::balance_of_batch(owners.clone(), ids.clone());
    assert(balances.pop_front().unwrap() == 7.into(), 'Balance is not 7');
    assert(balances.pop_front().unwrap() == 15.into(), 'Balance is not 15');
}

#[test]
#[available_gas(9000000)]
#[should_panic(expected: ('caller not owner or approved', ))]
fn test_burn_batch_not_approved() {
    let owner = setup();
    let mut ids = generate_array_u256(2_u32, 1.into(), 1.into());
    let mut values = generate_array_u256(2_u32, 10.into(), 10.into());
    ERC1155::mint_batch(owner, ids.clone(), values.clone());

    set_caller_address(contract_address_const::<3>());
    ERC1155::burn_batch(owner, ids, values);
}

#[test]
#[available_gas(9000000)]
#[should_panic(expected: ('burn from 0 address', ))]
fn test_burn_batch_from_0() {
    let owner = setup();
    let mut ids = generate_array_u256(2_u32, 1.into(), 1.into());
    let mut values = generate_array_u256(2_u32, 10.into(), 10.into());

    ERC1155::mint_batch(owner, ids.clone(), values.clone());
    ERC1155::burn_batch(contract_address_const::<0>(), ids, values);
}

#[test]
#[available_gas(9000000)]
#[should_panic(expected: ('ids and values len mismatch', ))]
fn test_burn_batch_len_mismatch() {
    let owner = setup();
    let mut ids = generate_array_u256(2_u32, 1.into(), 1.into());
    let mut values = generate_array_u256(1_u32, 10.into(), 10.into());

    ERC1155::mint_batch(owner, ids.clone(), values.clone());
    ERC1155::burn_batch(owner, ids, values);
}
