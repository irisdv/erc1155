#[contract]
mod ERC1155 {
    use traits::Into;
    use array::ArrayTrait;
    use array::SpanTrait;
    use debug::PrintTrait;
    use option::OptionTrait;
    use box::BoxTrait;
    use clone::Clone;
    use array::ArrayTCloneImpl;

    use starknet::get_caller_address;
    use starknet::contract_address_const;
    use starknet::ContractAddress;
    use starknet::ContractAddressIntoFelt252;
    use zeroable::Zeroable;
    use starknet::ContractAddressZeroable;

    use gas::withdraw_gas_all;
    use gas::get_builtin_costs;

    use erc1155::interfaces::IERC1155ReceiverDispatcher;
    use erc1155::interfaces::IERC1155ReceiverDispatcherTrait;
    use erc1155::interfaces::IERC165Dispatcher;
    use erc1155::interfaces::IERC165DispatcherTrait;

    const IERC1155_ID: felt252 = 0xd9b67a26;
    const IERC1155_METADATA_ID: felt252 = 0x0e89341c;
    const IERC1155_RECEIVER_ID: felt252 = 0x4e2312e0;
    const ON_ERC1155_RECEIVED_SELECTOR: felt252 = 0xf23a6e61;
    const ON_ERC1155_BATCH_RECEIVED_SELECTOR: felt252 = 0xbc197c81;
    const IACCOUNT_ID: felt252 = 0xa66bd575;

    struct Storage {
        contract_owner: ContractAddress,
        balances: LegacyMap::<(ContractAddress, u256), u256>,
        operator_approvals: LegacyMap::<(ContractAddress, ContractAddress), bool>,
        token_uris: LegacyMap::<u32, felt252>
    }

    #[event]
    fn TransferSingle(
        operator: ContractAddress,
        from_: ContractAddress,
        to: ContractAddress,
        id: u256,
        value: u256,
    ) {}

    #[event]
    fn TransferBatch(
        operator: ContractAddress,
        from_: ContractAddress,
        to: ContractAddress,
        ids: Array::<u256>,
        values: Array::<u256>,
    ) {}

    #[event]
    fn ApprovalForAll(account: ContractAddress, operator: ContractAddress, approved: bool) {}

    #[event]
    fn URI(value: Array::<felt252>, id: u256) {}

    #[constructor]
    fn constructor(_owner: ContractAddress, uri: Array::<felt252>) {
        contract_owner::write(_owner);
        _set_uri(uri);
    }

    fn _set_uri(uri: Array<felt252>) {
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
            if i == uri.len() {
                break ();
            }

            match uri.get(i) {
                Option::Some(value) => {
                    token_uris::write(i, *value.unbox());
                },
                Option::None(_) => {
                    break ();
                },
            }
            let j = i + 1_u32;
            i = j;
        };
    }

    //
    // Modifiers
    //

    fn assert_owner_or_approved(owner: ContractAddress) {
        let caller = get_caller_address();
        if caller == owner {
            return ();
        }
        let approved = is_approved_for_all(owner, caller);
        assert(approved, 'caller not owner or approved');
    }

    fn assert_only_owner() {
        let _owner = contract_owner::read();
        let operator = get_caller_address();
        assert(operator == _owner, 'only owner can mint');
    }

    //
    // Getters
    //

    #[view]
    fn uri(id: u256) -> Array::<felt252> {
        let mut uri = ArrayTrait::<felt252>::new();
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
            let value = token_uris::read(i);
            if (value.is_zero()) {
                break ();
            }
            uri.append(value);
            let j = i + 1_u32;
            i = j;
        };
        // uri.append(id.into());
        uri
    }

    #[view]
    fn balance_of(account: ContractAddress, id: u256) -> u256 {
        assert(!account.is_zero(), 'address 0 is not a valid owner');
        balances::read((account, id))
    }

    #[view]
    fn balance_of_batch(accounts: Array<ContractAddress>, ids: Array<u256>) -> Array<u256> {
        assert(accounts.len() == ids.len(), 'accounts and ids len mismatch');
        let mut batch_balance = ArrayTrait::<u256>::new();
        let mut _accounts = accounts;
        let mut _ids = ids;

        loop {
            match gas::withdraw_gas_all(get_builtin_costs()) {
                Option::Some(_) => {},
                Option::None(_) => {
                    let mut data = ArrayTrait::new();
                    data.append('Out of gas');
                    panic(data);
                },
            }
            if _accounts.len() == 0_u32 {
                break ();
            }
            let balance = balances::read(
                (_accounts.pop_front().unwrap(), _ids.pop_front().unwrap())
            );
            batch_balance.append(balance);
        };
        batch_balance
    }

    #[view]
    fn is_approved_for_all(account: ContractAddress, operator: ContractAddress) -> bool {
        operator_approvals::read((account, operator))
    }

    #[view]
    fn owner() -> ContractAddress {
        contract_owner::read()
    }

    //
    // Getters
    //

    #[external]
    fn set_approval_for_all(operator: ContractAddress, approved: bool) -> bool {
        let caller = get_caller_address();
        assert(!caller.is_zero(), 'caller cannot be 0 address');
        assert(!operator.is_zero(), 'operator cannot be 0 address');
        assert(caller != operator, 'cannot set for self');
        operator_approvals::write((caller, operator), approved);
        ApprovalForAll(caller, operator, approved);
        true
    }

    #[external]
    fn safe_transfer_from(
        from_: ContractAddress, to: ContractAddress, id: u256, value: u256
    ) -> bool {
        assert(!to.is_zero(), 'transfer to the zero address');

        assert_owner_or_approved(from_);

        let from_balance = balances::read((from_, id));
        assert(from_balance >= value, 'insufficient balance');
        let new_balance = from_balance - value;
        balances::write((from_, id), new_balance);

        _add_to_receiver(id, value, to);

        let operator = get_caller_address();
        TransferSingle(operator, from_, to, id, value);
        // todo add data 
        _do_safe_transfer_acceptance_check(
            operator, from_, to, id, value, ArrayTrait::<felt252>::new()
        );
        true
    }


    #[external]
    fn safe_batch_transfer_from(
        from_: ContractAddress, to: ContractAddress, ids: Array<u256>, values: Array<u256>
    ) -> bool {
        let operator = get_caller_address();
        assert(!operator.is_zero(), 'cannot call transfer from 0');

        assert_owner_or_approved(from_);

        assert(!to.is_zero(), 'transfer to the 0 address');
        assert(ids.len() == values.len(), 'ids and values len mismatch');

        let mut _ids = ids.clone();
        let mut _values = values.clone();

        loop {
            match gas::withdraw_gas_all(get_builtin_costs()) {
                Option::Some(_) => {},
                Option::None(_) => {
                    let mut data = ArrayTrait::new();
                    data.append('Out of gas');
                    panic(data);
                },
            }
            if _ids.len() == 0_u32 {
                break ();
            }
            safe_transfer_from(from_, to, _ids.pop_front().unwrap(), _values.pop_front().unwrap());
        };

        TransferBatch(operator, from_, to, ids, values);
        true
    }

    #[external]
    fn mint(to: ContractAddress, id: u256, value: u256) -> bool {
        assert_only_owner();
        assert(!to.is_zero(), 'mint to the zero address');

        // Add to minter
        _add_to_receiver(id, value, to);

        // Emit events
        let operator = get_caller_address();
        TransferSingle(operator, starknet::contract_address_const::<0>(), to, id, value);
        // todo update DATA array in arg
        _do_safe_transfer_acceptance_check(
            operator,
            starknet::contract_address_const::<0>(),
            to,
            id,
            value,
            ArrayTrait::<felt252>::new()
        );
        true
    }

    #[external]
    fn mint_batch(to: ContractAddress, ids: Array<u256>, values: Array<u256>) -> bool {
        assert_only_owner();
        assert(!to.is_zero(), 'mint to the zero address');
        assert(ids.len() == values.len(), 'ids and values len mismatch');

        let mut _ids = ids.clone();
        let mut _values = values.clone();

        loop {
            match gas::withdraw_gas_all(get_builtin_costs()) {
                Option::Some(_) => {},
                Option::None(_) => {
                    let mut data = ArrayTrait::new();
                    data.append('Out of gas');
                    panic(data);
                },
            }
            if _ids.len() == 0_u32 {
                break ();
            }
            mint(to, _ids.pop_front().unwrap(), _values.pop_front().unwrap());
        };

        let operator = get_caller_address();
        TransferBatch(operator, starknet::contract_address_const::<0>(), to, ids, values);
        true
    }

    #[external]
    fn burn(from_: ContractAddress, id: u256, value: u256) -> bool {
        assert(!from_.is_zero(), 'burn from 0 address');
        assert_owner_or_approved(from_);

        let from_balance = balances::read((from_, id));
        assert(from_balance >= value, 'insufficient balance');
        let new_balance = from_balance - value;
        balances::write((from_, id), new_balance);

        let operator = get_caller_address();
        TransferSingle(operator, from_, starknet::contract_address_const::<0>(), id, value);
        true
    }

    #[external]
    fn burn_batch(from_: ContractAddress, ids: Array<u256>, values: Array<u256>) -> bool {
        assert(!from_.is_zero(), 'burn from 0 address');
        assert(ids.len() == values.len(), 'ids and values len mismatch');
        assert_owner_or_approved(from_);

        let mut _ids = ids.clone();
        let mut _values = values.clone();

        loop {
            match gas::withdraw_gas_all(get_builtin_costs()) {
                Option::Some(_) => {},
                Option::None(_) => {
                    let mut data = ArrayTrait::new();
                    data.append('Out of gas');
                    panic(data);
                },
            }
            if _ids.len() == 0_u32 {
                break ();
            }
            burn(from_, _ids.pop_front().unwrap(), _values.pop_front().unwrap());
        };

        let operator = get_caller_address();
        TransferBatch(operator, from_, starknet::contract_address_const::<0>(), ids, values);
        true
    }

    #[external]
    fn transfer_ownership(new_owner: ContractAddress) {
        assert_only_owner();
        contract_owner::write(new_owner);
    }

    //
    // Private
    //
    fn _add_to_receiver(id: u256, value: u256, receiver: ContractAddress) {
        let receiver_balance = balances::read((receiver, id));
        let new_balance = receiver_balance + value;
        balances::write((receiver, id), new_balance);
    }

    fn _do_safe_transfer_acceptance_check(
        operator: ContractAddress,
        from_: ContractAddress,
        to: ContractAddress,
        id: u256,
        value: u256,
        data: Array<felt252>
    ) {
        let is_supported: bool = IERC165Dispatcher {
            contract_address: to
        }.supports_interface(IERC1155_RECEIVER_ID);
        if is_supported {
            let selector = IERC1155ReceiverDispatcher {
                contract_address: to
            }.on_erc1155_received(operator, from_, id, value, data);
            assert(selector == ON_ERC1155_RECEIVED_SELECTOR, 'ERC1155Receiver rejected tokens');
        } else {
            assert(
                IERC165Dispatcher { contract_address: to }.supports_interface(IACCOUNT_ID),
                'transfer to non-ERC1155Receiver'
            );
        }
    }
}
